import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    private static let refreshIntervalDefaultsKey = "autoRefreshIntervalSeconds"
    private static let autoUpdateBehaviorDefaultsKey = "autoUpdateBehavior"
    private static let appThemeStyleDefaultsKey = "appThemeStyle"

    @Published private(set) var snapshots: [ProviderVersionSnapshot]
    @Published private(set) var isRefreshing = false
    @Published private(set) var updatingProviders: Set<ProviderKind> = []
    @Published private(set) var updateErrors: [ProviderKind: String] = [:]
    let workspacePath: String
    @Published var autoUpdateBehavior: AutoUpdateBehavior {
        didSet {
            defaults.set(autoUpdateBehavior.rawValue, forKey: Self.autoUpdateBehaviorDefaultsKey)
            if autoUpdateBehavior != oldValue { automaticAttempts.removeAll() }
        }
    }
    @Published var refreshInterval: RefreshInterval {
        didSet {
            defaults.set(refreshInterval.rawValue, forKey: Self.refreshIntervalDefaultsKey)
            rescheduleAutoRefresh()
        }
    }
    @Published var themeStyle: AppThemeStyle {
        didSet {
            defaults.set(themeStyle.rawValue, forKey: Self.appThemeStyleDefaultsKey)
        }
    }

    private let refreshSnapshots: @Sendable () async -> [ProviderVersionSnapshot]
    private let automaticUpdater: @Sendable ([String]) async -> CommandOutput
    private var automaticAttempts: [ProviderKind: String] = [:]
    private let defaults: UserDefaults
    private var autoRefreshTask: Task<Void, Never>?
    private var visibleProviders: Set<ProviderKind>
    var themePalette: ThemePalette {
        AppTheme.palette(for: themeStyle)
    }

    init(
        service: VersionRefreshService = .live,
        defaults: UserDefaults = .standard,
        autoload: Bool = true,
        workspacePath: String? = nil,
        refreshSnapshots: (@Sendable () async -> [ProviderVersionSnapshot])? = nil,
        automaticUpdater: @escaping @Sendable ([String]) async -> CommandOutput = {
            await CommandExecutor.runAsync($0, timeout: 300)
        }
    ) {
        self.defaults = defaults
        let storedValue = defaults.integer(forKey: Self.refreshIntervalDefaultsKey)
        let storedAutoUpdateBehavior = defaults.string(forKey: Self.autoUpdateBehaviorDefaultsKey)
        let storedThemeStyle = defaults.string(forKey: Self.appThemeStyleDefaultsKey)
        self.refreshInterval = defaults.object(forKey: Self.refreshIntervalDefaultsKey) == nil
            ? .fiveMinutes : (RefreshInterval(rawValue: storedValue) ?? .fiveMinutes)
        self.autoUpdateBehavior = AutoUpdateBehavior(rawValue: storedAutoUpdateBehavior ?? "") ?? .notifyOnly
        self.themeStyle = AppThemeStyle(rawValue: storedThemeStyle ?? "") ?? .light
        self.refreshSnapshots = refreshSnapshots ?? { await service.refreshAll() }
        self.automaticUpdater = automaticUpdater
        self.workspacePath = workspacePath ?? Self.resolveWorkspacePath()
        self.snapshots = ProviderKind.allCases.map(ProviderVersionSnapshot.placeholder(for:))
        self.visibleProviders = Set(
            ProviderKind.allCases.filter { provider in
                let key = Self.visibilityDefaultsKey(for: provider)
                if defaults.object(forKey: key) == nil {
                    return true
                }

                return defaults.bool(forKey: key)
            }
        )
        if autoload {
            rescheduleAutoRefresh()
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

        if date.timeIntervalSince(latestCheckedAt) < 5 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: latestCheckedAt, relativeTo: date)
    }

    func refresh() async {
        guard isRefreshing == false else {
            return
        }

        isRefreshing = true
        let refreshed = await refreshSnapshots()
        snapshots = refreshed
        await runAutomaticUpdates()
        isRefreshing = false
    }

    private func runAutomaticUpdates() async {
        var didUpdate = false
        for snapshot in snapshots {
            guard !Task.isCancelled, autoUpdateBehavior == .packageManagerWhenPossible else { break }
            guard snapshot.isInstalled, snapshot.status == .updateAvailable,
                  !updatingProviders.contains(snapshot.provider),
                  let command = snapshot.automaticUpdateCommand else { continue }
            let attempt = [snapshot.currentTitle, snapshot.latestTitle, command.joined(separator: " ")].joined(separator: "|")
            guard automaticAttempts[snapshot.provider] != attempt else { continue }
            automaticAttempts[snapshot.provider] = attempt
            updatingProviders.insert(snapshot.provider)
            updateErrors[snapshot.provider] = nil
            let result = await automaticUpdater(command)
            updatingProviders.remove(snapshot.provider)
            if result.exitCode == 0 {
                didUpdate = true
            } else {
                let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                updateErrors[snapshot.provider] = detail.isEmpty ? "Update failed (exit \(result.exitCode))" : detail
            }
        }
        if didUpdate { snapshots = await refreshSnapshots() }
    }

    func isUpdating(_ provider: ProviderKind) -> Bool {
        updatingProviders.contains(provider)
    }

    func update(_ provider: ProviderKind) {
        guard updatingProviders.contains(provider) == false else {
            return
        }

        guard let snapshot = snapshots.first(where: { $0.provider == provider }),
              (snapshot.status == .updateAvailable || snapshot.status == .currentOnly),
              let command = snapshot.terminalUpdateCommand else {
            return
        }

        updatingProviders.insert(provider)
        updateErrors[provider] = nil

        Task {
            await Task.detached {
                VersionRefreshService.launchCommandInTerminal(command, workingDirectory: NSHomeDirectory())
            }.value
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

        defaults.set(isVisible, forKey: Self.visibilityDefaultsKey(for: provider))
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
