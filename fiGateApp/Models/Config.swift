import Foundation

public enum PollInterval: Int, CaseIterable, Codable, Identifiable, Sendable {
    case seconds15 = 15
    case seconds30 = 30
    case minute1 = 60
    case minutes5 = 300
    case minutes10 = 600
    case minutes30 = 1800

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .seconds15:
            return "15 seconds / 15 秒"
        case .seconds30:
            return "30 seconds / 30 秒"
        case .minute1:
            return "1 minute / 1 分鐘"
        case .minutes5:
            return "5 minutes / 5 分鐘"
        case .minutes10:
            return "10 minutes / 10 分鐘"
        case .minutes30:
            return "30 minutes / 30 分鐘"
        }
    }

    public var timeInterval: TimeInterval {
        TimeInterval(rawValue)
    }
}

public struct Config: Codable, Equatable, Sendable {
    public static let defaultChatDatabasePath = "~/Library/Messages/chat.db"
    public static let defaultOpenClawEndpoint = "http://127.0.0.1:18789/hooks/wake"

    public var pollInterval: PollInterval
    public var chatDatabasePath: String
    public var openClawEndpoint: String
    public var openClawToken: String
    public var allowedSources: [Source]

    public init(
        pollInterval: PollInterval = .seconds15,
        chatDatabasePath: String = Config.defaultChatDatabasePath,
        openClawEndpoint: String = Config.defaultOpenClawEndpoint,
        openClawToken: String = "",
        allowedSources: [Source] = []
    ) {
        self.pollInterval = pollInterval
        self.chatDatabasePath = chatDatabasePath
        self.openClawEndpoint = openClawEndpoint
        self.openClawToken = openClawToken
        self.allowedSources = allowedSources
    }

    public static let defaultValue = Config()

    public func isAllowed(sender: String) -> Bool {
        allowedSources.contains { $0.matches(sender) }
    }

    private enum CodingKeys: String, CodingKey {
        case pollInterval = "poll_interval"
        case chatDatabasePath = "chat_db"
        case openClawEndpoint = "openclaw_endpoint"
        case openClawToken = "openclaw_token"
        case allowedSources = "allowed_sources"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let rawInterval = try container.decodeIfPresent(Int.self, forKey: .pollInterval) ?? PollInterval.seconds15.rawValue
        pollInterval = PollInterval(rawValue: rawInterval) ?? .seconds15
        chatDatabasePath = try container.decodeIfPresent(String.self, forKey: .chatDatabasePath) ?? Config.defaultChatDatabasePath
        openClawEndpoint = try container.decodeIfPresent(String.self, forKey: .openClawEndpoint) ?? Config.defaultOpenClawEndpoint
        openClawToken = try container.decodeIfPresent(String.self, forKey: .openClawToken) ?? ""
        allowedSources = try container.decodeIfPresent([Source].self, forKey: .allowedSources) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(pollInterval.rawValue, forKey: .pollInterval)
        try container.encode(chatDatabasePath, forKey: .chatDatabasePath)
        try container.encode(openClawEndpoint, forKey: .openClawEndpoint)
        try container.encode(openClawToken, forKey: .openClawToken)
        try container.encode(allowedSources, forKey: .allowedSources)
    }
}
