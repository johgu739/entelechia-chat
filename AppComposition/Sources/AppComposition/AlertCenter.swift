import Combine
import Foundation

public struct UserFacingError: Identifiable, Equatable {
    public let id = UUID()
    public let title: String
    public let message: String
    public let recoverySuggestion: String?

    public init(title: String, message: String, recoverySuggestion: String? = nil) {
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }
}

public final class AlertCenter: ObservableObject {
    @Published public var alert: UserFacingError?

    public init() {}

    public func publish(_ error: UserFacingError) {
        alert = error
    }

    public func publish(_ error: Error, fallbackTitle: String = "Something went wrong") {
        alert = error.asUserFacingError(fallbackTitle: fallbackTitle)
    }
}

public extension Error {
    func asUserFacingError(fallbackTitle: String) -> UserFacingError {
        if let userFacing = self as? UserFacingError {
            return userFacing
        }

        if let localized = self as? LocalizedError {
            return UserFacingError(
                title: localized.errorDescription ?? fallbackTitle,
                message: localized.failureReason ?? localized.errorDescription ?? fallbackTitle,
                recoverySuggestion: localized.recoverySuggestion
            )
        }

        return UserFacingError(
            title: fallbackTitle,
            message: localizedDescription,
            recoverySuggestion: nil
        )
    }
}


