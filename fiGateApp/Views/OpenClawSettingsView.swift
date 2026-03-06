import SwiftUI
import fiGateCore

struct OpenClawSettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @State private var isTesting = false
    @State private var testMessage = ""
    @State private var saveMessage = ""

    var body: some View {
        Form {
            Section("OpenClaw / External System / 外部系統") {
                TextField("Webhook Endpoint / Webhook 端點", text: $configManager.config.openClawEndpoint)
                SecureField("Access Token / 存取權杖", text: $configManager.config.openClawToken)
                Text("fiGate is a macOS iMessage gateway for OpenClaw, Apple Messages automation, and Telegram Bot alternative workflows. OpenClaw is the default webhook adapter, and the endpoint remains user-configurable. / fiGate 是一個用於 OpenClaw、Apple Messages automation 與 Telegram Bot 替代工作流的 macOS iMessage gateway。OpenClaw 是預設 webhook adapter，但端點可由使用者自行設定。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Save Settings / 儲存設定") {
                        Task {
                            let saved = await configManager.save()
                            saveMessage = saved ? "External system settings saved. / 外部系統設定已儲存。" : "Failed to save external system settings. / 外部系統設定儲存失敗。"
                        }
                    }

                    Button(isTesting ? "Testing... / 測試中..." : "Test Connection / 測試連線") {
                        Task {
                            await testConnection()
                        }
                    }
                    .disabled(isTesting)
                }

                if !saveMessage.isEmpty {
                    Text(saveMessage)
                        .foregroundStyle(saveMessage.hasPrefix("Failed") ? .red : .secondary)
                }

                if !testMessage.isEmpty {
                    Text(testMessage)
                        .foregroundStyle(testMessage.hasPrefix("Failed") ? .red : .secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("OpenClaw / External System / 外部系統")
    }

    @MainActor
    private func testConnection() async {
        let trimmedEndpoint = configManager.config.openClawEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let endpointURL = URL(string: trimmedEndpoint) else {
            testMessage = "Failed: invalid external system endpoint. / 錯誤：外部系統端點無效。"
            return
        }

        isTesting = true
        defer { isTesting = false }

        do {
            let response = try await OpenClawClient().testConnection(
                endpoint: endpointURL,
                token: configManager.config.openClawToken
            )

            let reply = response.replyText.trimmingCharacters(in: .whitespacesAndNewlines)
            if reply.isEmpty {
                testMessage = "Connected successfully. External system returned HTTP \(response.statusCode). / 連線成功，外部系統回傳 HTTP \(response.statusCode)。"
            } else {
                testMessage = "Connected successfully. Reply: \(reply) / 連線成功，回覆：\(reply)"
            }
        } catch {
            testMessage = "Failed: \(error.localizedDescription) / 連線失敗：\(error.localizedDescription)"
        }
    }
}
