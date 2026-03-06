import SwiftUI
import fiGateCore

struct PermissionSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("fiGate.hasSeenPermissionSetup") private var hasSeenPermissionSetup = false
    @StateObject private var model = PermissionSetupModel()
    @State private var actionStatus: String?

    let isFirstLaunch: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Permission Setup")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("fiGate 需要 Full Disk Access 才能讀取 `~/Library/Messages/chat.db`。這個權限無法在 app 內直接授予，仍需你在系統設定中手動打開。")
                .foregroundStyle(.secondary)

            PermissionSetupStatusCard(
                isAccessible: model.isAccessible,
                detail: model.detailText
            )

            GroupBox("fiGate.app Path") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(SystemSettingsNavigator.fiGateAppPath)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("如果系統設定頁無法直接選中 fiGate，可先複製這個路徑，再拖曳或手動定位 app。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Recommended Steps")
                    .font(.headline)

                Text("1. 點擊 Open Full Disk Access Settings")
                Text("2. 在系統設定中為 fiGate 打開 Full Disk Access")
                Text("3. 回到 fiGate，點擊 Run Database Access Check")
                Text("4. 狀態變成綠色後即可正常監聽與回覆 iMessage")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Open Full Disk Access Settings") {
                    if SystemSettingsNavigator.openFullDiskAccessSettings() {
                        actionStatus = nil
                    } else {
                        actionStatus = "Unable to open System Settings automatically."
                    }
                }

                Button("Copy fiGate.app Path") {
                    if SystemSettingsNavigator.copyFiGateAppPathToPasteboard() {
                        actionStatus = "fiGate.app path copied."
                    } else {
                        actionStatus = "Unable to copy fiGate.app path."
                    }
                }

                Button(model.isRunningCheck ? "Checking…" : "Run Database Access Check") {
                    Task {
                        await model.refresh()
                    }
                }
                .disabled(model.isRunningCheck)
            }

            if let actionStatus {
                Text(actionStatus)
                    .foregroundStyle(actionStatus.contains("Unable") ? .red : .secondary)
            }

            Spacer()

            HStack {
                if !model.isAccessible {
                    Text("Current status: Not yet authorized")
                        .foregroundStyle(.red)
                } else {
                    Text("Current status: Ready")
                        .foregroundStyle(.green)
                }

                Spacer()

                Button(isFirstLaunch ? "Continue to fiGate" : "Done") {
                    hasSeenPermissionSetup = true
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 720, minHeight: 480)
        .task {
            await model.refresh()
        }
    }
}

private struct PermissionSetupStatusCard: View {
    let isAccessible: Bool
    let detail: String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isAccessible ? Color.green : Color.red)
                        .frame(width: 10, height: 10)

                    Text(isAccessible ? "Full Disk Access is active" : "Full Disk Access is missing")
                        .font(.headline)
                }

                Text(detail)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

@MainActor
private final class PermissionSetupModel: ObservableObject {
    @Published var isAccessible = false
    @Published var detailText = "Checking database access…"
    @Published var isRunningCheck = false

    private let messageListener = MessageListener()
    private let configStore = ConfigStore()

    func refresh() async {
        guard !isRunningCheck else {
            return
        }

        isRunningCheck = true
        defer { isRunningCheck = false }

        do {
            let config = try await configStore.load()
            await messageListener.updateChatDatabasePath(config.chatDatabasePath)
            let diagnostic = await messageListener.diagnoseDatabaseAccess(for: .fiGateApp)
            isAccessible = diagnostic.isAccessible
            detailText = diagnostic.detail
        } catch {
            isAccessible = false
            detailText = error.localizedDescription
        }
    }
}
