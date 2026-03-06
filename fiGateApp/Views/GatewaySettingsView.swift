import SwiftUI
import fiGateCore

struct GatewaySettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @State private var saveResult = ""

    var body: some View {
        Form {
            Section("Gateway / 閘道") {
                Picker("Polling Interval / 輪詢間隔", selection: $configManager.config.pollInterval) {
                    ForEach(PollInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }

                TextField("Messages chat.db Path / Messages chat.db 路徑", text: $configManager.config.chatDatabasePath)
                Text("fiGate polls Apple Messages chat.db on macOS and forwards approved iMessage events to OpenClaw or other webhook-based automation systems. / fiGate 會在 macOS 上輪詢 Apple Messages chat.db，並將符合條件的 iMessage 事件轉發到 OpenClaw 或其他以 webhook 為基礎的自動化系統。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Save Settings / 儲存設定") {
                        Task {
                            let saved = await configManager.save()
                            saveResult = saved ? "Gateway settings saved. / 閘道設定已儲存。" : "Failed to save gateway settings. / 閘道設定儲存失敗。"
                        }
                    }

                    Text(saveResult)
                        .foregroundStyle(saveResult.hasPrefix("Failed") ? .red : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Gateway Settings / 閘道設定")
    }
}
