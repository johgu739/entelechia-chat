---
name: Form Recovery - Ordered Transition
overview: "Restore order by addressing 4 formal contradictions in strict sequence: (1) Separate file mutation from LLM querying, (2) Split WorkspaceViewModel into distinct powers, (3) Replace polling with observation, (4) Centralize error authority. Each step maintains functional equivalence."
todos:
  - id: freeze-mutation-paths
    content: Add documentation comments freezing mutation entry points in CodexService and WorkspaceViewModel
    status: completed
  - id: power-classification
    content: Document power classification for all components to be extracted (descriptive/decisional/effectual, layer permissions)
    status: completed
    dependencies:
      - freeze-mutation-paths
  - id: create-mutation-plan-type
    content: Create MutationPlan type in AppCoreEngine to separate authorization from execution
    status: completed
    dependencies:
      - power-classification
  - id: create-file-mutation-service
    content: Create FileMutationService in AppCoreEngine that validates/orders and emits MutationPlan (does not execute)
    status: completed
    dependencies:
      - create-mutation-plan-type
  - id: split-codex-service
    content: Split CodexService into CodexQueryService (UIConnections, LLM only) and remove mutation authority
    status: completed
    dependencies:
      - create-file-mutation-service
  - id: update-file-mutation-authority
    content: Update FileMutationAuthority adapter to accept MutationPlan and execute it
    status: completed
    dependencies:
      - create-file-mutation-service
  - id: update-containers-mutation
    content: Update AppContainer and DependencyContainer to create and provide FileMutationService and FileMutationAuthority separately
    status: completed
    dependencies:
      - update-file-mutation-authority
  - id: update-call-sites-mutation
    content: Update all codexService.applyDiff() call sites to use fileMutationService.planMutation() then fileMutationAuthority.execute()
    status: completed
    dependencies:
      - update-containers-mutation
  - id: create-workspace-presentation-model
    content: Create WorkspacePresentationModel with ONLY pure UI state (exclude streamingMessages, lastContextResult, lastContextSnapshot)
    status: completed
    dependencies:
      - update-call-sites-mutation
  - id: create-workspace-projection
    content: Create WorkspaceProjection for domain-derived read-only projections (streamingMessages, lastContextResult, lastContextSnapshot)
    status: completed
    dependencies:
      - create-workspace-presentation-model
  - id: create-workspace-coordinator
    content: Create WorkspaceCoordinator with all orchestration logic (sendMessage, askCodex, context building, error handling)
    status: completed
    dependencies:
      - create-workspace-projection
  - id: create-workspace-state-observer
    content: Create WorkspaceStateObserver to observe WorkspaceEngine.updates() and project to both WorkspacePresentationModel and WorkspaceProjection
    status: completed
    dependencies:
      - create-workspace-coordinator
  - id: refactor-workspace-viewmodel
    content: Refactor WorkspaceViewModel to be thin mapper only, or remove if empty. Update all extension files to move logic to coordinator/observer
    status: completed
    dependencies:
      - create-workspace-state-observer
  - id: update-conversation-coordinator-protocol
    content: Update ConversationWorkspaceHandling protocol and ConversationCoordinator to use WorkspaceCoordinator
    status: completed
    dependencies:
      - refactor-workspace-viewmodel
  - id: expose-streaming-publisher
    content: Expose streamingPublisher from WorkspaceProjection using Combine (not WorkspacePresentationModel)
    status: completed
    dependencies:
      - update-conversation-coordinator-protocol
  - id: replace-polling-observation
    content: Replace ConversationCoordinator polling with Combine subscription to streamingPublisher
    status: completed
    dependencies:
      - expose-streaming-publisher
  - id: create-classified-error-type
    content: Create ClassifiedError type in AppCoreEngine with Severity and Intent enums
    status: completed
    dependencies:
      - replace-polling-observation
  - id: create-domain-error-authority
    content: Create DomainErrorAuthority in AppCoreEngine that classifies errors (does not route to UI)
    status: completed
    dependencies:
      - create-classified-error-type
  - id: create-ui-error-router
    content: Create UIPresentationErrorRouter in UIConnections that routes classified errors to alerts/banners
    status: completed
    dependencies:
      - create-domain-error-authority
  - id: update-containers-error
    content: Update AppContainer and DependencyContainer to create and provide DomainErrorAuthority and UIPresentationErrorRouter
    status: completed
    dependencies:
      - create-ui-error-router
  - id: remove-direct-error-publishing
    content: Remove all direct error publishing from WorkspaceViewModel, ProjectCoordinator, ProjectSession - route through DomainErrorAuthority
    status: completed
    dependencies:
      - update-containers-error
  - id: update-context-error-binding
    content: Update ContextErrorBindingCoordinator to bind to UIPresentationErrorRouter.contextErrorPublisher
    status: completed
    dependencies:
      - remove-direct-error-publishing
