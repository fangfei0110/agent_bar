import Foundation
import Testing
@testable import AgentVersionBarApp

@Suite("Command execution regressions")
struct CommandExecutorTests {
    @Test func drainsLargeStdoutAndStderr() {
        let output = CommandExecutor.run(["/bin/sh", "-c", "/usr/bin/head -c 1048576 /dev/zero; /usr/bin/head -c 1048576 /dev/zero >&2"], timeout: 5)
        #expect(output.exitCode == 0)
        #expect(output.stdout.utf8.count == 1_048_576)
        #expect(output.stderr.utf8.count == 1_048_576)
    }

    @Test func pumpsLargeStdinWhileReadingOutput() {
        let input = String(repeating: "input\n", count: 200_000)
        let output = CommandExecutor.run(["/bin/cat"], stdin: input, timeout: 5)
        #expect(output.exitCode == 0)
        #expect(output.stdout == input)
    }

    @Test func handlesEarlyStdinCloseAndEmptyInput() {
        let earlyExit = CommandExecutor.run(["/usr/bin/true"], stdin: String(repeating: "x", count: 1_048_576))
        #expect(earlyExit.exitCode == 0)
        let eof = CommandExecutor.run(["/bin/cat"])
        #expect(eof.exitCode == 0)
        #expect(eof.stdout.isEmpty)
    }

    @Test func timeoutKillsProcessIgnoringTermination() {
        let start = ProcessInfo.processInfo.systemUptime
        let output = CommandExecutor.run(["/bin/sh", "-c", "trap '' TERM; while :; do :; done"], timeout: 0.1)
        #expect(output.exitCode == 124)
        #expect(output.stderr.contains("timed out"))
        #expect(ProcessInfo.processInfo.systemUptime - start < 2)
    }

    @Test func cancellationStopsRunningCommand() async throws {
        let task = Task { await CommandExecutor.runAsync(["/bin/sleep", "20"], timeout: 30) }
        try await Task.sleep(for: .milliseconds(50))
        task.cancel()
        let output = await task.value
        #expect(output.exitCode == 130)
    }

    @Test func absolutePackageManagersReceiveLookupTimeouts() {
        for path in ["npm", "/opt/homebrew/bin/npm", "/Users/test/.nvm/versions/node/v24/bin/npm"] {
            #expect(VersionRefreshService.commandTimeout(for: [path, "view", "@openai/codex", "version"]) == 15)
        }
        #expect(VersionRefreshService.commandTimeout(for: ["/opt/homebrew/bin/brew", "info", "--json=v2"]) == 4)
    }

    @Test func changelogProbeAndExecutionShareGuiEnvironment() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bin = root.appendingPathComponent(".local/bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // A private fixture avoids invoking the user's real summarizer or any remote service.
        let executable = bin.appendingPathComponent("summarize")
        try "#!/bin/sh\nprintf 'fixture changelog'\n".write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let environment = ["HOME": root.path, "PATH": "/usr/bin:/bin"]
        let loader = LiveChangelogLoader { command, stdin in
            // Use a unique name: installed Homebrew tools must not shadow this fixture.
            let name = "agent-bar-test-summarize-\(root.lastPathComponent)"
            let fixtureCommand = command.map { $0 == "summarize" ? name : $0 }
            return CommandExecutor.run(fixtureCommand, stdin: stdin, environment: environment)
        }
        let unique = bin.appendingPathComponent("agent-bar-test-summarize-\(root.lastPathComponent)")
        try FileManager.default.moveItem(at: executable, to: unique)
        let request = ChangelogRequest(provider: .codexCli, currentVersion: "1.0.0", latestVersion: "1.1.0", sourceURL: URL(string: "https://example.com"))!
        #expect(try await loader.extractOriginalContent(for: request) == "fixture changelog")
    }
}

@Suite("App state regressions")
@MainActor
struct AppStateRegressionTests {
    @Test func missingRefreshPreferenceDefaultsToFiveMinutesButPreservesOff() {
        let suite = "AgentBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(AppModel(defaults: defaults, autoload: false).refreshInterval == .fiveMinutes)
        defaults.set(0, forKey: "autoRefreshIntervalSeconds")
        #expect(AppModel(defaults: defaults, autoload: false).refreshInterval == .off)
    }

