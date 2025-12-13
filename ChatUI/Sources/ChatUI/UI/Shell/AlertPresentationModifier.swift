import SwiftUI

public struct AlertPresentationModifier: ViewModifier {
    let alert: AlertItem?
    let onDismiss: () -> Void
    
    public struct AlertItem: Identifiable {
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
    
    public func body(content: Content) -> some View {
        content
            .alert(item: Binding(
                get: { alert },
                set: { _ in onDismiss() }
            )) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message + (alert.recoverySuggestion.map { "\n\n\($0)" } ?? "")),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

extension View {
    func alertPresentation(alert: AlertPresentationModifier.AlertItem?, onDismiss: @escaping () -> Void) -> some View {
        modifier(AlertPresentationModifier(alert: alert, onDismiss: onDismiss))
    }
}
