# ChatUI ViewModel Leakage Audit

**Date**: December 2025  
**Status**: 🔴 **CRITICAL VIOLATIONS IDENTIFIED**  
**Invariant**: ChatUI MUST NOT HOLD VIEW MODELS. EVER.

---

## ✅ INVARIANT ACCEPTANCE

I explicitly accept and acknowledge the non-negotiable system invariant:

**ChatUI MUST NOT HOLD VIEW MODELS. EVER.**

This is not stylistic. This is not optional. This is not negotiable.

**Canonical Layer Ownership**:
- **ChatUI**: ❌ NEVER holds ViewModels — Pure projection + intent emission only
- **UIConnections**: ✅ YES — ViewModels, intent handling, mutation
- **AppComposition**: ✅ YES — Wiring, construction, dependency injection

---

## 📋 COMPLETE INVENTORY OF VIOLATIONS

### Category 1: Direct @ObservedObject References

#### VIO-001: ChatView holds 3 ViewModels
**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift`

**Violations**:
```swift
19: @ObservedObject var workspaceStateViewModel: WorkspaceStateViewModel
20: @ObservedObject var workspaceConversationBindingViewModel: WorkspaceConversationBindingViewModel
21: @ObservedObject var chatViewModel: ChatViewModel
```

**Impact**: ChatView directly owns and observes 3 ViewModels from UIConnections.

**Direct Method Calls**:
- Line 47-49: `chatViewModel.messages`, `chatViewModel.streamingText`, `chatViewModel.isSending`
- Line 62: `chatViewModel.loadConversation(current)`
- Line 70: `chatViewModel.loadConversation(current)`
- Line 79: `chatViewModel.contextScope`
- Line 98: `$chatViewModel.text` (Binding to ViewModel property)
- Line 100: `chatViewModel.isSending`, `chatViewModel.isAsking`
- Line 102-103: `chatViewModel.model`, `chatViewModel.selectModel($0)`
- Line 106-107: `chatViewModel.contextScope`, `chatViewModel.selectScope($0)`
- Line 119: `chatViewModel.text = $0` (Direct property mutation)
- Line 125: `chatViewModel.commitMessage()` (Direct mutation method call)
- Line 129: `chatViewModel.startStreaming(...)` (Direct async method call)
- Line 135: `chatViewModel.loadConversation(refreshed)` (Direct mutation method call)
- Line 143: `chatViewModel.loadConversation(refreshed)` (Direct mutation method call)
- Line 150: `chatViewModel.askCodex(...)` (Direct async method call)
- Line 162: `chatViewModel.text = text` (Direct property mutation)

**Property Access**:
- Line 99: `workspaceStateViewModel.selectedNode`
- Line 118: `workspaceStateViewModel.selectedNode`
- Line 132: `workspaceStateViewModel.selectedDescriptorID`
- Line 137: `workspaceStateViewModel.selectedNode?.path`
- Line 78: `workspaceConversationBindingViewModel.lastContextSnapshot`
- Line 133: `workspaceConversationBindingViewModel.conversation(forDescriptorID:)`
- Line 141: `workspaceConversationBindingViewModel.conversation(for:)`
- Line 156: `workspaceConversationBindingViewModel.streamingMessages`
- Line 163: `workspaceConversationBindingViewModel.askCodex(...)`
- Line 169: `workspaceConversationBindingViewModel.contextForMessage(...)`

**Severity**: 🔴 **CRITICAL** — Core chat functionality violates layer boundary.

---

#### VIO-002: MainWorkspaceView holds ViewModel
**File**: `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift`

**Violations**:
```swift
19: @ObservedObject var workspaceStateViewModel: WorkspaceStateViewModel
20: @EnvironmentObject var workspacePresentationViewModel: WorkspacePresentationViewModel
```

**Impact**: MainWorkspaceView owns WorkspaceStateViewModel and receives WorkspacePresentationViewModel via environment.

**Direct Usage**:
- Line 26: `_workspaceStateViewModel = ObservedObject(wrappedValue: context.workspaceStateViewModel)`
- Line 47: `.environmentObject(workspaceStateViewModel)`
- Line 48: `.environmentObject(workspacePresentationViewModel)`
- Line 49: `.environmentObject(context.workspaceActivityViewModel)`
- Line 64: `.environmentObject(workspaceStateViewModel)`
- Line 65: `.environmentObject(context.workspaceActivityViewModel)`
- Line 66: `.environmentObject(context.workspaceConversationBindingViewModel)`
- Line 119: `workspaceStateViewModel.selectedNode`
- Line 121: `workspaceStateViewModel` (passed to ChatView)
- Line 122: `context.workspaceConversationBindingViewModel` (passed to ChatView)
- Line 123: `context.chatViewModelFactory(UUID())` (creates ChatViewModel, passed to ChatView)

**Severity**: 🔴 **CRITICAL** — Root view violates layer boundary and propagates violations.

---

#### VIO-003: ContextInspector holds ViewModels via @EnvironmentObject
**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift`

