import AppKit
import Testing
@testable import AgentVersionBarApp

@Suite("Notification appearance")
@MainActor
struct NotificationAppearanceTests {
    @Test func everyProviderHasADecodableBundledIcon() throws {
        for provider in ProviderKind.allCases {
            let url = try #require(ProviderIcon.resourceURL(for: provider))
            let image = try #require(NSImage(contentsOf: url))
            #expect(image.size.width >= 24)
            #expect(image.size.height >= 24)
        }
    }

    @Test func notificationListFitsShortScreensAndAllVisibilityStates() {
        for count in 0...ProviderKind.allCases.count {
            for height: CGFloat in [600, 720, 900, 1410] {
                let listHeight = NotificationLayout.listHeight(count: count, screenHeight: height)
                #expect(listHeight > 0)
                #expect(listHeight + 120 <= height)
                #expect(listHeight <= 600)
            }
        }
        #expect(NotificationLayout.listHeight(count: 1, screenHeight: 900) == 160)
        #expect(NotificationLayout.listHeight(count: 2, screenHeight: 900) == 160)
        #expect(NotificationLayout.listHeight(count: 3, screenHeight: 900) == 318)
        #expect(NotificationLayout.listHeight(count: 4, screenHeight: 900) == 318)
        #expect(NotificationLayout.listHeight(count: 6, screenHeight: 900) == 476)
    }
}
