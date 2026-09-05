import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var changelogModel: ChangelogWindowModel
    @Environment(\.openWindow) private var openWindow
    private var theme: ThemePalette { model.themePalette }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                if model.visibleSnapshots.isEmpty {
                    emptyState.padding(12)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: NotificationLayout.gap), GridItem(.flexible())], spacing: NotificationLayout.gap) {
                        ForEach(model.visibleSnapshots) { snapshot in
                            ProviderTile(
                                snapshot: snapshot, model: model, theme: theme,
                                canOpenChangelog: snapshot.canOpenChangelog || changelogModel.hasCachedContent(for: snapshot.provider)
                            ) {
                                changelogModel.open(snapshot: snapshot)
                                NSApplication.shared.activate(ignoringOtherApps: true)
                                openWindow(id: ChangelogView.windowID)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
            .scrollIndicators(.hidden)
            .frame(height: NotificationLayout.listHeight(
                count: model.visibleSnapshots.count,
                screenHeight: NSScreen.main?.visibleFrame.height ?? 900
            ))
            footer
        }
        .frame(width: NotificationLayout.width)
        .foregroundStyle(theme.strongText)
        .dashboardPanelBackground(theme: theme)
        .preferredColorScheme(model.themeStyle == .dark ? .dark : .light)
        .tint(theme.brand)
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "square.stack.3d.up.fill").foregroundStyle(theme.brand).accessibilityHidden(true)
            Text("Agent Bar").fontWeight(.semibold)
            Spacer()
            if model.isRefreshing { ProgressView().controlSize(.mini) }
            Text(summary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondaryText).monospacedDigit()
            NotificationIconButton(
                title: "Appearance: \(model.themeStyle.displayTitle). Switch to \(model.themeStyle.next.displayTitle)",
                symbol: model.themeStyle.systemImage,
                theme: theme
            ) {
                model.themeStyle = model.themeStyle.next
            }
            .background(theme.brand.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
            .padding(.leading, 4)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 16)
        .frame(height: 42)
    }

    private var summary: String {
        if model.isRefreshing { return "Checking..." }
        let updateCount = model.visibleSnapshots.filter { $0.status == .updateAvailable }.count
        if updateCount > 0 {
            return updateCount == 1 ? "1 update available" : "\(updateCount) updates available"
        }
        return "\(model.visibleSnapshots.count) agents"
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Circle().fill(model.refreshInterval == .off ? theme.secondaryText : theme.positive)
                .frame(width: 5, height: 5)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(model.latestCheckedAt == nil ? "Not checked yet" : "Checked \(model.checkedAtTitle(relativeTo: context.date))")
                    .help(model.refreshInterval == .off ? "Automatic checks off" : "Checks every \(model.refreshInterval.compactTitle)")
            }
            .font(.system(size: 10)).monospacedDigit().lineLimit(1)
            Spacer(minLength: 4)
            NotificationIconButton(title: "Refresh", symbol: "arrow.clockwise", theme: theme) {
                Task { await model.refresh() }
            }
            .disabled(model.isRefreshing)
            .keyboardShortcut("r", modifiers: .command)
            NotificationIconButton(title: "Settings", symbol: "gearshape", theme: theme, action: openSettings)
                .keyboardShortcut(",", modifiers: .command)
            NotificationIconButton(title: "Quit Agent Bar", symbol: "power", theme: theme) {
                NSApplication.shared.terminate(nil)
            }
        }
        .foregroundStyle(theme.secondaryText)
        .padding(.horizontal, 14)
        .frame(height: 38)
        .background(theme.elevatedSurface.opacity(0.5))
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.grid.2x2").font(.system(size: 22)).foregroundStyle(theme.secondaryText)
            Text("No agents selected").font(.system(size: 13, weight: .semibold))
            Button("Open Settings", action: openSettings).buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, minHeight: NotificationLayout.cardHeight - 12)
    }

    private func openSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        openWindow(id: SettingsView.windowID)
    }
}

private struct ProviderTile: View {
    let snapshot: ProviderVersionSnapshot
    @ObservedObject var model: AppModel
    let theme: ThemePalette
    let canOpenChangelog: Bool
    let openChangelog: () -> Void

