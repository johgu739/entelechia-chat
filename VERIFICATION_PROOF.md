# Verification Proof: DetailState Architecture

## 1. DetailState Replacement Happens in Exactly One Place

### Proof: Single Replacement Point

**Location**: `WorkspaceStateObserver.applyUpdate()` line 107-109

```swift
let selectionChanged = previousSelection != mapped.selectedDescriptorID
if selectionChanged {
    onDetailReplaced?(newSelection)
}
```

**Verification**:
- ✅ `replaceDetailState` is called **only** when `selectionChanged == true`
- ✅ `selectionChanged` is computed as `previousSelection != mapped.selectedDescriptorID`
- ✅ This is **identity comparison**, not state comparison
- ✅ Only called from `WorkspaceStateObserver.applyUpdate()` (single code path)

### Proof: Not Called on Re-select, Expand/Collapse, or Focus Changes

**Re-select (same selection)**:
- `previousSelection == mapped.selectedDescriptorID` → `selectionChanged == false`
- ✅ `onDetailReplaced` is **not** called

**Expand/Collapse**:
- `WorkspaceIntent.toggleExpanded` → `WorkspaceCoordinator.toggleExpanded()`
- Updates `presentationModel.expandedDescriptorIDs` only
- Does **not** call `workspaceEngine.select()`
- Does **not** trigger `WorkspaceUpdate` with selection change
- ✅ `onDetailReplaced` is **not** called

**Focus Changes**:
- Focus is UI-level, not domain-level
- Does **not** trigger `WorkspaceUpdate`
- ✅ `onDetailReplaced` is **not** called

**Selection Change**:
- `WorkspaceIntent.selectNode` → `WorkspaceCoordinator.selectPath()` → `workspaceEngine.select()`
- Triggers `WorkspaceUpdate` with new `selectedDescriptorID`
- `WorkspaceStateObserver` receives update
- `previousSelection != newSelection` → `selectionChanged == true`
- ✅ `onDetailReplaced` is called

**Conclusion**: DetailState replacement happens **only** on selection identity change, in exactly one place.

---

## 2. No Shadow Selection State Remains

### Proof: Single Source of Truth

**DetailState.selectedDescriptorID** (single source):
- Location: `DetailState.swift:16`
- Type: `let selectedDescriptorID: UIContracts.FileID?` (immutable)
- Owned by: `WorkspaceCoordinator.detailState`

**WorkspaceProjection.workspaceState.selectedDescriptorID** (domain projection, not shadow):
- Location: `WorkspaceProjection.swift:15`
- Type: Part of `WorkspaceViewState` (immutable DTO)
- Purpose: Domain projection from engine, **not** UI state
- Usage: Only for comparison in `WorkspaceStateObserver` to detect changes
- ✅ **Not shadow state** - it's a read-only projection

**WorkspacePresentationModel** (removed):
- ✅ `selectedDescriptorID` removed (was line 24, now deleted)
- ✅ `selectedNode` removed (was line 14, now deleted)

**ChatUI Layer** (no state):
- ✅ No `@State` or `@Published` properties for selection
- ✅ Selection comes from `WorkspaceUIViewState` (derived, not stored)

**AppComposition Layer** (no state):
- ✅ No `@State` or `@Published` properties for selection
- ✅ Selection comes from `deriveWorkspaceUIViewState()` (derived, not stored)

**Conclusion**: No shadow selection state exists. `DetailState.selectedDescriptorID` is the single source of truth.

---

## 3. Workspace-Level Preferences Stayed Workspace-Level

### Proof: Preferences Not in DetailState

**WorkspacePresentationModel** (workspace-level, persists):
- ✅ `filterText: String` (line 16)
- ✅ `activeNavigator: NavigatorMode` (line 17)
- ✅ `expandedDescriptorIDs: Set<FileID>` (line 18)
- ✅ `activeScope: ContextScopeChoice` (line 21)
- ✅ `modelChoice: ModelChoice` (line 22)

**DetailState** (detail-scoped, ephemeral):
- ✅ `contextSnapshot: ContextSnapshot?`
- ✅ `contextResult: UIContextBuildResult?`
- ✅ `streamingMessages: [UUID: String]`
- ✅ `inspectorTab: InspectorTab`
- ✅ **No workspace preferences**

### Proof: Preferences Don't Reset on Detail Change

**DetailState Replacement**:
```swift
func replaceDetailState(for selection: UIContracts.FileID?) {
    detailState = DetailState(selectedDescriptorID: selection)
}
```

**What Gets Reset**:
- ✅ Only `DetailState` properties (context, streaming, inspectorTab)
- ✅ **Not** `WorkspacePresentationModel` properties

**What Persists**:
- ✅ `filterText` - unchanged
- ✅ `activeNavigator` - unchanged
- ✅ `expandedDescriptorIDs` - unchanged (except on root change, line 88)
- ✅ `activeScope` - unchanged
- ✅ `modelChoice` - unchanged

**Root Change Exception** (line 88):
```swift
if previousRoot != mapped.rootPath {
    presentationModel.expandedDescriptorIDs.removeAll()
}
```
- ✅ This is **workspace-level** change (new project), not detail change
- ✅ Correct behavior: new workspace = reset expanded nodes

**Conclusion**: Workspace-level preferences remain workspace-level and do not reset on detail change.

---

## 4. Conversation Identity is Still Orthogonal

### Proof: Conversation Storage Separate from DetailState

**Conversation Storage** (AppCoreEngine):
- Location: `ConversationEngineLive` (line 28: `cache: [UUID: Conversation]`)
- Persistence: `ConversationPersistenceDriver` (disk-backed)
- Keyed by: Conversation ID (UUID), not selection
- ✅ **Not** owned by DetailState

**DetailState** (UIConnections):
- Owns: `contextSnapshot`, `contextResult`, `streamingMessages`, `inspectorTab`
- ✅ **Does not** own conversation history
- ✅ **Does not** own conversation ID

**Conversation Retrieval**:
```swift
func conversation(for url: URL) async -> Conversation
func conversation(forDescriptorIDs ids: [FileID]) async -> Conversation?
```
- ✅ Conversations retrieved from `ConversationEngine`
- ✅ Not from DetailState
- ✅ DetailState only provides `selectedDescriptorID` as input

**Context vs Conversation**:
- **Context**: Built for selection, stored in DetailState (ephemeral)
- **Conversation**: Stored in engine, keyed by ID (persistent)
- ✅ **Orthogonal** - context scopes to detail, conversation scopes to ID

**Conclusion**: Conversation identity is orthogonal to DetailState. Conversations are stored in the engine, not in DetailState. DetailState only scopes context, not conversation history.

---

## Summary

✅ **Criterion 1**: DetailState replacement happens in exactly one place, only on selection identity change

✅ **Criterion 2**: No shadow selection state remains; DetailState.selectedDescriptorID is single source of truth

✅ **Criterion 3**: Workspace-level preferences stayed workspace-level; they don't reset on detail change

✅ **Criterion 4**: Conversation identity is still orthogonal; conversations stored in engine, not DetailState

**All criteria verified and proven.**
