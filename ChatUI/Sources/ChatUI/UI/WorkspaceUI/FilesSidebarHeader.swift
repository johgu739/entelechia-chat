import SwiftUI

struct FilesSidebarHeader: View {
    let hasFiles: Bool
    let onAdd: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            Text("Context Files")
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("Add files")
            
            if hasFiles {
                Button(action: onClear) {
                    Image(systemName: "trash")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.borderless)
                .help("Clear all context files")
            }
        }
        .padding(.horizontal, DS.s12)
        .padding(.vertical, DS.s8)
        .background(AppTheme.windowBackground)
        .overlay(Divider(), alignment: .bottom)
    }
}