**Violations**:
```swift
42: @EnvironmentObject var workspaceStateViewModel: WorkspaceStateViewModel
43: @EnvironmentObject var workspaceActivityViewModel: WorkspaceActivityViewModel
44: @EnvironmentObject var workspaceConversationBindingViewModel: WorkspaceConversationBindingViewModel
45: @EnvironmentObject var contextPresentationViewModel: ContextPresentationViewModel
```

**Impact**: ContextInspector receives 4 ViewModels via environment.

**Direct Usage**:
- Line 80: `.onChange(of: workspaceConversationBindingViewModel.lastContextResult)`
- Line 82: `contextPresentationViewModel.clearBanner()` (Direct method call)
- Line 85: `.onChange(of: workspaceStateViewModel.selectedNode?.path)`
- Line 105: `workspaceStateViewModel.selectedNode`
- Line 108: `workspaceConversationBindingViewModel.lastContextResult`
- Line 254: `workspaceConversationBindingViewModel.isPathIncludedInContext(url)`
- Line 256: `workspaceActivityViewModel.setContextInclusion(include, for: url)` (Direct method call)
- Line 285: `workspaceStateViewModel.selectedNode?.isDirectory`

**Severity**: 🔴 **CRITICAL** — Inspector violates layer boundary.

---

#### VIO-004: FilesSidebarView holds ViewModel
**File**: `ChatUI/Sources/ChatUI/UI/WorkspaceUI/FilesSidebarView.swift`

**Violations**:
```swift
19: @ObservedObject var fileViewModel: FileViewModel
```

**Impact**: FilesSidebarView directly owns FileViewModel from UIConnections.

**Severity**: 🔴 **CRITICAL** — Sidebar violates layer boundary.

---

#### VIO-005: OnboardingSelectProjectView holds ViewModel
**File**: `ChatUI/Sources/ChatUI/UI/WorkspaceUI/OnboardingSelectProjectView.swift`

**Violations**:
```swift
19: @ObservedObject var coordinator: ProjectCoordinator
```

**Impact**: Onboarding view holds ProjectCoordinator (which is likely an ObservableObject).

**Severity**: 🔴 **CRITICAL** — Onboarding violates layer boundary.

---

#### VIO-006: AlertPresentationModifier holds ViewModel
**File**: `ChatUI/Sources/ChatUI/UI/Shell/AlertPresentationModifier.swift`

**Violations**:
```swift
6: @ObservedObject var alertCenter: AlertCenter
```

**Impact**: Alert modifier holds AlertCenter (ObservableObject) from UIConnections.

**Severity**: 🔴 **CRITICAL** — Alert system violates layer boundary.

---

### Category 2: @StateObject in ChatUI

