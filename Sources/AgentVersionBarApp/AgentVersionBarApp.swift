import AppKit
import SwiftUI

@main
struct AgentVersionBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Agent Versions", systemImage: "square.stack.3d.up.fill") {
            MenuBarContentView(model: model)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("Settings", id: SettingsView.windowID) {
            SettingsView(model: model)
        }
        .defaultSize(width: 500, height: 540)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}
