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
    
    /// Bind context error publisher to banner message handler.
    public func bindContextErrors(
        publisher: AnyPublisher<Error, Never>,
        onBannerMessage: @escaping (String) -> Void
    ) {
        publisher
            .receive(on: DispatchQueue.main)
            .map { error -> String in
                if let localized = error as? LocalizedError {
                    return localized.errorDescription ?? localized.localizedDescription
                }
                return error.localizedDescription
            }
            .sink { message in
                onBannerMessage(message)
            }
            .store(in: &cancellables)
    }
}

