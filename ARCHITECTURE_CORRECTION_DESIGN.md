# Architecture Correction: Detail View Design

## 1️⃣ Root Architectural Flaw

### The Fundamental Wrong Assumption

**The system assumes "detail" is a collection of independently mutating stateful components that are procedurally coordinated.**

**Evidence from audit:**
- Selection state in `WorkspacePresentationModel`
- Context state in `WorkspaceProjection` (global, not keyed)
- Chat state derived from `ConversationCoordinator` (no persistent state)
- Inspector state in `MainWorkspaceView` (local UI)
- No single object owns "the detail"
- Coordination via `ChatUIHost.updateViewStates()` procedural calls

**The wrong mental model:**
- "Detail" = selection widget + context widget + chat widget + inspector widget
- These widgets share some state but operate independently
- Coordination happens procedurally when needed

**Why this is wrong:**
- Selection and context can become misaligned (structural violation)
- No guarantee that all facets show the same "detail"
- Context can persist across selection changes (leakage)
- No structural enforcement of "one detail at a time"

### The Correct Assumption

**"Detail" is a single coherent entity with multiple facets (views), not a collection of independent components.**

**The correct mental model:**
- "Detail" = one selection with all its associated state (context, chat, inspector)
- When you navigate to a detail (select a file), you're viewing one entity
- All facets (chat, inspector, context) are views of the same detail
- Detail state must be structurally coherent (cannot be misaligned)

---

## 2️⃣ Correct Mental Model

### Decision: Option B — Navigation → Single Detail View System

**Rejected: Option A (Independent widgets with shared state)**
- Current system approximates this
- Leads to misalignment (selection vs context)
- No structural guarantees
- Procedural coordination required

**Rejected: Option C (Multiple loosely coupled coordinators)**
- Current system approximates this
- `WorkspaceCoordinator` and `ConversationCoordinator` are loosely coupled
- No single source of truth for "current detail"
- Coordination failures (context leakage)

**Selected: Option B (Navigation → Single Detail View System)**

**Justification:**
- User selects a file → navigates to its detail view
- Detail view has one identity (the selected file/folder)
- All UI facets (chat, inspector, context) are views of that same detail
- Detail state must be structurally bound to selection identity
- Navigation to new detail invalidates previous detail state

**Architectural pattern:**
```
Navigation List → Detail View
  - Detail has identity (selection)
  - Detail has state (context, chat, inspector)
  - Detail state is scoped to identity
  - Navigation change = new detail = new state
```

**Key principle:**
- **One detail at a time**
- **Detail state is scoped to selection identity**
- **Navigation change invalidates previous detail state**
- **All facets view the same detail**

---

## 3️⃣ Correct "Detail State" Definition

### Should there be one DetailState object?

**YES.**

### Identity

**Detail identity = `selectedDescriptorID` (or `nil` for no selection)**

- Detail is identified by the selected file/folder descriptor
- `nil` selection = no detail (empty state)
- Selection change = navigation to new detail

### Ownership Table

| Responsibility | Owned By | Stored vs Derived | Ephemeral vs Persistent | Keyed By Selection? |
|----------------|----------|-------------------|-------------------------|---------------------|
| **Detail identity** | DetailState | Stored | Persistent (until selection changes) | N/A (is the key) |
| **Selected node (tree)** | DetailState | Derived | Ephemeral (derived from tree) | Yes |
| **Context snapshot** | DetailState | Stored | Ephemeral (invalidated on selection change) | Yes |
| **Context result** | DetailState | Stored | Ephemeral (invalidated on selection change) | Yes |
| **Streaming messages** | DetailState | Stored | Ephemeral (per conversation) | Yes (by conversation ID) |
| **Model/scope choice** | DetailState | Stored | Persistent (user preference, not detail-scoped) | No (global preference) |
| **Inspector tab** | DetailState | Stored | Ephemeral (UI state for this detail) | Yes |
| **Chat messages** | Not owned | Derived | Ephemeral (from conversation engine) | Yes (by conversation) |
| **Presentation (filter, navigator)** | Not owned | Stored | Persistent (workspace-level, not detail-scoped) | No |

### What Must Be Derived, Not Stored

