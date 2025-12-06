// @EntelechiaHeaderStart
// Signifier: CodeView
// Substance: Operator code view
// Genus: UI view
// Differentia: Displays code with navigation/edit affordances
// Form: Code display/editor composition
// Matter: Source text; highlights; selections
// Powers: Show code; allow navigation/edit affordances
// FinalCause: Inspect or edit code within operator context
// Relations: Serves operator workspace; depends on file content state
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import Engine
import AppKit

struct CodeView: NSViewRepresentable {
    let fileURL: URL

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        if let content = try? String(contentsOf: fileURL, encoding: .utf8) {
            nsView.string = content
        }
    }
}