---

# Form Recovery - Ordered Transition Plan

## Governing Principles

- **Separation before refactoring**: Powers must be separated, not "cleaned up"
- **Functional equivalence**: System must compile and behave identically at each step
- **No new abstractions**: Only recover form from what exists
- **Fractal self-similarity**: Patterns must be repeatable at all levels

## Sequence Overview

0.5. **Explicit Authority Classification** (power declaration)

1. **Freeze mutation paths** (documentation only)
2. **Extract FileMutationService** (Contradiction 1)
3. **Split WorkspaceViewModel** (Contradiction 2)
4. **Replace polling with observation** (Contradiction 3)
5. **Centralize error authority** (Contradiction 4)

---

## STEP 0.5: Explicit Authority Classification

**Purpose**: Before extracting any component, explicitly declare its power classification to prevent silent re-corruption.

**For each component to be extracted, document:**

1. **What power it exercises**

   - Descriptive (reads/observes)
   - Decisional (validates/orders/classifies)
   - Effectual (mutates/executes)

2. **Which layer is permitted to hold that power**

   - AppCoreEngine: Domain execution, validation, ordering
   - UIConnections: UI-domain mapping, coordination
   - AppAdapters: OS/platform effects

3. **Power boundaries**

   - What it may NOT do
   - What it must delegate

**Apply this classification to:**

- FileMutationService (Step 2)
- WorkspacePresentationModel, WorkspaceProjection, WorkspaceCoordinator (Step 3)
- DomainErrorAuthority, UIPresentationErrorRouter (Step 5)

**No code changes** - documentation and design-time verification only

---

## STEP 1: Freeze Mutation Paths

**Purpose**: Document current mutation entry points to prevent further corruption

**Actions**:

