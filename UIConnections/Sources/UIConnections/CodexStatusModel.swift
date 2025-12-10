import Foundation
import SwiftUI

/// Observable status holder for Codex availability (UI-facing).
public final class CodexStatusModel: ObservableObject {
    public enum State: Equatable {
        case connected
        case degradedStub
        case misconfigured(String)
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
    
    public var accentColor: Color {
        switch state {
        case .connected:
            return .green
        case .degradedStub:
            return .orange
        case .misconfigured:
            return .red
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

