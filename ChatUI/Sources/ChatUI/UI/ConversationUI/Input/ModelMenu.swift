import SwiftUI
import UIContracts

struct ModelMenu: View {
    let selection: Binding<UIContracts.ModelChoice>
    
    var body: some View {
        Menu {
            Picker("Model", selection: selection) {
                ForEach(UIContracts.ModelChoice.allCases, id: \.self) { choice in
                    Text(choice.displayName).tag(choice)
                }
            }
        } label: {
            Image(systemName: "app.badge")
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Model selection")
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
    }
}