    @Test(arguments: AutoUpdateBehavior.allCases)
    func automaticUpdatesRespectPreferenceAndDoNotRepeat(behavior: AutoUpdateBehavior) async throws {
        let suite = "AgentBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(atPath: root.appendingPathComponent("npm").path, withDestinationPath: "/usr/bin/true")
        let snapshot = fixtureSnapshot(.codexCli, executable: root.appendingPathComponent("codex").path)
        let counter = RegressionCounter()
        let model = AppModel(defaults: defaults, autoload: false, refreshSnapshots: { [snapshot] }, automaticUpdater: { command in
            #expect(command == [root.appendingPathComponent("npm").path, "install", "-g", "@openai/codex@latest"])
            await counter.increment()
            return CommandOutput(exitCode: 1, stdout: "", stderr: "fixture failure")
        })
        model.autoUpdateBehavior = behavior
        await model.refresh()
        await model.refresh()
        #expect(await counter.value == (behavior == .packageManagerWhenPossible ? 1 : 0))
        #expect(model.updatingProviders.isEmpty)
        #expect(!model.isRefreshing)
        #expect(model.updateErrors[.codexCli] == (behavior == .packageManagerWhenPossible ? "fixture failure" : nil))
    }

    @Test func successfulAutoUpdateRefreshesInstalledVersion() async throws {
        let suite = "AgentBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createSymbolicLink(atPath: root.appendingPathComponent("npm").path, withDestinationPath: "/usr/bin/true")
        let old = fixtureSnapshot(.codexCli, executable: root.appendingPathComponent("codex").path)
        let updated = fixtureSnapshot(.codexCli, executable: old.executablePath!, current: "1.1.0")
        let calls = RegressionCounter()
        let model = AppModel(defaults: defaults, autoload: false, refreshSnapshots: {
            await calls.increment()
            return await calls.value == 1 ? [old] : [updated]
        }, automaticUpdater: { _ in CommandOutput(exitCode: 0, stdout: "", stderr: "") })
        model.autoUpdateBehavior = .packageManagerWhenPossible
        await model.refresh()
        #expect(model.snapshots.first?.status == .upToDate)
        #expect(await calls.value == 2)
    }

    @Test func automaticUpdatesExcludeUnmanagedAndMissingManagerInstalls() {
        #expect(fixtureSnapshot(.codexCli, executable: "/missing/codex").automaticUpdateCommand == nil)
        #expect(fixtureSnapshot(.hermes, source: .nativeInstaller).automaticUpdateCommand == nil)
        #expect(fixtureSnapshot(.openCode, source: .directBinary).automaticUpdateCommand == nil)
    }

    @Test func cachedSelectionCancelsUnrelatedPendingSummary() async throws {
        let started = RegressionGate()
        let finish = RegressionGate()
        let returned = RegressionGate()
        let model = ChangelogWindowModel(service: ChangelogService(extract: { _ in "Original" }, summarize: { request, _ in
            if request.provider == .hermes {
                await started.open()
                await finish.wait()
                await returned.open()
            }
            return request.provider.displayName
        }))
        model.open(snapshot: fixtureSnapshot(.codexCli))
        await model.waitForLoadForTesting()
        let cached = model.state
        model.open(snapshot: fixtureSnapshot(.hermes))
        await started.wait()
        model.open(snapshot: fixtureSnapshot(.codexCli))
        #expect(model.state == cached)
        await finish.open()
        await returned.wait()
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.state == cached)
    }
}

private func fixtureSnapshot(_ provider: ProviderKind, executable: String = "/missing/cli", source: InstallSource = .npm, current: String = "1.0.0") -> ProviderVersionSnapshot {
    ProviderVersionSnapshot(provider: provider, currentVersion: current, latestVersion: "1.1.0", executablePath: executable,
                            resolvedExecutablePath: executable, configPath: "/tmp/config", installSource: source,
                            installMethodTitle: source.displayTitle, updateMethodTitle: "Update", terminalUpdateCommand: nil,
                            isInstalled: true, checkedAt: Date(), errorDescription: nil)
}

private actor RegressionCounter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor RegressionGate {
    private var isOpen = false
    private var continuations: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { continuations.append($0) }
    }
    func open() {
        isOpen = true
        for continuation in continuations { continuation.resume() }
        continuations.removeAll()
    }
}
