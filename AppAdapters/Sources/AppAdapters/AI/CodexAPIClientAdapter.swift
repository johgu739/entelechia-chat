import Foundation
import AppCoreEngine
@preconcurrency import os.log

/// Codex client adapter (self-contained HTTP implementation with lightweight streaming).
public struct CodexAPIClientAdapter: CodexClient, Sendable {
    public typealias MessageType = Message
    public typealias ContextFileType = LoadedFile
    public typealias OutputPayload = ModelResponse

    private let client: HTTPClient
    private let model: String
    private let retryPolicy: RetryPolicy

    public init(config: CodexConfigBridge, retryPolicy: RetryPolicy = RetryPolicy()) {
        self.client = HTTPClient(config: config)
        self.model = config.model
        self.retryPolicy = retryPolicy
    }

    public func stream(
        messages: [Message],
        contextFiles: [LoadedFile]
    ) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        try await executeWithRetry {
            try await client.stream(messages: messages, contextFiles: contextFiles, model: model)
        }
    }

    private func executeWithRetry<T>(
        _ operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 0...retryPolicy.maxRetries {
            try Task.checkCancellation()
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt == retryPolicy.maxRetries {
                    break
                }
                let delay = retryPolicy.backoff.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? StreamTransportError.invalidResponse("Unknown streaming failure")
    }
}

public struct CodexConfigBridge: Sendable {
    public let apiKey: String
    public let organization: String?
    public let baseURL: URL
    public let session: URLSession
    public let model: String

    public init(apiKey: String, organization: String?, baseURL: URL, session: URLSession = .shared, model: String = "gpt-4o-mini") {
        self.apiKey = apiKey
        self.organization = organization
        self.baseURL = baseURL
        self.session = session
        self.model = model
    }
}

// MARK: - Streaming HTTP client (typed SSE with framing + timeout)

private actor HTTPClient {
    private let config: CodexConfigBridge
    private let logger = Logger(subsystem: "chat.entelechia.uiconnections", category: "CodexAPI")
    private let decoder = JSONDecoder()
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()
    private let streamTimeoutNanoseconds: UInt64 = 60 * 1_000_000_000 // 60s hard timeout

    init(config: CodexConfigBridge) {
        self.config = config
    }

    func stream(
        messages: [Message],
        contextFiles: [LoadedFile],
        model: String
    ) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        let request = try buildRequest(messages: messages, contextFiles: contextFiles, model: model)
        let (bytes, response) = try await config.session.bytes(for: request)
        try validate(response: response)

        let framer = SSEStreamFramer<ModelResponse>(
            timeoutNanoseconds: streamTimeoutNanoseconds,
            handler: { [decoder] event, continuation in
                try Self.handle(event, into: continuation, decoder: decoder)
            }
        )
        let dataStream = AsyncStream<Data> { continuation in
            Task {
                for try await chunk in bytes {
                    continuation.yield(Data([chunk]))
                }
                continuation.finish()
            }
        }
        return framer.makeStream(bytes: dataStream)
    }

    private func buildRequest(
        messages: [Message],
        contextFiles: [LoadedFile],
        model: String
    ) throws -> URLRequest {
        var url = config.baseURL
        if url.lastPathComponent != "chat" {
            url.appendPathComponent("chat")
        }
        url.appendPathComponent("completions")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        if let org = config.organization {
            request.setValue(org, forHTTPHeaderField: "X-Codex-Org")
        }

        let payload = RequestPayload(
            model: model,
            stream: true,
            temperature: 0.2,
            messages: messages.map { .init(role: $0.role.rawValue, content: $0.text) },
            context: contextFiles.map { .init(path: $0.url.path, content: $0.content) }
        )
        request.httpBody = try encoder.encode(payload)
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw StreamTransportError.invalidResponse("Missing HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            throw StreamTransportError.invalidResponse("HTTP \(http.statusCode)")
        }
    }

    @Sendable
    private static func handle(
        _ event: ServerSentEvent,
        into continuation: AsyncThrowingStream<StreamChunk<ModelResponse>, Error>.Continuation,
        decoder: JSONDecoder
    ) throws -> Bool {
        guard let payloadText = event.dataPayload else { return false }
        let trimmed = payloadText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed == "[DONE]" {
            continuation.yield(.done)
            continuation.finish()
            return true
        }

        guard let payloadData = trimmed.data(using: .utf8) else {
            throw StreamTransportError.framing("Non-UTF8 payload")
        }

        do {
            let chunk = try decoder.decode(StreamChunkPayload.self, from: payloadData)
            switch chunk.type {
            case "text":
                if let text = chunk.text {
                    continuation.yield(.token(text))
                }
            case "diff":
                if let diff = chunk.diff {
                    continuation.yield(.output(ModelResponse(content: diff.patch)))
                }
            case "file":
                if let file = chunk.file {
                    continuation.yield(.output(ModelResponse(content: file.content)))
                }
            default:
                break
            }
        } catch {
            throw StreamTransportError.decoding(error.localizedDescription)
        }

        return false
    }

}

// MARK: - SSE parsing

struct ServerSentEvent {
    var event: String?
    var dataLines: [String] = []
    var id: String?
    var retry: Int?

    var hasData: Bool { !dataLines.isEmpty }