- Add comments in [`UIConnections/Sources/UIConnections/Codex/CodexService.swift`](UIConnections/Sources/UIConnections/Codex/CodexService.swift) marking `applyDiff()` as frozen
- Add comments in [`UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Conversation.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Conversation.swift) marking orchestration methods as frozen

**No code changes** - documentation only

---

## STEP 2: Extract FileMutationService (Contradiction 1)

**Purpose**: Separate file mutation authority from LLM querying. File mutation is a domain execution power and must live in AppCoreEngine.

### 2.1 Create MutationPlan Type

**New file**: [`AppCoreEngine/Sources/CoreEngine/Domain/Workspace/MutationPlan.swift`](AppCoreEngine/Sources/CoreEngine/Domain/Workspace/MutationPlan.swift)

```swift
import Foundation

/// Describes a validated, ordered mutation plan.
/// Domain layer authorizes; adapter layer executes.
public struct MutationPlan: Sendable, Equatable {
    public let rootPath: String
    public let canonicalRoot: String
    public let fileDiffs: [FileDiff]
    public let validationErrors: [String]
    
    public init(rootPath: String, canonicalRoot: String, fileDiffs: [FileDiff], validationErrors: [String] = []) {
        self.rootPath = rootPath
        self.canonicalRoot = canonicalRoot
        self.fileDiffs = fileDiffs
        self.validationErrors = validationErrors
    }
    
    public var isValid: Bool {
        validationErrors.isEmpty && !fileDiffs.isEmpty
    }
}
```

### 2.2 Create FileMutationService in AppCoreEngine

**New file**: [`AppCoreEngine/Sources/CoreEngine/Services/FileMutationService.swift`](AppCoreEngine/Sources/CoreEngine/Services/FileMutationService.swift)

```swift
import Foundation

/// Domain service for authorizing and planning file mutations.
/// Power: Descriptive (parses) + Decisional (validates, orders)
/// Does NOT execute mutations - emits MutationPlan for adapter execution.
public final class FileMutationService: Sendable {
    public init() {}
    
    /// Authorizes and plans mutations from unified diff text.
    /// Returns MutationPlan that adapter must execute.
    public func planMutation(_ diffText: String, rootPath: String) throws -> MutationPlan {
        let fileDiffs = UnifiedDiffParser.parse(diffText: diffText)
        let canonicalRoot = try canonicalizeRoot(rootPath)
        let validationErrors = validateDiffs(fileDiffs, rootPath: canonicalRoot)
        
        return MutationPlan(
            rootPath: rootPath,
            canonicalRoot: canonicalRoot,
            fileDiffs: fileDiffs,
            validationErrors: validationErrors
        )
    }
    
    private func canonicalizeRoot(_ rootPath: String) throws -> String {
        let url = URL(fileURLWithPath: rootPath)
        return url.resolvingSymlinksInPath().standardizedFileURL.path
    }
    
    private func validateDiffs(_ diffs: [FileDiff], rootPath: String) -> [String] {
        var errors: [String] = []
        // Add validation logic: path existence, permissions, etc.
        return errors
    }
}

// Move UnifiedDiffParser from UIConnections here
private enum UnifiedDiffParser {
    // ... existing parsing logic from CodexMutationPipeline
}
```

**Protocol addition**: Add `FileMutationPlanning` protocol to [`AppCoreEngine/Sources/CoreEngine/Protocols/EngineProtocols.swift`](AppCoreEngine/Sources/CoreEngine/Protocols/EngineProtocols.swift):

```swift
public protocol FileMutationPlanning: Sendable {
    func planMutation(_ diffText: String, rootPath: String) throws -> MutationPlan
}
```

Make `FileMutationService` conform to this protocol.

### 2.3 Update FileMutationAuthorizing Protocol

**Modify**: [`AppCoreEngine/Sources/CoreEngine/Domain/Workspace/FileMutations.swift`](AppCoreEngine/Sources/CoreEngine/Domain/Workspace/FileMutations.swift)

**Changes**:

- Update `FileMutationAuthorizing` to accept `MutationPlan` instead of raw diffs:
```swift
public protocol FileMutationAuthorizing: Sendable {
    func execute(_ plan: MutationPlan) throws -> [AppliedPatchResult]
}
```


### 2.4 Update FileMutationAuthority Adapter

**Modify**: [`AppAdapters/Sources/AppAdapters/Workspace/FileMutationAuthority.swift`](AppAdapters/Sources/AppAdapters/Workspace/FileMutationAuthority.swift)

**Changes**:

- Update `apply()` method to accept `MutationPlan`:
```swift
public func execute(_ plan: MutationPlan) throws -> [AppliedPatchResult] {
    guard plan.isValid else {
        throw EngineError.invalidMutation("Validation errors: \(plan.validationErrors.joined(separator: ", "))")
    }
    let rootURL = URL(fileURLWithPath: plan.canonicalRoot)
    return try applier.apply(diffs: plan.fileDiffs, in: rootURL)
}
```


**Power classification**:

- FileMutationService: Descriptive + Decisional (plans)
- FileMutationAuthority: Effectual (executes)

### 2.2 Split CodexService into CodexQueryService

**Modify**: [`UIConnections/Sources/UIConnections/Codex/CodexService.swift`](UIConnections/Sources/UIConnections/Codex/CodexService.swift)

**Changes**:

- Remove `mutationPipeline` property
- Remove `mutationAuthority` from init
- Remove `applyDiff()` method
- Rename class to `CodexQueryService`
- Keep only LLM querying functionality (`askAboutWorkspaceNode`, `shapedPrompt`)

**New file**: [`UIConnections/Sources/UIConnections/Codex/CodexQueryService.swift`](UIConnections/Sources/UIConnections/Codex/CodexQueryService.swift) (rename from CodexService.swift)

### 2.6 Update CodexQuerying Protocol

**Modify**: [`UIConnections/Sources/UIConnections/CodexContracts.swift`](UIConnections/Sources/UIConnections/CodexContracts.swift) (or wherever `CodexQuerying` is defined)

**Changes**:

- Remove `applyDiff()` from `CodexQuerying` protocol
- Protocol now only contains `askAboutWorkspaceNode()` and `shapedPrompt()`

### 2.7 Update AppContainer

**Modify**: [`AppComposition/Sources/AppComposition/AppContainer.swift`](AppComposition/Sources/AppComposition/AppContainer.swift)

**Changes**:

- Create `FileMutationService` instance (no adapter dependency):
  ```swift
  let fileMutationService = FileMutationService()
  ```

- Create `FileMutationAuthority` instance (adapter):
  ```swift
  let mutationAuthority = FileMutationAuthority()
  ```

- Update `CodexService` (now `CodexQueryService`) init to remove `mutationAuthority` parameter
- Add both `fileMutationService` and `mutationAuthority` to container

### 2.8 Update DependencyContainer

**Modify**: [`AppComposition/Sources/AppComposition/DependencyContainer.swift`](AppComposition/Sources/AppComposition/DependencyContainer.swift)

**Changes**:

- Add `fileMutationService: FileMutationPlanning` property
- Add `fileMutationAuthority: FileMutationAuthorizing` property
- Update `DefaultContainer` and `TestContainer` to provide both

### 2.9 Update ChatUIHost and Call Sites

**Modify**: [`AppComposition/Sources/AppComposition/ChatUIHost.swift`](AppComposition/Sources/AppComposition/ChatUIHost.swift) and any call sites

**Changes**:

- If `CodexService.applyDiff()` is called anywhere:

  1. Call `fileMutationService.planMutation(diffText, rootPath: rootPath)` to get `MutationPlan`
  2. Call `fileMutationAuthority.execute(plan)` to execute the plan

- Both services must be available (from DependencyContainer)

### 2.10 Remove CodexMutationPipeline

**Delete**: [`UIConnections/Sources/UIConnections/Codex/CodexMutationPipeline.swift`](UIConnections/Sources/UIConnections/Codex/CodexMutationPipeline.swift)

**Reason**: Parsing logic moves to `FileMutationService` in AppCoreEngine; execution stays in adapter

**Verification**: System compiles; file mutations work via plan → execute pattern; domain layer does not execute effects

---

## STEP 3: Split WorkspaceViewModel (Contradiction 2)

**Purpose**: Separate presentation, coordination, and orchestration into distinct beings.

### 3.1 Create WorkspacePresentationModel (Pure UI State)

**New file**: [`UIConnections/Sources/UIConnections/Workspaces/WorkspacePresentationModel.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspacePresentationModel.swift)

