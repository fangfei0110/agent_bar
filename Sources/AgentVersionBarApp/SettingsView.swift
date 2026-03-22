import AppKit
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings-window"

    @ObservedObject var model: AppModel
    @State private var selectedTab: SettingsTab = .agents

    private var theme: ThemePalette { model.themePalette }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.panelBackgroundTop.opacity(0.92), theme.panelBackgroundBottom.opacity(0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            TabView(selection: $selectedTab) {
                agentsTab
                    .tabItem { Label("Agents", systemImage: "square.stack.3d.up") }
                    .tag(SettingsTab.agents)

                preferenceTab
                    .tabItem { Label("Preference", systemImage: "slider.horizontal.3") }
                    .tag(SettingsTab.preference)

                aboutTab
                    .tabItem { Label("About", systemImage: "info.circle") }
                    .tag(SettingsTab.about)
            }
            .padding(20)
        }
        .frame(minWidth: 560, minHeight: 560)
    }

    private var agentsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tabHero(
                    title: "Agents",
                    subtitle: "Inspect executable paths, config locations, install source, and update entrypoints from one controlled surface.",
                    metrics: [
                        ("Tracked", "\(ProviderKind.allCases.count)"),
                        ("Visible", "\(model.visibleSnapshots.count)"),
                        ("Updates", "\(model.outdatedCount)")
                    ]
                )

                ForEach(model.snapshots) { snapshot in
                    agentCard(snapshot)
                }
            }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var preferenceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tabHero(
                    title: "Preference",
                    subtitle: "Tune refresh cadence, update behavior, panel visibility, and the default visual theme.",
                    metrics: [
                        ("Refresh", model.refreshInterval.compactTitle),
                        ("Theme", model.themeStyle.displayTitle),
                        ("Shown", "\(model.visibleSnapshots.count)")
                    ]
                )

                settingsCard("Appearance", systemImage: "paintpalette") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Default theme", selection: $model.themeStyle) {
                            ForEach(AppThemeStyle.allCases) { style in
                                Label(style.displayTitle, systemImage: style.systemImage)
                                    .tag(style)
                            }
                        }
                        .pickerStyle(.menu)

                        Text("Sets the default theme used when Agent Bar opens. Panel theme switching uses the same persisted value.")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                settingsCard("Refresh Cadence", systemImage: "timer") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Auto refresh", selection: $model.refreshInterval) {
                            ForEach(RefreshInterval.allCases) { interval in
                                Text(interval.displayTitle)
                                    .tag(interval)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(model.refreshInterval.subtitle)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                settingsCard("Update Flow", systemImage: "arrow.triangle.2.circlepath") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Automatic update", selection: $model.autoUpdateBehavior) {
                            ForEach(AutoUpdateBehavior.allCases) { behavior in
                                Text(behavior.displayTitle)
                                    .tag(behavior)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(model.autoUpdateBehavior.subtitle)
                            .font(.caption)
                            .foregroundStyle(theme.secondaryText)
                    }
                }

                settingsCard("Panel Visibility", systemImage: "eye") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(ProviderKind.allCases) { provider in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.strongText)

                                    Text(model.isProviderVisible(provider) ? "Visible in panel" : "Hidden from panel")
                                        .font(.caption)
                                        .foregroundStyle(theme.secondaryText)
                                }

                                Spacer()

                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { model.isProviderVisible(provider) },
                                        set: { model.setProviderVisibility($0, for: provider) }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            }
                            .padding(.vertical, 4)

                            if provider != ProviderKind.allCases.last {
                                Divider()
                                    .overlay(theme.rowDivider)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var aboutTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tabHero(
                    title: "About",
                    subtitle: "A focused menu bar utility for checking installed and available versions across local coding agents.",
                    metrics: [
                        ("Version", "0.2.1"),
                        ("Agents", "\(ProviderKind.allCases.count)"),
                        ("Theme", model.themeStyle.displayTitle)
                    ]
                )

                settingsCard("Application", systemImage: "sparkles.rectangle.stack") {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsRow("Name", "Agent Bar")
                        settingsRow("Version", "0.2.1")
                        settingsRow("Tracked agents", "\(ProviderKind.allCases.count)")
                    }
                }

                settingsCard("Workspace", systemImage: "folder") {
                    VStack(alignment: .leading, spacing: 10) {
                        settingsRow("Project path", model.workspacePath)
                        settingsRow("Menu title", "Agent Bar")
                    }
                }

                settingsCard("Capability", systemImage: "bolt.horizontal.circle") {
                    Text("Shows installed and available versions, highlights update availability, opens upgrade commands in Terminal, and now supports switchable warm, light, and dark themes.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func tabHero(title: String, subtitle: String, metrics: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.strongText)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                ForEach(metrics, id: \.0) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.0.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(theme.tertiaryText)

                        Text(metric.1)
                            .font(.system(.subheadline, design: .monospaced).weight(.medium))
                            .foregroundStyle(theme.strongText)
                    }
                    .dashboardMetricTile(theme: theme)
                }
            }
        }
        .dashboardCard(theme: theme, padding: 18)
    }

    private func agentCard(_ snapshot: ProviderVersionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.provider.displayName)
                        .font(.headline)
                        .foregroundStyle(theme.strongText)

                    Text(snapshot.installSource.displayTitle)
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()

                SettingsStatusBadge(status: snapshot.status, theme: theme)
            }

            HStack(spacing: 10) {
                versionBadge(title: "Current", value: snapshot.currentTitle, role: .current, status: snapshot.status)
                versionBadge(title: "Latest", value: snapshot.latestTitle, role: .available, status: snapshot.status)
            }

            pathBlock(
                title: "Bin path",
                value: snapshot.executablePath ?? "Not found",
                canOpenInTerminal: snapshot.executablePath != nil,
                canRevealInFinder: snapshot.executablePath != nil
            )

            if let resolvedExecutablePath = snapshot.resolvedExecutablePath,
               resolvedExecutablePath != snapshot.executablePath {
                pathBlock(
                    title: "Resolved path",
                    value: resolvedExecutablePath,
                    canOpenInTerminal: true,
                    canRevealInFinder: true
                )
            }

            pathBlock(
                title: "Config path",
                value: snapshot.configPath,
                canOpenInTerminal: snapshot.configPath != "Unavailable",
                canRevealInFinder: snapshot.configPath != "Unavailable"
            )

            HStack(alignment: .top, spacing: 12) {
                infoBlock(title: "Install method", value: snapshot.installMethodTitle)
                infoBlock(title: "Update method", value: snapshot.updateMethodTitle)
            }

            if let terminalUpdateCommand = snapshot.terminalUpdateCommand {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Update command")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)

                    codeBlock(terminalUpdateCommand.joined(separator: " "))
                }
            }
        }
        .dashboardCard(theme: theme, accent: snapshot.status.dashboardAccent, padding: 16)
    }

    private func pathBlock(title: String, value: String, canOpenInTerminal: Bool, canRevealInFinder: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.secondaryText)

                Spacer()

                HStack(spacing: 6) {
                    miniActionButton("Copy", systemImage: "doc.on.doc") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    }

                    if canRevealInFinder {
                        miniActionButton("Reveal", systemImage: "folder") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: value)])
                        }
                    }

                    if canOpenInTerminal {
                        miniActionButton("Terminal", systemImage: "chevron.left.forwardslash.chevron.right") {
                            VersionRefreshService.launchPathInTerminal(value)
                        }
                    }
                }
            }

            codeBlock(value)
        }
    }

    private func codeBlock(_ value: String) -> some View {
        Text(value)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(theme.strongText)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(theme.codeBlockFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.codeBlockStroke, lineWidth: 1)
            )
    }

    private func infoBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(theme.strongText)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .dashboardMetricTile(theme: theme)
    }

    private func versionBadge(title: String, value: String, role: VersionBadgeRole, status: VersionStatus) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(theme.tertiaryText)

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(role == .available && status == .updateAvailable ? theme.updateHighlight : theme.strongText)
                .lineLimit(1)
        }
        .dashboardMetricTile(theme: theme)
    }

    private func miniActionButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(theme.secondaryButtonFill)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(theme.heavyStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func settingsCard<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(theme.strongText)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCard(theme: theme, padding: 18)
    }

    private func settingsRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            Spacer()

            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(theme.strongText)
        }
    }
}

private struct SettingsStatusBadge: View {
    let status: VersionStatus
    let theme: ThemePalette

    var body: some View {
        Label(status.displayTitle, systemImage: status.dashboardSymbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.dashboardAccent.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(status.dashboardAccent.softFill)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(status.dashboardAccent.stroke, lineWidth: 1)
            )
    }
}

private enum VersionBadgeRole {
    case current
    case available
}

private enum SettingsTab {
    case agents
    case preference
    case about
}
