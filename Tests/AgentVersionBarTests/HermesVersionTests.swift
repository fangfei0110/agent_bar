import Foundation
import Testing
@testable import AgentVersionBarApp

@Suite("Hermes version regressions")
struct HermesVersionTests {
    @Test func timeoutPreservesBannerAndUsesReleaseFallback() {
        let fixture = HermesCommandFixture(output: CommandOutput(
            exitCode: 124,
            stdout: "Hermes Agent v0.21.0 (2026.8.31)\nPython: 3.11.15\n",
            stderr: "Command timed out after 6 seconds"
        ))
        let snapshot = fixture.refresh()
        #expect(snapshot.currentVersion == "0.21.0")
        #expect(snapshot.latestVersion == "0.22.0")
        #expect(snapshot.status == .updateAvailable)
        #expect(snapshot.errorDescription == nil)
        #expect(fixture.versionCalls == 1)
    }

    @Test func commitLagIsReadFromTheSameInvocation() {
        let fixture = HermesCommandFixture(output: CommandOutput(
            exitCode: 0,
            stdout: "Hermes Agent v0.21.0 (2026.8.31)\nUpdate available: 21 commits behind\n",
            stderr: ""
        ))
        let snapshot = fixture.refresh()
        #expect(snapshot.currentVersion == "0.21.0")
        #expect(snapshot.latestVersion == "21 commits behind")
        #expect(fixture.versionCalls == 1)
    }

    @Test func timeoutWithoutBannerIsNotRetriedOrMistakenForPythonVersion() {
        let fixture = HermesCommandFixture(output: CommandOutput(
            exitCode: 124, stdout: "Python: 3.11.15\nOpenAI SDK: 2.24.0\n", stderr: "timeout"
        ))
        let snapshot = fixture.refresh()
        #expect(snapshot.isInstalled)
        #expect(snapshot.currentVersion == nil)
        #expect(snapshot.errorDescription == "Hermes version check timed out")
        #expect(fixture.versionCalls == 1)
    }

    @Test func cancelledCommandDoesNotPublishPartialVersion() {
        let fixture = HermesCommandFixture(output: CommandOutput(
            exitCode: 130, stdout: "Hermes Agent v0.21.0\n", stderr: "cancelled"
        ))
        #expect(fixture.refresh().currentVersion == nil)
        #expect(fixture.versionCalls == 1)
    }

    @Test func pythonUnbufferingIsLimitedToHermesVersionProbe() {
        let base = ["PATH": "/usr/bin:/bin", "PYTHONUNBUFFERED": "0"]
        for path in ["hermes", "/Users/test/.local/bin/hermes"] {
            #expect(VersionRefreshService.processEnvironment(for: [path, "--version"], baseEnvironment: base)["PYTHONUNBUFFERED"] == "1")
        }
        for command in [["hermes", "update"], ["codex", "--version"], ["python3", "--version"]] {
            #expect(VersionRefreshService.processEnvironment(for: command, baseEnvironment: base)["PYTHONUNBUFFERED"] == "0")
        }
    }

    @Test func timeoutKeepsAlreadyWrittenBanner() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("hermes")
        try "#!/bin/sh\nprintf 'Hermes Agent v0.21.0\\n'\nexec /bin/sleep 5\n"
            .write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let output = CommandExecutor.run([executable.path, "--version"], timeout: 1)
        #expect(output.exitCode == 124)
        #expect(VersionParsing.extractHermesVersion(from: output.stdout) == "0.21.0", "stdout: \(output.stdout); stderr: \(output.stderr)")
    }
}

private final class HermesCommandFixture: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0
    private let output: CommandOutput
    private let executable = "/Users/test/.hermes/hermes-agent/venv/bin/hermes"

    init(output: CommandOutput) { self.output = output }

    var versionCalls: Int { lock.withLock { calls } }

    func refresh() -> ProviderVersionSnapshot {
        VersionRefreshService(commandRunner: { self.run($0) }, dateProvider: { Date(timeIntervalSince1970: 1) })
            .refresh(provider: .hermes)
    }

    private func run(_ command: [String]) -> CommandOutput {
        if command == ["/usr/bin/which", "hermes"] {
            return CommandOutput(exitCode: 0, stdout: executable, stderr: "")
        }
        if command == [executable, "--version"] {
            lock.withLock { calls += 1 }
            return output
        }
        if command.contains("https://api.github.com/repos/NousResearch/hermes-agent/releases/latest") {
            return CommandOutput(exitCode: 0, stdout: #"{"tag_name":"v0.22.0","name":"Hermes Agent v0.22.0"}"#, stderr: "")
        }
        return CommandOutput(exitCode: 1, stdout: "", stderr: "unexpected command")
    }
}
