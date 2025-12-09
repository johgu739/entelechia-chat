// @EntelechiaHeaderStart
// Signifier: OperatorChatView
// Substance: Operator chat surface
// Genus: UI view
// Differentia: Operator conversations with backend
// Form: Conversation view for operator interactions
// Matter: Messages; input bindings; streaming state
// Powers: Display chat; send prompts; show responses
// FinalCause: Let operator converse with Codex/backend
// Relations: Serves operator workflows; depends on app state and services
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppCoreEngine

struct OperatorChatView: View {
    let sessionID: UUID

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<5) { index in
                        if index % 2 == 0 {
                            UserMessageBubble(text: "Mock user message #\(index)")
                        } else {
                            MarkdownDocumentView(markdown: sampleMarkdown)
                                .padding(.leading, -8)
                        }
                    }
                }
                .padding(24)
            }

            Divider()

            ChatComposer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct UserMessageBubble: View {
    let text: String

    var body: some View {
        HStack {
            Spacer()
            Text(text)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

private struct ChatComposer: View {
    @State private var message: String = ""

    var body: some View {
        HStack(spacing: 12) {
            TextField("Message Codex…", text: $message, axis: .vertical)
                .textFieldStyle(.roundedBorder)
            Button("Send") {}
                .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }
}

private let sampleMarkdown = """
# Mock Codex Response

- Bullet one
- Bullet two

```swift
func example() {
    print("Hello")
}
```
"""
