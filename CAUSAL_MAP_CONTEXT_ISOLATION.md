# Causal Map: Context Isolation Failure

## A. CAUSAL TIMELINE

### Timeline 1: Select File A → Send Message

```
User clicks file A in UI
 → FilesSidebarView/List selection binding changes (selectedFileID)
 → UI emits WorkspaceIntent.selectNode(nodeA)
 → ChatUIHost.onWorkspaceIntent { workspaceCoordinator.handle(intent) }
 → WorkspaceCoordinator.handle(.selectNode(nodeA)) [line 588]
   → Task { await selectPath(URL(...)) } [line 590-591]
     → WorkspaceCoordinator.selectPath(url) [line 446]
       → workspaceEngine.select(path: url.path) [line 449]
         → WorkspaceEngineImpl.select() [async]
           → Emits WorkspaceUpdate via workspaceEngine.updates() stream
 → WorkspaceStateObserver.subscribeToUpdates() receives update [line 35]
   → WorkspaceStateObserver.applyUpdate(update) [line 43]
     → Updates projection.workspaceState.selectedDescriptorID [line 82]
     → Updates presentationModel.selectedDescriptorID [line 91]
     → Updates presentationModel.selectedNode [line 110]
     → ❌ DOES NOT clear projection.lastContextResult
     → ❌ DOES NOT clear projection.lastContextSnapshot
     → Calls onStateUpdated() callback [line 116]
       → ChatUIHost.stateUpdatePublisher.send() [line 88]
         → ChatUIHost.updateViewStates() [line 149]
           → workspaceCoordinator.deriveContextViewState() [line 175]
             → Reads projection.lastContextSnapshot [line 568]
             → Reads projection.lastContextResult [line 569]
             → ❌ STALE context from previous selection (or nil if first time)
             → UI displays stale context

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
             → Context is built and message sent
         → Sets projection.lastContextResult [line 84]
         → Sets projection.lastContextSnapshot [line 85]
         → ChatUIHost.updateViewStates() called [line 198]
           → deriveContextViewState() now reads NEW context
           → UI displays correct context for File A
```

### Timeline 2: Switch to File B (Before Send)

```
User clicks file B in UI
 → FilesSidebarView/List selection binding changes (selectedFileID)
 → UI emits WorkspaceIntent.selectNode(nodeB)
 → WorkspaceCoordinator.handle(.selectNode(nodeB)) [line 588]
   → Task { await selectPath(URL(...)) } [line 590-591]
     → WorkspaceCoordinator.selectPath(url) [line 446]
       → workspaceEngine.select(path: url.path) [line 449]
         → WorkspaceEngineImpl.select() [async]
           → Emits WorkspaceUpdate via workspaceEngine.updates() stream
 → WorkspaceStateObserver.applyUpdate(update) [line 43]
   → Updates projection.workspaceState.selectedDescriptorID [line 82]
   → Updates presentationModel.selectedDescriptorID [line 91]
   → Updates presentationModel.selectedNode [line 110]
   → ❌ DOES NOT clear projection.lastContextResult
   → ❌ DOES NOT clear projection.lastContextSnapshot
   → Calls onStateUpdated() callback [line 116]
     → ChatUIHost.stateUpdatePublisher.send() [line 88]
       → ChatUIHost.updateViewStates() [line 149]
         → workspaceCoordinator.deriveContextViewState() [line 175]
           → Reads projection.lastContextSnapshot [line 568]
           → Reads projection.lastContextResult [line 569]
           → ❌ STILL contains context from File A
           → UI displays STALE context for File A (even though File B is selected)
```

### Timeline 3: Send Message for File B

```
User clicks Send (File B is selected, but context still shows File A)
 → ConversationCoordinator.handle(.sendMessage) [line 95]
   → WorkspaceCoordinator.sendMessage(text, for: conversation) [line 58]
     → Reads presentationModel.selectedDescriptorID [line 75] ✅ NOW File B
     → Sets convo.contextDescriptorIDs = [FileB descriptorID] [line 76]
     → buildContextRequest(for: convo) [line 78]
       → Reads workspaceSnapshot (current) [line 153]
       → Reads conversation.contextDescriptorIDs (File B) [line 154] ✅ CORRECT
       → Returns ConversationContextRequest for File B
     → sendMessageWithContext(...) [line 79]
       → Context is built for File B and message sent
     → Sets projection.lastContextResult [line 84] ✅ NOW File B
     → Sets projection.lastContextSnapshot [line 85] ✅ NOW File B
     → ChatUIHost.updateViewStates() called [line 198]
       → deriveContextViewState() now reads NEW context for File B
       → UI displays correct context for File B
```

