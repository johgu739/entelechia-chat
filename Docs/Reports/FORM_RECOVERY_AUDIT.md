# ENTELECHIA — FORM RECOVERY AUDIT (BEING → OUGHT)

**Date**: 2025-12-11  
**Method**: Aristotelian descriptive audit  
**Scope**: All modules except Ontology layers (as instructed)

---

## PHASE A — INVENTORY OF WHAT EXISTS (NO IDEALS)

### Modules / Packages

1. **EntelechiaChat** (App Target)
   - Location: `EntelechiaChat/EntelechiaChatApp.swift`
   - What it does: SwiftUI app entry point
   - What it mutates: Nothing (pure entry)
   - What it depends on: `AppComposition`

2. **AppComposition**
   - Location: `AppComposition/Sources/AppComposition/`
   - What it does: Composition root; wires dependencies; creates long-lived objects
   - What it mutates: Creates and initializes ViewModels, Coordinators, Engines
   - What it depends on: `AppCoreEngine`, `AppAdapters`, `UIConnections`, `ChatUI`, `OntologyIntegration`, `OntologyDomain` (latter two ignored per instructions)

3. **ChatUI**
   - Location: `ChatUI/Sources/ChatUI/`
   - What it does: SwiftUI views and UI components
   - What it mutates: UI state only (via @Published properties)
   - What it depends on: `UIConnections`, `SwiftUI`, `AppKit`

4. **UIConnections**
   - Location: `UIConnections/Sources/UIConnections/`
   - What it does: ViewModels, Coordinators, UI-domain bridge types
   - What it mutates: UI-observable state; orchestrates engine calls
   - What it depends on: `AppCoreEngine`

5. **AppCoreEngine**
   - Location: `AppCoreEngine/Sources/CoreEngine/`
   - What it does: Domain engines (Workspace, Project, Conversation); domain types; protocols
   - What it mutates: Domain state (workspace snapshots, conversations, projects)
   - What it depends on: `Foundation`, `Dispatch` only

6. **AppAdapters**
   - Location: `AppAdapters/Sources/AppAdapters/`
   - What it does: OS/platform adapters (filesystem, persistence, security, HTTP, file mutations)
   - What it mutates: Filesystem, keychain, HTTP requests, file contents
   - What it depends on: `AppCoreEngine`, OS frameworks

7. **UIContracts**
   - Location: `UIContracts/`
   - What it does: Empty directory (no files)
   - What it mutates: Nothing
   - What it depends on: Nothing

### Long-Lived Objects (Engines, ViewModels, Coordinators)

#### Engines (Domain)

1. **WorkspaceEngineImpl**
   - Location: `AppCoreEngine/Sources/CoreEngine/Workspace/WorkspaceEngineImpl.swift`
   - What it does: Manages workspace tree, selection, context preferences, file watching
   - What it mutates: `WorkspaceStateActor` (snapshot, descriptorIndex, pathIndex); emits `WorkspaceUpdate` stream
   - What it depends on: `FileSystemAccess`, `PreferencesDriver`, `ContextPreferencesDriver`, `FileSystemWatching`

2. **ProjectEngineImpl**
   - Location: `AppCoreEngine/Sources/CoreEngine/Projects/ProjectEngineImpl.swift`
   - What it does: Validates and persists project representations
   - What it mutates: Project persistence store
   - What it depends on: `ProjectPersistenceDriver`

3. **ConversationEngineLive**
   - Location: `AppCoreEngine/Sources/CoreEngine/Engines/ConversationEngineLive.swift`
   - What it does: Manages conversations, streams LLM responses, resolves context, persists conversations
   - What it mutates: Actor-isolated cache (conversations, pathIndex, descriptorIndex); persistence store
   - What it depends on: `CodexClient`, `ConversationPersistenceDriver`, `FileContentLoading`, `ContextBuilder`

#### ViewModels (UI-Domain Bridge)

4. **WorkspaceViewModel**
   - Location: `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift`
   - What it does: Mediates workspace domain to UI; manages selection, tree projection, conversations, streaming messages
   - What it mutates: `@Published` UI state (selectedNode, rootFileNode, isLoading, filterText, expandedDescriptorIDs, projectTodos, streamingMessages, workspaceState); publishes errors via `contextErrorSubject`
   - What it depends on: `WorkspaceEngine`, `ConversationStreaming`, `ProjectTodosLoading`, `CodexQuerying`, `AlertCenter`, `ContextSelectionState`

5. **ChatViewModel**
   - Location: `UIConnections/Sources/UIConnections/Conversation/ChatViewModel.swift`
   - What it does: Presentation model for chat UI (text input, messages, model/scope selection)
   - What it mutates: `@Published` UI state (text, model, contextScope, isSending, isAsking, messages, streamingText)
   - What it depends on: `ConversationCoordinator`, `ContextSelectionState`

6. **ProjectSession**
   - Location: `UIConnections/Sources/UIConnections/Projects/ProjectSession.swift`
   - What it does: Runtime session for active project; manages security scopes
   - What it mutates: `@Published` state (activeProjectURL, projectName); security scope access
   - What it depends on: `ProjectEngine`, `WorkspaceEngine`, `SecurityScopeHandling`, `AlertCenter`

#### Coordinators (Orchestration)

