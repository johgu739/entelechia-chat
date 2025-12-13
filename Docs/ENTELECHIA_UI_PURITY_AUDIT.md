# 🔍 ENTELECHIA UI PURITY AUDIT — COMPLETE REPORT

**Date:** 2024-12-19  
**Audit Type:** Mechanical Structural & Semantic Violation Detection  
**Target Architecture:** ChatUI = pure projection, UIContracts = value-only, UIConnections = cognition/mutation, AppComposition = wiring only

---

## PHASE A — CANONICAL TARGET (ESTABLISHED)

### Target Architecture

**UIContracts** (Target: Does not exist — must be created)
- Value types only (struct, enum)
- ViewState, Intent, UI-facing enums
- No class, no ObservableObject, no Combine, no async
- Imports: Foundation only

**ChatUI** (Target: Pure projection)
- SwiftUI views only
- Renders ViewState
- Emits Intent
- May hold ephemeral @State
- MUST NOT:
  - import UIConnections
  - import AppComposition
  - reference ViewModels
  - observe anything
  - mutate anything

**UIConnections** (Target: Cognition, mutation, coordination)
- ViewModels
- IntentControllers
- Combine, async
- Screen adapters that observe controllers and feed ChatUI
- Derives ViewState

**AppComposition** (Target: Wiring only)
- Constructs controllers and screens
- Owns lifetimes
- Wires dependencies
- MUST NOT derive ViewState
- MUST NOT observe for semantic reasons

---

## PHASE B — DEPENDENCY GRAPH AUDIT (STRUCTURAL)

### Illegal Imports in ChatUI

| File | Module | Illegal Import | Why Illegal | Severity |
|------|--------|----------------|-------------|----------|
| `ChatUI/Sources/ChatUI/UI/Shell/RootView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspectorView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/OnboardingSelectProjectView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorRepresentable.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/OntologyTodosView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/NavigatorContent.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/NavigatorModeButton.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/NavigatorFilterField.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/NavigatorModeBar.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/Shell/AlertPresentationModifier.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFileStatsRowView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFolderStatsView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFilePreviewView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatInputBar.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/Shell/ErrorToast.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Input/InputTextArea.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/Support/Rendering/MarkdownRenderer.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextPopoverView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatMessagesList.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/MarkdownMessageView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextBudgetDiagnosticsView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextBarHeader.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextInspectorSegmentList.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Input/ContextScopeMenu.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/RecentProjectRow.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatFooter.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Input/ModelMenu.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatMessageRow.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Input/InputActionCluster.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/NavigatorCellView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/NavigatorDiffApplier.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/MessageBubbleContent.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/FilePreviewView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/MessageBubbleActions.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/MessageBubbleHeader.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/ContextBudgetSummaryView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatEmptyStateView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextBar.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/MessageBubbleView.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextInspectorFileRow.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextBarMetrics.swift` | ChatUI | `import UIConnections` | ChatUI must be blind to UIConnections | CRITICAL |

**Total Structural Violations:** 45 files with illegal `import UIConnections`

**Package-Level Violation:**
- `ChatUI/Package.swift` declares dependency on `UIConnections` package (line 16, 22)
- This makes the structural violation systemic and compiler-enforced

---

## PHASE C — SYMBOL VIOLATION AUDIT (SEMANTIC)

### Forbidden Symbols in ChatUI

