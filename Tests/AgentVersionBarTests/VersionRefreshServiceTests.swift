import Foundation
import Testing

@testable import AgentVersionBarApp

@Suite("VersionRefreshServiceTests")
struct VersionRefreshServiceTests {
    @Test
    func extractJSONPayloadIgnoresNoise() {
        let payload = VersionParsing.extractJSONPayload(from: """
        booting
        {"version":{"current":"1.2.0","latest":"1.3.0"}}
        trailing line
        """)

        XCTAssertEqual(payload, #"{"version":{"current":"1.2.0","latest":"1.3.0"}}"#)
    }

    @Test
    func extractMarkedSectionIgnoresShellNoise() {
        let text = """
        startup noise
        __AGENT_VERSION_BAR_START__
        /opt/homebrew/bin/codex
        __AGENT_VERSION_BAR_END__
        trailing noise
        """

        let payload = VersionParsing.extractMarkedSection(
            from: text,
            startMarker: "__AGENT_VERSION_BAR_START__",
            endMarker: "__AGENT_VERSION_BAR_END__"
        )

        XCTAssertEqual(payload, "/opt/homebrew/bin/codex")
    }

    @Test
    func extractCommitsBehindTitle() {
        XCTAssertEqual(
            VersionParsing.extractCommitsBehindTitle(from: "Update available: 5 commits behind — run 'hermes update'"),
            "5 commits behind"
        )
        XCTAssertEqual(
            VersionParsing.extractCommitsBehindTitle(from: "Update available: 1 commit behind"),
            "1 commit behind"
        )
        XCTAssertNil(VersionParsing.extractCommitsBehindTitle(from: "Up to date"))
    }

    @Test
    func commandEnvironmentAddsHomebrewPathsForGuiLaunches() {
        let environment = VersionRefreshService.commandEnvironment(base: [
            "HOME": "/Users/test",
            "PATH": "/usr/bin:/bin"
        ])
        let paths = environment["PATH"]?.split(separator: ":").map(String.init)

        XCTAssertEqual(paths?.prefix(4), [
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            "/usr/local/bin",
            "/usr/local/sbin"
        ])
        XCTAssertTrue(paths?.contains("/Users/test/.local/bin") == true)
        XCTAssertEqual(paths?.filter { $0 == "/usr/bin" }.count, 1)
    }

    @Test
    func detectInstallSourceUnderstandsPackageManagers() {
        XCTAssertEqual(
            VersionParsing.detectInstallSource(
                executablePath: "/opt/homebrew/Cellar/opencode/0.9.0/bin/opencode",
                provider: .openCode
            ),
            .homebrew
        )
        XCTAssertEqual(
            VersionParsing.detectInstallSource(
                executablePath: "/usr/local/lib/node_modules/openclaw/bin/openclaw.js",
                provider: .openClaw
            ),
            .npm
        )
        XCTAssertEqual(
            VersionParsing.detectInstallSource(
                executablePath: "/Users/test/Library/pnpm/global/5/.pnpm/opencode-ai@0.9.0/node_modules/opencode-ai/bin/opencode",
                provider: .openCode
            ),
            .pnpm
        )
        XCTAssertEqual(
            VersionParsing.detectInstallSource(
                executablePath: "/Users/test/.npm/_npx/hash/node_modules/opencode-ai/bin/opencode",
                provider: .openCode
            ),
            .npm
        )
        XCTAssertEqual(
            VersionParsing.detectInstallSource(
                executablePath: "/Users/test/.hermes/hermes-agent/venv/bin/hermes",
                provider: .hermes
            ),
            .nativeInstaller
        )
        XCTAssertEqual(
            VersionParsing.detectInstallSource(
                executablePath: "/usr/local/lib/node_modules/paperclipai/dist/index.js",
                provider: .paperclip
            ),
            .npm
        )
        XCTAssertEqual(
            VersionParsing.detectInstallSource(
                executablePath: "/Users/test/projects/paperclip",
                provider: .paperclip
            ),
            .sourceCheckout
        )
    }

    @Test
    func latestVersionFromBrewInfoSupportsFormulaeAndCasks() {
        let formulaData = Data("""
        {"formulae":[{"versions":{"stable":"0.9.2"}}],"casks":[]}
        """.utf8)
        let caskData = Data("""
        {"formulae":[],"casks":[{"version":"1.0.16"}]}
        """.utf8)

        XCTAssertEqual(VersionParsing.latestVersionFromBrewInfo(data: formulaData), "0.9.2")
        XCTAssertEqual(VersionParsing.latestVersionFromBrewInfo(data: caskData), "1.0.16")
    }

    @Test
    func commandEnvironmentAddsNvmDefaultBinForEnvCommands() throws {
        let fileManager = FileManager.default
        let homeURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let aliasURL = homeURL.appendingPathComponent(".nvm/alias", isDirectory: true)
        let binURL = homeURL.appendingPathComponent(".nvm/versions/node/v24.14.0/bin", isDirectory: true)

        try fileManager.createDirectory(at: aliasURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: binURL, withIntermediateDirectories: true)
        try "v24.14.0\n".write(to: aliasURL.appendingPathComponent("default"), atomically: true, encoding: .utf8)
        defer { try? fileManager.removeItem(at: homeURL) }

        let environment = VersionRefreshService.processEnvironment(
            for: ["npm", "view", "@openai/codex", "version"],
            baseEnvironment: ["PATH": "/usr/bin"],
            homeDirectory: homeURL.path,
            fileManager: fileManager
        )

        let pathEntries = environment["PATH"]?.split(separator: ":").map(String.init) ?? []
        XCTAssertEqual(pathEntries.first, binURL.path)
        XCTAssertTrue(pathEntries.contains("/usr/bin"))
    }

    @Test
    func hermesVersionCommandGetsLongerTimeout() {
        XCTAssertEqual(
            VersionRefreshService.commandTimeout(for: ["/Users/test/.local/bin/hermes", "--version"]),
            6
        )
        XCTAssertEqual(
            VersionRefreshService.commandTimeout(for: ["npm", "view", "@openai/codex", "version"]),
            4
        )
    }

    @Test
    func refreshUsesOpenClawStatusPayloadBeforeVersionCommand() {
        let service = VersionRefreshService(
            commandRunner: { command in
                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'openclaw'") == true {
                    return CommandOutput(exitCode: 1, stdout: "", stderr: "")
                }

                if command == ["/usr/bin/which", "openclaw"] {
                    return CommandOutput(exitCode: 0, stdout: "/usr/local/bin/openclaw\n", stderr: "")
                }

                if command.contains("status"), command.contains("--json") {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: #"{"version":{"current":"1.4.0","latest":"1.5.0"}}"#,
                        stderr: ""
                    )
                }

                if command == ["npm", "view", "openclaw", "version"] {
                    return CommandOutput(exitCode: 0, stdout: "1.5.0\n", stderr: "")
                }

                return CommandOutput(exitCode: 1, stdout: "", stderr: "unexpected")
            },
            dateProvider: { Date(timeIntervalSince1970: 100) }
        )

