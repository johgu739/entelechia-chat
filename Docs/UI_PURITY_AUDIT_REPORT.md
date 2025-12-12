# UI PURITY AUDIT REPORT

**Date:** 2024  
**Scope:** ChatUI, UIContracts, UIConnections  
**Auditor Role:** Layer Purity Auditor (diagnosis only)

---

## EXECUTIVE SUMMARY

**VERDICT: FAIL — UI layer separation is cosmetic**

The system violates fundamental layer separation principles. ChatUI has direct knowledge of coordination, workflows, and domain execution. UIContracts contains presentation logic. UIConnections leaks domain types directly into the UI layer.

---

## SECTION 1 — ChatUI Findings

**STATUS: FAIL**

### Critical Violations

#### 1.1 Direct Import of UIConnections
**Location:** Multiple files throughout ChatUI  
**Violation Type:** Architectural boundary violation

ChatUI imports `UIConnections` in 30+ files, violating the declared dependency rule that ChatUI should only depend on UIContracts.

**Affected Files:**
- `ChatUI/Sources/ChatUI/UI/Shell/RootView.swift:15` — `import UIConnections`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:15` — `import UIConnections`
- `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift:15` — `import UIConnections`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatMessagesList.swift:2` — `import UIConnections`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/MessageBubbleContent.swift:2` — `import UIConnections`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatInputBar.swift:2` — `import UIConnections`
- And 24+ additional files

**Impact:** ChatUI cannot be reasoned about without knowing UIConnections internals.

---

#### 1.2 Direct Use of ViewModels from UIConnections
**Location:** Multiple files  
**Violation Type:** Knowledge of coordination

ChatUI directly uses `WorkspaceViewModel` and `ChatViewModel` from UIConnections. These ViewModels contain coordination logic, state management, and domain interaction knowledge.

**Affected Files:**
- `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:20-21`
  ```swift
  @ObservedObject var workspaceViewModel: WorkspaceViewModel
  @ObservedObject var chatViewModel: ChatViewModel
  ```

- `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift:20`
  ```swift
  @ObservedObject var workspaceViewModel: WorkspaceViewModel
  ```

- `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift:43`
  ```swift
  @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
  ```

- `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorView.swift:20`
  ```swift
  @EnvironmentObject var workspaceViewModel: WorkspaceViewModel
  ```

- And 10+ additional files using `WorkspaceViewModel` or `ChatViewModel`

**Impact:** ChatUI knows about ViewModel coordination semantics, not just presentation state.

---

#### 1.3 Direct Use of WorkspaceContext
**Location:** `ChatUI/Sources/ChatUI/UI/Shell/RootView.swift:19`  
**Violation Type:** Knowledge of orchestration structure

```swift
public let context: WorkspaceContext
```

`WorkspaceContext` is a composition object from UIConnections that bundles coordinators, ViewModels, and services. ChatUI receiving this object means it implicitly knows about the orchestration structure.

**Impact:** ChatUI cannot be reasoned about without understanding how UIConnections organizes its components.

---

#### 1.4 Direct Use of Domain Types via UIConnections
**Location:** Multiple files  
**Violation Type:** Domain type leakage

ChatUI uses domain types that are re-exported from UIConnections via `EngineAliases.swift`:

**Affected Types:**
- `Message` (from AppCoreEngine, not UIContracts)
- `Conversation` (from AppCoreEngine, not UIContracts)
- `FileNode` (from UIConnections, which wraps domain types)
- `ContextBuildResult` (from AppCoreEngine)
- `ContextExclusionReason` (from AppCoreEngine)
- `LoadedFile` (from AppCoreEngine)

**Affected Files:**
- `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatMessagesList.swift:5` — `let messages: [Message]`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:144` — `private func reask(_ message: Message)`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:153` — `private func handleMessageContext(_ message: Message)`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatEmptyStateView.swift:5` — `let selectedNode: FileNode?`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextPopoverView.swift:5` — `let context: ContextBuildResult`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextBudgetDiagnosticsView.swift:5` — `let diagnostics: ContextBuildResult`
- `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextBudgetDiagnosticsView.swift:96` — `private func exclusionMessage(for reason: ContextExclusionReason)`
- `ChatUI/Sources/ChatUI/UI/WorkspaceUI/FileRow.swift:72` — `private func reasonMessage(for reason: ContextExclusionReason)`
- `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorRepresentable.swift` — Multiple uses of `FileNode`

**Impact:** ChatUI directly manipulates domain types, not UI-safe forms. This means ChatUI must understand domain semantics.

---

#### 1.5 Async Coordination Logic in ChatUI
**Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:108-151`  
**Violation Type:** Knowledge of workflows and execution

