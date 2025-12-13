# DetailState API Specification

## Purpose

`DetailState` is the single coherent state object representing "the current detail" in a navigation → detail view architecture. It owns all detail-scoped ephemeral state and enforces structural invariants that prevent misalignment between selection, context, and other detail facets.

## Ownership Model

**Owner**: `WorkspaceCoordinator` (single instance, replaced on selection change)

**Lifetime**: From selection change to next selection change (or nil selection)

**Identity**: `selectedDescriptorID` (or `nil` for no detail)

## Type Definition

```swift
@MainActor
internal final class DetailState: ObservableObject {
    // MARK: - Detail Identity
    
    /// The identity of this detail (the selected file/folder descriptor).
    /// `nil` means no detail is selected.
    /// This is the primary key that scopes all other detail state.
    @Published public var selectedDescriptorID: UIContracts.FileID?
    
    // MARK: - Detail-Scoped State
    
    /// Context snapshot for this detail (built on send, invalidated on detail change).
    /// `nil` until first send operation completes for this detail.
    @Published public var contextSnapshot: UIContracts.ContextSnapshot?
    
    /// Context build result for this detail (built on send, invalidated on detail change).
    /// `nil` until first send operation completes for this detail.
    @Published public var contextResult: UIContracts.UIContextBuildResult?
    
    /// Streaming messages for conversations in this detail.
    /// Keyed by conversation ID, cleared when detail changes.
    @Published public var streamingMessages: [UUID: String] = [:]
    
    /// Inspector tab selection for this detail.
    /// Reset to default when detail changes.
    @Published public var inspectorTab: UIContracts.InspectorTab = .files
    
    // MARK: - Derived State (not stored, computed on demand)
    
    /// Selected node in the file tree (derived from rootFileNode + selectedDescriptorID).
    /// Computed by: rootFileNode?.findNode(withDescriptorID: selectedDescriptorID)
    var selectedNode: FileNode? {
        // Derived, not stored
    }
    
    // MARK: - Initialization
    
    /// Create a new detail state for the given selection.
    /// Context and inspector state start as nil/default.
    init(selectedDescriptorID: UIContracts.FileID?) {
        self.selectedDescriptorID = selectedDescriptorID
        self.contextSnapshot = nil
        self.contextResult = nil
        self.streamingMessages = [:]
        self.inspectorTab = .files
    }
    
    /// Create an empty detail state (no selection).
    static var empty: DetailState {
        DetailState(selectedDescriptorID: nil)
    }
}
```

## Structural Invariants

### INV-DETAIL-1: Single Detail Identity

**Statement**: At most one `DetailState` exists at a time, identified by `selectedDescriptorID`.

**Enforcement**: `WorkspaceCoordinator` owns a single `DetailState` instance. Selection change replaces it.

**Violation**: Impossible by construction (single instance ownership).

---

### INV-DETAIL-2: Context Scoped to Selection

**Statement**: `contextSnapshot` and `contextResult` exist only if they were built for `selectedDescriptorID`.

**Enforcement**: 
- Context is stored in `DetailState` (same object as selection)
- Selection change = new `DetailState` = old context discarded
- Context cannot outlive its detail

**Violation**: Impossible by construction (same object ownership).

---

### INV-DETAIL-3: Detail Replacement on Selection Change

**Statement**: Selection change replaces `DetailState`, discarding all previous detail state.

**Enforcement**: `WorkspaceStateObserver` detects selection change → `WorkspaceCoordinator.replaceDetailState()` creates new `DetailState` with `nil` context.

**Violation**: Impossible by construction (replacement, not mutation).

---

### INV-DETAIL-4: No Global Detail State

**Statement**: All detail-scoped state is owned by `DetailState`, not stored globally.

**Enforcement**: No global properties for context, streaming, or inspector state. All in `DetailState`.

**Violation**: Impossible by construction (no global storage exists).

---

### INV-DETAIL-5: Context Build for Current Detail

**Statement**: Context is always built for the current `DetailState.selectedDescriptorID`.

**Enforcement**: `WorkspaceCoordinator.sendMessage()` reads from `detailState.selectedDescriptorID` and stores result in `detailState`.

**Violation**: Impossible by construction (single source of truth).

---

## API Surface

### Initialization

```swift
// Create detail for selection
let detail = DetailState(selectedDescriptorID: fileID)

// Create empty detail (no selection)
let empty = DetailState.empty
```

