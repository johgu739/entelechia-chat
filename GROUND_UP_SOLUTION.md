# Ground-Up Solution: Correct Architecture

## Principles

1. **Stability First**: Modifiers that affect layout must be on stable containers
2. **Explicit Constraints**: Every fillable area must have frame constraints
3. **Column Isolation**: Each NavigationSplitView column must be properly isolated

---

## The Correct Structure

### MainView.swift

```swift
private var navigationLayout: some View {
    NavigationSplitView(columnVisibility: $columnVisibility) {
        navigatorColumn  // Left: Navigator (stable, fixed width)
    } detail: {
        chatColumn       // Middle: Editor (stable container)
    }
    .overlay(statusOverlay, alignment: .top)
}

private var navigatorColumn: some View {
    XcodeNavigatorView(
        workspaceState: workspaceState,
        presentationState: presentationState,
        onWorkspaceIntent: onWorkspaceIntent
    )
    .navigationSplitViewColumnWidth(
        min: DS.s20 * CGFloat(10),
        ideal: DS.s20 * CGFloat(12),
        max: DS.s20 * CGFloat(16)
    )
}

private var chatColumn: some View {
    NavigationStack {
        chatContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .inspector(isPresented: $isInspectorVisible) {  // ✅ STABLE: On container, not branches
        inspectorColumn
    }
}

@ViewBuilder
private var chatContent: some View {
    if let selectedNode = workspaceState.selectedNode {
        ChatView(
            chatState: chatState,
            workspaceState: workspaceState,
            contextState: contextState,
            onChatIntent: onChatIntent,
            onWorkspaceIntent: onWorkspaceIntent,
            inspectorTab: $inspectorTab
        )
        .navigationTitle(selectedNode.name)
    } else {
        NoFileSelectedView()
        .navigationTitle("No Selection")
    }
}

private var inspectorColumn: some View {
    ContextInspector(
        workspaceState: workspaceState,
        contextState: contextState,
        filePreviewState: filePreviewState,
        fileStatsState: fileStatsState,
        folderStatsState: folderStatsState,
        selectedInspectorTab: $inspectorTab,
        onWorkspaceIntent: onWorkspaceIntent,
        isPathIncludedInContext: isPathIncludedInContext
    )
    // NO .navigationSplitViewColumnWidth - inspector manages own width via .frame()
}
```

**Key changes:**
1. `.inspector()` moved back to `chatColumn` (stable NavigationStack wrapper)
2. Removed from conditional branches (`chatContent` if/else)
3. Inspector column has no `.navigationSplitViewColumnWidth` (already removed)

---

### XcodeNavigatorView.swift

**Current (BROKEN):**
```swift
var body: some View {
    ZStack {
        VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
            .ignoresSafeArea()
        
        VStack(spacing: 0) {
            NavigatorModeBar(...)
            NavigatorContent(...)  // ❌ NO FRAME CONSTRAINT
            if presentationState.activeNavigator == .project {
                Divider()
                NavigatorFilterField(...)
            }
        }
    }
    .background(Color.clear)
}
```

**Fixed:**
```swift
var body: some View {
    ZStack {
        VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)
            .ignoresSafeArea()
        
        VStack(spacing: 0) {
            NavigatorModeBar(
                activeNavigator: presentationState.activeNavigator,
                projectTodos: workspaceState.projectTodos,
                onWorkspaceIntent: onWorkspaceIntent
            )
            .fixedSize(horizontal: false, vertical: true)  // ✅ Fixed height
            
            NavigatorContent(
                activeNavigator: presentationState.activeNavigator,
                workspaceState: workspaceState,
                presentationState: presentationState,
                onWorkspaceIntent: onWorkspaceIntent
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)  // ✅ FILLS REMAINING SPACE
            
            if presentationState.activeNavigator == UIContracts.NavigatorMode.project {
                Divider()
                
                NavigatorFilterField(
                    filterText: presentationState.filterText,
                    onWorkspaceIntent: onWorkspaceIntent
                )
                .fixedSize(horizontal: false, vertical: true)  // ✅ Fixed height
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)  // ✅ CONTAINER CONSTRAINT
    }
    .background(Color.clear)
}
```

**Key changes:**
1. Added `.frame(maxWidth: .infinity, maxHeight: .infinity)` to `NavigatorContent`
2. Added `.fixedSize(horizontal: false, vertical: true)` to fixed-height children
3. Added container frame constraint to VStack

---

## Why This Works

### 1. Stability

**Before (BROKEN):**
- `.inspector()` on conditional branches
- Modifier recreated on every state change
- Layout system fights to maintain constraints

**After (CORRECT):**
- `.inspector()` on stable `NavigationStack` container
- Modifier never recreated
- Layout system maintains stable constraints

### 2. Frame Constraints

**Before (BROKEN):**
- `NavigatorContent` has no frame constraint
- VStack tries to fit all children
- Entire VStack scrolls during resize

**After (CORRECT):**
- `NavigatorContent` fills remaining space
- Fixed-height children have `.fixedSize()`
- Only `NavigatorContent` scrolls (via NSOutlineView)

### 3. Column Isolation

**Before (BROKEN):**
- Inspector modifier instability causes coupling
- Navigator lacks constraints
- Layout system couples them to resolve conflicts

**After (CORRECT):**
- Inspector modifier is stable
- Navigator has proper constraints
- Columns are isolated and independent

---

## Implementation Steps

1. **Move `.inspector()` modifier:**
   - From: `chatContent` branches (lines 127, 133)
   - To: `chatColumn` (after NavigationStack, line 92)

2. **Fix XcodeNavigatorView:**
   - Add `.fixedSize(horizontal: false, vertical: true)` to NavigatorModeBar
   - Add `.frame(maxWidth: .infinity, maxHeight: .infinity)` to NavigatorContent
   - Add `.fixedSize(horizontal: false, vertical: true)` to NavigatorFilterField
   - Add `.frame(maxWidth: .infinity, maxHeight: .infinity)` to VStack container

3. **Verify:**
   - Inspector toggle button appears and works
   - Navigator doesn't scroll during resize
   - Sidebars resize independently
   - No horizontal movement issues

---

## What This Fixes

1. ✅ **Navigator stability**: Fixed frame constraints prevent scrolling
2. ✅ **Sidebar decoupling**: Stable modifier placement prevents coupling
3. ✅ **Correct horizontal movement**: Proper constraints resolve correctly
4. ✅ **Inspector functionality**: Stable modifier allows toolbar button to work

---

## No Hacks, No Workarounds

This solution:
- Uses SwiftUI as designed
- Follows Apple's patterns exactly
- Requires no AppKit bridging
- Requires no introspection
- Pure SwiftUI, stable architecture
