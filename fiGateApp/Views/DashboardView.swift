import Foundation
import SwiftUI
import fiGateCore

struct DashboardView: View {
    @EnvironmentObject private var configManager: ConfigManager
    @EnvironmentObject private var backgroundAgentManager: BackgroundAgentManager
    @AppStorage("fiGate.hasSeenPermissionSetup") private var hasSeenPermissionSetup = false
    @StateObject private var model = DashboardModel()
    @State private var permissionActionStatus: String?
    @State private var isShowingPermissionSetup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                PermissionStatusBanner(
                    isAccessible: model.isChatDatabaseReadable,
                    detailText: model.permissionBannerText
                )

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 16) {
                    DashboardCard(title: "Gateway Status", value: configManager.gatewayStatusText)
                    DashboardCard(title: "App Mode", value: backgroundAgentManager.statusText)
                    DashboardCard(title: "Polling Interval", value: configManager.config.pollInterval.displayName)
                    DashboardCard(title: "External Endpoint", value: configManager.config.openClawEndpoint)
                    StatusDashboardCard(
                        title: "Gateway Runtime",
                        isHealthy: backgroundAgentManager.isRunningNormally,
                        healthyText: backgroundAgentManager.gatewayRuntimeStatusText,
                        unhealthyText: backgroundAgentManager.gatewayRuntimeStatusText
                    )
                    StatusDashboardCard(
                        title: "chat.db Access",
                        isHealthy: model.isChatDatabaseReadable,
                        healthyText: model.databaseAccessText,
                        unhealthyText: model.databaseAccessText
                    )
                }

                GroupBox("Resident Runtime") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(backgroundAgentManager.detailText)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(backgroundAgentManager.gatewayRuntimeDetailText)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)

                        HStack {
                            Button("Refresh Runtime") {
                                Task {
                                    await backgroundAgentManager.refreshStatus()
                                }
                            }

                            Button("Restart Gateway") {
                                Task {
                                    await backgroundAgentManager.restartGateway()
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("Permissions") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("fiGate.app needs Full Disk Access to read the local Messages database. Once granted, keep fiGate running to maintain the resident gateway.")
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack {
                            Button("Open Full Disk Access Settings") {
                                if SystemSettingsNavigator.openFullDiskAccessSettings() {
                                    permissionActionStatus = nil
                                } else {
                                    permissionActionStatus = "Unable to open System Settings automatically. Open Privacy & Security > Full Disk Access manually."
                                }
                            }

                            Button("Copy fiGate.app Path") {
                                if SystemSettingsNavigator.copyFiGateAppPathToPasteboard() {
                                    permissionActionStatus = "fiGate.app path copied."
                                } else {
                                    permissionActionStatus = "Unable to copy fiGate.app path."
                                }
                            }

                            Button(model.isRunningDiagnostic ? "Checking…" : "Run Database Access Check") {
                                Task {
                                    await model.runDatabaseAccessCheck()
                                }
                            }
                            .disabled(model.isRunningDiagnostic)

                            Button("Open Setup Guide") {
                                hasSeenPermissionSetup = false
                                isShowingPermissionSetup = true
                            }
                        }

                        if let permissionActionStatus {
                            Text(permissionActionStatus)
                                .foregroundStyle(permissionActionStatus.contains("Unable") ? .red : .secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Latest Activity")
                        .font(.title2)
                        .fontWeight(.medium)

                    GroupBox("Last Message Received") {
                        Text(model.lastMessageReceived)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }

                    GroupBox("Last Action Executed") {
                        Text(model.lastActionExecuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }

                    GroupBox("Last Error") {
                        Text(model.lastErrorRecorded)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Database Messages")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("This list is read directly by fiGate.app. In the single-app architecture, this is the same process that handles polling and auto-replies.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    GroupBox {
                        if let databaseReadError = model.databaseReadError {
                            Text(databaseReadError)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        } else if model.recentMessages.isEmpty {
                            Text("No recent text messages were read from chat.db.")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(model.recentMessages) { message in
                                    DatabaseMessageRow(message: message)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                if let saveError = configManager.lastSaveError {
                    Text(saveError)
                        .foregroundStyle(.red)
                }

                if let runtimeError = backgroundAgentManager.lastError {
                    Text(runtimeError)
                        .foregroundStyle(.red)
                }
            }
            .padding(24)
        }
        .task {
            model.start()
        }
        .task {
            while !Task.isCancelled {
                await backgroundAgentManager.refreshStatus()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onDisappear {
            model.stop()
        }
        .sheet(isPresented: $isShowingPermissionSetup) {
            PermissionSetupView(isFirstLaunch: false)
        }
    }
}

private struct PermissionStatusBanner: View {
    let isAccessible: Bool
    let detailText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isAccessible ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(isAccessible ? .green : .orange)

            VStack(alignment: .leading, spacing: 6) {
                Text(isAccessible ? "Full Disk Access Active" : "Full Disk Access Required")
                    .font(.headline)

                Text(detailText)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isAccessible ? Color.green.opacity(0.10) : Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isAccessible ? Color.green.opacity(0.35) : Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct DashboardCard: View {
    let title: String
    let value: String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(value)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct StatusDashboardCard: View {
    let title: String
    let isHealthy: Bool
    let healthyText: String
    let unhealthyText: String

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.headline)

                HStack(spacing: 8) {
                    Circle()
                        .fill(isHealthy ? Color.green : Color.red)
                        .frame(width: 10, height: 10)

                    Text(isHealthy ? healthyText : unhealthyText)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DatabaseMessageRow: View {
    let message: MessageEvent

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    private var senderLabel: String {
        let trimmedSender = message.sender.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedSender.isEmpty ? "No handle.id" : trimmedSender
    }

    private var directionLabel: String {
        if message.isSentByFiGate {
            return "fiGate"
        }

        return message.isFromMe ? "From Me" : "Incoming"
    }

    private var directionColor: Color {
        if message.isSentByFiGate {
            return .blue
        }

        return message.isFromMe ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(directionLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(directionColor)

                Text(senderLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(Self.timestampFormatter.string(from: message.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(message.text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

@MainActor
private final class DashboardModel: ObservableObject {
    @Published var lastMessageReceived = "No messages received yet."
    @Published var lastActionExecuted = "No actions recorded yet."
    @Published var lastErrorRecorded = "No errors recorded yet."
    @Published var recentMessages: [MessageEvent] = []
    @Published var databaseReadError: String?
    @Published var appDatabaseDiagnostic: DatabaseAccessDiagnostic?
    @Published var isRunningDiagnostic = false

    private var refreshTask: Task<Void, Never>?
    private let messageListener = MessageListener()
    private let configStore = ConfigStore()

    var isChatDatabaseReadable: Bool {
        appDatabaseDiagnostic?.isAccessible == true
    }

    var databaseAccessText: String {
        appDatabaseDiagnostic?.isAccessible == true ? "Readable in fiGate.app" : "Unavailable in fiGate.app"
    }

    var permissionBannerText: String {
        if let appDatabaseDiagnostic {
            return appDatabaseDiagnostic.detail
        }

        return "fiGate has not checked Messages database access yet."
    }

    func start() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task {
            await runDatabaseAccessCheck()

            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        lastMessageReceived = await Logger.shared.lastLine(channel: .message) ?? "No messages received yet."
        lastActionExecuted = await Logger.shared.lastLine(channel: .gateway) ?? "No actions recorded yet."

        do {
            let config = try await configStore.load()
            await messageListener.updateChatDatabasePath(config.chatDatabasePath)
            recentMessages = try await messageListener.fetchRecentMessagesOrThrow(limit: 2)
            databaseReadError = nil
            appDatabaseDiagnostic = DatabaseAccessDiagnostic(
                subject: .fiGateApp,
                status: .accessible,
                databasePath: ConfigPaths.expandedPath(config.chatDatabasePath),
                detail: "fiGate.app can read the Messages database.",
                recentTextMessageCount: recentMessages.count
            )
        } catch {
            recentMessages = []
            databaseReadError = error.localizedDescription
            appDatabaseDiagnostic = databaseDiagnostic(for: error)
        }

        let loggedError = await Logger.shared.lastLine(channel: .error)
        if let loggedError, !loggedError.isEmpty {
            lastErrorRecorded = loggedError
        } else if let databaseReadError, !databaseReadError.isEmpty {
            lastErrorRecorded = databaseReadError
        } else {
            lastErrorRecorded = "No errors recorded yet."
        }
    }

    func runDatabaseAccessCheck() async {
        guard !isRunningDiagnostic else {
            return
        }

        isRunningDiagnostic = true
        defer { isRunningDiagnostic = false }

        do {
            let config = try await configStore.load()
            await messageListener.updateChatDatabasePath(config.chatDatabasePath)
            appDatabaseDiagnostic = await messageListener.diagnoseDatabaseAccess(for: .fiGateApp)
        } catch {
            appDatabaseDiagnostic = .failed(
                subject: .fiGateApp,
                databasePath: ConfigPaths.expandedPath(Config.defaultChatDatabasePath),
                detail: "Unable to load fiGate configuration before running the app diagnostic: \(error.localizedDescription)"
            )
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    private func databaseDiagnostic(for error: Error) -> DatabaseAccessDiagnostic {
        let databasePath = ConfigPaths.expandedPath(Config.defaultChatDatabasePath)

        if let listenerError = error as? MessageListenerError {
            let status: DatabaseAccessStatus

            switch listenerError {
            case .databaseAccessDenied:
                status = .accessDenied
            case .databaseNotFound:
                status = .databaseNotFound
            case .databaseOpenFailed, .statementPreparationFailed, .statementExecutionFailed:
                status = .failed
            }

            return DatabaseAccessDiagnostic(
                subject: .fiGateApp,
                status: status,
                databasePath: databasePath,
                detail: listenerError.localizedDescription
            )
        }

        return .failed(
            subject: .fiGateApp,
            databasePath: databasePath,
            detail: error.localizedDescription
        )
    }
}
