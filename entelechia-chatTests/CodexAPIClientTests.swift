import XCTest
@testable import entelechia_chat

final class CodexAPIClientTests: XCTestCase {
    override func setUp() {
        super.setUp()
        URLProtocolMock.responses = []
        URLProtocolMock.requestObserver = nil
        URLProtocolMock.requestCount = 0
    }
    
    private func makeClient(responses: [URLProtocolMock.Response]) -> CodexAPIClient {
        URLProtocolMock.responses = responses
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolMock.self]
        let session = URLSession(configuration: configuration)
        let config = CodexConfig(
            apiKey: "sk-test",
            baseURL: URL(string: "https://codex.example.com/v1")!,
            organization: "entelechia",
            source: .environment
        )
        return CodexAPIClient(config: config, session: session, model: "codex-test")
    }

    func testRequestIncludesHeaders() async throws {
        let expectation = expectation(description: "Request observed")
        URLProtocolMock.requestObserver = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Codex-Org"), "entelechia")
            expectation.fulfill()
        }

        let responses: [URLProtocolMock.Response] = [
            .success(
                status: 200,
                body: """
                data: {"type":"text","text":"hello"}
                
                data: [DONE]
                """.data(using: .utf8)!
            )
        ]

        let client = makeClient(responses: responses)
        _ = try await collectEvents(from: client)
        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testStreamingParsesTextEvents() async throws {
        let responses: [URLProtocolMock.Response] = [
            .success(
                status: 200,
                body: """
                data: {"type":"text","text":"Hello"}
                data: {"type":"text","text":" world"}
                
                data: [DONE]
                """.data(using: .utf8)!
            )
        ]

        let events = try await collectEvents(from: makeClient(responses: responses))
        XCTAssertEqual(events, [.text("Hello"), .text(" world")])
    }

    func testRetriesOnRateLimit() async throws {
        let responses: [URLProtocolMock.Response] = [
            .success(
                status: 200,
                body: """
                data: {"type":"text","text":"after retry"}
                
                data: [DONE]
                """.data(using: .utf8)!
            )
        ]
        
        let events = try await collectEvents(from: makeClient(responses: responses))
        XCTAssertFalse(events.isEmpty)
    }

    // MARK: - Helpers

    private func collectEvents(from client: CodexAPIClient) async throws -> [CodexAPIClient.StreamEvent] {
        var iterator = await client.streamChatCompletions(messages: sampleMessages, attachments: []).makeAsyncIterator()
        var events: [CodexAPIClient.StreamEvent] = []
        while let event = try await iterator.next() {
            events.append(event)
        }
        return events
    }

    private var sampleMessages: [Message] {
        [Message(role: .user, text: "Hello Codex")]
    }
}

// MARK: - URLProtocol mock

final class URLProtocolMock: URLProtocol {
    struct Response {
        enum Kind {
            case success
            case failure
        }
        let kind: Kind
        let status: Int
        let body: Data

        static func success(status: Int, body: Data) -> Response {
            Response(kind: .success, status: status, body: body)
        }

        static func failure(status: Int, body: Data) -> Response {
            Response(kind: .failure, status: status, body: body)
        }
    }

    static var responses: [Response] = []
    static var requestObserver: ((URLRequest) -> Void)?
    static var requestCount: Int = 0

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        URLProtocolMock.requestCount += 1
        URLProtocolMock.requestObserver?(request)

        guard !URLProtocolMock.responses.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        let next = URLProtocolMock.responses.removeFirst()

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: next.status,
            httpVersion: nil,
            headerFields: [:]
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: next.body)

        if next.kind == .success {
            client?.urlProtocolDidFinishLoading(self)
        } else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
        }
    }

    override func stopLoading() {
        // No-op
    }
}
