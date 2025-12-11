import SwiftUI
import UIConnections

struct AlertPresentationModifier: ViewModifier {
    @ObservedObject var alertCenter: AlertCenter
    
    func body(content: Content) -> some View {
        content
            .alert(item: $alertCenter.alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message + (alert.recoverySuggestion.map { "\n\n\($0)" } ?? "")),
                    dismissButton: .default(Text("OK"), action: { alertCenter.alert = nil })
                )
            }
    }
}

extension View {
    func alertPresentation(alertCenter: AlertCenter) -> some View {
        modifier(AlertPresentationModifier(alertCenter: alertCenter))
    }
}
