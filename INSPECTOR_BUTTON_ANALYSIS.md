# Inspector Button Missing: Root Cause Analysis

## Current State

### Structure
```swift
NavigationSplitView {
    navigatorColumn
} detail: {
    NavigationStack {
        chatContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .inspector(isPresented: $isInspectorVisible) {  // ← Modifier here
        inspectorColumn
    }
}

@ViewBuilder
private var chatContent: some View {
    if let selectedNode = workspaceState.selectedNode {
        ChatView(...)
            .navigationTitle(selectedNode.name)  // ← Title here
    } else {
        NoFileSelectedView()
            .navigationTitle("No Selection")  // ← Title here
    }
}
```

## Problem: No Toolbar Button

**Observation:** Inspector toggle button is completely missing from window toolbar.

## Root Cause Analysis

### Issue 1: Modifier Placement vs Navigation Context

**The `.inspector()` modifier needs:**
1. A view with `.navigationTitle` in the hierarchy
2. The modifier should be on a view that participates in navigation
3. Toolbar system searches up hierarchy for navigation context

**Current problem:**
- `.inspector()` is on `NavigationStack` wrapper (line 93)
- `.navigationTitle` is on conditional child views (`chatContent` branches)
- NavigationStack itself doesn't have `.navigationTitle`
- Toolbar system might not find navigation context properly

### Issue 2: Conditional Navigation Titles

**The `.navigationTitle` is on conditional branches:**
- `if let selectedNode` → one title
- `else` → another title
- This means the navigation title changes based on state
- Toolbar system might lose context during state changes

### Issue 3: Frame Modifier Interference

**The `.frame(maxWidth: .infinity, maxHeight: .infinity)` on `chatContent`:**
- This might be interfering with navigation context propagation
- Frame modifiers can affect how navigation context is established

## What Apple's Documentation Says

From WWDC 2023 and Apple forums:
- `.inspector()` should be on a view with navigation context
- The view should have `.navigationTitle` or be in a NavigationStack with titles
- Toolbar button appears automatically when context is found

## The Simplest Solution

**Strip everything down to the absolute minimum:**

1. Remove all unnecessary modifiers from inspector
2. Ensure `.navigationTitle` is stable (not conditional)
3. Apply `.inspector()` to the view that has the title

## Complicated Hacks/Modifiers to Remove

1. **`.frame(maxWidth: .infinity, maxHeight: .infinity)` on chatContent** - Might interfere
2. **Conditional `.navigationTitle`** - Should be stable
3. **Any other modifiers between NavigationStack and inspector**

## The Correct Minimal Pattern

```swift
NavigationSplitView {
    navigatorColumn
} detail: {
    NavigationStack {
        chatContent
            .navigationTitle("Title")  // ← Stable title
            .inspector(isPresented: $isInspectorVisible) {  // ← On content with title
                inspectorColumn
            }
    }
}
```

**Key insight:** The modifier should be on the view that has `.navigationTitle`, not on the NavigationStack wrapper.
