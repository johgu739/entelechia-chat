// @EntelechiaHeaderStart
// Substance: File icon UI
// Genus: UI icon view
// Differentia: Selects icon by file type
// Form: Icon selection rules
// Matter: FileNode/URL extensions
// Powers: Render appropriate file symbol
// FinalCause: Visually cue file types in lists
// Relations: Serves navigator/sidebar UI
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// SwiftUI view that displays native macOS file/folder icons
struct FileIconView: View {
    let url: URL
    let isDirectory: Bool
    let isParentDirectory: Bool
    
    var body: some View {
        Group {
            if isParentDirectory {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
            } else {
                Image(nsImage: fileIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 16, height: 16)
            }
        }
    }
    
    private var fileIcon: NSImage {
        // Use NSWorkspace to get native macOS file/folder icons
        // This automatically handles:
        // - Folder icons (with correct styling)
        // - File type icons (Swift files, images, PDFs, etc.)
        // - Custom file icons set by the system or user
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