**Content**: Extract ONLY pure UI state properties (no domain artifacts):

- `selectedNode`, `rootFileNode`, `isLoading`, `filterText`, `activeNavigator`
- `expandedDescriptorIDs`, `projectTodos`, `todosError`
- `activeScope`, `modelChoice`, `selectedDescriptorID`, `watcherError`

**Explicitly EXCLUDE** (these are domain projections, not UI state):

- `streamingMessages` → Move to WorkspaceProjection
- `lastContextResult` → Move to WorkspaceProjection
- `lastContextSnapshot` → Move to WorkspaceProjection

**No engine dependencies** - pure UI state container only

**Power classification**: Descriptive (UI state only, no domain echoes)

### 3.1a Create WorkspaceProjection (Domain Projections)

**New file**: [`UIConnections/Sources/UIConnections/Workspaces/WorkspaceProjection.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspaceProjection.swift)

**Content**: Read-only projections derived from domain streams:

- `streamingMessages: [UUID: String]` - derived from conversation engine
- `lastContextResult: ContextBuildResult?` - derived from context resolution
- `lastContextSnapshot: ContextSnapshot?` - derived from context resolution

**Power classification**: Descriptive (projects domain state to UI-readable form)

### 3.2 Create WorkspaceCoordinator

**New file**: [`UIConnections/Sources/UIConnections/Workspaces/WorkspaceCoordinator.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspaceCoordinator.swift)

