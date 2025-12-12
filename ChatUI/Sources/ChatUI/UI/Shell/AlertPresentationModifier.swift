import SwiftUI

struct AlertPresentationModifier: ViewModifier {
    let alert: AlertItem?
    let onDismiss: () -> Void
    
    struct AlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let recoverySuggestion: String?
    }
    
    func body(content: Content) -> some View {
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
