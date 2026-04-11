import Foundation
import XCTest

@testable import AgentVersionBarApp

final class VersionRefreshServiceTests: XCTestCase {
    func testExtractJSONPayloadIgnoresNoise() {
        let payload = VersionParsing.extractJSONPayload(from: """
        booting
        {"version":{"current":"1.2.0","latest":"1.3.0"}}
        trailing line
        """)

        XCTAssertEqual(payload, #"{"version":{"current":"1.2.0","latest":"1.3.0"}}"#)
    }

    func testDetectInstallSourceUnderstandsPackageManagers() {
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
    }

    func testLatestVersionFromBrewInfoSupportsFormulaeAndCasks() {
        let formulaData = Data("""
        {"formulae":[{"versions":{"stable":"0.9.2"}}],"casks":[]}
        """.utf8)
        let caskData = Data("""
        {"formulae":[],"casks":[{"version":"1.0.16"}]}
        """.utf8)

        XCTAssertEqual(VersionParsing.latestVersionFromBrewInfo(data: formulaData), "0.9.2")
        XCTAssertEqual(VersionParsing.latestVersionFromBrewInfo(data: caskData), "1.0.16")
    }

    func testRefreshUsesOpenClawStatusPayloadBeforeVersionCommand() {
        let service = VersionRefreshService(
            commandRunner: { command in
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

    func testResolveWorkspacePathFindsRepoRootFromExecutablePath() throws {
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

    func testResolveWorkspacePathFallsBackToCurrentDirectory() throws {
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

    func testRefreshUsesPackageManagerUpdateCommandForCodexCLI() {
        let service = VersionRefreshService(
            commandRunner: { command in
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

                if command == ["npm", "view", "@openai/codex", "version"] {
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

    func testRefreshUsesGitHubReleaseForHermes() {
        let service = VersionRefreshService(
            commandRunner: { command in
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

    func testProvidersExposeOfficialChangelogURLs() {
        XCTAssertEqual(ProviderKind.openClaw.officialChangelogURL?.absoluteString, "https://github.com/clawdbot/clawdbot/releases")
        XCTAssertEqual(ProviderKind.openCode.officialChangelogURL?.absoluteString, "https://opencode.ai/changelog")
        XCTAssertEqual(ProviderKind.claudeCode.officialChangelogURL?.absoluteString, "https://github.com/anthropics/claude-code/releases")
        XCTAssertEqual(ProviderKind.codexCli.officialChangelogURL?.absoluteString, "https://github.com/openai/codex/releases")
        XCTAssertEqual(ProviderKind.hermes.officialChangelogURL?.absoluteString, "https://github.com/NousResearch/hermes-agent/releases")
    }

    func testSnapshotCanOpenChangelogWhenVersionsAreKnown() {
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
