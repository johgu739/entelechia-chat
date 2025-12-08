import Foundation
import CoreServices
import CoreEngine

/// FSEvents-based recursive watcher emitting coalesced change signals for a root path.
///
/// Concurrency: event callbacks are confined to a single Dispatch queue; AsyncStream continuation is only
/// touched on that queue and on termination. Marked `@unchecked Sendable` due to FSEvents pointers and
/// continuation not being statically Sendable.
///
/// Debounce/ordering:
/// - Incoming FSEvents are coalesced via a 150ms timer; multiple events in that window yield a single
///   `Void` tick to the stream.
/// - The stream emits one initial tick on successful start, then one tick per coalesced burst, then finishes
///   if the root is missing or the stream is terminated.
public final class FileSystemWatcherAdapter: FileSystemWatching, @unchecked Sendable {
    public init() {}

    public nonisolated func watch(rootPath: String) -> AsyncStream<Void> {
        // If root does not exist, finish immediately to avoid dangling streams.
        guard FileManager.default.fileExists(atPath: rootPath) else {
            return AsyncStream { $0.finish() }
        }

        return AsyncStream { continuation in
            let queue = DispatchQueue(label: "chat.entelechia.fs.watcher")
            let paths = [rootPath] as CFArray
            var stream: FSEventStreamRef?

            // Coalesce bursts of events into a single yield per tick.
            var pending = false
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + .milliseconds(150), repeating: .milliseconds(150))
            timer.setEventHandler {
                if pending {
                    pending = false
                    continuation.yield()
                }
            }
            timer.resume()

            let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
                guard let info else { return }
                guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }
                let box = Unmanaged<ContinuationBox>.fromOpaque(info).takeUnretainedValue()
                box.handleEvent(paths: paths)
            }

            let box = ContinuationBox {
                pending = true
            }
            var context = FSEventStreamContext(
                version: 0,
                info: Unmanaged.passUnretained(box).toOpaque(),
                retain: nil,
                release: nil,
                copyDescription: nil
            )

            stream = FSEventStreamCreate(
                kCFAllocatorDefault,
                callback,
                &context,
                paths,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                0.1, // latency seconds
                FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagIgnoreSelf)
            )

            let streamBits: UInt = stream.map { UInt(bitPattern: $0) } ?? 0

            if let stream {
                FSEventStreamSetDispatchQueue(stream, queue)
                FSEventStreamStart(stream)
                continuation.yield()
            } else {
                continuation.finish()
            }

            continuation.onTermination = { _ in
                timer.cancel()
                if streamBits != 0 {
                    let ref = FSEventStreamRef(bitPattern: streamBits)!
                    FSEventStreamStop(ref)
                    FSEventStreamInvalidate(ref)
                    FSEventStreamRelease(ref)
                }
            }
        }
    }
}

private final class ContinuationBox {
    private let onEvent: () -> Void
    private let allowedExtensions: Set<String> = ["swift", "md", "txt", "json", "yml", "yaml", "ent"]
    init(onEvent: @escaping () -> Void) {
        self.onEvent = onEvent
    }
    func handleEvent(paths: [String]) {
        // Filter to relevant paths: ignore hidden and system clutter.
        let relevant = paths.contains { path in
            let name = (path as NSString).lastPathComponent
            if name.hasPrefix(".") { return false }
            if name == ".DS_Store" { return false }
            if name.isEmpty { return false }
            let ext = (path as NSString).pathExtension.lowercased()
            if ext.isEmpty { return true }
            return allowedExtensions.contains(ext)
        }
        if relevant { onEvent() }
    }
}

