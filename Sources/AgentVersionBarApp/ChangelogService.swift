import Foundation

struct ChangelogRequest: Equatable, Hashable, Sendable {
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
            latestVersion: snapshot.effectiveLatestVersion,
            sourceURL: snapshot.changelogSourceURL
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
    case loading(ChangelogRequest, ChangelogLoadingPhase)
    case showingOriginal(ChangelogContent)
    case loaded(ChangelogContent)
    case unavailable(ProviderKind)
    case failed(ProviderKind, String)
}

enum ChangelogLoadingPhase: Equatable, Sendable {
    case fetching
    case summarizing

    var title: String {
        switch self {
        case .fetching:
            return "Fetching official changelog"
        case .summarizing:
            return "Summarizing latest two versions"
        }
    }

    var subtitle: String {
        switch self {
        case .fetching:
            return "Reading the official release notes page."
        case .summarizing:
            return "Generating a Chinese summary from the newest two versions."
        }
    }
}

struct ChangelogService: Sendable {
    typealias Extractor = @Sendable (ChangelogRequest) async throws -> String
    typealias Summarizer = @Sendable (ChangelogRequest, String) async throws -> String

    let extract: Extractor
    let summarize: Summarizer

    static let live = ChangelogService(
        extract: { request in
            try await Task.detached(priority: .userInitiated) {
                try LiveChangelogLoader().extractOriginalContent(for: request)
            }.value
        },
        summarize: { request, sourceContent in
            try await Task.detached(priority: .userInitiated) {
                try LiveChangelogLoader().summarize(request: request, sourceContent: sourceContent)
            }.value
        }
    )

    static func latestVersionSections(from markdown: String, limit: Int = 2) -> String {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return markdown
        }

        let lines = trimmed.components(separatedBy: .newlines)
        let headingPattern = #"^\[v?\d+(?:\.\d+)+(?:[-+][A-Za-z0-9._-]+)?\]\("#
        var sectionStartIndexes: [Int] = []

        for (index, line) in lines.enumerated() {
            if line.range(of: headingPattern, options: .regularExpression) != nil {
                sectionStartIndexes.append(index)
            }
        }

        guard sectionStartIndexes.isEmpty == false else {
            return markdown
        }

        let limitedStarts = Array(sectionStartIndexes.prefix(limit))
        let endIndex = limitedStarts.count < sectionStartIndexes.count
            ? sectionStartIndexes[limitedStarts.count]
            : lines.count

        return lines[..<endIndex].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func summaryPrompt(for request: ChangelogRequest) -> String {
        """
        请使用中文，总结 \(request.provider.displayName) 从已安装版本 \(request.currentVersion) 到可用版本 \(request.latestVersion) 的关键变化。只基于输入内容里的最近 2 个版本进行总结。重点提炼：用户可感知的新功能、重要修复、破坏性变更、迁移注意事项、升级风险。输出尽量简洁，适合开发者快速判断是否升级。
        """
    }

    static func summaryCommand(
        for request: ChangelogRequest,
        environment: ChangelogCommandEnvironment = .init(hasSummarize: true, hasCodex: true)
    ) -> [String]? {
        guard environment.hasSummarize else {
            return nil
        }

        var command = [
            "/usr/bin/env",
            "summarize",
            "-",
            "--plain",
            "--no-color",
            "--stream", "off",
            "--metrics", "off",
            "--length", "medium",
            "--timeout", "30s",
            "--prompt", summaryPrompt(for: request)
        ]

        if environment.hasCodex {
            command.insert(contentsOf: ["--cli", "codex"], at: 3)
        }

        return command
    }

    static func extractCommand(for request: ChangelogRequest) -> [String] {
        [
            "/usr/bin/env",
            "summarize",
            request.sourceURL.absoluteString,
            "--extract",
            "--format", "md",
            "--markdown-mode", "readability",
            "--plain",
            "--no-color",
            "--stream", "off",
            "--metrics", "off",
            "--timeout", "30s",
            "--max-extract-characters", "12000"
        ]
    }

    static func readableSummaryError(from error: Error) -> String {
        if let serviceError = error as? ChangelogServiceError {
            return serviceError.errorDescription ?? "Summary unavailable"
        }

        return error.localizedDescription
    }
}

struct ChangelogCommandEnvironment: Equatable, Sendable {
    let hasSummarize: Bool
    let hasCodex: Bool
}

private struct LiveChangelogLoader {
    func extractOriginalContent(for request: ChangelogRequest) throws -> String {
        let environment = commandEnvironment()
        guard environment.hasSummarize else {
            throw ChangelogServiceError.extractionFailed("summarize is not installed")
        }

        let output = try runCommand(ChangelogService.extractCommand(for: request))

        let text = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard output.exitCode == 0, text.isEmpty == false else {
            throw ChangelogServiceError.extractionFailed(errorMessage(from: output))
        }

        return text
    }

    func summarize(request: ChangelogRequest, sourceContent: String) throws -> String {
        let environment = commandEnvironment()
        guard let command = ChangelogService.summaryCommand(for: request, environment: environment) else {
            throw ChangelogServiceError.summaryUnavailable("summarize is not installed")
        }

        let output = try runCommand(
            command,
            stdin: sourceContent
        )

        let text = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard output.exitCode == 0, text.isEmpty == false else {
            throw ChangelogServiceError.summaryFailed(errorMessage(from: output))
        }

        return text
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

    private func commandEnvironment() -> ChangelogCommandEnvironment {
        let hasSummarize = commandExists("summarize")
        let hasCodex = commandExists("codex")
        return ChangelogCommandEnvironment(hasSummarize: hasSummarize, hasCodex: hasCodex)
    }

    private func commandExists(_ name: String) -> Bool {
        let output = try? runCommand(["/usr/bin/env", "sh", "-lc", "command -v \(name) >/dev/null 2>&1"])
        return output?.exitCode == 0
    }
    private func runCommand(_ command: [String], stdin: String? = nil) throws -> CommandOutput {
        guard let executable = command.first else {
            throw ChangelogServiceError.executionFailed("Missing executable")
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()

        if executable.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = Array(command.dropFirst())
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = command
        }

        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.standardInput = stdinPipe

        do {
            try process.run()
        } catch {
            stdinPipe.fileHandleForWriting.closeFile()
            throw ChangelogServiceError.executionFailed(error.localizedDescription)
        }

        if let stdin {
            if let data = stdin.data(using: .utf8) {
                stdinPipe.fileHandleForWriting.write(data)
            }
        }
        stdinPipe.fileHandleForWriting.closeFile()

        let timeoutDate = Date().addingTimeInterval(35)
        while process.isRunning && Date() < timeoutDate {
            Thread.sleep(forTimeInterval: 0.05)
        }

        if process.isRunning {
            process.terminate()
            process.waitUntilExit()
            throw ChangelogServiceError.executionFailed("summarize command timed out")
        }

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        return CommandOutput(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self)
        )
    }
}

enum ChangelogServiceError: LocalizedError {
    case extractionFailed(String)
    case summaryFailed(String)
    case summaryUnavailable(String)
    case executionFailed(String)

    var errorDescription: String? {
        switch self {
        case let .extractionFailed(message):
            return message
        case let .summaryFailed(message):
            return message
        case let .summaryUnavailable(message):
            return message
        case let .executionFailed(message):
            return message
        }
    }
}