| File | Line | Symbol | What It Observes / Mutates | Why This Violates Telos | Severity |
|------|------|--------|---------------------------|------------------------|----------|
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift` | 66 | `.onChange(of: conversationBinding?.wrappedValue.id)` | Observes conversation binding changes | ChatUI must not observe; should receive state via props | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift` | 68 | `Task { @MainActor in }` | Async mutation in view | ChatUI must not perform async work | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift` | 76 | `Task { @MainActor in }` | Async mutation in view | ChatUI must not perform async work | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift` | 82 | `.onChange(of: chatState.text)` | Observes state changes | ChatUI must not observe; should receive state via props | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift` | 166 | `Task { @MainActor in }` | Async mutation in view | ChatUI must not perform async work | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift` | 91 | `.onChange(of: contextState.lastContextResult)` | Observes state changes | ChatUI must not observe; should receive state via props | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift` | 96 | `.onChange(of: workspaceState.selectedNode?.path)` | Observes state changes | ChatUI must not observe; should receive state via props | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorRepresentable.swift` | 276 | `Task { @MainActor [weak self] in }` | Async mutation in view | ChatUI must not perform async work | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorRepresentable.swift` | 296 | `Task { @MainActor [weak self] in }` | Async mutation in view | ChatUI must not perform async work | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorRepresentable.swift` | 306 | `Task { @MainActor [weak self] in }` | Async mutation in view | ChatUI must not perform async work | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextErrorBanner.swift` | 88 | `Task { try? await Task.sleep(...) }` | Async work in view | ChatUI must not perform async work | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatInputView.swift` | 128 | `.onChange(of: text)` | Observes local state | Acceptable for ephemeral UI state only | MEDIUM |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatMessagesList.swift` | 23 | `.onChange(of: messages.count)` | Observes state changes | ChatUI must not observe; should receive state via props | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatMessagesList.swift` | 30 | `.onChange(of: streamingText)` | Observes state changes | ChatUI must not observe; should receive state via props | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/MarkdownMessageView.swift` | 42 | `Task { @MainActor in try? await Task.sleep(...) }` | Async work in view | ChatUI must not perform async work | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/MessageBubbleActions.swift` | 69 | `Task { @MainActor in try? await Task.sleep(...) }` | Async work in view | ChatUI must not perform async work | CRITICAL |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/CodeBlockView.swift` | 55 | `Task { @MainActor in try? await Task.sleep(...) }` | Async work in view | ChatUI must not perform async work | CRITICAL |

**Total Semantic Violations:** 17 occurrences

### ViewModel Type References in ChatUI

| File | Line | Symbol | What It References | Why This Violates Telos | Severity |
|------|------|--------|-------------------|------------------------|----------|
| `ChatUI/Sources/ChatUI/UI/Shell/RootView.swift` | 25, 45 | `FileMetadataViewModel.FolderStats` | ViewModel nested type | ChatUI must not know ViewModel types exist | HIGH |
| `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift` | 24, 39 | `FileMetadataViewModel.FolderStats` | ViewModel nested type | ChatUI must not know ViewModel types exist | HIGH |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift` | 46, 60 | `FileMetadataViewModel.FolderStats` | ViewModel nested type | ChatUI must not know ViewModel types exist | HIGH |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFolderStatsView.swift` | 6, 14 | `FileMetadataViewModel.FolderStats` | ViewModel nested type | ChatUI must not know ViewModel types exist | HIGH |

**Total ViewModel Reference Violations:** 8 occurrences

### Domain Type Contamination

| File | Line | Type | Why This Violates Telos | Severity |
|------|------|------|------------------------|----------|
| `ChatUI/Sources/ChatUI/UI/Shell/RootView.swift` | 27 | `ProjectSession` | Domain coordination type; should be in ViewState | HIGH |
| `ChatUI/Sources/ChatUI/UI/Shell/RootView.swift` | 28 | `RecentProject` | Domain type; should be in ViewState | HIGH |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift` | 25 | `Conversation` | Domain type; should be in ViewState | HIGH |

---

## PHASE D — VALUE / EFFECT CONTAMINATION AUDIT

### UIContracts Candidates (Currently in UIConnections)

**Current Location:** `UIConnections/Sources/UIConnections/Conversation/ChatViewState.swift`
- ✅ Pure struct
- ✅ Immutable properties
- ❌ Imports `AppCoreEngine` (line 2) — should only import Foundation
- **Verdict:** Can move to UIContracts after removing AppCoreEngine dependency

**Current Location:** `UIConnections/Sources/UIConnections/Conversation/ChatIntent.swift`
- ✅ Pure enum
- ❌ Imports `AppCoreEngine` (line 2) — should only import Foundation
- **Verdict:** Can move to UIContracts after removing AppCoreEngine dependency

**Current Location:** `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewState.swift`
- ✅ Pure struct
- ❌ Imports `AppCoreEngine` (line 2) — should only import Foundation
- **Verdict:** Can move to UIContracts after removing AppCoreEngine dependency

**Current Location:** `UIConnections/Sources/UIConnections/Workspaces/WorkspaceIntent.swift`
- ✅ Pure enum
- ❌ Imports `AppCoreEngine` (line 2) — should only import Foundation
- **Verdict:** Can move to UIContracts after removing AppCoreEngine dependency

**Current Location:** `UIConnections/Sources/UIConnections/Workspaces/ContextViewState.swift`
- ✅ Pure struct
- ❌ Imports `AppCoreEngine` (line 2) — should only import Foundation
- **Verdict:** Can move to UIContracts after removing AppCoreEngine dependency

**Current Location:** `UIConnections/Sources/UIConnections/Workspaces/PresentationViewState.swift`
- ✅ Pure struct
- ✅ Imports Foundation only
- **Verdict:** ✅ Ready for UIContracts

