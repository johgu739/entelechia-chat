import Foundation
import SwiftUI
import Combine

/// Observable status holder for Codex availability.
public final class CodexStatusModel: ObservableObject {
    public enum State {
        case connected
        case degradedStub
        case misconfigured(String)

        init(from availability: CodexAvailability) {
            switch availability {
            case .connected:
                self = .connected
            case .degradedStub:
                self = .degradedStub
            case .misconfigured(let error):
                self = .misconfigured(error.localizedDescription)
            }
        }

        public var message: String {
            switch self {
            case .connected:
                return "Codex connected"
            case .degradedStub:
                return "Codex stub mode (offline)"
            case .misconfigured(let reason):
                return "Codex unavailable: \(reason)"
            }
        }

        public var accentColor: Color {
            switch self {
            case .connected:
                return .green
            case .degradedStub:
                return .orange
            case .misconfigured:
                return .red
            }
        }

        public var icon: String {
            switch self {
            case .connected:
                return "checkmark.seal.fill"
            case .degradedStub:
                return "antenna.radiowaves.left.and.right"
            case .misconfigured:
                return "exclamationmark.triangle.fill"
            }
        }
    }

    @Published public private(set) var state: State

    public init(availability: CodexAvailability) {
        self.state = State(from: availability)
    }
}


