import AppKit
import SwiftUI
import fiGateCore

struct ResidentMenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var backgroundAgentManager: BackgroundAgentManager

    private var runtimeLabelColor: Color {
        backgroundAgentManager.isRunningNormally ? .green : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("fiGate")
                .font(.headline)

            HStack(spacing: 8) {
                Circle()
                    .fill(runtimeLabelColor)
                    .frame(width: 10, height: 10)

                Text(backgroundAgentManager.gatewayRuntimeStatusText)
                    .font(.subheadline)
            }

            Text("Polling / 輪詢: \(configManager.config.pollInterval.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(backgroundAgentManager.gatewayRuntimeDetailText)
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            Button("Open Dashboard / 開啟儀表板") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "dashboard")
            }

            Button("Refresh Runtime / 重新整理執行狀態") {
                Task {
                    await backgroundAgentManager.refreshStatus()
                }
            }

            Button("Restart Gateway / 重新啟動閘道") {
                Task {
                    await backgroundAgentManager.restartGateway()
                }
            }

            Divider()

            Button("Quit fiGate / 結束 fiGate") {
                NSApp.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 280)
    }
}
