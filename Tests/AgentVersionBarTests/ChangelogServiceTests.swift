import Foundation
import Testing

@testable import AgentVersionBarApp

@Suite("ChangelogServiceTests")
struct ChangelogServiceTests {
    @Test
    func latestVersionSectionsOnlyKeepNewestTwoVersions() {
        let markdown = """
        # Changelog
        [v1.3.2](https://example.com/v1.3.2)
        Mar 24, 2026
        - Added heap snapshots.
        [v1.3.1](https://example.com/v1.3.1)
        Mar 24, 2026
        - Added Poe auth provider.
        [v1.3.0](https://example.com/v1.3.0)
        Mar 22, 2026
        - Added interactive update flow.
        """

        let trimmed = ChangelogService.latestVersionSections(from: markdown, limit: 2)

        #expect(trimmed.contains("v1.3.2"))
        #expect(trimmed.contains("v1.3.1"))
        #expect(trimmed.contains("v1.3.0") == false)
    }

    @Test
    func summaryPromptRequestsChineseOutputForLatestTwoVersions() {
        let request = ChangelogRequest(
            provider: .openCode,
            currentVersion: "1.3.0",
            latestVersion: "1.3.2",
            sourceURL: URL(string: "https://opencode.ai/changelog")
        )!

        let prompt = ChangelogService.summaryPrompt(for: request)

        #expect(prompt.contains("请使用中文"))
        #expect(prompt.contains("最近 2 个版本"))
        #expect(prompt.contains("1.3.0"))
        #expect(prompt.contains("1.3.2"))
    }

    @Test
    func summaryCommandUsesCodexCliBackend() {
        let request = ChangelogRequest(
            provider: .openCode,
            currentVersion: "1.3.0",
            latestVersion: "1.3.2",
            sourceURL: URL(string: "https://opencode.ai/changelog")
        )!

        let command = ChangelogService.summaryCommand(for: request)

        #expect(command != nil)
        #expect(command?.contains("--cli") == true)
        #expect(command?.contains("codex") == true)
        #expect(command?.contains("--prompt") == true)
        #expect(command?.contains("-") == true)
    }

    @Test
    func summaryCommandFallsBackWhenCodexIsUnavailable() {
        let request = ChangelogRequest(
            provider: .openCode,
            currentVersion: "1.3.0",
            latestVersion: "1.3.2",
            sourceURL: URL(string: "https://opencode.ai/changelog")
        )!

        let command = ChangelogService.summaryCommand(
            for: request,
            environment: .init(hasSummarize: true, hasCodex: false)
        )

        #expect(command != nil)
        #expect(command?.contains("--cli") == false)
        #expect(command?.contains("codex") == false)
    }

    @Test
    func summaryCommandReturnsNilWhenSummarizeIsUnavailable() {
        let request = ChangelogRequest(
            provider: .openCode,
            currentVersion: "1.3.0",
            latestVersion: "1.3.2",
            sourceURL: URL(string: "https://opencode.ai/changelog")
        )!

        let command = ChangelogService.summaryCommand(
            for: request,
            environment: .init(hasSummarize: false, hasCodex: false)
        )

        #expect(command == nil)
    }

    @Test
    func readableSummaryErrorReportsMissingSummarizeClearly() {
        let message = ChangelogService.readableSummaryError(
            from: ChangelogServiceError.summaryUnavailable("summarize is not installed")
        )

        #expect(message == "summarize is not installed")
    }

    @Test
    func extractCommandUsesOfficialUrlAndStableFlags() {
        let request = ChangelogRequest(
            provider: .openCode,
            currentVersion: "1.3.0",
            latestVersion: "1.3.2",
            sourceURL: URL(string: "https://opencode.ai/changelog")
        )!

        let command = ChangelogService.extractCommand(for: request)

        #expect(command.contains("https://opencode.ai/changelog"))
        #expect(command.contains("--extract"))
        #expect(command.contains("--format"))
        #expect(command.contains("--markdown-mode"))
        #expect(command.contains("--timeout"))
    }
}
