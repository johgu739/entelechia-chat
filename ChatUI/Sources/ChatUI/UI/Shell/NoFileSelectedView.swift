// @EntelechiaHeaderStart
// Signifier: NoFileSelectedView
// Substance: Empty-state view
// Genus: UI placeholder
// Differentia: Shows no-selection copy
// Form: Static UI copy
// Matter: Text; layout
// Powers: Inform user nothing is selected
// FinalCause: Handle idle state gracefully
// Relations: Serves workspace UI
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI

struct NoFileSelectedView: View {
    var body: some View {
        VStack(spacing: DS.s16) {
            Image(systemName: "doc.text")
                .font(.system(size: DS.s16 * 3))
                .foregroundColor(.secondary)
            
            Text("Select a file or folder to begin chatting")
                .font(DS.body)
                .foregroundColor(DS.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .textBackgroundColor))
    }
}