7. **ConversationCoordinator**
   - Location: `UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift`
   - What it does: Coordinates chat message sending; forwards streaming updates to ChatViewModel
   - What it mutates: Weak reference to ChatViewModel; monitors workspace streamingMessages
   - What it depends on: `ConversationWorkspaceHandling` (WorkspaceViewModel), `ContextSelectionState`, `CodexStatusModel`

8. **ProjectCoordinator**
   - Location: `UIConnections/Sources/UIConnections/Projects/ProjectCoordinator.swift`
   - What it does: Coordinates project open/close operations; manages recent projects
   - What it mutates: Project persistence via ProjectEngine; publishes alerts
   - What it depends on: `ProjectEngine`, `ProjectSessioning`, `AlertCenter`, `SecurityScopeHandling`, `ProjectMetadataHandling`

9. **ContextErrorBindingCoordinator**
   - Location: `AppComposition/Sources/AppComposition/ContextErrorBindingCoordinator.swift`
   - What it does: Binds domain error publisher to UI presentation view model
   - What it mutates: Subscription lifecycle (Combine cancellable)
   - What it depends on: `WorkspaceViewModel.contextErrorPublisher`, `ContextPresentationViewModel`

#### Services (Domain-Adapter Bridge)

10. **CodexService**
    - Location: `UIConnections/Sources/UIConnections/Codex/CodexService.swift`
    - What it does: Queries Codex/AI with workspace context; applies file mutations via diffs
    - What it mutates: Files via `CodexMutationPipeline` → `FileMutationAuthority`; streams LLM responses
    - What it depends on: `ConversationStreaming`, `WorkspaceEngine`, `AnyCodexClient`, `FileContentLoading`, `RetryPolicy`, `FileMutationAuthorizing`

11. **FileMutationAuthority**
    - Location: `AppAdapters/Sources/AppAdapters/Workspace/FileMutationAuthority.swift`
    - What it does: Authorizes and applies file diffs to filesystem
    - What it mutates: Filesystem (writes, creates directories)
    - What it depends on: `AtomicDiffApplying`, `WorkspaceRootProviding`

12. **CodexMutationPipeline**
    - Location: `UIConnections/Sources/UIConnections/Codex/CodexMutationPipeline.swift`
    - What it does: Parses unified diff text and coordinates application via FileMutationAuthority
    - What it mutates: Nothing directly (delegates to authority)
    - What it depends on: `FileMutationAuthorizing`

#### Composition Root

13. **ChatUIHost**
    - Location: `AppComposition/Sources/AppComposition/ChatUIHost.swift`
    - What it does: SwiftUI view that composes all ViewModels and Coordinators; wires dependencies
    - What it mutates: Creates and initializes all long-lived objects; binds coordinators
    - What it depends on: `DependencyContainer` (provides engines, services, adapters)

14. **AppContainer**
    - Location: `AppComposition/Sources/AppComposition/AppContainer.swift`
    - What it does: Factory that creates all adapters, engines, services
    - What it mutates: Nothing (pure factory)
    - What it depends on: `AppCoreEngine`, `AppAdapters`, `UIConnections`

### Agents (Explicit or Implicit)

**Explicit Agents:**
- None found. No explicit "agent" classes that execute autonomous actions.

**Implicit Agents:**
1. **FileSystemWatcherAdapter** (via WorkspaceEngineImpl)
   - Location: `AppAdapters/Sources/AppAdapters/FilesystemWatcherAdapter.swift`
   - What it does: Watches filesystem for changes; triggers workspace refresh
   - What it mutates: Triggers WorkspaceEngineImpl.refresh() via AsyncStream
   - What it depends on: FSEvent framework

2. **ConversationEngineLive** (via streaming callbacks)
   - Acts as implicit agent when streaming LLM responses
   - Mutates UI state indirectly via callbacks → WorkspaceViewModel → ConversationCoordinator → ChatViewModel

3. **CodexService** (via user-triggered queries)
   - Acts as implicit agent when applying file mutations from LLM responses
   - Mutates filesystem via FileMutationAuthority

### Execution Paths

1. **User chat message flow:**
   - User types in ChatViewModel → ChatViewModel.commitMessage() → ConversationCoordinator.stream() → WorkspaceViewModel.sendMessage() → ConversationEngineLive.sendMessage() → CodexClient.stream() → Callback chain: ConversationDelta → WorkspaceViewModel.streamingMessages → ConversationCoordinator polling → ChatViewModel.applyDelta()

2. **File being read:**
   - WorkspaceEngineImpl.openWorkspace() → FileSystemAccess.listChildren() → FileContentLoaderAdapter.load() (when needed) → LoadedFile

3. **File being modified:**
   - User/LLM provides diff text → CodexService.applyDiff() → CodexMutationPipeline.applyUnifiedDiff() → FileMutationAuthority.apply() → AtomicDiffApplierAdapter.apply() → FileWriteAdapter.write() → Filesystem

4. **Error occurring:**
   - Error thrown in engine/adapter → Caught in ViewModel/Coordinator → AlertCenter.publish() OR WorkspaceViewModel.contextErrorSubject.send() → ContextErrorBindingCoordinator binds to ContextPresentationViewModel → UI banner

5. **Agent "fixing" something:**
   - Not implemented. No autonomous agent execution found.

### UI Surfaces

1. **RootView** (ChatUI)
   - Routes to OnboardingSelectProjectView or MainWorkspaceView

