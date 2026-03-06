import SwiftUI
import fiGateCore

struct SourcesView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @State private var newSource = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Allowed Sources")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Only configured phone numbers, email addresses, or Apple IDs can trigger the gateway.")
                .foregroundStyle(.secondary)

            HStack {
                TextField("Add phone number, email, or Apple ID", text: $newSource)

                Button("Add Source") {
                    let trimmedSource = newSource.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedSource.isEmpty else {
                        return
                    }

                    Task {
                        configManager.addSource(trimmedSource)
                        if await configManager.save() {
                            newSource = ""
                        }
                    }
                }
                .disabled(newSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            List {
                if configManager.config.allowedSources.isEmpty {
                    Text("No allowed sources configured.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(configManager.config.allowedSources) { source in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.value)
                                    .font(.body)
                                Text(source.kind.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Remove") {
                                Task {
                                    configManager.removeSource(source)
                                    _ = await configManager.save()
                                }
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let error = configManager.lastSaveError {
                Text(error)
                    .foregroundStyle(.red)
            }
        }
        .padding(24)
    }
}
