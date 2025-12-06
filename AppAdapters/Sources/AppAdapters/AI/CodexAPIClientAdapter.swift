import Foundation
import CoreEngine
@preconcurrency import os.log

/// Codex client adapter (self-contained HTTP implementation with lightweight streaming).
public struct CodexAPIClientAdapter: CodexClient, @unchecked Sendable {
    public typealias MessageType = Message
    public typealias ContextFileType = LoadedFile
    public typealias OutputPayload = ModelResponse

    private let client: HTTPClient
    private let model: String

    public init(config: CodexConfigBridge) {
        self.client = HTTPClient(config: config)
        self.model = config.model
    }

    public func stream(
        messages: [Message],
        contextFiles: [LoadedFile]
    ) async throws -> AsyncThrowingStream<StreamChunk<ModelResponse>, Error> {
        try await client.stream(messages: messages, contextFiles: contextFiles, model: model)
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

// MARK: - Minimal HTTP client (SSE-like via line splitting)

private final class HTTPClient {
    private let config: CodexConfigBridge
    private let logger = Logger(subsystem: "chat.entelechia.uiconnections", category: "CodexAPI")
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

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

        return AsyncThrowingStream { continuation in
            Task {
                var buffer = Data()
                do {
                    for try await chunk in bytes {
                        buffer.append(chunk)
                        // Split on newlines to approximate SSE framing.
                        while let range = buffer.firstRange(of: Data("\n".utf8)) {
                            let lineData = buffer.subdata(in: 0..<range.lowerBound)
                            buffer.removeSubrange(0...range.lowerBound)
                            let line = String(data: lineData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            guard line.hasPrefix("data:") else { continue }
                            let payloadString = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                            if payloadString == "[DONE]" {
                                continuation.yield(.done)
                                continuation.finish()
                                return
                            }
                            if let payloadData = payloadString.data(using: .utf8) {
                                parsePayload(payloadData, into: continuation)
                            }
                        }
                    }
                    // Flush any remaining buffer as a single message
                    if !buffer.isEmpty, let text = String(data: buffer, encoding: .utf8) {
                        continuation.yield(.output(ModelResponse(content: text)))
                    }
                    continuation.yield(.done)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
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
            throw NSError(domain: "CodexAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        guard (200...299).contains(http.statusCode) else {
            throw NSError(domain: "CodexAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
        }
    }

    private func parsePayload(_ data: Data, into continuation: AsyncThrowingStream<StreamChunk<ModelResponse>, Error>.Continuation) {
        do {
            let chunk = try JSONDecoder().decode(StreamChunkPayload.self, from: data)
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
            logger.error("Codex payload decode failed: \(error.localizedDescription, privacy: .public)")
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

private struct StreamChunkPayload: Decodable {
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

