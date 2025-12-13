# Surface Classification (STEP 1)

## 1. Window Background
- **File:** `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift:58`
- **Current Fill:** `AppTheme.windowBackground` → `Color(nsColor: .windowBackgroundColor)`
- **Type:** Flat Color
- **Also:** `OnboardingSelectProjectView.swift:131`

## 2. Primary Content Background
- **File:** `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:57`
- **Current Fill:** `AppTheme.editorBackground` → `Color(nsColor: .textBackgroundColor)`
- **Type:** Flat Color
- **Also:** `NoFileSelectedView.swift:28`

## 3. Grouped Side Panels

### Navigator Sidebar
- **File:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorView.swift:26`
- **Current Fill:** `VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)`
- **Type:** Material (NSVisualEffectView)

### Files Sidebar
- **File:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/FilesSidebarView.swift:116`
- **Current Fill:** `AppTheme.panelBackground` → `Color(nsColor: .controlBackgroundColor)`
- **Type:** Flat Color

### Inspector
- **File:** `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift:57`
- **Current Fill:** `Color.clear`
- **Type:** Transparent

## 4. Cards / Bubbles / Chips

### Using Color.secondary.opacity()
- **RecentProjectRow:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/RecentProjectRow.swift:43`
  - Fill: `Color.secondary.opacity(0.15)` (hover) or `Color.secondary.opacity(0.08)` (default)
  
- **ContextInspectorSegmentList:** `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextInspectorSegmentList.swift:18`
  - Fill: `Color.secondary.opacity(0.08)`
  
- **StreamingChip:** `ChatUI/Sources/ChatUI/UI/ConversationUI/StreamingChip.swift:19`
  - Fill: `Color.secondary.opacity(0.1)`

### Other Cards (using DS.background - leave unchanged)
- MessageBubbleContent, CodeBlockView, ChatInputBar, ContextBar, etc.

## 5. Selection & Hover Surfaces

### Navigator Mode Button (Active)
- **File:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/NavigatorModeButton.swift:21`
- **Fill:** `Color.accentColor.opacity(0.2)`
- **Type:** Accent color with opacity

### Inspector Tab Selection
- **File:** `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextInspectorTabs.swift:20`
- **Fill:** `DS.background` when selected, `Color.clear` when not
- **Type:** Flat color fill

### Recent Project Row Hover
- **File:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/RecentProjectRow.swift:47`
- **Stroke:** `Color.blue.opacity(0.3)` (hover)
- **Type:** Flat color stroke