    var dataPayload: String? {
        guard hasData else { return nil }
        // Normalize escaped newlines in payload lines so trailing "\\n" sequences
        // become real newlines and don’t break downstream JSON decoding.
        let normalized = dataLines.map { $0.replacingOccurrences(of: "\\n", with: "\n") }
        return normalized.joined(separator: "\n")
    }
}

struct ServerSentEventParser {
    private var buffer = Data()
    private var building = ServerSentEvent()
    private let newline = Data([0x0A]) // \n

    mutating func feed(_ chunk: Data) throws -> [ServerSentEvent] {
        buffer.append(chunk)
        var events: [ServerSentEvent] = []

        guard let text = String(data: buffer, encoding: .utf8) else {
            throw StreamTransportError.framing("Non-UTF8 chunk")
        }

        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let hasTrailingNewline = text.last == "\n"

        // All but last (if partial) are complete lines to process.
        let completeCount = hasTrailingNewline ? lines.count : max(lines.count - 1, 0)
        for i in 0..<completeCount {
            try processLine(Data(lines[i].utf8), into: &events)
        }

        if !hasTrailingNewline, let remainder = lines.last {
            // Treat the trailing line as complete (no newline) so callers can drain it later.
            try processLine(Data(remainder.utf8), into: &events)
            buffer.removeAll()
        } else {
            buffer.removeAll()
        }

        return events
    }

    private mutating func processLine(_ lineData: Data, into events: inout [ServerSentEvent]) throws {
        guard let rawLine = String(data: lineData, encoding: .utf8) else {
            throw StreamTransportError.framing("Non-UTF8 line")
        }
        // Normalize: strip trailing newlines, then trim leading/trailing spaces for field parsing.
        let line = rawLine.trimmingCharacters(in: .newlines)
        let fieldLine = line.trimmingCharacters(in: .whitespaces)

        if fieldLine.isEmpty {
            if building.hasData {
                events.append(building)
                building = ServerSentEvent()
            }
            return
        }

        if fieldLine.hasPrefix(":") {
            return // comment line per SSE spec
        }

        let components = fieldLine.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard let field = components.first else { return }
        let value = components.count > 1 ? components[1].dropFirst(components[1].first == " " ? 1 : 0) : Substring()

        switch field {
        case "event":
            building.event = String(value)
        case "data":
            building.dataLines.append(String(value))
        case "id":
            building.id = String(value)
        case "retry":
            building.retry = Int(value)
        default:
            return
        }
    }

    mutating func drainPendingEvent() -> ServerSentEvent? {
        guard building.hasData else { return nil }
        let pending = building
        building = ServerSentEvent()
        return pending
    }
}

// MARK: - Streaming framer

struct SSEStreamFramer<Output> {
    private let timeoutNanoseconds: UInt64
    private let handler: @Sendable (ServerSentEvent, AsyncThrowingStream<StreamChunk<Output>, Error>.Continuation) throws -> Bool

    init(
        timeoutNanoseconds: UInt64,
        handler: @escaping @Sendable (ServerSentEvent, AsyncThrowingStream<StreamChunk<Output>, Error>.Continuation) throws -> Bool
    ) {
        self.timeoutNanoseconds = timeoutNanoseconds
        self.handler = handler
    }

    func makeStream<Bytes: AsyncSequence>(
        bytes: Bytes
    ) -> AsyncThrowingStream<StreamChunk<Output>, Error> where Bytes.Element == Data {
        AsyncThrowingStream { continuation in
            let streamTask = Task {
                var parser = ServerSentEventParser()
                var finished = false
                do {
                    for try await chunk in bytes {
                        try Task.checkCancellation()
                        if finished { break }
                        let events = try parser.feed(chunk)
                        for event in events {
                            finished = try handler(event, continuation) || finished
                            if finished { break }
                        }
                    }
                    if !finished, let trailing = parser.drainPendingEvent() {
                        finished = try handler(trailing, continuation)
                    }
                    if !finished {
                        continuation.yield(.done)
                        continuation.finish()
                    }
                } catch is CancellationError {
                    continuation.finish(throwing: StreamTransportError.cancelled)
                } catch let transport as StreamTransportError {
                    continuation.finish(throwing: transport)
                } catch {
                    continuation.finish(throwing: StreamTransportError.underlying(error.localizedDescription))
                }
            }

            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                if !streamTask.isCancelled {
                    streamTask.cancel()
                    continuation.finish(throwing: StreamTransportError.timedOut)
                }
            }

            continuation.onTermination = { @Sendable _ in
                streamTask.cancel()
                timeoutTask.cancel()
            }
        }
    }
}

private struct RequestPayload: Encodable {
    struct MessagePayload: Encodable {
        let role: String
        let content: String
    }

    struct ContextFilePayload: Encodable {
        let path: String
        let content: String
    }

    let model: String
    let stream: Bool
    let temperature: Double
    let messages: [MessagePayload]
    let context: [ContextFilePayload]
}

struct StreamChunkPayload: Decodable {
    struct FilePayload: Decodable {
        let path: String
        let content: String
    }

    struct DiffPayload: Decodable {
        let file: String
        let patch: String
    }

    let type: String
    let text: String?
    let file: FilePayload?
    let diff: DiffPayload?
}

