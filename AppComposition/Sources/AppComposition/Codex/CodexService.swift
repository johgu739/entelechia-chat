import Foundation
import AppCoreEngine
import AppAdapters
import UIConnections

public struct CodexPromptShaper: Sendable {
    public init() {}
    public func shape(_ userText: String) -> String {
        userText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public typealias WorkspaceScope = UIConnections.WorkspaceScope
public typealias CodexAnswer = UIConnections.CodexAnswer

public final class CodexMutationPipeline: @unchecked Sendable {
    private let authority: FileMutationAuthorizing

    public init(authority: FileMutationAuthorizing) {
        self.authority = authority
    }

    public func applyUnifiedDiff(_ diffText: String, rootPath: String) throws -> [AppliedPatchResult] {
        let fileDiffs = UnifiedDiffParser.parse(diffText: diffText)
        return try authority.apply(diffs: fileDiffs, rootPath: rootPath)
    }
}

public final class CodexService: @unchecked Sendable {
    private let conversationEngine: ConversationStreaming
    private let workspaceEngine: WorkspaceEngine
    private let codexClient: AnyCodexClient
    private let contextPreparer: WorkspaceContextPreparer
    private let contextEncoder: WorkspaceContextEncoder
    private let segmenter: WorkspaceContextSegmenter
    private let retryPolicy: RetryPolicy
    private let promptShaper: CodexPromptShaper
    private let mutationPipeline: CodexMutationPipeline

    public init(
        conversationEngine: ConversationStreaming,
        workspaceEngine: WorkspaceEngine,
        codexClient: AnyCodexClient,
        fileLoader: FileContentLoading,
        contextSegmenter: WorkspaceContextSegmenter = WorkspaceContextSegmenter(),
        retryPolicy: RetryPolicy = RetryPolicy(),
        mutationPipeline: CodexMutationPipeline,
        promptShaper: CodexPromptShaper = CodexPromptShaper()
    ) {
        self.conversationEngine = conversationEngine
        self.workspaceEngine = workspaceEngine
        self.codexClient = codexClient
        self.contextPreparer = WorkspaceContextPreparer(fileLoader: fileLoader)
        self.contextEncoder = WorkspaceContextEncoder()
        self.segmenter = contextSegmenter
        self.retryPolicy = retryPolicy
        self.mutationPipeline = mutationPipeline
        self.promptShaper = promptShaper
    }

    public func shapedPrompt(_ text: String) -> String {
        promptShaper.shape(text)
    }

    public func applyDiff(_ diffText: String, rootPath: String) throws -> [AppliedPatchResult] {
        try mutationPipeline.applyUnifiedDiff(diffText, rootPath: rootPath)
    }

    /// Read-only Codex query for a workspace node.
    public func askAboutWorkspaceNode(
        scope: WorkspaceScope,
        question: String,
        onStream: ((String) -> Void)? = nil
    ) async throws -> CodexAnswer {
        try Task.checkCancellation()
        let shaped = promptShaper.shape(question)
        let snapshot = await workspaceEngine.snapshot()

        let descriptorIDs: [FileID]? = {
            switch scope {
            case .descriptor(let id): return [id]
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
            Message(role: .system, text: systemPrompt, createdAt: Date()),
            Message(role: .user, text: userPrompt, createdAt: Date())
        ]

        let text = try await streamWithRetry(messages: messages, contextFiles: contextResult.attachments, onStream: onStream)

        return CodexAnswer(text: text, context: contextResult)
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
        messages: [Message],
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
                let delay = retryPolicy.backoff.delay(for: attempt)
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError ?? StreamTransportError.invalidResponse("Unknown failure")
    }

    private func streamOnce(
        messages: [Message],
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

private enum UnifiedDiffParser {
    static func parse(diffText: String) -> [FileDiff] {
        var diffs: [FileDiff] = []
        let lines = diffText.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var currentPath: String?
        var currentPatch: [String] = []

        func flush() {
            guard let path = currentPath, !currentPatch.isEmpty else { return }
            diffs.append(FileDiff(path: path, patch: currentPatch.joined(separator: "\n")))
            currentPatch.removeAll()
        }

        for line in lines {
            if line.hasPrefix("--- ") {
                flush()
                continue
            }
            if line.hasPrefix("+++ ") {
                let path = line.replacingOccurrences(of: "+++ b/", with: "").replacingOccurrences(of: "+++ ", with: "")
                currentPath = path
                currentPatch.append(line)
                continue
            }
            currentPatch.append(line)
        }
        flush()
        return diffs
    }
}

