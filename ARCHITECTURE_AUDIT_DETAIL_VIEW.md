# Architecture Audit: Detail View Structure

## 1️⃣ Identify All State Roots

### AppComposition Layer

| File | Type | Owner | Lifetime | Mutation Trigger | Keyed By Selection? |
|------|------|-------|----------|------------------|---------------------|
| `ChatUIHost.swift` | `@State` | `ChatUIHost` (View) | View lifetime | `updateViewStates()` calls | No - global |
| `ChatUIHost.swift:30` | `workspaceUIViewState` | `ChatUIHost` | View lifetime | `workspaceCoordinator.deriveWorkspaceUIViewState()` | No - derived |
| `ChatUIHost.swift:31` | `contextViewState` | `ChatUIHost` | View lifetime | `workspaceCoordinator.deriveContextViewState()` | No - derived |
| `ChatUIHost.swift:32` | `presentationViewState` | `ChatUIHost` | View lifetime | `workspaceCoordinator.derivePresentationViewState()` | No - derived |
| `ChatUIHost.swift:33` | `chatViewState` | `ChatUIHost` | View lifetime | `conversationCoordinator.deriveChatViewState()` | No - derived |
| `ChatUIHost.swift:34` | `bannerMessage` | `ChatUIHost` | View lifetime | `bindingCoordinator.bannerMessagePublisher` | No - global |
| `ChatUIHost.swift:17` | `projectSession` | `ChatUIHost` | View lifetime | Project open/close | No - global |
| `ChatUIHost.swift:19` | `alertCenter` | `ChatUIHost` | View lifetime | Error events | No - global |
| `ChatUIHost.swift:20` | `codexStatusModel` | `ChatUIHost` | View lifetime | Codex status changes | No - global |
| `ChatUIHost.swift:26` | `bindingCoordinator` | `ChatUIHost` | View lifetime | Error publisher binding | No - global |
| `ChatUIHost.swift:42` | `contextSelectionState` | `ChatUIHost` | View lifetime | User model/scope choice | No - global |
| `ContextErrorBindingCoordinator.swift:21` | `bannerMessage` | `ContextErrorBindingCoordinator` | Coordinator lifetime | Error publisher | No - global |

### UIConnections Layer

