// @EntelechiaHeaderStart
// Substance: UI accident palette
// Genus: UI theme
// Differentia: Defines colors and styles
// Form: Color and style definitions
// Matter: Color values; gradients
// Powers: Provide consistent theming
// FinalCause: Beautify and unify UI appearance
// Relations: Serves all UI views
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit

/// Centralized theme colors using native NSColor system colors
struct AppTheme {
    /// Root window background - native system color
    static var windowBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }
    
    /// Editor background - native system color
    static var editorBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }
    
    /// Sidebar/Inspector panel background - native system color
    static var panelBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }
    
    /// Input pill background - slightly darker than editor for subtle contrast
    static var inputBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }
}
