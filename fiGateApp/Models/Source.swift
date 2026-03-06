import Foundation

public enum SourceKind: String, CaseIterable, Codable, Sendable {
    case phoneNumber
    case email
    case appleID

    public var displayName: String {
        switch self {
        case .phoneNumber:
            return "Phone Number / 電話號碼"
        case .email:
            return "Email / 電子郵件"
        case .appleID:
            return "Apple ID / Apple ID"
        }
    }
}

public struct Source: Codable, Hashable, Identifiable, Sendable {
    public let value: String
    public let kind: SourceKind

    public init(value: String, kind: SourceKind? = nil) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        self.value = trimmedValue
        self.kind = kind ?? Self.detectKind(for: trimmedValue)
    }

    public var id: String {
        normalizedValue
    }

    public var normalizedValue: String {
        switch kind {
        case .phoneNumber:
            return value
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
        case .email, .appleID:
            return value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    public func matches(_ candidate: String) -> Bool {
        Source(value: candidate, kind: kind).normalizedValue == normalizedValue
    }

    private static func detectKind(for value: String) -> SourceKind {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.contains("@") {
            if normalized.hasSuffix("@icloud.com") || normalized.hasSuffix("@me.com") || normalized.hasSuffix("@mac.com") {
                return .appleID
            }
            return .email
        }

        if normalized.hasPrefix("+") || normalized.allSatisfy(\.isNumber) {
            return .phoneNumber
        }

        return .appleID
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case kind
    }

    public init(from decoder: Decoder) throws {
        if let singleValue = try? decoder.singleValueContainer(),
           let decodedString = try? singleValue.decode(String.self) {
            self = Source(value: decodedString)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedValue = try container.decode(String.self, forKey: .value)
        let decodedKind = try container.decodeIfPresent(SourceKind.self, forKey: .kind)
        self = Source(value: decodedValue, kind: decodedKind)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
