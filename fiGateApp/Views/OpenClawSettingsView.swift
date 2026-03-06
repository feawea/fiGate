import SwiftUI
import fiGateCore

struct OpenClawSettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @State private var isTesting = false
    @State private var testMessage = ""
    @State private var saveMessage = ""

    var body: some View {
        Form {
            Section("External System") {
                TextField("Webhook Endpoint", text: $configManager.config.openClawEndpoint)
                SecureField("Access Token", text: $configManager.config.openClawToken)
                Text("fiGate is the gateway layer. OpenClaw is the default webhook adapter, but the endpoint is user-configurable.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                HStack {
                    Button("Save Settings") {
                        Task {
                            let saved = await configManager.save()
                            saveMessage = saved ? "External system settings saved." : "Failed to save external system settings."
                        }
                    }

                    Button(isTesting ? "Testing..." : "Test Connection") {
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
        .navigationTitle("External System")
    }

    @MainActor
    private func testConnection() async {
        let trimmedEndpoint = configManager.config.openClawEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let endpointURL = URL(string: trimmedEndpoint) else {
            testMessage = "Failed: invalid external system endpoint."
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
                testMessage = "Connected successfully. External system returned HTTP \(response.statusCode)."
            } else {
                testMessage = "Connected successfully. Reply: \(reply)"
            }
        } catch {
            testMessage = "Failed: \(error.localizedDescription)"
        }
    }
}
