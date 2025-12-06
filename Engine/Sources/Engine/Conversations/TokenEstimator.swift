import Foundation

public enum TokenEstimator {
    private static let charactersPerToken = 4.0

    public static func estimateTokens(for content: String) -> Int {
        estimateTokens(forByteCount: content.utf8.count)
    }

    public static func estimateTokens(forByteCount bytes: Int) -> Int {
        guard bytes > 0 else { return 0 }
        let estimate = Int(ceil(Double(bytes) / charactersPerToken))
        return max(1, estimate)
    }
}

