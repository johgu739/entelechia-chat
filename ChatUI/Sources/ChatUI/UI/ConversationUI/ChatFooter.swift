import SwiftUI
import UIConnections

struct ChatFooter: View {
    let contextSnapshot: ContextSnapshot?
    let activeScope: ContextScopeChoice
    let onViewDetails: () -> Void
    let inputBar: ChatInputBar
    let contextPopover: ContextBuildResult?
    
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