2. **MainWorkspaceView** (ChatUI)
   - Contains navigator, editor, chat panels

3. **OnboardingSelectProjectView** (ChatUI)
   - Project selection UI

### Persistence Mechanisms

1. **ProjectStoreRealAdapter**
   - Location: `AppAdapters/Sources/AppAdapters/Persistence/ProjectStoreRealAdapter.swift`
   - What it does: Persists ProjectRepresentation to filesystem
   - What it mutates: Filesystem (project metadata files)

2. **FileStoreConversationPersistence**
   - Location: `AppAdapters/Sources/AppAdapters/Persistence/FileStoreAdapter.swift`
   - What it does: Persists Conversation to filesystem
   - What it mutates: Filesystem (conversation JSON files)

3. **PreferencesStoreAdapter**
   - Location: `AppAdapters/Sources/AppAdapters/Preferences/PreferencesStoreAdapter.swift`
   - What it does: Persists WorkspacePreferences to UserDefaults
   - What it mutates: UserDefaults

4. **ContextPreferencesStoreAdapter**
   - Location: `AppAdapters/Sources/AppAdapters/Preferences/ContextPreferencesStoreAdapter.swift`
   - What it does: Persists WorkspaceContextPreferencesState to filesystem
   - What it mutates: Filesystem (context preferences files)

---

## PHASE B — ACTUAL DEPENDENCY GRAPH (AS-IS)

### Module Dependencies (from ArchitectureRules.json and imports)

```
EntelechiaChat
  └─> AppComposition

AppComposition
  └─> AppCoreEngine
  └─> AppAdapters
  └─> UIConnections
  └─> ChatUI
  └─> OntologyIntegration (ignored)
  └─> OntologyDomain (ignored)

ChatUI
  └─> UIConnections
  └─> SwiftUI
  └─> AppKit

UIConnections
  └─> AppCoreEngine

AppAdapters
  └─> AppCoreEngine

AppCoreEngine
  └─> Foundation
  └─> Dispatch
```

### Runtime Dependency Graph (from code analysis)

```
ChatUIHost
  ├─> WorkspaceViewModel
  │     ├─> WorkspaceEngine
  │     ├─> ConversationStreaming (ConversationEngineBox)
  │     ├─> CodexQuerying (CodexService)
  │     ├─> ProjectTodosLoading
  │     ├─> AlertCenter
  │     └─> ContextSelectionState
  ├─> ConversationCoordinator
  │     ├─> WorkspaceViewModel (ConversationWorkspaceHandling)
  │     ├─> ContextSelectionState
  │     └─> CodexStatusModel
  ├─> ProjectCoordinator
  │     ├─> ProjectEngine
  │     ├─> ProjectSession
  │     ├─> AlertCenter
  │     ├─> SecurityScopeHandling
  │     └─> ProjectMetadataHandling
  ├─> ProjectSession
  │     ├─> ProjectEngine
  │     ├─> WorkspaceEngine
  │     └─> SecurityScopeHandling
  └─> ContextErrorBindingCoordinator
        ├─> WorkspaceViewModel.contextErrorPublisher
        └─> ContextPresentationViewModel

WorkspaceEngineImpl
  ├─> FileSystemAccess (adapter)
  ├─> PreferencesDriver (adapter)
  ├─> ContextPreferencesDriver (adapter)
  └─> FileSystemWatching (adapter)

ConversationEngineLive
  ├─> CodexClient (adapter)
  ├─> ConversationPersistenceDriver (adapter)
  └─> FileContentLoading (adapter)

CodexService
  ├─> ConversationStreaming
  ├─> WorkspaceEngine
  ├─> AnyCodexClient (adapter)
  ├─> FileContentLoading (adapter)
  └─> FileMutationAuthorizing (FileMutationAuthority)

FileMutationAuthority
  ├─> AtomicDiffApplying (adapter)
  └─> WorkspaceRootProviding
```

### Cycles

**No cycles detected** in the dependency graph. All dependencies flow downward:
- UI → UIConnections → AppCoreEngine ← AppAdapters

### Peer Dependencies

1. **UIConnections ↔ AppAdapters**
   - Both depend on AppCoreEngine only
   - No direct dependency between them (correct)

2. **AppComposition ↔ UIConnections**
   - AppComposition imports UIConnections (creates ViewModels/Coordinators)
   - UIConnections does not import AppComposition (correct)

---

## PHASE C — ACTUAL POWERS & AUTHORITIES

### Component Powers Matrix

