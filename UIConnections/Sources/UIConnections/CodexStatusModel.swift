import Foundation

/// Observable status holder for Codex availability (UI-facing).
public final class CodexStatusModel: ObservableObject {
    public enum State: Equatable {
        case connected
        case degradedStub
        case misconfigured(String)
    }
    
    public enum Tone {
        case success
        case warning
        case error
    }
    
    @Published public private(set) var state: State
    
    public init(availability: State) {
        self.state = availability
    }
    
    public var message: String {
        switch state {
        case .connected:
            return "Codex connected"
        case .degradedStub:
            return "Codex stub mode (offline)"
        case .misconfigured(let reason):
            return "Codex unavailable: \(reason)"
        }
    }
    
    public var tone: Tone {
        switch state {
        case .connected:
            return .success
        case .degradedStub:
            return .warning
        case .misconfigured:
            return .error
        }
    }
    
    public var icon: String {
        switch state {
        case .connected:
            return "checkmark.seal.fill"
        case .degradedStub:
            return "antenna.radiowaves.left.and.right"
        case .misconfigured:
            return "exclamationmark.triangle.fill"
        }
    }
}

