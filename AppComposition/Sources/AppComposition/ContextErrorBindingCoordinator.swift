// @EntelechiaHeaderStart
// Signifier: ContextErrorBindingCoordinator
// Substance: Context error binding coordinator
// Genus: Composition coordinator
// Differentia: Manages binding between domain publisher and banner message
// Form: Subscription lifecycle management
// Matter: Publisher; subscriber; subscription
// Powers: Bind domain errors to banner message
// FinalCause: Connect domain errors to UI without coupling
// Relations: Serves ChatUIHost; no ViewModel dependencies
// CausalityType: Formal
// @EntelechiaHeaderEnd

import Foundation
import Combine
import UIConnections

@MainActor
final class ContextErrorBindingCoordinator: ObservableObject {
    private var cancellable: AnyCancellable?
    @Published var bannerMessage: String? = nil
    
    var bannerMessagePublisher: AnyPublisher<String?, Never> {
        $bannerMessage.eraseToAnyPublisher()
    }
    
    func bind(
        publisher: AnyPublisher<Error, Never>,
        to bannerUpdater: @escaping (String?) -> Void
    ) {
        cancellable = publisher
            .receive(on: DispatchQueue.main)
            .map { error -> String? in
                if let localized = error as? LocalizedError {
                    return localized.errorDescription ?? localized.localizedDescription
                }
                return error.localizedDescription
            }
            .sink { [weak self] message in
                self?.bannerMessage = message
                bannerUpdater(message)
            }
    }
    
    func bindStringPublisher(
        publisher: AnyPublisher<String, Never>,
        to bannerUpdater: @escaping (String?) -> Void
    ) {
        cancellable = publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.bannerMessage = message
                bannerUpdater(message)
            }
    }
    
    func unbind() {
        cancellable?.cancel()
        cancellable = nil
        bannerMessage = nil
    }
}
