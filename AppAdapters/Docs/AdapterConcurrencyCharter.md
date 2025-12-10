# Adapter Concurrency Charter

This charter states which AppAdapters types are Sendable across threads/actors and under what invariants.

## Principles
- Adapters touching OS handles (FileManager, DispatchQueue, NSLock, URLSession, FSEvents) are not statically Sendable; they are marked `@unchecked Sendable` only when internal synchronization confines mutation.
- Where Sendable is unnecessary, types avoid conformance.
- Async actors are preferred when mutable state is present and unsynchronized.

## Adapters

- `CodexAPIClientAdapter.HTTPClient` (actor): actor-isolated; safe to send.
- `CodexAPIClientAdapter`: struct; delegates to actor; Sendable by composition.
- `CodexClientAdapter`: struct; stateless; Sendable.
- `FileSystemAccessAdapter`: `@unchecked Sendable`; guarded by `OSAllocatedUnfairLock`; FileManager calls are thread-safe for these uses.
- `FileSystemWatcherAdapter`: `@unchecked Sendable`; FSEvent callbacks confined to a dedicated Dispatch queue; AsyncStream continuation touched only on that queue.
- `FileContentLoaderAdapter` (actor): actor-isolated; safe to send.
- `FileStoreConversationPersistence`: `@unchecked Sendable`; serialized on private DispatchQueue; no nested sync.
- `FileStore` (internal): `@unchecked Sendable`; used only on persistence queue.
- `ProjectStoreRealAdapter`: `@unchecked Sendable`; guarded by `OSAllocatedUnfairLock`.
- `ProjectStoreShim`: `@unchecked Sendable`; internal to adapter; lock-guarded.
- `PreferencesStoreAdapter` / `ContextPreferencesStoreAdapter` and shims: `@unchecked Sendable`; locking ensures serialized access.
- `InMemory*` drivers: `@unchecked Sendable`; locking ensures serialized access.
- `SecurityScopeService`: `@unchecked Sendable`; NSLock protects state; bookmark APIs are synchronous.
- `KeychainServiceAdapter`: struct; stateless; Sendable.
- `FileSystemWatcherAdapter.ContinuationBox` (internal): queue-confined; not exported.

## Tests
- FileStoreConversationPersistence round-trip and delete.
- ProjectStoreRealAdapter metadata round-trip.
- FileContentLoaderAdapter size/type guards.
- FileSystemWatcherAdapter coalescing/cancel semantics.
- KeychainServiceAdapter save/load/delete.
- SecurityScopeService Noop lifecycle smoke test.


