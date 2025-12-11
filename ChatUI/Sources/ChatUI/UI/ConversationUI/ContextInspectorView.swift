import SwiftUI
import UIConnections

struct ContextInspectorView: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    var snapshot: ContextSnapshot? {
        workspaceViewModel.lastContextSnapshot
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.s12) {
                if let snapshot {
                    InspectorSection(title: "Scope") {
                        Text(snapshot.scope.displayName)
                            .font(.system(size: 13, weight: .semibold))
                        if let hash = snapshot.snapshotHash {
                            Text("Snapshot \(hash)")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    InspectorSection(title: "Segments (\(snapshot.segments.count))") {
                        ContextInspectorSegmentList(segments: snapshot.segments)
                    }
                    
                    InspectorSection(title: "Included Files (\(snapshot.includedFiles.count))") {
                        ForEach(snapshot.includedFiles) { file in
                            ContextInspectorFileRow(file: file)
                        }
                    }
                    
                    if !snapshot.truncatedFiles.isEmpty {
                        InspectorSection(title: "Truncated (\(snapshot.truncatedFiles.count))") {
                            ForEach(snapshot.truncatedFiles) { file in
                                ContextInspectorFileRow(file: file, truncated: true)
                            }
                        }
                    }
                    
                    if !snapshot.excludedFiles.isEmpty {
                        InspectorSection(title: "Excluded (\(snapshot.excludedFiles.count))") {
                            ForEach(snapshot.excludedFiles) { file in
                                ContextInspectorFileRow(file: file, excluded: true)
                            }
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: DS.s8) {
                        Text("No context built yet.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text("Ask Codex or send a message to build context.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(DS.s12)
        }
    }
}
