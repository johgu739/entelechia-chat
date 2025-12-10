## Concurrency Model

- CoreEngine
  - Engines are actors (ConversationEngineLive) or Sendable classes with actor-owned state (WorkspaceEngineImpl + UpdateStreamBox + WorkspaceStateActor).
  - Mutable state is actor-confined; async APIs may be called from any executor.
  - Callbacks to UI (stream deltas) are dispatched via MainActor wrapper where needed.
- AppAdapters
  - OS-bound adapters are synchronous services; Sendability is explicit (`@unchecked Sendable`) only when internal locks/queues serialize access (see Adapter Concurrency Charter).
  - FileSystemWatcherAdapter confines FSEvent handling to a dedicated Dispatch queue; AsyncStream continuation only touched on that queue.
  - FileContentLoaderAdapter and HTTPClient are actors; safe to send across executors.
- UIConnections
  - Pure mappers; no mutable state; Sendable structs.
- ChatUI
  - ViewModels (`WorkspaceViewModel`, `ProjectCoordinator`, `ProjectSession`) are `@MainActor`; all state mutations happen on the main executor.
  - Continuations/callbacks into UI are main-actor only.

Rules:
- Engines are the concurrency boundary between UI and adapters.
- Adapters must not assume main-thread; they serialize internally if Sendable.
- Continuations are owned by dedicated actors/queues to ensure single-executor access.
- Violations are tested via watcher/stream shutdown tests and mapping/order tests.


