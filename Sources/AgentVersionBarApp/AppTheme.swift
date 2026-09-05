import AppKit
import SwiftUI

enum AppThemeStyle: String, CaseIterable, Identifiable, Sendable {
    case warm
    case light
    case dark

    var id: String { rawValue }

    var next: Self {
        switch self {
        case .light: return .warm
        case .warm: return .dark
        case .dark: return .light
        }
    }

    var displayTitle: String {
        switch self {
        case .warm:
            return "Warm"
        case .light:
            return "Cool"
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

    // Use PulseBar's OKLCH palette in the existing token model.
    init(_ lightness: Double, _ chroma: Double, _ hue: Double, opacity: Double = 1) {
        let a = chroma * cos(hue * .pi / 180)
        let b = chroma * sin(hue * .pi / 180)
        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)
        func gamma(_ value: Double) -> Double {
            min(1, max(0, value <= 0.0031308 ? 12.92 * value : 1.055 * pow(value, 1 / 2.4) - 0.055))
        }
        self.init(
            red: gamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            green: gamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            blue: gamma(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s),
            opacity: opacity
        )
    }

    var color: Color {
        Color(red: red, green: green, blue: blue).opacity(opacity)
    }
}

struct ThemePalette: Equatable {
    var isDark: Bool { strongTextToken.red > 0.8 }
    let panelBackgroundTopToken: ThemeColorToken
    let elevatedSurfaceToken: ThemeColorToken
    let heavyStrokeToken: ThemeColorToken
    let strongTextToken: ThemeColorToken
    let secondaryTextToken: ThemeColorToken
    let tertiaryTextToken: ThemeColorToken
    let shadowToken: ThemeColorToken
    let rowDividerToken: ThemeColorToken
    let brandToken: ThemeColorToken
    let supportingToken: ThemeColorToken
    let warningToken: ThemeColorToken
    let positiveToken: ThemeColorToken
    let onTintToken: ThemeColorToken

    var panelBackgroundTop: Color { panelBackgroundTopToken.color }
    var elevatedSurface: Color { elevatedSurfaceToken.color }
    var heavyStroke: Color { heavyStrokeToken.color }
    var strongText: Color { strongTextToken.color }
    var secondaryText: Color { secondaryTextToken.color }
    var tertiaryText: Color { tertiaryTextToken.color }
    var shadow: Color { shadowToken.color }
    var rowDivider: Color { rowDividerToken.color }
    var brand: Color { brandToken.color }
    var supporting: Color { supportingToken.color }
    var warning: Color { warningToken.color }
    var positive: Color { positiveToken.color }
    var onTint: Color { onTintToken.color }
}

enum DashboardAccent: Equatable {
    case success
    case warning
    case info
    case muted