| Component | Read Files | Write Files | Delete Files | Restructure Dirs | Mutate Domain State | Emit Side Effects | Call LLMs | Spawn Tasks | Trigger Other Components | Power Explicit? | Power Constrained? |
|-----------|------------|-------------|--------------|------------------|---------------------|-------------------|-----------|-------------|--------------------------|-----------------|-------------------|
| **WorkspaceEngineImpl** | ✅ (via FileSystemAccess) | ❌ | ❌ | ❌ | ✅ (snapshot, state) | ✅ (update stream) | ❌ | ✅ (watcher task) | ✅ (triggers refresh) | ✅ | ✅ (actor-isolated) |
| **ProjectEngineImpl** | ✅ (via persistence) | ✅ (via persistence) | ❌ | ❌ | ✅ (project store) | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ (via protocol) |
| **ConversationEngineLive** | ✅ (via FileContentLoading) | ❌ | ❌ | ❌ | ✅ (conversation cache) | ✅ (stream callbacks) | ✅ (via CodexClient) | ✅ (streaming task) | ✅ (triggers UI updates) | ✅ | ✅ (actor-isolated) |
| **WorkspaceViewModel** | ❌ | ❌ | ❌ | ❌ | ✅ (UI state) | ✅ (alerts, errors) | ❌ | ✅ (async tasks) | ✅ (triggers engines) | ✅ | ⚠️ (MainActor only) |
| **ChatViewModel** | ❌ | ❌ | ❌ | ❌ | ✅ (UI state) | ❌ | ❌ | ✅ (async tasks) | ✅ (triggers coordinator) | ✅ | ✅ (MainActor only) |
| **ProjectSession** | ❌ | ❌ | ❌ | ❌ | ✅ (session state) | ✅ (security scopes) | ❌ | ✅ (async tasks) | ✅ (triggers workspace) | ✅ | ✅ (MainActor only) |
| **ConversationCoordinator** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (polling task) | ✅ (triggers workspace, chat VM) | ✅ | ✅ (MainActor only) |
| **ProjectCoordinator** | ❌ | ❌ | ❌ | ❌ | ✅ (via ProjectEngine) | ✅ (alerts) | ❌ | ❌ | ✅ (triggers session, engine) | ✅ | ✅ (MainActor only) |
| **CodexService** | ✅ (via FileContentLoading) | ✅ (via FileMutationAuthority) | ❌ | ✅ (via mutation) | ❌ | ✅ (stream callbacks) | ✅ (via CodexClient) | ✅ (async tasks) | ✅ (triggers mutations) | ✅ | ⚠️ (@unchecked Sendable) |
| **FileMutationAuthority** | ❌ | ✅ (via AtomicDiffApplying) | ❌ | ✅ (creates dirs) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ⚠️ (@unchecked Sendable) |
| **AtomicDiffApplierAdapter** | ✅ (reads for backup) | ✅ (writes files) | ❌ | ✅ (creates dirs) | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ⚠️ (@unchecked Sendable) |
| **FileSystemAccessAdapter** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ (protocol) |
| **FileContentLoaderAdapter** | ✅ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ (actor) |
| **FileSystemWatcherAdapter** | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ (triggers refresh) | ❌ | ✅ (FSEvent task) | ✅ (triggers workspace) | ✅ | ✅ (queue-isolated) |

### Power Analysis

**Explicit Powers:**
- All file mutations go through explicit protocols: `FileMutationAuthorizing`, `AtomicDiffApplying`
- All LLM calls go through explicit protocols: `CodexClient`, `CodexQuerying`
- All domain state mutations are actor-isolated or MainActor-isolated

**Implicit Powers:**
- `CodexService` can mutate filesystem, but this is explicit via `FileMutationAuthorizing` dependency
- `WorkspaceViewModel` can trigger engine operations, but this is explicit via engine dependencies

**Unconstrained Powers:**
- `CodexService` is `@unchecked Sendable` but accesses engines/services that are thread-safe
- `FileMutationAuthority` is `@unchecked Sendable` but only accesses thread-safe adapters
- `AtomicDiffApplierAdapter` is `@unchecked Sendable` but uses FileManager (thread-safe for atomic writes)

---

## PHASE D — ACTUAL PROCESS FLOWS

### Flow 1: User Chat Message

**Step-by-step trace:**

1. **Intent enters:** User types in `ChatViewModel.text` and submits
2. **ChatViewModel.commitMessage()** (MainActor)
   - Creates `Message(role: .user, ...)`
   - Appends to `messages` array (optimistic UI)
   - Sets `isSending = true`
   - Clears `text = ""`
3. **ChatViewModel.send()** → **ConversationCoordinator.sendMessage()** (MainActor)
   - Calls `workspace.sendMessage(text, for: conversation)`
4. **WorkspaceViewModel.sendMessage()** (MainActor)
   - Sets `isLoading = true`
   - Sets `streamingMessages[conversation.id] = ""`
   - Checks `hasContextAnchor()` (requires workspace snapshot)
   - Builds `ConversationContextRequest` from workspace snapshot
   - Calls `conversationEngine.sendMessage(...)`
5. **ConversationEngineLive.sendMessage()** (Actor)
   - Appends user message to conversation
   - Calls `contextResolver.resolve()` → loads files via `FileContentLoading`
   - Emits `.context(contextResult)` callback
   - Calls `client.stream(messages, contextFiles)` → spawns streaming task
   - For each chunk: emits `.assistantStreaming(buffer)` callback
   - On completion: emits `.assistantCommitted(message)` callback
   - Persists conversation via `ConversationPersistenceDriver`
6. **Callback chain:** `ConversationDelta` → `WorkspaceViewModel.buildStreamHandler()`
   - Updates `streamingMessages[conversationID]` (MainActor)
   - Updates `lastContextResult`, `lastContextSnapshot`
7. **ConversationCoordinator.monitorAndForwardStreaming()** (MainActor, polling)
   - Polls `workspace.streamingMessages[conversationID]` every 50ms
   - Calls `chatViewModel.applyDelta(.assistantStreaming(...))`
8. **ChatViewModel.applyDelta()** (MainActor)
   - Updates `streamingText = aggregate`
   - On `.assistantCommitted`: appends message, sets `streamingText = nil`, `isSending = false`