### State Access

```swift
// Read detail identity
let selection = detailState.selectedDescriptorID

// Read context (nil until first send)
let context = detailState.contextSnapshot

// Read streaming (keyed by conversation ID)
let streaming = detailState.streamingMessages[conversationID]

// Read inspector tab
let tab = detailState.inspectorTab
```

### State Mutation (Internal to WorkspaceCoordinator)

```swift
// Set context (after send operation)
detailState.contextSnapshot = snapshot
detailState.contextResult = result

// Update streaming (during message send)
detailState.streamingMessages[conversationID] = text

// Update inspector tab (from UI)
detailState.inspectorTab = .context
```

### Detail Replacement (Internal to WorkspaceCoordinator)

```swift
// Replace detail on selection change
func replaceDetailState(for selection: UIContracts.FileID?) {
    detailState = DetailState(selectedDescriptorID: selection)
    // Old detailState is discarded, all its state is lost
}
```

## Field Mapping: Existing → DetailState

### Fields Moving to DetailState

| Current Location | Field | New Location | Reason |
|------------------|-------|--------------|--------|
| `WorkspacePresentationModel.selectedDescriptorID` | Selection identity | `DetailState.selectedDescriptorID` | Detail identity |
| `WorkspacePresentationModel.selectedNode` | Selected node | `DetailState.selectedNode` (derived) | Detail-scoped, derived |
| `WorkspaceProjection.lastContextSnapshot` | Context snapshot | `DetailState.contextSnapshot` | Detail-scoped context |
| `WorkspaceProjection.lastContextResult` | Context result | `DetailState.contextResult` | Detail-scoped context |
| `WorkspaceProjection.streamingMessages` | Streaming | `DetailState.streamingMessages` | Detail-scoped streaming |
| `MainWorkspaceView.inspectorTab` | Inspector tab | `DetailState.inspectorTab` | Detail-scoped UI state |

### Fields Remaining in WorkspacePresentationModel (Workspace-Level)

| Field | Reason | Scope |
|-------|--------|------|
| `rootFileNode` | Tree structure | Workspace-level (persists across detail changes) |
| `isLoading` | Operation state | Workspace-level (not detail-scoped) |
| `filterText` | Navigator filter | Workspace-level (user preference) |
| `activeNavigator` | Navigator mode | Workspace-level (user preference) |
| `expandedDescriptorIDs` | Tree expansion | Workspace-level (user preference) |
| `projectTodos` | Project metadata | Workspace-level (not detail-scoped) |
| `todosError` | Project error | Workspace-level (not detail-scoped) |
| `activeScope` | Context scope choice | Workspace-level (user preference, not detail-scoped) |
| `modelChoice` | Model choice | Workspace-level (user preference, not detail-scoped) |
| `watcherError` | Workspace error | Workspace-level (not detail-scoped) |

### Fields Remaining in WorkspaceProjection (Domain Projections)

| Field | Reason | Scope |
|-------|--------|------|
| `workspaceState` | Domain projection | Workspace-level (from engine) |

### Fields Remaining in ContextSelectionState (Global Preferences)

| Field | Reason | Scope |
|-------|--------|------|
| `modelChoice` | User preference | Global (not detail-scoped) |
| `scopeChoice` | User preference | Global (not detail-scoped) |

**Note**: `modelChoice` and `scopeChoice` appear in both `WorkspacePresentationModel` and `ContextSelectionState`. This duplication should be resolved (single source of truth in `ContextSelectionState`).

## Pure Derivations

### WorkspaceUIViewState (Derived)

**Source**: `DetailState` + `WorkspacePresentationModel` + `WorkspaceProjection`

```swift
func deriveWorkspaceUIViewState() -> WorkspaceUIViewState {
    WorkspaceUIViewState(
        selectedNode: detailState.selectedNode?.toUIContracts(),
        selectedDescriptorID: detailState.selectedDescriptorID,
        rootFileNode: presentationModel.rootFileNode?.toUIContracts(),
        rootDirectory: projection.workspaceState.rootPath.map { URL(...) },
        projectTodos: presentationModel.projectTodos,
        todosErrorDescription: presentationModel.todosError
    )
}
```

### ContextViewState (Derived)

**Source**: `DetailState` + `WorkspaceCoordinator.codexContextByMessageID` + banner message

