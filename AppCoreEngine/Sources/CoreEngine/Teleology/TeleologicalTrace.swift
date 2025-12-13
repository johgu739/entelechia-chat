import Foundation

/// Side-effect-free teleological trace for causal flow observation.
/// Power: Descriptive (records, does not decide or execute)
/// Records component entry with power type, correlation ID, and timestamp.
public struct TeleologicalTrace: Sendable, Equatable {
    public let component: String
    public let power: PowerType
    public let correlationID: UUID
    public let timestamp: Date
    
    public enum PowerType: String, Sendable, Equatable {
        case descriptive = "Descriptive"
        case decisional = "Decisional"
        case effectual = "Effectual"
    }
    
    public init(component: String, power: PowerType, correlationID: UUID, timestamp: Date = Date()) {
        self.component = component
        self.power = power
        self.correlationID = correlationID
        self.timestamp = timestamp
    }
}

/// Tracer for teleological traces.
/// Power: Descriptive (stores traces, no I/O, no side effects)
/// Thread-safe, side-effect-free in-memory storage only.
public final class TeleologicalTracer: @unchecked Sendable {
    public static let shared = TeleologicalTracer()
    
    private let lock = NSLock()
    private var traces: [TeleologicalTrace] = []
    
    private init() {}
    
    /// Record a trace point.
    /// Side-effect free: stores in memory only, no I/O, no UI dependencies.
    public func trace(_ component: String, power: TeleologicalTrace.PowerType, correlationID: UUID = UUID()) {
        lock.lock()
        defer { lock.unlock() }
        traces.append(TeleologicalTrace(component: component, power: power, correlationID: correlationID))
    }
    
    /// Retrieve all traces (for observation/debugging only).
    /// Does not modify state.
    public func allTraces() -> [TeleologicalTrace] {
        lock.lock()
        defer { lock.unlock() }
        return traces
    }
    
    /// Clear all traces (for testing/reset only).
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        traces.removeAll()
    }
}


