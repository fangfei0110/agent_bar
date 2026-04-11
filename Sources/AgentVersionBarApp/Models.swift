import Foundation

enum ProviderKind: String, CaseIterable, Identifiable, Sendable {
    case openClaw
    case openCode
    case claudeCode
    case codexCli
    case hermes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openClaw:
            return "OpenClaw"
        case .openCode:
            return "OpenCode"
        case .claudeCode:
            return "Claude Code"
        case .codexCli:
            return "Codex CLI"
        case .hermes:
            return "Hermes Agent"
        }
    }

    var executableName: String {
        switch self {
        case .openClaw:
            return "openclaw"
        case .openCode:
            return "opencode"
        case .claudeCode:
            return "claude"
        case .codexCli:
            return "codex"
        case .hermes:
            return "hermes"
        }
    }

    var npmPackage: String {
        switch self {
        case .openClaw:
            return "openclaw"
        case .openCode:
            return "opencode-ai"
        case .claudeCode:
            return "@anthropic-ai/claude-code"
        case .codexCli:
            return "@openai/codex"
        case .hermes:
            return "hermes-agent"
        }
    }

    var packageExecutableRelativePath: String? {
        switch self {
        case .openClaw:
            return "openclaw/bin/openclaw"
        case .openCode:
            return "opencode-ai/bin/opencode"
        case .claudeCode:
            return nil
        case .codexCli:
            return "@openai/codex/bin/codex.js"
        case .hermes:
            return nil
        }
    }

    var brewPackage: String? {
        switch self {
        case .openClaw:
            return nil
        case .openCode:
            return "anomalyco/tap/opencode"
        case .claudeCode:
            return "claude-code"
        case .codexCli:
            return nil
        case .hermes:
            return nil
        }
    }

    var githubReleaseRepository: String? {
        switch self {
        case .hermes:
            return "NousResearch/hermes-agent"
        case .openClaw, .openCode, .claudeCode, .codexCli:
            return nil
        }
    }

    var officialChangelogURL: URL? {
        switch self {
        case .openClaw:
            return URL(string: "https://github.com/clawdbot/clawdbot/releases")
        case .openCode:
            return URL(string: "https://opencode.ai/changelog")
        case .claudeCode:
            return URL(string: "https://github.com/anthropics/claude-code/releases")
        case .codexCli:
            return URL(string: "https://github.com/openai/codex/releases")
        case .hermes:
            return URL(string: "https://github.com/NousResearch/hermes-agent/releases")
        }
    }

    var fallbackLatestSources: [InstallSource] {
        switch self {
        case .openClaw:
            return [.npm]
        case .openCode:
            return [.npm, .homebrew]
        case .claudeCode:
            return [.npm, .homebrew]
        case .codexCli:
            return [.npm]
        case .hermes:
            return []
        }
    }

    func configPathCandidates(home: String) -> [String] {
        switch self {
        case .openClaw:
            return [
                "\(home)/.openclaw/openclaw.json",
                "\(home)/.openclaw/node.json"
            ]
        case .openCode:
            return [
                "\(home)/.config/opencode/opencode.json",
                "\(home)/Library/Application Support/ai.opencode.desktop/opencode.settings.dat",
                "\(home)/Library/Application Support/ai.opencode.desktop/opencode.global.dat"
            ]
        case .claudeCode:
            return [
                "\(home)/.claude/settings.json",
                "\(home)/.claude/.claude/settings.json"
            ]
        case .codexCli:
            return [
                "\(home)/.codex/config.toml"
            ]
        case .hermes:
            return [
                "\(home)/.hermes/config.yaml"
            ]
        }
    }

    func installMethodTitle(for installSource: InstallSource, executablePath: String?) -> String {
        switch installSource {
        case .homebrew:
            return "Homebrew"
        case .npm:
            if executablePath?.contains("/.npm/_npx/") == true {
                return "npx cache (\(npmPackage))"
            }

            return "npm global package (\(npmPackage))"
        case .pnpm:
            return "pnpm global package (\(npmPackage))"
        case .nativeInstaller:
            return "Native installer"
        case .directBinary:
            return "Direct binary"
        case .unknown:
            return "Unknown"
        }
    }

    func nativeUpdateSubcommand() -> [String]? {
        switch self {
        case .openClaw:
            return ["update"]
        case .openCode:
            return ["upgrade"]
        case .claudeCode:
            return ["update"]
        case .codexCli:
            return nil
        case .hermes:
            return ["update"]
        }
    }

    func packageManagerUpdateCommand(for installSource: InstallSource, executablePath: String?) -> [String]? {
        switch installSource {
        case .homebrew:
            guard let brewPackage else {
                return nil
            }
            return ["brew", "upgrade", brewPackage]
        case .npm:
            if executablePath?.contains("/.npm/_npx/") == true {
                return nil
            }
            return ["npm", "install", "-g", "\(npmPackage)@latest"]
        case .pnpm:
            return ["pnpm", "add", "-g", "\(npmPackage)@latest"]
        case .nativeInstaller, .directBinary, .unknown:
            return nil
        }
    }

    func updateMethodTitle(command: [String]?) -> String {
        command?.joined(separator: " ") ?? "Manual update"
    }
}

