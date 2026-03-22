import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private static let refreshIntervalDefaultsKey = "autoRefreshIntervalSeconds"
    private static let autoUpdateBehaviorDefaultsKey = "autoUpdateBehavior"

    @Published private(set) var snapshots: [ProviderVersionSnapshot]
    @Published private(set) var isRefreshing = false
    @Published private(set) var updatingProviders: Set<ProviderKind> = []
    let workspacePath: String
    @Published var autoUpdateBehavior: AutoUpdateBehavior {
        didSet {
            UserDefaults.standard.set(autoUpdateBehavior.rawValue, forKey: Self.autoUpdateBehaviorDefaultsKey)
        }
    }
    @Published var refreshInterval: RefreshInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval.rawValue, forKey: Self.refreshIntervalDefaultsKey)
            rescheduleAutoRefresh()
        }
    }

    private let service: VersionRefreshService
    private var autoRefreshTask: Task<Void, Never>?
    private var visibleProviders: Set<ProviderKind>

    init(
        service: VersionRefreshService = .live,
        autoload: Bool = true,
        workspacePath: String? = nil
    ) {
        let storedValue = UserDefaults.standard.integer(forKey: Self.refreshIntervalDefaultsKey)
        let storedAutoUpdateBehavior = UserDefaults.standard.string(forKey: Self.autoUpdateBehaviorDefaultsKey)
        self.refreshInterval = RefreshInterval(rawValue: storedValue) ?? .fiveMinutes
        self.autoUpdateBehavior = AutoUpdateBehavior(rawValue: storedAutoUpdateBehavior ?? "") ?? .notifyOnly
        self.service = service
        self.workspacePath = workspacePath ?? Self.resolveWorkspacePath()
        self.snapshots = ProviderKind.allCases.map(ProviderVersionSnapshot.placeholder(for:))
        self.visibleProviders = Set(
            ProviderKind.allCases.filter { provider in
                let key = Self.visibilityDefaultsKey(for: provider)
                if UserDefaults.standard.object(forKey: key) == nil {
                    return true
                }

                return UserDefaults.standard.bool(forKey: key)
            }
        )
        rescheduleAutoRefresh()

        if autoload {
            Task {
                await refresh()
            }
        }
    }

    deinit {
        autoRefreshTask?.cancel()
    }

    var outdatedCount: Int {
        snapshots.filter { $0.status == .updateAvailable }.count
    }

    var visibleSnapshots: [ProviderVersionSnapshot] {
        snapshots.filter { visibleProviders.contains($0.provider) }
    }

    var latestCheckedAt: Date? {
        snapshots.compactMap(\.checkedAt).max()
    }

    func checkedAtTitle(relativeTo date: Date) -> String {
        guard let latestCheckedAt else {
            return "Never checked"
        }

        return RelativeDateTimeFormatter().localizedString(for: latestCheckedAt, relativeTo: date)
    }

    func refresh() async {
        guard isRefreshing == false else {
            return
        }

        isRefreshing = true
        let refreshed = await service.refreshAll()
        snapshots = refreshed
        isRefreshing = false
    }

    func isUpdating(_ provider: ProviderKind) -> Bool {
        updatingProviders.contains(provider)
    }

    func update(_ provider: ProviderKind) {
        guard updatingProviders.contains(provider) == false else {
            return
        }

        guard let snapshot = snapshots.first(where: { $0.provider == provider }),
              snapshot.status == .updateAvailable,
              let command = snapshot.terminalUpdateCommand else {
            return
        }

        updatingProviders.insert(provider)

        Task {
            VersionRefreshService.launchCommandInTerminal(command, workingDirectory: NSHomeDirectory())
            updatingProviders.remove(provider)
        }
    }

    func isProviderVisible(_ provider: ProviderKind) -> Bool {
        visibleProviders.contains(provider)
    }

    func setProviderVisibility(_ isVisible: Bool, for provider: ProviderKind) {
        if isVisible {
            visibleProviders.insert(provider)
        } else {
            visibleProviders.remove(provider)
        }

        UserDefaults.standard.set(isVisible, forKey: Self.visibilityDefaultsKey(for: provider))
        objectWillChange.send()
    }

    private func rescheduleAutoRefresh() {
        autoRefreshTask?.cancel()

        guard refreshInterval.seconds > 0 else {
            return
        }

        let interval = refreshInterval.seconds
        autoRefreshTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: UInt64(interval) * 1_000_000_000)
                guard Task.isCancelled == false else {
                    break
                }

                await self?.refresh()
            }
        }
    }

    private static func visibilityDefaultsKey(for provider: ProviderKind) -> String {
        "is\(provider.rawValue)Visible"
    }

    nonisolated static func resolveWorkspacePath(
        executablePath: String? = Bundle.main.executableURL?.path,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        fileManager: FileManager = .default
    ) -> String {
        let candidates = [
            executablePath.map { URL(fileURLWithPath: $0).deletingLastPathComponent().path },
            environment["PWD"],
            currentDirectoryPath
        ].compactMap(Self.normalizedPath)

        for candidate in candidates {
            if let workspaceRoot = findWorkspaceRoot(startingAt: candidate, fileManager: fileManager) {
                return workspaceRoot
            }
        }

        return candidates.first ?? currentDirectoryPath
    }

    private nonisolated static func normalizedPath(_ path: String?) -> String? {
        guard let path, path.isEmpty == false else {
            return nil
        }

        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private nonisolated static func findWorkspaceRoot(startingAt path: String, fileManager: FileManager) -> String? {
        var currentURL = URL(fileURLWithPath: path).standardizedFileURL
        var isDirectory: ObjCBool = false

        if fileManager.fileExists(atPath: currentURL.path, isDirectory: &isDirectory), isDirectory.boolValue == false {
            currentURL.deleteLastPathComponent()
        }

        while true {
            if workspaceMarkerExists(in: currentURL, fileManager: fileManager) {
                return currentURL.path
            }

            let parentURL = currentURL.deletingLastPathComponent()
            if parentURL.path == currentURL.path {
                return nil
            }

            currentURL = parentURL
        }
    }

    private nonisolated static func workspaceMarkerExists(in directoryURL: URL, fileManager: FileManager) -> Bool {
        let markers = ["Package.swift", ".git"]
        return markers.contains { marker in
            fileManager.fileExists(atPath: directoryURL.appendingPathComponent(marker).path)
        }
    }
}