#### VIO-007: ContextInspector creates ViewModels
**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift`

**Violations**:
```swift
46: @StateObject private var metadataViewModel = FileMetadataViewModel()
47: @StateObject private var filePreviewViewModel = FilePreviewViewModel()
48: @StateObject private var fileStatsViewModel: FileStatsViewModel
49: @StateObject private var folderStatsViewModel: FolderStatsViewModel
```

**Impact**: ContextInspector creates and owns 4 ViewModels from UIConnections.

**Direct Usage**:
- Line 169: `fileStatsViewModel` (passed to AsyncFileStatsRowView)
- Line 203: `filePreviewViewModel` (passed to AsyncFilePreviewView)
- Line 245: `folderStatsViewModel` (passed to AsyncFolderStatsView)
- Line 277-279: `filePreviewViewModel.clear()`, `fileStatsViewModel.clear()`, `folderStatsViewModel.clear()`
- Line 290: `await folderStatsViewModel.loadStats(for: url)`
- Line 298: `await filePreviewViewModel.loadPreview(for: url)`
- Line 299: `await fileStatsViewModel.loadStats(for: url)`

**Severity**: 🔴 **CRITICAL** — ChatUI creates ViewModels, violating ownership boundary.

---

### Category 3: ViewModels Defined in ChatUI

#### VIO-008: WorkspacePresentationViewModel defined in ChatUI
**File**: `ChatUI/Sources/ChatUI/UI/WorkspaceUI/WorkspacePresentationViewModel.swift`

**Violations**:
```swift
41: public final class WorkspacePresentationViewModel: ObservableObject {
46: @Published public var activeNavigator: NavigatorMode = .project
49: @Published public var filterText: String = ""
52: @Published public var expandedDescriptorIDs: Set<FileID> = []
```

**Impact**: ChatUI defines and owns a ViewModel that should be in UIConnections.

**Usage Locations**:
- `MainView.swift:20` — Received via @EnvironmentObject
- `XcodeNavigatorRepresentable.swift:21` — Received via @EnvironmentObject
- `NavigatorContent.swift:6` — Received via @EnvironmentObject
- `NavigatorModeButton.swift:5` — Received via @EnvironmentObject
- `NavigatorModeBar.swift:5` — Received via @EnvironmentObject
- `NavigatorFilterField.swift:5` — Received via @EnvironmentObject

**Severity**: 🔴 **CRITICAL** — ViewModel defined in wrong layer.

---

#### VIO-009: ContextPresentationViewModel defined in ChatUI
**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextPresentationViewModel.swift`

**Violations**:
```swift
18: public final class ContextPresentationViewModel: ObservableObject {
19: @Published public var bannerMessage: String?
```

**Impact**: ChatUI defines and owns a ViewModel that should be in UIConnections.

**Usage Locations**:
- `ContextInspector.swift:45` — Received via @EnvironmentObject
- `ContextInspector.swift:82` — Direct method call: `clearBanner()`

**Severity**: 🔴 **CRITICAL** — ViewModel defined in wrong layer.

---

### Category 4: EnvironmentObject Propagation

#### VIO-010: EnvironmentObject chain violations
**Files**: Multiple files in ChatUI

**Violations**: ViewModels are passed via `@EnvironmentObject` throughout ChatUI, creating an implicit ownership chain.

**Affected Views**:
- `XcodeNavigatorView` — Receives 3 ViewModels via environment
- `NavigatorContent` — Receives 3 ViewModels via environment
- `NavigatorModeButton` — Receives 2 ViewModels via environment
- `NavigatorModeBar` — Receives 1 ViewModel via environment
- `NavigatorFilterField` — Receives 1 ViewModel via environment
- `OntologyTodosView` — Receives 2 ViewModels via environment
- `ContextInspectorView` — Receives 1 ViewModel via environment
- `ContextInspector` — Receives 4 ViewModels via environment

**Severity**: 🔴 **CRITICAL** — EnvironmentObject is still ViewModel ownership, just indirect.

---

### Category 5: Direct Method Calls on ViewModels

#### VIO-011: Mutation method calls from ChatUI
**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift`

**Direct Mutation Calls**:
- `chatViewModel.commitMessage()` — Line 125
- `chatViewModel.loadConversation(current)` — Lines 62, 70, 135, 143
- `chatViewModel.selectModel($0)` — Line 103
- `chatViewModel.selectScope($0)` — Line 107
- `chatViewModel.startStreaming(...)` — Line 129
- `chatViewModel.askCodex(...)` — Line 150

**Direct Property Mutations**:
- `chatViewModel.text = $0` — Line 119
- `chatViewModel.text = text` — Line 162

**Severity**: 🔴 **CRITICAL** — ChatUI directly mutates ViewModel state.

---

#### VIO-012: Mutation method calls from ContextInspector
**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift`

**Direct Mutation Calls**:
- `contextPresentationViewModel.clearBanner()` — Line 82
- `workspaceActivityViewModel.setContextInclusion(include, for: url)` — Line 256
- `filePreviewViewModel.clear()` — Line 277
- `fileStatsViewModel.clear()` — Line 278
- `folderStatsViewModel.clear()` — Line 279
- `await folderStatsViewModel.loadStats(for: url)` — Line 290
- `await filePreviewViewModel.loadPreview(for: url)` — Line 298
- `await fileStatsViewModel.loadStats(for: url)` — Line 299

**Severity**: 🔴 **CRITICAL** — ChatUI directly mutates ViewModel state.

---

### Category 6: @Binding to ViewModel Properties

#### VIO-013: Binding to ViewModel @Published properties
**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift`

**Violations**:
```swift
98: text: $chatViewModel.text
```

**Impact**: ChatUI creates a Binding directly to a ViewModel's @Published property, creating implicit ownership.

**Severity**: 🔴 **CRITICAL** — Binding to ViewModel property violates layer boundary.

---

### Category 7: Async Method Calls on ViewModels

#### VIO-014: Async method calls from ChatUI
**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift`

**Violations**:
- `await workspaceConversationBindingViewModel.conversation(forDescriptorID:)` — Line 133
- `await workspaceConversationBindingViewModel.conversation(for:)` — Line 141
- `await workspaceConversationBindingViewModel.askCodex(...)` — Line 163
- `await chatViewModel.startStreaming(...)` — Line 129

**Impact**: ChatUI directly calls async methods on ViewModels, creating tight coupling.

**Severity**: 🔴 **CRITICAL** — Async calls violate layer boundary.

---

## 🧩 PROPOSED RE-ANCHORING PLAN

### Phase 1: Extract ViewState Types

**1.1**: Define immutable `ChatViewState` struct in UIConnections
```swift
// UIConnections/Sources/UIConnections/Conversation/ChatViewState.swift
public struct ChatViewState {
    public let text: String
    public let model: ModelChoice
    public let contextScope: ContextScopeChoice
    public let isSending: Bool
    public let isAsking: Bool
    public let messages: [Message]
    public let streamingText: String?
}
```

**1.2**: Define immutable `WorkspaceViewState` struct in UIConnections
```swift
// UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewState.swift
public struct WorkspaceViewState {
    public let selectedNode: FileNode?
    public let selectedDescriptorID: FileID?
    public let rootFileNode: FileNode?
    // ... other read-only state
}
```

**1.3**: Define immutable `ContextViewState` struct in UIConnections
```swift
// UIConnections/Sources/UIConnections/Workspaces/ContextViewState.swift
public struct ContextViewState {
    public let lastContextSnapshot: ContextSnapshot?
    public let lastContextResult: ContextBuildResult?
    public let streamingMessages: [UUID: String]
    public let bannerMessage: String?
}
```

---

### Phase 2: Create Intent Controllers in UIConnections

**2.1**: Create `ChatIntentController` in UIConnections
```swift
// UIConnections/Sources/UIConnections/Conversation/ChatIntentController.swift
@MainActor
public final class ChatIntentController {
    private let viewModel: ChatViewModel
    
    public var viewState: ChatViewState { /* computed from viewModel */ }
    
    public func handle(_ intent: ChatIntent) {
        // sole mutation boundary
    }
}
```

**2.2**: Create `WorkspaceIntentController` in UIConnections
```swift
// UIConnections/Sources/UIConnections/Workspaces/WorkspaceIntentController.swift
@MainActor
public final class WorkspaceIntentController {
    private let stateViewModel: WorkspaceStateViewModel
    private let activityViewModel: WorkspaceActivityViewModel
    private let bindingViewModel: WorkspaceConversationBindingViewModel
    
    public var viewState: WorkspaceViewState { /* computed from viewModels */ }
    
    public func handle(_ intent: WorkspaceIntent) {
        // sole mutation boundary
    }
}
```

**2.3**: Move `WorkspacePresentationViewModel` and `ContextPresentationViewModel` to UIConnections
- These are ViewModels and must be in UIConnections, not ChatUI

---

### Phase 3: Define Intent Types

**3.1**: Define `ChatIntent` enum in UIConnections
```swift
// UIConnections/Sources/UIConnections/Conversation/ChatIntent.swift
public enum ChatIntent {
    case sendMessage(String)
    case askCodex(String)
    case clearText
    case updateText(String)
    case selectModel(ModelChoice)
    case selectScope(ContextScopeChoice)
    case loadConversation(Conversation)
    case streamingDelta(ConversationDelta)
}
```

**3.2**: Define `WorkspaceIntent` enum in UIConnections
```swift
// UIConnections/Sources/UIConnections/Workspaces/WorkspaceIntent.swift
public enum WorkspaceIntent {
    case selectNode(FileNode?)
    case setContextInclusion(Bool, URL)
    case loadFilePreview(URL)
    case loadFileStats(URL)
    case loadFolderStats(URL)
    // ... other workspace intents
}
```

---

### Phase 4: Refactor ChatUI to Use ViewState + Intents

**4.1**: Refactor `ChatView` to receive `ChatViewState` and intent closure
```swift
// ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift
struct ChatView: View {
    let state: ChatViewState
    let workspaceState: WorkspaceViewState
    let contextState: ContextViewState
    let onIntent: (ChatIntent) -> Void
    // NO ViewModels
}
```

**4.2**: Refactor `MainWorkspaceView` to receive ViewState and intent closures
```swift
// ChatUI/Sources/ChatUI/UI/Shell/MainView.swift
struct MainWorkspaceView: View {
    let workspaceState: WorkspaceViewState
    let onWorkspaceIntent: (WorkspaceIntent) -> Void
    // NO ViewModels
}
```

**4.3**: Remove all `@ObservedObject`, `@StateObject`, `@EnvironmentObject` ViewModel references from ChatUI

**4.4**: Replace all ViewModel method calls with intent dispatches
- `chatViewModel.commitMessage()` → `onIntent(.sendMessage(text))`
- `chatViewModel.loadConversation(...)` → `onIntent(.loadConversation(...))`
- `workspaceActivityViewModel.setContextInclusion(...)` → `onWorkspaceIntent(.setContextInclusion(...))`

**4.5**: Replace all ViewModel property access with ViewState property access
- `chatViewModel.messages` → `state.messages`
- `chatViewModel.text` → `state.text`
- `workspaceStateViewModel.selectedNode` → `workspaceState.selectedNode`

---

### Phase 5: Wire in AppComposition

**5.1**: AppComposition creates IntentControllers
```swift
// AppComposition creates:
let chatIntentController = ChatIntentController(viewModel: chatViewModel)
let workspaceIntentController = WorkspaceIntentController(...)
```

**5.2**: AppComposition maps ViewState to ChatUI props
```swift
ChatView(
    state: chatIntentController.viewState,
    workspaceState: workspaceIntentController.viewState,
    contextState: workspaceIntentController.contextState,
    onIntent: { chatIntentController.handle($0) }
)
```

**5.3**: AppComposition observes ViewState changes and updates ChatUI
- IntentControllers publish ViewState changes
- AppComposition observes and re-renders ChatUI with new state

---

### Phase 6: Remove ViewModels from ChatUI Package

**6.1**: Move `WorkspacePresentationViewModel` to UIConnections
**6.2**: Move `ContextPresentationViewModel` to UIConnections
**6.3**: Remove all ViewModel imports from ChatUI
**6.4**: Verify ChatUI has zero references to ObservableObject types from UIConnections

---

## ✅ SUCCESS CRITERIA

After re-anchoring:

1. **Zero ViewModel references in ChatUI**
   - No `@ObservedObject` ViewModels
   - No `@StateObject` ViewModels
   - No `@EnvironmentObject` ViewModels
   - No ViewModel type imports

2. **ChatUI only receives value types**
   - `ChatViewState` (struct)
   - `WorkspaceViewState` (struct)
   - `ContextViewState` (struct)
   - Intent closures: `(ChatIntent) -> Void`

3. **ChatUI only emits intents**
   - All mutations become intent dispatches
   - No direct method calls on ViewModels
   - No property mutations

4. **UIConnections owns all ViewModels**
   - ViewModels are private to IntentControllers
   - IntentControllers are the sole mutation boundary
   - ViewState is computed from ViewModels

5. **AppComposition wires everything**
   - Creates IntentControllers
   - Maps ViewState to ChatUI props
   - Observes ViewState changes

---

## 📊 VIOLATION SUMMARY

| Category | Count | Severity |
|----------|-------|----------|
| Direct @ObservedObject | 6 | 🔴 CRITICAL |
| @StateObject | 1 | 🔴 CRITICAL |
| ViewModels defined in ChatUI | 2 | 🔴 CRITICAL |
| EnvironmentObject propagation | 8+ views | 🔴 CRITICAL |
| Direct method calls | 15+ calls | 🔴 CRITICAL |
| @Binding to ViewModel | 1 | 🔴 CRITICAL |
| Async method calls | 4+ calls | 🔴 CRITICAL |

**Total Violations**: 37+ distinct violation sites

**Status**: 🔴 **SYSTEM-WIDE LAYER COLLAPSE**

---

## 🎯 NEXT STEPS

1. ✅ **AUDIT COMPLETE** — All violations enumerated
2. ⏳ **AWAITING APPROVAL** — Re-anchoring plan ready for review
3. ⏳ **IMPLEMENTATION BLOCKED** — Cannot proceed until layer purity is restored

**Critical Path**: Layer purity restoration must precede intent abstraction implementation. The current correction plan is invalid because it assumes ChatUI can hold ViewModels—this assumption violates the fundamental architectural invariant.



