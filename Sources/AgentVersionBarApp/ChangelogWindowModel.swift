import Foundation

@MainActor
final class ChangelogWindowModel: ObservableObject {
    @Published private(set) var state: ChangelogViewState = .idle

    private let service: ChangelogService
    private var loadTask: Task<Void, Never>?

    init(service: ChangelogService = .live) {
        self.service = service
    }

    deinit {
        loadTask?.cancel()
    }

    func open(snapshot: ProviderVersionSnapshot) {
        guard let request = ChangelogRequest(snapshot: snapshot) else {
            loadTask?.cancel()
            state = .idle
            return
        }

        load(request: request)
    }

    func waitForLoadForTesting() async {
        while case .loading = state {
            await Task.yield()
        }
    }

    private func load(request: ChangelogRequest) {
        loadTask?.cancel()
        state = .loading(request)

        loadTask = Task { [service] in
            do {
                let content = try await service.load(request)
                guard Task.isCancelled == false else {
                    return
                }
                await MainActor.run {
                    self.state = .loaded(content)
                }
            } catch {
                guard Task.isCancelled == false else {
                    return
                }
                await MainActor.run {
                    self.state = .failed(request, error.localizedDescription)
                }
            }
        }
    }
}