| Derived | Source | When |
|---------|--------|------|
| `selectedNode` | `rootFileNode.findNode(selectedDescriptorID)` | On selection change |
| `ChatViewState.messages` | `ConversationEngine.conversation(for: selectedDescriptorID)` | On view derivation |
| `WorkspaceUIViewState` | `DetailState` + `WorkspacePresentationModel` (presentation) | On view derivation |

### Ephemeral vs Persistent

**Ephemeral (scoped to detail, invalidated on selection change):**
- Context snapshot
- Context result
- Streaming messages
- Inspector tab

**Persistent (workspace-level, not detail-scoped):**
- Model/scope choice (user preference)
- Filter text
- Active navigator
- Expanded descriptor IDs
- Root file node (tree structure)

**Key insight:**
- Detail state = selection + detail-scoped ephemeral state
- Workspace state = persistent preferences + tree structure
- Detail state is invalidated on navigation (selection change)
- Workspace state persists across navigation

---

## 4️⃣ Re-established Invariants (Structural)

### Invariant 1: Selection ↔ Context Alignment

**Statement**: Context must always correspond to the current detail identity (selection).

**Who enforces**: `DetailState` (structural ownership)

**When enforced**: 
- On selection change: Context is cleared (structural invalidation)
- On context storage: Context is stored with selection identity (structural binding)
- On context retrieval: Context is only returned if it matches current selection (structural validation)

**Why cannot be violated structurally**:
- Context is owned by `DetailState`
- `DetailState` is identified by `selectedDescriptorID`
- Selection change creates new `DetailState` (or clears it)
- Context cannot exist without matching selection identity

**Enforcement mechanism**:
- `DetailState` owns both `selectedDescriptorID` and `contextSnapshot`
- Selection change = new `DetailState` instance (or clearing)
- Context stored in `DetailState` is structurally bound to its identity

---

### Invariant 2: Context Lifetime

**Statement**: Context exists only for the detail that generated it, and is invalidated when detail changes.

**Who enforces**: `DetailState` lifecycle (structural)

**When enforced**:
- On detail creation: Context is `nil`
- On detail change: Previous detail's context is discarded
- On send: Context is stored in current `DetailState`
- On context read: Only current `DetailState`'s context is returned

**Why cannot be violated structurally**:
- Context is stored in `DetailState`
- `DetailState` is replaced/cleared on selection change
- No global context storage exists
- Context cannot outlive its detail

**Enforcement mechanism**:
- `DetailState` is the sole owner of context
- Selection change = `DetailState` replacement
- Old `DetailState` (with context) is discarded
- New `DetailState` has `nil` context

---

### Invariant 3: Inspector Correctness

**Statement**: Inspector always reflects the current detail, not a previous one.

**Who enforces**: `DetailState` (structural ownership of inspector state)

**When enforced**:
- On detail change: Inspector state is reset
- On inspector update: State is stored in current `DetailState`
- On inspector read: Only current `DetailState`'s inspector state is returned

**Why cannot be violated structurally**:
- Inspector state (tab selection) is owned by `DetailState`
- `DetailState` is replaced on selection change
- Inspector state cannot persist across detail changes

**Enforcement mechanism**:
- `DetailState` owns `inspectorTab`
- Selection change = new `DetailState` with default inspector state
- Old inspector state is discarded with old `DetailState`

---

### Invariant 4: Chat/Context Causality

**Statement**: Chat operations (send) use context built for the current detail, and context is stored in the current detail.

**Who enforces**: `DetailState` + `WorkspaceCoordinator` (structural binding)

**When enforced**:
- On send: Context is built for current `DetailState.selectedDescriptorID`
- On context storage: Context is stored in current `DetailState`
- On context read: Only current `DetailState`'s context is returned

**Why cannot be violated structurally**:
- `WorkspaceCoordinator.sendMessage()` reads from current `DetailState.selectedDescriptorID`
- Context is stored in current `DetailState`
- No global context storage exists
- Context cannot be built for one detail and stored in another

**Enforcement mechanism**:
- `DetailState` is the single source of truth for current selection
- `WorkspaceCoordinator` reads selection from `DetailState`
- Context is stored in `DetailState` (not global projection)
- Structural binding: selection and context in same object

---

### Invariant 5: Navigation Semantics

**Statement**: Navigation to a new detail invalidates all state from the previous detail.

**Who enforces**: `DetailState` lifecycle (structural replacement)

**When enforced**:
- On selection change: Previous `DetailState` is replaced/cleared
- On new detail: New `DetailState` is created with `nil` context
- On detail access: Only current `DetailState` is accessible