    func color(in theme: ThemePalette) -> Color {
        switch self {
        case .success: return theme.positive
        case .warning: return theme.warning
        case .info: return theme.supporting
        case .muted: return theme.secondaryText
        }
    }
}

enum AppTheme {
    static func palette(for style: AppThemeStyle) -> ThemePalette {
        switch style {
        case .warm:
            return ThemePalette(
                panelBackgroundTopToken: ThemeColorToken(0.95, 0.021, 72),
                elevatedSurfaceToken: ThemeColorToken(0.993, 0.007, 72),
                heavyStrokeToken: ThemeColorToken(0.27, 0.024, 52, opacity: 0.12),
                strongTextToken: ThemeColorToken(0.27, 0.024, 52),
                secondaryTextToken: ThemeColorToken(0.46, 0.026, 52),
                tertiaryTextToken: ThemeColorToken(0.46, 0.026, 52),
                shadowToken: ThemeColorToken(0.27, 0.024, 52, opacity: 0.08),
                rowDividerToken: ThemeColorToken(0.27, 0.024, 52, opacity: 0.08),
                brandToken: ThemeColorToken(0.50, 0.115, 42),
                supportingToken: ThemeColorToken(0.50, 0.075, 12),
                warningToken: ThemeColorToken(0.50, 0.17, 28),
                positiveToken: ThemeColorToken(0.47, 0.075, 151),
                onTintToken: ThemeColorToken(1, 0, 0)
            )
        case .light:
            return ThemePalette(
                panelBackgroundTopToken: ThemeColorToken(0.95, 0.008, 166),
                elevatedSurfaceToken: ThemeColorToken(0.993, 0.002, 166),
                heavyStrokeToken: ThemeColorToken(0.25, 0.014, 166, opacity: 0.12),
                strongTextToken: ThemeColorToken(0.25, 0.014, 166),
                secondaryTextToken: ThemeColorToken(0.48, 0.012, 166),
                tertiaryTextToken: ThemeColorToken(0.48, 0.012, 166),
                shadowToken: ThemeColorToken(0.25, 0.014, 166, opacity: 0.08),
                rowDividerToken: ThemeColorToken(0.25, 0.014, 166, opacity: 0.08),
                brandToken: ThemeColorToken(0.48, 0.095, 166),
                supportingToken: ThemeColorToken(0.52, 0.09, 250),
                warningToken: ThemeColorToken(0.55, 0.135, 43),
                positiveToken: ThemeColorToken(0.48, 0.095, 166),
                onTintToken: ThemeColorToken(1, 0, 0)
            )
        case .dark:
            return ThemePalette(
                panelBackgroundTopToken: ThemeColorToken(0.19, 0.016, 166),
                elevatedSurfaceToken: ThemeColorToken(0.27, 0.015, 166),
                heavyStrokeToken: ThemeColorToken(0.95, 0.008, 166, opacity: 0.12),
                strongTextToken: ThemeColorToken(0.95, 0.008, 166),
                secondaryTextToken: ThemeColorToken(0.76, 0.012, 166),
                tertiaryTextToken: ThemeColorToken(0.76, 0.012, 166),
                shadowToken: ThemeColorToken(0, 0, 0, opacity: 0.10),
                rowDividerToken: ThemeColorToken(0.95, 0.008, 166, opacity: 0.08),
                brandToken: ThemeColorToken(0.76, 0.095, 166),
                supportingToken: ThemeColorToken(0.76, 0.08, 250),
                warningToken: ThemeColorToken(0.78, 0.105, 43),
                positiveToken: ThemeColorToken(0.76, 0.095, 166),
                onTintToken: ThemeColorToken(0.15, 0.015, 166)
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

struct FrostedGlass: NSViewRepresentable {
    let isDark: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = FrostedEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    }
}

private final class FrostedEffectView: NSVisualEffectView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.isOpaque = false
        window?.backgroundColor = .clear
        window?.titlebarAppearsTransparent = true
    }
}

struct DashboardPanelBackground: ViewModifier {
    let theme: ThemePalette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.background {
            ZStack {
                if !reduceTransparency { FrostedGlass(isDark: theme.isDark) }
                theme.panelBackgroundTop.opacity(reduceTransparency ? 1 : (theme.isDark ? 0.96 : 0.94))
            }
            .ignoresSafeArea()
        }
    }
}

struct GlassButtonStyle: ButtonStyle {
    let theme: ThemePalette
    var prominent = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(prominent ? theme.strongText : theme.secondaryText)
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(theme.strongText.opacity(configuration.isPressed ? 0.17 : (hovered ? 0.11 : (prominent ? 0.08 : 0.035))))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(theme.heavyStroke.opacity(prominent || hovered ? 1 : 0.4), lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hovered)
    }
}

struct GlassIconButton: View {
    let title: String
    let symbol: String
    let theme: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).frame(width: 12)
        }
        .buttonStyle(GlassButtonStyle(theme: theme))
        .help(title)
        .accessibilityLabel(title)
    }
}

extension View {
    func dashboardPanelBackground(theme: ThemePalette) -> some View {
        modifier(DashboardPanelBackground(theme: theme))
    }

}
