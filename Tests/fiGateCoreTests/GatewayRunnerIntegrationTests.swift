import Foundation
import SQLite3
import XCTest
@testable import fiGateCore

final class GatewayRunnerIntegrationTests: XCTestCase {
    private var tempDirectoryURL: URL!
    private var databaseURL: URL!

    override func setUpWithError() throws {
        tempDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("fiGateTests-\(UUID().uuidString)", isDirectory: true)
        databaseURL = tempDirectoryURL.appendingPathComponent("chat.db")

        try FileManager.default.createDirectory(at: tempDirectoryURL, withIntermediateDirectories: true)
        setenv("FIGATE_APP_SUPPORT_DIRECTORY", tempDirectoryURL.path, 1)
        try createMessagesDatabase(at: databaseURL)
    }

    override func tearDownWithError() throws {
        unsetenv("FIGATE_APP_SUPPORT_DIRECTORY")
        if let tempDirectoryURL {
            try? FileManager.default.removeItem(at: tempDirectoryURL)
        }
    }

    func testGatewayRunnerProcessesAllowedIncomingMessage() async throws {
        try insertMessage(text: "baseline", sender: "+10000000000", isFromMe: false)
        let acknowledgementDate = makeDate(
            year: 2026,
            month: 3,
            day: 6,
            hour: 20,
            minute: 36,
            timeZone: .current
        )

        let configStore = ConfigStore()
        try await configStore.save(
            Config(
                pollInterval: .minutes30,
                chatDatabasePath: databaseURL.path,
                openClawEndpoint: "http://127.0.0.1:18789/hooks/wake",
                openClawToken: "test-token",
                allowedSources: [Source(value: "+15551234567")]
            )
        )

        let relay = RecordingRelayClient(replyText: "Task completed")
        let sender = RecordingMessageSender()
        let runner = GatewayRunner(
            configStore: configStore,
            messageListener: MessageListener(chatDatabasePath: databaseURL.path),
            sourceFilter: SourceFilter(configStore: configStore),
            relayClient: relay,
            messageSender: sender,
            logger: Logger.shared,
            nowProvider: { acknowledgementDate }
        )

        try await runner.start()
        try await Task.sleep(for: .milliseconds(200))

        try insertMessage(text: "build ios", sender: "+15551234567", isFromMe: false)
        await runner.runPollCycleNow()
        await runner.stop()

        let forwarded = await relay.forwardedMessages
        let sentReplies = await sender.sentMessages

        XCTAssertEqual(forwarded.count, 1)
        XCTAssertEqual(forwarded.first?.source, "+15551234567")
        XCTAssertEqual(forwarded.first?.text, "build ios")

        XCTAssertEqual(sentReplies.count, 2)
        XCTAssertEqual(sentReplies.first?.recipient, "+15551234567")
        XCTAssertEqual(
            sentReplies.first?.text,
            MessageEvent.receivedAcknowledgementText(at: acknowledgementDate)
        )
        XCTAssertEqual(sentReplies.last?.recipient, "+15551234567")
        XCTAssertEqual(sentReplies.last?.text, "[fiGate] Task completed")
    }

    func testGatewayRunnerIgnoresUnauthorizedIncomingMessage() async throws {
        try insertMessage(text: "baseline", sender: "+10000000000", isFromMe: false)

        let configStore = ConfigStore()
        try await configStore.save(
            Config(
                pollInterval: .minutes30,
                chatDatabasePath: databaseURL.path,
                openClawEndpoint: "http://127.0.0.1:18789/hooks/wake",
                openClawToken: "test-token",
                allowedSources: [Source(value: "+15551234567")]
            )
        )

        let relay = RecordingRelayClient(replyText: "Task completed")
        let sender = RecordingMessageSender()
        let runner = GatewayRunner(
            configStore: configStore,
            messageListener: MessageListener(chatDatabasePath: databaseURL.path),
            sourceFilter: SourceFilter(configStore: configStore),
            relayClient: relay,
            messageSender: sender,
            logger: Logger.shared
        )

        try await runner.start()
        try await Task.sleep(for: .milliseconds(200))

        try insertMessage(text: "rm -rf /", sender: "+19999999999", isFromMe: false)
        await runner.runPollCycleNow()
        await runner.stop()

        let forwarded = await relay.forwardedMessages
        let sentReplies = await sender.sentMessages

        XCTAssertTrue(forwarded.isEmpty)
        XCTAssertTrue(sentReplies.isEmpty)
    }

