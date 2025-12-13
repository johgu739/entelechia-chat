import Foundation
import AppCoreEngine
import UIContracts

// Import WorkspaceScope from UIConnections (it's defined in CodexContracts.swift)
// We'll handle this via typealias or direct reference

/// Mappers from domain types (AppCoreEngine) to UI types (UIContracts).
/// Power: Descriptive (transforms, does not decide)
public enum DomainToUIMappers {
    
    // MARK: - Conversation & Message
    
    public static func toUIConversation(_ conversation: AppCoreEngine.Conversation) -> UIContracts.UIConversation {
        UIContracts.UIConversation(
            id: conversation.id,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            messages: conversation.messages.map(toUIMessage),
            contextFilePaths: conversation.contextFilePaths,
            contextDescriptorIDs: conversation.contextDescriptorIDs?.map { $0.rawValue }
        )
    }
    
    public static func toUIMessage(_ message: AppCoreEngine.Message) -> UIContracts.UIMessage {
        UIContracts.UIMessage(
            id: message.id,
            role: toUIMessageRole(message.role),
            text: message.text,
            createdAt: message.createdAt,
            attachments: message.attachments.map(toUIAttachment)
        )
    }
    
    public static func toUIMessageRole(_ role: AppCoreEngine.MessageRole) -> UIContracts.UIMessageRole {
        switch role {
        case .user: return UIContracts.UIMessageRole.user
        case .assistant: return UIContracts.UIMessageRole.assistant
        case .system: return UIContracts.UIMessageRole.system
        }
    }
    
    public static func toUIAttachment(_ attachment: AppCoreEngine.Attachment) -> UIContracts.UIAttachment {
        switch attachment {
        case .file(let path):
            return UIContracts.UIAttachment.file(path: path)
        case .code(let language, let content):
            return UIContracts.UIAttachment.code(language: language, content: content)
        }
    }
    
    // MARK: - Workspace
    
    public static func toUIWorkspaceTree(_ projection: AppCoreEngine.WorkspaceTreeProjection) -> UIContracts.UIWorkspaceTree {
        UIContracts.UIWorkspaceTree(
            id: projection.id.rawValue,
            name: projection.name,
            path: projection.path,
            isDirectory: projection.isDirectory,
            children: projection.children.map(toUIWorkspaceTree)
        )
    }
    
    public static func toUIContextInclusionState(_ state: AppCoreEngine.ContextInclusionState) -> UIContracts.UIContextInclusionState {
        switch state {
        case .included: return UIContracts.UIContextInclusionState.included
        case .excluded: return UIContracts.UIContextInclusionState.excluded
        case .neutral: return UIContracts.UIContextInclusionState.neutral
        }
    }
    
    public static func toWorkspaceViewState(
        rootPath: String?,
        selectedDescriptorID: AppCoreEngine.FileID?,
        selectedPath: String?,
        projection: AppCoreEngine.WorkspaceTreeProjection?,
        contextInclusions: [AppCoreEngine.FileID: AppCoreEngine.ContextInclusionState],
        watcherError: String?
    ) -> UIContracts.WorkspaceViewState {
        UIContracts.WorkspaceViewState(
            rootPath: rootPath,
            selectedDescriptorID: selectedDescriptorID.map { (fileID: AppCoreEngine.FileID) -> UUID in fileID.rawValue },
            selectedPath: selectedPath,
            projection: projection.map(toUIWorkspaceTree),
            contextInclusions: Dictionary(uniqueKeysWithValues: contextInclusions.map { (key: AppCoreEngine.FileID, value: AppCoreEngine.ContextInclusionState) -> (UUID, UIContracts.UIContextInclusionState) in
                (UIContracts.FileID(key.rawValue).rawValue, toUIContextInclusionState(value))
            }),
            watcherError: watcherError
        )
    }
    
    // MARK: - Context
    
