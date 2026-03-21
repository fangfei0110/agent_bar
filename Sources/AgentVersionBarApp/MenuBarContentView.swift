import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if model.visibleSnapshots.isEmpty {
                Text("No agents are visible. Re-enable them in Settings > Preference.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(model.visibleSnapshots) { snapshot in
                    ProviderCard(snapshot: snapshot, model: model)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button(model.isRefreshing ? "Refreshing..." : "Refresh") {
                    Task {
                        await model.refresh()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isRefreshing)

                Button("Settings") {
                    NSApplication.shared.activate(ignoringOtherApps: true)
                    openWindow(id: SettingsView.windowID)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(width: 380)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Agent Bar")
                .font(.headline)

            HStack(spacing: 8) {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    HeaderBadge(title: "Checked \(model.checkedAtTitle(relativeTo: context.date))", tint: .blue)
                }
                HeaderBadge(title: "Auto \(model.refreshInterval.compactTitle)", tint: .gray)
                if model.outdatedCount > 0 {
                    HeaderBadge(title: "\(model.outdatedCount) updates", tint: .orange)
                }
            }
        }
    }
}

private struct ProviderCard: View {
    let snapshot: ProviderVersionSnapshot
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.provider.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(snapshot.installSource.displayTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HeaderBadge(title: snapshot.status.displayTitle, tint: tint)
            }

            HStack(spacing: 12) {
                MetricBlock(title: "Installed", value: snapshot.currentTitle)
                MetricBlock(title: "Available", value: snapshot.latestTitle)
            }

            HStack {
                Button(model.isUpdating(snapshot.provider) ? "Updating..." : "Update") {
                    model.update(snapshot.provider)
                }
                .buttonStyle(.bordered)
                .disabled(isUpdateEnabled == false || model.isUpdating(snapshot.provider))

                Spacer()
            }

            if snapshot.errorDescription != nil {
                Text(snapshot.errorTitle)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var tint: Color {
        switch snapshot.status {
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

    private var isUpdateEnabled: Bool {
        snapshot.status == .updateAvailable && snapshot.terminalUpdateCommand != nil
    }
}

private struct MetricBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HeaderBadge: View {
    let title: String
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.12))
            )
    }
}
