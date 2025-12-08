## Purity Charter

Allowed impurities and their layers:
- OS filesystem (FileManager): AppAdapters only (FileSystemAccessAdapter, FileStoreConversationPersistence, ProjectStoreRealAdapter, Preferences stores). Concurrency enforced via locks/queues.
- Security-scoped bookmarks: AppAdapters SecurityScopeService; consumed by ChatUI ProjectCoordinator/Session via injected handler. Concurrency via NSLock inside service; UI accesses on MainActor.
- Keychain: AppAdapters KeychainServiceAdapter and ChatUI KeychainService; synchronous Security APIs; usage in adapters/UI only.
- URLSession (SSE streaming): AppAdapters CodexAPIClientAdapter; network performed in actor HTTPClient; stream delivered over AsyncSequence.
- FSEvents: AppAdapters FileSystemWatcherAdapter; confined to dedicated Dispatch queue.

Prohibitions:
- CoreEngine remains pure (no direct OS/UI).
- UIConnections remains pure mapping.
- Impurities must not cross into CoreEngine; accessed via injected adapters only.

Concurrency boundaries for impurities:
- File IO: serialized via queues/locks; not main-thread bound.
- Security/bookmarks: synchronous; main-thread usage coordinated by UI, state protected by locks in adapter.
- URLSession: actor encapsulation; callbacks not main-thread by default.
- FSEvents: queue-confined; AsyncStream continuation touched only on watcher queue.

