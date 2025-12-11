import SwiftUI
import AppKit

enum DS {
    // Spacing
    static let s6: CGFloat = 6
    static let s4: CGFloat = 4
    static let s8: CGFloat = 8
    static let s10: CGFloat = 10
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s20: CGFloat = 20
    
    // Corners
    static let r12: CGFloat = 12
    static let r16: CGFloat = 16
    
    // Fonts
    static let body: Font = .system(size: 15)
    static let footnote: Font = .footnote
    static let caption2: Font = .caption2
    static let monoFootnote: Font = .system(.footnote, design: .monospaced)
    
    // Colors
    static let background: Color = Color(nsColor: .windowBackgroundColor)
    static let stroke: Color = Color(nsColor: .separatorColor)
    static let secondaryText: Color = Color(nsColor: .secondaryLabelColor)
    static let tertiaryText: Color = Color(nsColor: .tertiaryLabelColor)
}

