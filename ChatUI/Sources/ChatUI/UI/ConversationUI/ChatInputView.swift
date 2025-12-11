// @EntelechiaHeaderStart
// Signifier: ChatInputView
// Substance: Input accident
// Genus: UI control
// Differentia: Captures chat input
// Form: TextField and send handling
// Matter: User text; send actions
// Powers: Capture and dispatch user messages
// FinalCause: Initiate conversation acts
// Relations: Serves ChatView; depends on VM
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit

struct ChatInputView: View {
    @Binding var text: String
    let onSend: () -> Void
    let onAttachFile: () -> Void
    let onAskCodex: (() -> Void)?
    let isAskEnabled: Bool
    let currentTarget: String?
    let sendShortcut: String
    let askShortcut: String
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.s8) {
            targetRow
            inputRow
        }
        .padding(.horizontal, DS.s4)
        .onAppear { isFocused = true }
    }
    
    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend()
        text = ""
    }

    private func ask(_ handler: () -> Void) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        handler()
        text = ""
    }
    
    @ViewBuilder
    private var targetRow: some View {
        if let currentTarget, !currentTarget.isEmpty {
            HStack(spacing: DS.s6) {
                Image(systemName: "folder")
                    .foregroundColor(DS.secondaryText)
                    .font(.system(size: 11, weight: .semibold))
                Text(currentTarget)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(DS.secondaryText)
            }
            .padding(.horizontal, DS.s4)
        }
    }
    
    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: DS.s8) {
            attachButton
            editor
            actionButtons
        }
        .padding(.horizontal, DS.s12)
        .padding(.vertical, DS.s10)
        .background(
            RoundedRectangle(cornerRadius: DS.r16)
                .fill(DS.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.r16)
                        .stroke(DS.stroke, lineWidth: 1)
                )
        )
        .frame(
            minHeight: DS.s12 * CGFloat(4),
            maxHeight: DS.s20 * CGFloat(9),
            alignment: .top
        )
    }
    
    private var attachButton: some View {
        Button(
            action: { onAttachFile() },
            label: {
                Image(systemName: "plus")
                    .foregroundColor(DS.secondaryText)
                    .font(.system(size: 16, weight: .medium))
                    .accessibilityLabel("Attach file")
            }
        )
        .buttonStyle(.plain)
    }
    
    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("Message Codex…")
                    .foregroundColor(DS.secondaryText)
                    .font(DS.body)
                    .padding(.vertical, DS.s8)
                    .padding(.horizontal, DS.s6)
                    .allowsHitTesting(false)
            }
            
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .font(DS.body)
                .padding(.vertical, DS.s6)
                .padding(.horizontal, DS.s4)
                .frame(
                    minHeight: DS.s12 * CGFloat(3),
                    maxHeight: DS.s20 * CGFloat(6),
                    alignment: .top
                )
                .fixedSize(horizontal: false, vertical: true)
                .focused($isFocused)
                .onChange(of: text) { oldValue, newValue in
                    if newValue.contains("\n") && !oldValue.contains("\n") {
                        if let event = NSApp.currentEvent, !event.modifierFlags.contains(.command) {
                            let trimmed = text.replacingOccurrences(of: "\n", with: "")
                            text = trimmed
                            if !trimmed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                send()
                            }
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var actionButtons: some View {
        HStack(spacing: DS.s6) {
            if let onAskCodex {
                Button(
                    action: { ask(onAskCodex) },
                    label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(actionEnabled && isAskEnabled ? .accentColor : DS.secondaryText)
                            .accessibilityLabel("Ask Codex")
                    }
                )
                .buttonStyle(.plain)
                .disabled(!actionEnabled || !isAskEnabled)
            }
            
            Button(
                action: { send() },
                label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(actionEnabled ? .accentColor : DS.secondaryText)
                        .font(.system(size: 16, weight: .semibold))
                        .accessibilityLabel("Send")
                }
            )
            .buttonStyle(.plain)
            .disabled(!actionEnabled)
        }
    }
    
    private var actionEnabled: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
