import Foundation

/// Trims and normalizes user prompts before Codex submission.
struct CodexPromptShaper: Sendable {
    init() {}
    func shape(_ userText: String) -> String {
        userText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