    func testGatewayRunnerAcknowledgesIncomingMessageWhenRelayFails() async throws {
        try insertMessage(text: "baseline", sender: "+10000000000", isFromMe: false)
        let acknowledgementDate = makeDate(
            year: 2026,
            month: 3,
            day: 6,
            hour: 20,
            minute: 45,
            timeZone: .current
        )

        let configStore = ConfigStore()
        try await configStore.save(
            Config(
                pollInterval: .minutes30,
                chatDatabasePath: databaseURL.path,
                openClawEndpoint: "http://127.0.0.1:18789/hooks/wake",
                openClawToken: "",
                allowedSources: [Source(value: "tester@example.com")]
            )
        )

        let relay = ThrowingRelayClient()
        let sender = RecordingMessageSender()
        let runner = GatewayRunner(
            configStore: configStore,
            messageListener: MessageListener(chatDatabasePath: databaseURL.path),
            sourceFilter: SourceFilter(configStore: configStore),
            relayClient: relay,
            messageSender: sender,
            logger: Logger.shared,
            nowProvider: { acknowledgementDate }
        )

        try await runner.start()
        try await Task.sleep(for: .milliseconds(200))

        try insertMessage(text: "hello from iphone", sender: "tester@example.com", isFromMe: false)
        await runner.runPollCycleNow()
        await runner.stop()

        let sentReplies = await sender.sentMessages

        XCTAssertEqual(sentReplies.count, 1)
        XCTAssertEqual(sentReplies.first?.recipient, "tester@example.com")
        XCTAssertEqual(
            sentReplies.first?.text,
            MessageEvent.receivedAcknowledgementText(at: acknowledgementDate)
        )
    }

    func testGatewayRunnerIgnoresFiGateTaggedIncomingMessage() async throws {
        try insertMessage(text: "baseline", sender: "+10000000000", isFromMe: false)

        let configStore = ConfigStore()
        try await configStore.save(
            Config(
                pollInterval: .minutes30,
                chatDatabasePath: databaseURL.path,
                openClawEndpoint: "http://127.0.0.1:18789/hooks/wake",
                openClawToken: "test-token",
                allowedSources: [Source(value: "tester@example.com")]
            )
        )

        let relay = RecordingRelayClient(replyText: "Task completed")
        let sender = RecordingMessageSender()
        let runner = GatewayRunner(
            configStore: configStore,
            messageListener: MessageListener(chatDatabasePath: databaseURL.path),
            sourceFilter: SourceFilter(configStore: configStore),
            relayClient: relay,
            messageSender: sender,
            logger: Logger.shared
        )

        try await runner.start()
        try await Task.sleep(for: .milliseconds(200))

        try insertMessage(
            text: "[fiGate]Recieved.(03-06 20:36)",
            sender: "tester@example.com",
            isFromMe: false
        )
        await runner.runPollCycleNow()
        await runner.stop()

        let forwarded = await relay.forwardedMessages
        let sentReplies = await sender.sentMessages

        XCTAssertTrue(forwarded.isEmpty)
        XCTAssertTrue(sentReplies.isEmpty)
    }

    func testMessageListenerFallsBackToAttributedBodyWhenTextIsEmpty() async throws {
        let fallbackText = "attributed body message"
        let archivedBody = NSArchiver.archivedData(withRootObject: NSAttributedString(string: fallbackText))

        try insertMessage(
            text: "",
            sender: "tester@example.com",
            isFromMe: false,
            attributedBody: archivedBody
        )

        let listener = MessageListener(chatDatabasePath: databaseURL.path)
        let messages = try await listener.fetchRecentMessagesOrThrow(limit: 1)

        XCTAssertEqual(messages.first?.text, fallbackText)
        XCTAssertEqual(messages.first?.sender, "tester@example.com")
    }

    func testFiGatePrefixRuleAvoidsDoublePrefixing() {
        XCTAssertEqual(
            MessageEvent.fiGatePrefixedText("Task completed"),
            "[fiGate] Task completed"
        )
        XCTAssertEqual(
            MessageEvent.fiGatePrefixedText("[fiGate] Task completed"),
            "[fiGate] Task completed"
        )
        XCTAssertEqual(
            MessageEvent.receivedAcknowledgementText(
                at: makeDate(
                    year: 2026,
                    month: 3,
                    day: 6,
                    hour: 12,
                    minute: 34,
                    timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt
                ),
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: TimeZone(secondsFromGMT: 0) ?? .gmt
            ),
            "[fiGate]Recieved.(03-06 12:34)"
        )
    }

