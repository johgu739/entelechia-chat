import Foundation
import AppCoreEngine
import UIContracts

public enum CodexAvailability {
    case connected
    case degradedStub
    case misconfigured(Error)
}

/// Service for querying Codex/AI models with workspace context.
/// Power: Descriptive (queries LLM) - no file mutation authority.
/// Marked `@unchecked Sendable` because internal dependencies (engines, clients) are
/// thread-safe and accessed via async/await boundaries.
public final class CodexQueryService: @unchecked Sendable, CodexQuerying {
    private let conversationEngine: ConversationStreaming
    private let workspaceEngine: WorkspaceEngine
    private let codexClient: AnyCodexClient
    private let contextPreparer: WorkspaceContextPreparer
    private let contextEncoder: WorkspaceContextEncoder
    private let segmenter: WorkspaceContextSegmenter
    private let retryPolicy: AppCoreEngine.RetryPolicy
    private let promptShaper: CodexPromptShaper

    public init(
        conversationEngine: ConversationStreaming,
        workspaceEngine: WorkspaceEngine,
        codexClient: AnyCodexClient,
        fileLoader: FileContentLoading,
        contextSegmenter: WorkspaceContextSegmenter = WorkspaceContextSegmenter(),
        retryPolicy: AppCoreEngine.RetryPolicy
    ) {
        self.conversationEngine = conversationEngine
        self.workspaceEngine = workspaceEngine
        self.codexClient = codexClient
        self.contextPreparer = WorkspaceContextPreparer(fileLoader: fileLoader)
        self.contextEncoder = WorkspaceContextEncoder()
        self.segmenter = contextSegmenter
        self.retryPolicy = retryPolicy
        self.promptShaper = CodexPromptShaper()
    }

    public func shapedPrompt(_ text: String) -> String {
        promptShaper.shape(text)
    }

    public func askAboutWorkspaceNode(
        scope: UIContracts.WorkspaceScope,
        question: String,
        onStream: ((String) -> Void)? = nil
    ) async throws -> CodexAnswer {
        try Task.checkCancellation()
        let shaped = promptShaper.shape(question)
        let snapshot = await workspaceEngine.snapshot()

        let descriptorIDs: [AppCoreEngine.FileID]? = {
            switch scope {
            case .descriptor(let uiFileID): 
                return [AppCoreEngine.FileID(uiFileID.rawValue)]
            case .path(let path):
                if let id = snapshot.descriptorPaths.first(where: { $0.value == path })?.key {
                    return [id]
                }
                return nil
            case .selection:
                if let id = snapshot.selectedDescriptorID { return [id] }
                return nil
            }
        }()

        let contextResult = try await contextPreparer.prepare(
            snapshot: snapshot,
            preferredDescriptorIDs: descriptorIDs,
            budget: .default
        )
        try Task.checkCancellation()

        let encodedFiles = contextEncoder.encode(files: contextResult.attachments)
        let segments = segmenter.segment(files: encodedFiles)

        let systemPrompt = """
You are Codex. Answer only with plain text. Do not propose edits.
Context is provided in stable segments; respect ordering.
"""
        let userPrompt = makeUserPrompt(question: shaped, segments: segments)

        let messages = [
            AppCoreEngine.Message(role: .system, text: systemPrompt, createdAt: Date()),
            AppCoreEngine.Message(role: .user, text: userPrompt, createdAt: Date())
        ]

        let text = try await streamWithRetry(
            messages: messages,
            contextFiles: contextResult.attachments,
            onStream: onStream
        )

        return CodexAnswer(text: text, context: DomainToUIMappers.toUIContextBuildResult(contextResult))
    }

    private func makeUserPrompt(question: String, segments: [ContextSegment]) -> String {
        var lines: [String] = []
        for (idx, segment) in segments.enumerated() {
            lines.append("## Context Segment \(idx + 1)")
            for file in segment.files {
                lines.append("-- \(file.path)")
                lines.append(file.content)
            }
        }
        lines.append("## Question")
        lines.append(question)
        return lines.joined(separator: "\n")
    }

    private func streamWithRetry(
        messages: [AppCoreEngine.Message],
        contextFiles: [LoadedFile],
        onStream: ((String) -> Void)?
    ) async throws -> String {
        var lastError: Error?
        for attempt in 0...retryPolicy.maxRetries {
            try Task.checkCancellation()
            do {
                return try await streamOnce(messages: messages, contextFiles: contextFiles, onStream: onStream)
            } catch {
                lastError = error
                if attempt == retryPolicy.maxRetries { break }
                let delay = retryPolicy.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? StreamTransportError.invalidResponse("Unknown failure")
    }

    private func streamOnce(
        messages: [AppCoreEngine.Message],
        contextFiles: [LoadedFile],
        onStream: ((String) -> Void)?
    ) async throws -> String {
        var buffer = ""
        let stream = try await codexClient.stream(messages: messages, contextFiles: contextFiles)
        for try await chunk in stream {
            try Task.checkCancellation()
            switch chunk {
            case .token(let token):
                buffer += token
                onStream?(buffer)
            case .output(let payload):
                buffer += payload.content
                onStream?(buffer)
            case .done:
                return buffer
            }
        }
        return buffer
    }
}