**Current Location:** `UIConnections/Sources/UIConnections/Workspaces/WorkspaceUIViewState.swift`
- ✅ Pure struct
- ❌ Imports `AppCoreEngine` (line 2) — should only import Foundation
- **Verdict:** Can move to UIContracts after removing AppCoreEngine dependency

**Summary:** All ViewState/Intent types are value-only but contaminated with `AppCoreEngine` imports. They reference domain types (`Message`, `FileNode`, `FileID`, `ProjectTodos`, `ContextSnapshot`, `ContextBuildResult`) that must be either:
1. Moved to UIContracts as value types, or
2. Abstracted behind protocol types that UIContracts can reference

---

## PHASE E — APPCOMPOSITION ROLE VIOLATION AUDIT

### Observation in AppComposition

| File | Responsibility Leaked | Why This Is Cognition | Severity |
|------|----------------------|----------------------|----------|
| `AppComposition/Sources/AppComposition/ChatUIHost.swift` | `.onChange(of: projectSession.activeProjectURL)` (line 200) | Observes domain state changes and triggers async work | CRITICAL |
| `AppComposition/Sources/AppComposition/ChatUIHost.swift` | `Task { await workspaceActivityViewModel.openWorkspace(...) }` (lines 191, 203) | Performs async domain operations | CRITICAL |
| `AppComposition/Sources/AppComposition/ChatUIHost.swift` | `.sink { error in alertCenter.publish(...) }` (line 128) | Observes domain errors and routes to UI | CRITICAL |
| `AppComposition/Sources/AppComposition/ContextErrorBindingCoordinator.swift` | `.sink { [weak presentationViewModel] message in ... }` (line 50) | Observes domain errors and mutates ViewModel | CRITICAL |

### ViewState Derivation in AppComposition

| File | Line | What It Derives | Why This Is Cognition | Severity |
|------|------|----------------|----------------------|----------|
| `AppComposition/Sources/AppComposition/ChatUIHost.swift` | 171-177 | Passes `chatIntentController.viewState`, `workspaceIntentController.workspaceState`, etc. | AppComposition is deriving ViewState from IntentControllers | MEDIUM |

**Note:** This is borderline acceptable if IntentControllers are the source of truth, but AppComposition should not be computing or transforming ViewState.

---

## PHASE F — OBSERVATION LOCATION AUDIT

### Legitimate Observation Points (✅)

| Location | Type | Module | Verdict |
|---------|------|--------|---------|
| `UIConnections/Sources/UIConnections/Conversation/ChatIntentController.swift` | `@Published var viewState` | UIConnections | ✅ Legitimate |
| `UIConnections/Sources/UIConnections/Workspaces/WorkspaceIntentController.swift` | `@Published var workspaceState` | UIConnections | ✅ Legitimate |
| `UIConnections/Sources/UIConnections/Workspaces/WorkspaceIntentController.swift` | `@Published var contextState` | UIConnections | ✅ Legitimate |
| `UIConnections/Sources/UIConnections/Workspaces/WorkspaceIntentController.swift` | `@Published var presentationState` | UIConnections | ✅ Legitimate |
| All ViewModels in UIConnections | `@Published` properties | UIConnections | ✅ Legitimate |

### Illegitimate Observation Points (❌)