```swift
func deriveContextViewState(bannerMessage: String?) -> ContextViewState {
    ContextViewState(
        lastContextSnapshot: detailState.contextSnapshot,
        lastContextResult: detailState.contextResult,
        streamingMessages: detailState.streamingMessages,
        bannerMessage: bannerMessage,
        contextByMessageID: codexContextByMessageID
    )
}
```

### PresentationViewState (Derived)

**Source**: `WorkspacePresentationModel` (unchanged, workspace-level)

```swift
func derivePresentationViewState() -> PresentationViewState {
    PresentationViewState(
        activeNavigator: presentationModel.activeNavigator,
        filterText: presentationModel.filterText,
        expandedDescriptorIDs: presentationModel.expandedDescriptorIDs
    )
}
```

### ChatViewState (Derived)

**Source**: `DetailState` + `ContextSelectionState` + `ConversationEngine`

```swift
func deriveChatViewState(text: String) -> ChatViewState {
    // Messages come from ConversationEngine, not DetailState
    // But model/scope come from preferences
    ChatViewState(
        text: text,
        messages: [], // From ConversationEngine
        streamingText: detailState.streamingMessages[conversationID],
        isSending: presentationModel.isLoading,
        isAsking: false,
        model: contextSelectionState.modelChoice,
        contextScope: contextSelectionState.scopeChoice
    )
}
```

## Lifecycle

### Creation

```swift
// On selection change (WorkspaceStateObserver)
let newSelection = snapshot.selectedDescriptorID
workspaceCoordinator.replaceDetailState(for: newSelection)
```

### Mutation

```swift
// On send message (WorkspaceCoordinator)
detailState.contextSnapshot = buildContextSnapshot(from: result)
detailState.contextResult = toUIContextBuildResult(result)

// On streaming (WorkspaceCoordinator)
detailState.streamingMessages[conversationID] = text

// On inspector tab change (from UI intent)
detailState.inspectorTab = newTab
```

### Replacement

```swift
// On selection change (WorkspaceCoordinator)
func replaceDetailState(for selection: UIContracts.FileID?) {
    // Old detailState is discarded
    // All its state (context, streaming, inspector) is lost
    detailState = DetailState(selectedDescriptorID: selection)
}
```

## Structural Guarantees

### Guarantee 1: Selection-Context Alignment

**By construction**: Selection and context are in the same object (`DetailState`). They cannot be misaligned.

**Proof**: 
- `selectedDescriptorID` and `contextSnapshot` are properties of the same object
- Selection change replaces the object
- Old context is discarded with old object

### Guarantee 2: Context Lifetime

**By construction**: Context cannot outlive its detail.

**Proof**:
- Context is stored in `DetailState`
- Selection change = new `DetailState`
- Old `DetailState` (with context) is discarded
- No global context storage exists

### Guarantee 3: No Stale Context

**By construction**: Stale context cannot appear in UI.

**Proof**:
- Selection change = new `DetailState` with `nil` context
- UI reads from current `DetailState`
- Old context is not accessible
- Context only exists if built for current selection

### Guarantee 4: Single Source of Truth

**By construction**: Selection identity is the single source of truth for detail.

**Proof**:
- `DetailState.selectedDescriptorID` is the only stored selection identity
- All detail-scoped state is keyed by this identity
- Selection change replaces the entire detail state
- No other selection storage exists

## Migration Notes

### WorkspaceStateObserver Changes

**Before**: Updates `WorkspacePresentationModel.selectedDescriptorID`

**After**: Calls `WorkspaceCoordinator.replaceDetailState(for: newSelection)`

**Reason**: Selection change must replace `DetailState`, not mutate it.

### WorkspaceCoordinator Changes

**Before**: Stores context in `WorkspaceProjection.lastContextSnapshot`

**After**: Stores context in `DetailState.contextSnapshot`

**Reason**: Context must be scoped to detail, not global.

### ViewState Derivation Changes

**Before**: Reads from `WorkspacePresentationModel` and `WorkspaceProjection`

**After**: Reads from `DetailState` for detail-scoped state, `WorkspacePresentationModel` for workspace-level state

**Reason**: Clear separation between detail-scoped and workspace-level state.

## Summary

`DetailState` is the single coherent state object for "the current detail". It owns all detail-scoped ephemeral state (selection, context, streaming, inspector) and enforces structural invariants that prevent misalignment. Selection change replaces `DetailState`, ensuring old state cannot leak. View state derivation becomes trivial and safe because all detail state is in one place.
