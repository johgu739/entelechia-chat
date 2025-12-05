// @EntelechiaHeaderStart
// Substance: Operator inspector panel
// Genus: UI inspector
// Differentia: Displays details for selection
// Form: Detail display and controls
// Matter: Selection data; editable fields
// Powers: Show and edit metadata for selection
// FinalCause: Inform and adjust selected operator target
// Relations: Serves operator workspace; depends on selection state
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI

struct InspectorPanel: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Inspector")
                    .font(.headline)

                Form {
                    Section("Selection") {
                        Text(selectionDescription)
                    }

                    Section("Metadata") {
                        if metadata.isEmpty {
                            Text("No metadata available")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(metadata, id: \.0) { key, value in
                                HStack {
                                    Text(key).foregroundColor(.secondary)
                                    Spacer()
                                    Text(value)
                                }
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var selectionDescription: String {
        switch appState.selection {
        case .file(let url):
            return url.lastPathComponent
        case .codexSession:
            return "Codex Session"
        case .daemon:
            return "Daemon"
        case .logStream(let name):
            return "Log: \(name)"
        case .patch:
            return "Patch"
        case .none:
            return "No selection"
        }
    }

    private var metadata: [(String, String)] {
        switch appState.selection {
        case .file(let url):
            return [
                ("Path", url.path),
                ("Type", url.pathExtension.isEmpty ? "Folder" : url.pathExtension.uppercased())
            ]
        default:
            return []
        }
    }
}