```swift
private func sendMessage() {
    guard let userMessage = chatViewModel.commitMessage() else { return }
    
    Task { @MainActor in
        await chatViewModel.coordinator.stream(userMessage.text, in: conversation)
        
        // Refresh conversation after streaming completes
        if let descriptorID = workspaceViewModel.selectedDescriptorID,
           let refreshed = await workspaceViewModel.conversation(forDescriptorID: descriptorID) {
            conversation = refreshed
            chatViewModel.loadConversation(refreshed)
        } else {
            // ... more coordination logic
        }
    }
}

private func askCodex() {
    chatViewModel.askCodex(conversation: conversation) { updated in
        conversation = updated
    }
}

private func reask(_ message: Message) {
    let text = message.text
    Task { @MainActor in
        chatViewModel.text = text
        let updated = await workspaceViewModel.askCodex(text, for: conversation)
        conversation = updated
    }
}
```

**Impact:** ChatUI contains workflow logic that:
- Knows about streaming coordination
- Makes decisions about conversation refresh strategies
- Understands execution sequencing (stream → refresh → update)
- Interprets outcomes and selects next actions

This is not presentation logic; this is orchestration.

---

#### 1.6 Direct Coordinator Access
**Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:114`  
**Violation Type:** Knowledge of execution mechanism

```swift
await chatViewModel.coordinator.stream(userMessage.text, in: conversation)
```

ChatUI directly accesses `chatViewModel.coordinator`, which is an internal coordination mechanism. This exposes execution details to the presentation layer.

**Impact:** ChatUI knows about coordinators, not just presentation state.

---

#### 1.7 Use of ProjectCoordinator
**Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/OnboardingSelectProjectView.swift:19`  
**Violation Type:** Knowledge of coordination

```swift
@ObservedObject var coordinator: ProjectCoordinator
```

ChatUI directly uses a coordinator, which is a coordination/orchestration concept, not a presentation concept.

**Impact:** ChatUI knows about project opening workflows, not just presentation.

---

### Summary of ChatUI Violations

ChatUI violates purity in the following ways:
1. **Dependency violation:** Imports UIConnections (30+ files)
2. **Coordination knowledge:** Uses ViewModels that contain coordination logic
3. **Domain type leakage:** Uses domain types (Message, Conversation, FileNode, ContextBuildResult, etc.)
4. **Workflow knowledge:** Contains async coordination logic that knows about execution sequencing
5. **Orchestration knowledge:** Uses coordinators and context objects that bundle orchestration components

**Answer to core question:** "Can ChatUI be reasoned about without knowing anything about engines, workflows, or domain execution?"

**Answer: NO.** ChatUI directly imports UIConnections, uses domain types, contains workflow logic, and accesses coordinators.

---

## SECTION 2 — UIContracts Findings

**STATUS: FAIL**

### Violations

#### 2.1 Computed Properties Encoding Presentation Logic
**Location:** Multiple files  
**Violation Type:** Presentation logic in pure forms

UIContracts contains computed properties that encode presentation/display logic, not just data transformation.

**Affected Files:**

**`UIContracts/Sources/UIContracts/NavigatorMode.swift:12`**
```swift
public var icon: String {
    switch self {
    case .project: return "folder"
    case .todos: return "checklist"
    case .search: return "magnifyingglass"
    case .issues: return "exclamationmark.triangle"
    case .tests: return "checkmark.circle"
    case .reports: return "chart.bar"
    }
}
```
**Violation:** Encodes icon selection logic. Icons are presentation concerns, not form concerns.

**`UIContracts/Sources/UIContracts/ContextScopeChoice.swift:10`**
```swift
public var displayName: String {
    switch self {
    case .selection: return "Selection"
    case .workspace: return "Workspace"
    case .selectionAndSiblings: return "Selection + siblings"
    case .manual: return "Manual include…"
    }
}
```
**Violation:** Encodes display name logic. Display names are presentation concerns.

**`UIContracts/Sources/UIContracts/ModelChoice.swift:8`**
```swift
public var displayName: String {
    switch self {
    case .codex: return "Codex"
    case .stub: return "Stub"
    }
}
```
**Violation:** Encodes display name logic.

