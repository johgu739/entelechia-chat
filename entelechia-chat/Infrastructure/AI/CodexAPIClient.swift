// @EntelechiaHeaderStart
// Signifier: CodexAPIClient
// Substance: Codex networking client
// Genus: Instrumental cause (AI transport)
// Differentia: Serializes chat requests and parses streaming responses
// Form: URLSession transport with SSE decoding and retry logic
// Matter: HTTP requests/responses; JSON payloads; Codex configuration
// Powers: Send chat prompts; stream tokens/diffs/full files; surface errors
// FinalCause: Supply Codex output for higher faculties (assistants/services)
// Relations: Serves CodexAssistant/ConversationService; depends on CodexConfig
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation
import os.log

struct CodexAPIClient {
    enum StreamEvent: Equatable {
        case text(String)
        case diff(file: String, patch: String)
        case file(path: String, content: String)
    }

    enum APIError: LocalizedError, Equatable {
        case unauthorized
        case forbidden
        case rateLimited(retryAfter: TimeInterval?)
        case server(status: Int)
        case decodingFailed
        case transport(String)
        case tooManyRetries

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Codex rejected the credentials (401)."
            case .forbidden:
                return "Codex denied access (403)."
            case .rateLimited(let retryAfter):
                return "Codex rate limit encountered. Retry after \(retryAfter ?? 0) seconds."
            case .server(let status):
                return "Codex server error (status \(status))."
            case .decodingFailed:
                return "Failed to decode Codex response."
            case .transport(let reason):
                return "Transport error: \(reason)"
            case .tooManyRetries:
                return "Codex request exceeded maximum retry attempts."
            }
        }
    }

    private struct RequestPayload: Encodable {
        struct MessagePayload: Encodable {
            struct AttachmentPayload: Encodable {
                let type: String
                let path: String?
                let language: String?
                let content: String?
            }

            let role: String
            let content: String
            let attachments: [AttachmentPayload]
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

    private let config: CodexConfig
    private let session: URLSession
    private let model: String
    private let maxRetries = 2
    private let logger = Logger(subsystem: "chat.entelechia", category: "CodexAPIClient")

    init(
        config: CodexConfig,
        session: URLSession = .shared,
        model: String = "gpt-4o-mini"
    ) {
        self.config = config
        self.session = session
        self.model = model
    }

    func streamChatCompletions(
        messages: [Message],
        attachments: [LoadedFile],
        temperature: Double = 0.2
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var attempt = 0
                while attempt <= maxRetries {
                    do {
                        let request = try buildRequest(
                            messages: messages,
                            attachments: attachments,
                            temperature: temperature
                        )
                        let (data, response) = try await session.data(for: request)
                        try validate(response: response, data: data)
                        try parseStream(data: data, continuation: continuation)
                        continuation.finish()
                        return
                    } catch let error as APIError {
                        if let delay = retryDelay(for: error, attempt: attempt) {
                            attempt += 1
                            let reason = error.errorDescription ?? error.localizedDescription
                            logger.warning("Codex request failed (\(reason, privacy: .public)). Retrying in \(delay, privacy: .public)s (attempt \(attempt)).")
                            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                            continue
                        } else {
                            continuation.finish(throwing: error)
                            return
                        }
                    } catch {
                        continuation.finish(throwing: error)
                        return
                    }
                }

                continuation.finish(throwing: APIError.tooManyRetries)
            }
        }
    }

    private func buildRequest(
        messages: [Message],
        attachments: [LoadedFile],
        temperature: Double
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
            temperature: temperature,
            messages: messages.map { message in
                let attachmentPayloads = message.attachments.map { attachment -> RequestPayload.MessagePayload.AttachmentPayload in
                    switch attachment {
                    case .file(let path):
                        return .init(type: "file", path: path, language: nil, content: nil)
                    case .code(let language, let content):
                        return .init(type: "code", path: nil, language: language, content: content)
                    }
                }
                return RequestPayload.MessagePayload(
                    role: message.role.rawValue,
                    content: message.text,
                    attachments: attachmentPayloads
                )
            },
            context: attachments.map {
                RequestPayload.ContextFilePayload(path: $0.url.path, content: $0.content)
            }
        )

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(payload)
        return request
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("Invalid HTTP response")
        }

        switch http.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 403:
            throw APIError.forbidden
        case 429:
            var retryAfter: TimeInterval?
            if let header = http.value(forHTTPHeaderField: "Retry-After"), let value = TimeInterval(header) {
                retryAfter = value
            }
            throw APIError.rateLimited(retryAfter: retryAfter)
        case 500...599:
            throw APIError.server(status: http.statusCode)
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.transport("Status \(http.statusCode): \(message)")
        }
    }

    private func parseStream(
        data: Data,
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) throws {
        guard let string = String(data: data, encoding: .utf8) else {
            throw APIError.decodingFailed
        }

        let decoder = JSONDecoder()
        let lines = string
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.hasPrefix("data:") else { continue }

            let payloadString = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payloadString == "[DONE]" {
                break
            }

            guard let payloadData = payloadString.data(using: .utf8) else {
                logger.error("Codex stream payload could not be converted to data.")
                continue
            }

            do {
                let chunk = try decoder.decode(StreamChunkPayload.self, from: payloadData)
                switch chunk.type {
                case "text":
                    if let text = chunk.text {
                        continuation.yield(.text(text))
                    }
                case "diff":
                    if let diff = chunk.diff {
                        continuation.yield(.diff(file: diff.file, patch: diff.patch))
                    }
                case "file":
                    if let file = chunk.file {
                        continuation.yield(.file(path: file.path, content: file.content))
                    }
                default:
                    logger.debug("Ignoring Codex stream chunk of type \(chunk.type, privacy: .public)")
                }
            } catch {
                logger.error("Failed to decode Codex stream payload: \(error.localizedDescription, privacy: .public)")
                throw APIError.decodingFailed
            }
        }
    }

    private func retryDelay(for error: APIError, attempt: Int) -> TimeInterval? {
        switch error {
        case .rateLimited(let retryAfter):
            return retryAfter ?? pow(2.0, Double(attempt))
        case .server:
            return pow(2.0, Double(attempt))
        default:
            return nil
        }
    }
}
