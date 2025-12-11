import SwiftUI

struct KeyboardAdaptiveInset: ViewModifier {
    #if os(iOS)
    @State private var bottom: CGFloat = 0
    #endif
    
    func body(content: Content) -> some View {
        #if os(iOS)
        content
            .padding(.bottom, bottom)
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillChangeFrameNotification
                )
            ) { notification in
                if let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    let height = UIScreen.main.bounds.height - frame.origin.y
                    bottom = max(0, height - UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                bottom = 0
            }
        #else
        content
        #endif
    }
}

extension View {
    func keyboardAdaptiveInset() -> some View {
        modifier(KeyboardAdaptiveInset())
    }
}

