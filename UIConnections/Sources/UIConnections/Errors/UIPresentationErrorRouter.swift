import Foundation
import Combine
import AppCoreEngine

/// UI router for error presentation.
/// Power: Decisional (routes classified errors to alerts/banners)
/// Maps domain error classification to UI presentation.
@MainActor
public final class UIPresentationErrorRouter: ObservableObject {
    private let alertCenter: AlertCenter
    private let contextErrorSubject = PassthroughSubject<String, Never>()
    private var cancellable: AnyCancellable?
    
    public var contextErrorPublisher: AnyPublisher<String, Never> {
        contextErrorSubject.eraseToAnyPublisher()
    }
    
    public init(alertCenter: AlertCenter, domainErrorAuthority: DomainErrorAuthority) {
        self.alertCenter = alertCenter
        
        // Subscribe to domain error authority and route based on intent
        cancellable = domainErrorAuthority.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] classified in
                self?.route(classified)
            }
    }
    
    private func route(_ classified: ClassifiedError) {
        switch classified.intent {
        case .userAction, .systemAlert:
            let userError = UserFacingError(
                title: classified.title,
                message: classified.message,
                recoverySuggestion: classified.recoverySuggestion
            )
            alertCenter.publish(userError)
            
        case .contextNotification:
            contextErrorSubject.send(classified.message)
            
        case .silentLog:
            // Log only, no UI presentation
            break
        }
    }
}

