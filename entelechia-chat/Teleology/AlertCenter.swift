// @EntelechiaHeaderStart
// Signifier: AlertCenter
// Substance: Global user-facing error bus
// Genus: Teleological support faculty
// Differentia: Publishes canonical alerts consumed by the UI shell
// Form: ObservableObject encapsulating UserFacingError routing
// Matter: Error metadata (title, message, recovery suggestion)
// Powers: Accept errors from view models and expose them to the Accidents layer
// FinalCause: Ensure recoverable faults surface as non-blocking UI alerts
// Relations: Shared across Teleology, Intelligence, and Accidents
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Combine
import Foundation

struct UserFacingError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let recoverySuggestion: String?

    init(title: String, message: String, recoverySuggestion: String? = nil) {
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }
}

@MainActor
final class AlertCenter: ObservableObject {
    @Published var alert: UserFacingError?

    func publish(_ error: UserFacingError) {
        alert = error
    }

    func publish(_ error: Error, fallbackTitle: String = "Something went wrong") {
        alert = error.asUserFacingError(fallbackTitle: fallbackTitle)
    }
}

extension Error {
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