enum InstallSource: String, Equatable, Sendable {
    case homebrew
    case npm
    case pnpm
    case nativeInstaller
    case directBinary
    case unknown

    var displayTitle: String {
        switch self {
        case .homebrew:
            return "Homebrew"
        case .npm:
            return "npm"
        case .pnpm:
            return "pnpm"
        case .nativeInstaller:
            return "Native Installer"
        case .directBinary:
            return "Direct Binary"
        case .unknown:
            return "Unknown"
        }
    }
}

enum VersionStatus: Equatable, Sendable {
    case upToDate
    case updateAvailable
    case currentOnly
    case latestOnly
    case unavailable

    var displayTitle: String {
        switch self {
        case .upToDate:
            return "Up to date"
        case .updateAvailable:
            return "Update available"
        case .currentOnly:
            return "Current only"
        case .latestOnly:
            return "Latest only"
        case .unavailable:
            return "Unavailable"
        }
    }
}

struct ProviderVersionSnapshot: Identifiable, Equatable, Sendable {
    let provider: ProviderKind
    let currentVersion: String?
    let latestVersion: String?
    let executablePath: String?
    let resolvedExecutablePath: String?
    let configPath: String
    let installSource: InstallSource
    let installMethodTitle: String
    let updateMethodTitle: String
    let terminalUpdateCommand: [String]?
    let isInstalled: Bool
    let checkedAt: Date?
    let errorDescription: String?

    var id: String { provider.id }

    var status: VersionStatus {
        switch (currentVersion, latestVersion) {
        case let (current?, latest?):
            return current == latest ? .upToDate : .updateAvailable
        case (.some, nil):
            return .currentOnly
        case (nil, .some):
            return .latestOnly
        case (nil, nil):
            return .unavailable
        }
    }

    var currentTitle: String {
        currentVersion ?? (isInstalled ? "Unknown" : "Not installed")
    }

    var latestTitle: String {
        latestVersion ?? "Unavailable"
    }

    var errorTitle: String {
        errorDescription ?? status.displayTitle
    }

    var changelogSourceURL: URL? {
        provider.officialChangelogURL
    }

    var changelogURL: URL? {
        guard status == .updateAvailable else {
            return nil
        }

        return provider.officialChangelogURL
    }

    var isChangelogAvailable: Bool {
        changelogURL != nil
    }

    var canOpenChangelog: Bool {
        currentVersion != nil && latestVersion != nil && changelogSourceURL != nil
    }

    static func placeholder(for provider: ProviderKind) -> ProviderVersionSnapshot {
        ProviderVersionSnapshot(
            provider: provider,
            currentVersion: nil,
            latestVersion: nil,
            executablePath: nil,
            resolvedExecutablePath: nil,
            configPath: provider.configPathCandidates(home: NSHomeDirectory()).first ?? "Unavailable",
            installSource: .unknown,
            installMethodTitle: "Unknown",
            updateMethodTitle: "Manual update",
            terminalUpdateCommand: nil,
            isInstalled: false,
            checkedAt: nil,
            errorDescription: nil
        )
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case off = 0
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1800
    case hourly = 3600

    var id: Int { rawValue }

    var seconds: Int { rawValue }

    var displayTitle: String {
        switch self {
        case .off:
            return "Off"
        case .oneMinute:
            return "Every minute"
        case .fiveMinutes:
            return "Every 5 minutes"
        case .fifteenMinutes:
            return "Every 15 minutes"
        case .thirtyMinutes:
            return "Every 30 minutes"
        case .hourly:
            return "Every hour"
        }
    }

    var compactTitle: String {
        switch self {
        case .off:
            return "Manual"
        case .oneMinute:
            return "1m"
        case .fiveMinutes:
            return "5m"
        case .fifteenMinutes:
            return "15m"
        case .thirtyMinutes:
            return "30m"
        case .hourly:
            return "60m"
        }
    }

    var subtitle: String {
        switch self {
        case .off:
            return "Only refresh when you click the refresh button."
        case .oneMinute:
            return "Best for active monitoring."
        case .fiveMinutes:
            return "Good default for regular use."
        case .fifteenMinutes:
            return "Balanced refresh with lower background activity."
        case .thirtyMinutes:
            return "Lower overhead for occasional checking."
        case .hourly:
            return "Minimal background activity."
        }
    }
}

enum AutoUpdateBehavior: String, CaseIterable, Identifiable {
    case disabled
    case notifyOnly
    case packageManagerWhenPossible

    var id: String { rawValue }

    var displayTitle: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .notifyOnly:
            return "Notify only"
        case .packageManagerWhenPossible:
            return "Run package manager when possible"
        }
    }

    var subtitle: String {
        switch self {
        case .disabled:
            return "Never auto-update agents."
        case .notifyOnly:
            return "Show that updates are available, but do not run update commands."
        case .packageManagerWhenPossible:
            return "Automatically run supported package-manager update commands."
        }
    }
}
