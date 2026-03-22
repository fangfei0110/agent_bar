import AppKit
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings-window"

    @ObservedObject var model: AppModel
    @State private var selectedTab: SettingsTab = .agents

    var body: some View {
        TabView(selection: $selectedTab) {
            agentsTab
                .tabItem { Text("Agents") }
                .tag(SettingsTab.agents)

            preferenceTab
                .tabItem { Text("Preference") }
                .tag(SettingsTab.preference)

            aboutTab
                .tabItem { Text("About") }
                .tag(SettingsTab.about)
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 500)
    }

    private var agentsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tabHeader(
                    title: "Agents",
                    subtitle: "Inspect executable paths, config locations, install source, and update entrypoints."
                )

                ForEach(model.snapshots) { snapshot in
                    agentCard(snapshot)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var preferenceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tabHeader(
                    title: "Preference",
                    subtitle: "Choose how often Agent Bar refreshes, how it behaves on updates, and which agents stay visible."
                )

                settingsCard("Refresh") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Auto refresh", selection: $model.refreshInterval) {
                            ForEach(RefreshInterval.allCases) { interval in
                                Text(interval.displayTitle)
                                    .tag(interval)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(model.refreshInterval.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                settingsCard("Updates") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Automatic update", selection: $model.autoUpdateBehavior) {
                            ForEach(AutoUpdateBehavior.allCases) { behavior in
                                Text(behavior.displayTitle)
                                    .tag(behavior)
                            }
                        }
                        .pickerStyle(.menu)

                        Text(model.autoUpdateBehavior.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                settingsCard("Panel Visibility") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(ProviderKind.allCases) { provider in
                            HStack(spacing: 12) {
                                Text(provider.displayName)
                                    .font(.subheadline)

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
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var aboutTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tabHeader(
                    title: "About",
                    subtitle: "A focused menu bar utility for checking current and available versions across local coding agents."
                )

                settingsCard("App") {
                    VStack(alignment: .leading, spacing: 8) {
                        settingsRow("Name", "Agent Bar")
                        settingsRow("Version", "0.1.0")
                        settingsRow("Tracked agents", "\(ProviderKind.allCases.count)")
                    }
                }

                settingsCard("Workspace") {
                    VStack(alignment: .leading, spacing: 8) {
                        settingsRow("Project path", model.workspacePath)
                        settingsRow("Menu title", "Agent Bar")
                    }
                }

                settingsCard("What It Does") {
                    Text("Shows installed and available versions, highlights update availability, and can open native CLI upgrade commands in Terminal.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func agentCard(_ snapshot: ProviderVersionSnapshot) -> some View {
        settingsCard(snapshot.provider.displayName) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text(snapshot.installSource.displayTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    statusBadge(snapshot.status)
                    Spacer()
                }

                HStack(spacing: 10) {
                    versionBadge(title: "Current", value: snapshot.currentTitle)
                    versionBadge(title: "Latest", value: snapshot.latestTitle)
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

                Divider()

                HStack(alignment: .top, spacing: 18) {
                    infoBlock(title: "Install method", value: snapshot.installMethodTitle)
                    infoBlock(title: "Update method", value: snapshot.updateMethodTitle)
                }

                if let terminalUpdateCommand = snapshot.terminalUpdateCommand {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Update command")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(terminalUpdateCommand.joined(separator: " "))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(nsColor: .textBackgroundColor))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }

    private func pathBlock(title: String, value: String, canOpenInTerminal: Bool, canRevealInFinder: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    miniActionButton("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(value, forType: .string)
                    }

                    if canRevealInFinder {
                        miniActionButton("Reveal") {
                            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: value)])
                        }
                    }

                    if canOpenInTerminal {
                        miniActionButton("Terminal") {
                            VersionRefreshService.launchPathInTerminal(value)
                        }
                    }
                }
            }

            Text(value)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private func infoBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func versionBadge(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private func miniActionButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .windowBackgroundColor))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func settingsCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.08), lineWidth: 1)
        )
    }

    private func tabHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func statusBadge(_ status: VersionStatus) -> some View {
        Text(status.displayTitle)
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusTint(status))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(statusTint(status).opacity(0.12))
            )
    }

    private func statusTint(_ status: VersionStatus) -> Color {
        switch status {
        case .upToDate:
            return .green
        case .updateAvailable:
            return .orange
        case .currentOnly, .latestOnly:
            return .blue
        case .unavailable:
            return .gray
        }
    }

    private func settingsRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
            .font(.subheadline)
    }
}

private enum SettingsTab {
    case agents
    case preference
    case about
}
