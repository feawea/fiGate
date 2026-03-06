import Foundation

public final class PollingEngine {
    public typealias PollHandler = @Sendable () async -> Void

    private enum Mode: Sendable {
        case recentMessages
        case custom(PollHandler)
    }

    private let queue: DispatchQueue
    private let queueKey = DispatchSpecificKey<Void>()
    private let messageListener: MessageListener

    private var timer: DispatchSourceTimer?
    private var interval: PollInterval
    private var mode: Mode = .recentMessages
    private var isPolling = false

    public init(
        messageListener: MessageListener = MessageListener(),
        interval: PollInterval = .seconds15,
        label: String = "com.figate.polling"
    ) {
        self.messageListener = messageListener
        self.interval = interval
        self.queue = DispatchQueue(label: label, qos: .utility)
        self.queue.setSpecific(key: queueKey, value: ())
    }

    public func startPolling() {
        performSync {
            mode = .recentMessages
            installTimerLocked()
        }
    }

    public func start(handler: @escaping PollHandler) {
        performSync {
            mode = .custom(handler)
            installTimerLocked()
        }
    }

    public func update(interval: PollInterval) {
        performSync {
            guard self.interval != interval else {
                return
            }

            self.interval = interval

            if timer != nil {
                installTimerLocked()
            }
        }
    }

    public func fireNow() {
        performSync {
            pollIfNeededLocked()
        }
    }

    public func stop() {
        performSync {
            stopTimerLocked()
            isPolling = false
        }
    }

    deinit {
        stop()
    }

    private func installTimerLocked() {
        stopTimerLocked()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        let repeatingInterval = DispatchTimeInterval.seconds(interval.rawValue)

        timer.schedule(deadline: .now(), repeating: repeatingInterval)
        timer.setEventHandler { [weak self] in
            self?.pollIfNeededLocked()
        }

        self.timer = timer
        timer.resume()

        print("fiGate PollingEngine started with interval \(interval.displayName).")
    }

    private func stopTimerLocked() {
        timer?.setEventHandler {}
        timer?.cancel()
        timer = nil
    }

    private func pollIfNeededLocked() {
        guard !isPolling else {
            print("fiGate PollingEngine skipped a poll because the previous cycle is still running.")
            return
        }

        isPolling = true
        let mode = self.mode

        Task(priority: .utility) { [weak self] in
            guard let self else {
                return
            }

            defer {
                self.performAsync {
                    self.isPolling = false
                }
            }

            switch mode {
            case .recentMessages:
                await self.pollRecentMessages()
            case .custom(let handler):
                await handler()
            }
        }
    }

    private func pollRecentMessages() async {
        let messages = await messageListener.fetchRecentMessages()

        guard !messages.isEmpty else {
            return
        }

        print("fiGate PollingEngine fetched \(messages.count) recent messages.")
    }

    private func performSync(_ operation: () -> Void) {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            operation()
        } else {
            queue.sync(execute: operation)
        }
    }

    private func performAsync(_ operation: @escaping () -> Void) {
        queue.async(execute: operation)
    }
}
