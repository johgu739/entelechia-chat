import Foundation
import AppCoreEngine
import AppAdapters

public enum WorkspaceScope: Equatable, Sendable {
    case descriptor(FileID)
    case path(String)
    case selection
}

public struct CodexAnswer: Equatable, Sendable {
    public let text: String
    public let context: ContextBuildResult
    
    public init(text: String, context: ContextBuildResult) {
        self.text = text
        self.context = context
    }
}

public protocol CodexQuerying: Sendable {
    func askAboutWorkspaceNode(
        scope: WorkspaceScope,
        question: String,
        onStream: ((String) -> Void)?
    ) async throws -> CodexAnswer
}