**`UIContracts/Sources/UIContracts/ContextBuildResult.swift:77`**
```swift
public var description: String {
    switch self {
    case .exceedsPerFileBytes(let limit):
        return "Exceeds per-file bytes limit (\(limit))"
    case .exceedsPerFileTokens(let limit):
        return "Exceeds per-file tokens limit (\(limit))"
    case .exceedsTotalBytes(let limit):
        return "Exceeds total bytes limit (\(limit))"
    case .exceedsTotalTokens(let limit):
        return "Exceeds total tokens limit (\(limit))"
    }
}
```
**Violation:** Encodes error message formatting logic. Error messages are presentation concerns.

---

#### 2.2 Business Logic in Computed Properties
**Location:** `UIContracts/Sources/UIContracts/ProjectTodos.swift:15-37`  
**Violation Type:** Logic beyond pure data

```swift
public var totalCount: Int {
    if !allTodos.isEmpty {
        return allTodos.count
    }
    return missingHeaders.count
    + missingFolderTelos.count
    + filesWithIncompleteHeaders.count
    + foldersWithIncompleteTelos.count
}

public var flatTodos: [String] {
    if !allTodos.isEmpty {
        return allTodos
    }
    
    var todos: [String] = []
    todos.append(contentsOf: missingHeaders.map { "Missing header: \($0)" })
    todos.append(contentsOf: missingFolderTelos.map { "Missing folder telos: \($0)" })
    todos.append(contentsOf: filesWithIncompleteHeaders.map { "Incomplete header: \($0)" })
    todos.append(contentsOf: foldersWithIncompleteTelos.map { "Incomplete folder telos: \($0)" })
    return todos
}
```

**Violation:** These computed properties encode:
1. Business logic (conditional aggregation rules)
2. Presentation formatting (string interpolation with labels like "Missing header:")
3. Decision-making (if-then-else based on data state)

UIContracts should be pure forms. These properties encode "how to present" and "how to aggregate," which are presentation and business concerns, not form concerns.

---

### Summary of UIContracts Violations

UIContracts violates purity in the following ways:
1. **Presentation logic:** Computed properties that encode icon selection, display names, and error message formatting
2. **Business logic:** Computed properties that encode aggregation rules and conditional formatting

**Answer to core question:** "Are UIContracts pure forms without behavior?"

**Answer: NO.** UIContracts contains computed properties that encode presentation logic and business rules.

---

## SECTION 3 — UIConnections Findings

**STATUS: FAIL**

### Violations

#### 3.1 Direct Re-export of Domain Types
**Location:** `UIConnections/Sources/UIConnections/EngineAliases.swift`  
**Violation Type:** Boundary leak

```swift
@_exported import AppCoreEngine

public typealias Conversation = AppCoreEngine.Conversation
public typealias Message = AppCoreEngine.Message
public typealias Attachment = AppCoreEngine.Attachment
public typealias ContentBlock = AppCoreEngine.ContentBlock
public typealias ModelResponse = AppCoreEngine.ModelResponse
public typealias LoadedFile = AppCoreEngine.LoadedFile
public typealias ContextBuildResult = AppCoreEngine.ContextBuildResult
public typealias ContextExclusion = AppCoreEngine.ContextExclusion
public typealias ContextExclusionReason = AppCoreEngine.ContextExclusionReason
public typealias ContextBudget = AppCoreEngine.ContextBudget
public typealias ContextBuilder = AppCoreEngine.ContextBuilder
public typealias TokenEstimator = AppCoreEngine.TokenEstimator
public typealias ConversationDelta = AppCoreEngine.ConversationDelta
public typealias ConversationContextRequest = AppCoreEngine.ConversationContextRequest
public typealias WorkspaceEngine = AppCoreEngine.WorkspaceEngine
public typealias ProjectTodosLoading = AppCoreEngine.ProjectTodosLoading
```

**Violation:** UIConnections re-exports domain types directly, making them available to any module that imports UIConnections. This means:
- ChatUI can import UIConnections and get direct access to domain types
- The boundary between domain and UI is not enforced
- Domain types leak into the UI layer

**Impact:** Domain types escape into ChatUI, violating the separation principle.

---

#### 3.2 Public APIs Exposing Domain Types
**Location:** Multiple files  
**Violation Type:** Incomplete mapping

UIConnections exposes domain types in its public APIs instead of only UIContracts types:

**Affected Files:**

**`UIConnections/Sources/UIConnections/Conversation/ChatViewModel.swift:15`**
```swift
@Published public var messages: [Message] = []
```
Uses domain `Message` type, not `UIContracts.UIMessage`.

**`UIConnections/Sources/UIConnections/Conversation/ChatViewModel.swift:57`**
```swift
public func loadConversation(_ conversation: Conversation) {
```
Uses domain `Conversation` type, not `UIContracts.UIConversation`.

