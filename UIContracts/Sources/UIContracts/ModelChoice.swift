import Foundation

/// Model selector for Codex queries (pure value type).
public enum ModelChoice: String, CaseIterable, Sendable {
    case codex
    case stub
}

