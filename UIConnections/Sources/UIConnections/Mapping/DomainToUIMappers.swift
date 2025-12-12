import Foundation
import AppCoreEngine
import UIContracts

// Import WorkspaceScope from UIConnections (it's defined in CodexContracts.swift)
// We'll handle this via typealias or direct reference

/// Mappers from domain types (AppCoreEngine) to UI types (UIContracts).
/// Power: Descriptive (transforms, does not decide)
public enum DomainToUIMappers {
    
    // MARK: - Conversation & Message
    
    public static func toUIConversation(_ conversation: Conversation) -> UIConversation {
        UIConversation(
            id: conversation.id,
            title: conversation.title,
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            messages: conversation.messages.map(toUIMessage),
            contextFilePaths: conversation.contextFilePaths,
            contextDescriptorIDs: conversation.contextDescriptorIDs?.map { $0.rawValue }
        )
    }
    
    public static func toUIMessage(_ message: Message) -> UIMessage {
        UIMessage(
            id: message.id,
            role: toUIMessageRole(message.role),
            text: message.text,
            createdAt: message.createdAt,
            attachments: message.attachments.map(toUIAttachment)
        )
    }
    
    public static func toUIMessageRole(_ role: MessageRole) -> UIMessageRole {
        switch role {
        case .user: return .user
        case .assistant: return .assistant
        case .system: return .system
        }
    }
    
    public static func toUIAttachment(_ attachment: Attachment) -> UIAttachment {
        switch attachment {
        case .file(let path):
            return .file(path: path)
        case .code(let language, let content):
            return .code(language: language, content: content)
        }
    }
    
    // MARK: - Workspace
    
    public static func toUIWorkspaceTree(_ projection: WorkspaceTreeProjection) -> UIWorkspaceTree {
        UIWorkspaceTree(
            id: projection.id.rawValue,
            name: projection.name,
            path: projection.path,
            isDirectory: projection.isDirectory,
            children: projection.children.map(toUIWorkspaceTree)
        )
    }
    
    public static func toUIContextInclusionState(_ state: ContextInclusionState) -> UIContextInclusionState {
        switch state {
        case .included: return .included
        case .excluded: return .excluded
        case .neutral: return .neutral
        }
    }
    
    public static func toWorkspaceViewState(
        rootPath: String?,
        selectedDescriptorID: FileID?,
        selectedPath: String?,
        projection: WorkspaceTreeProjection?,
        contextInclusions: [FileID: ContextInclusionState],
        watcherError: String?
    ) -> WorkspaceViewState {
        WorkspaceViewState(
            rootPath: rootPath,
            selectedDescriptorID: selectedDescriptorID?.rawValue,
            selectedPath: selectedPath,
            projection: projection.map(toUIWorkspaceTree),
            contextInclusions: Dictionary(uniqueKeysWithValues: contextInclusions.map { ($0.rawValue, toUIContextInclusionState($1)) }),
            watcherError: watcherError
        )
    }
    
    // MARK: - Context
    
    public static func toUIContextBuildResult(_ result: ContextBuildResult) -> UIContextBuildResult {
        UIContextBuildResult(
            attachments: result.attachments.map(toUILoadedFile),
            truncatedFiles: result.truncatedFiles.map(toUILoadedFile),
            excludedFiles: result.excludedFiles.map(toUIContextExclusion),
            totalBytes: result.totalBytes,
            totalTokens: result.totalTokens,
            encodedSegments: result.encodedSegments.map(toUIContextSegment)
        )
    }
    
    public static func toUILoadedFile(_ file: LoadedFile) -> UILoadedFile {
        UILoadedFile(
            id: file.id,
            path: file.url.path,
            language: file.fileTypeIdentifier,
            size: file.byteCount,
            hash: nil
        )
    }
    
    public static func toUIContextExclusion(_ exclusion: ContextExclusion) -> UIContextExclusion {
        UIContextExclusion(
            id: exclusion.id,
            file: toUILoadedFile(exclusion.file),
            reason: exclusionReasonToString(exclusion.reason)
        )
    }
    
    public static func toUIContextSegment(_ segment: ContextSegment) -> UIContextSegment {
        UIContextSegment(
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
    
    public static func toUIProjectTodos(_ todos: ProjectTodos) -> UIProjectTodos {
        UIProjectTodos(
            generatedAt: todos.generatedAt,
            missingHeaders: todos.missingHeaders,
            missingFolderTelos: todos.missingFolderTelos,
            filesWithIncompleteHeaders: todos.filesWithIncompleteHeaders,
            foldersWithIncompleteTelos: todos.foldersWithIncompleteTelos,
            allTodos: todos.allTodos
        )
    }
    
    public static func toUIProjectRepresentation(_ representation: ProjectRepresentation) -> UIProjectRepresentation {
        UIProjectRepresentation(
            rootPath: representation.rootPath,
            name: representation.name,
            metadata: representation.metadata,
            linkedFiles: representation.linkedFiles
        )
    }
    
    public static func toRecentProject(_ project: RecentProject) -> UIContracts.RecentProject {
        UIContracts.RecentProject(
            representation: toUIProjectRepresentation(project.representation),
            bookmarkData: project.bookmarkData
        )
    }
    
    // MARK: - WorkspaceScope
    
    // Note: WorkspaceScope in UIConnections uses FileID, UIContracts uses UUID
    // This conversion happens when passing scope to UI
    public static func toWorkspaceScope(_ scope: WorkspaceScope) -> UIContracts.WorkspaceScope {
        switch scope {
        case .descriptor(let fileID):
            return .descriptor(fileID.rawValue)
        case .path(let path):
            return .path(path)
        case .selection:
            return .selection
        }
    }
    
    // MARK: - Helpers
    
    private static func exclusionReasonToString(_ reason: ContextExclusionReason) -> String {
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

