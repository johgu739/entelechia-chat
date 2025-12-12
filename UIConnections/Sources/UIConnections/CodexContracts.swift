import Foundation
import AppCoreEngine
import UIContracts

public enum WorkspaceScope: Equatable, Sendable {
    case descriptor(FileID)
    case path(String)
    case selection
}

public struct CodexAnswer: Equatable, Sendable {
    public let text: String
    public let context: UIContracts.UIContextBuildResult
    
    public init(text: String, context: UIContracts.UIContextBuildResult) {
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
    func shapedPrompt(_ text: String) -> String
}

