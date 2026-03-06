import AppKit
import Foundation
import SwiftUI
import fiGateCore

@MainActor
final class BackgroundAgentManager: ObservableObject {
    enum GatewayRuntimeMode {
        case residentApp
        case stopped
    }

    @Published private(set) var statusText = "Single-app resident mode"
    @Published private(set) var detailText = "fiGate.app is the only gateway runtime. Keep the app running to continue polling Messages."
    @Published private(set) var lastError: String?
    @Published private(set) var gatewayRuntimeMode: GatewayRuntimeMode = .stopped
    @Published private(set) var gatewayRuntimeStatusText = "Not Running"
    @Published private(set) var gatewayRuntimeDetailText = "Gateway runtime has not been started yet."

    private var didBootstrap = false
    private let gatewayRunner = GatewayRunner()
    private var isGatewayRunning = false

    var isEnabled: Bool {
        true
    }

    var isRunningNormally: Bool {
        gatewayRuntimeMode == .residentApp && isGatewayRunning
    }

    var isUsingInAppGateway: Bool {
        isRunningNormally
    }

    func bootstrap() async {
        guard !didBootstrap else {
            return
        }

        didBootstrap = true
        await refreshStatus()
    }

    func refreshStatus() async {
        if isGatewayRunning {
            applyRunningState()
            return
        }

        do {
            try await startGatewayIfNeeded()
            applyRunningState()
        } catch {
            applyStoppedState(error.localizedDescription)
            print("fiGate failed to start the resident gateway runner: \(error.localizedDescription)")
        }
    }

    func restartGateway() async {
        await stopGateway()
        await refreshStatus()
    }

    func stopGateway() async {
        guard isGatewayRunning else {
            gatewayRuntimeMode = .stopped
            gatewayRuntimeStatusText = "Stopped"
            gatewayRuntimeDetailText = "The resident gateway runner is not active."
            return
        }

        await gatewayRunner.stop()
        isGatewayRunning = false
        gatewayRuntimeMode = .stopped
        gatewayRuntimeStatusText = "Stopped"
        gatewayRuntimeDetailText = "The resident gateway runner has been stopped."
        lastError = nil
        statusText = "Single-app resident mode"
        detailText = "fiGate.app is idle. Restart the gateway runner to resume polling Messages."
    }

    private func startGatewayIfNeeded() async throws {
        guard !isGatewayRunning else {
            return
        }

        try await gatewayRunner.start()
        isGatewayRunning = true
        print("fiGate started the resident gateway runner.")
    }

    private func applyRunningState() {
        gatewayRuntimeMode = .residentApp
        gatewayRuntimeStatusText = "Running in fiGate.app"
        gatewayRuntimeDetailText = "fiGate.app is actively polling Messages and sending replies in single-app resident mode."
        lastError = nil
        statusText = "Single-app resident mode"
        detailText = "fiGate.app is the only gateway runtime. Closing the dashboard window does not stop polling."
    }

    private func applyStoppedState(_ errorDescription: String) {
        gatewayRuntimeMode = .stopped
        gatewayRuntimeStatusText = "Not Running"
        gatewayRuntimeDetailText = errorDescription
        lastError = errorDescription
        statusText = "Single-app resident mode"
        detailText = "fiGate.app could not start the resident gateway runner."
    }
}
