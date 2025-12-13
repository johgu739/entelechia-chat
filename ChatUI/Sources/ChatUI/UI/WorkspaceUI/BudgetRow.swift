import SwiftUI

struct BudgetRow: View {
    let label: String
    let value: Int
    let limit: Int
    let formattedValue: String
    let formattedLimit: String
    
    private var progressColor: Color {
        guard limit > 0 else { return .accentColor }
        let ratio = Double(value) / Double(limit)
        if ratio >= 1 {
            return AppTheme.errorColor
        } else if ratio >= 0.85 {
            return AppTheme.warningColor
        } else {
            return .accentColor
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.s4) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(formattedValue) / \(formattedLimit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(progressColor)
            }
            ProgressView(value: Double(min(value, limit)), total: Double(limit))
                .tint(progressColor)
        }
    }
}

