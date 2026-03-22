import SwiftUI

enum AppThemeStyle: String, CaseIterable, Identifiable, Sendable {
    case warm
    case light
    case dark

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .warm:
            return "Warm"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .warm:
            return "sun.haze.fill"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.stars.fill"
        }
    }
}

struct ThemeColorToken: Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.opacity = opacity
    }

    var color: Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }

    func withOpacity(_ opacity: Double) -> ThemeColorToken {
        ThemeColorToken(red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct ThemePalette: Equatable {
    let panelBackgroundTopToken: ThemeColorToken
    let panelBackgroundBottomToken: ThemeColorToken
    let elevatedSurfaceToken: ThemeColorToken
    let elevatedSurfaceTopToken: ThemeColorToken
    let elevatedSurfaceBottomToken: ThemeColorToken
    let subtleStrokeToken: ThemeColorToken
    let heavyStrokeToken: ThemeColorToken
    let strongTextToken: ThemeColorToken
    let secondaryTextToken: ThemeColorToken
    let tertiaryTextToken: ThemeColorToken
    let shadowToken: ThemeColorToken
    let metricTileFillToken: ThemeColorToken
    let metricTileStrokeToken: ThemeColorToken
    let secondaryButtonFillToken: ThemeColorToken
    let quietBorderToken: ThemeColorToken
    let codeBlockFillToken: ThemeColorToken
    let codeBlockStrokeToken: ThemeColorToken
    let rowDividerToken: ThemeColorToken

    var panelBackgroundTop: Color { panelBackgroundTopToken.color }
    var panelBackgroundBottom: Color { panelBackgroundBottomToken.color }
    var windowBackground: Color { panelBackgroundBottomToken.color }
    var elevatedSurface: Color { elevatedSurfaceToken.color }
    var elevatedSurfaceTop: Color { elevatedSurfaceTopToken.color }
    var elevatedSurfaceBottom: Color { elevatedSurfaceBottomToken.color }
    var subtleStroke: Color { subtleStrokeToken.color }
    var heavyStroke: Color { heavyStrokeToken.color }
    var strongText: Color { strongTextToken.color }
    var secondaryText: Color { secondaryTextToken.color }
    var tertiaryText: Color { tertiaryTextToken.color }
    var shadow: Color { shadowToken.color }
    var metricTileFill: Color { metricTileFillToken.color }
    var metricTileStroke: Color { metricTileStrokeToken.color }
    var secondaryButtonFill: Color { secondaryButtonFillToken.color }
    var quietBorder: Color { quietBorderToken.color }
    var codeBlockFill: Color { codeBlockFillToken.color }
    var codeBlockStroke: Color { codeBlockStrokeToken.color }
    var rowDivider: Color { rowDividerToken.color }
}

enum DashboardAccent: Equatable {
    case success
    case warning
    case info
    case muted

    var token: ThemeColorToken {
        switch self {
        case .success:
            return ThemeColorToken(red: 0.33, green: 0.63, blue: 0.46)
        case .warning:
            return ThemeColorToken(red: 0.83, green: 0.56, blue: 0.27)
        case .info:
            return ThemeColorToken(red: 0.45, green: 0.61, blue: 0.76)
        case .muted:
            return ThemeColorToken(red: 0.56, green: 0.51, blue: 0.46)
        }
    }

    var color: Color { token.color }
    var softFill: Color { token.withOpacity(0.14).color }
    var stroke: Color { token.withOpacity(0.28).color }
}

enum AppTheme {
    static func palette(for style: AppThemeStyle) -> ThemePalette {
        switch style {
        case .warm:
            return ThemePalette(
                panelBackgroundTopToken: ThemeColorToken(red: 0.98, green: 0.95, blue: 0.91),
                panelBackgroundBottomToken: ThemeColorToken(red: 0.94, green: 0.89, blue: 0.83),
                elevatedSurfaceToken: ThemeColorToken(red: 0.99, green: 0.97, blue: 0.95),
                elevatedSurfaceTopToken: ThemeColorToken(red: 1.00, green: 0.99, blue: 0.98, opacity: 0.78),
                elevatedSurfaceBottomToken: ThemeColorToken(red: 0.91, green: 0.86, blue: 0.79, opacity: 0.64),
                subtleStrokeToken: ThemeColorToken(red: 0.69, green: 0.61, blue: 0.50, opacity: 0.18),
                heavyStrokeToken: ThemeColorToken(red: 0.63, green: 0.55, blue: 0.44, opacity: 0.28),
                strongTextToken: ThemeColorToken(red: 0.24, green: 0.18, blue: 0.14, opacity: 0.96),
                secondaryTextToken: ThemeColorToken(red: 0.40, green: 0.33, blue: 0.27, opacity: 0.82),
                tertiaryTextToken: ThemeColorToken(red: 0.53, green: 0.45, blue: 0.38, opacity: 0.72),
                shadowToken: ThemeColorToken(red: 0.31, green: 0.22, blue: 0.14, opacity: 0.10),
                metricTileFillToken: ThemeColorToken(red: 0.95, green: 0.92, blue: 0.87, opacity: 0.96),
                metricTileStrokeToken: ThemeColorToken(red: 0.71, green: 0.63, blue: 0.54, opacity: 0.12),
                secondaryButtonFillToken: ThemeColorToken(red: 1.00, green: 0.99, blue: 0.98, opacity: 0.62),
                quietBorderToken: ThemeColorToken(red: 0.71, green: 0.63, blue: 0.54, opacity: 0.16),
                codeBlockFillToken: ThemeColorToken(red: 0.96, green: 0.93, blue: 0.89, opacity: 0.98),
                codeBlockStrokeToken: ThemeColorToken(red: 0.69, green: 0.61, blue: 0.50, opacity: 0.14),
                rowDividerToken: ThemeColorToken(red: 0.71, green: 0.63, blue: 0.54, opacity: 0.12)
            )
        case .light:
            return ThemePalette(
                panelBackgroundTopToken: ThemeColorToken(red: 0.96, green: 0.97, blue: 0.99),
                panelBackgroundBottomToken: ThemeColorToken(red: 0.89, green: 0.92, blue: 0.97),
                elevatedSurfaceToken: ThemeColorToken(red: 0.99, green: 0.99, blue: 1.00),
                elevatedSurfaceTopToken: ThemeColorToken(red: 1.00, green: 1.00, blue: 1.00, opacity: 0.82),
                elevatedSurfaceBottomToken: ThemeColorToken(red: 0.86, green: 0.90, blue: 0.96, opacity: 0.48),
                subtleStrokeToken: ThemeColorToken(red: 0.60, green: 0.68, blue: 0.80, opacity: 0.16),
                heavyStrokeToken: ThemeColorToken(red: 0.54, green: 0.62, blue: 0.74, opacity: 0.26),
                strongTextToken: ThemeColorToken(red: 0.14, green: 0.19, blue: 0.28, opacity: 0.96),
                secondaryTextToken: ThemeColorToken(red: 0.28, green: 0.35, blue: 0.47, opacity: 0.82),
                tertiaryTextToken: ThemeColorToken(red: 0.42, green: 0.49, blue: 0.60, opacity: 0.72),
                shadowToken: ThemeColorToken(red: 0.19, green: 0.24, blue: 0.31, opacity: 0.08),
                metricTileFillToken: ThemeColorToken(red: 0.93, green: 0.96, blue: 0.99, opacity: 0.96),
                metricTileStrokeToken: ThemeColorToken(red: 0.62, green: 0.69, blue: 0.80, opacity: 0.10),
                secondaryButtonFillToken: ThemeColorToken(red: 0.99, green: 1.00, blue: 1.00, opacity: 0.70),
                quietBorderToken: ThemeColorToken(red: 0.62, green: 0.69, blue: 0.80, opacity: 0.14),
                codeBlockFillToken: ThemeColorToken(red: 0.94, green: 0.97, blue: 1.00, opacity: 0.98),
                codeBlockStrokeToken: ThemeColorToken(red: 0.60, green: 0.68, blue: 0.80, opacity: 0.12),
                rowDividerToken: ThemeColorToken(red: 0.62, green: 0.69, blue: 0.80, opacity: 0.10)
            )
        case .dark:
            return ThemePalette(
                panelBackgroundTopToken: ThemeColorToken(red: 0.10, green: 0.12, blue: 0.15),
                panelBackgroundBottomToken: ThemeColorToken(red: 0.06, green: 0.07, blue: 0.10),
                elevatedSurfaceToken: ThemeColorToken(red: 0.13, green: 0.15, blue: 0.19),
                elevatedSurfaceTopToken: ThemeColorToken(red: 0.20, green: 0.23, blue: 0.28, opacity: 0.30),
                elevatedSurfaceBottomToken: ThemeColorToken(red: 0.03, green: 0.04, blue: 0.06, opacity: 0.36),
                subtleStrokeToken: ThemeColorToken(red: 0.85, green: 0.88, blue: 0.93, opacity: 0.08),
                heavyStrokeToken: ThemeColorToken(red: 0.85, green: 0.88, blue: 0.93, opacity: 0.14),
                strongTextToken: ThemeColorToken(red: 0.95, green: 0.97, blue: 0.99, opacity: 0.96),
                secondaryTextToken: ThemeColorToken(red: 0.77, green: 0.81, blue: 0.87, opacity: 0.82),
                tertiaryTextToken: ThemeColorToken(red: 0.59, green: 0.65, blue: 0.73, opacity: 0.72),
                shadowToken: ThemeColorToken(red: 0.00, green: 0.00, blue: 0.00, opacity: 0.24),
                metricTileFillToken: ThemeColorToken(red: 0.08, green: 0.10, blue: 0.13, opacity: 0.96),
                metricTileStrokeToken: ThemeColorToken(red: 0.85, green: 0.88, blue: 0.93, opacity: 0.08),
                secondaryButtonFillToken: ThemeColorToken(red: 0.22, green: 0.25, blue: 0.30, opacity: 0.54),
                quietBorderToken: ThemeColorToken(red: 0.85, green: 0.88, blue: 0.93, opacity: 0.10),
                codeBlockFillToken: ThemeColorToken(red: 0.07, green: 0.09, blue: 0.12, opacity: 0.98),
                codeBlockStrokeToken: ThemeColorToken(red: 0.85, green: 0.88, blue: 0.93, opacity: 0.10),
                rowDividerToken: ThemeColorToken(red: 0.85, green: 0.88, blue: 0.93, opacity: 0.08)
            )
        }
    }
}

extension VersionStatus {
    var dashboardAccent: DashboardAccent {
        switch self {
        case .upToDate:
            return .success
        case .updateAvailable:
            return .warning
        case .currentOnly, .latestOnly:
            return .info
        case .unavailable:
            return .muted
        }
    }

    var dashboardSymbol: String {
        switch self {
        case .upToDate:
            return "checkmark.circle.fill"
        case .updateAvailable:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .currentOnly, .latestOnly:
            return "info.circle.fill"
        case .unavailable:
            return "minus.circle.fill"
        }
    }
}

struct DashboardPanelBackground: ViewModifier {
    let theme: ThemePalette

    func body(content: Content) -> some View {
        content
            .background(
                LinearGradient(
                    colors: [theme.panelBackgroundTop, theme.panelBackgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}

struct DashboardCardStyle: ViewModifier {
    let theme: ThemePalette
    let accent: DashboardAccent?
    let paddingAmount: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(paddingAmount)
            .background(cardBackground)
            .overlay(cardOverlay)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: theme.shadow, radius: 16, x: 0, y: 8)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [theme.elevatedSurfaceTop, theme.elevatedSurfaceBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.elevatedSurface)
            )
    }

    @ViewBuilder
    private var cardOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(theme.subtleStroke, lineWidth: 1)

        if let accent {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(accent.stroke.opacity(0.55), lineWidth: 1)
                .padding(0.5)
        }
    }
}

struct DashboardMetricTileStyle: ViewModifier {
    let theme: ThemePalette

    func body(content: Content) -> some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.metricTileFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.metricTileStroke, lineWidth: 1)
            )
    }
}

extension View {
    func dashboardPanelBackground(theme: ThemePalette) -> some View {
        modifier(DashboardPanelBackground(theme: theme))
    }

    func dashboardCard(theme: ThemePalette, accent: DashboardAccent? = nil, padding: CGFloat = 14) -> some View {
        modifier(DashboardCardStyle(theme: theme, accent: accent, paddingAmount: padding))
    }

    func dashboardMetricTile(theme: ThemePalette) -> some View {
        modifier(DashboardMetricTileStyle(theme: theme))
    }
}
