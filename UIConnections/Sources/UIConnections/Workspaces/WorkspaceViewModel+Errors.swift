import Foundation
import os.log

extension WorkspaceViewModel {
    struct TimeoutError: LocalizedError {
        let seconds: Double
        var errorDescription: String? { "Operation timed out after \(seconds) seconds." }
    }
    
    func handleFileSystemError(_ error: Error, fallbackTitle: String) {
        logger.error("Workspace error: \(error.localizedDescription, privacy: .public)")
        alertCenter?.publish(error, fallbackTitle: fallbackTitle)
    }

    func withTimeout<T>(seconds: Double, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError(seconds: seconds)
            }
            guard let result = try await group.next() else {
                throw TimeoutError(seconds: seconds)
            }
            group.cancelAll()
            return result
        }
    }
}