| File | Type | Owner | Lifetime | Mutation Trigger | Keyed By Selection? |
|------|------|-------|----------|------------------|---------------------|
| `WorkspacePresentationModel.swift` | `ObservableObject` | `WorkspaceCoordinator` | Coordinator lifetime | `WorkspaceStateObserver.applyUpdate()` | Partially |
| `WorkspacePresentationModel.swift:14` | `selectedNode` | `WorkspacePresentationModel` | Coordinator lifetime | Selection change via observer | Yes - current selection |
| `WorkspacePresentationModel.swift:15` | `rootFileNode` | `WorkspacePresentationModel` | Coordinator lifetime | Structural updates | No - global tree |
| `WorkspacePresentationModel.swift:16` | `isLoading` | `WorkspacePresentationModel` | Coordinator lifetime | Send/ask operations | No - global |
| `WorkspacePresentationModel.swift:17` | `filterText` | `WorkspacePresentationModel` | Coordinator lifetime | User input | No - global |
| `WorkspacePresentationModel.swift:18` | `activeNavigator` | `WorkspacePresentationModel` | Coordinator lifetime | User choice | No - global |
| `WorkspacePresentationModel.swift:19` | `expandedDescriptorIDs` | `WorkspacePresentationModel` | Coordinator lifetime | Tree expansion | No - set of IDs |
| `WorkspacePresentationModel.swift:20` | `projectTodos` | `WorkspacePresentationModel` | Coordinator lifetime | Project load | No - global |
| `WorkspacePresentationModel.swift:22` | `activeScope` | `WorkspacePresentationModel` | Coordinator lifetime | User choice | No - global |
| `WorkspacePresentationModel.swift:23` | `modelChoice` | `WorkspacePresentationModel` | Coordinator lifetime | User choice | No - global |
| `WorkspacePresentationModel.swift:24` | `selectedDescriptorID` | `WorkspacePresentationModel` | Coordinator lifetime | Selection change via observer | Yes - current selection |
| `WorkspaceProjection.swift` | `ObservableObject` | `WorkspaceCoordinator` | Coordinator lifetime | Domain updates + send operations | No |
| `WorkspaceProjection.swift:13` | `streamingMessages` | `WorkspaceProjection` | Coordinator lifetime | Message streaming | No - keyed by conversation ID |
| `WorkspaceProjection.swift:14` | `lastContextResult` | `WorkspaceProjection` | Coordinator lifetime | `sendMessage()` completion | No - global, not keyed |
| `WorkspaceProjection.swift:15` | `lastContextSnapshot` | `WorkspaceProjection` | Coordinator lifetime | `sendMessage()` completion | No - global, not keyed |
| `WorkspaceProjection.swift:16` | `workspaceState` | `WorkspaceProjection` | Coordinator lifetime | `WorkspaceStateObserver.applyUpdate()` | Contains selection |
| `WorkspaceCoordinator.swift:29` | `workspaceSnapshot` | `WorkspaceCoordinator` | Coordinator lifetime | Engine updates | Contains selection |
| `WorkspaceCoordinator.swift:30` | `codexContextByMessageID` | `WorkspaceCoordinator` | Coordinator lifetime | Codex ask operations | Yes - keyed by message ID |
| `ContextSelectionState.swift:6` | `modelChoice` | `ContextSelectionState` | App lifetime | User choice | No - global |
| `ContextSelectionState.swift:7` | `scopeChoice` | `ContextSelectionState` | App lifetime | User choice | No - global |
| `ConversationCoordinator.swift:24` | `contextSelection` | `ConversationCoordinator` | Coordinator lifetime | Reference only | No - global |
| `ConversationCoordinator.swift:25` | `codexStatusModel` | `ConversationCoordinator` | Coordinator lifetime | Reference only | No - global |

### ChatUI Layer

| File | Type | Owner | Lifetime | Mutation Trigger | Keyed By Selection? |
|------|------|-------|----------|------------------|---------------------|
| `MainView.swift:29` | `inspectorTab` | `MainWorkspaceView` | View lifetime | User tab selection | No - global UI state |
| `MainView.swift:30` | `columnVisibility` | `MainWorkspaceView` | View lifetime | User layout change | No - global UI state |

### Summary: State Ownership

- **Selection state**: `WorkspacePresentationModel.selectedDescriptorID` and `selectedNode`
- **Context state**: `WorkspaceProjection.lastContextResult` and `lastContextSnapshot` (NOT keyed by selection)
- **Chat state**: Derived from `ConversationCoordinator` (no persistent chat state)
- **Inspector state**: `MainWorkspaceView.inspectorTab` (local UI state)
- **Presentation state**: `WorkspacePresentationModel` (filter, navigator, expanded)

**No single "Detail State" object exists. State is split across:**
- `WorkspacePresentationModel` (selection, UI preferences)
- `WorkspaceProjection` (context, streaming)
- `ContextSelectionState` (model/scope choice)
- `ChatUIHost` @State (derived view states)

---

## 2️⃣ Trace Selection → UI Projection Causally

### Timeline: File Selection → UI Update

