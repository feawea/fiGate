import Foundation

public protocol ExternalMessageRelayClient: Sendable {
    func forward(_ message: MessageEvent, endpoint: URL, token: String) async throws -> ExternalSystemResponse
    func send(source: String, text: String, endpoint: URL, token: String) async throws -> ExternalSystemResponse
    func testConnection(endpoint: URL, token: String) async throws -> ExternalSystemResponse
}

public enum OpenClawClientError: LocalizedError {
    case invalidEndpoint(String)
    case missingToken
    case encodingFailed(Error)
    case transportFailed(Error)
    case invalidHTTPResponse
    case requestFailed(statusCode: Int, body: String)

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint(let endpoint):
            return "OpenClaw endpoint is invalid: \(endpoint)"
        case .missingToken:
            return "OpenClaw token is missing."
        case .encodingFailed(let error):
            return "Failed to encode OpenClaw request body: \(error.localizedDescription)"
        case .transportFailed(let error):
            return "OpenClaw connection failed: \(error.localizedDescription)"
        case .invalidHTTPResponse:
            return "OpenClaw did not return an HTTP response."
        case .requestFailed(let statusCode, let body):
            return "OpenClaw request failed with status \(statusCode): \(body)"
        }
    }
}

public struct ExternalSystemResponse: Sendable {
    public let statusCode: Int
    public let body: String

    public var rawBody: String {
        body
    }

    public var replyText: String {
        body
    }

    public init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }
}

public typealias OpenClawResponse = ExternalSystemResponse

public final class OpenClawClient: ExternalMessageRelayClient {
    public static let defaultBaseURLString = "http://127.0.0.1:18789"
    public static let defaultWebhookPath = "/hooks/wake"

    private let session: URLSession
    private let encoder: JSONEncoder
    private let endpoint: URL
    private let token: String

    public init(
        endpoint: URL? = nil,
        token: String = "",
        session: URLSession = .shared
    ) {
        self.endpoint = endpoint ?? URL(string: Self.defaultBaseURLString + Self.defaultWebhookPath)!
        self.token = token
        self.session = session
        self.encoder = JSONEncoder()
    }

    public convenience init(
        endpointString: String,
        token: String = "",
        session: URLSession = .shared
    ) throws {
        guard let endpointURL = URL(string: endpointString) else {
            throw OpenClawClientError.invalidEndpoint(endpointString)
        }

        self.init(endpoint: endpointURL, token: token, session: session)
    }

    public func sendMessageToAgent(source: String, text: String) async throws -> String {
        let response = try await sendRequest(
            payload: OpenClawWakePayload(source: source, text: text, mode: "now"),
            endpoint: endpoint,
            token: token,
            source: source
        )

        return response.body
    }

    public func forward(_ message: MessageEvent, endpoint: URL, token: String) async throws -> ExternalSystemResponse {
        try await sendRequest(
            payload: OpenClawWakePayload(source: message.source, text: message.text, mode: "now"),
            endpoint: endpoint,
            token: token,
            source: message.source
        )
    }

    public func send(source: String, text: String, endpoint: URL, token: String) async throws -> ExternalSystemResponse {
        try await sendRequest(
            payload: OpenClawWakePayload(source: source, text: text, mode: "now"),
            endpoint: endpoint,
            token: token,
            source: source
        )
    }

    public func testConnection(endpoint: URL, token: String) async throws -> ExternalSystemResponse {
        try await sendRequest(
            payload: OpenClawWakePayload(source: "fiGate", text: "fiGate connection test", mode: "now"),
            endpoint: endpoint,
            token: token,
            source: "fiGate"
        )
    }

    private func sendRequest(
        payload: OpenClawWakePayload,
        endpoint: URL,
        token: String,
        source: String
    ) async throws -> ExternalSystemResponse {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            print("OpenClaw error")
            throw OpenClawClientError.missingToken
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authorizationHeaderValue(from: trimmedToken), forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            print("OpenClaw error")
            throw OpenClawClientError.encodingFailed(error)
        }

        print("Sending message to OpenClaw... source=\(source)")

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            print("OpenClaw error")
            throw OpenClawClientError.transportFailed(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            print("OpenClaw error")
            throw OpenClawClientError.invalidHTTPResponse
        }

        let body = String(decoding: data, as: UTF8.self)

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            print("OpenClaw error")
            throw OpenClawClientError.requestFailed(statusCode: httpResponse.statusCode, body: body)
        }

        print("OpenClaw response received")
        return ExternalSystemResponse(statusCode: httpResponse.statusCode, body: body)
    }

    private func authorizationHeaderValue(from token: String) -> String {
        if token.lowercased().hasPrefix("bearer ") {
            return token
        }

        return "Bearer \(token)"
    }
}

private struct OpenClawWakePayload: Codable, Sendable {
    let source: String
    let text: String
    let mode: String
}
