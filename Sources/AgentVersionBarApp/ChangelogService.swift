import Foundation

struct ChangelogRequest: Equatable, Sendable {
    let provider: ProviderKind
    let currentVersion: String
    let latestVersion: String
    let sourceURL: URL

    init?(
        provider: ProviderKind,
        currentVersion: String?,
        latestVersion: String?,
        sourceURL: URL?
    ) {
        guard let currentVersion,
              let latestVersion,
              let sourceURL else {
            return nil
        }

        self.provider = provider
        self.currentVersion = currentVersion
        self.latestVersion = latestVersion
        self.sourceURL = sourceURL
    }

    init?(snapshot: ProviderVersionSnapshot) {
        self.init(
            provider: snapshot.provider,
            currentVersion: snapshot.currentVersion,
            latestVersion: snapshot.latestVersion,
            sourceURL: snapshot.changelogURL
        )
    }
}

struct ChangelogContent: Equatable, Sendable {
    let request: ChangelogRequest
    let summary: String?
    let originalContent: String?
    let summaryErrorDescription: String?
}

enum ChangelogViewState: Equatable, Sendable {
    case idle
    case loading(ChangelogRequest)
    case loaded(ChangelogContent)
    case failed(ChangelogRequest, String)
}

struct ChangelogService: Sendable {
    typealias Loader = @Sendable (ChangelogRequest) async throws -> ChangelogContent

    let load: Loader

    static let live = ChangelogService { request in
        try await Task.detached(priority: .userInitiated) {
            try LiveChangelogLoader().load(request: request)
        }.value
    }
}

private struct LiveChangelogLoader {
    private let commandRunner: ([String]) -> CommandOutput = VersionRefreshService.runCommand

    func load(request: ChangelogRequest) throws -> ChangelogContent {
        let originalContent = try extractOriginalContent(for: request)

        do {
            let summary = try summarize(request: request)
            return ChangelogContent(
                request: request,
                summary: summary,
                originalContent: originalContent,
                summaryErrorDescription: nil
            )
        } catch {
            return ChangelogContent(
                request: request,
                summary: nil,
                originalContent: originalContent,
                summaryErrorDescription: readableError(from: error)
            )
        }
    }

    private func extractOriginalContent(for request: ChangelogRequest) throws -> String {
        let output = commandRunner([
            "/usr/bin/env",
            "summarize",
            request.sourceURL.absoluteString,
            "--extract",
            "--format", "md",
            "--markdown-mode", "readability",
            "--plain",
            "--no-color",
            "--max-extract-characters", "40000"
        ])

        let text = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard output.exitCode == 0, text.isEmpty == false else {
            throw ChangelogServiceError.extractionFailed(errorMessage(from: output))
        }

        return text
    }

    private func summarize(request: ChangelogRequest) throws -> String {
        let output = commandRunner([
            "/usr/bin/env",
            "summarize",
            request.sourceURL.absoluteString,
            "--plain",
            "--no-color",
            "--length", "medium",
            "--prompt", summaryPrompt(for: request)
        ])

        let text = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard output.exitCode == 0, text.isEmpty == false else {
            throw ChangelogServiceError.summaryFailed(errorMessage(from: output))
        }

        return text
    }

    private func summaryPrompt(for request: ChangelogRequest) -> String {
        """
        Summarize the most important changes for \(request.provider.displayName) between installed version \(request.currentVersion) and available version \(request.latestVersion). Focus on user-impacting features, fixes, breaking changes, migration notes, and update risk. Keep it concise and structured for a coding tool user.
        """
    }

    private func errorMessage(from output: CommandOutput) -> String {
        let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        let stdout = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = stderr.isEmpty == false ? stderr : stdout

        if message.isEmpty {
            return "summarize command failed"
        }

        return message
    }

    private func readableError(from error: Error) -> String {
        if let serviceError = error as? ChangelogServiceError {
            return serviceError.errorDescription ?? "Summary unavailable"
        }

        return error.localizedDescription
    }
}

private enum ChangelogServiceError: LocalizedError {
    case extractionFailed(String)
    case summaryFailed(String)

    var errorDescription: String? {
        switch self {
        case let .extractionFailed(message):
            return message
        case let .summaryFailed(message):
            return message
        }
    }
}
