import Foundation

@MainActor
final class ChangelogWindowModel: ObservableObject {
    @Published private(set) var state: ChangelogViewState = .idle

    private let service: ChangelogService
    private var loadTask: Task<Void, Never>?
    private var cache: [ChangelogRequest: ChangelogContent] = [:]
    private var cachedContentByProvider: [ProviderKind: ChangelogContent] = [:]

    init(service: ChangelogService = .live) {
        self.service = service
    }

    deinit {
        loadTask?.cancel()
    }

    func open(snapshot: ProviderVersionSnapshot) {
        guard let request = ChangelogRequest(snapshot: snapshot) else {
            loadTask?.cancel()
            state = cachedContentByProvider[snapshot.provider].map(ChangelogViewState.loaded) ?? .unavailable(snapshot.provider)
            return
        }

        if let cachedContent = cache[request] {
            state = .loaded(cachedContent)
            return
        }

        load(request: request)
    }

    func hasCachedContent(for provider: ProviderKind) -> Bool {
        cachedContentByProvider[provider] != nil
    }

    func waitForLoadForTesting() async {
        while true {
            if case .loading = state {
                await Task.yield()
                continue
            }
            if case .showingOriginal = state {
                await Task.yield()
                continue
            }
            return
        }
    }

    private func load(request: ChangelogRequest) {
        loadTask?.cancel()
        state = .loading(request, .fetching)

        loadTask = Task { [service] in
            do {
                let originalContent = try await service.extract(request)
                guard Task.isCancelled == false else {
                    return
                }

                let partialContent = ChangelogContent(
                    request: request,
                    summary: nil,
                    originalContent: originalContent,
                    summaryErrorDescription: nil
                )

                await MainActor.run {
                    self.state = .showingOriginal(partialContent)
                }

                let summaryInput = ChangelogService.latestVersionSections(from: originalContent, limit: 2)
                let content: ChangelogContent
                do {
                    let summary = try await service.summarize(request, summaryInput)
                    content = ChangelogContent(
                        request: request,
                        summary: summary,
                        originalContent: originalContent,
                        summaryErrorDescription: nil
                    )
                } catch {
                    content = ChangelogContent(
                        request: request,
                        summary: nil,
                        originalContent: originalContent,
                        summaryErrorDescription: ChangelogService.readableSummaryError(from: error)
                    )
                }

                guard Task.isCancelled == false else {
                    return
                }

                await MainActor.run {
                    self.cache[request] = content
                    self.cachedContentByProvider[request.provider] = content
                    self.state = .loaded(content)
                }
            } catch {
                guard Task.isCancelled == false else {
                    return
                }
                await MainActor.run {
                    self.state = .failed(request.provider, error.localizedDescription)
                }
            }
        }
    }
}
