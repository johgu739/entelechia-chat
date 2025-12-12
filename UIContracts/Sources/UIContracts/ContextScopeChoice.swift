import Foundation

/// View-facing scope selector for Codex context (pure value type).
public enum ContextScopeChoice: String, CaseIterable, Sendable {
    case selection
    case workspace
    case selectionAndSiblings
    case manual
}

