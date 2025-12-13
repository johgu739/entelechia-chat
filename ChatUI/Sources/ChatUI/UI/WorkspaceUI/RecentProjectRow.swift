import SwiftUI
import UIContracts

struct RecentProjectRow: View {
    let project: UIContracts.RecentProject
    let action: () -> Void
    @State private var isHovered = false
    
    private var url: URL {
        URL(fileURLWithPath: project.representation.rootPath)
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.s12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: DS.s20)
                
                VStack(alignment: .leading, spacing: DS.s4) {
                    Text(project.representation.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(url.deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, DS.s16)
            .padding(.vertical, DS.s12)
            .background(.thinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: DS.r12)
                    .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}
