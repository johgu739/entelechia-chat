// @EntelechiaHeaderStart
// Signifier: TerminalView
// Substance: Operator terminal view
// Genus: UI view
// Differentia: Renders console I/O
// Form: Output/input console rendering
// Matter: Command text; logs; status
// Powers: Display terminal output; accept commands
// FinalCause: Mirror command-line interactions inside operator UI
// Relations: Serves operator workflows; depends on daemon outputs
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import Engine
import AppKit

struct TerminalView: NSViewRepresentable {
    let streamID: String

    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = .black
        textView.textColor = .green
        return textView
    }

    func updateNSView(_ nsView: NSTextView, context: Context) {
        nsView.string = "Live logs for \(streamID) will appear here."
    }
}