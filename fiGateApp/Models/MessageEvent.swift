import Foundation

public struct MessageEvent: Identifiable, Codable, Equatable, Sendable {
    public static let fiGateTag = "[fiGate]"
    public static let fiGatePrefix = "\(fiGateTag) "

    public let id: Int64
    public let text: String
    public let date: Date
    public let sender: String
    public let isFromMe: Bool

    public var source: String {
        sender
    }

    public var isFiGateTagged: Bool {
        text.hasPrefix(Self.fiGateTag)
    }

    public var isSentByFiGate: Bool {
        isFromMe && isFiGateTagged
    }

    public init(id: Int64, text: String, date: Date, sender: String, isFromMe: Bool) {
        self.id = id
        self.text = text
        self.date = date
        self.sender = sender
        self.isFromMe = isFromMe
    }

    public init(id: Int64, text: String, date: Date, isFromMe: Bool, source: String) {
        self.init(id: id, text: text, date: date, sender: source, isFromMe: isFromMe)
    }

    public static func fiGatePrefixedText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return trimmed
        }

        if trimmed.hasPrefix(fiGateTag) {
            return trimmed
        }

        return fiGatePrefix + trimmed
    }

    public static func receivedAcknowledgementText(
        at date: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "MM-dd HH:mm"
        return "\(fiGateTag)Recieved.(\(formatter.string(from: date)))"
    }
}
