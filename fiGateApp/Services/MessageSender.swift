import Foundation

public protocol MessageSending: Sendable {
    func send(_ text: String, to recipient: String) async throws
}

public enum MessageSenderError: LocalizedError {
    case invalidRecipient
    case emptyMessage
    case processLaunchFailed(String)
    case messagesUnavailable(String)
    case permissionDenied(String)
    case appleScriptExecutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRecipient:
            return "The iMessage recipient is empty."
        case .emptyMessage:
            return "The iMessage body is empty."
        case .processLaunchFailed(let message),
             .messagesUnavailable(let message),
             .permissionDenied(let message),
             .appleScriptExecutionFailed(let message):
            return message
        }
    }
}

public final class MessageSender: MessageSending, Sendable {
    private let osascriptExecutableURL: URL

    public init(osascriptExecutableURL: URL = URL(fileURLWithPath: "/usr/bin/osascript")) {
        self.osascriptExecutableURL = osascriptExecutableURL
    }

    public static func sendMessage(to recipient: String, text: String) async throws {
        try await MessageSender().sendMessage(to: recipient, text: text)
    }

    public func sendMessage(to recipient: String, text: String) async throws {
        let trimmedRecipient = recipient.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedRecipient.isEmpty else {
            throw MessageSenderError.invalidRecipient
        }

        guard !trimmedText.isEmpty else {
            throw MessageSenderError.emptyMessage
        }

        let outboundText = MessageEvent.fiGatePrefixedText(trimmedText)

        print("Sending iMessage...")

        do {
            let result = try await Task.detached(priority: .utility) { [osascriptExecutableURL] in
                try Self.executeAppleScript(
                    osascriptExecutableURL: osascriptExecutableURL,
                    recipient: trimmedRecipient,
                    text: outboundText
                )
            }.value

            if !result.output.isEmpty {
                print(result.output)
            }

            print("Message sent successfully")
        } catch let error as MessageSenderError {
            print("AppleScript execution failed")
            throw error
        } catch {
            print("AppleScript execution failed")
            throw MessageSenderError.appleScriptExecutionFailed(error.localizedDescription)
        }
    }

    public func send(_ text: String, to recipient: String) async throws {
        try await sendMessage(to: recipient, text: text)
    }

    private static func executeAppleScript(
        osascriptExecutableURL: URL,
        recipient: String,
        text: String
    ) throws -> ScriptExecutionResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = osascriptExecutableURL
        process.arguments = [
            "-e", appleScript,
            "--",
            recipient,
            text,
        ]
        process.standardOutput = standardOutput
        process.standardError = standardError

        do {
            try process.run()
        } catch {
            throw MessageSenderError.processLaunchFailed("Unable to launch osascript: \(error.localizedDescription)")
        }

        process.waitUntilExit()

        let output = String(decoding: standardOutput.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let errorOutput = String(decoding: standardError.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard process.terminationStatus == 0 else {
            throw classifyFailure(errorOutput: errorOutput, output: output, terminationStatus: process.terminationStatus)
        }

        return ScriptExecutionResult(output: output)
    }

    private static func classifyFailure(
        errorOutput: String,
        output: String,
        terminationStatus: Int32
    ) -> MessageSenderError {
        let details = [errorOutput, output]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let failureMessage = details.isEmpty ? "osascript exited with status \(terminationStatus)." : details
        let normalized = failureMessage.lowercased()

        if normalized.contains("1743") || normalized.contains("not authorized") || normalized.contains("not permitted") {
            return .permissionDenied(failureMessage)
        }

        if normalized.contains("can't get buddy") || normalized.contains("1728") || normalized.contains("invalid") {
            return .invalidRecipient
        }

        if normalized.contains("1001") || normalized.contains("messages") && normalized.contains("not running") {
            return .messagesUnavailable(failureMessage)
        }

        return .appleScriptExecutionFailed(failureMessage)
    }

    // Arguments are passed through argv instead of string interpolation to avoid
    // quoting bugs and AppleScript injection issues.
    private static let appleScript = """
    on run argv
        if (count of argv) is not 2 then error "Expected recipient and message arguments." number 64

        set targetRecipient to item 1 of argv
        set outboundMessage to item 2 of argv
        set targetService to missing value

        tell application "Messages"
            if it is not running then launch

            repeat 10 times
                try
                    set targetService to 1st service whose service type = iMessage
                    exit repeat
                on error
                    delay 0.3
                end try
            end repeat
        end tell

        if targetService is missing value then error "No iMessage service is available." number 1001

        tell application "Messages"
            set targetBuddy to buddy targetRecipient of targetService
            send outboundMessage to targetBuddy
        end tell

        return "Sent iMessage to " & targetRecipient
    end run
    """
}

private struct ScriptExecutionResult: Sendable {
    let output: String
}
