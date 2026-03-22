import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    private var theme: ThemePalette { model.themePalette }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if model.visibleSnapshots.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(model.visibleSnapshots) { snapshot in
                        ProviderCard(snapshot: snapshot, model: model, theme: theme)
                    }
                }
            }

            actionBar
        }
        .padding(12)
        .frame(width: 424)
        .dashboardPanelBackground(theme: theme)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Agent Bar")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.strongText)

                    Text("Version visibility for local coding agents")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()

                ThemeMenuButton(model: model, theme: theme)

                DashboardPill(
                    title: model.isRefreshing ? "Refreshing" : "Live",
                    systemImage: model.isRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "bolt.horizontal.circle.fill",
                    accent: .info,
                    theme: theme
                )
            }

            HStack(spacing: 8) {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    DashboardPill(
                        title: "Checked \(model.checkedAtTitle(relativeTo: context.date))",
                        systemImage: "clock.fill",
                        accent: .muted,
                        theme: theme
                    )
                }

                DashboardPill(
                    title: "Auto \(model.refreshInterval.compactTitle)",
                    systemImage: "timer",
                    accent: .info,
                    theme: theme
                )

                DashboardPill(
                    title: "\(model.outdatedCount) updates",
                    systemImage: model.outdatedCount == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    accent: model.outdatedCount == 0 ? .success : .warning,
                    theme: theme
                )
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing on the panel")
                .font(.headline)
                .foregroundStyle(theme.strongText)

            Text("No agents are visible right now. Re-enable them in Settings > Preference.")
                .font(.caption)
                .foregroundStyle(theme.secondaryText)
        }
        .dashboardCard(theme: theme, padding: 14)
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            PanelActionButton(
                title: model.isRefreshing ? "Refreshing..." : "Refresh",
                systemImage: "arrow.clockwise",
                prominence: .primary,
                theme: theme
            ) {
                Task {
                    await model.refresh()
                }
            }
            .disabled(model.isRefreshing)

            PanelActionButton(
                title: "Settings",
                systemImage: "slider.horizontal.3",
                prominence: .secondary,
                theme: theme
            ) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: SettingsView.windowID)
            }

            Spacer(minLength: 0)

            PanelActionButton(
                title: "Quit",
                systemImage: "xmark.circle",
                prominence: .quiet,
                theme: theme
            ) {
                NSApplication.shared.terminate(nil)
            }
        }
        .dashboardCard(theme: theme, padding: 10)
    }
}

private struct ThemeMenuButton: View {
    @ObservedObject var model: AppModel
    let theme: ThemePalette

    var body: some View {
        Menu {
            ForEach(AppThemeStyle.allCases) { style in
                Button {
                    model.themeStyle = style
                } label: {
                    Label(style.displayTitle, systemImage: model.themeStyle == style ? "checkmark" : style.systemImage)
                }
            }
        } label: {
            Image(systemName: model.themeStyle.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(theme.secondaryButtonFill)
                )
                .overlay(
                    Circle()
                        .strokeBorder(theme.heavyStroke, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .help("Theme")
    }
}

private struct ProviderCard: View {
    let snapshot: ProviderVersionSnapshot
    @ObservedObject var model: AppModel
    let theme: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(snapshot.status.dashboardAccent.softFill)
                        .frame(width: 34, height: 34)

                    Image(systemName: snapshot.status.dashboardSymbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(snapshot.status.dashboardAccent.color)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(snapshot.provider.displayName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.strongText)

                    Text(snapshot.installSource.displayTitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()

                DashboardPill(
                    title: snapshot.status.displayTitle,
                    systemImage: snapshot.status.dashboardSymbol,
                    accent: snapshot.status.dashboardAccent,
                    theme: theme
                )
            }

            HStack(spacing: 10) {
                MetricBlock(
                    title: "Installed",
                    value: snapshot.currentTitle,
                    role: .current,
                    status: snapshot.status,
                    theme: theme
                )
                MetricBlock(
                    title: "Available",
                    value: snapshot.latestTitle,
                    role: .available,
                    status: snapshot.status,
                    theme: theme
                )
            }

            HStack(spacing: 10) {
                PanelActionButton(
                    title: model.isUpdating(snapshot.provider) ? "Updating..." : "Update",
                    systemImage: "arrow.up.circle",
                    prominence: isUpdateEnabled ? .primary : .secondary,
                    theme: theme
                ) {
                    model.update(snapshot.provider)
                }
                .disabled(isUpdateEnabled == false || model.isUpdating(snapshot.provider))

                if snapshot.errorDescription != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(DashboardAccent.warning.color)
                        Text(snapshot.errorTitle)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                            .lineLimit(1)
                    }
                } else {
                    Text(snapshot.installMethodTitle)
                        .font(.caption)
                        .foregroundStyle(theme.tertiaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
        }
        .dashboardCard(theme: theme, accent: snapshot.status.dashboardAccent, padding: 12)
    }

    private var isUpdateEnabled: Bool {
        snapshot.status == .updateAvailable && snapshot.terminalUpdateCommand != nil
    }
}

private struct MetricBlock: View {
    enum Role {
        case current
        case available
    }

    let title: String
    let value: String
    let role: Role
    let status: VersionStatus
    let theme: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(theme.tertiaryText)

            Text(value)
                .font(.system(size: 12, weight: valueWeight, design: .monospaced))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .dashboardMetricTile(theme: theme)
    }

    private var valueWeight: Font.Weight {
        .bold
    }

    private var valueColor: Color {
        if role == .available, status == .updateAvailable {
            return theme.updateHighlight
        }

        return theme.strongText
    }
}

private struct DashboardPill: View {
    let title: String
    let systemImage: String
    let accent: DashboardAccent
    let theme: ThemePalette

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(accent.color)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.softFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(accent.stroke, lineWidth: 1)
            )
    }
}

private struct PanelActionButton: View {
    enum Prominence {
        case primary
        case secondary
        case quiet
    }

    let title: String
    let systemImage: String
    let prominence: Prominence
    let theme: ThemePalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(background)
                .overlay(border)
        }
        .buttonStyle(.plain)
        .opacity(prominence == .quiet ? 0.9 : 1)
    }

    private var foregroundColor: Color {
        switch prominence {
        case .primary:
            return theme.strongText
        case .secondary:
            return theme.secondaryText
        case .quiet:
            return theme.tertiaryText
        }
    }

    private var background: some View {
        Capsule(style: .continuous)
            .fill(backgroundColor)
    }

    private var border: some View {
        Capsule(style: .continuous)
            .strokeBorder(borderColor, lineWidth: 1)
    }

    private var backgroundColor: Color {
        switch prominence {
        case .primary:
            return DashboardAccent.info.color.opacity(0.22)
        case .secondary:
            return theme.secondaryButtonFill
        case .quiet:
            return Color.clear
        }
    }

    private var borderColor: Color {
        switch prominence {
        case .primary:
            return DashboardAccent.info.stroke
        case .secondary:
            return theme.heavyStroke
        case .quiet:
            return theme.quietBorder
        }
    }
}
