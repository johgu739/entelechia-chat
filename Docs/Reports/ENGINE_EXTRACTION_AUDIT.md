## Engine Boundary Map
- Domain models and services that are already UI-agnostic: `Intelligence/Conversations/Models` (Conversation, Message, LoadedFile, etc.), `Intelligence/Conversations/Services` (`ConversationService`, `ContextBuilder`, `TokenEstimator`), `Intelligence/Projects/Services/ProjectSession` (project lifecycle state), `Intelligence/Workspace/Models` (`FileNode`, `LoadedFile`), and `Infrastructure/AI` (`CodexAPIClient`, `CodexAssistant`, `ModelClient`).
- Persistence and migration: `Infrastructure/Persistence` (`FileStore`, `ConversationStore`, `ProjectStore`, `ProjectsDirectory`, `PersistenceMigrator`) hold storage logic and path decisions.
- Preferences: `Infrastructure/Preferences` (`PreferencesStore`, `ContextPreferencesStore`) for `.entelechia` sidecar files.
- Workspace/file access: `Intelligence/Workspace/Services` (`WorkspaceFileSystemService`, `FileContentService`, `FileExclusion`, `FileContentService`) provide file traversal and loading.
- Security/bookmarking abstractions: `SecurityScopeHandling` and `RealSecurityScopeHandler` (defined alongside `ProjectCoordinator`).
- Alert transformation: `AlertCenter` converts errors to user-facing payloads but is UI-facing; the error typing can live in Engine while presentation moves to UI.
- Test doubles: `TestContainer`, `MockCodeAssistant`, `MockFailingConfigLoader`, `NoopSecurityScopeHandler` already model engine-level seams.

## UI Boundary Map
- SwiftUI views and layout: all under `Accidents/` (Shell, ConversationUI, WorkspaceUI, Theme, XcodeNavigator), e.g., `RootView`, `MainWorkspaceView`, `ChatView`, `ChatInputView`, `ContextInspector`, `XcodeNavigatorView`, `FilesSidebarView`, `OnboardingSelectProjectView`.
- Teleology bootstrap: `Teleology/EntelechiaChatApp.swift` wires container, runs migrations, injects environment objects, and hosts SwiftUI `Scene`.
- View models with UI state: `Intelligence/Workspace/Faculties/WorkspaceViewModel` (selection, streaming text UI state, navigator toggles); any other SwiftUI `ObservableObject` types used by views.
- App-level orchestration and environment: `Teleology/AppEnvironment` (holds selected assistant mode and Codex config) and `DependencyContainer` (currently concrete wiring).

## Entanglement Report (violation → impact → surgical fix)
- App boot performs migrations and persistence I/O inside SwiftUI entry: `EntelechiaChatApp` runs `PersistenceMigrator`, constructs default stores (disk I/O) and loads conversations in `.task` on the root view, binding engine lifecycle to UI start-up.  
  Fix: move migrations and store initialization behind an Engine bootstrap service that the UI calls via protocol; UI gets a ready-made engine instance.
  ```
  57:114:entelechia-chat/Teleology/EntelechiaChatApp.swift
  try PersistenceMigrator().runMigrations()
  _conversationStore = StateObject(wrappedValue: container.conversationStore)
  .task { try conversationStore.loadAll() }
  ```
- AppEnvironment both configures Codex and instantiates the assistant, performing keychain/env lookups in a UI-observable object.  
  Fix: split into pure Engine `AssistantConfigService` + `AssistantFactory` protocol; UI holds only the status/result.  
  ```
  38:76:entelechia-chat/Teleology/AppEnvironment.swift
  switch loader.loadConfig() { ... assistant = CodexAssistant(config: config) ... }
  ```
- DefaultContainer constructs real services (FileStore, ProjectStore from disk, Codex assistant) eagerly inside UI bootstrap, using `ProcessInfo` and `FileManager`.  
  Fix: make container an Engine-owned composition root; UI receives protocols.  
  ```
  31:49:entelechia-chat/Teleology/DependencyContainer.swift
  self.fileStore = FileStore()
  self.projectStore = (try? ProjectStore.loadFromDisk()) ?? ...
  self.codexAssistant = CodexAssistant(config: config)
  ```
- WorkspaceViewModel mixes UI state with Engine behavior: it loads conversations, manages preferences, file I/O, FSEvents, and calls `ConversationService` directly.  
  Impact: hard to run Engine headless; view model must be in UI, not the Engine core.  
  Fix: introduce `WorkspaceEngine` protocol returning immutable view data; UI VM becomes a thin adapter.  
  ```
  154:166:entelechia-chat/Intelligence/Workspace/Faculties/WorkspaceViewModel.swift
  self.conversationService = ConversationService(..., fileContentService: FileContentService.shared)
  ```
- FileContentService/WorkspaceFileSystemService/FileStore are singletons (`shared`) referenced directly by services and view models, causing hidden global state and shared mutable base paths.  
  Fix: remove statics; inject via protocols `FileSystemAccess`, `FileContentLoading`, `PersistenceDriver`.  
  ```
  18:33:entelechia-chat/Infrastructure/Persistence/FileStore.swift
  private static var _shared = FileStore(); static var shared: FileStore { _shared }
  ```
  ```
  42:48:entelechia-chat/Intelligence/Workspace/Services/WorkspaceFileSystemService.swift
  private static var _shared = WorkspaceFileSystemService(); static var shared: WorkspaceFileSystemService { _shared }
  ```
  ```
  18:23:entelechia-chat/Intelligence/Workspace/Services/FileContentService.swift
  static let shared = FileContentService()
  ```
