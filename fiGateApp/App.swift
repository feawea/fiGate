import AppKit
import SwiftUI
import fiGateCore

@MainActor
final class FiGateAppDelegate: NSObject, NSApplicationDelegate {
    let configManager = ConfigManager()
    let backgroundAgentManager = BackgroundAgentManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task {
            await backgroundAgentManager.bootstrap()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            sender.activate(ignoringOtherApps: true)
        }

        return true
    }
}

@main
struct FiGateMacApp: App {
    @NSApplicationDelegateAdaptor(FiGateAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("fiGate", id: "dashboard") {
            ContentView()
                .environmentObject(appDelegate.configManager)
                .environmentObject(appDelegate.backgroundAgentManager)
                .frame(minWidth: 960, minHeight: 640)
        }

        MenuBarExtra(
            "fiGate",
            systemImage: appDelegate.backgroundAgentManager.isRunningNormally ? "message.badge.waveform.fill" : "message.badge"
        ) {
            ResidentMenuBarView()
                .environmentObject(appDelegate.configManager)
                .environmentObject(appDelegate.backgroundAgentManager)
        }
        .menuBarExtraStyle(.window)
    }
}
