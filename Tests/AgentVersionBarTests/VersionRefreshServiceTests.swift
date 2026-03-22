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

        #expect(payload == #"{"version":{"current":"1.2.0","latest":"1.3.0"}}"#)
    }

    @Test
    func detectInstallSourceUnderstandsPackageManagers() {
        #expect(
            VersionParsing.detectInstallSource(
                executablePath: "/opt/homebrew/Cellar/opencode/0.9.0/bin/opencode",
                provider: .openCode
            ) == .homebrew
        )
        #expect(
            VersionParsing.detectInstallSource(
                executablePath: "/usr/local/lib/node_modules/openclaw/bin/openclaw.js",
                provider: .openClaw
            ) == .npm
        )
        #expect(
            VersionParsing.detectInstallSource(
                executablePath: "/Users/test/Library/pnpm/global/5/.pnpm/opencode-ai@0.9.0/node_modules/opencode-ai/bin/opencode",
                provider: .openCode
            ) == .pnpm
        )
        #expect(
            VersionParsing.detectInstallSource(
                executablePath: "/Users/test/.npm/_npx/hash/node_modules/opencode-ai/bin/opencode",
                provider: .openCode
            ) == .npm
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

        #expect(VersionParsing.latestVersionFromBrewInfo(data: formulaData) == "0.9.2")
        #expect(VersionParsing.latestVersionFromBrewInfo(data: caskData) == "1.0.16")
    }

    @Test
    func refreshUsesOpenClawStatusPayloadBeforeVersionCommand() {
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

        #expect(snapshot.currentVersion == "1.4.0")
        #expect(snapshot.latestVersion == "1.5.0")
        #expect(snapshot.status == .updateAvailable)
        #expect(snapshot.executablePath == "/usr/local/bin/openclaw")
        #expect(snapshot.resolvedExecutablePath?.contains("openclaw") == true)
        #expect(snapshot.terminalUpdateCommand == ["/usr/local/bin/openclaw", "update"])
        #expect(snapshot.checkedAt == Date(timeIntervalSince1970: 100))
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

        #expect(workspacePath == rootURL.path)
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

        #expect(workspacePath == currentDirectoryURL.path)
    }
}
