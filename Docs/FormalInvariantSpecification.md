## Formal Invariant Specification (Phase 2)

This document lists invariants by component, categorized as preconditions, postconditions, state invariants, ordering/causality, cancellation, error, data-shape/DTO, lifetime/teardown, sendability/executor, and boundary placement. Each invariant is test-backed unless marked implicit. Dependencies denote causality/refinement relationships.

### CoreEngine
- ConversationEngineLive
  - Preconditions: non-empty message text; preferredDescriptorIDs require snapshot and descriptorPaths present.
  - Ordering: deltas emit `.context` then streaming tokens then `.assistantCommitted`; persistence after streaming completes.
  - State: cache/pathIndex/descriptorIndex mutated only on actor; eviction keeps most-recently-updated.
  - Error: invalid descriptor -> EngineError.invalidDescriptor; missing snapshot -> contextRequired; empty message -> emptyMessage; streaming failure -> streamingTransport; persistence failure leaves cache unchanged.
  - Cancellation: cancel before commit yields no assistant persisted/cached.
  - Sendability: actor-isolated; callbacks hop via MainActor wrapper.
  - Tests: ConversationEngineLiveTests ordering, errors, cancellation, persistence.
  - Depends on: ContextBuilder/Resolver budget invariants; persistence adapters.
- WorkspaceEngineImpl
  - Preconditions: openWorkspace requires non-empty root; select requires path in pathIndex.
  - Ordering: open emits initial update; watcher emits on file changes; watcher end -> watcherUnavailable.
  - State: WorkspaceStateActor owns snapshot/indices/watcherTask; UpdateStreamBox owns continuation single-executor.
  - Error: invalidSelection; workspaceNotOpened; context prefs persistence failures surface.
  - Cancellation: refresh/select/setContextInclusion honor Task cancellation.
  - Sendability: class Sendable with all mutable state in actors.
  - Tests: WorkspaceEngineImplTests (selection, refresh, context inclusion, watcher stream serial/shutdown), WorkspaceEngineUpdatesTests.
- WorkspaceContextPreparer / ContextBuilder
  - Preconditions: preferredDescriptorIDs must resolve to paths; fileLoader must load.
  - State/Data: budget limits enforced; truncation recorded; exclusions recorded.
  - Error: missing descriptor path or load failure -> contextLoadFailed.
  - Tests: WorkspaceContextPreparerTests, ContextBudgetTests.
- ProjectEngineImpl
  - Preconditions: non-empty name.
  - Postconditions: save/load round-trip.
  - Tests: ProjectEngineImplTests.

### AppAdapters
- FileSystemAccessAdapter
  - Invariant: path↔ID mapping stable across listings.
  - Concurrency: lock-guarded maps; @unchecked Sendable.
  - Tests: FileSystemAccessAdapterTests.
- FileSystemWatcherAdapter
  - Invariant: emits initial tick; coalesces bursts into single tick; finishes on root missing/termination; no events after finish.
  - Concurrency: dispatch-queue confined continuation; @unchecked Sendable.
  - Tests: FileSystemWatcherAdapterTests (coalescing/cancel).
- FileContentLoaderAdapter (actor)
  - Preconditions: readable text/source within size limit.
  - Error: tooLarge/unsupported/unreadable.
  - Tests: FileContentLoaderAdapterTests.
- FileStoreConversationPersistence
  - Invariant: operations serialized on queue; no nested sync; index consistent with stored files.
  - Tests: FileStoreConversationPersistenceTests.
- ProjectStoreRealAdapter
  - Invariant: metadata round-trip preserved.
  - Tests: ProjectStoreRealAdapterTests.
- Preferences/ContextPreferences shims & InMemory drivers
  - Invariant: lock-guarded; JSON round-trip.
  - Tests: covered indirectly; implicit.
- SecurityScopeService
  - Invariant: bookmark resolve/start/stop paired; errors propagate.
  - Tests: SecurityScopeServiceTests (Noop).
- KeychainServiceAdapter
  - Invariant: save/load/delete round-trip.
  - Tests: KeychainServiceAdapterTests.
- Adapter Concurrency Charter documents sendability rationale for all above.

### UIConnections
- ConversationViewStateMapper
  - Ordering: `.context` updates lastContext; `.assistantStreaming` updates streamingText aggregate; `.assistantCommitted` appends and clears streamingText.
  - Data-shape: fields id/messages/streamingText/lastContext preserved.
  - Tests: MappingTests, ConversationMapperCompletenessTests.
- WorkspaceViewStateMapper
  - Data-shape: rootPath/selectedPath/selectedDescriptorID/contextInclusions/projection mapped; watcherError mapped to string when provided.
  - Tests: MappingTests, WorkspaceMapperCompletenessTests.

### ChatUI
- WorkspaceViewModel
  - Invariant: updates stream applied on MainActor; selection/context inclusion reflected in snapshot/view state.
  - Tests: WorkspaceViewModelIntegrationTests.
- ProjectCoordinator & ProjectSession
  - Invariant: bookmark start/stop paired; opening recent establishes session; invalid bookmark propagates error.
  - Tests: ProjectCoordinatorSessionTests.
- CodexConfigLoader
  - Invariant: precedence ENV > Keychain > Plist; missing credentials -> missingAPIKey.
  - Tests: CodexConfigLoaderTests (Xcode).

### Dependency Graph (invariants)
- CE ConversationEngineLive -> ContextBuilder/Resolver, persistence adapters, UIConnections ConversationViewStateMapper.
- CE WorkspaceEngineImpl -> FileSystemAccessAdapter, FileSystemWatcherAdapter, Preferences/ContextPrefs drivers, UIConnections WorkspaceViewStateMapper, ChatUI WorkspaceViewModel.
- ContextPreparer -> FileContentLoaderAdapter.
- ProjectEngineImpl -> ProjectStoreRealAdapter.
- UI mappers -> CoreEngine deltas/snapshots.
- WorkspaceViewModel -> CE WorkspaceEngineImpl + UIConnections mapper.
- ProjectCoordinator/Session -> SecurityScopeService/Keychain.
- CodexConfigLoader -> KeychainServiceAdapter/env/plist.

### Enforcement Status
- Enforced in code + tests: ConversationEngineLive, WorkspaceEngineImpl, ContextPreparer/Builder, ProjectEngineImpl, FileSystemWatcherAdapter, FileContentLoaderAdapter, FileStoreConversationPersistence, ProjectStoreRealAdapter, KeychainServiceAdapter, UI mappers, WorkspaceViewModel (integration), FileSystemAccessAdapter mapping.
- Enforced in code, lightly tested: SecurityScopeService (Noop only), Preferences/ContextPrefs.
- Implicit: adapter lock guards for prefs; real security-scope error paths.


