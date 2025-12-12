import SwiftUI
import UIContracts

struct ChatFooter: View {
    let contextSnapshot: UIContracts.ContextSnapshot?
    let activeScope: UIContracts.ContextScopeChoice
    let onViewDetails: () -> Void
    let inputBar: ChatInputBar
    let contextPopover: UIContracts.UIContextBuildResult?
    
    var body: some View {
        VStack(spacing: DS.s6) {
            ContextBar(
                snapshot: contextSnapshot,
                activeScope: activeScope,
                onViewDetails: onViewDetails
            )
            inputBar
        }
        .padding(.bottom, 8)
        .background(
            Color.clear
                .ignoresSafeArea()
        )
        #if os(iOS)
        .modifier(KeyboardAdaptiveInset())
        #endif
    }
}

