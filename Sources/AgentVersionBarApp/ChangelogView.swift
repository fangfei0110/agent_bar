import AppKit
import SwiftUI

struct ChangelogView: View {
    static let windowID = "changelog-window"

    @ObservedObject var appModel: AppModel
    @ObservedObject var model: ChangelogWindowModel

    private var theme: ThemePalette { appModel.themePalette }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.panelBackgroundTop.opacity(0.96), theme.panelBackgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard

                    switch model.state {
                    case .idle:
                        idleState
                    case let .loading(request, phase):
                        loadingState(request: request, phase: phase)
                    case let .showingOriginal(content):
                        partialLoadedState(content: content)
                    case let .loaded(content):
                        loadedState(content: content)
                    case let .unavailable(provider):
                        unavailableState(provider: provider)
                    case let .failed(provider, message):
                        failedState(provider: provider, message: message)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 760, minHeight: 640)
    }

    @ViewBuilder
    private var heroCard: some View {
        switch model.state {
        case .idle:
            VStack(alignment: .leading, spacing: 6) {
                Text("Changelog")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.strongText)

                Text("Open changelog details from the panel when an agent update is available.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            .dashboardCard(theme: theme, padding: 18)
        case let .loading(request, _):
            requestHero(for: request)
        case let .showingOriginal(content):
            requestHero(for: content.request)
        case let .loaded(content):
            requestHero(for: content.request)
        case let .unavailable(provider):
            VStack(alignment: .leading, spacing: 6) {
                Text("\(provider.displayName) Changelog")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.strongText)

                Text("Version information is unavailable for this agent.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            .dashboardCard(theme: theme, padding: 18)
        case let .failed(provider, _):
            VStack(alignment: .leading, spacing: 6) {
                Text("\(provider.displayName) Changelog")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.strongText)

                Text("Unable to load changelog content.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }
            .dashboardCard(theme: theme, padding: 18)
        }
    }

    private func requestHero(for request: ChangelogRequest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(request.provider.displayName) Changelog")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(theme.strongText)

                Text("Official release notes and an AI summary for \(request.currentVersion) to \(request.latestVersion).")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }

            HStack(spacing: 10) {
                changelogMetric(title: "Installed", value: request.currentVersion)
                changelogMetric(title: "Available", value: request.latestVersion)
                changelogMetric(title: "Source", value: request.provider.displayName)
            }

            HStack(spacing: 10) {
                miniActionButton("Open in Browser", systemImage: "safari") {
                    NSWorkspace.shared.open(request.sourceURL)
                }

                Text(request.sourceURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(theme.tertiaryText)
                    .textSelection(.enabled)
                    .lineLimit(1)
            }
        }
        .dashboardCard(theme: theme, accent: .info, padding: 18)
    }

    private var idleState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No changelog selected")
                .font(.headline)
                .foregroundStyle(theme.strongText)

            Text("Choose an agent with an available update from the panel to load its changelog here.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .dashboardCard(theme: theme, padding: 18)
    }

    private func unavailableState(provider: ProviderKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Changelog unavailable")
                .font(.headline)
                .foregroundStyle(theme.strongText)

            Text("\(provider.displayName) does not currently expose enough version information to load its changelog.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .dashboardCard(theme: theme, padding: 18)
    }

    private func loadingState(request: ChangelogRequest, phase: ChangelogLoadingPhase) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.regular)

                VStack(alignment: .leading, spacing: 4) {
                    Text(phase.title)
                        .font(.headline)
                        .foregroundStyle(theme.strongText)

                    Text(phase.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }
            }

            Text("Source: \(request.provider.displayName) • \(request.currentVersion) -> \(request.latestVersion)")
                .font(.caption)
                .foregroundStyle(theme.tertiaryText)
        }
        .dashboardCard(theme: theme, accent: .info, padding: 18)
    }

    private func partialLoadedState(content: ChangelogContent) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryLoadingCard()
            originalCard(content: content)
        }
    }

    private func loadedState(content: ChangelogContent) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryCard(content: content)
            originalCard(content: content)
        }
    }

    private func failedState(provider: ProviderKind, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Unable to load changelog content", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(DashboardAccent.warning.color)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .dashboardCard(theme: theme, accent: .warning, padding: 18)
    }

    private func summaryLoadingCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Summary", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(theme.strongText)

            HStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.regular)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Summarizing latest two versions")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.strongText)

                    Text("Summary will appear here as soon as it finishes.")
                        .font(.caption)
                        .foregroundStyle(theme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.metricTileFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.metricTileStroke, lineWidth: 1)
            )
        }
        .dashboardCard(theme: theme, accent: .success, padding: 18)
    }

    private func summaryCard(content: ChangelogContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Summary", systemImage: "sparkles")
                .font(.headline)
                .foregroundStyle(theme.strongText)

            if let summary = content.summary, summary.isEmpty == false {
                contentBlock(summary)
            } else {
                Text(content.summaryErrorDescription ?? "Summary unavailable")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.metricTileFill)
                    )
            }
        }
        .dashboardCard(theme: theme, accent: .success, padding: 18)
    }

    private func originalCard(content: ChangelogContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Original", systemImage: "doc.text")
                .font(.headline)
                .foregroundStyle(theme.strongText)

            if let originalContent = content.originalContent, originalContent.isEmpty == false {
                contentBlock(originalContent)
            } else {
                Text("No changelog content available.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(theme.metricTileFill)
                    )
            }
        }
        .dashboardCard(theme: theme, padding: 18)
    }

    private func contentBlock(_ text: String) -> some View {
        Text(text)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(theme.strongText)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(theme.codeBlockFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(theme.codeBlockStroke, lineWidth: 1)
            )
    }

    private func changelogMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(theme.tertiaryText)

            Text(value)
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .foregroundStyle(theme.strongText)
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
}
