// @EntelechiaHeaderStart
// Signifier: ContextErrorBindingCoordinator
// Substance: Context error binding coordinator
// Genus: Composition coordinator
// Differentia: Manages binding between domain publisher and UI view model
// Form: Subscription lifecycle management
// Matter: Publisher; subscriber; subscription
// Powers: Bind domain errors to UI presentation
// FinalCause: Connect domain errors to UI without coupling
// Relations: Serves ChatUIHost; depends on WorkspaceViewModel and ContextPresentationViewModel
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import Combine
import UIConnections
import ChatUI

@MainActor
final class ContextErrorBindingCoordinator: ObservableObject {
    private var cancellable: AnyCancellable?
    
    func bind(
        publisher: AnyPublisher<Error, Never>,
        to presentationViewModel: ContextPresentationViewModel
    ) {
        cancellable = publisher
            .receive(on: DispatchQueue.main)
            .map { $0.localizedDescription }
            .sink { [weak presentationViewModel] message in
                presentationViewModel?.bannerMessage = message
            }
    }
    
    func unbind() {
        cancellable?.cancel()
        cancellable = nil
    }
}
