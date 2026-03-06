import Foundation

public enum LogChannel: String, CaseIterable, Identifiable, Sendable {
    case gateway
    case message
    case error

    public var id: String { rawValue }

    public var fileName: String {
        "\(rawValue).log"
    }

    public var displayName: String {
        switch self {
        case .gateway:
            return "Gateway / 閘道"
        case .message:
            return "Message / 訊息"
        case .error:
            return "Error / 錯誤"
        }
    }
}

public actor Logger {
    public static let shared = Logger()

    private let fileManager = FileManager.default
    private let formatter: ISO8601DateFormatter

    public init() {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter
    }

    public func log(_ message: String, channel: LogChannel = .gateway) {
        do {
            try ensureLogDirectory()

            let logURL = ConfigPaths.logsDirectory.appendingPathComponent(channel.fileName)
            let formattedLine = "\(formatter.string(from: Date())) [\(channel.rawValue.uppercased())] \(message)\n"
            let data = Data(formattedLine.utf8)

            if fileManager.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            fputs("fiGate logging error: \(error.localizedDescription)\n", stderr)
        }
    }

    public func read(channel: LogChannel) -> String {
        do {
            try ensureLogDirectory()

            let logURL = ConfigPaths.logsDirectory.appendingPathComponent(channel.fileName)
            guard fileManager.fileExists(atPath: logURL.path) else {
                return ""
            }

            return try String(contentsOf: logURL, encoding: .utf8)
        } catch {
            return "Unable to read \(channel.fileName): \(error.localizedDescription)"
        }
    }

    public func lastLine(channel: LogChannel) -> String? {
        let content = read(channel: channel)
        return content
            .split(whereSeparator: \.isNewline)
            .last
            .map(String.init)
    }

    private func ensureLogDirectory() throws {
        try fileManager.createDirectory(at: ConfigPaths.logsDirectory, withIntermediateDirectories: true, attributes: nil)
    }
}
