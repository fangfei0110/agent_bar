import Foundation
import Testing

@testable import AgentVersionBarApp

@Suite("ChangelogWindowModelTests")
struct ChangelogWindowModelTests {
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
                load: { request in
                    #expect(request.provider == .codexCli)
                    #expect(request.currentVersion == "0.116.0")
                    #expect(request.latestVersion == "0.117.0")
                    return ChangelogContent(
                        request: request,
                        summary: "Added sandbox UX improvements.",
                        originalContent: "# 0.117.0\n\n- Added sandbox UX improvements.",
                        summaryErrorDescription: nil
                    )
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
                load: { request in
                    ChangelogContent(
                        request: request,
                        summary: nil,
                        originalContent: "## 1.1.0\n\n- Improved tools.",
                        summaryErrorDescription: "Summary unavailable"
                    )
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
    func openDoesNothingWhenSnapshotHasNoAvailableChangelog() async {
        let snapshot = ProviderVersionSnapshot(
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

        let model = ChangelogWindowModel(
            service: ChangelogService(
                load: { _ in
                    Issue.record("Service should not be called")
                    return ChangelogContent(
                        request: ChangelogRequest(
                            provider: .codexCli,
                            currentVersion: "0.117.0",
                            latestVersion: "0.117.0",
                            sourceURL: URL(string: "https://github.com/openai/codex/releases")!
                        )!,
                        summary: nil,
                        originalContent: nil,
                        summaryErrorDescription: nil
                    )
                }
            )
        )

        model.open(snapshot: snapshot)
        await model.waitForLoadForTesting()

        #expect(model.state == ChangelogViewState.idle)
    }
}