    private var isUpdating: Bool { model.isUpdating(snapshot.provider) }
    private var updateError: String? { model.updateErrors[snapshot.provider] }
    private var canUpdate: Bool {
        snapshot.terminalUpdateCommand != nil && (snapshot.status == .updateAvailable || snapshot.status == .currentOnly)
    }
    private var isFirstCheck: Bool { model.isRefreshing && snapshot.checkedAt == nil }
    private var stateColor: Color {
        if updateError != nil { return theme.warning }
        if isFirstCheck || isUpdating { return theme.secondaryText }
        return snapshot.status.dashboardAccent.color(in: theme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 7) {
                ProviderIcon(provider: snapshot.provider, size: 20)
                Text(snapshot.provider.displayName).font(.system(size: 12, weight: .semibold)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .help(snapshot.installMethodTitle)
            .padding(.bottom, 10)
            Text(installedTitle)
                .font(.system(size: snapshot.currentVersion == nil ? 19 : 25, weight: .semibold, design: .rounded))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.75)
                .frame(height: 30, alignment: .leading)
                .accessibilityLabel("\(snapshot.provider.displayName), installed \(installedTitle)")
                .help(snapshot.executablePath ?? snapshot.installMethodTitle)
            Text(versionDetail)
                .font(.system(size: 11)).monospacedDigit()
                .foregroundStyle(snapshot.status == .updateAvailable ? theme.supporting : theme.secondaryText)
                .lineLimit(1).minimumScaleFactor(0.85)
                .frame(height: 18, alignment: .leading).help(versionDetail)
            Spacer(minLength: 8)
            HStack(spacing: 4) {
                Text(statusTitle)
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(stateColor)
                    .lineLimit(1).minimumScaleFactor(0.85)
                    .help(updateError ?? snapshot.errorDescription ?? snapshot.installMethodTitle)
                Spacer(minLength: 0)
                if canOpenChangelog {
                    NotificationIconButton(title: "\(snapshot.provider.displayName) changelog", symbol: "text.alignleft", theme: theme, action: openChangelog)
                }
                if isUpdating || isFirstCheck {
                    ProgressView().controlSize(.mini).frame(width: 26, height: 26)
                } else if canUpdate {
                    NotificationIconButton(title: "Update \(snapshot.provider.displayName)", symbol: "arrow.up", theme: theme, prominent: true) {
                        model.update(snapshot.provider)
                    }
                } else if snapshot.status == .upToDate {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14)).foregroundStyle(theme.positive)
                        .frame(width: 26, height: 26).accessibilityHidden(true)
                }
            }
            .frame(height: 26)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: NotificationLayout.cardHeight)
        .modifier(NotificationSurface(theme: theme))
        .contextMenu {
            if canOpenChangelog {
                Button("View Changelog", systemImage: "doc.text", action: openChangelog)
            }
            if canUpdate {
                Button("Update in Terminal", systemImage: "arrow.up") { model.update(snapshot.provider) }.disabled(isUpdating)
            }
            if let path = snapshot.executablePath {
                Button("Copy Executable Path", systemImage: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                }
            }
        }
    }

    private var installedTitle: String {
        if let version = snapshot.currentVersion { return version }
        if isFirstCheck { return "Checking..." }
        return snapshot.isInstalled ? "Unknown version" : "Not installed"
    }

    private var versionDetail: String {
        if isFirstCheck { return "Reading version" }
        if snapshot.status == .updateAvailable || snapshot.status == .latestOnly {
            return snapshot.commitsBehind != nil ? snapshot.latestTitle : "Latest \(snapshot.latestTitle)"
        }
        if snapshot.status == .currentOnly { return "Latest version unavailable" }
        if snapshot.status == .unavailable { return snapshot.errorDescription ?? "Version unavailable" }
        return snapshot.installSource.displayTitle
    }

    private var statusTitle: String {
        if isFirstCheck { return "Checking" }
        if isUpdating { return "Updating" }
        if updateError != nil { return "Update failed" }
        switch snapshot.status {
        case .updateAvailable: return "Update available"
        case .upToDate: return "Up to date"
        case .currentOnly: return "Current only"
        case .latestOnly: return snapshot.isInstalled ? "Version unavailable" : "Not installed"
        case .unavailable: return "Unavailable"
        }
    }
}

struct VersionColumn: View {
    let title: String
    let value: String
    let color: Color
    let theme: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(theme.secondaryText)
            Text(value).font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.75).help(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct StatusLabel: View {
    let status: VersionStatus
    let theme: ThemePalette
    var isUpdating = false
    var body: some View {
        Label(isUpdating ? "Updating" : status.displayTitle,
              systemImage: isUpdating ? "arrow.triangle.2.circlepath" : status.dashboardSymbol)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(status.dashboardAccent.color(in: theme))
            .lineLimit(1).fixedSize(horizontal: true, vertical: false)
    }
}