        let snapshot = service.refresh(provider: .openClaw)

        XCTAssertEqual(snapshot.currentVersion, "1.4.0")
        XCTAssertEqual(snapshot.latestVersion, "1.5.0")
        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.executablePath, "/usr/local/bin/openclaw")
        XCTAssertTrue(snapshot.resolvedExecutablePath?.contains("openclaw") == true)
        XCTAssertEqual(snapshot.terminalUpdateCommand, ["/usr/local/bin/openclaw", "update"])
        XCTAssertEqual(snapshot.checkedAt, Date(timeIntervalSince1970: 100))
    }

    @Test
    func resolveWorkspacePathFindsRepoRootFromExecutablePath() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let executableDirectoryURL = rootURL
            .appendingPathComponent(".run/AgentVersionBar.app/Contents/MacOS", isDirectory: true)

        try fileManager.createDirectory(at: executableDirectoryURL, withIntermediateDirectories: true)
        try Data().write(to: rootURL.appendingPathComponent("Package.swift"))

        defer {
            try? fileManager.removeItem(at: rootURL)
        }

        let workspacePath = AppModel.resolveWorkspacePath(
            executablePath: executableDirectoryURL.appendingPathComponent("AgentVersionBarApp").path,
            environment: ["PWD": "/tmp/not-the-workspace"],
            currentDirectoryPath: "/tmp/not-the-workspace",
            fileManager: fileManager
        )

        XCTAssertEqual(workspacePath, rootURL.path)
    }

    @Test
    func resolveWorkspacePathFallsBackToCurrentDirectory() throws {
        let fileManager = FileManager.default
        let currentDirectoryURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        try fileManager.createDirectory(at: currentDirectoryURL, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: currentDirectoryURL)
        }

        let workspacePath = AppModel.resolveWorkspacePath(
            executablePath: nil,
            environment: [:],
            currentDirectoryPath: currentDirectoryURL.path,
            fileManager: fileManager
        )

        XCTAssertEqual(workspacePath, currentDirectoryURL.path)
    }

    @Test
    func refreshUsesPackageManagerUpdateCommandForCodexCLI() {
        let service = VersionRefreshService(
            commandRunner: { command in
                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'codex'") == true {
                    return CommandOutput(exitCode: 1, stdout: "", stderr: "")
                }

                if command == ["/usr/bin/which", "codex"] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: "/usr/local/lib/node_modules/@openai/codex/bin/codex.js\n",
                        stderr: ""
                    )
                }

                if command == ["/usr/local/lib/node_modules/@openai/codex/bin/codex.js", "--version"] {
                    return CommandOutput(exitCode: 0, stdout: "codex-cli 0.116.0\n", stderr: "")
                }

                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'npm'") == true {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: """
                        __AGENT_VERSION_BAR_START__
                        /opt/homebrew/bin/npm
                        __AGENT_VERSION_BAR_END__
                        """,
                        stderr: ""
                    )
                }

                if command == ["/opt/homebrew/bin/npm", "view", "@openai/codex", "version"] {
                    return CommandOutput(exitCode: 0, stdout: "0.117.0\n", stderr: "")
                }

                return CommandOutput(exitCode: 1, stdout: "", stderr: "unexpected")
            },
            dateProvider: { Date(timeIntervalSince1970: 200) }
        )

        let snapshot = service.refresh(provider: .codexCli)

        XCTAssertEqual(snapshot.currentVersion, "0.116.0")
        XCTAssertEqual(snapshot.latestVersion, "0.117.0")
        XCTAssertEqual(snapshot.installSource, .npm)
        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.updateMethodTitle, "npm install -g @openai/codex@latest")
        XCTAssertEqual(snapshot.terminalUpdateCommand, ["npm", "install", "-g", "@openai/codex@latest"])
        XCTAssertEqual(snapshot.configPath, "\(NSHomeDirectory())/.codex/config.toml")
        XCTAssertEqual(snapshot.checkedAt, Date(timeIntervalSince1970: 200))
    }

    @Test
    func refreshPrefersInteractiveShellPathForCodexCLI() throws {
        let fileManager = FileManager.default
        let rootURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let targetURL = rootURL
            .appendingPathComponent("lib/node_modules/@openai/codex/bin", isDirectory: true)
            .appendingPathComponent("codex.js")
        let symlinkURL = rootURL
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("codex")

        try fileManager.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.createDirectory(at: symlinkURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "#!/usr/bin/env node\n".write(to: targetURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: targetURL.path)
        try fileManager.createSymbolicLink(at: symlinkURL, withDestinationURL: targetURL)
        defer { try? fileManager.removeItem(at: rootURL) }

        let service = VersionRefreshService(
            commandRunner: { command in
                if command.first == "/bin/zsh",
                   command.dropFirst().first == "-lic",
                   command.last?.contains("whence -p 'codex'") == true {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: """
                        shell startup noise
                        __AGENT_VERSION_BAR_START__
                        \(symlinkURL.path)
                        __AGENT_VERSION_BAR_END__
                        """,
                        stderr: ""
                    )
                }

                if command == [symlinkURL.path, "--version"] {
                    return CommandOutput(exitCode: 0, stdout: "codex-cli 0.120.0\n", stderr: "")
                }

                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'npm'") == true {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: """
                        __AGENT_VERSION_BAR_START__
                        /opt/homebrew/bin/npm
                        __AGENT_VERSION_BAR_END__
                        """,
                        stderr: ""
                    )
                }

                if command == ["/opt/homebrew/bin/npm", "view", "@openai/codex", "version"] {
                    return CommandOutput(exitCode: 0, stdout: "0.120.0\n", stderr: "")
                }

                return CommandOutput(exitCode: 1, stdout: "", stderr: "unexpected")
            },
            dateProvider: { Date(timeIntervalSince1970: 201) }
        )

        let snapshot = service.refresh(provider: .codexCli)

        XCTAssertEqual(snapshot.executablePath, symlinkURL.path)
        XCTAssertEqual(snapshot.resolvedExecutablePath, targetURL.path)
        XCTAssertEqual(snapshot.currentVersion, "0.120.0")
        XCTAssertEqual(snapshot.latestVersion, "0.120.0")
        XCTAssertEqual(snapshot.status, .upToDate)
    }

    @Test
    func refreshUsesGitHubReleaseForHermes() {
        let service = VersionRefreshService(
            commandRunner: { command in
                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'hermes'") == true {
                    return CommandOutput(exitCode: 1, stdout: "", stderr: "")
                }

                if command == ["/usr/bin/which", "hermes"] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: "/Users/test/.hermes/hermes-agent/venv/bin/hermes\n",
                        stderr: ""
                    )
                }

                if command == ["/Users/test/.hermes/hermes-agent/venv/bin/hermes", "--version"] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: "Hermes Agent v0.8.0 (2026.4.8)\nUp to date\n",
                        stderr: ""
                    )
                }

                if command == [
                    "/usr/bin/curl",
                    "-fsSL",
                    "https://api.github.com/repos/NousResearch/hermes-agent/releases/latest"
                ] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: #"{"tag_name":"v2026.4.8","name":"Hermes Agent v0.8.0 (v2026.4.8)"}"#,
                        stderr: ""
                    )
                }

                return CommandOutput(exitCode: 1, stdout: "", stderr: "unexpected")
            },
            dateProvider: { Date(timeIntervalSince1970: 250) }
        )

        let snapshot = service.refresh(provider: .hermes)

        XCTAssertEqual(snapshot.currentVersion, "0.8.0")
        XCTAssertEqual(snapshot.latestVersion, "0.8.0")
        XCTAssertEqual(snapshot.installSource, .nativeInstaller)
        XCTAssertEqual(snapshot.status, .upToDate)
        XCTAssertEqual(snapshot.updateMethodTitle, "/Users/test/.hermes/hermes-agent/venv/bin/hermes update")
        XCTAssertEqual(snapshot.terminalUpdateCommand, ["/Users/test/.hermes/hermes-agent/venv/bin/hermes", "update"])
        XCTAssertEqual(snapshot.configPath, "\(NSHomeDirectory())/.hermes/config.yaml")
        XCTAssertEqual(snapshot.checkedAt, Date(timeIntervalSince1970: 250))
    }

    @Test
    func refreshFallsBackToGitHubReleasePageForHermesWhenApiIsRateLimited() {
        let service = VersionRefreshService(
            commandRunner: { command in
                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'hermes'") == true {
                    return CommandOutput(exitCode: 1, stdout: "", stderr: "")
                }

                if command == ["/usr/bin/which", "hermes"] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: "/Users/test/.hermes/hermes-agent/venv/bin/hermes\n",
                        stderr: ""
                    )
                }

                if command == ["/Users/test/.hermes/hermes-agent/venv/bin/hermes", "--version"] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: "Hermes Agent v0.8.0 (2026.4.8)\nUp to date\n",
                        stderr: ""
                    )
                }

                if command == [
                    "/usr/bin/curl",
                    "-fsSL",
                    "https://api.github.com/repos/NousResearch/hermes-agent/releases/latest"
                ] {
                    return CommandOutput(exitCode: 56, stdout: "", stderr: "403")
                }

                if command == [
                    "/usr/bin/curl",
                    "-fsSL",
                    "https://github.com/NousResearch/hermes-agent/releases/latest"
                ] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: "<html><head><title>Release Hermes Agent v0.8.0 (v2026.4.8) · NousResearch/hermes-agent</title></head></html>",
                        stderr: ""
                    )
                }

                return CommandOutput(exitCode: 1, stdout: "", stderr: "unexpected")
            },
            dateProvider: { Date(timeIntervalSince1970: 251) }
        )

        let snapshot = service.refresh(provider: .hermes)

        XCTAssertEqual(snapshot.currentVersion, "0.8.0")
        XCTAssertEqual(snapshot.latestVersion, "0.8.0")
        XCTAssertEqual(snapshot.status, .upToDate)
    }

    @Test
    func refreshUsesHermesCommitLagWhenVersionOutputReportsUpdate() {
        let service = VersionRefreshService(
            commandRunner: { command in
                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'hermes'") == true {
                    return CommandOutput(exitCode: 1, stdout: "", stderr: "")
                }

                if command == ["/usr/bin/which", "hermes"] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: "/Users/test/.hermes/hermes-agent/venv/bin/hermes\n",
                        stderr: ""
                    )
                }

                if command == ["/Users/test/.hermes/hermes-agent/venv/bin/hermes", "--version"] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: """
                        Hermes Agent v0.11.0 (2026.4.23)
                        Update available: 5 commits behind — run 'hermes update'
                        """,
                        stderr: ""
                    )
                }

                return CommandOutput(exitCode: 1, stdout: "", stderr: "unexpected")
            },
            dateProvider: { Date(timeIntervalSince1970: 251) }
        )

        let snapshot = service.refresh(provider: .hermes)

        XCTAssertEqual(snapshot.currentVersion, "0.11.0")
        XCTAssertEqual(snapshot.latestVersion, "5 commits behind")
        XCTAssertEqual(snapshot.status, .updateAvailable)
    }

    @Test
    func refreshUsesPackageManagerUpdateCommandForPaperclip() {
        let service = VersionRefreshService(
            commandRunner: { command in
                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'paperclipai'") == true {
                    return CommandOutput(exitCode: 1, stdout: "", stderr: "")
                }

                if command == ["/usr/bin/which", "paperclipai"] {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: "/usr/local/lib/node_modules/paperclipai/dist/index.js\n",
                        stderr: ""
                    )
                }

                if command == ["/usr/local/lib/node_modules/paperclipai/dist/index.js", "--version"] {
                    return CommandOutput(exitCode: 0, stdout: "paperclipai 2026.402.0\n", stderr: "")
                }

                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'npm'") == true {
                    return CommandOutput(
                        exitCode: 0,
                        stdout: """
                        __AGENT_VERSION_BAR_START__
                        /opt/homebrew/bin/npm
                        __AGENT_VERSION_BAR_END__
                        """,
                        stderr: ""
                    )
                }

                if command == ["/opt/homebrew/bin/npm", "view", "paperclipai", "version"] {
                    return CommandOutput(exitCode: 0, stdout: "2026.403.0\n", stderr: "")
                }

                return CommandOutput(exitCode: 1, stdout: "", stderr: "unexpected")
            },
            dateProvider: { Date(timeIntervalSince1970: 275) }
        )

        let snapshot = service.refresh(provider: .paperclip)

        XCTAssertEqual(snapshot.currentVersion, "2026.402.0")
        XCTAssertEqual(snapshot.latestVersion, "2026.403.0")
        XCTAssertEqual(snapshot.installSource, .npm)
        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.updateMethodTitle, "npm install -g paperclipai@latest")
        XCTAssertEqual(snapshot.terminalUpdateCommand, ["npm", "install", "-g", "paperclipai@latest"])
        XCTAssertEqual(snapshot.configPath, "\(NSHomeDirectory())/.paperclip/instances/default/config.json")
        XCTAssertEqual(snapshot.checkedAt, Date(timeIntervalSince1970: 275))
    }

    @Test
    func refreshUsesSourceCheckoutForPaperclipWhenCliIsNotOnPath() throws {
        let fileManager = FileManager.default
        let originalHome = NSHomeDirectory()
        let homeURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repoURL = homeURL.appendingPathComponent("projects/paperclip", isDirectory: true)

        try fileManager.createDirectory(at: repoURL.appendingPathComponent("cli", isDirectory: true), withIntermediateDirectories: true)
        try "{}\n".write(to: repoURL.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        try "{}\n".write(to: repoURL.appendingPathComponent("cli/package.json"), atomically: true, encoding: .utf8)

        setenv("HOME", homeURL.path, 1)
        defer {
            setenv("HOME", originalHome, 1)
            try? fileManager.removeItem(at: homeURL)
        }

        let service = VersionRefreshService(
            commandRunner: { command in
                if command.first == "/bin/zsh", command.dropFirst().first == "-lic", command.last?.contains("whence -p 'paperclipai'") == true {
                    return CommandOutput(exitCode: 1, stdout: "", stderr: "")
                }

                if command == ["/usr/bin/which", "paperclipai"] {
                    return CommandOutput(exitCode: 1, stdout: "", stderr: "not found")
                }

                if command == ["/bin/zsh", "-lc", "command -v paperclipai 2>/dev/null"] {
                    return CommandOutput(exitCode: 1, stdout: "", stderr: "")
                }

                if command == ["pnpm", "--dir", repoURL.path, "paperclipai", "--version"] {
                    return CommandOutput(exitCode: 0, stdout: "0.3.1\n", stderr: "")
                }

                if command == ["git", "-C", repoURL.path, "rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"] {
                    return CommandOutput(exitCode: 0, stdout: "origin/master\n", stderr: "")
                }

                if command == ["git", "-C", repoURL.path, "rev-list", "--count", "HEAD..@{upstream}"] {
                    return CommandOutput(exitCode: 0, stdout: "7\n", stderr: "")
                }

                return CommandOutput(exitCode: 1, stdout: "", stderr: "unexpected")
            },
            dateProvider: { Date(timeIntervalSince1970: 280) }
        )

        let snapshot = service.refresh(provider: .paperclip)

        XCTAssertEqual(snapshot.executablePath, repoURL.path)
        XCTAssertEqual(snapshot.installSource, .sourceCheckout)
        XCTAssertEqual(snapshot.installMethodTitle, "Source checkout")
        XCTAssertEqual(snapshot.currentVersion, "0.3.1")
        XCTAssertEqual(snapshot.latestVersion, "7 commits behind")
        XCTAssertEqual(snapshot.status, .updateAvailable)
        XCTAssertEqual(snapshot.updateMethodTitle, "Manual update")
        XCTAssertNil(snapshot.terminalUpdateCommand)
    }

    @Test
    func sourceCheckoutStatusUsesCommitLagInsteadOfVersionComparison() {
        let snapshot = ProviderVersionSnapshot(
            provider: .paperclip,
            currentVersion: "0.3.1",
            latestVersion: "0 commits behind",
            executablePath: "/Users/test/projects/paperclip",
            resolvedExecutablePath: "/Users/test/projects/paperclip",
            configPath: "\(NSHomeDirectory())/.paperclip/instances/default/config.json",
            installSource: .sourceCheckout,
            installMethodTitle: "Source checkout",
            updateMethodTitle: "Manual update",
            terminalUpdateCommand: nil,
            isInstalled: true,
            checkedAt: Date(timeIntervalSince1970: 281),
            errorDescription: nil
        )

        XCTAssertEqual(snapshot.status, .upToDate)
        XCTAssertEqual(snapshot.latestTitle, "0 commits behind")
        XCTAssertFalse(snapshot.canOpenChangelog)
    }

    @Test
    func snapshotDoesNotOfferUpdateWhenInstalledVersionIsNewerThanAvailableVersion() {
        let snapshot = ProviderVersionSnapshot(
            provider: .claudeCode,
            currentVersion: "2.1.119",
            latestVersion: "2.1.112",
            executablePath: "/usr/local/bin/claude",
            resolvedExecutablePath: "/usr/local/lib/node_modules/@anthropic-ai/claude-code/cli.js",
            configPath: "\(NSHomeDirectory())/.claude/settings.json",
            installSource: .npm,
            installMethodTitle: "npm global package (@anthropic-ai/claude-code)",
            updateMethodTitle: "npm install -g @anthropic-ai/claude-code@latest",
            terminalUpdateCommand: ["npm", "install", "-g", "@anthropic-ai/claude-code@latest"],
            isInstalled: true,
            checkedAt: Date(timeIntervalSince1970: 282),
            errorDescription: nil
        )

        XCTAssertEqual(snapshot.status, .upToDate)
        XCTAssertEqual(snapshot.latestTitle, "2.1.119")
        XCTAssertFalse(snapshot.isChangelogAvailable)
    }

    @Test
    func providersExposeOfficialChangelogURLs() {
        XCTAssertEqual(ProviderKind.openClaw.officialChangelogURL?.absoluteString, "https://github.com/clawdbot/clawdbot/releases")
        XCTAssertEqual(ProviderKind.openCode.officialChangelogURL?.absoluteString, "https://opencode.ai/changelog")
        XCTAssertEqual(ProviderKind.claudeCode.officialChangelogURL?.absoluteString, "https://github.com/anthropics/claude-code/releases")
        XCTAssertEqual(ProviderKind.codexCli.officialChangelogURL?.absoluteString, "https://github.com/openai/codex/releases")
        XCTAssertEqual(ProviderKind.hermes.officialChangelogURL?.absoluteString, "https://github.com/NousResearch/hermes-agent/releases")
        XCTAssertEqual(ProviderKind.paperclip.officialChangelogURL?.absoluteString, "https://github.com/paperclipai/paperclip/releases")
    }

    @Test
    func snapshotCanOpenChangelogWhenVersionsAreKnown() {
        let updateSnapshot = ProviderVersionSnapshot(
            provider: .codexCli,
            currentVersion: "0.116.0",
            latestVersion: "0.117.0",
            executablePath: "/usr/local/bin/codex",
            resolvedExecutablePath: "/usr/local/bin/codex",
            configPath: "\(NSHomeDirectory())/.codex/config.toml",
            installSource: .npm,
            installMethodTitle: "npm global package (@openai/codex)",
            updateMethodTitle: "npm install -g @openai/codex@latest",
            terminalUpdateCommand: ["npm", "install", "-g", "@openai/codex@latest"],
            isInstalled: true,
            checkedAt: Date(timeIntervalSince1970: 300),
            errorDescription: nil
        )

        let upToDateSnapshot = ProviderVersionSnapshot(
            provider: .codexCli,
            currentVersion: "0.117.0",
            latestVersion: "0.117.0",
            executablePath: "/usr/local/bin/codex",
            resolvedExecutablePath: "/usr/local/bin/codex",
            configPath: "\(NSHomeDirectory())/.codex/config.toml",
            installSource: .npm,
            installMethodTitle: "npm global package (@openai/codex)",
            updateMethodTitle: "npm install -g @openai/codex@latest",
            terminalUpdateCommand: ["npm", "install", "-g", "@openai/codex@latest"],
            isInstalled: true,
            checkedAt: Date(timeIntervalSince1970: 300),
            errorDescription: nil
        )
        let currentSnapshot = ProviderVersionSnapshot(
            provider: .codexCli,
            currentVersion: "0.117.0",
            latestVersion: nil,
            executablePath: "/usr/local/bin/codex",
            resolvedExecutablePath: "/usr/local/bin/codex",
            configPath: "\(NSHomeDirectory())/.codex/config.toml",
            installSource: .npm,
            installMethodTitle: "npm global package (@openai/codex)",
            updateMethodTitle: "npm install -g @openai/codex@latest",
            terminalUpdateCommand: ["npm", "install", "-g", "@openai/codex@latest"],
            isInstalled: true,
            checkedAt: Date(timeIntervalSince1970: 300),
            errorDescription: nil
        )

        XCTAssertTrue(updateSnapshot.isChangelogAvailable)
        XCTAssertEqual(updateSnapshot.changelogURL, ProviderKind.codexCli.officialChangelogURL)
        XCTAssertTrue(upToDateSnapshot.canOpenChangelog)
        XCTAssertEqual(upToDateSnapshot.changelogSourceURL, ProviderKind.codexCli.officialChangelogURL)
        XCTAssertFalse(currentSnapshot.canOpenChangelog)
    }
}

private func XCTAssertEqual<T: Equatable>(
    _ lhs: @autoclosure () -> T,
    _ rhs: @autoclosure () -> T
) {
    #expect(lhs() == rhs())
}

private func XCTAssertTrue(_ condition: @autoclosure () -> Bool) {
    #expect(condition())
}

private func XCTAssertFalse(_ condition: @autoclosure () -> Bool) {
    #expect(condition() == false)
}

private func XCTAssertNil<T>(_ value: @autoclosure () -> T?) {
    #expect(value() == nil)
}
