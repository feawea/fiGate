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

    @Published private(set) var statusText = "Single-App Resident Mode / 單一常駐模式"
    @Published private(set) var detailText = "fiGate.app is the only gateway runtime for iMessage, OpenClaw, and Apple Messages automation. Keep the app running to continue polling Messages. / fiGate.app 是唯一的 iMessage、OpenClaw 與 Apple Messages automation gateway runtime。請保持 app 常駐以持續輪詢 Messages。"
    @Published private(set) var lastError: String?
    @Published private(set) var gatewayRuntimeMode: GatewayRuntimeMode = .stopped
    @Published private(set) var gatewayRuntimeStatusText = "Not Running / 未運行"
    @Published private(set) var gatewayRuntimeDetailText = "Gateway runtime has not been started yet. / Gateway runtime 尚未啟動。"

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
            gatewayRuntimeStatusText = "Stopped / 已停止"
            gatewayRuntimeDetailText = "The resident gateway runner is not active. / 常駐 gateway runner 尚未啟用。"
            return
        }

        await gatewayRunner.stop()
        isGatewayRunning = false
        gatewayRuntimeMode = .stopped
        gatewayRuntimeStatusText = "Stopped / 已停止"
        gatewayRuntimeDetailText = "The resident gateway runner has been stopped. / 常駐 gateway runner 已停止。"
        lastError = nil
        statusText = "Single-App Resident Mode / 單一常駐模式"
        detailText = "fiGate.app is idle. Restart the gateway runner to resume iMessage polling and OpenClaw relay work. / fiGate.app 目前閒置。重新啟動 gateway runner 以恢復 iMessage 輪詢與 OpenClaw relay。"
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
        gatewayRuntimeStatusText = "Running in fiGate.app / 由 fiGate.app 運行"
        gatewayRuntimeDetailText = "fiGate.app is actively polling Apple Messages, relaying requests to OpenClaw, and sending iMessage replies in single-app resident mode. / fiGate.app 正在單一常駐模式下輪詢 Apple Messages、轉發請求到 OpenClaw，並回送 iMessage。"
        lastError = nil
        statusText = "Single-App Resident Mode / 單一常駐模式"
        detailText = "fiGate.app is the only gateway runtime. Closing the dashboard window does not stop iMessage polling. / fiGate.app 是唯一的 gateway runtime。關閉 dashboard 視窗不會停止 iMessage 輪詢。"
    }

    private func applyStoppedState(_ errorDescription: String) {
        gatewayRuntimeMode = .stopped
        gatewayRuntimeStatusText = "Not Running / 未運行"
        gatewayRuntimeDetailText = errorDescription
        lastError = errorDescription
        statusText = "Single-App Resident Mode / 單一常駐模式"
        detailText = "fiGate.app could not start the resident gateway runner for iMessage and OpenClaw relay. / fiGate.app 無法啟動用於 iMessage 與 OpenClaw relay 的常駐 gateway runner。"
    }
}
