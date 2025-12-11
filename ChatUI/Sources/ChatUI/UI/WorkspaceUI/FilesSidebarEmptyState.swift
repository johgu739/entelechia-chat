import SwiftUI

struct FilesSidebarEmptyState: View {
    let onDrop: ([NSItemProvider]) -> Bool
    
    var body: some View {
        VStack(spacing: DS.s12) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("No files attached")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("Drag files here or click +")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDrop(of: ["public.file-url"], isTargeted: nil, perform: onDrop)
    }
}
