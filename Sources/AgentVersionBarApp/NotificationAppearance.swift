import AppKit
import SwiftUI

enum NotificationLayout {
    static let width: CGFloat = 436
    static let corner: CGFloat = 12
    static let cardHeight: CGFloat = 148
    static let gap: CGFloat = 10

    static func listHeight(count: Int, screenHeight: CGFloat) -> CGFloat {
        let rows = max(1, (count + 1) / 2)
        let contentHeight = CGFloat(rows) * cardHeight + CGFloat(rows - 1) * gap + 12
        return min(contentHeight, max(160, min(600, screenHeight - 120)))
    }
}

struct ProviderIcon: View {
    let provider: ProviderKind
    var size: CGFloat = 24

    var body: some View {
        Group {
            if let icon = Self.images[provider] {
                Image(nsImage: icon).resizable().interpolation(.high).scaledToFit()
            } else {
                Image(systemName: "terminal.fill").resizable().scaledToFit().padding(4)
            }
        }
        .frame(width: size, height: size)
        .background(.white.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
        .accessibilityHidden(true)
    }

    static func resourceURL(for provider: ProviderKind) -> URL? {
        let ext = provider == .openClaw ? "jpg" : "png"
        if let url = Bundle.main.url(forResource: provider.rawValue, withExtension: ext, subdirectory: "ProviderIcons") {
            return url
        }
        #if SWIFT_PACKAGE
        return Bundle.module.url(forResource: provider.rawValue, withExtension: ext, subdirectory: "ProviderIcons")
        #else
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Resources/ProviderIcons/\(provider.rawValue).\(ext)")
        #endif
    }

    private static let images: [ProviderKind: NSImage] = Dictionary(uniqueKeysWithValues:
        ProviderKind.allCases.compactMap { provider in
            guard let url = resourceURL(for: provider), let image = NSImage(contentsOf: url) else { return nil }
            return (provider, image)
        }
    )
}

struct NotificationSurface: ViewModifier {
    let theme: ThemePalette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    if !reduceTransparency {
                        RoundedRectangle(cornerRadius: NotificationLayout.corner, style: .continuous).fill(.regularMaterial)
                    }
                    RoundedRectangle(cornerRadius: NotificationLayout.corner, style: .continuous)
                        .fill(theme.elevatedSurface.opacity(reduceTransparency ? 1 : (theme.isDark ? 0.92 : 0.88)))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: NotificationLayout.corner, style: .continuous)
                    .strokeBorder(
                        contrast == .increased ? theme.secondaryText : theme.rowDivider.opacity(0.55),
                        lineWidth: 0.5
                    )
            }
    }
}

struct NotificationButtonStyle: ButtonStyle {
    let theme: ThemePalette
    var prominent = false
    var diameter: CGFloat = 26
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(prominent ? theme.onTint : theme.secondaryText)
            .frame(width: diameter, height: diameter)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(prominent ? theme.brand : theme.strongText.opacity(hovered ? 0.08 : 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.65 : 1) : 0.35)
            .onHover { hovered = $0 }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovered)
    }
}

struct NotificationIconButton: View {
    let title: String
    let symbol: String
    let theme: ThemePalette
    var prominent = false
    var diameter: CGFloat = 26
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(NotificationButtonStyle(theme: theme, prominent: prominent, diameter: diameter))
            .accessibilityLabel(title)
            .help(title)
    }
}
