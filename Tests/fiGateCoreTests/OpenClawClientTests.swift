import Foundation
import XCTest
@testable import fiGateCore

final class OpenClawClientTests: XCTestCase {
    override class func tearDown() {
        MockURLProtocol.requestHandler = nil
    }

    func testSendMessageToAgentIncludesAuthorizationAndStructuredPayload() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let endpoint = try XCTUnwrap(URL(string: "http://127.0.0.1:18789/hooks/wake"))

        let requestExpectation = expectation(description: "OpenClaw request received")

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")

            let body = try XCTUnwrap(requestBody(from: request))
            let payload = try JSONSerialization.jsonObject(with: body) as? [String: String]

            XCTAssertEqual(payload?["source"], "+15551234567")
            XCTAssertEqual(payload?["text"], "build ios")
            XCTAssertEqual(payload?["mode"], "now")

            requestExpectation.fulfill()

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "text/plain"]
            )!

            return (response, Data("ok".utf8))
        }

        let client = OpenClawClient(endpoint: endpoint, token: "test-token", session: session)
        let response = try await client.sendMessageToAgent(source: "+15551234567", text: "build ios")

        XCTAssertEqual(response, "ok")
        await fulfillment(of: [requestExpectation], timeout: 1.0)
    }
}

private func requestBody(from request: URLRequest) -> Data? {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    let bufferSize = 4096
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    var data = Data()

    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: bufferSize)
        guard read > 0 else {
            break
        }

        data.append(buffer, count: read)
    }

    return data.isEmpty ? nil : data
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var requestHandler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
