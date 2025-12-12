import SwiftUI
import UIContracts

struct InputActionCluster: View {
    @Binding var text: String
    let isAskEnabled: Bool
    let modelSelection: Binding<UIContracts.ModelChoice>
    let scopeSelection: Binding<UIContracts.ContextScopeChoice>
    let onMic: () -> Void
    let onAsk: () -> Void
    let onSend: () -> Void
    
    var body: some View {
        HStack(alignment: .bottom, spacing: DS.s12) {
            ContextScopeMenu(selection: scopeSelection)
            ModelMenu(selection: modelSelection)
            MicButton(action: onMic)
            AskButton(
                action: onAsk,
                isEnabled: isAskEnabled,
                hasText: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
            SendButton(
                action: onSend,
                hasText: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .font(.system(size: 16))
        .foregroundColor(DS.secondaryText)
    }
}

