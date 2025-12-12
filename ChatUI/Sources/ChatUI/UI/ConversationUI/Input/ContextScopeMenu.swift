import SwiftUI
import UIContracts

struct ContextScopeMenu: View {
    let selection: Binding<UIContracts.ContextScopeChoice>
    
    var body: some View {
        Menu {
            Picker("Context Scope", selection: selection) {
                ForEach(UIContracts.ContextScopeChoice.allCases, id: \.self) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
        } label: {
            Image(systemName: "globe")
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Context scope")
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
}

