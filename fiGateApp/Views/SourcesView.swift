import SwiftUI
import fiGateCore

struct SourcesView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @State private var newSource = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Allowed Sources / 允許來源")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Only configured phone numbers, email addresses, or Apple IDs can trigger the iMessage gateway and OpenClaw workflow. This keeps fiGate focused on approved Apple Messages contacts and makes it a safer Telegram Bot alternative. / 只有已設定的電話號碼、電子郵件或 Apple ID 才能觸發 iMessage gateway 與 OpenClaw 工作流。這能讓 fiGate 專注於核准的 Apple Messages 聯絡人，也讓它成為更安全的 Telegram Bot 替代方案。")
                .foregroundStyle(.secondary)

            HStack {
                TextField("Add phone number, email, or Apple ID / 新增電話、電子郵件或 Apple ID", text: $newSource)

                Button("Add Source / 新增來源") {
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
                    Text("No allowed sources configured. / 尚未設定允許來源。")
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

                            Button("Remove / 移除") {
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