- ConversationStore is an `ObservableObject` with SwiftUI-facing `@Published` state and uses `Task` to mutate UI state after I/O.  
  Impact: engine persistence tied to SwiftUI runtime; cannot drop into a headless process.  
  Fix: split into pure store protocol plus UI adapter that mirrors changes into published properties.  
  ```
  41:172:entelechia-chat/Infrastructure/Persistence/ConversationStore.swift
  @Published var conversations ... Task { @MainActor ... }
  ```
- ProjectCoordinator mixes engine duties (bookmarking, persistence) with UI alerting and menu updates via NotificationCenter.  
  Fix: define `ProjectEngine` (open/close, recents, bookmarks) returning results; UI layer handles alerts and menu notifications.  
  ```
  103:146:entelechia-chat/Intelligence/Projects/Services/ProjectCoordinator.swift
  let bookmarkData = try securityScopeHandler.makeBookmark(...)
  projectSession.open(...); alertCenter.publish(error, ...)
  ```
- RootView/MainWorkspaceView push engine stores and preferences directly into views, including passing `PreferencesStore`/`ContextPreferencesStore` into UI constructors.  
  Impact: UI holds persistence primitives.  
  Fix: UI should depend on a `WorkspaceViewModel` fed by `WorkspaceEngine` DTOs; persistence lives behind engine interfaces.  
  ```
  54:115:entelechia-chat/Accidents/Shell/MainView.swift
  workspaceViewModel.setConversationStore(conversationStore)
  workspaceViewModel.setPreferencesStore(preferencesStore)
  ```

## Dependency Inversion Plan (protocols to introduce)
- `CodexClient` (transport) and `CodexAssistant` already exist; formalize an interface that the Engine depends on, implemented by network client or mock.
- `ConversationEngine`: orchestrates send/ensure conversation, context building, and persistence; UI receives immutable DTOs and stream callbacks.
- `ProjectEngine`: opens/closes projects, manages recents, bookmarks, and sessions; UI calls this instead of `ProjectCoordinator`.
- `SecurityScopeHandling`: exists; move to Engine-facing protocol with macOS adapter in UI process.
- `FileSystemAccess`: wrap directory traversal and node creation; implemented by `WorkspaceFileSystemService`.
- `FileContentLoading`: wrap content reads; implemented by `FileContentService`.
- `PersistenceDriver`: wrap `FileStore` path resolution and atomic IO; enable alternate roots for tests/services.
- `PreferencesDriver` and `ContextPreferencesDriver`: abstract `.entelechia` files.
- `AlertSink`: Engine emits typed errors; UI implements presentation.
- `WorkspaceEngine`: aggregates workspace tree, selection, watcher events into pure outputs; UI subscribes.

## Clean Engine Architecture Blueprint
/Engine  
  /Domain (Conversations, Projects, Workspace models)  
  /Conversations (ConversationEngine, ContextBuilder, TokenEstimator)  
  /Projects (ProjectEngine, session state)  
  /Workspace (FileSystemAccess, FileContentLoading, FileExclusion)  
  /Persistence (PersistenceDriver, ConversationStore, ProjectStore, Migrator)  
  /Codex (CodexClient, CodexAssistant)  
  /Security (SecurityScopeHandling)  
  /Adapters (macOS implementations, mocks)  
  /Migration (PersistenceMigrator and seeds)  
/App  
  /UI (SwiftUI views)  
  /ViewModels (pure adapters consuming Engine protocols)  
  /AppEnvironment (status only; no IO)  
  /Coordinators (UI-only routing, alerts)  

## Separation Migration Sequence
1) Identify pure logic: freeze Engine-worthy files above and ensure tests cover them headless.  
2) Extract tests: move conversation/persistence/preferences/coordinator tests into an Engine test target; remove SwiftUI/runtime dependencies.  
3) Replace singletons: refactor `FileStore.shared`, `WorkspaceFileSystemService.shared`, `FileContentService.shared` into injected `PersistenceDriver/FileSystemAccess/FileContentLoading`.  
4) Introduce adapters: define Engine protocols (listed) and provide macOS adapters for security scope, filesystem, alert sink, Codex transport.  
5) Move persistence: expose `ConversationStore`/`ProjectStore` via Engine protocols; UI holds only references returned by Engine bootstrap.  
6) Move Codex: Engine owns assistant instantiation; UI receives a protocol handle and status DTO; AppEnvironment becomes a thin status reporter.  
7) Detach security concerns: wrap `SecurityScopeHandling` in adapter; Engine returns bookmark data; UI invokes macOS-specific implementation.  
8) Wire container: create Engine bootstrap (factory) that yields all protocols; UI composition root resolves only protocol types.  
9) Clean UI: rewrite `WorkspaceViewModel` to depend on `WorkspaceEngine` outputs; remove direct file/persistence calls.  
10) Final readiness audit: ensure no SwiftUI import in Engine, all globals removed, and tests run headless with injected adapters.

