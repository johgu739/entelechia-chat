# macOS Surface Hierarchy Restoration - Summary

## STEP 1 - Flattening Change Identified

**Problem:** Global `.regularMaterial` was applied to root surfaces, collapsing the macOS three-tier surface hierarchy.

**Files with flattening:**
1. `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift:58` - Root window background
2. `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:57` - Editor content background
3. `ChatUI/Sources/ChatUI/UI/Shell/NoFileSelectedView.swift:28` - Editor empty state background
4. `ChatUI/Sources/ChatUI/UI/WorkspaceUI/OnboardingSelectProjectView.swift:131` - Onboarding window background

**Root cause:** All surfaces used the same material, eliminating visual distinction between window chrome, sidebars, and editor regions.

---

## STEP 2 - Correct macOS Surface Hierarchy Restored

### A) Window / Chrome Background (Outermost)

**Files Changed:**
1. `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift:58`
   - **Before:** `.background(.regularMaterial)`
   - **After:** `.background(Color(nsColor: .windowBackgroundColor))`
   - **Added guardrail comment:** "Do not apply global material; it collapses surface hierarchy."

2. `ChatUI/Sources/ChatUI/UI/WorkspaceUI/OnboardingSelectProjectView.swift:131`
   - **Before:** `.background(.regularMaterial)`
   - **After:** `.background(Color(nsColor: .windowBackgroundColor))`

**Result:** Window chrome now uses semantic window background color, not a material blanket.

### B) Sidebar Regions (Navigator + Inspector)

**Files Verified/Changed:**
1. `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorView.swift:26`
   - **Status:** ✓ Already correct - uses `VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)`

2. `ChatUI/Sources/ChatUI/UI/WorkspaceUI/FilesSidebarView.swift:116`
   - **Status:** ✓ Already correct - uses `VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)`

3. `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift:57`
   - **Before:** `.background(Color.clear)` (transparent)
   - **After:** `.background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active))`

**Result:** All sidebar regions now consistently use `.sidebar` material, visually distinct from editor.

### C) Main Editor / Content Region

**Files Changed:**
1. `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:57`
   - **Before:** `.background(.regularMaterial)`
   - **After:** `.background(Color(nsColor: .textBackgroundColor))`

2. `ChatUI/Sources/ChatUI/UI/Shell/NoFileSelectedView.swift:28`
   - **Before:** `.background(.regularMaterial)`
   - **After:** `.background(Color(nsColor: .textBackgroundColor))`

**Result:** Editor region now uses semantic text background color, lighter/cleaner than sidebars.

---

## STEP 3 - Verification

### Surface Hierarchy Confirmed

| Surface Role | Implementation | Status |
|-------------|----------------|--------|
| **Window Chrome** | `Color(nsColor: .windowBackgroundColor)` | ✓ Restored |
| **Navigator Sidebar** | `VisualEffectView(material: .sidebar)` | ✓ Correct |
| **Files Sidebar** | `VisualEffectView(material: .sidebar)` | ✓ Correct |
| **Inspector Sidebar** | `VisualEffectView(material: .sidebar)` | ✓ Restored |
| **Editor/Content** | `Color(nsColor: .textBackgroundColor)` | ✓ Restored |

### Visual Distinction

- **Sidebar vs Editor:** Sidebars use `.sidebar` material (frosted glass effect), editor uses `textBackgroundColor` (lighter, cleaner)
- **Window vs Content:** Window chrome uses neutral `windowBackgroundColor`, content regions use appropriate semantic colors
- **No Global Material:** Root no longer applies a single material everywhere

---

## STEP 4 - Guardrail Added

**Location:** `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift:57-59`

```swift
// Do not apply global material; it collapses surface hierarchy.
// Window chrome uses semantic color, sidebars use .sidebar material, editor uses textBackgroundColor.
navigationLayout
    .background(Color(nsColor: .windowBackgroundColor))
```

---

## Summary

**Files Modified:** 5 files
- 2 window backgrounds restored to `windowBackgroundColor`
- 2 editor backgrounds restored to `textBackgroundColor`
- 1 inspector background changed from transparent to `.sidebar` material

**Result:** Three-tier macOS surface hierarchy restored:
1. Window chrome: Neutral semantic color
2. Sidebars: Frosted glass material (`.sidebar`)
3. Editor: Clean semantic color (`textBackgroundColor`)

**No layout, typography, or card styling changes** - only background/material application adjusted.