**Where reasoning occurs:** None. Pure data flow.

**Where decisions are made:**
- `WorkspaceViewModel.hasContextAnchor()` — decides if context is available
- `ConversationEngineLive.contextResolver.resolve()` — decides which files to load
- `CodexClient` (external) — generates response

**Where mutation happens:**
- `ChatViewModel.messages` (UI state)
- `WorkspaceViewModel.streamingMessages` (UI state)
- `ConversationEngineLive.cache` (domain state)
- `ConversationPersistenceDriver` (persistence)

**Where feedback is observed:**
- UI updates via `@Published` properties
- Streaming text appears in chat UI
- Final message appears when committed

### Flow 2: File Being Read

**Step-by-step trace:**

1. **Intent enters:** WorkspaceEngineImpl needs to build tree or load file content
2. **WorkspaceEngineImpl.openWorkspace()** (Actor)
   - Calls `fileSystem.resolveRoot(at: canonicalRoot)` → `FileSystemAccessAdapter.resolveRoot()`
   - Calls `buildTree(from: rootID, ...)` → `walk(id: id, ...)`
3. **WorkspaceEngineImpl.walk()** (Actor)
   - Calls `fileSystem.listChildren(of: id)` → `FileSystemAccessAdapter.listChildren()`
   - Reads directory contents via FileManager
   - Recurses for subdirectories
4. **FileContentLoaderAdapter.load()** (when file content needed)
   - Called by `ConversationContextResolver` or `WorkspaceContextPreparer`
   - Reads file via FileManager
   - Returns `LoadedFile`

**Where reasoning occurs:** None. Pure I/O.

**Where decisions are made:**
- `WorkspaceEngineImpl.filtered()` — filters excluded paths
- `ContextBuilder` — decides which files to include in context

**Where mutation happens:**
- `WorkspaceEngineImpl.state` (descriptorIndex, pathIndex, snapshot)

**Where feedback is observed:**
- Workspace tree appears in UI
- File content available for context

### Flow 3: File Being Modified

**Step-by-step trace:**

1. **Intent enters:** User or LLM provides unified diff text (e.g., from LLM response)
2. **CodexService.applyDiff()** (any executor, @unchecked Sendable)
   - Calls `mutationPipeline.applyUnifiedDiff(diffText, rootPath: rootPath)`
3. **CodexMutationPipeline.applyUnifiedDiff()** (any executor)
   - Parses diff text via `UnifiedDiffParser.parse()`
   - Extracts `FileDiff` objects
   - Calls `authority.apply(diffs: fileDiffs, rootPath: rootPath)`
4. **FileMutationAuthority.apply()** (any executor)
   - Resolves canonical root via `rootProvider.canonicalRoot(for: rootPath)`
   - Calls `applier.apply(diffs: diffs, in: rootURL)`
5. **AtomicDiffApplierAdapter.apply()** (any executor)
   - For each diff: reads original file, creates backup
   - Applies patch via `UnifiedDiffApplier.apply(patch: ..., to: originalContent)`
   - Writes patched content via `writer.write(patched, to: targetURL)`
   - On error: rolls back via `RollbackManager.rollback()`
6. **FileWriteAdapter.write()** (any executor)
   - Creates directory if needed: `FileManager.createDirectory(...)`
   - Writes file atomically: `data.write(to: url, options: .atomic)`

**Where reasoning occurs:** None. Pure transformation.

**Where decisions are made:**
- `UnifiedDiffParser` — parses diff format
- `UnifiedDiffApplier` — applies hunks to content
- `RollbackManager` — decides to rollback on error

**Where mutation happens:**
- Filesystem (file contents, directory structure)

**Where feedback is observed:**
- File changes appear in filesystem
- FileSystemWatcherAdapter detects changes → triggers workspace refresh → UI updates

### Flow 4: Error Occurring

**Step-by-step trace:**

1. **Error thrown:** In engine, adapter, or service
2. **Caught in ViewModel/Coordinator:**
   - `WorkspaceViewModel.sendMessage()` catches → `handleSendMessageError()`
   - `ProjectCoordinator.openProject()` catches → `alertCenter.publish()`
   - `ProjectSession.open()` catches → `alertCenter.publish()`
3. **Error publishing:**
   - **Path A:** `AlertCenter.publish(error, fallbackTitle: ...)` → UI alert
   - **Path B:** `WorkspaceViewModel.contextErrorSubject.send(error)` → `ContextErrorBindingCoordinator` → `ContextPresentationViewModel.bannerMessage` → UI banner
4. **UI presentation:**
   - Alert appears via SwiftUI `.alert()` modifier
   - Banner appears via `ContextPresentationViewModel.bannerMessage`

**Where reasoning occurs:** None. Pure propagation.

**Where decisions are made:**
- ViewModel/Coordinator — decides which error path (alert vs banner)
- `AlertCenter` — decides alert presentation

**Where mutation happens:**
- `AlertCenter` internal state (alert queue)
- `ContextPresentationViewModel.bannerMessage` (UI state)

**Where feedback is observed:**
- Alert dialog appears
- Banner message appears

### Flow 5: Agent "Fixing" Something

**Not implemented.** No autonomous agent execution found in codebase.

---

