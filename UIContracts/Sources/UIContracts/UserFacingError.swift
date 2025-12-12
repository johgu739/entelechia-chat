import Foundation

/// User-facing error for UI display (pure value type).
public struct UserFacingError: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let message: String
    public let recoverySuggestion: String?
    
    public init(id: UUID = UUID(), title: String, message: String, recoverySuggestion: String? = nil) {
        self.id = id
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }
}

