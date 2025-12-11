// @EntelechiaHeaderStart
// Signifier: ContextPresentationViewModel
// Substance: Context error presentation UI faculty
// Genus: Application faculty
// Differentia: Presents context errors to UI
// Form: Error presentation rules
// Matter: Error messages; banner state
// Powers: Display context error banners
// FinalCause: Inform user of context errors
// Relations: Serves ContextInspector; depends on error publishers
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import Combine

@MainActor
public final class ContextPresentationViewModel: ObservableObject {
    @Published public var bannerMessage: String?
    
    public init() {}
    
    public func clearBanner() {
        bannerMessage = nil
    }
}