**Content**: Extract all orchestration logic from `WorkspaceViewModel`:

- `sendMessage()`, `askCodex()` - conversation orchestration
- `buildContextRequest()`, `sendMessageWithContext()` - context building
- `hasContextAnchor()`, `currentWorkspaceScope()` - decision logic
- All async engine calls
- Error handling and publishing

**Dependencies**: Engines, services, `WorkspacePresentationModel` (updates state)

### 3.3 Create WorkspaceStateObserver

**New file**: [`UIConnections/Sources/UIConnections/Workspaces/WorkspaceStateObserver.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspaceStateObserver.swift)

**Content**:

- Observes `WorkspaceEngine.updates()` stream
- Projects snapshots to `WorkspacePresentationModel` (UI state updates)
- Projects context/streaming results to `WorkspaceProjection` (domain projections)
- Coordinator decides when projections are updated

**Dependencies**: `WorkspaceEngine`, `WorkspacePresentationModel`, `WorkspaceProjection`

**Power classification**: Descriptive (observes and projects, does not decide)

### 3.4 Refactor WorkspaceViewModel

**Modify**: [`UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift)

**Changes**:

- Remove all `@Published` properties (moved to `WorkspacePresentationModel`)
- Remove all orchestration methods (moved to `WorkspaceCoordinator`)
- Keep only: projection/mapping methods that convert domain types to UI types
- ViewModel becomes a thin mapper between domain and presentation model

**OR**: Consider removing `WorkspaceViewModel` entirely if it becomes empty, and have `WorkspaceCoordinator` own the presentation model directly.

### 3.5 Update ConversationWorkspaceHandling Protocol

**Modify**: [`UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift`](UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift)

**Changes**:

- Update `ConversationWorkspaceHandling` protocol to reference `WorkspaceCoordinator` instead of `WorkspaceViewModel`
- Update `ConversationCoordinator` to use `WorkspaceCoordinator`

### 3.6 Update ChatUIHost

**Modify**: [`AppComposition/Sources/AppComposition/ChatUIHost.swift`](AppComposition/Sources/AppComposition/ChatUIHost.swift)

**Changes**:

- Create `WorkspacePresentationModel` instance (pure UI state)
- Create `WorkspaceProjection` instance (domain projections)
- Create `WorkspaceCoordinator` instance (depends on engines, services, presentation model, projection)
- Create `WorkspaceStateObserver` instance (observes engine, updates both model and projection)
- Update `WorkspaceContext` to use new structure

### 3.7 Update Extension Files

**Modify**: All `WorkspaceViewModel+*.swift` files:

