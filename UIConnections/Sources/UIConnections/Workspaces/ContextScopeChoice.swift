import Foundation

/// View-facing scope selector for Codex context.
public enum ContextScopeChoice: String, CaseIterable, Sendable {
    case selection
    case workspace
    case selectionAndSiblings
    case manual
    
    public var displayName: String {
        switch self {
        case .selection: return "Selection"
        case .workspace: return "Workspace"
        case .selectionAndSiblings: return "Selection + siblings"
        case .manual: return "Manual include…"
        }
    }
}

/// Model selector for Codex queries.
public enum ModelChoice: String, CaseIterable, Sendable {
    case codex
    case stub
    
    public var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .stub: return "Stub"
        }
    }
}