**Why cannot be violated structurally**:
- Only one `DetailState` exists at a time (current detail)
- Selection change = `DetailState` replacement
- Previous `DetailState` is not accessible
- No state can persist from previous detail

**Enforcement mechanism**:
- `DetailState` is owned by `WorkspaceCoordinator` (single instance)
- Selection change = `DetailState` replacement
- Old `DetailState` is discarded
- New `DetailState` has no context (until send)

---

## 5️⃣ Map Current Code to Correct Model

### Objects That Are Wrongly Split

| Current Object | Responsibility | Correct Owner | Action |
|----------------|----------------|---------------|--------|
| `WorkspacePresentationModel.selectedDescriptorID` | Selection identity | `DetailState` | Move to `DetailState` |
| `WorkspacePresentationModel.selectedNode` | Selected node | `DetailState` (derived) | Derive in `DetailState` |
| `WorkspaceProjection.lastContextResult` | Context result | `DetailState` | Move to `DetailState` |
| `WorkspaceProjection.lastContextSnapshot` | Context snapshot | `DetailState` | Move to `DetailState` |
| `MainWorkspaceView.inspectorTab` | Inspector tab | `DetailState` | Move to `DetailState` |
| `WorkspaceProjection.streamingMessages` | Streaming | `DetailState` | Move to `DetailState` |

### Objects That Should Be Merged Conceptually

| Current Objects | Conceptual Merge | Result |
|-----------------|------------------|--------|
| `WorkspacePresentationModel` (selection) + `WorkspaceProjection` (context) | Detail-scoped state | `DetailState` |
| Selection identity + context + inspector | All detail-scoped state | `DetailState` |

### Objects That Should Become Pure Derivations

| Current Object | Should Become | Source |
|----------------|---------------|--------|
| `WorkspaceUIViewState` | Derived | `DetailState` + `WorkspacePresentationModel` (presentation) |
| `ContextViewState` | Derived | `DetailState` |
| `ChatViewState` | Derived | `DetailState` + `ConversationEngine` |

### Responsibilities That Must Move

| Responsibility | Current Location | Correct Location | Reason |
|----------------|------------------|-----------------|--------|
| Selection identity | `WorkspacePresentationModel` | `DetailState` | Detail identity |
| Context storage | `WorkspaceProjection` | `DetailState` | Detail-scoped state |
| Inspector tab | `MainWorkspaceView` | `DetailState` | Detail-scoped UI state |
| Streaming messages | `WorkspaceProjection` | `DetailState` | Detail-scoped state |

### Objects That Remain (Correctly Scoped)

| Object | Responsibility | Scope | Correct? |
|--------|----------------|-------|----------|
| `WorkspacePresentationModel` | Presentation preferences (filter, navigator, expanded) | Workspace-level | ✅ Yes |
| `ContextSelectionState` | Model/scope choice | Global user preference | ✅ Yes |
| `WorkspaceProjection.workspaceState` | Domain projection (tree, selection from engine) | Workspace-level | ✅ Yes |
| `WorkspaceCoordinator.workspaceSnapshot` | Engine snapshot | Workspace-level | ✅ Yes |

---

## 6️⃣ Minimal Structural Correction Plan

### Constraint Compliance

✅ **No new ViewModels**: `DetailState` is not a ViewModel; it's a state container in UIConnections
✅ **No fixes in ChatUI**: All changes in UIConnections layer
✅ **No "clear on selection" band-aids**: Structural ownership ensures invalidation
✅ **No procedural coordination via ChatUIHost**: Structural binding in `DetailState`
✅ **No breaking public APIs**: `DetailState` is internal to UIConnections

### Correction Plan

#### Step 1: Create DetailState (UIConnections)

**File**: `UIConnections/Sources/UIConnections/Workspaces/DetailState.swift`

**Purpose**: Single coherent state object for current detail

**Owns**:
- `selectedDescriptorID: FileID?` (detail identity)
- `contextSnapshot: ContextSnapshot?` (detail-scoped context)
- `contextResult: UIContextBuildResult?` (detail-scoped context result)
- `streamingMessages: [UUID: String]` (detail-scoped streaming)
- `inspectorTab: InspectorTab` (detail-scoped inspector state)

**Lifecycle**:
- Created/cleared on selection change
- Replaced when selection changes
- Owned by `WorkspaceCoordinator`

