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
                    case let .loading(request):
                        loadingState(request: request)
                    case let .loaded(content):
                        loadedState(content: content)
                    case let .failed(request, message):
                        failedState(request: request, message: message)
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
        case let .loading(request):
            requestHero(for: request)
        case let .loaded(content):
            requestHero(for: content.request)
        case let .failed(request, _):
            requestHero(for: request)
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

    private func loadingState(request: ChangelogRequest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Loading official changelog content", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                .font(.headline)
                .foregroundStyle(theme.strongText)

            Text("Fetching and summarizing \(request.provider.displayName) release notes.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .dashboardCard(theme: theme, accent: .info, padding: 18)
    }

    private func loadedState(content: ChangelogContent) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryCard(content: content)
            originalCard(content: content)
        }
    }

    private func failedState(request: ChangelogRequest, message: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Unable to load changelog content", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(DashboardAccent.warning.color)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)

            miniActionButton("Open in Browser", systemImage: "safari") {
                NSWorkspace.shared.open(request.sourceURL)
            }
        }
        .dashboardCard(theme: theme, accent: .warning, padding: 18)
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
