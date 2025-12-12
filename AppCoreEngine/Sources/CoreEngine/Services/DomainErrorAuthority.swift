import Foundation
@preconcurrency import Combine

/// Domain authority for error classification.
/// Power: Decisional (classifies errors, assigns severity/intent)
/// Does NOT route to UI - emits ClassifiedError for UI layer.
public final class DomainErrorAuthority: @unchecked Sendable {
    private let errorSubject = PassthroughSubject<ClassifiedError, Never>()
    
    public var errorPublisher: AnyPublisher<ClassifiedError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    public init() {}
    
    public func classify(_ error: Error, context: String? = nil) -> ClassifiedError {
        // Domain logic to classify errors
        // Assigns severity and intent based on error type and context
        let severity: ClassifiedError.Severity
        let intent: ClassifiedError.Intent
        
        if let engineError = error as? EngineError {
            switch engineError {
            case .contextLoadFailed:
                severity = .warning
                intent = .contextNotification
            case .streamingTransport:
                severity = .error
                intent = .userAction
            case .invalidMutation:
                severity = .error
                intent = .systemAlert
            case .conversationNotFound:
                severity = .warning
                intent = .contextNotification
            default:
                severity = .error
                intent = .systemAlert
            }
        } else {
            severity = .error
            intent = .systemAlert
        }
        
        let title = (error as? LocalizedError)?.errorDescription ?? "Error"
        let message = (error as? LocalizedError)?.failureReason ?? error.localizedDescription
        let recovery = (error as? LocalizedError)?.recoverySuggestion
        
        return ClassifiedError(
            underlying: error,
            severity: severity,
            intent: intent,
            title: title,
            message: message,
            recoverySuggestion: recovery
        )
    }
    
    public func publish(_ error: Error, context: String? = nil) {
        let correlationID = UUID()
        TeleologicalTracer.shared.trace("DomainErrorAuthority.publish", power: .decisional, correlationID: correlationID)
        let classified = classify(error, context: context)
        errorSubject.send(classified)
    }
}