#### Step 2: Move Selection to DetailState

**File**: `WorkspacePresentationModel.swift`

**Change**: Remove `selectedDescriptorID` and `selectedNode`

**File**: `DetailState.swift`

**Change**: Add `selectedDescriptorID` and derive `selectedNode` from tree

**File**: `WorkspaceStateObserver.swift`

**Change**: Update `DetailState` instead of `WorkspacePresentationModel.selectedDescriptorID`

#### Step 3: Move Context to DetailState

**File**: `WorkspaceProjection.swift`

**Change**: Remove `lastContextResult` and `lastContextSnapshot`

**File**: `DetailState.swift`

**Change**: Add `contextResult` and `contextSnapshot`

**File**: `WorkspaceCoordinator.swift`

**Change**: Store context in `DetailState` instead of `WorkspaceProjection`

#### Step 4: Move Inspector State to DetailState

**File**: `MainWorkspaceView.swift` (ChatUI)

**Change**: Remove `@State private var inspectorTab`

**File**: `DetailState.swift`

**Change**: Add `inspectorTab: InspectorTab`

**File**: `ChatUIHost.swift` (AppComposition)

**Change**: Pass `detailState.inspectorTab` to `MainWorkspaceView`

**Note**: This violates "No fixes in ChatUI" constraint. Alternative: Keep inspector tab in ChatUI but make it detail-scoped via binding from `DetailState`.

#### Step 5: Move Streaming to DetailState

**File**: `WorkspaceProjection.swift`

**Change**: Remove `streamingMessages`

**File**: `DetailState.swift`

**Change**: Add `streamingMessages: [UUID: String]`

**File**: `WorkspaceCoordinator.swift`

**Change**: Store streaming in `DetailState` instead of `WorkspaceProjection`

#### Step 6: Update ViewState Derivation

**File**: `WorkspaceCoordinator.swift`

**Change**: `deriveWorkspaceUIViewState()` reads from `DetailState` instead of `WorkspacePresentationModel`

**Change**: `deriveContextViewState()` reads from `DetailState` instead of `WorkspaceProjection`

**Change**: `derivePresentationViewState()` reads from `WorkspacePresentationModel` (unchanged, workspace-level)

#### Step 7: Enforce Structural Invalidation

**File**: `WorkspaceStateObserver.swift`

**Change**: On selection change, replace `DetailState` (not just update fields)

**Mechanism**:
- `WorkspaceCoordinator` owns `DetailState`
- `WorkspaceStateObserver` detects selection change
- `WorkspaceStateObserver` calls `WorkspaceCoordinator.replaceDetailState(newSelection)`
- `WorkspaceCoordinator` creates new `DetailState` with `nil` context
- Old `DetailState` is discarded

**Structural guarantee**: Selection change = new `DetailState` = no context from previous detail

### Minimal Change Summary

**New files**: 1 (`DetailState.swift`)

**Modified files**:
- `WorkspacePresentationModel.swift` (remove selection)
- `WorkspaceProjection.swift` (remove context, streaming)
- `WorkspaceCoordinator.swift` (own `DetailState`, update derivation)
- `WorkspaceStateObserver.swift` (update `DetailState` on selection change)
- `MainWorkspaceView.swift` (receive inspector tab from state, or keep local with binding)

**No changes to**:
- ChatUI (except inspector tab binding, if needed)
- UIContracts (immutable DTOs unchanged)
- AppCoreEngine (domain unchanged)

### Structural Guarantees

After correction:
1. ✅ **Selection and context in same object**: `DetailState` owns both
2. ✅ **Selection change = new DetailState**: Old context discarded structurally
3. ✅ **Context cannot outlive detail**: `DetailState` lifecycle enforces this
4. ✅ **No global context storage**: All context in `DetailState`
5. ✅ **Structural alignment**: Cannot have context for wrong selection (same object)

---

## Summary

**Root flaw**: System treats "detail" as collection of independent components, not single coherent entity.

**Correct model**: Navigation → Single Detail View system with `DetailState` as coherent state object.

**Correction**: Create `DetailState` that owns all detail-scoped state (selection, context, inspector, streaming). Selection change = new `DetailState` = structural invalidation of previous detail state.

**Structural guarantees**: Selection and context in same object, selection change replaces object, no global context storage, cannot be misaligned by construction.