## B. PRECISE ROOT CAUSE CLASSIFICATION

### Primary Root Causes:

1. **Missing reset on selection change**
   - **Location**: `WorkspaceStateObserver.applyUpdate()` [line 43-117]
   - **Evidence**: When `updateType == .selectionOnly` [line 157], the observer updates `presentationModel.selectedDescriptorID` and `selectedNode` [lines 91, 110], but does NOT clear `projection.lastContextResult` or `projection.lastContextSnapshot`
   - **Impact**: Stale context persists across selection changes

2. **Context recomputed only on send (lazy evaluation)**
   - **Location**: `WorkspaceCoordinator.sendMessage()` [line 58]
   - **Evidence**: `buildContextRequest()` is called only inside `sendMessage()` [line 78], not when selection changes
   - **Impact**: Context is not available until after first send, and appears "late" in UI

3. **Global mutable context state (not keyed by selection)**
   - **Location**: `WorkspaceProjection.lastContextResult` and `lastContextSnapshot` [WorkspaceProjection.swift:14-15]
   - **Evidence**: These are single global properties, not keyed by `selectedDescriptorID` or file path
   - **Impact**: Only one context can exist at a time, and it persists across selection changes

### Secondary Contributing Factors:

4. **Context bound to conversation instead of selection**
   - **Location**: `WorkspaceCoordinator.sendMessage()` [line 74-77]
   - **Evidence**: Context descriptor IDs are read from `presentationModel.selectedDescriptorID` at send time and written to `conversation.contextDescriptorIDs`, but the context result is stored in global `projection.lastContextResult`, not associated with the conversation or selection
   - **Impact**: Context result is not scoped to the selection that generated it

5. **Incorrect ownership (wrong layer)**
   - **Location**: `WorkspaceProjection` owns context state, but it's not reset by `WorkspaceStateObserver`
   - **Evidence**: `WorkspaceStateObserver` updates `presentationModel` (UI state) but does not reset `projection` (domain projections) when selection changes
   - **Impact**: Context state lives in projection but is not managed by the observer that handles selection updates

## C. EXPLICIT INVARIANT CURRENTLY VIOLATED

**"Context must be a pure function of (current selection × user intent) at send time, and the UI must display context that matches the current selection, not a previous selection."**

**Current violation**: 
- Context displayed in UI (`projection.lastContextSnapshot`) is a function of the last send operation, not the current selection
- When selection changes, context is not recomputed or cleared, violating the invariant that displayed context must match current selection

## D. DETAILED STATE OWNERSHIP AND MUTATION ANALYSIS

### 1. Selection Origin

**Who owns the state**: 
- UI layer: `FilesSidebarView` has `@Binding var selectedFileID`
- Presentation layer: `WorkspacePresentationModel.selectedDescriptorID` and `selectedNode`

**When it mutates**:
- Synchronous: UI binding updates immediately
- Async: `WorkspaceCoordinator.selectPath()` → `workspaceEngine.select()` → `WorkspaceUpdate` stream → `WorkspaceStateObserver.applyUpdate()`

**Reset/replace/append**:
- **REPLACED**: `presentationModel.selectedDescriptorID` is replaced on each selection [WorkspaceStateObserver.swift:91-94]
- **REPLACED**: `presentationModel.selectedNode` is replaced [WorkspaceStateObserver.swift:110, 164-170]

### 2. ContextSelectionState

**Who owns the state**: 
- `ContextSelectionState` (ObservableObject) owned by `ChatUIHost` [ChatUIHost.swift:42, 47]

**When it mutates**:
- Synchronous: When user changes model choice or scope choice via UI controls
- **NOT mutated on selection change**

**Reset/replace/append**:
- **REPLACED**: `modelChoice` and `scopeChoice` are replaced when user changes them
- **NOT keyed by descriptor/file ID**: Single global instance, not per-selection

