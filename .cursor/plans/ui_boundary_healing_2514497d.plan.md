---
name: UI Boundary Healing
overview: Eliminate all AppCoreEngine type leaks from UIConnections public APIs by replacing domain types with UIContracts equivalents and removing/updating violating public symbols.
todos:
  - id: delete-violating-types
    content: Delete UIConnections.WorkspaceIntent, ChatIntent, ChatViewState, and WorkspaceViewState files (already replaced by UIContracts versions)
    status: pending
  - id: verify-no-typealiases
    content: Verify no typealiases re-export WorkspaceIntent, ChatIntent, ChatViewState, or WorkspaceViewState
    status: pending
  - id: fix-project-coordinator
    content: Make ProjectCoordinator entirely internal (class and all properties), update RecentProject to use UIContracts.UIProjectRepresentation
    status: pending
    dependencies:
      - verify-no-typealiases
  - id: update-recent-project-mapping
    content: Update ProjectCoordinator.recentProjects and openRecent to map between UIContracts and domain types internally
    status: pending
    dependencies:
      - fix-project-coordinator
  - id: handle-appcomposition-access
    content: Ensure AppComposition can still access project operations (may need public factory/adapter or move creation to UIConnections)
    status: pending
    dependencies:
      - fix-project-coordinator
  - id: verify-no-leaks
    content: Run verification commands to ensure no AppCoreEngine types appear in public UIConnections APIs
    status: pending
    dependencies:
      - delete-violating-types
      - fix-project-coordinator
      - update-recent-project-mapping
---

# UI Boundary Healing Plan

## Objective

Make the statement true: "No public API in UIConnections exposes any AppCoreEngine type, directly or indirectly."

## Violations to Fix

### 1. WorkspaceIntent (UIConnections)

**File:** `UIConnections/Sources/UIConnections/Workspaces/WorkspaceIntent.swift`

**Problem:** Public enum uses `AppCoreEngine.FileNode?` and `AppCoreEngine.FileID?`

**Solution:**

- Delete `UIConnections/Sources/UIConnections/Workspaces/WorkspaceIntent.swift` entirely
- All code already uses `UIContracts.WorkspaceIntent` (verified in WorkspaceIntentController)
- Update any remaining imports if needed

### 2. ChatIntent (UIConnections)

**File:** `UIConnections/Sources/UIConnections/Conversation/ChatIntent.swift`

**Problem:** Public enum uses `AppCoreEngine.Conversation` and `AppCoreEngine.ConversationDelta`

**Solution:**

- Delete `UIConnections/Sources/UIConnections/Conversation/ChatIntent.swift` entirely
- `ChatIntentController` already uses `UIContracts.ChatIntent` (line 58)
- Note: UIContracts.ChatIntent has different cases (`sendMessage(String, UUID)`, `askCodex(String, UUID)`) but controllers already handle this

### 3. ChatViewState (UIConnections)

**File:** `UIConnections/Sources/UIConnections/Conversation/ChatViewState.swift`

**Problem:** Public struct uses `AppCoreEngine.Message`

**Solution:**

- Delete `UIConnections/Sources/UIConnections/Conversation/ChatViewState.swift` entirely
- `ChatIntentController` already uses `UIContracts.ChatViewState` (line 16)
- UIContracts.ChatViewState uses `UIMessage` (correct)

### 4. WorkspaceViewState (UIConnections)

**File:** `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewState.swift`

**Problem:** Public struct uses `AppCoreEngine.FileNode?`, `AppCoreEngine.FileID?`, `AppCoreEngine.ProjectTodos`

**Solution:**

- Delete `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewState.swift` entirely
- No references found to `UIConnections.WorkspaceViewState` (grep returned zero matches)
- Code uses `UIContracts.WorkspaceUIViewState` instead

### 5. ProjectCoordinator

**File:** `UIConnections/Sources/UIConnections/Projects/ProjectCoordinator.swift`

**Problem:** Public class with public property `projectEngine: ProjectEngine` exposes domain type

**Solution (Option A - Make Entire Class Internal):**

- Change `public final class ProjectCoordinator` to `internal final class ProjectCoordinator`
- RootScreen (in UIConnections) can still access it (same module)
- AppComposition will need to use a public factory/adapter or access through RootScreen
- All domain-typed properties become internal automatically

