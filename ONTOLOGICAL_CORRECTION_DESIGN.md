# Ontological Correction: Context Scoping & Invariant Restoration

## 1. Ontological Correction (Conceptual)

### What is context, ontologically?

**Context is an ephemeral artifact of a (selection × send) operation.**

Context is NOT:
- A property of the workspace (workspace is the file tree structure)
- A property of the conversation (conversation is message history)
- Global state that persists across selection changes

Context IS:
- A property of the (selection × intent) pair at the moment of send
- The result of building context FOR a specific selection at a specific point in time
- Relational state: it exists only in relation to the selection that generated it

### Who owns context state?

**Current (incorrect) ownership:**
- `WorkspaceProjection` owns `lastContextResult` and `lastContextSnapshot`
- These are treated as persistent projections of domain state

**Correct ownership:**
- `WorkspaceProjection` may store context, but it must be scoped to the selection that generated it
- Context is owned by the (selection × send) operation that created it
- When selection changes, any stored context becomes invalid and must be cleared

### When must it be invalidated?

**Context must be invalidated when:**
1. Selection changes (primary): Any context built for a previous selection is invalid
2. Workspace structure changes (secondary): Files may have changed, making context stale

### When may it persist?

**Context may persist only when:**
- Selection has not changed since the context was built
- AND the context was built for the current selection
- Since context is built lazily (only on send), it may persist between sends if selection hasn't changed

**Explicit definition:**

Context is a transient artifact representing "what context was used for the last send operation." It is valid only for the selection that generated it. When selection changes, context must be invalidated because it no longer corresponds to the current selection. Context is not global state; it is relational state bound to a specific selection.

---

## 2. Invariant Set (Executable Rules)

### Selection Invariants

**INV-SEL-1**: On any selection change, all context derived from a previous selection must be invalidated before UI derivation.

**INV-SEL-2**: Selection change is detected when `projection.workspaceState.selectedDescriptorID` changes from previous value to new value.

**INV-SEL-3**: Selection change triggers immediate context invalidation (synchronous with selection update).

### Context Lifecycle Invariants

**INV-CTX-1**: Context (`lastContextResult`, `lastContextSnapshot`) may only exist if it was built for the current selection.

**INV-CTX-2**: Context must be cleared when selection changes (before any UI reads the new selection state).

**INV-CTX-3**: Context is built lazily (only on send), not eagerly (not on selection change).

**INV-CTX-4**: Context is stored in `WorkspaceProjection` but is invalidated by `WorkspaceStateObserver` when selection changes.

### UI Display Invariants

**INV-UI-1**: `deriveContextViewState()` must never return context that corresponds to a different selection than the current one.

**INV-UI-2**: When selection changes, UI must immediately show `nil` context (or empty context) until a new send operation completes.

**INV-UI-3**: Context displayed in UI must always match `presentationModel.selectedDescriptorID` at the time the context was built.

### Enforcement Rules

**RULE-1**: In `WorkspaceStateObserver.applyUpdate()`, when `previousSelection != newSelection` (selection changed), set `projection.lastContextResult = nil` and `projection.lastContextSnapshot = nil` before calling `onStateUpdated()`.

**RULE-2**: Context clearing must occur synchronously with selection update, in the same `applyUpdate()` call, before any reactive updates.

**RULE-3**: No additional state tracking is required; clearing on selection change is sufficient because context is only built for the current selection at send time.

---

## 3. Minimal Code-Level Fix (Surgical)

### Change Set

#### File: `UIConnections/Sources/UIConnections/Workspaces/WorkspaceStateObserver.swift`

**Location**: `applyUpdate()` method, after selection update and before `onStateUpdated()`

**Exact change**:

After line 94 (where `presentationModel.selectedDescriptorID` is updated), add context invalidation:

```swift
if let uuid = mapped.selectedDescriptorID {
    presentationModel.selectedDescriptorID = UIContracts.FileID(uuid)
} else {
    presentationModel.selectedDescriptorID = nil
}

// INVARIANT: Context invalidation on selection change
// Context is relational state bound to a specific selection.
// When selection changes, any context built for the previous selection is invalid.
let selectionChanged = previousSelection != mapped.selectedDescriptorID?.rawValue
if selectionChanged {
    projection.lastContextResult = nil
    projection.lastContextSnapshot = nil
}
```

**Reason**: Selection change invalidates derived context. Context must be cleared synchronously with selection update to prevent UI from displaying stale context.

**Alternative location consideration**: This could also be done in the `updateType == .selectionOnly` branch (line 78), but checking `previousSelection != newSelection` is more explicit and handles all selection changes (including structural changes that also change selection).

#### Verification Points

1. **Selection change detection**: Uses existing `previousSelection` (line 49) compared to `mapped.selectedDescriptorID` (line 60)
2. **Context clearing**: Sets both `lastContextResult` and `lastContextSnapshot` to `nil`
3. **Timing**: Occurs after selection update (line 90-94) but before `onStateUpdated()` (line 116), ensuring UI derivation reads cleared state
4. **No new state**: Uses existing variables; no new fields or tracking needed

### Why This Is Minimal

1. **Single location**: One change in one method
2. **No new abstractions**: Uses existing `projection` and existing selection comparison
3. **No caches or maps**: Direct assignment to `nil`
4. **No precomputation**: Context still built lazily on send
5. **No UI changes**: UI automatically reflects cleared state via existing reactive mechanism
6. **Surgical precision**: Only adds the missing invalidation step

### Success Criteria Verification

After this fix:

1. ✅ **Switching selection immediately clears visible context**
   - `applyUpdate()` clears context when `selectionChanged == true`
   - `onStateUpdated()` triggers `deriveContextViewState()` which reads `nil` context
   - UI displays empty context immediately

2. ✅ **Context appears only after send, and only for the current selection**
   - Context is still built lazily in `sendMessage()` (line 78-85)
   - After send, context is set for current selection
   - If selection changes before send, context is cleared (enforced by fix)

3. ✅ **No stale context can ever appear by construction**
   - Selection change always clears context before UI derivation
   - Context can only exist if selection hasn't changed since it was built
   - No path exists where stale context persists across selection changes

### Edge Cases Handled

- **Selection cleared (nil)**: `selectionChanged` is true when going from non-nil to nil, context is cleared
- **Selection set (from nil)**: `selectionChanged` is true when going from nil to non-nil, context is cleared
- **Same selection reselected**: `selectionChanged` is false, context persists (correct behavior)
- **Structural change with selection change**: Context is cleared (handled by same check)
- **Structural change without selection change**: Context persists (correct if selection unchanged)

---

## Summary

**Ontological correction**: Context is relational state bound to selection, not global persistent state.

**Invariant restoration**: Selection change immediately invalidates context before UI derivation.

**Minimal fix**: Add 5 lines in `WorkspaceStateObserver.applyUpdate()` to clear context when selection changes.

**No new abstractions, no caches, no speculative stores, no precomputation pipelines.**

This is a surgical repair that restores the violated invariant by adding the missing invalidation step.