## PHASE E — IMPLICIT FORMS (DISCOVERED, NOT CHOSEN)

### Forms Already Present

1. **Contract Form** (Protocols)
   - `WorkspaceEngine`, `ProjectEngine`, `ConversationEngine` — engine contracts
   - `FileSystemAccess`, `FileContentLoading`, `ConversationPersistenceDriver` — adapter contracts
   - `CodexClient`, `CodexQuerying` — LLM contracts
   - `FileMutationAuthorizing`, `AtomicDiffApplying` — mutation contracts
   - **Location:** `AppCoreEngine/Sources/CoreEngine/Protocols/`

2. **State Form** (Domain State)
   - `WorkspaceSnapshot` — immutable workspace state
   - `WorkspaceStateActor` — actor-isolated mutable state
   - `Conversation` — conversation state
   - `ProjectRepresentation` — project state
   - **Location:** `AppCoreEngine/Sources/CoreEngine/Domain/`

3. **Coordination Form** (Coordinators)
   - `ConversationCoordinator` — coordinates chat flow
   - `ProjectCoordinator` — coordinates project operations
   - `ContextErrorBindingCoordinator` — coordinates error binding
   - **Location:** `UIConnections/Sources/UIConnections/` and `AppComposition/`

4. **Execution Form** (Engines)
   - `WorkspaceEngineImpl` — executes workspace operations
   - `ProjectEngineImpl` — executes project operations
   - `ConversationEngineLive` — executes conversation operations
   - **Location:** `AppCoreEngine/Sources/CoreEngine/`

5. **Composition Form** (Composition Root)
   - `ChatUIHost` — composes all dependencies
   - `AppContainer` — creates all instances
   - `DependencyContainer` — provides dependency interface
   - **Location:** `AppComposition/Sources/AppComposition/`

6. **Mapping Form** (UI-Domain Bridge)
   - `WorkspaceViewModel` — maps domain to UI
   - `ChatViewModel` — maps conversation to UI
   - `FileNode` — maps FileDescriptor to UI
   - **Location:** `UIConnections/Sources/UIConnections/`

### What Functions As:

- **Contracts:** Protocol definitions in `AppCoreEngine/Protocols/`
- **State:** Immutable value types (`WorkspaceSnapshot`, `Conversation`) + actor-isolated mutable state (`WorkspaceStateActor`, `ConversationEngineLive` cache)
- **Coordination:** Coordinator classes that orchestrate flows without owning domain state
- **Execution:** Engine implementations that execute domain operations
- **Composition:** `ChatUIHost` and `AppContainer` that wire dependencies

---

## PHASE F — FORMAL CONTRADICTIONS (IS → IS NOT)

### Contradiction 1: CodexService Exercises File Mutation Authority

**The Contradiction:**
- `CodexService` (in `UIConnections`) both queries LLMs AND applies file mutations
- `UIConnections` is supposed to be a UI-domain bridge (mapping layer)
- File mutation is a domain operation, not a UI concern

**Concrete Elements:**
- `CodexService.applyDiff()` calls `FileMutationAuthority.apply()`
- `CodexService` is in `UIConnections` module
- `FileMutationAuthority` is in `AppAdapters` module

**Specific Power Mismatch:**
- `CodexService` exercises filesystem write authority from a module that should only map/coordinate
- This violates the intended form: `UIConnections` should not mutate filesystem

**Evidence:**
```swift
// UIConnections/Sources/UIConnections/Codex/CodexService.swift
public func applyDiff(_ diffText: String, rootPath: String) throws -> [AppliedPatchResult] {
    try mutationPipeline.applyUnifiedDiff(diffText, rootPath: rootPath)
}
```

### Contradiction 2: WorkspaceViewModel Exercises Multiple Authorities

**The Contradiction:**
- `WorkspaceViewModel` both coordinates UI state AND triggers domain operations AND publishes errors AND manages streaming
- It conflates presentation, coordination, and domain orchestration

**Concrete Elements:**
- `WorkspaceViewModel` implements `ConversationWorkspaceHandling` (coordination)
- `WorkspaceViewModel` manages `@Published` UI state (presentation)
- `WorkspaceViewModel` calls engines directly (domain orchestration)
- `WorkspaceViewModel` publishes errors via `contextErrorSubject` (error coordination)

**Specific Power Mismatch:**
- A single component exercises powers of presentation, coordination, and domain orchestration
- This violates separation: ViewModel should only map domain to UI, not orchestrate flows

**Evidence:**
```swift
// UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Conversation.swift
func sendMessage(_ text: String, for conversation: Conversation) async {
    // Orchestrates: builds context, calls engine, handles streaming, publishes errors
    let (_, contextResult) = try await sendMessageWithContext(...)
    lastContextResult = contextResult
    // ...
}
```

### Contradiction 3: ConversationCoordinator Polls Instead of Observing

**The Contradiction:**
- `ConversationCoordinator` polls `workspace.streamingMessages` every 50ms instead of observing via Combine
- This is an implicit form violation: coordination should use explicit observation, not polling

**Concrete Elements:**
- `ConversationCoordinator.monitorAndForwardStreaming()` uses `Task.sleep()` polling loop
- `WorkspaceViewModel.streamingMessages` is `@Published` but not observed via Combine subscription

**Specific Power Mismatch:**
- Coordinator exercises polling authority instead of observation authority
- This creates unnecessary CPU usage and latency