### 6. RecentProject (UIConnections)

**File:** `UIConnections/Sources/UIConnections/Projects/ProjectCoordinator.swift` (lines 6-14)

**Problem:** Public struct uses `AppCoreEngine.ProjectRepresentation`

**Solution:**

- Replace `AppCoreEngine.ProjectRepresentation` with `UIContracts.UIProjectRepresentation`
- Update `recentProjects` getter (line 81-93) to map domain types to UIContracts types using `DomainToUIMappers.toUIProjectRepresentation`
- Update `openRecent` method (line 61-79) to convert from UIContracts to domain internally

## Pre-Checks (MANDATORY)

**Verify no typealiases re-export deleted types:**

```bash
grep -R "typealias .*WorkspaceIntent" UIConnections
grep -R "typealias .*ChatIntent" UIConnections
grep -R "typealias .*ChatViewState" UIConnections
grep -R "typealias .*WorkspaceViewState" UIConnections
```

**Result:** All four searches returned zero matches ✅

## Implementation Steps

1. **Delete violating type definitions:**

   - Delete `UIConnections/Sources/UIConnections/Workspaces/WorkspaceIntent.swift`
   - Delete `UIConnections/Sources/UIConnections/Conversation/ChatIntent.swift`
   - Delete `UIConnections/Sources/UIConnections/Conversation/ChatViewState.swift`
   - Delete `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewState.swift`

2. **Fix ProjectCoordinator (make entirely internal):**

   - Change `public final class ProjectCoordinator` to `internal final class ProjectCoordinator`
   - Change `public struct RecentProject` to `internal struct RecentProject` (or delete if unused)
   - Update `RecentProject` to use `UIContracts.UIProjectRepresentation` instead of `AppCoreEngine.ProjectRepresentation`
   - Update `recentProjects` getter to return `[UIContracts.RecentProject]` (using `DomainToUIMappers.toRecentProject`)
   - Update `openRecent` to accept `UIContracts.RecentProject` and map internally
   - Update `openProject` to remain public but accept only UIContracts types (URL, String are fine)
   - **Note:** RootScreen (in UIConnections) can still access internal ProjectCoordinator. AppComposition will need to use a public adapter or factory.

3. **Handle AppComposition access to ProjectCoordinator:**

   - **Option A (Preferred):** Create a public factory function in UIConnections that creates internal ProjectCoordinator and returns a public protocol/adapter
   - **Option B:** Move ProjectCoordinator creation into RootScreen (internal to UIConnections)
   - **Option C:** Create a public `ProjectIntentController` that wraps ProjectCoordinator internally (similar to WorkspaceIntentController pattern)
   - **Decision:** Since RootScreen already uses ProjectCoordinator and is in UIConnections, making ProjectCoordinator internal will work. AppComposition can pass dependencies to RootScreen, which creates ProjectCoordinator internally. However, ChatUIHost currently creates it directly, so we may need a factory or move creation to RootScreen.

4. **Verify no broken references:**

   - Run grep to ensure no code references deleted types
   - Verify all controllers already use UIContracts types
   - Check that AppComposition can still function (may need adapter)

5. **Add/verify guards:**

   - Ensure `scripts/forbidden-symbol-guard.sh` blocks domain types in public APIs
   - Verify `scripts/chatui-import-guard.sh` blocks UIConnections imports in ChatUI

## Verification Commands

After implementation, run:

```bash
grep -R "public .*AppCoreEngine" UIConnections/Sources
# Must return zero matches

grep -R "public.*\(FileNode\|FileID\|Conversation\|ConversationDelta\|Message\|ProjectTodos\|ProjectEngine\|ProjectRepresentation\)" UIConnections/Sources
# Must return zero matches (unless explicitly UIContracts.*)
```

## Files to Modify

1. `UIConnections/Sources/UIConnections/Projects/ProjectCoordinator.swift` - Fix RecentProject and projectEngine visibility
2. Delete 4 files (WorkspaceIntent, ChatIntent, ChatViewState, WorkspaceViewState)

## Notes

- UIContracts already has correct versions of all these types
- Controllers already use UIContracts types, so deletion is safe
- ProjectCoordinator needs internal mapping between UIContracts and domain types