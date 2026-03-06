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
            Text("Permission Setup / 權限設定")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("fiGate needs Full Disk Access to read `~/Library/Messages/chat.db` for iMessage gateway, OpenClaw relay, and Telegram Bot alternative workflows. This permission cannot be granted inside the app and must still be enabled manually in System Settings. / fiGate 需要 Full Disk Access 才能讀取 `~/Library/Messages/chat.db`，以支援 iMessage gateway、OpenClaw relay 與 Telegram Bot 替代工作流。這個權限無法在 app 內直接授予，仍需你在系統設定中手動開啟。")
                .foregroundStyle(.secondary)

            PermissionSetupStatusCard(
                isAccessible: model.isAccessible,
                detail: model.detailText
            )

            GroupBox("fiGate.app Path / fiGate.app 路徑") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(SystemSettingsNavigator.fiGateAppPath)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("If System Settings cannot locate fiGate automatically, copy this path first and then drag or locate the app manually. / 如果系統設定頁無法直接找到 fiGate，可先複製這個路徑，再拖曳或手動定位 app。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Recommended Steps / 建議步驟")
                    .font(.headline)

                Text("1. Click Open Full Disk Access Settings / 點擊 Open Full Disk Access Settings")
                Text("2. Enable Full Disk Access for fiGate in System Settings / 在系統設定中為 fiGate 打開 Full Disk Access")
                Text("3. Return to fiGate and click Run Database Access Check / 回到 fiGate，點擊 Run Database Access Check")
                Text("4. Once the status turns green, iMessage listening and auto-replies are ready / 狀態變成綠色後即可正常監聽與回覆 iMessage")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button("Open Full Disk Access Settings / 開啟 Full Disk Access 設定") {
                    if SystemSettingsNavigator.openFullDiskAccessSettings() {
                        actionStatus = nil
                    } else {
                        actionStatus = "Unable to open System Settings automatically. / 無法自動開啟系統設定。"
                    }
                }

                Button("Copy fiGate.app Path / 複製 fiGate.app 路徑") {
                    if SystemSettingsNavigator.copyFiGateAppPathToPasteboard() {
                        actionStatus = "fiGate.app path copied. / fiGate.app 路徑已複製。"
                    } else {
                        actionStatus = "Unable to copy fiGate.app path. / 無法複製 fiGate.app 路徑。"
                    }
                }

                Button(model.isRunningCheck ? "Checking… / 檢查中…" : "Run Database Access Check / 執行資料庫權限檢查") {
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
                    Text("Current status: Not yet authorized / 目前狀態：尚未授權")
                        .foregroundStyle(.red)
                } else {
                    Text("Current status: Ready / 目前狀態：可用")
                        .foregroundStyle(.green)
                }

                Spacer()

                Button(isFirstLaunch ? "Continue to fiGate / 繼續使用 fiGate" : "Done / 完成") {
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

                    Text(isAccessible ? "Full Disk Access is active / 已取得 Full Disk Access" : "Full Disk Access is missing / 尚未取得 Full Disk Access")
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
    @Published var detailText = "Checking database access… / 正在檢查資料庫權限…"
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
