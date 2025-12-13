import Foundation
import UIContracts

/// Presentation helpers for UIContracts types.
/// These provide display formatting that was removed from UIContracts to maintain purity.
extension UIContracts.NavigatorMode {
    /// Icon name for this mode.
    public var icon: String {
        switch self {
        case .project: return "folder"
        case .todos: return "checklist"
        case .search: return "magnifyingglass"
        case .issues: return "exclamationmark.triangle"
        case .tests: return "checkmark.circle"
        case .reports: return "chart.bar"
        }
    }
}

extension UIContracts.ContextScopeChoice {
    /// Display name for this scope choice.
    public var displayName: String {
        switch self {
        case .selection: return "Selection"
        case .workspace: return "Workspace"
        case .selectionAndSiblings: return "Selection + siblings"
        case .manual: return "Manual include…"
        }
    }
}

extension UIContracts.ModelChoice {
    /// Display name for this model choice.
    public var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .stub: return "Stub"
        }
    }
}

extension UIContracts.ContextExclusionReasonView {
    /// Human-readable description of the exclusion reason.
    public var description: String {
        switch self {
        case .exceedsPerFileBytes(let limit):
            return "Exceeds per-file bytes limit (\(limit))"
        case .exceedsPerFileTokens(let limit):
            return "Exceeds per-file tokens limit (\(limit))"
        case .exceedsTotalBytes(let limit):
            return "Exceeds total bytes limit (\(limit))"
        case .exceedsTotalTokens(let limit):
            return "Exceeds total tokens limit (\(limit))"
        }
    }
}

extension UIContracts.ContextBuildResult {
    /// Count of attachments.
    public var attachmentCount: Int {
        attachments.count
    }
}

extension UIContracts.ProjectTodos {
    /// Total count used for badges.
    public func totalCount() -> Int {
        if !allTodos.isEmpty {
            return allTodos.count
        }
        return missingHeaders.count
        + missingFolderTelos.count
        + filesWithIncompleteHeaders.count
        + foldersWithIncompleteTelos.count
    }
    
    /// Flattened todos used for display.
    public func flatTodos() -> [String] {
        if !allTodos.isEmpty {
            return allTodos
        }
        
        var todos: [String] = []
        todos.append(contentsOf: missingHeaders.map { "Missing header: \($0)" })
        todos.append(contentsOf: missingFolderTelos.map { "Missing folder telos: \($0)" })
        todos.append(contentsOf: filesWithIncompleteHeaders.map { "Incomplete header: \($0)" })
        todos.append(contentsOf: foldersWithIncompleteTelos.map { "Incomplete folder telos: \($0)" })
        return todos
    }
}


