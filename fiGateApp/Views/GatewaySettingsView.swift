import SwiftUI
import fiGateCore

struct GatewaySettingsView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @State private var saveResult = ""

    var body: some View {
        Form {
            Section("Gateway") {
                Picker("Polling Interval", selection: $configManager.config.pollInterval) {
                    ForEach(PollInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }

                TextField("Messages chat.db Path", text: $configManager.config.chatDatabasePath)
            }

            Section {
                HStack {
                    Button("Save Settings") {
                        Task {
                            let saved = await configManager.save()
                            saveResult = saved ? "Gateway settings saved." : "Failed to save gateway settings."
                        }
                    }

                    Text(saveResult)
                        .foregroundStyle(saveResult.hasPrefix("Failed") ? .red : .secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Gateway Settings")
    }
}
