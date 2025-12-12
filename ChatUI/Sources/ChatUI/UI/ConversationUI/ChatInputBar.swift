import SwiftUI
import UIContracts

struct ChatInputBar: View {
    @Binding var text: String
    var isAskEnabled: Bool
    var isSending: Bool
    var modelSelection: Binding<UIContracts.ModelChoice>
    var scopeSelection: Binding<UIContracts.ContextScopeChoice>
    var onSend: () -> Void
    var onAsk: () -> Void
    var onAttach: () -> Void
    var onMic: () -> Void
    
    @FocusState private var isFocused: Bool
    @State private var measuredHeight: CGFloat = 38
    
    private let cornerRadius: CGFloat = DS.r16
    private var lineHeight: CGFloat {
        18
    }
    private var minEditorHeight: CGFloat { max(38, lineHeight + DS.s8) }
    private var maxEditorHeight: CGFloat { ceil(lineHeight * 5 + DS.s8) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.s8) {
            inputTextArea
            actionRow
        }
        .padding(.horizontal, DS.s16)
        .padding(.vertical, DS.s8)
        .background(inputBackground)
        .padding(.horizontal, DS.s16)
        .padding(.top, DS.s8)
        .padding(.bottom, DS.s8)
        .onAppear { isFocused = true }
    }
    
    private var inputTextArea: some View {
        InputTextArea(
            text: $text,
            measuredHeight: $measuredHeight,
            isFocused: $isFocused,
            minEditorHeight: minEditorHeight,
            maxEditorHeight: maxEditorHeight,
            onSend: send
        )
    }
    
    private var actionRow: some View {
        HStack(alignment: .bottom, spacing: DS.s12) {
            InputAttachButton(action: onAttach)
            Spacer()
            InputActionCluster(
                text: $text,
                isAskEnabled: isAskEnabled,
                modelSelection: modelSelection,
                scopeSelection: scopeSelection,
                onMic: onMic,
                onAsk: ask,
                onSend: send
            )
        }
    }
    
    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(DS.background)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DS.stroke, lineWidth: 1)
            )
    }
    
    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend()
        text = ""
    }
    
    private func ask() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onAsk()
        text = ""
    }
}