**Evidence:**
```swift
// UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift
private func monitorAndForwardStreaming(...) async {
    // Polls every 50ms
    while elapsed < maxWaitTime {
        // Check workspace.streamingMessages
        try? await Task.sleep(nanoseconds: pollInterval)
    }
}
```

### Contradiction 4: FileMutationAuthority in AppAdapters But Used by UIConnections

**The Contradiction:**
- `FileMutationAuthority` is in `AppAdapters` (adapter layer)
- `CodexService` (in `UIConnections`) uses it directly
- Adapters should be used by engines, not by UI-domain bridge layers

**Concrete Elements:**
- `CodexService` depends on `FileMutationAuthorizing` (protocol in `AppCoreEngine`)
- `FileMutationAuthority` implements the protocol (in `AppAdapters`)
- `AppContainer` creates `FileMutationAuthority` and passes it to `CodexService`

**Specific Power Mismatch:**
- `UIConnections` depends on adapter implementation detail (even if via protocol)
- This violates layering: `UIConnections` should not know about adapters

**Evidence:**
```swift
// AppComposition/Sources/AppComposition/AppContainer.swift
let mutationAuthority = FileMutationAuthority()  // Adapter
let codexService = CodexService(
    // ...
    mutationAuthority: mutationAuthority  // Passed to UIConnections service
)
```

### Contradiction 5: WorkspaceViewModel Manages Both UI State and Domain State Projection

**The Contradiction:**
- `WorkspaceViewModel` maintains `workspaceSnapshot` (domain state projection) AND `workspaceState` (UI state)
- It conflates domain state observation with UI state management

**Concrete Elements:**
- `WorkspaceViewModel.workspaceSnapshot` (private, domain state)
- `WorkspaceViewModel.workspaceState` (`@Published`, UI state)
- Both are updated from the same engine updates stream

**Specific Power Mismatch:**
- ViewModel exercises both domain state projection and UI state management
- This violates separation: ViewModel should only project domain to UI, not maintain domain state

**Evidence:**
```swift
// UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift
var workspaceSnapshot: WorkspaceSnapshot = .empty  // Domain state
@Published public var workspaceState: WorkspaceViewState = ...  // UI state
```

### Contradiction 6: Multiple Components Claim Error Publishing Authority

**The Contradiction:**
- `WorkspaceViewModel`, `ProjectCoordinator`, `ProjectSession` all publish errors via `AlertCenter`
- `WorkspaceViewModel` also publishes errors via `contextErrorSubject`
- No single authority for error coordination

**Concrete Elements:**
- `WorkspaceViewModel.alertCenter?.publish(...)`
- `ProjectCoordinator.alertCenter.publish(...)`
- `ProjectSession.alertCenter?.publish(...)`
- `WorkspaceViewModel.contextErrorSubject.send(...)`

**Specific Power Mismatch:**
- Multiple components exercise error publishing authority
- This creates inconsistency: some errors go to alerts, some to banners, some to both

**Evidence:**
- Multiple files publish errors independently
- No centralized error coordination strategy

---

## PHASE G — NECESSARY OUGHT (DERIVED, NOT DESIRED)

### Correction 1: CodexService Cannot Remain in UIConnections

**Necessary Correction:**
- `CodexService` exercises file mutation authority, which exceeds the form of a UI-domain bridge
- It must be separated: either moved to `AppCoreEngine` (as a domain service) or split into query service (UIConnections) and mutation service (AppCoreEngine)

**Principle:**
- A component that mutates filesystem cannot remain in a mapping/coordination layer
- File mutation is a domain operation, not a UI concern

**Language of Necessity:**
- "CodexService cannot remain where it is, because it exercises file mutation authority"
- "File mutation must be separated from LLM querying, because they are different powers"

### Correction 2: WorkspaceViewModel Must Be Separated

**Necessary Correction:**
- `WorkspaceViewModel` conflates presentation, coordination, and domain orchestration
- It must be separated into: ViewModel (presentation only), Coordinator (coordination), and possibly a domain service (orchestration)

**Principle:**
- A single component cannot exercise powers of presentation, coordination, and domain orchestration
- Each power requires a distinct form

**Language of Necessity:**
- "WorkspaceViewModel cannot remain as a single component, because it exercises multiple distinct powers"
- "Presentation must be separated from coordination, because they are different forms"

### Correction 3: ConversationCoordinator Must Observe, Not Poll

**Necessary Correction:**
- `ConversationCoordinator` must observe `streamingMessages` via Combine subscription, not poll
- Polling violates the form of coordination (explicit observation)

**Principle:**
- Coordination requires explicit observation, not implicit polling
- Polling creates unnecessary resource usage

**Language of Necessity:**
- "ConversationCoordinator cannot poll, because coordination requires explicit observation"
- "Streaming updates must be observed, not polled, because observation is the proper form"

### Correction 4: FileMutationAuthority Must Not Be Used by UIConnections

**Necessary Correction:**
- `CodexService` (in `UIConnections`) cannot use `FileMutationAuthority` (in `AppAdapters`) directly
- Either `CodexService` moves to `AppCoreEngine`, or file mutation is delegated to an engine

**Principle:**
- UI-domain bridge layers cannot depend on adapter implementations
- Adapters must be used by engines, not by bridge layers

