import Foundation

public actor GatewayRunner {
    private let configStore: ConfigStore
    private let messageListener: MessageListener
    private let sourceFilter: SourceFilter
    private let relayClient: any ExternalMessageRelayClient
    private let messageSender: any MessageSending
    private let logger: Logger
    private let pollingEngine: PollingEngine
    private let nowProvider: @Sendable () -> Date

    private var currentInterval: PollInterval?
    private var isPolling = false
    private var hasStarted = false

    public init(
        configStore: ConfigStore = ConfigStore(),
        messageListener: MessageListener = MessageListener(),
        sourceFilter: SourceFilter? = nil,
        relayClient: any ExternalMessageRelayClient = OpenClawClient(),
        messageSender: any MessageSending = MessageSender(),
        logger: Logger = .shared,
        nowProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.configStore = configStore
        self.messageListener = messageListener
        self.sourceFilter = sourceFilter ?? SourceFilter(configStore: configStore)
        self.relayClient = relayClient
        self.messageSender = messageSender
        self.logger = logger
        self.pollingEngine = PollingEngine()
        self.nowProvider = nowProvider
    }

    public func start() async throws {
        guard !hasStarted else {
            return
        }

        let config = try await configStore.load()
        currentInterval = config.pollInterval

        await messageListener.updateChatDatabasePath(config.chatDatabasePath)
        try await messageListener.primeCursor()

        await logger.log("fiGate resident gateway started with polling interval \(config.pollInterval.displayName).", channel: .gateway)
        hasStarted = true

        pollingEngine.start { [weak self] in
            await self?.pollCycle()
        }
    }

    public func runPollCycleNow() async {
        await pollCycle()
    }

    public func stop() async {
        pollingEngine.stop()
        hasStarted = false
        await logger.log("fiGate resident gateway stopped.", channel: .gateway)
    }

    private func pollCycle() async {
        guard !isPolling else {
            await logger.log("Skipping polling cycle because the previous cycle is still running.", channel: .gateway)
            return
        }

        isPolling = true
        defer { isPolling = false }

        do {
            let config = try await configStore.load()
            await applyConfigIfNeeded(config)

            let incomingMessages = try await messageListener.fetchNewMessages()
            if incomingMessages.isEmpty {
                return
            }

            for message in incomingMessages {
                if message.isFromMe {
                    let originDescription = message.isSentByFiGate ? "fiGate-generated" : "manually authored"
                    await logger.log(
                        "Skipped \(originDescription) self message \(message.id). fiGate only processes inbound messages from other senders.",
                        channel: .gateway
                    )
                    continue
                }

                if message.isFiGateTagged {
                    await logger.log("Ignored fiGate-tagged inbound message \(message.id) from \(message.source).", channel: .gateway)
                    continue
                }

                if !(await sourceFilter.isAllowed(sender: message.source)) {
                    await logger.log("Ignored message from unauthorized source \(message.source).", channel: .gateway)
                    continue
                }

                await logger.log("Received from \(message.source): \(message.text)", channel: .message)

                let acknowledgement = MessageEvent.receivedAcknowledgementText(at: nowProvider())
                try await messageSender.send(acknowledgement, to: message.source)
                await logger.log("Acknowledged receipt to \(message.source): \(acknowledgement)", channel: .gateway)

                guard let endpointURL = URL(string: config.openClawEndpoint) else {
                    await logger.log("Invalid external system endpoint: \(config.openClawEndpoint)", channel: .error)
                    continue
                }

                let response = try await relayClient.forward(message, endpoint: endpointURL, token: config.openClawToken)
                let reply = response.replyText.trimmingCharacters(in: .whitespacesAndNewlines)

                if reply.isEmpty {
                    await logger.log("External system returned an empty response for message \(message.id).", channel: .gateway)
                    continue
                }

                try await messageSender.send(reply, to: message.source)
                await logger.log("Replied to \(message.source): \(reply)", channel: .gateway)
            }
        } catch {
            await logger.log("Polling cycle failed: \(error.localizedDescription)", channel: .error)
        }
    }

    private func applyConfigIfNeeded(_ config: Config) async {
        await messageListener.updateChatDatabasePath(config.chatDatabasePath)

        guard currentInterval != config.pollInterval else {
            return
        }

        currentInterval = config.pollInterval
        pollingEngine.update(interval: config.pollInterval)
        await logger.log("Updated polling interval to \(config.pollInterval.displayName).", channel: .gateway)
    }
}
