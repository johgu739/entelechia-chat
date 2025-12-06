// @EntelechiaHeaderStart
// Signifier: TokenEstimator
// Substance: Token estimation helper
// Genus: Intelligence utility
// Differentia: Approximates token usage from text or byte counts
// Form: Pure functions over counts
// Matter: Character counts; byte counts
// Powers: Provide conservative token estimates for budgeting
// FinalCause: Guard Codex calls from exceeding context limits
// Relations: Serves context builders, inspectors, and UI affordances
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation

enum TokenEstimator {
    private static let charactersPerToken = 4.0

    static func estimateTokens(for content: String) -> Int {
        estimateTokens(forByteCount: content.utf8.count)
    }

    static func estimateTokens(forByteCount bytes: Int) -> Int {
        guard bytes > 0 else { return 0 }
        let estimate = Int(ceil(Double(bytes) / charactersPerToken))
        return max(1, estimate)
    }
}
