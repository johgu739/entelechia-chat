// @EntelechiaHeaderStart
// Signifier: OntologyTodosView
// Substance: Ontology TODOs navigator view
// Genus: UI list view
// Differentia: Shows ontology gaps and errors per project
// Form: SwiftUI list with error/empty/content states
// Matter: ProjectTodos data and errors
// Powers: Render todos; display badges; surface load failures
// FinalCause: Make ontology work visible within the navigator
// Relations: Serves workspace navigator; depends on WorkspaceViewModel
// CausalityType: Accidental
// @EntelechiaHeaderEnd

import SwiftUI
import AppCoreEngine

struct OntologyTodosView: View {
    @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }
    
    private var header: some View {
        HStack {
            Text("Ontology TODOs")
                .font(.system(size: 12, weight: .semibold))
            Spacer()
            if let generatedAt = workspaceViewModel.projectTodos.generatedAt, !generatedAt.isEmpty {
                Text(generatedAt)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if let error = workspaceViewModel.todosError {
            stateCard(systemImage: "exclamationmark.triangle", title: "Failed to load", detail: error)
        } else if workspaceViewModel.projectTodos.totalCount == 0 {
            stateCard(systemImage: "checkmark.circle", title: "All clear", detail: "No ontology todos found.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(workspaceViewModel.projectTodos.flatTodos, id: \.self) { item in
                        todoRow(text: item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    private func todoRow(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "smallcircle.filled.circle")
                .font(.system(size: 8))
                .foregroundColor(.accentColor)
                .padding(.top, 3)
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
        )
    }
    
    private func stateCard(systemImage: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
        )
    }
}