**Language of Necessity:**
- "UIConnections cannot use adapters, because bridge layers must not know about adapters"
- "File mutation must be exercised by an engine, not by a bridge layer"

### Correction 5: WorkspaceViewModel Must Not Maintain Domain State

**Necessary Correction:**
- `WorkspaceViewModel` cannot maintain `workspaceSnapshot` (domain state projection)
- It must only project domain state to UI state on-demand or via observation

**Principle:**
- ViewModels must not maintain domain state; they must only project it
- Domain state belongs in engines

**Language of Necessity:**
- "WorkspaceViewModel cannot maintain domain state, because ViewModels must only project"
- "Domain state projection must be on-demand, not cached in ViewModel"

### Correction 6: Error Publishing Must Have Single Authority

**Necessary Correction:**
- Error publishing cannot be exercised by multiple components independently
- Either a single error coordinator is created, or error publishing is constrained to a single layer

**Principle:**
- Error coordination requires a single authority
- Multiple authorities create inconsistency

**Language of Necessity:**
- "Error publishing cannot be exercised by multiple components, because coordination requires single authority"
- "Error coordination must be centralized, because multiple authorities violate order"

---

## PHASE H — REBUILD READINESS CHECK

### 1. What Must Be Frozen First to Prevent Further Corruption?

**Answer:**
- **File mutation authority** must be frozen: `CodexService.applyDiff()` must not be called until it is moved to proper layer
- **WorkspaceViewModel orchestration** must be frozen: `WorkspaceViewModel.sendMessage()` and `askCodex()` must not be extended until separated
- **Error publishing** must be frozen: No new error publishing paths until centralized

**Rationale:**
- These are the primary formal corruptions (Contradictions 1, 2, 6)
- Further use will deepen the corruption

### 2. What Cannot Be Rebuilt Yet Because Its Form Is Not Fully Known?

**Answer:**
- **UIContracts** cannot be rebuilt: It is empty, and its intended form is not discovered in the codebase
- **Agent execution** cannot be built: No form exists for autonomous agent execution
- **Error coordination** form is partially known (AlertCenter exists) but not fully specified (banner vs alert strategy unclear)

**Rationale:**
- UIContracts has no existing form to recover
- Agent execution has no existing form to recover
- Error coordination has mixed forms (alert + banner) that need clarification

### 3. What Single Separation Would Yield the Greatest Restoration of Order?

**Answer:**
- **Separate `CodexService` into query service (UIConnections) and mutation service (AppCoreEngine)**

**Rationale:**
- This addresses Contradiction 1 (CodexService exercises file mutation from wrong layer)
- This also partially addresses Contradiction 4 (UIConnections using adapters)
- This is a single, clear separation that restores layering order
- File mutation is clearly a domain operation and belongs in AppCoreEngine

**Implementation Principle:**
- Create `FileMutationService` in `AppCoreEngine` that exercises `FileMutationAuthorizing`
- Move `CodexService.applyDiff()` to `FileMutationService`
- `CodexService` (in UIConnections) delegates file mutation to `FileMutationService` (in AppCoreEngine)
- This restores the form: UIConnections coordinates, AppCoreEngine executes

---

## FORM RECOVERY VERDICT

### Is the system currently intelligible as a single ordered being?

**Answer: No.**

**Reason:**
- Multiple formal contradictions exist where components exercise powers exceeding their discovered forms
- `CodexService` exercises file mutation from a UI-domain bridge layer
- `WorkspaceViewModel` exercises multiple distinct powers (presentation, coordination, orchestration)
- Error publishing has multiple authorities without coordination
- These contradictions prevent the system from being intelligible as a single ordered being

### Where is the primary formal corruption?

**Answer:**
- **Primary corruption:** `CodexService` in `UIConnections` exercises file mutation authority
- **Secondary corruption:** `WorkspaceViewModel` conflates presentation, coordination, and orchestration
- **Tertiary corruption:** Error publishing has multiple uncoordinated authorities

**Location:**
- `UIConnections/Sources/UIConnections/Codex/CodexService.swift` (primary)
- `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift` (secondary)
- Multiple files with error publishing (tertiary)

### What must be separated before any rebuilding?

**Answer:**
1. **File mutation must be separated from LLM querying**
   - `CodexService.applyDiff()` must move to `AppCoreEngine` as `FileMutationService`
   - `CodexService` (in UIConnections) must only query LLMs

2. **Presentation must be separated from coordination**
   - `WorkspaceViewModel` must be split: ViewModel (presentation) + Coordinator (coordination) + possibly domain service (orchestration)

3. **Error publishing must be centralized**
   - Single error coordinator or single layer for error publishing

**Order of Separation:**
1. File mutation separation (restores layering)
2. WorkspaceViewModel separation (restores power boundaries)
3. Error coordination (restores single authority)

### Is rebuilding UIContracts justified now, or premature?

**Answer: Premature.**

**Reason:**
- UIContracts is empty (no existing form to recover)
- No discovered form exists for what UIContracts should contain
- Rebuilding without form would be invention, not recovery
- Must first recover forms from existing codebase before inventing new layers

**When Justified:**
- After file mutation and WorkspaceViewModel are separated, the form of contracts may emerge
- If a clear contract form is discovered (e.g., explicit UI-domain contracts), then rebuilding is justified
- Until then, rebuilding UIContracts would be speculation

---

## END OF AUDIT

