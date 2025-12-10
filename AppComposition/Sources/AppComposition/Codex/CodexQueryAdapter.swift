import Foundation
@preconcurrency import UIConnections
import AppCoreEngine
import AppAdapters

public struct CodexQueryAdapter: @unchecked Sendable, CodexQuerying {
    private let service: CodexService
    
    public init(service: CodexService) {
        self.service = service
    }
    
    public func askAboutWorkspaceNode(
        scope: WorkspaceScope,
        question: String,
        onStream: ((String) -> Void)?
    ) async throws -> UIConnections.CodexAnswer {
        try await service.askAboutWorkspaceNode(scope: scope, question: question, onStream: onStream)
    }
}

