import Foundation
import SQLite3

public enum MessageListenerError: LocalizedError {
    case databaseNotFound(String)
    case databaseAccessDenied(String)
    case databaseOpenFailed(String)
    case statementPreparationFailed(String)
    case statementExecutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .databaseNotFound(let message),
             .databaseAccessDenied(let message),
             .databaseOpenFailed(let message),
             .statementPreparationFailed(let message),
             .statementExecutionFailed(let message):
            return message
        }
    }
}

public actor MessageListener {
    private static let recentMessageLimit = 10

    private var chatDatabasePath: String
    private var lastSeenMessageID: Int64?
    private var lastLoggedMessageID: Int64?
    private let consoleDateFormatter: ISO8601DateFormatter

    public init(chatDatabasePath: String = "~/Library/Messages/chat.db") {
        self.chatDatabasePath = chatDatabasePath
        self.consoleDateFormatter = ISO8601DateFormatter()
        self.consoleDateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    public func updateChatDatabasePath(_ path: String) {
        let currentExpanded = expandedPath(from: chatDatabasePath)
        let nextExpanded = expandedPath(from: path)

        if currentExpanded != nextExpanded {
            lastSeenMessageID = nil
            lastLoggedMessageID = nil
        }

        chatDatabasePath = path
    }

    public func primeCursor() throws {
        lastSeenMessageID = try queryLatestMessageID()
    }

    public func fetchNewMessages() throws -> [MessageEvent] {
        let latestMessageID = try queryLatestMessageID()

        guard let latestMessageID else {
            return []
        }

        guard let lastSeenMessageID else {
            self.lastSeenMessageID = latestMessageID
            return []
        }

        guard latestMessageID > lastSeenMessageID else {
            return []
        }

        let messages = try queryMessages(after: lastSeenMessageID)
        self.lastSeenMessageID = messages.last?.id ?? latestMessageID
        logIfNeeded(messages)
        return messages
    }

    public func fetchRecentMessages() -> [MessageEvent] {
        do {
            return try fetchRecentMessagesOrThrow()
        } catch {
            print("fiGate MessageListener error: \(error.localizedDescription)")
            return []
        }
    }

    public func fetchRecentMessagesOrThrow(limit: Int? = nil) throws -> [MessageEvent] {
        let messages = try queryRecentMessages(limit: limit ?? Self.recentMessageLimit)
        logIfNeeded(messages)
        return messages
    }

    public func diagnoseDatabaseAccess(for subject: DatabaseAccessSubject) -> DatabaseAccessDiagnostic {
        let databasePath = expandedPath(from: chatDatabasePath)

        do {
            let latestMessageID = try queryLatestMessageID()
            let recentMessages = try queryRecentMessages(limit: Self.recentMessageLimit)
            let detail = """
            \(subject.displayName) can read the Messages database.
            Recent text messages fetched: \(recentMessages.count).
            """

            return DatabaseAccessDiagnostic(
                subject: subject,
                status: .accessible,
                databasePath: databasePath,
                detail: detail,
                latestMessageID: latestMessageID,
                recentTextMessageCount: recentMessages.count
            )
        } catch let error as MessageListenerError {
            return DatabaseAccessDiagnostic(
                subject: subject,
                status: status(for: error),
                databasePath: databasePath,
                detail: error.localizedDescription
            )
        } catch {
            return DatabaseAccessDiagnostic.failed(
                subject: subject,
                databasePath: databasePath,
                detail: error.localizedDescription
            )
        }
    }

    private func queryLatestMessageID() throws -> Int64? {
        try withDatabase { database in
            let sql = "SELECT MAX(ROWID) FROM message;"
            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MessageListenerError.statementPreparationFailed(database.lastErrorMessage)
            }

            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }

            guard sqlite3_column_type(statement, 0) != SQLITE_NULL else {
                return nil
            }

            return sqlite3_column_int64(statement, 0)
        }
    }

    private func queryRecentMessages(limit: Int) throws -> [MessageEvent] {
        try withDatabase { database in
            let sql = """
            SELECT
                message.ROWID,
                COALESCE(message.text, ''),
                message.date,
                message.is_from_me,
                message.attributedBody,
                COALESCE(handle.id, '')
            FROM message
            LEFT JOIN handle ON message.handle_id = handle.ROWID
            ORDER BY message.date DESC
            LIMIT ?;
            """

            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MessageListenerError.statementPreparationFailed(database.lastErrorMessage)
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int(statement, 1, Int32(limit))

            var events: [MessageEvent] = []

            while true {
                let stepResult = sqlite3_step(statement)

                if stepResult == SQLITE_DONE {
                    return events
                }

                guard stepResult == SQLITE_ROW else {
                    throw MessageListenerError.statementExecutionFailed(database.lastErrorMessage)
                }

                if let event = readMessageEvent(from: statement) {
                    events.append(event)
                }
            }
        }
    }

    private func queryMessages(after rowID: Int64) throws -> [MessageEvent] {
        try withDatabase { database in
            let sql = """
            SELECT
                message.ROWID,
                COALESCE(message.text, ''),
                message.date,
                message.is_from_me,
                message.attributedBody,
                COALESCE(handle.id, '')
            FROM message
            LEFT JOIN handle ON message.handle_id = handle.ROWID
            WHERE message.ROWID > ?
            ORDER BY message.ROWID ASC;
            """

            var statement: OpaquePointer?

            guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
                throw MessageListenerError.statementPreparationFailed(database.lastErrorMessage)
            }

            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int64(statement, 1, rowID)

            var events: [MessageEvent] = []

            while true {
                let stepResult = sqlite3_step(statement)

                if stepResult == SQLITE_DONE {
                    return events
                }

                guard stepResult == SQLITE_ROW else {
                    throw MessageListenerError.statementExecutionFailed(database.lastErrorMessage)
                }

                if let event = readMessageEvent(from: statement) {
                    events.append(event)
                }
            }
        }
    }

    private func withDatabase<T>(_ body: (OpaquePointer) throws -> T) throws -> T {
        var database: OpaquePointer?
        let expandedPath = expandedPath(from: chatDatabasePath)

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw MessageListenerError.databaseNotFound("Messages database not found at \(expandedPath).")
        }

        let openResult = sqlite3_open_v2(expandedPath, &database, SQLITE_OPEN_READONLY, nil)

        guard openResult == SQLITE_OK else {
            let errorMessage = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "Unknown SQLite error"
            sqlite3_close(database)

            if openResult == SQLITE_AUTH || openResult == SQLITE_PERM {
                throw MessageListenerError.databaseAccessDenied(
                    """
                    Access to the Messages database was denied at \(expandedPath).
                    Grant Full Disk Access to Xcode while debugging, or to fiGate.app when running the built app.
                    SQLite reported: \(errorMessage)
                    """
                )
            }

            throw MessageListenerError.databaseOpenFailed(errorMessage)
        }

        guard let database else {
            throw MessageListenerError.databaseOpenFailed("SQLite returned a nil database handle.")
        }

        sqlite3_busy_timeout(database, 2_000)

        defer { sqlite3_close(database) }
        return try body(database)
    }

    private func readMessageEvent(from statement: OpaquePointer?) -> MessageEvent? {
        let eventID = sqlite3_column_int64(statement, 0)
        let text = extractedMessageText(from: statement)
        let rawDate = sqlite3_column_int64(statement, 2)
        let isFromMe = sqlite3_column_int(statement, 3) == 1
        let sender = statement.readText(at: 5)

        guard !text.isEmpty else {
            return nil
        }

        return MessageEvent(
            id: eventID,
            text: text,
            date: Self.decodeMessageDate(rawDate),
            sender: sender,
            isFromMe: isFromMe
        )
    }

    private func logIfNeeded(_ messages: [MessageEvent]) {
        guard !messages.isEmpty else {
            return
        }

        let newestMessageID = messages.map(\.id).max()

        guard let newestMessageID else {
            return
        }

        guard let lastLoggedMessageID else {
            self.lastLoggedMessageID = newestMessageID
            return
        }

        let newIncomingMessages = messages
            .filter { $0.id > lastLoggedMessageID && !$0.isFromMe }
            .sorted { $0.date < $1.date }

        for message in newIncomingMessages {
            let timestamp = consoleDateFormatter.string(from: message.date)
            print("fiGate MessageListener new message [\(timestamp)] from \(message.sender): \(message.text)")
        }

        self.lastLoggedMessageID = max(lastLoggedMessageID, newestMessageID)
    }

    private static func decodeMessageDate(_ value: Int64) -> Date {
        guard value != 0 else {
            return .distantPast
        }

        let absoluteValue = abs(value)
        let secondsSinceReferenceDate: TimeInterval

        if absoluteValue > 1_000_000_000_000 {
            secondsSinceReferenceDate = TimeInterval(value) / 1_000_000_000
        } else {
            secondsSinceReferenceDate = TimeInterval(value)
        }

        return Date(timeIntervalSinceReferenceDate: secondsSinceReferenceDate)
    }

    private func extractedMessageText(from statement: OpaquePointer?) -> String {
        let rawText = statement.readText(at: 1).trimmingCharacters(in: .whitespacesAndNewlines)
        if !rawText.isEmpty {
            return rawText
        }

        guard let attributedBody = statement.readData(at: 4),
              let attributedText = decodeLegacyAttributedBody(attributedBody) else {
            return ""
        }

        return attributedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeLegacyAttributedBody(_ data: Data) -> String? {
        // Messages often stores the visible text in attributedBody instead of
        // message.text. That blob uses the legacy NSUnarchiver typedstream
        // format, so modern NSKeyedUnarchiver decoding does not work here.
        guard let attributedString = NSUnarchiver.unarchiveObject(with: data) as? NSAttributedString else {
            return nil
        }

        return attributedString.string
    }

    private func expandedPath(from path: String) -> String {
        NSString(string: path).expandingTildeInPath
    }

    private func status(for error: MessageListenerError) -> DatabaseAccessStatus {
        switch error {
        case .databaseAccessDenied:
            return .accessDenied
        case .databaseNotFound:
            return .databaseNotFound
        case .databaseOpenFailed, .statementPreparationFailed, .statementExecutionFailed:
            return .failed
        }
    }
}

private extension OpaquePointer {
    var lastErrorMessage: String {
        String(cString: sqlite3_errmsg(self))
    }
}

private extension Optional where Wrapped == OpaquePointer {
    func readText(at index: Int32) -> String {
        guard let column = self,
              let value = sqlite3_column_text(column, index) else {
            return ""
        }

        return String(cString: value)
    }

    func readData(at index: Int32) -> Data? {
        guard let column = self,
              sqlite3_column_type(column, index) != SQLITE_NULL,
              let bytes = sqlite3_column_blob(column, index) else {
            return nil
        }

        let count = Int(sqlite3_column_bytes(column, index))
        return Data(bytes: bytes, count: count)
    }
}