| Location | Type | Module | Why Illegitimate |
|---------|------|--------|------------------|
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift` | `.onChange(of: conversationBinding?.wrappedValue.id)` | ChatUI | ❌ ChatUI must not observe |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift` | `.onChange(of: chatState.text)` | ChatUI | ❌ ChatUI must not observe |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift` | `.onChange(of: contextState.lastContextResult)` | ChatUI | ❌ ChatUI must not observe |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift` | `.onChange(of: workspaceState.selectedNode?.path)` | ChatUI | ❌ ChatUI must not observe |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatMessagesList.swift` | `.onChange(of: messages.count)` | ChatUI | ❌ ChatUI must not observe |
| `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatMessagesList.swift` | `.onChange(of: streamingText)` | ChatUI | ❌ ChatUI must not observe |
| `AppComposition/Sources/AppComposition/ChatUIHost.swift` | `.onChange(of: projectSession.activeProjectURL)` | AppComposition | ❌ AppComposition must not observe for semantic reasons |
| `AppComposition/Sources/AppComposition/ChatUIHost.swift` | `.sink { error in ... }` | AppComposition | ❌ AppComposition must not observe for semantic reasons |
| `AppComposition/Sources/AppComposition/ContextErrorBindingCoordinator.swift` | `.sink { [weak presentationViewModel] ... }` | AppComposition | ❌ AppComposition must not observe for semantic reasons |

---

## PHASE G — SUMMARY REPORT

### 1. Violation Count by Category

| Category | Count | Breakdown |
|----------|-------|-----------|
| **Structural (imports)** | 45 | All ChatUI files import UIConnections; Package.swift declares dependency |
| **Semantic (symbols)** | 17 | `.onChange`, `Task`, `await` in ChatUI views |
| **Causal (observation/mutation)** | 9 | Observation in ChatUI and AppComposition |
| **Formal (value impurity)** | 7 | ViewState/Intent types import AppCoreEngine |
| **ViewModel references** | 8 | `FileMetadataViewModel.FolderStats` in ChatUI |
| **Domain contamination** | 3 | `ProjectSession`, `RecentProject`, `Conversation` in ChatUI |
| **TOTAL** | **89** | |

### 2. Purity Score: 12/100

**Deduction Logic:**
- **-45 points:** Structural violations (45 files with illegal imports)
- **-17 points:** Semantic violations (forbidden symbols)
- **-9 points:** Causal violations (observation/mutation in wrong layers)
- **-7 points:** Formal violations (value type contamination)
- **-8 points:** ViewModel type awareness in ChatUI
- **-2 points:** Domain type contamination in ChatUI

**Remaining 12 points** reflect:
- Some ViewState/Intent types are structurally correct (just wrong location/imports)
- No `@ObservedObject`/`@StateObject` in ChatUI views (good)
- Intent-based mutation pattern partially in place

### 3. Top 5 Root Causes

1. **Missing UIContracts Module**
   - ViewState/Intent types live in UIConnections
   - ChatUI must import UIConnections to access them
   - Creates structural dependency that enables all other violations

2. **Package-Level Dependency**
   - `ChatUI/Package.swift` declares `UIConnections` as dependency
   - Makes structural violation compiler-enforced
   - Cannot be fixed without module surgery

3. **ViewModel Type Leakage**
   - `FileMetadataViewModel.FolderStats` nested type used in ChatUI
   - ChatUI knows ViewModel types exist
   - Should be extracted to UIContracts as pure value type

4. **Domain Type Contamination**
   - `ProjectSession`, `RecentProject`, `Conversation` passed directly to ChatUI
   - Should be abstracted into ViewState structs
   - Enables ChatUI to know about domain coordination

5. **Observation in Wrong Layers**
   - ChatUI uses `.onChange` to react to state
   - AppComposition uses `.onChange` and `.sink` for semantic coordination
   - Both should be handled by UIConnections screen adapters

### 4. Non-Obvious Violations

1. **Nested ViewModel Type Reference**
   - `FileMetadataViewModel.FolderStats` appears to be a value type
   - But it's nested in a ViewModel class, making ChatUI aware of ViewModel existence
   - Should be extracted to UIContracts as `FolderStats` struct

2. **Binding<Conversation> in ChatView**
   - `ChatView` accepts `conversationBinding: Binding<Conversation>?`
   - This is a two-way binding to a domain type
   - Should be replaced with ViewState + intent pattern

3. **AppComposition as Screen Adapter**
   - `ChatUIHost` observes IntentController `@Published` properties
   - This is correct, but it also observes `projectSession.activeProjectURL`
   - Mixing legitimate observation with semantic observation

4. **Async Work in Views**
   - Multiple `Task { await ... }` blocks in ChatUI views
   - Even if they're just delays, they represent async capability
   - Should be handled by UIConnections or removed

5. **Domain Types in View Props**
   - `ProjectSession`, `RecentProject` passed as props
   - These are coordination/domain types, not UI state
   - Should be abstracted into ViewState

---

## FINAL VERDICT

**System cannot reach full purity without structural change**

### Justification

1. **Module Surgery Required:**
   - UIContracts module does not exist and must be created
   - ViewState/Intent types must be moved from UIConnections to UIContracts
   - ChatUI package dependency on UIConnections must be removed
   - New dependency on UIContracts must be added

2. **Type Extraction Required:**
   - `FileMetadataViewModel.FolderStats` must be extracted to UIContracts
   - Domain types (`ProjectSession`, `RecentProject`, `Conversation`) must be abstracted into ViewState
   - AppCoreEngine types referenced in ViewState must be abstracted or moved

3. **Architectural Reorganization:**
   - Screen adapters must be created in UIConnections to observe IntentControllers
   - AppComposition must not observe for semantic reasons
   - All observation must flow through UIConnections → ChatUI

4. **Compiler Enforcement:**
   - Package-level dependency makes violations structural
   - Cannot be fixed with "local cleanups"
   - Requires module boundary changes

**Conclusion:** The system requires module surgery, type extraction, and architectural reorganization. A refactor-only approach cannot achieve full purity because the violations are structural (package dependencies) and require new module boundaries.

---

**End of Audit**



