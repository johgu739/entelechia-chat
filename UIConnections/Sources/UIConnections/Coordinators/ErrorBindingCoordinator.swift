import Foundation
import Combine

/// Coordinator for binding domain error publishers to UI presentation (moved from AppComposition).
@MainActor
public final class ErrorBindingCoordinator: ObservableObject {
    var cancellables: Set<AnyCancellable> = []
    
    public init() {}
    
    /// Bind domain error publisher to alert center.
    public func bindDomainErrors(
        publisher: AnyPublisher<Error, Never>,
        to alertCenter: AlertCenter
    ) {
        publisher
            .sink { error in
                alertCenter.publish(error, fallbackTitle: "Workspace Error")
            }
            .store(in: &cancellables)
    }
    
    /// Bind context error publisher to presentation view model.
    public func bindContextErrors(
        publisher: AnyPublisher<Error, Never>,
        to presentationViewModel: ContextPresentationViewModel
    ) {
        publisher
            .receive(on: DispatchQueue.main)
            .map { error -> String in
                if let localized = error as? LocalizedError {
                    return localized.errorDescription ?? localized.localizedDescription
                }
                return error.localizedDescription
            }
            .sink { [weak presentationViewModel] message in
                presentationViewModel?.bannerMessage = message
            }
            .store(in: &cancellables)
    }
}

