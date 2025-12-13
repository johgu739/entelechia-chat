# macOS Surface Stratification Restoration - Summary

## Problem Diagnosis

The app had correct system semantics but lacked surface stratification. Everything sat on the same perceptual plane → dull gray, loss of affordances (chat input, sidebars).

## Layer Model Restored

### Layer 0 — Window Chrome ✓
**File:** `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift:58`
- **Background:** `Color(nsColor: .windowBackgroundColor)`
- **Status:** ✓ Correct - no material, semantic color only

### Layer 1 — Side Chrome (Navigator + Inspector) ✓
**Files:**
1. `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorView.swift:26`
   - **Background:** `VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)`
   - **Status:** ✓ Correct - uses .sidebar material

2. `ChatUI/Sources/ChatUI/UI/WorkspaceUI/FilesSidebarView.swift:116`
   - **Background:** `VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)`
   - **Status:** ✓ Correct - uses .sidebar material

3. `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift:57`
   - **Background:** `VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)`
   - **Status:** ✓ Correct - uses .sidebar material

**Result:** All sidebars use .sidebar material, visually distinct from editor even in Light Mode. No flat gray overlays canceling the material.

### Layer 2 — Editor Canvas ✓
**Files:**
1. `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:57`
   - **Background:** `Color(nsColor: .textBackgroundColor)`
   - **Status:** ✓ Correct - flat surface, no material

2. `ChatUI/Sources/ChatUI/UI/Shell/NoFileSelectedView.swift:28`
   - **Background:** `Color(nsColor: .textBackgroundColor)`
   - **Status:** ✓ Correct - flat surface, no material

**Result:** Editor is the "paper" plane - flat and lighter than sidebars.

### Layer 3 — Controls Floating on Editor ✓ FIXED
**File:** `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatInputBar.swift:66-75`

**Before:**
```swift
private var inputBackground: some View {
    RoundedRectangle(cornerRadius: cornerRadius)
        .fill(DS.background)  // ❌ windowBackgroundColor - wrong layer
        .shadow(color: .black.opacity(0.04), radius: 1)  // ❌ Too subtle
}
```

**After:**
```swift
private var inputBackground: some View {
    // Layer 3: Control floating on editor - must be visually lifted
    // Background: controlBackgroundColor (not textBackgroundColor or windowBackgroundColor)
    // Inset stroke: separatorColor for subtle separation
    // Shadow: proper elevation to distinguish from editor floor
    RoundedRectangle(cornerRadius: cornerRadius)
        .fill(Color(nsColor: .controlBackgroundColor))  // ✓ Correct layer
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)  // ✓ Inset stroke
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)  // ✓ Proper elevation
}
```

**Result:** Chat input is now visually lifted with:
1. ✓ `controlBackgroundColor` background (not textBackgroundColor or windowBackgroundColor)
2. ✓ `separatorColor` inset stroke for subtle separation
3. ✓ Proper shadow: `.shadow(color: .black.opacity(0.08), radius: 8, y: 2)`

This exactly matches Xcode's console/input affordance.

---

## Verification Checklist

### ✓ Chat input is clearly distinct at a glance
- Uses `controlBackgroundColor` (darker than editor)
- Has inset stroke for separation
- Has proper shadow for elevation

### ✓ Sidebars feel recessed, editor feels open
- Sidebars use `.sidebar` material (frosted glass effect)
- Editor uses `textBackgroundColor` (lighter, cleaner)
- Visual distinction maintained even in Light Mode

### ✓ App does not look uniformly gray
- Window chrome: neutral `windowBackgroundColor`
- Sidebars: frosted `.sidebar` material
- Editor: light `textBackgroundColor`
- Input: elevated `controlBackgroundColor` with shadow

### ✓ Looks closer to Xcode / Finder split view
- Three-tier hierarchy restored
- Proper material usage
- Correct elevation for controls

---

## Files Changed

**Total:** 1 file modified

1. `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatInputBar.swift:66-75`
   - Changed background from `DS.background` (windowBackgroundColor) to `controlBackgroundColor`
   - Added inset stroke with `separatorColor`
   - Upgraded shadow from subtle (0.04 opacity, radius 1) to proper elevation (0.08 opacity, radius 8, y: 2)
   - Added documentation comment explaining Layer 3

---

## What Was NOT Changed

- ✓ No `.regularMaterial` or `.thinMaterial` added to root surfaces
- ✓ No opacity-based "contrast fixes"
- ✓ No custom gradients
- ✓ No new palette
- ✓ No layout or typography changes
- ✓ Sidebars already correct (no changes needed)

---

## Result

**Pure macOS UI physics restored:**
- Window chrome: Semantic color
- Sidebars: Material (frosted glass)
- Editor: Semantic color (lighter)
- Input control: Elevated with proper shadow

The app now has proper surface stratification matching Xcode's visual hierarchy.