```
User clicks file in FilesSidebarView
 → SwiftUI List selection binding updates (selectedFileID)
 → UI emits WorkspaceIntent.selectNode(node)
 → ChatUIHost.onWorkspaceIntent { workspaceCoordinator.handle(intent) }
 → WorkspaceCoordinator.handle(.selectNode(node)) [line 588]
   → Task { await selectPath(URL(...)) } [line 590]
     → WorkspaceCoordinator.selectPath(url) [line 446]
       → workspaceEngine.select(path: url.path) [line 449]
         → WorkspaceEngineImpl.select() [async]
           → Updates WorkspaceState.selectedPath
           → Emits WorkspaceUpdate via workspaceEngine.updates() stream
 → WorkspaceStateObserver.subscribeToUpdates() receives update [line 35]
   → WorkspaceStateObserver.applyUpdate(update) [line 43]
     → Reads previousSelection from projection.workspaceState.selectedDescriptorID [line 49]
     → Maps snapshot to WorkspaceViewState [line 58]
     → Classifies update type [line 68]
     → Updates projection.workspaceState [line 82]
     → Updates presentationModel.selectedDescriptorID [line 91]
     → Updates presentationModel.selectedNode [line 110]
     → ❌ DOES NOT clear projection.lastContextResult
     → ❌ DOES NOT clear projection.lastContextSnapshot
     → Calls onStateUpdated() callback [line 116]
       → ChatUIHost.stateUpdatePublisher.send() [line 88]
         → ChatUIHost.updateViewStates() [line 149]
           → workspaceCoordinator.deriveWorkspaceUIViewState() [line 174]
             → Reads presentationModel.selectedNode [line 556]
             → Reads presentationModel.selectedDescriptorID [line 557]
             → Returns WorkspaceUIViewState
           → workspaceCoordinator.deriveContextViewState() [line 175]
             → Reads projection.lastContextSnapshot [line 568]
             → Reads projection.lastContextResult [line 569]
             → ❌ STALE context from previous selection
             → Returns ContextViewState with stale context
           → conversationCoordinator.deriveChatViewState() [line 177]
           → workspaceCoordinator.derivePresentationViewState() [line 176]
         → Updates @State properties in ChatUIHost [lines 174-177]
 → MainWorkspaceView receives updated view states
   → ChatView displays with stale context
   → ContextInspector displays with stale context
```

### Causal Ordering Analysis

**Selection update path:**
- Selection → `WorkspaceStateObserver` → `WorkspacePresentationModel` → `deriveWorkspaceUIViewState()` → UI
- **Synchronous within observer, async from engine**

**Context display path:**
- Context → `WorkspaceProjection` → `deriveContextViewState()` → UI
- **NOT causally ordered with selection update**
- **Context persists independently of selection**

**Violation:**
- Selection and context updates are **coincidental, not causally ordered**
- Context is not invalidated when selection changes
- UI reads context from projection that may be stale

---

## 3️⃣ Trace Send → Context → UI

### Timeline: Send Message → Context → UI

```
User types message and clicks Send
 → UI emits ChatIntent.sendMessage(text, conversationID)
 → ChatUIHost.onChatIntent { conversationCoordinator.handle(intent) }
 → ConversationCoordinator.handle(.sendMessage) [line 95]
   → ConversationCoordinator.sendMessage(text, conversation) [line 46]
     → workspace.sendMessage(text, for: conversation) [line 47]
       → WorkspaceCoordinator.sendMessage(text, for: conversation) [line 58]
         → Reads presentationModel.selectedDescriptorID [line 75]
         → Sets convo.contextDescriptorIDs = [selectedDescriptorID] [line 76]
         → buildContextRequest(for: convo) [line 78]
           → Reads workspaceSnapshot (current) [line 153]
           → Reads conversation.contextDescriptorIDs (from line 76) [line 154]
           → Reads presentationModel.selectedNode?.path (fallback) [line 155]
           → Returns ConversationContextRequest
         → sendMessageWithContext(...) [line 79]
           → conversationEngine.sendMessage(..., context: contextRequest) [line 166]
             → Context is built asynchronously
             → Message is sent
         → Sets projection.lastContextResult [line 84]
         → Sets projection.lastContextSnapshot [line 85]
         → ChatUIHost.updateViewStates() called [line 198]
           → deriveContextViewState() now reads NEW context
           → UI displays correct context
```

