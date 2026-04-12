import Foundation

struct CommandOutput: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
}

struct VersionRefreshService: Sendable {
    typealias CommandRunner = @Sendable ([String]) -> CommandOutput

    let commandRunner: CommandRunner
    let dateProvider: @Sendable () -> Date

    static let live = VersionRefreshService(
        commandRunner: Self.runCommand,
        dateProvider: Date.init
    )

    func refreshAll() async -> [ProviderVersionSnapshot] {
        await withTaskGroup(of: ProviderVersionSnapshot.self) { group in
            for provider in ProviderKind.allCases {
                group.addTask {
                    refresh(provider: provider)
                }
            }

            var snapshots: [ProviderVersionSnapshot] = []
            for await snapshot in group {
                snapshots.append(snapshot)
            }

            let order = Dictionary(uniqueKeysWithValues: ProviderKind.allCases.enumerated().map { ($1, $0) })
            return snapshots.sorted { order[$0.provider, default: 0] < order[$1.provider, default: 0] }
        }
    }

    func refresh(provider: ProviderKind) -> ProviderVersionSnapshot {
        let executableLocation = resolveExecutablePath(for: provider)
        let executablePath = executableLocation.commandPath
        let resolvedExecutablePath = executableLocation.resolvedPath
        let installSource = VersionParsing.detectInstallSource(
            executablePath: resolvedExecutablePath ?? executablePath,
            provider: provider
        )
        let configPath = resolveConfigPath(for: provider)
        let statusVersions = provider == .openClaw
            ? openClawStatusVersions(executablePath: executablePath)
            : (current: nil, latest: nil)
        let current = statusVersions.current ?? currentVersion(for: provider, executablePath: executablePath)
        let latest = statusVersions.latest ?? latestVersion(
            for: provider,
            installSource: installSource,
            executablePath: executablePath
        )
        let updateCommand = terminalUpdateCommand(
            for: provider,
            executablePath: executablePath,
            installSource: installSource
        )
        let error: String?
        if executablePath == nil {
            error = "CLI not found on PATH or common install locations"
        } else if current == nil && latest == nil {
            error = "No version information available"
        } else {
            error = nil
        }

        return ProviderVersionSnapshot(
            provider: provider,
            currentVersion: current,
            latestVersion: latest,
            executablePath: executablePath,
            resolvedExecutablePath: resolvedExecutablePath,
            configPath: configPath,
            installSource: installSource,
            installMethodTitle: provider.installMethodTitle(for: installSource, executablePath: executablePath),
            updateMethodTitle: provider.updateMethodTitle(command: updateCommand),
            terminalUpdateCommand: updateCommand,
            isInstalled: executablePath != nil,
            checkedAt: dateProvider(),
            errorDescription: error
        )
    }

    private func openClawStatusVersions(executablePath: String?) -> (current: String?, latest: String?) {
        guard let executablePath,
              let output = runTextCommand([executablePath, "status", "--json"]),
              let jsonText = VersionParsing.extractJSONPayload(from: output),
              let data = jsonText.data(using: .utf8),
              let payload = try? JSONDecoder().decode(OpenClawStatusPayload.self, from: data) else {
            return (nil, nil)
        }

        return (
            payload.version?.current ?? payload.runtimeVersion,
            payload.version?.latest
        )
    }

    private func currentVersion(for provider: ProviderKind, executablePath: String?) -> String? {
        guard let executablePath else {
            return nil
        }

        if provider == .paperclip {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: executablePath, isDirectory: &isDirectory),
               isDirectory.boolValue {
                return runTextCommand(["pnpm", "--dir", executablePath, "paperclipai", "--version"])
                    .flatMap(VersionParsing.extractFirstVersion(from:))
            }
        }

