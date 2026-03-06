import Foundation

public enum DatabaseAccessSubject: String, Codable, Sendable {
    case fiGateApp

    public var displayName: String {
        "fiGate / fiGate"
    }
}

public enum DatabaseAccessStatus: String, Codable, Sendable {
    case accessible
    case accessDenied
    case databaseNotFound
    case failed

    public var displayName: String {
        switch self {
        case .accessible:
            return "Accessible / 可存取"
        case .accessDenied:
            return "Access Denied / 權限遭拒"
        case .databaseNotFound:
            return "Database Missing / 找不到資料庫"
        case .failed:
            return "Check Failed / 檢查失敗"
        }
    }
}

public struct DatabaseAccessDiagnostic: Codable, Equatable, Sendable {
    public let subject: DatabaseAccessSubject
    public let status: DatabaseAccessStatus
    public let checkedAt: Date
    public let databasePath: String
    public let detail: String
    public let latestMessageID: Int64?
    public let recentTextMessageCount: Int

    public init(
        subject: DatabaseAccessSubject,
        status: DatabaseAccessStatus,
        checkedAt: Date = Date(),
        databasePath: String,
        detail: String,
        latestMessageID: Int64? = nil,
        recentTextMessageCount: Int = 0
    ) {
        self.subject = subject
        self.status = status
        self.checkedAt = checkedAt
        self.databasePath = databasePath
        self.detail = detail
        self.latestMessageID = latestMessageID
        self.recentTextMessageCount = recentTextMessageCount
    }

    public var isAccessible: Bool {
        status == .accessible
    }

    public static func failed(
        subject: DatabaseAccessSubject,
        databasePath: String,
        detail: String
    ) -> DatabaseAccessDiagnostic {
        DatabaseAccessDiagnostic(
            subject: subject,
            status: .failed,
            databasePath: databasePath,
            detail: detail
        )
    }
}
