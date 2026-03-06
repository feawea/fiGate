import AppKit
import Foundation

@MainActor
enum SystemSettingsNavigator {
    // Deep-link coverage varies across macOS releases, so use a fallback chain.
    private static let fullDiskAccessCandidates: [URL] = [
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"),
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy"),
        URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension"),
        URL(string: "x-apple.systempreferences:")
    ]
    .compactMap { $0 }

    static func openFullDiskAccessSettings() -> Bool {
        openFirstAvailableURL(from: fullDiskAccessCandidates)
    }

    static var fiGateAppPath: String {
        Bundle.main.bundleURL.path
    }

    @discardableResult
    static func copyFiGateAppPathToPasteboard() -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(fiGateAppPath, forType: .string)
    }

    private static func openFirstAvailableURL(from candidates: [URL]) -> Bool {
        let workspace = NSWorkspace.shared

        for url in candidates where workspace.open(url) {
            return true
        }

        let systemSettingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        return workspace.open(systemSettingsURL)
    }
}
