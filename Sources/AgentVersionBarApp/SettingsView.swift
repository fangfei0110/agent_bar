import AppKit
import SwiftUI

struct SettingsView: View {
    static let windowID = "settings-window"
    @ObservedObject var model: AppModel
    @State private var selectedTab = SettingsTab.agents
    private var theme: ThemePalette { model.themePalette }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.system(size: 20, weight: .semibold))
                Spacer()
                Picker("Settings section", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in Text(tab.rawValue).tag(tab) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 290)
            }
            .padding(22)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch selectedTab {
                    case .agents:
                        ForEach(model.snapshots) { agentDetails($0) }
                    case .preferences:
                        preferences
                    case .about:
                        about
                    }
                }
                .padding(22)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 580, minHeight: 520)
        .foregroundStyle(theme.strongText)
        .tint(theme.brand)
        .dashboardPanelBackground(theme: theme)
        .preferredColorScheme(model.themeStyle == .dark ? .dark : .light)
    }

    private var preferences: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsSection("Appearance") {
                HStack {
                    Text("Theme")
                    Spacer()
                    Picker("Theme", selection: $model.themeStyle) {
                        ForEach(AppThemeStyle.allCases) { style in
                            Label(style.displayTitle, systemImage: style.systemImage).tag(style)
                        }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 280)
                }
            }
            settingsSection("Updates") {
                HStack {
                    Text("Check for updates")
                    Spacer()
                    Picker("Check for updates", selection: $model.refreshInterval) {
                        ForEach(RefreshInterval.allCases) { Text($0.displayTitle).tag($0) }
                    }.labelsHidden().frame(width: 280)
                }
                HStack {
                    Text("Automatic updates")
                    Spacer()
                    Picker("Automatic updates", selection: $model.autoUpdateBehavior) {
                        ForEach(AutoUpdateBehavior.allCases) { Text($0.displayTitle).tag($0) }
                    }.labelsHidden().frame(width: 280)
                }
            }
            settingsSection("Menu bar agents") {
                ForEach(ProviderKind.allCases) { provider in
                    HStack {
                        Text(provider.displayName)
                        Spacer()
                        Toggle(provider.displayName, isOn: Binding(
                            get: { model.isProviderVisible(provider) },
                            set: { model.setProviderVisibility($0, for: provider) }
                        ))
                        .toggleStyle(.switch).controlSize(.small).labelsHidden()
                        .accessibilityLabel(provider.displayName)
                    }
                    if provider != ProviderKind.allCases.last { Divider() }
                }
            }
        }
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Agent Bar").font(.title2.weight(.semibold))
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")")
                        .foregroundStyle(theme.secondaryText)
                }
            }
            Divider()
            pathRow("Workspace", value: model.workspacePath)
            LabeledContent("Tracked agents", value: "\(ProviderKind.allCases.count)")
        }
    }

    private func agentDetails(_ snapshot: ProviderVersionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ProviderIcon(provider: snapshot.provider)
                Text(snapshot.provider.displayName).font(.headline)
                Spacer()
                StatusLabel(status: snapshot.status, theme: theme, isUpdating: model.isUpdating(snapshot.provider))
            }
            HStack(spacing: 20) {
                VersionColumn(title: "Installed", value: snapshot.currentTitle, color: theme.strongText, theme: theme)
                VersionColumn(title: "Available", value: snapshot.latestTitle, color: theme.strongText, theme: theme)
            }
            pathRow("Executable", value: snapshot.executablePath)
            if let resolved = snapshot.resolvedExecutablePath, resolved != snapshot.executablePath {
                pathRow("Resolved path", value: resolved)
            }
            pathRow("Configuration", value: snapshot.configPath == "Unavailable" ? nil : snapshot.configPath)
            LabeledContent("Installation", value: snapshot.installMethodTitle)
                .font(.caption).foregroundStyle(theme.secondaryText)
            if let command = snapshot.terminalUpdateCommand {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Update command").font(.caption).foregroundStyle(theme.secondaryText)
                    Text(command.joined(separator: " ")).font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let error = model.updateErrors[snapshot.provider] ?? snapshot.errorDescription {
                Label(error, systemImage: "exclamationmark.circle").font(.caption)
                    .foregroundStyle(theme.warning).textSelection(.enabled)
            }
        }
        .padding(18)
        .modifier(NotificationSurface(theme: theme))
    }

    private func pathRow(_ title: String, value: String?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption).foregroundStyle(theme.secondaryText)
                Text(value ?? "Not found").font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let value {
                GlassIconButton(title: "Copy \(title.lowercased())", symbol: "doc.on.doc", theme: theme) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(value, forType: .string)
                }
                GlassIconButton(title: "Reveal in Finder", symbol: "folder", theme: theme) {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: value)])
                }
                GlassIconButton(title: "Open in Terminal", symbol: "terminal", theme: theme) {
                    Task.detached { VersionRefreshService.launchPathInTerminal(value) }
                }
            }
        }
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            content()
            Divider().padding(.top, 8)
        }
    }
}

private enum SettingsTab: String, CaseIterable, Identifiable {
    case agents = "Agents"
    case preferences = "Preferences"
    case about = "About"
    var id: Self { self }
}
