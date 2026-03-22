import Foundation
import Testing

@testable import AgentVersionBarApp

@Suite("AppModelTests")
struct AppModelTests {
    @Test
    @MainActor
    func themeDefaultsToLightAndPersistsChanges() {
        let defaults = UserDefaults(suiteName: "AppModelTests.themeDefaultsToWarmAndPersistsChanges")!
        defaults.removePersistentDomain(forName: "AppModelTests.themeDefaultsToWarmAndPersistsChanges")

        let model = AppModel(
            service: VersionRefreshService(
                commandRunner: { _ in CommandOutput(exitCode: 1, stdout: "", stderr: "") },
                dateProvider: Date.init
            ),
            defaults: defaults,
            autoload: false
        )

        #expect(model.themeStyle == .light)

        model.themeStyle = .dark

        #expect(defaults.string(forKey: "appThemeStyle") == AppThemeStyle.dark.rawValue)

        let restored = AppModel(
            service: VersionRefreshService(
                commandRunner: { _ in CommandOutput(exitCode: 1, stdout: "", stderr: "") },
                dateProvider: Date.init
            ),
            defaults: defaults,
            autoload: false
        )

        #expect(restored.themeStyle == .dark)
    }
}