### 3. WorkspaceCoordinator → Context Derivation

**Who owns the state**:
- `WorkspaceCoordinator.workspaceSnapshot` (private var) [WorkspaceCoordinator.swift:29]
- `WorkspaceProjection.lastContextResult` and `lastContextSnapshot` [WorkspaceProjection.swift:14-15]

**When context gets recomputed**:
- **ONLY on send**: `buildContextRequest()` called inside `sendMessage()` [line 78]
- **NOT on selection**: No context building when `WorkspaceIntent.selectNode` is handled

**Is context derived from**:
- `workspaceSnapshot` (current snapshot) [line 153]
- `conversation.contextDescriptorIDs` (from `presentationModel.selectedDescriptorID` at send time) [line 154]
- `presentationModel.selectedNode?.path` (fallback) [line 155]

**Synchronous or async**:
- **Async**: `buildContextRequest()` is synchronous, but `sendMessageWithContext()` is async [line 79]
- Context is built asynchronously during message send

### 4. ConversationCoordinator

**When handling .send**:
- Reads context from: `WorkspaceCoordinator.sendMessage()` which reads `presentationModel.selectedDescriptorID` at send time [line 75]

**Is context captured**:
- **LAZILY (at send time)**: Context is built only when `sendMessage()` is called
- **NOT eagerly (at selection time)**: No context building when selection changes

**Async gap**:
- **YES**: There is an async gap between selection change and context availability
  - Selection changes → `WorkspaceStateObserver.applyUpdate()` (synchronous state update)
  - Context is NOT built until `sendMessage()` is called (async)
  - During this gap, UI displays stale context from `projection.lastContextSnapshot`

### 5. Persistence / Snapshot Reuse

**Is any of the following reused across selections?**

- **ConversationContextRequest**: 
  - **NO**: Built fresh on each send [line 78]
  - **Location**: `WorkspaceCoordinator.buildContextRequest()` [line 151]

- **ContextBuildResult**:
  - **YES**: `projection.lastContextResult` persists across selections
  - **Location**: `WorkspaceProjection.lastContextResult` [WorkspaceProjection.swift:14]
  - **When cleared**: Only on error [line 342, 347], never on selection change

- **ContextSnapshot**:
  - **YES**: `projection.lastContextSnapshot` persists across selections
  - **Location**: `WorkspaceProjection.lastContextSnapshot` [WorkspaceProjection.swift:15]
  - **When cleared**: Only on error [never explicitly cleared], never on selection change

**Where is the reuse happening**:
- `WorkspaceProjection` stores single global instances of `lastContextResult` and `lastContextSnapshot`
- These are read by `WorkspaceCoordinator.deriveContextViewState()` [line 568-569]
- UI displays these via `ContextViewState` [ChatUIHost.swift:175]
- **No invalidation or clearing when selection changes**

## E. CODE LOCATIONS

### Selection Handling
- **UI Selection**: `ChatUI/Sources/ChatUI/UI/WorkspaceUI/FilesSidebarView.swift:93` (`List(selection: $selectedFileID)`)
- **Intent Emission**: `ChatUIHost.swift:192` (`onWorkspaceIntent`)
- **Intent Handling**: `WorkspaceCoordinator.swift:586-597` (`handle(.selectNode)`)
- **Selection Update**: `WorkspaceCoordinator.swift:446-458` (`selectPath()`)
- **State Observer**: `WorkspaceStateObserver.swift:43-117` (`applyUpdate()`)

### Context State
- **Context Storage**: `WorkspaceProjection.swift:14-15` (`lastContextResult`, `lastContextSnapshot`)
- **Context Building**: `WorkspaceCoordinator.swift:151-158` (`buildContextRequest()`)
- **Context Usage**: `WorkspaceCoordinator.swift:78` (inside `sendMessage()`)
- **Context Display**: `WorkspaceCoordinator.swift:565-574` (`deriveContextViewState()`)

### Missing Reset Points
- **Should clear context but doesn't**: `WorkspaceStateObserver.swift:157` (when `updateType == .selectionOnly`)
- **Should clear context but doesn't**: `WorkspaceStateObserver.swift:90-94` (when `selectedDescriptorID` changes)