    private func createMessagesDatabase(at url: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK else {
            defer { sqlite3_close(database) }
            throw XCTSkip("Unable to create test Messages database.")
        }

        defer { sqlite3_close(database) }

        let statements = [
            "CREATE TABLE handle (ROWID INTEGER PRIMARY KEY AUTOINCREMENT, id TEXT NOT NULL);",
            """
            CREATE TABLE message (
                ROWID INTEGER PRIMARY KEY AUTOINCREMENT,
                text TEXT,
                attributedBody BLOB,
                date INTEGER NOT NULL,
                is_from_me INTEGER NOT NULL DEFAULT 0,
                handle_id INTEGER
            );
            """,
        ]

        for sql in statements {
            guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
                throw XCTSkip("Unable to initialize test Messages schema.")
            }
        }
    }

    private func insertMessage(
        text: String,
        sender: String,
        isFromMe: Bool,
        attributedBody: Data? = nil
    ) throws {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK else {
            defer { sqlite3_close(database) }
            throw XCTSkip("Unable to open test Messages database.")
        }

        defer { sqlite3_close(database) }

        let handleID = try insertHandleIfNeeded(sender: sender, database: database)
        let rawDate = Int64(Date().timeIntervalSinceReferenceDate)
        let sql = "INSERT INTO message (text, attributedBody, date, is_from_me, handle_id) VALUES (?, ?, ?, ?, ?);"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw XCTSkip("Unable to prepare test message insert.")
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, text, -1, sqliteTransientDestructor)

        if let attributedBody {
            _ = attributedBody.withUnsafeBytes { rawBuffer in
                sqlite3_bind_blob(statement, 2, rawBuffer.baseAddress, Int32(rawBuffer.count), sqliteTransientDestructor)
            }
        } else {
            sqlite3_bind_null(statement, 2)
        }

        sqlite3_bind_int64(statement, 3, rawDate)
        sqlite3_bind_int(statement, 4, isFromMe ? 1 : 0)
        sqlite3_bind_int64(statement, 5, handleID)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw XCTSkip("Unable to insert test message.")
        }
    }

    private func insertHandleIfNeeded(sender: String, database: OpaquePointer?) throws -> Int64 {
        let querySQL = "SELECT ROWID FROM handle WHERE id = ? LIMIT 1;"
        var query: OpaquePointer?

        guard sqlite3_prepare_v2(database, querySQL, -1, &query, nil) == SQLITE_OK else {
            throw XCTSkip("Unable to prepare handle lookup.")
        }

        defer { sqlite3_finalize(query) }
        sqlite3_bind_text(query, 1, sender, -1, sqliteTransientDestructor)

        if sqlite3_step(query) == SQLITE_ROW {
            return sqlite3_column_int64(query, 0)
        }

        let insertSQL = "INSERT INTO handle (id) VALUES (?);"
        var insert: OpaquePointer?

        guard sqlite3_prepare_v2(database, insertSQL, -1, &insert, nil) == SQLITE_OK else {
            throw XCTSkip("Unable to prepare handle insert.")
        }

        defer { sqlite3_finalize(insert) }
        sqlite3_bind_text(insert, 1, sender, -1, sqliteTransientDestructor)

        guard sqlite3_step(insert) == SQLITE_DONE else {
            throw XCTSkip("Unable to insert handle.")
        }

        return sqlite3_last_insert_rowid(database)
    }
}

private func makeDate(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    timeZone: TimeZone
) -> Date {
    var components = DateComponents()
    components.calendar = Calendar(identifier: .gregorian)
    components.timeZone = timeZone
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    components.minute = minute
    return components.date ?? Date(timeIntervalSince1970: 0)
}

private actor RecordingRelayClient: ExternalMessageRelayClient {
    struct ForwardedMessage: Equatable {
        let source: String
        let text: String
    }

    private let cannedReply: String
    private(set) var forwardedMessages: [ForwardedMessage] = []

    init(replyText: String) {
        self.cannedReply = replyText
    }

    func forward(_ message: MessageEvent, endpoint: URL, token: String) async throws -> ExternalSystemResponse {
        forwardedMessages.append(ForwardedMessage(source: message.source, text: message.text))
        return ExternalSystemResponse(statusCode: 200, body: cannedReply)
    }

    func send(source: String, text: String, endpoint: URL, token: String) async throws -> ExternalSystemResponse {
        forwardedMessages.append(ForwardedMessage(source: source, text: text))
        return ExternalSystemResponse(statusCode: 200, body: cannedReply)
    }

    func testConnection(endpoint: URL, token: String) async throws -> ExternalSystemResponse {
        ExternalSystemResponse(statusCode: 200, body: "ok")
    }
}

private actor ThrowingRelayClient: ExternalMessageRelayClient {
    func forward(_ message: MessageEvent, endpoint: URL, token: String) async throws -> ExternalSystemResponse {
        throw OpenClawClientError.missingToken
    }

    func send(source: String, text: String, endpoint: URL, token: String) async throws -> ExternalSystemResponse {
        throw OpenClawClientError.missingToken
    }

    func testConnection(endpoint: URL, token: String) async throws -> ExternalSystemResponse {
        throw OpenClawClientError.missingToken
    }
}

private actor RecordingMessageSender: MessageSending {
    struct SentMessage: Equatable {
        let recipient: String
        let text: String
    }

    private(set) var sentMessages: [SentMessage] = []

    func send(_ text: String, to recipient: String) async throws {
        sentMessages.append(
            SentMessage(
                recipient: recipient,
                text: MessageEvent.fiGatePrefixedText(text)
            )
        )
    }
}

private let sqliteTransientDestructor = unsafeBitCast(
    OpaquePointer(bitPattern: -1),
    to: sqlite3_destructor_type.self
)
