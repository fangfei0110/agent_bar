import AppKit
import SwiftUI

struct ChangelogView: View {
    static let windowID = "changelog-window"
    @ObservedObject var appModel: AppModel
    @ObservedObject var model: ChangelogWindowModel
    @State private var selectedSection = Section.summary
    private var theme: ThemePalette { appModel.themePalette }

    private var request: ChangelogRequest? {
        switch model.state {
        case let .loading(request, _): return request
        case let .showingOriginal(content), let .loaded(content): return content.request
        default: return nil
        }
    }

    private var content: ChangelogContent? {
        switch model.state {
        case let .showingOriginal(content), let .loaded(content): return content
        default: return nil
        }
    }

    private var selectedText: String? {
        selectedSection == .summary ? content?.summary : content?.originalContent
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 12) {
                Picker("Content", selection: $selectedSection) {
                    Text("Summary").tag(Section.summary)
                    Text("Original").tag(Section.original)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 210)
                Spacer()
                if let request {
                    Text(request.sourceURL.host() ?? "").font(.caption).foregroundStyle(theme.secondaryText)
                    GlassIconButton(title: "Open official changelog", symbol: "safari", theme: theme) {
                        NSWorkspace.shared.open(request.sourceURL)
                    }
                }
                GlassIconButton(title: "Copy content", symbol: "doc.on.doc", theme: theme) {
                    guard let selectedText else { return }
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(selectedText, forType: .string)
                }.disabled(selectedText == nil)
            }
            .padding(.horizontal, 24).padding(.vertical, 14)
            Divider()
            ScrollView {
                bodyContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .foregroundStyle(theme.strongText)
        .tint(theme.brand)
        .dashboardPanelBackground(theme: theme)
        .preferredColorScheme(appModel.themeStyle == .dark ? .dark : .light)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 22, weight: .semibold))
                if let request {
                    HStack(spacing: 10) {
                        Text(request.currentVersion)
                        Image(systemName: "arrow.right").font(.caption)
                        Text(request.latestVersion)
                    }
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.secondaryText)
                }
            }
            Spacer()
            if canRetry {
                GlassIconButton(title: "Reload changelog", symbol: "arrow.clockwise", theme: theme) {
                    model.retry()
                }
            }
        }
        .padding(24)
    }

    private var title: String {
        switch model.state {
        case let .failed(provider, _), let .unavailable(provider): return "\(provider.displayName) Changelog"
        default: return request.map { "\($0.provider.displayName) Changelog" } ?? "Changelog"
        }
    }

    private var canRetry: Bool {
        switch model.state {
        case .loaded, .failed: return true
        default: return false
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch model.state {
        case .idle:
            message("No changelog selected", symbol: "doc.text")
        case .unavailable:
            message("Version information unavailable", symbol: "info.circle")
        case let .failed(_, error):
            VStack(alignment: .leading, spacing: 16) {
                message("Unable to load changelog", symbol: "exclamationmark.circle")
                errorDetails(error)
                Button("Try Again") { model.retry() }.buttonStyle(GlassButtonStyle(theme: theme))
            }
        case let .loading(_, phase):
            loading(phase.title)
        case let .showingOriginal(content):
            if selectedSection == .summary {
                VStack(alignment: .leading, spacing: 18) {
                    loading("Summarizing latest two versions...")
                    Button("Read Original") { selectedSection = .original }
                        .buttonStyle(GlassButtonStyle(theme: theme))
                }
            } else {
                document(content.originalContent)
            }
        case let .loaded(content):
            if selectedSection == .summary, content.summary == nil {
                VStack(alignment: .leading, spacing: 16) {
                    message("Summary unavailable", symbol: "exclamationmark.circle")
                    errorDetails(content.summaryErrorDescription ?? "No summary returned.")
                    Button("Read Original") { selectedSection = .original }
                        .buttonStyle(GlassButtonStyle(theme: theme))
                }
            } else {
                document(selectedText)
            }
        }
    }

    private func document(_ text: String?) -> some View {
        let source = text ?? "No content available."
        let attributed = selectedSection == .summary
            ? ((try? AttributedString(markdown: source, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(source))
            : AttributedString(source)
        return Text(attributed)
            .font(selectedSection == .original ? .system(size: 12, design: .monospaced) : .system(size: 14))
            .lineSpacing(6)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func errorDetails(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(error.contains("timed out") ? "The request timed out." : "The service could not complete this request.")
                .foregroundStyle(theme.secondaryText)
            DisclosureGroup("Details") {
                Text(error).font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
            }.foregroundStyle(theme.secondaryText)
        }
    }

    private func message(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.headline).foregroundStyle(theme.secondaryText)
            .padding(.vertical, 10)
    }

    private func loading(_ title: String) -> some View {
        HStack(spacing: 12) {
            ProgressView().controlSize(.small)
            Text(title).font(.body).foregroundStyle(theme.secondaryText)
        }.padding(.vertical, 10)
    }

    private enum Section { case summary, original }
}
