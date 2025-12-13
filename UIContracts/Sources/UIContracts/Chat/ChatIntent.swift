import Foundation

/// Chat user intents.
public enum ChatIntent: Sendable, Equatable {
    case sendMessage(String, UUID)
    case askCodex(String, UUID)
    case setContextScope(ContextScopeChoice)
    case setModelChoice(ModelChoice)
}