### Context Binding Analysis

**Context construction:**
- **Bound to selection at send time**: Reads `presentationModel.selectedDescriptorID` [line 75]
- **NOT bound to selection in storage**: Stored in global `projection.lastContextResult` [line 84]
- **NOT keyed by selection**: Single global property, not a map

**Context persistence:**
- **Survives selection changes**: `projection.lastContextResult` is never cleared on selection change
- **Cached globally**: Single instance in `WorkspaceProjection`
- **No invalidation**: No mechanism to clear when selection changes

**Context display:**
- UI reads from `projection.lastContextSnapshot` via `deriveContextViewState()` [line 568]
- No validation that context matches current selection
- Stale context can be displayed if selection changed after last send

---

## 4️⃣ Identify "Detail State" (If It Exists)

### Does a single object represent "the current detail"?

**NO.**

### Responsibilities Split Across Objects

| Responsibility | Owner | Location |
|----------------|-------|----------|
| **Current selection** | `WorkspacePresentationModel.selectedDescriptorID` | `WorkspacePresentationModel.swift:24` |
| **Selected node (tree)** | `WorkspacePresentationModel.selectedNode` | `WorkspacePresentationModel.swift:14` |
| **Context for selection** | `WorkspaceProjection.lastContextSnapshot` | `WorkspaceProjection.swift:15` |
| **Context result** | `WorkspaceProjection.lastContextResult` | `WorkspaceProjection.swift:14` |
| **Chat state** | Derived from `ConversationCoordinator` | No persistent state |
| **Inspector tab** | `MainWorkspaceView.inspectorTab` | `MainView.swift:29` |
| **Model/scope choice** | `ContextSelectionState` | `ContextSelectionState.swift:6-7` |
| **Presentation (filter, navigator)** | `WorkspacePresentationModel` | `WorkspacePresentationModel.swift:17-18` |

### Coordination Mechanism

**Procedural coordination, not structural:**
- `WorkspaceStateObserver.applyUpdate()` updates selection state
- `WorkspaceCoordinator.sendMessage()` updates context state
- `ChatUIHost.updateViewStates()` derives view states from multiple sources
- **No single object owns "the detail"**
- **No structural guarantee that selection and context are aligned**

---

## 5️⃣ Invariant Audit

### Implicit Invariants Assumed by UI

