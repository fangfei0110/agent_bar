import Foundation
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
    func textMeetsContrastOnOpaqueAccessibilityFallback() {
        for style in AppThemeStyle.allCases {
            let palette = AppTheme.palette(for: style)
            for surface in [palette.panelBackgroundTopToken, palette.elevatedSurfaceToken] {
                for text in [palette.strongTextToken, palette.secondaryTextToken] {
                    #expect(contrast(text, on: surface) >= 4.5)
                }
            }
            #expect(contrast(palette.onTintToken, on: palette.brandToken) >= 4.5)
            for text in [palette.warningToken, palette.positiveToken, palette.supportingToken] {
                #expect(contrast(text, on: palette.elevatedSurfaceToken) >= 4.5)
            }
        }
    }

    @Test
    func appearancePreservesPulseBarColorRoles() {
        let warm = AppTheme.palette(for: .warm)
        let cool = AppTheme.palette(for: .light)
        let dark = AppTheme.palette(for: .dark)
        #expect(warm.brandToken.red > warm.brandToken.green)
        #expect(warm.positiveToken.green > warm.positiveToken.red)
        #expect(cool.brandToken.green > cool.brandToken.red)
        #expect(dark.brandToken.green > dark.brandToken.red)
        #expect(dark.isDark && !warm.isDark && !cool.isDark)
        // Keep the stored light preference compatible while presenting the cool palette.
        #expect(AppThemeStyle(rawValue: "light") == .light)
        #expect(AppThemeStyle.light.displayTitle == "Cool")
    }

    @Test
    func oklchNeutralConversionHasNoColorCast() {
        let white = ThemeColorToken(1, 0, 0)
        let black = ThemeColorToken(0, 0, 0)
        #expect(abs(white.red - 1) < 0.00001)
        #expect(abs(white.green - 1) < 0.00001)
        #expect(abs(white.blue - 1) < 0.00001)
        #expect(black == ThemeColorToken(red: 0, green: 0, blue: 0))
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

    private func contrast(_ foreground: ThemeColorToken, on background: ThemeColorToken) -> Double {
        func luminance(_ values: [Double]) -> Double {
            let linear = values.map { $0 <= 0.04045 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
            return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
        }
        let bg = [background.red, background.green, background.blue]
        let fg = zip([foreground.red, foreground.green, foreground.blue], bg).map {
            $0 * foreground.opacity + $1 * (1 - foreground.opacity)
        }
        let first = luminance(fg)
        let second = luminance(bg)
        return (max(first, second) + 0.05) / (min(first, second) + 0.05)
    }
}