        return runTextCommand([executablePath, "--version"])
            .flatMap(VersionParsing.extractFirstVersion(from:))
    }

    private func latestVersion(for provider: ProviderKind, installSource: InstallSource, executablePath: String?) -> String? {
        if installSource == .sourceCheckout {
            return sourceCheckoutBehindTitle(executablePath: executablePath)
        }

        let lookupOrder = latestLookupOrder(for: provider, installSource: installSource)

        for source in lookupOrder {
            if let version = latestVersion(for: provider, source: source) {
                return version
            }
        }

        if let repository = provider.githubReleaseRepository,
           let version = latestGitHubReleaseVersion(repository: repository) {
            return version
        }

        return nil
    }

    private func sourceCheckoutBehindTitle(executablePath: String?) -> String? {
        guard let executablePath else {
            return nil
        }

        guard runTextCommand(["git", "-C", executablePath, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"]) != nil,
              let rawCount = runTextCommand(["git", "-C", executablePath, "rev-list", "--count", "HEAD..@{upstream}"]),
              let count = Int(rawCount.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return nil
        }

        let noun = count == 1 ? "commit" : "commits"
        return "\(count) \(noun) behind"
    }

    private func latestLookupOrder(for provider: ProviderKind, installSource: InstallSource) -> [InstallSource] {
        var order: [InstallSource] = []
        if installSource != .unknown, installSource != .directBinary, installSource != .nativeInstaller, installSource != .sourceCheckout {
            order.append(installSource)
        }

        for source in provider.fallbackLatestSources where order.contains(source) == false {
            order.append(source)
        }

        return order
    }

    private func latestVersion(for provider: ProviderKind, source: InstallSource) -> String? {
        switch source {
        case .homebrew:
            guard let brewPackage = provider.brewPackage,
                  let data = runJSONCommand(["brew", "info", "--json=v2", brewPackage]) else {
                return nil
            }

            return VersionParsing.latestVersionFromBrewInfo(data: data)
        case .npm, .pnpm:
            return runTextCommand(["npm", "view", provider.npmPackage, "version"])
                .flatMap(VersionParsing.extractFirstVersion(from:))
        case .sourceCheckout, .nativeInstaller, .directBinary, .unknown:
            return nil
        }
    }

    private func latestGitHubReleaseVersion(repository: String) -> String? {
        guard let data = runJSONCommand([
            "/usr/bin/curl",
            "-fsSL",
            "https://api.github.com/repos/\(repository)/releases/latest"
        ]),
        let payload = try? JSONDecoder().decode(GitHubReleasePayload.self, from: data) else {
            return nil
        }

        if let name = payload.name,
           let version = VersionParsing.extractFirstVersion(from: name) {
            return version
        }

        return VersionParsing.extractFirstVersion(from: payload.tagName)
    }

    private func resolveExecutablePath(for provider: ProviderKind) -> (commandPath: String?, resolvedPath: String?) {
        let executable = provider.executableName
        if let interactivePath = interactiveShellExecutablePath(for: executable) {
            return (interactivePath, URL(fileURLWithPath: interactivePath).resolvingSymlinksInPath().path)
        }

        let output = commandRunner(["/usr/bin/which", executable])
        if output.exitCode == 0 {
            let path = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if path.isEmpty == false {
                return (path, URL(fileURLWithPath: path).resolvingSymlinksInPath().path)
            }
        }

        let shellOutput = commandRunner(["/bin/zsh", "-lc", "command -v \(executable) 2>/dev/null"])
        if shellOutput.exitCode == 0 {
            let path = shellOutput.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            if path.isEmpty == false {
                return (path, URL(fileURLWithPath: path).resolvingSymlinksInPath().path)
            }
        }

        if let fallbackPath = executableFallbackCandidates(for: provider)
            .first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return (fallbackPath, URL(fileURLWithPath: fallbackPath).resolvingSymlinksInPath().path)
        }

        if let sourcePath = sourceCheckoutCandidate(for: provider) {
            return (sourcePath, sourcePath)
        }

        return (nil, nil)
    }

    private func interactiveShellExecutablePath(for executable: String) -> String? {
        let startMarker = "__AGENT_VERSION_BAR_START__"
        let endMarker = "__AGENT_VERSION_BAR_END__"
        let script = """
        printf '\(startMarker)\\n'
        whence -p \(Self.shellQuoted(executable))
        printf '\(endMarker)\\n'
        """

        let output = commandRunner(["/bin/zsh", "-lic", script])
        guard output.exitCode == 0,
              let section = VersionParsing.extractMarkedSection(
                from: output.stdout,
                startMarker: startMarker,
                endMarker: endMarker
              ) else {
            return nil
        }

        return section
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: $0) })
    }

    private func executableFallbackCandidates(for provider: ProviderKind) -> [String] {
        let home = NSHomeDirectory()
        var candidates = [
            "\(home)/.local/bin/\(provider.executableName)",
            "\(home)/.npm-packages/bin/\(provider.executableName)",
            "\(home)/Library/pnpm/\(provider.executableName)"
        ]

        if let npxExecutable = cachedNpxExecutable(for: provider) {
            candidates.append(npxExecutable)
        }

        return candidates
    }

    private func cachedNpxExecutable(for provider: ProviderKind) -> String? {
        guard let relativePath = provider.packageExecutableRelativePath else {
            return nil
        }

        let npxRoot = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".npm", isDirectory: true)
            .appendingPathComponent("_npx", isDirectory: true)

        guard let directories = try? FileManager.default.contentsOfDirectory(
            at: npxRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for directory in directories {
            let candidate = directory
                .appendingPathComponent("node_modules", isDirectory: true)
                .appendingPathComponent(relativePath)

            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate.path
            }
        }

        return nil
    }

    private func sourceCheckoutCandidate(for provider: ProviderKind) -> String? {
        guard provider == .paperclip else {
            return nil
        }

        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        let candidates = [
            "\(home)/projects/paperclip",
            "\(home)/src/paperclip",
            "\(home)/code/paperclip"
        ]

        return candidates.first(where: isPaperclipSourceCheckout)
    }

    private func isPaperclipSourceCheckout(_ path: String) -> Bool {
        let fileManager = FileManager.default
        let packageJSON = URL(fileURLWithPath: path).appendingPathComponent("package.json").path
        let cliPackageJSON = URL(fileURLWithPath: path).appendingPathComponent("cli/package.json").path
        return fileManager.fileExists(atPath: packageJSON) && fileManager.fileExists(atPath: cliPackageJSON)
    }

    private func resolveConfigPath(for provider: ProviderKind) -> String {
        let candidates = provider.configPathCandidates(home: NSHomeDirectory())
        if let existing = candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) {
            return existing
        }

        return candidates.first ?? "Unavailable"
    }

    private func terminalUpdateCommand(
        for provider: ProviderKind,
        executablePath: String?,
        installSource: InstallSource
    ) -> [String]? {
        if let executablePath, let nativeUpdateSubcommand = provider.nativeUpdateSubcommand() {
            return [executablePath] + nativeUpdateSubcommand
        }

        return provider.packageManagerUpdateCommand(
            for: installSource,
            executablePath: executablePath
        )
    }

    private func runTextCommand(_ command: [String]) -> String? {
        let output = commandRunner(command)
        let trimmed = output.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return output.exitCode == 0 && trimmed.isEmpty == false ? trimmed : nil
    }

    private func runJSONCommand(_ command: [String]) -> Data? {
        let output = commandRunner(command)
        guard output.exitCode == 0 else {
            return nil
        }

        return output.stdout.data(using: .utf8)
    }

    static func runCommand(_ command: [String]) -> CommandOutput {
        guard let executable = command.first else {
            return CommandOutput(exitCode: 1, stdout: "", stderr: "Missing executable")
        }

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        if executable.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = Array(command.dropFirst())
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = command
        }
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return CommandOutput(exitCode: 1, stdout: "", stderr: error.localizedDescription)
        }

        return CommandOutput(
            exitCode: process.terminationStatus,
            stdout: String(decoding: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self),
            stderr: String(decoding: stderrPipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        )
    }

    static func launchCommandInTerminal(_ command: [String], workingDirectory: String = NSHomeDirectory()) {
        let script = """
        tell application "Terminal"
            activate
            do script \(quotedAppleScriptString(for: terminalShellCommand(command: command, workingDirectory: workingDirectory)))
        end tell
        """

        _ = runCommand(["/usr/bin/osascript", "-e", script])
    }

    static func launchPathInTerminal(_ path: String) {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        let targetDirectory: String

        if exists, isDirectory.boolValue {
            targetDirectory = path
        } else {
            targetDirectory = URL(fileURLWithPath: path).deletingLastPathComponent().path
        }

        let script = """
        tell application "Terminal"
            activate
            do script \(quotedAppleScriptString(for: "cd \(shellQuoted(targetDirectory)); exec $SHELL -l"))
        end tell
        """

        _ = runCommand(["/usr/bin/osascript", "-e", script])
    }

    private static func terminalShellCommand(command: [String], workingDirectory: String) -> String {
        let cdPart = "cd \(shellQuoted(workingDirectory))"
        let commandPart = command.map(shellQuoted).joined(separator: " ")
        let tail = "status=$?; echo; echo \"Command finished with exit code $status.\"; exec $SHELL -l"
        return "\(cdPart); \(commandPart); \(tail)"
    }

    private static func shellQuoted(_ string: String) -> String {
        "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func quotedAppleScriptString(for string: String) -> String {
        let escaped = string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

enum VersionParsing {
    static func extractFirstVersion(from text: String) -> String? {
        if let match = text.range(of: #"\d+(?:\.\d+)+(?:[-+][A-Za-z0-9._-]+)?"#, options: .regularExpression) {
            return String(text[match])
        }

        return nil
    }

    static func extractJSONPayload(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            return nil
        }

        return String(text[start...end])
    }

    static func extractMarkedSection(from text: String, startMarker: String, endMarker: String) -> String? {
        guard let startRange = text.range(of: startMarker),
              let endRange = text.range(of: endMarker),
              startRange.upperBound <= endRange.lowerBound else {
            return nil
        }

        return String(text[startRange.upperBound..<endRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func detectInstallSource(executablePath: String?, provider: ProviderKind) -> InstallSource {
        guard let executablePath else {
            return .unknown
        }

        let normalized = executablePath.lowercased()
        if normalized.contains("/cellar/") || normalized.contains("/caskroom/") {
            return .homebrew
        }
        if normalized.contains("/.pnpm/") || normalized.contains("/pnpm/") {
            return .pnpm
        }
        if normalized.contains("/node_modules/") {
            return .npm
        }
        if provider == .claudeCode && normalized.contains("/claude code.app/") {
            return .nativeInstaller
        }
        if provider == .hermes && normalized.contains("/.hermes/hermes-agent/") {
            return .nativeInstaller
        }
        if provider == .paperclip &&
            (normalized.contains("/projects/paperclip") ||
             normalized.contains("/src/paperclip") ||
             normalized.contains("/code/paperclip")) {
            return .sourceCheckout
        }

        return .directBinary
    }

    static func latestVersionFromBrewInfo(data: Data) -> String? {
        guard let payload = try? JSONDecoder().decode(BrewInfoPayload.self, from: data) else {
            return nil
        }

        return payload.formulae.first?.versions.stable ?? payload.casks.first?.version
    }
}

private struct OpenClawStatusPayload: Decodable {
    let version: OpenClawVersionPayload?
    let runtimeVersion: String?
}

private struct OpenClawVersionPayload: Decodable {
    let current: String?
    let latest: String?
}

private struct BrewInfoPayload: Decodable {
    let formulae: [BrewFormulaPayload]
    let casks: [BrewCaskPayload]
}

private struct BrewFormulaPayload: Decodable {
    let versions: BrewVersionPayload
}

private struct BrewVersionPayload: Decodable {
    let stable: String?
}

private struct BrewCaskPayload: Decodable {
    let version: String?
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let name: String?

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
    }
}