- `WorkspaceViewModel+Conversation.swift` → Move to `WorkspaceCoordinator`
- `WorkspaceViewModel+State.swift` → Move state observation to `WorkspaceStateObserver`
- `WorkspaceViewModel+Loading.swift` → Move to `WorkspaceCoordinator`
- `WorkspaceViewModel+Errors.swift` → Move to `WorkspaceCoordinator`
- `WorkspaceViewModel+Context.swift` → Move to `WorkspaceCoordinator`
- `WorkspaceViewModel+Bindings.swift` → Move to `WorkspaceStateObserver` or `WorkspaceCoordinator`
- `WorkspaceViewModel+Todos.swift` → Move to `WorkspaceCoordinator`

**Verification**: System compiles; UI behavior identical; no orchestration in presentation model

---

## STEP 4: Replace Polling with Observation (Contradiction 3)

**Purpose**: Replace implicit polling with explicit Combine observation.

### 4.1 Expose Streaming Publisher from WorkspaceProjection

**Modify**: [`UIConnections/Sources/UIConnections/Workspaces/WorkspaceProjection.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspaceProjection.swift)

**Changes**:

- Add `streamingPublisher: AnyPublisher<(UUID, String?), Never>` that publishes changes to `streamingMessages`
- Use Combine to observe changes to `streamingMessages` dictionary
- This is a domain projection, not UI state, so it belongs in WorkspaceProjection

### 4.2 Update ConversationCoordinator

**Modify**: [`UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift`](UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift)

**Changes**:

- Remove `monitorAndForwardStreaming()` polling method
- In `setupStreamingObservation()`: Subscribe to `workspace.streamingPublisher` (or equivalent)
- Filter by `currentStreamingConversationID`
- Forward deltas to `ChatViewModel` via Combine pipeline
- Remove all `Task.sleep()` polling logic

**New approach**:

```swift
private func setupStreamingObservation() {
    guard let workspaceCoord = workspace as? WorkspaceCoordinator else { return }
    
    streamingObservation = workspaceCoord.projection.streamingPublisher
        .filter { [weak self] id, _ in id == self?.currentStreamingConversationID }
        .sink { [weak self] id, text in
            guard let self = self, let viewModel = self.chatViewModel else { return }
            if let text = text {
                viewModel.applyDelta(.assistantStreaming(text))
            } else {
                viewModel.finishStreaming()
            }
        }
}
```

### 4.3 Update stream() Method

**Modify**: [`UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift`](UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift)

**Changes**:

- Remove call to `monitorAndForwardStreaming()`
- Streaming updates now flow automatically via Combine subscription
- Keep fallback response logic but trigger it via timeout or completion observation, not polling

**Verification**: System compiles; streaming works via observation; no polling loops

---

## STEP 5: Centralize Error Authority (Contradiction 4)

**Purpose**: Establish single error authority with proper layer separation. Domain classifies errors; UI routes presentation.

### 5.1 Create ClassifiedError Type

**New file**: [`AppCoreEngine/Sources/CoreEngine/Domain/Errors/ClassifiedError.swift`](AppCoreEngine/Sources/CoreEngine/Domain/Errors/ClassifiedError.swift)

**Content**:

```swift
import Foundation

/// Domain-classified error with severity and intent.
/// Separates error meaning from UI presentation.
public struct ClassifiedError: Sendable, Equatable {
    public enum Severity: Sendable {
        case info
        case warning
        case error
        case critical
    }
    
    public enum Intent: Sendable {
        case userAction
        case contextNotification
        case systemAlert
        case silentLog
    }
    
    public let underlying: Error
    public let severity: Severity
    public let intent: Intent
    public let title: String
    public let message: String
    public let recoverySuggestion: String?
    
    public init(
        underlying: Error,
        severity: Severity,
        intent: Intent,
        title: String,
        message: String,
        recoverySuggestion: String? = nil
    ) {
        self.underlying = underlying
        self.severity = severity
        self.intent = intent
        self.title = title
        self.message = message
        self.recoverySuggestion = recoverySuggestion
    }
}
```

### 5.2 Create DomainErrorAuthority in AppCoreEngine

**New file**: [`AppCoreEngine/Sources/CoreEngine/Services/DomainErrorAuthority.swift`](AppCoreEngine/Sources/CoreEngine/Services/DomainErrorAuthority.swift)

**Content**:

```swift
import Foundation
import Combine

/// Domain authority for error classification.
/// Power: Decisional (classifies errors, assigns severity/intent)
/// Does NOT route to UI - emits ClassifiedError for UI layer.
public final class DomainErrorAuthority: Sendable {
    private let errorSubject = PassthroughSubject<ClassifiedError, Never>()
    
    public var errorPublisher: AnyPublisher<ClassifiedError, Never> {
        errorSubject.eraseToAnyPublisher()
    }
    
    public init() {}
    
    public func classify(_ error: Error, context: String? = nil) -> ClassifiedError {
        // Domain logic to classify errors
        // Assigns severity and intent based on error type and context
        let severity: ClassifiedError.Severity
        let intent: ClassifiedError.Intent
        
        if error is EngineError {
            switch error {
            case EngineError.contextLoadFailed:
                severity = .warning
                intent = .contextNotification
            case EngineError.streamingTransport:
                severity = .error
                intent = .userAction
            default:
                severity = .error
                intent = .systemAlert
            }
        } else {
            severity = .error
            intent = .systemAlert
        }
        
        let title = (error as? LocalizedError)?.errorDescription ?? "Error"
        let message = (error as? LocalizedError)?.failureReason ?? error.localizedDescription
        let recovery = (error as? LocalizedError)?.recoverySuggestion
        
        return ClassifiedError(
            underlying: error,
            severity: severity,
            intent: intent,
            title: title,
            message: message,
            recoverySuggestion: recovery
        )
    }
    
    public func publish(_ error: Error, context: String? = nil) {
        let classified = classify(error, context: context)
        errorSubject.send(classified)
    }
}
```

**Power classification**: Decisional (classifies, does not route)

### 5.3 Create UIPresentationErrorRouter in UIConnections

**New file**: [`UIConnections/Sources/UIConnections/Errors/UIPresentationErrorRouter.swift`](UIConnections/Sources/UIConnections/Errors/UIPresentationErrorRouter.swift)

**Content**:

```swift
import Foundation
import Combine
import AppCoreEngine

/// UI router for error presentation.
/// Power: Decisional (routes classified errors to alerts/banners)
/// Maps domain error classification to UI presentation.
@MainActor
public final class UIPresentationErrorRouter: ObservableObject {
    private let alertCenter: AlertCenter
    private let contextErrorSubject = PassthroughSubject<String, Never>()
    private var cancellable: AnyCancellable?
    
    public var contextErrorPublisher: AnyPublisher<String, Never> {
        contextErrorSubject.eraseToAnyPublisher()
    }
    
    public init(alertCenter: AlertCenter, domainErrorAuthority: DomainErrorAuthority) {
        self.alertCenter = alertCenter
        
        // Subscribe to domain error authority and route based on intent
        cancellable = domainErrorAuthority.errorPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] classified in
                self?.route(classified)
            }
    }
    
    private func route(_ classified: ClassifiedError) {
        switch classified.intent {
        case .userAction, .systemAlert:
            let userError = UserFacingError(
                title: classified.title,
                message: classified.message,
                recoverySuggestion: classified.recoverySuggestion
            )
            alertCenter.publish(userError)
            
        case .contextNotification:
            contextErrorSubject.send(classified.message)
            
        case .silentLog:
            // Log only, no UI presentation
            break
        }
    }
}
```

**Power classification**: Decisional (routes, does not classify)

### 5.4 Update AppContainer

**Modify**: [`AppComposition/Sources/AppComposition/AppContainer.swift`](AppComposition/Sources/AppComposition/AppContainer.swift)

**Changes**:

- Create `DomainErrorAuthority` instance (no dependencies - domain service)
- Create `UIPresentationErrorRouter` instance (depends on `AlertCenter` and `DomainErrorAuthority`)
- Add both to container

### 5.5 Update DependencyContainer

**Modify**: [`AppComposition/Sources/AppComposition/DependencyContainer.swift`](AppComposition/Sources/AppComposition/DependencyContainer.swift)

**Changes**:

- Add `domainErrorAuthority: DomainErrorAuthority` property
- Add `errorRouter: UIPresentationErrorRouter` property
- Update `DefaultContainer` and `TestContainer` to provide both

### 5.6 Remove Error Publishing from Components

**Modify**: All components that publish errors directly:

**Files to update**:

- [`UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Conversation.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Conversation.swift) → Use `DomainErrorAuthority` instead of `alertCenter` and `contextErrorSubject`
- [`UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Errors.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Errors.swift) → Remove, use `DomainErrorAuthority`
- [`UIConnections/Sources/UIConnections/Projects/ProjectCoordinator.swift`](UIConnections/Sources/UIConnections/Projects/ProjectCoordinator.swift) → Use `DomainErrorAuthority` instead of `alertCenter`
- [`UIConnections/Sources/UIConnections/Projects/ProjectSession.swift`](UIConnections/Sources/UIConnections/Projects/ProjectSession.swift) → Use `DomainErrorAuthority` instead of `alertCenter`

**Changes**:

- Remove `alertCenter` and `contextErrorSubject` properties
- Add `domainErrorAuthority: DomainErrorAuthority` dependency
- Replace all `alertCenter?.publish(...)` with `domainErrorAuthority.publish(...)`
- Replace all `contextErrorSubject.send(...)` with `domainErrorAuthority.publish(...)` (router handles routing)
- Domain classifies; router routes to appropriate UI presentation

### 5.7 Update WorkspaceCoordinator

**Modify**: [`UIConnections/Sources/UIConnections/Workspaces/WorkspaceCoordinator.swift`](UIConnections/Sources/UIConnections/Workspaces/WorkspaceCoordinator.swift) (created in Step 3)

**Changes**:

- Use `DomainErrorAuthority` for all error publishing
- Remove direct `AlertCenter` dependency

### 5.8 Update ContextErrorBindingCoordinator

**Modify**: [`AppComposition/Sources/AppComposition/ContextErrorBindingCoordinator.swift`](AppComposition/Sources/AppComposition/ContextErrorBindingCoordinator.swift)

**Changes**:

- Bind to `UIPresentationErrorRouter.contextErrorPublisher` instead of `WorkspaceViewModel.contextErrorPublisher`

### 5.9 Update ChatUIHost

**Modify**: [`AppComposition/Sources/AppComposition/ChatUIHost.swift`](AppComposition/Sources/AppComposition/ChatUIHost.swift)

**Changes**:

- Pass `DomainErrorAuthority` to all coordinators and view models that need it
- Pass `UIPresentationErrorRouter` to `ContextErrorBindingCoordinator`
- Update `ContextErrorBindingCoordinator` to use `UIPresentationErrorRouter`

**Verification**: System compiles; all errors flow through `DomainErrorAuthority` → `UIPresentationErrorRouter`; domain classifies, UI routes; no direct error publishing

---

## Verification Checklist

After each step:

- [ ] System compiles without errors
- [ ] All tests pass (if applicable)
- [ ] Functional behavior is identical
- [ ] No new abstractions introduced
- [ ] Powers are properly separated

After all steps:

- [ ] UI layers can be reasoned about without knowing filesystem exists
- [ ] File mutation can be reasoned about without knowing UI exists
- [ ] Workspace logic can be replayed without UI
- [ ] LLM querying and material mutation are distinct beings
- [ ] Every component has exactly one dominant power

---

## Notes

- **No UIContracts work**: Explicitly forbidden until forms emerge
- **No agent autonomy**: Not yet specified
- **Fractal principle**: Each separation pattern must be repeatable
- **Functional equivalence**: Behavior must remain identical at each step