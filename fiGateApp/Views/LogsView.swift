import SwiftUI
import fiGateCore

struct LogsView: View {
    @StateObject private var model = LogsViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Logs / 日誌")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text("Review runtime activity for iMessage polling, OpenClaw relay requests, Apple Messages auto-replies, and Telegram Bot alternative workflows. / 在這裡查看 iMessage 輪詢、OpenClaw relay 請求、Apple Messages 自動回覆，以及 Telegram Bot 替代工作流的執行紀錄。")
                .foregroundStyle(.secondary)

            Picker("Log Channel / 日誌頻道", selection: $model.selectedChannel) {
                ForEach(LogChannel.allCases) { channel in
                    Text(channel.displayName).tag(channel)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                Text(model.contents.isEmpty ? "No log entries yet. / 尚無日誌紀錄。" : model.contents)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
            .background(.quaternary.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(24)
        .task {
            model.start()
        }
        .task(id: model.selectedChannel) {
            await model.refresh()
        }
        .onDisappear {
            model.stop()
        }
    }
}

@MainActor
private final class LogsViewModel: ObservableObject {
    @Published var selectedChannel: LogChannel = .gateway
    @Published var contents = ""

    private var refreshTask: Task<Void, Never>?

    func start() {
        guard refreshTask == nil else {
            return
        }

        refreshTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func refresh() async {
        contents = await Logger.shared.read(channel: selectedChannel)
    }

    deinit {
        refreshTask?.cancel()
    }
}
