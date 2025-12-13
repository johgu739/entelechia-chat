# NavigationSplitView Inspector Architecture: Complete Causal Chain

**Date:** 2025-01-XX  
**Critical Discovery:** We are fundamentally misusing NavigationSplitView's architecture.

---

## Executive Summary

**Root Cause:** We are using NavigationSplitView's `detail` column as an inspector, which is architecturally incorrect. NavigationSplitView's `detail` column is designed for hierarchical navigation detail views, NOT for hideable inspectors.

**The Correct Solution:** Use `.inspector()` modifier (macOS 14+) on the content/detail view, NOT NavigationSplitView's `detail` parameter.

---

## Causal Chain: Why Right Sidebar Is Not Hideable

### Current (INCORRECT) Architecture

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    navigatorColumn      // Sidebar - ✅ Correct
} content: {
    chatColumn          // Content - ✅ Correct
} detail: {
    inspectorColumn     // ❌ WRONG: This is NOT an inspector!
}
```

### Why This Fails

1. **NavigationSplitViewVisibility only controls sidebar and content columns**
   - `.all` - Shows sidebar + content + detail
   - `.doubleColumn` - Shows content + detail (hides sidebar)
   - `.detailOnly` - Shows only detail (hides sidebar + content)
   - **NO option to hide detail column alone**

2. **NavigationSplitView's automatic toolbar items only provide:**
   - Sidebar toggle button (for first column)
   - **NO inspector toggle button** (because detail is not an inspector)

3. **The `detail` column is semantically wrong:**
   - It's meant for navigation hierarchy: Sidebar → Content → Detail
   - Example: Mail app: Mailboxes → Message List → Message Detail
   - It's NOT meant for: Sidebar → Editor → Inspector

4. **Result:** The right sidebar appears as a fixed column with no native toggle mechanism.

---

## Apple's Design Intent: `.inspector()` Modifier

### Introduced in macOS 14+ (WWDC 2023)

**The correct pattern for a hideable right sidebar/inspector:**

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    sidebarColumn
} detail: {
    contentView
        .inspector(isPresented: $isInspectorVisible) {
            InspectorView()
        }
        .toolbar {
            // Inspector toggle button appears automatically
        }
}
```

### Why `.inspector()` is the Correct Solution

1. **Semantic correctness:**
   - Inspector is a supplementary panel, not part of navigation hierarchy
   - `.inspector()` modifier makes this explicit

2. **Automatic toolbar integration:**
   - `.inspector()` automatically provides toggle button in toolbar
   - Button appears/disappears based on `isPresented` binding
   - Native macOS behavior (like Xcode's inspector)

3. **Proper lifecycle:**
   - Inspector can be shown/hidden independently
   - State persists correctly
   - Window remembers inspector visibility

4. **Two-column NavigationSplitView:**
   - Use sidebar + detail (content is optional)
   - Apply `.inspector()` to the detail view
   - This matches Apple's intended pattern

---

## The Correct Architecture

### Pattern 1: Two-Column with Inspector (Recommended)

```swift
@State private var columnVisibility = NavigationSplitViewVisibility.all
@State private var isInspectorVisible = true

NavigationSplitView(columnVisibility: $columnVisibility) {
    navigatorColumn  // Sidebar
} detail: {
    chatColumn       // Content/Detail
        .inspector(isPresented: $isInspectorVisible) {
            inspectorColumn  // Inspector
        }
}
```

### Pattern 2: Three-Column (If Content Column Needed)

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    navigatorColumn  // Sidebar
} content: {
    chatColumn       // Content
} detail: {
    detailView       // Detail (for navigation hierarchy)
        .inspector(isPresented: $isInspectorVisible) {
            inspectorColumn  // Inspector
        }
}
```

**Note:** If you don't need a navigation hierarchy (sidebar → content → detail), use Pattern 1.

---

## Why Our Current Implementation Is Wrong

### Current Structure

```swift
NavigationSplitView {
    navigatorColumn      // ✅ Correct: Sidebar
} content: {
    chatColumn          // ✅ Correct: Content
} detail: {
    inspectorColumn     // ❌ WRONG: Inspector in detail column
}
```

### Problems

1. **Semantic violation:** Detail column is for navigation hierarchy, not inspectors
2. **No automatic toggle:** NavigationSplitView doesn't provide inspector toggle buttons
3. **Visibility control:** Cannot hide detail column independently (only via columnVisibility which affects all columns)
4. **Architectural mismatch:** We're forcing an inspector into a navigation detail slot

---

## The Correct Implementation

### Step 1: Convert to Two-Column Layout

Since we don't need a three-level navigation hierarchy (sidebar → content → detail), we should use two columns:

```swift
NavigationSplitView(columnVisibility: $columnVisibility) {
    navigatorColumn  // Sidebar
} detail: {
    chatColumn       // Content (this becomes the "detail" in two-column mode)
        .inspector(isPresented: $isInspectorVisible) {
            ContextInspector(...)
        }
}
```

### Step 2: Add Inspector State

```swift
@State private var isInspectorVisible = true
```

### Step 3: Remove Inspector from Detail Column

The inspector should NOT be in NavigationSplitView's detail parameter. It should be applied via `.inspector()` modifier.

---

## Verification: Why This Is Apple-Grade

1. **Follows WWDC 2023 pattern:** Uses `.inspector()` modifier as demonstrated
2. **Semantic correctness:** Inspector is supplementary, not part of navigation hierarchy
3. **Automatic toolbar integration:** Toggle button appears automatically
4. **Native behavior:** Matches Xcode, Notes, and other Apple apps
5. **No hacks:** Uses framework as designed, no workarounds

---

## Migration Path

1. **Remove inspector from detail column**
2. **Convert to two-column NavigationSplitView** (unless three-level navigation is needed)
3. **Apply `.inspector()` modifier to content/detail view**
4. **Add `@State private var isInspectorVisible = true`**
5. **Remove manual inspector toggle logic** (`.inspector()` handles it)

---

## Conclusion

**The right sidebar is not hideable because:**
- We're using NavigationSplitView's `detail` column for an inspector (wrong semantic)
- NavigationSplitView doesn't provide inspector toggle buttons for detail columns
- The correct pattern is `.inspector()` modifier, not detail column

**The fix:**
- Use two-column NavigationSplitView (sidebar + detail)
- Apply `.inspector()` modifier to the detail view
- Let the framework handle inspector toggle automatically

**This is not a bug or missing feature - it's a fundamental architectural misunderstanding of NavigationSplitView's design intent.**
