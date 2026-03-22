import Testing

@testable import AgentVersionBarApp

@Suite("AppThemeTests")
struct AppThemeTests {
    @Test
    func versionStatusMapsToStableDashboardAppearance() {
        #expect(VersionStatus.upToDate.dashboardAccent == .success)
        #expect(VersionStatus.upToDate.dashboardSymbol == "checkmark.circle.fill")

        #expect(VersionStatus.updateAvailable.dashboardAccent == .warning)
        #expect(VersionStatus.updateAvailable.dashboardSymbol == "arrow.triangle.2.circlepath.circle.fill")

        #expect(VersionStatus.currentOnly.dashboardAccent == .info)
        #expect(VersionStatus.latestOnly.dashboardAccent == .info)

        #expect(VersionStatus.unavailable.dashboardAccent == .muted)
        #expect(VersionStatus.unavailable.dashboardSymbol == "minus.circle.fill")
    }

    @Test
    func appThemeUsesWarmLightPalette() {
        let warm = AppTheme.palette(for: .warm)

        #expect(warm.panelBackgroundTopToken == ThemeColorToken(red: 0.98, green: 0.95, blue: 0.91))
        #expect(warm.panelBackgroundBottomToken == ThemeColorToken(red: 0.94, green: 0.89, blue: 0.83))
        #expect(warm.elevatedSurfaceToken == ThemeColorToken(red: 0.99, green: 0.97, blue: 0.95))
        #expect(warm.strongTextToken == ThemeColorToken(red: 0.24, green: 0.18, blue: 0.14, opacity: 0.96))
        #expect(warm.codeBlockFillToken == ThemeColorToken(red: 0.96, green: 0.93, blue: 0.89, opacity: 0.98))
    }

    @Test
    func appThemeExposesThreeDistinctPalettes() {
        let warm = AppTheme.palette(for: .warm)
        let light = AppTheme.palette(for: .light)
        let dark = AppTheme.palette(for: .dark)

        #expect(AppThemeStyle.allCases == [.warm, .light, .dark])
        #expect(warm.panelBackgroundTopToken != light.panelBackgroundTopToken)
        #expect(light.panelBackgroundTopToken != dark.panelBackgroundTopToken)
        #expect(warm.strongTextToken != dark.strongTextToken)
    }
}
