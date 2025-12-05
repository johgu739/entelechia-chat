// @EntelechiaHeaderStart
// Substance: Model response envelope
// Genus: Conversation output model
// Differentia: Captures model reply fields
// Form: Output payload schema
// Matter: Model output data
// Powers: Convey model-generated results
// FinalCause: Capture assistant outputs
// Relations: Used by ConversationService/UI
// CausalityType: Material
// @EntelechiaHeaderEnd

import Foundation

struct ModelResponse {
    let content: String
    let error: Error?
    
    init(content: String, error: Error? = nil) {
        self.content = content
        self.error = error
    }
    
    var isSuccess: Bool {
        error == nil
    }
}