| Invariant | Where Assumed | Where Enforced | Enforcement Type |
|-----------|---------------|----------------|------------------|
| **"Context matches selected file"** | `ContextInspector` displays `contextState.lastContextSnapshot` | ❌ NOT enforced | Procedural (violated) |
| **"Inspector reflects current selection"** | `ContextInspector` reads `workspaceState.selectedNode` | ✅ Enforced via observer | Structural (works) |
| **"Switching files switches the whole detail"** | `MainWorkspaceView` shows `ChatView` when `selectedNode != nil` | ⚠️ Partially enforced | Procedural (selection works, context doesn't) |
| **"Context is built for current selection"** | `WorkspaceCoordinator.sendMessage()` reads `selectedDescriptorID` | ✅ Enforced at build time | Procedural (works at send) |
| **"Context is invalidated on selection change"** | UI expects context to clear when selection changes | ❌ NOT enforced | Missing |
| **"Selection and context are causally ordered"** | UI assumes context corresponds to selection | ❌ NOT enforced | Missing |

### Enforcement Analysis

**Structural enforcement (works):**
- Selection update: `WorkspaceStateObserver` updates `presentationModel.selectedDescriptorID` and `selectedNode` atomically
- Inspector selection: Reads from `workspaceState.selectedNode` which is updated by observer

**Procedural enforcement (works at send time):**
- Context building: Reads `selectedDescriptorID` at send time, builds for current selection

**Missing enforcement (violations):**
- Context invalidation: No clearing of `projection.lastContextResult`/`lastContextSnapshot` on selection change
- Context-selection alignment: No validation that displayed context matches current selection
- Causal ordering: Selection and context updates are independent, not causally ordered

---

## 6️⃣ Structural Misalignments

### Misalignment 1: Global Context Leakage

**Name**: Global Context Leakage

**Violated Principle**: Context is relational state bound to selection, not global persistent state

**Responsible Ownership Error**: 
- `WorkspaceProjection.lastContextResult` and `lastContextSnapshot` are global properties
- Not keyed by `selectedDescriptorID`
- Not invalidated when selection changes
- Owned by `WorkspaceProjection` but should be invalidated by `WorkspaceStateObserver`

**Evidence**:
- `WorkspaceProjection.swift:14-15`: Global `@Published` properties
- `WorkspaceStateObserver.swift:43-117`: Updates selection but does not clear context
- `WorkspaceCoordinator.swift:84-85`: Sets context but does not track which selection it's for

---

### Misalignment 2: Split Detail Ownership

**Name**: Split Detail Ownership

**Violated Principle**: Detail view should have single coherent state object

**Responsible Ownership Error**:
- Selection owned by `WorkspacePresentationModel`
- Context owned by `WorkspaceProjection`
- Chat state derived from `ConversationCoordinator`
- Inspector state owned by `MainWorkspaceView`
- No single "DetailState" object coordinates these

**Evidence**:
- `WorkspacePresentationModel`: Owns selection, UI preferences
- `WorkspaceProjection`: Owns context, streaming
- `ChatUIHost`: Derives view states from multiple coordinators
- `MainWorkspaceView`: Owns inspector tab state

---

### Misalignment 3: Procedural Coordination

**Name**: Procedural Coordination

**Violated Principle**: State updates should be causally ordered, not procedurally coordinated

**Responsible Ownership Error**:
- Selection update and context invalidation are separate operations
- `WorkspaceStateObserver` updates selection
- `WorkspaceCoordinator` updates context
- `ChatUIHost` coordinates via `updateViewStates()` calls
- No structural guarantee that selection and context stay aligned

**Evidence**:
- `WorkspaceStateObserver.applyUpdate()`: Updates selection, does not invalidate context
- `WorkspaceCoordinator.sendMessage()`: Updates context, does not validate against selection
- `ChatUIHost.updateViewStates()`: Derives states independently, no validation

---

### Misalignment 4: Missing Causal Chain

**Name**: Missing Causal Chain

**Violated Principle**: Selection change should causally invalidate derived context

**Responsible Ownership Error**:
- Selection change does not trigger context invalidation
- Context persists across selection changes
- UI can display context for wrong selection

**Evidence**:
- `WorkspaceStateObserver.swift:155`: Detects selection change
- `WorkspaceStateObserver.swift:157`: Returns `.selectionOnly` update type
- `WorkspaceStateObserver.swift:90-94`: Updates selection
- **Missing**: Context clearing when `selectionChanged == true`

---

### Misalignment 5: ViewState Derivation Without Validation

**Name**: ViewState Derivation Without Validation

**Violated Principle**: Derived state should validate consistency

**Responsible Ownership Error**:
- `deriveContextViewState()` reads context without checking if it matches current selection
- No validation that `lastContextSnapshot` corresponds to `selectedDescriptorID`
- UI displays whatever context exists, regardless of selection

**Evidence**:
- `WorkspaceCoordinator.swift:566-574`: `deriveContextViewState()` reads `projection.lastContextSnapshot`
- `WorkspaceCoordinator.swift:553-563`: `deriveWorkspaceUIViewState()` reads `presentationModel.selectedDescriptorID`
- **No validation**: No check that context matches selection before returning

---

## Summary

**Architecture Type**: Ad-hoc composition of independently mutating states

**Not**: Navigation → detail view architecture with single detail state

**Key Finding**: No single "Detail State" object exists. State is split across multiple objects with procedural coordination, not structural guarantees.
