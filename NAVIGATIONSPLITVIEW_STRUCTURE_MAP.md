# NavigationSplitView Structure Map: Current vs Apple Ideal

## Current State (BROKEN)

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    navigatorColumn  // Left sidebar ✅
} detail: {
    chatColumn       // ❌ WRONG: This is now the "detail" in two-column mode
        .inspector(isPresented: $isInspectorVisible) {
            inspectorColumn  // Right inspector
        }
}
```

**Problem:** Removed `content:` parameter, converting from three-column to two-column.

---

## What We Should Have (Three-Column Structure)

### Column Mapping

| Position | NavigationSplitView Parameter | Our Content | Purpose |
|----------|------------------------------|-------------|---------|
| **Left** | `sidebar` (first) | `navigatorColumn` | File navigator ✅ |
| **Middle** | `content` (second) | `chatColumn` | Chat/editor content ✅ |
| **Right** | `.inspector()` modifier | `inspectorColumn` | Inspector panel ✅ |

### Correct Structure

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    navigatorColumn  // Left: Sidebar (file navigator)
} content: {
    chatColumn       // Middle: Content (chat/editor)
        .inspector(isPresented: $isInspectorVisible) {
            inspectorColumn  // Right: Inspector (attached to content)
        }
} detail: {
    // Empty or minimal - detail is for navigation hierarchy, not needed here
    EmptyView()
}
```

---

## Apple's Ideal Pattern

### For Three-Column Navigation Hierarchy

```swift
NavigationSplitView {
    SidebarView()      // Mailboxes
} content: {
    ContentView()      // Message List
} detail: {
    DetailView()       // Message Detail
}
```

**Semantic:** Sidebar → Content → Detail (hierarchical navigation)

### For Sidebar + Content + Inspector

```swift
NavigationSplitView {
    SidebarView()      // File navigator
} detail: {
    ContentView()      // Editor/content
        .inspector(isPresented: $showInspector) {
            InspectorView()  // Inspector panel
        }
}
```

**Semantic:** Sidebar + Content with Inspector (two-column with inspector)

### For Sidebar + Content + Inspector (Three Visible Columns)

```swift
NavigationSplitView {
    SidebarView()      // File navigator
} content: {
    ContentView()      // Editor/content
        .inspector(isPresented: $showInspector) {
            InspectorView()  // Inspector panel
        }
} detail: {
    // Empty or placeholder - not used for navigation hierarchy
    EmptyView()
}
```

**Semantic:** Three visible columns, but detail is not part of navigation hierarchy

---

## Our Use Case Analysis

**What we have:**
- Left: File navigator (hierarchical file tree)
- Middle: Chat/editor (content area)
- Right: Inspector (metadata panel)

**Is this a navigation hierarchy?**
- NO: We're not navigating Sidebar → Content → Detail
- We're showing: Navigator + Editor + Inspector (three independent panels)

**Apple's recommendation:**
- Use two-column NavigationSplitView (sidebar + detail)
- Attach inspector to the detail view with `.inspector()`
- OR use three-column but attach inspector to content

---

## The Correct Fix

### Option 1: Two-Column (Recommended if no navigation hierarchy)

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    navigatorColumn  // Left: Sidebar
} detail: {
    chatColumn       // Middle/Right: Content
        .inspector(isPresented: $isInspectorVisible) {
            inspectorColumn  // Right: Inspector
        }
}
```

### Option 2: Three-Column (If we need all three visible)

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    navigatorColumn  // Left: Sidebar
} content: {
    chatColumn       // Middle: Content
        .inspector(isPresented: $isInspectorVisible) {
            inspectorColumn  // Right: Inspector
        }
} detail: {
    EmptyView()      // Not used for navigation
}
```

---

## Deviations from Apple Ideal

### Current Deviations

1. **❌ Missing `content:` parameter** - Converted to two-column when we need three visible columns
2. **❌ Inspector in wrong place** - Should be attached to content, not detail
3. **✅ NavigationStack in content** - Correct
4. **✅ Inspector using `.inspector()` modifier** - Correct approach

### What Needs Fixing

1. **Restore `content:` parameter** to maintain three-column structure
2. **Move `.inspector()` to content column** (not detail)
3. **Keep detail column empty** (or minimal placeholder)

---

## Final Correct Structure

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    navigatorColumn  // Left sidebar ✅
} content: {
    chatColumn       // Middle content ✅
        .inspector(isPresented: $isInspectorVisible) {
            inspectorColumn  // Right inspector ✅
        }
} detail: {
    // Empty - not part of navigation hierarchy
    EmptyView()
}
```
