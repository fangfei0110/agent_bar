import AppKit
import SwiftUI

@main
struct AgentVersionBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var changelogModel = ChangelogWindowModel()

    var body: some Scene {
        MenuBarExtra("Agent Versions", systemImage: "square.stack.3d.up.fill") {
            MenuBarContentView(model: model, changelogModel: changelogModel)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Settings", id: SettingsView.windowID) {
            SettingsView(model: model)
        }
        .defaultSize(width: 620, height: 620)

        WindowGroup("Changelog", id: ChangelogView.windowID) {
            ChangelogView(appModel: model, model: changelogModel)
        }
        .defaultSize(width: 760, height: 640)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
