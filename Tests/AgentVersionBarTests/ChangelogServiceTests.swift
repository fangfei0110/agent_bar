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
}