**`UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift:101-102`**
```swift
@Published public var selectedNode: FileNode?
@Published public var rootFileNode: FileNode?
```
Uses `FileNode` from UIConnections (which wraps domain types), not a UIContracts type.

**`UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift:110-111`**
```swift
@Published public var lastContextResult: ContextBuildResult?
@Published public var lastContextSnapshot: ContextSnapshot?
```
Uses domain `ContextBuildResult` type, not `UIContracts.UIContextBuildResult`.

**`UIConnections/Sources/UIConnections/ConversationStreaming.swift:6-7`**
```swift
func conversation(for url: URL) async -> Conversation?
func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation?
```
Uses domain `Conversation` type in public protocol.

**Impact:** ChatUI receives domain types through UIConnections APIs, not UI-safe forms.

---

#### 3.3 Incomplete Domain-to-UI Mapping
**Location:** Throughout UIConnections  
**Violation Type:** Boundary discipline failure

UIConnections should be the **only translator** between domain reality and UI form reality. However:

1. **Domain types are exposed directly** via `EngineAliases.swift`
2. **ViewModels use domain types** in their public APIs instead of UIContracts types
3. **ChatUI receives domain types** through ViewModels and context objects

**Impact:** UIConnections does not fully mediate between domain and UI. Domain types leak through.

---

### Summary of UIConnections Violations

UIConnections violates boundary discipline in the following ways:
1. **Direct re-export:** `EngineAliases.swift` makes domain types available to any importer
2. **Incomplete mapping:** Public APIs expose domain types instead of UIContracts types
3. **Boundary leak:** Domain types escape into ChatUI

**Answer to core question:** "Is UIConnections the only translator between domain reality and UI form reality?"

**Answer: NO.** Domain types leak directly through re-exports and public APIs.

---

## SECTION 4 — Structural Verdict

**VERDICT: FAIL — UI layer separation is cosmetic**

### Blocking Impurities

The following violations prevent the system from achieving true layer separation:

#### Critical Blockers

1. **ChatUI → UIConnections dependency**
   - 30+ files import UIConnections
   - Violates declared architecture (ChatUI should only depend on UIContracts)

2. **Domain type leakage through UIConnections**
   - `EngineAliases.swift` re-exports AppCoreEngine types
   - ViewModels expose domain types in public APIs
   - ChatUI receives domain types, not UI-safe forms

3. **ChatUI contains coordination logic**
   - `ChatView.swift` contains async workflow logic
   - ChatUI accesses coordinators directly
   - ChatUI makes decisions about execution sequencing

4. **UIContracts contains presentation logic**
   - Computed properties encode icon selection, display names, error formatting
   - Business logic in `ProjectTodos` computed properties

5. **ChatUI uses ViewModels with coordination semantics**
   - `WorkspaceViewModel` and `ChatViewModel` contain coordination logic
   - ChatUI cannot be reasoned about without understanding ViewModel behavior

---

### Dependency Direction Reality

**Declared:**
- ChatUI → UIContracts ✓
- UIConnections → UIContracts ✓
- UIConnections → AppCoreEngine ✓

**Actual:**
- ChatUI → UIConnections ✗ (violation)
- ChatUI → AppCoreEngine (via UIConnections re-exports) ✗ (violation)
- ChatUI implicitly depends on UIConnections semantics via ViewModels ✗ (violation)

**Conclusion:** Dependency direction is violated. ChatUI has direct and indirect dependencies on UIConnections and domain types.

---

### Telic Standard Assessment

**ChatUI = appearance**
- ❌ FAIL: Contains coordination logic, workflow knowledge, domain type usage

**UIContracts = form**
- ❌ FAIL: Contains presentation logic and business rules in computed properties

**UIConnections = mediation**
- ❌ FAIL: Leaks domain types directly instead of fully mediating

**Anything else = violation**
- ✅ CONFIRMED: Multiple violations detected

---

## CONCLUSION

The UI layer separation is **cosmetic, not mechanical**. While the package structure suggests separation, the actual code violates fundamental boundaries:

1. ChatUI cannot be reasoned about without knowing UIConnections internals
2. Domain types leak directly into ChatUI
3. ChatUI contains orchestration logic
4. UIContracts contains presentation logic

The system requires architectural changes to achieve true layer separation. The current state allows ChatUI to have knowledge of engines, workflows, and domain execution, violating the core purity requirement.

---

**END OF AUDIT**

