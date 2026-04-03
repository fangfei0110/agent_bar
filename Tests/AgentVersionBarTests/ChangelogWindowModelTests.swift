import Foundation
import Testing

@testable import AgentVersionBarApp

@Suite("ChangelogWindowModelTests")
struct ChangelogWindowModelTests {
    private struct AsyncGate: Sendable {
        let stream: AsyncStream<Void>
        let continuation: AsyncStream<Void>.Continuation

        init() {
            var continuation: AsyncStream<Void>.Continuation?
            self.stream = AsyncStream<Void> { continuation = $0 }
            self.continuation = continuation!
        }

        func wait() async {
            for await _ in stream {
                break
            }
        }

        func open() {
            continuation.yield(())
            continuation.finish()
        }
    }

    @Test
    @MainActor
    func openLoadsSummaryAndOriginalContent() async {
        let expectedSnapshot = ProviderVersionSnapshot(
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

        let model = ChangelogWindowModel(
            service: ChangelogService(
                extract: { request in
                    #expect(request.provider == .codexCli)
                    #expect(request.currentVersion == "0.116.0")
                    #expect(request.latestVersion == "0.117.0")
                    return "# 0.117.0\n\n- Added sandbox UX improvements."
                },
                summarize: { _, _ in
                    "Added sandbox UX improvements."
                }
            )
        )

        model.open(snapshot: expectedSnapshot)
        await model.waitForLoadForTesting()

        #expect(model.state == .loaded(
            ChangelogContent(
                request: ChangelogRequest(
                    provider: .codexCli,
                    currentVersion: "0.116.0",
                    latestVersion: "0.117.0",
                    sourceURL: URL(string: "https://github.com/openai/codex/releases")!
                )!,
                summary: "Added sandbox UX improvements.",
                originalContent: "# 0.117.0\n\n- Added sandbox UX improvements.",
                summaryErrorDescription: nil
            )
        ))
    }

    @Test
    @MainActor
    func openKeepsOriginalContentWhenSummaryFails() async {
        let snapshot = ProviderVersionSnapshot(
            provider: .claudeCode,
            currentVersion: "1.0.0",
            latestVersion: "1.1.0",
            executablePath: "/usr/local/bin/claude",
            resolvedExecutablePath: "/usr/local/bin/claude",
            configPath: "\(NSHomeDirectory())/.claude/settings.json",
            installSource: .npm,
            installMethodTitle: "npm global package (@anthropic-ai/claude-code)",
            updateMethodTitle: "claude update",
            terminalUpdateCommand: ["/usr/local/bin/claude", "update"],
            isInstalled: true,
            checkedAt: Date(timeIntervalSince1970: 300),
            errorDescription: nil
        )

        let model = ChangelogWindowModel(
            service: ChangelogService(
                extract: { _ in "## 1.1.0\n\n- Improved tools." },
                summarize: { _, _ in
                    struct SummaryFailure: LocalizedError {
                        var errorDescription: String? { "Summary unavailable" }
                    }
                    throw SummaryFailure()
                }
            )
        )

        model.open(snapshot: snapshot)
        await model.waitForLoadForTesting()

        guard case let .loaded(content) = model.state else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(content.summary == nil)
        #expect(content.originalContent == "## 1.1.0\n\n- Improved tools.")
        #expect(content.summaryErrorDescription == "Summary unavailable")
    }

    @Test
    @MainActor
    func openWithoutVersionsAndNoCacheShowsUnavailableState() async {
        let snapshot = ProviderVersionSnapshot(
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

        let model = ChangelogWindowModel(
            service: ChangelogService(
                extract: { _ in
                    Issue.record("Service should not be called")
                    return ""
                },
                summarize: { _, _ in
                    Issue.record("Service should not be called")
                    return ""
                }
            )
        )

        model.open(snapshot: snapshot)
        await model.waitForLoadForTesting()

        #expect(model.state == ChangelogViewState.unavailable(.codexCli))
    }

    @Test
    @MainActor
    func openingSnapshotWithoutUpdateLoadsFreshChangelog() async {
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
        let extractCalls = Locked<Int>(0)
        let summarizeCalls = Locked<Int>(0)

        let model = ChangelogWindowModel(
            service: ChangelogService(
                extract: { _ in
                    await extractCalls.increment()
                    return "## 0.117.0"
                },
                summarize: { _, _ in
                    await summarizeCalls.increment()
                    return "中文总结"
                }
            )
        )

        model.open(snapshot: upToDateSnapshot)
        await model.waitForLoadForTesting()

        guard case let .loaded(content) = model.state else {
            Issue.record("Expected loaded state")
            return
        }

        #expect(content.request.provider == .codexCli)
        #expect(content.request.currentVersion == "0.117.0")
        #expect(content.request.latestVersion == "0.117.0")
        #expect(content.summary == "中文总结")
        #expect(await extractCalls.value == 1)
        #expect(await summarizeCalls.value == 1)
        #expect(model.hasCachedContent(for: .codexCli) == true)
    }

    @Test
    @MainActor
    func reopeningSameVersionUsesInMemoryCache() async {
        let snapshot = ProviderVersionSnapshot(
            provider: .openCode,
            currentVersion: "1.3.0",
            latestVersion: "1.3.2",
            executablePath: "/usr/local/bin/opencode",
            resolvedExecutablePath: "/usr/local/bin/opencode",
            configPath: "\(NSHomeDirectory())/.config/opencode/opencode.json",
            installSource: .npm,
            installMethodTitle: "npm global package (opencode-ai)",
            updateMethodTitle: "opencode upgrade",
            terminalUpdateCommand: ["/usr/local/bin/opencode", "upgrade"],
            isInstalled: true,
            checkedAt: Date(timeIntervalSince1970: 400),
            errorDescription: nil
        )
        let extractCalls = Locked<Int>(0)
        let summarizeCalls = Locked<Int>(0)

        let model = ChangelogWindowModel(
            service: ChangelogService(
                extract: { _ in
                    await extractCalls.increment()
                    return "# Changelog\n[v1.3.2](https://example.com/v1.3.2)\n- Added heap snapshots."
                },
                summarize: { _, _ in
                    await summarizeCalls.increment()
                    return "中文总结"
                }
            )
        )

        model.open(snapshot: snapshot)
        await model.waitForLoadForTesting()
        model.open(snapshot: snapshot)
        await model.waitForLoadForTesting()

        #expect(await extractCalls.value == 1)
        #expect(await summarizeCalls.value == 1)
    }

    @Test
    @MainActor
    func originalContentAppearsBeforeSummaryCompletes() async {
        let snapshot = ProviderVersionSnapshot(
            provider: .openCode,
            currentVersion: "1.3.0",
            latestVersion: "1.3.2",
            executablePath: "/usr/local/bin/opencode",
            resolvedExecutablePath: "/usr/local/bin/opencode",
            configPath: "\(NSHomeDirectory())/.config/opencode/opencode.json",
            installSource: .npm,
            installMethodTitle: "npm global package (opencode-ai)",
            updateMethodTitle: "opencode upgrade",
            terminalUpdateCommand: ["/usr/local/bin/opencode", "upgrade"],
            isInstalled: true,
            checkedAt: Date(timeIntervalSince1970: 400),
            errorDescription: nil
        )
        let extractGate = AsyncGate()
        let summarizeGate = AsyncGate()

        let model = ChangelogWindowModel(
            service: ChangelogService(
                extract: { _ in
                    await extractGate.wait()
                    return "# Changelog\n[v1.3.2](https://example.com/v1.3.2)\n- Added heap snapshots."
                },
                summarize: { _, _ in
                    await summarizeGate.wait()
                    return "中文总结"
                }
            )
        )

        model.open(snapshot: snapshot)
        await Task.yield()

        if case let .loading(request, phase) = model.state {
            #expect(request.provider == ProviderKind.openCode)
            #expect(phase == ChangelogLoadingPhase.fetching)
        } else {
            Issue.record("Expected fetching loading state")
        }

        extractGate.open()
        for _ in 0..<20 {
            if case .showingOriginal = model.state {
                break
            }
            await Task.yield()
        }

        if case let .showingOriginal(content) = model.state {
            #expect(content.request.provider == ProviderKind.openCode)
            #expect(content.originalContent == "# Changelog\n[v1.3.2](https://example.com/v1.3.2)\n- Added heap snapshots.")
            #expect(content.summary == nil)
            #expect(content.summaryErrorDescription == nil)
        } else {
            Issue.record("Expected original content while summary is still loading")
        }

        summarizeGate.open()
        await model.waitForLoadForTesting()

        if case .loaded = model.state {
        } else {
            Issue.record("Expected loaded state")
        }
    }
}

private actor Locked<Value: Sendable> {
    private(set) var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

private extension Locked where Value == Int {
    func increment() {
        value += 1
    }
}