    public static func toUIContextBuildResult(_ result: AppCoreEngine.ContextBuildResult) -> UIContracts.UIContextBuildResult {
        UIContextBuildResult(
            attachments: result.attachments.map(toUILoadedFile),
            truncatedFiles: result.truncatedFiles.map(toUILoadedFile),
            excludedFiles: result.excludedFiles.map(toUIContextExclusion),
            totalBytes: result.totalBytes,
            totalTokens: result.totalTokens,
            encodedSegments: result.encodedSegments.map(toUIContextSegment),
            budget: toContextBudgetView(result.budget)
        )
    }
    
    public static func toContextBudgetView(_ budget: AppCoreEngine.ContextBudget) -> UIContracts.ContextBudgetView {
        UIContracts.ContextBudgetView(
            maxPerFileBytes: budget.maxPerFileBytes,
            maxPerFileTokens: budget.maxPerFileTokens,
            maxTotalBytes: budget.maxTotalBytes,
            maxTotalTokens: budget.maxTotalTokens
        )
    }
    
    public static func toUILoadedFile(_ file: AppCoreEngine.LoadedFile) -> UIContracts.UILoadedFile {
        UIContracts.UILoadedFile(
            id: file.id,
            path: file.url.path,
            language: file.fileTypeIdentifier,
            size: file.byteCount,
            hash: nil
        )
    }
    
    public static func toUIContextExclusion(_ exclusion: AppCoreEngine.ContextExclusion) -> UIContracts.UIContextExclusion {
        UIContracts.UIContextExclusion(
            id: exclusion.id,
            file: toUILoadedFile(exclusion.file),
            reason: exclusionReasonToString(exclusion.reason)
        )
    }
    
    public static func toUIContextSegment(_ segment: AppCoreEngine.ContextSegment) -> UIContracts.UIContextSegment {
        UIContracts.UIContextSegment(
            files: segment.files.map { file in
                UILoadedFile(
                    id: UUID(),
                    path: file.path,
                    language: file.language,
                    size: file.size,
                    hash: file.hash
                )
            },
            totalTokens: segment.totalTokens,
            totalBytes: segment.totalBytes
        )
    }
    
    // MARK: - Projects
    
    public static func toUIProjectTodos(_ todos: AppCoreEngine.ProjectTodos) -> UIContracts.UIProjectTodos {
        UIContracts.UIProjectTodos(
            generatedAt: todos.generatedAt,
            missingHeaders: todos.missingHeaders,
            missingFolderTelos: todos.missingFolderTelos,
            filesWithIncompleteHeaders: todos.filesWithIncompleteHeaders,
            foldersWithIncompleteTelos: todos.foldersWithIncompleteTelos,
            allTodos: todos.allTodos
        )
    }
    
    public static func toUIProjectRepresentation(_ representation: AppCoreEngine.ProjectRepresentation) -> UIContracts.UIProjectRepresentation {
        UIContracts.UIProjectRepresentation(
            rootPath: representation.rootPath,
            name: representation.name,
            metadata: representation.metadata,
            linkedFiles: representation.linkedFiles
        )
    }
    
    static func toRecentProject(_ project: RecentProject) -> UIContracts.RecentProject {
        UIContracts.RecentProject(
            representation: toUIProjectRepresentation(project.representation),
            bookmarkData: project.bookmarkData
        )
    }
    
    
    // MARK: - Helpers
    
    private static func exclusionReasonToString(_ reason: AppCoreEngine.ContextExclusionReason) -> String {
        switch reason {
        case .exceedsPerFileBytes(let limit):
            return "Exceeds per-file bytes limit: \(limit)"
        case .exceedsPerFileTokens(let limit):
            return "Exceeds per-file tokens limit: \(limit)"
        case .exceedsTotalBytes(let limit):
            return "Exceeds total bytes limit: \(limit)"
        case .exceedsTotalTokens(let limit):
            return "Exceeds total tokens limit: \(limit)"
        }
    }
}

