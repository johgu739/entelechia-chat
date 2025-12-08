// @EntelechiaHeaderStart
// Signifier: VisualEffectView
// Substance: Visual effect wrapper
// Genus: UI effect view
// Differentia: Wraps NSVisualEffectView
// Form: Bridge to material/blending params
// Matter: Material and blending parameters
// Powers: Provide blurred backgrounds
// FinalCause: Supply macOS visual style in SwiftUI
// Relations: Serves UI containers
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit

/// SwiftUI wrapper for NSVisualEffectView to match Xcode's sidebar appearance
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .withinWindow
    var state: NSVisualEffectView.State = .active
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}
