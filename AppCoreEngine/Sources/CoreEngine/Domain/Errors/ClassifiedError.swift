import Foundation

/// Domain-classified error with severity and intent.
/// Separates error meaning from UI presentation.
public struct ClassifiedError: Sendable, Equatable {
    public enum Severity: Sendable {
        case info
        case warning
        case error
        case critical
    }
    
    public enum Intent: Sendable {
        case userAction
        case contextNotification
        case systemAlert
        case silentLog
    }
    
    public let underlying: Error
    public let severity: Severity
    public let intent: Intent
    public let title: String
    public let message: String
    public let recoverySuggestion: String?
    
    public init(
        underlying: Error,
        severity: Severity,
        intent: Intent,
        title: String,
        message: String,
        recoverySuggestion: String? = nil
    ) {
        self.underlying = underlying
        self.severity = severity
        self.intent = intent
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }
    
    // Equatable conformance (Error is not Equatable, so we compare by description)
    public static func == (lhs: ClassifiedError, rhs: ClassifiedError) -> Bool {
        lhs.severity == rhs.severity &&
        lhs.intent == rhs.intent &&
        lhs.title == rhs.title &&
        lhs.message == rhs.message &&
        lhs.recoverySuggestion == rhs.recoverySuggestion
    }
}

