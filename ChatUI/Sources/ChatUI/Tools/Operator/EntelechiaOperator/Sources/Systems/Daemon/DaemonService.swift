// @EntelechiaHeaderStart
// Signifier: DaemonService
// Substance: Operator daemon service
// Genus: Backend connector
// Differentia: Manages connection to daemon
// Form: Connection management and IPC rules
// Matter: Process handles; IPC messages
// Powers: Start/stop daemon; forward commands; stream output
// FinalCause: Provide backend capabilities to operator UI
// Relations: Serves operator app; depends on system processes
// CausalityType: Instrumental
// @EntelechiaHeaderEnd

import Foundation

struct DaemonStatus: Identifiable {
    let id: UUID
    let name: String
    let state: State

    enum State {
        case running
        case stopped
        case error
    }
}

protocol DaemonServicing {
    func fetchStatuses() async throws -> [DaemonStatus]
    func start(identifier: UUID) async throws
    func stop(identifier: UUID) async throws
}

final class StubDaemonService: DaemonServicing {
    func fetchStatuses() async throws -> [DaemonStatus] {
        [DaemonStatus(id: UUID(), name: "Repo Server", state: .running)]
    }

    func start(identifier: UUID) async throws {}
    func stop(identifier: UUID) async throws {}
}