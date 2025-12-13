# Color & Material Audit Report

**Date:** 2024-12-19  
**Scope:** ChatUI, AppComposition (UI composition only)  
**Type:** Read-only audit (no changes)

---

## 1. Root Surfaces

### Window / Root View
- **Location:** `ChatUI/Sources/ChatUI/UI/Shell/MainView.swift:58`
- **Background:** `AppTheme.windowBackground`
- **Type:** Flat Color
- **Definition:** `Color(nsColor: .windowBackgroundColor)` (system semantic)
- **Also used in:** `OnboardingSelectProjectView.swift:131`

### Sidebar / Navigator Containers
- **Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorView.swift:26`
- **Background:** `VisualEffectView(material: .sidebar, blendingMode: .withinWindow, state: .active)`
- **Type:** SwiftUI Material (via NSVisualEffectView wrapper)
- **Material:** `.sidebar` (NSVisualEffectView.Material)
- **Blending:** `.withinWindow`
- **Implementation:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/VisualEffectView.swift` (NSViewRepresentable wrapper)

- **Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/FilesSidebarView.swift:116`
- **Background:** `AppTheme.panelBackground`
- **Type:** Flat Color
- **Definition:** `Color(nsColor: .controlBackgroundColor)` (system semantic)

### Main Content Containers
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:57`
- **Background:** `AppTheme.editorBackground`
- **Type:** Flat Color
- **Definition:** `Color(nsColor: .textBackgroundColor)` (system semantic)
- **Also used in:** `NoFileSelectedView.swift:28`

### Inspector Column
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift:57`
- **Background:** `Color.clear`
- **Type:** Nothing (transparent)

---

## 2. Selection & Highlighting

### Navigator Selection (NSOutlineView)
- **Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/XcodeNavigatorRepresentable.swift:52-54`
- **Style:** `.sourceList` (NSOutlineView selectionHighlightStyle)
- **Type:** System semantic selection style
- **Background:** Uses system selection color (handled by AppKit)

### Files Sidebar Selection
- **Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/FilesSidebarView.swift:93,112`
- **Style:** `List(selection:)` with `.listStyle(.sidebar)`
- **Type:** System semantic selection style
- **Background:** Uses system selection color (handled by SwiftUI)

### Navigator Mode Button (Active State)
- **Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/NavigatorModeButton.swift:21`
- **Background:** `Color.accentColor.opacity(0.2)`
- **Type:** Accent color with opacity
- **Inactive:** `Color.clear`

### Inspector Tab Selection
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextInspectorTabs.swift:15,20`
- **Text Color:** `.primary` when selected, `.secondary` when not
- **Background:** `DS.background` when selected, `Color.clear` when not
- **Type:** Flat color fill

### Navigator Cell View (AppKit)
- **Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/NavigatorCellView.swift:20`
- **Background:** `NSColor.clear.cgColor`
- **Type:** Transparent (selection handled by NSOutlineView)

---

## 3. Containers & Cards

### Message Bubbles
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/MessageBubbleContent.swift:29-34`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r16)`
- **Fill:** `DS.background` (assistant) or `DS.background.opacity(0.95)` (user)
- **Stroke:** `DS.stroke` (1pt lineWidth)
- **Type:** Flat Color fill with stroke

### Code Blocks
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/CodeBlockView.swift:38-43`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r12)`
- **Fill:** `DS.background`
- **Stroke:** `DS.stroke` (1pt lineWidth)
- **Type:** Flat Color fill with stroke

### Input Bar
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatInputBar.swift:67-72`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r16)`
- **Fill:** `DS.background`
- **Stroke:** `DS.stroke` (1pt lineWidth)
- **Type:** Flat Color fill with stroke

### Context Bar
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextBar.swift:20-24`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r12)`
- **Fill:** `DS.background`
- **Stroke:** `DS.stroke` (1pt lineWidth)
- **Type:** Flat Color fill with stroke

### Error Banner
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextErrorBanner.swift:24-25`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r12)`
- **Fill:** `Color(NSColor.windowBackgroundColor).opacity(0.9)`
- **Type:** Flat Color with opacity

### Recent Project Row
- **Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/RecentProjectRow.swift:42-47`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r12)`
- **Fill:** `Color.secondary.opacity(0.15)` (hover) or `Color.secondary.opacity(0.08)` (default)
- **Stroke:** `Color.blue.opacity(0.3)` (hover) or `Color.clear` (default)
- **Type:** Flat Color with conditional opacity

### Message Bubble Actions
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/MessageBubbleActions.swift:36,54`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r12)`
- **Fill:** `DS.stroke.opacity(0.2)`
- **Type:** Flat Color with opacity

### Ontology Todos Cards
- **Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/OntologyTodosView.swift:75-79,99-103`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r12)`
- **Fill:** `DS.background`
- **Stroke:** `DS.stroke` (1pt lineWidth)
- **Type:** Flat Color fill with stroke

### Navigator Filter Field
- **Location:** `ChatUI/Sources/ChatUI/UI/WorkspaceUI/XcodeNavigator/NavigatorFilterField.swift:35-39`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r12)`
- **Fill:** `DS.background`
- **Stroke:** `DS.stroke` (1pt lineWidth)
- **Type:** Flat Color fill with stroke

### Codex Status Banner
- **Location:** `ChatUI/Sources/ChatUI/UI/Shell/CodexStatusBanner.swift:38-42`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r12)`
- **Fill:** `DS.background`
- **Stroke:** `accentColor.opacity(0.6)` (1pt lineWidth)
- **Type:** Flat Color fill with accent stroke

### Context Inspector Segment List
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/ContextInspectorSegmentList.swift:18`
- **Shape:** `RoundedRectangle(cornerRadius: DS.r12)`
- **Fill:** `Color.secondary.opacity(0.08)`
- **Type:** Flat Color with opacity

### Streaming Chip
- **Location:** `ChatUI/Sources/ChatUI/UI/ConversationUI/StreamingChip.swift:19`
- **Shape:** `Capsule()`
- **Fill:** `Color.secondary.opacity(0.1)`
- **Type:** Flat Color with opacity

---

## 4. Text & Icon Coloring

### Default Text Colors
- **System Semantic:** `.primary`, `.secondary` (used extensively)
- **Design System:** `DS.secondaryText`, `DS.tertiaryText`
  - **Definition:** `Color(nsColor: .secondaryLabelColor)`, `Color(nsColor: .tertiaryLabelColor)`
  - **Location:** `ChatUI/Sources/ChatUI/Design/DesignSystem.swift:27-28`

### Explicit ForegroundColor Usage
- **Primary:** `.foregroundColor(.primary)` - used in toolbar buttons, selected states
- **Secondary:** `.foregroundColor(.secondary)` - used in 50+ locations for secondary text
- **Design System:** `.foregroundColor(DS.secondaryText)` - used in input fields, labels
- **Design System:** `.foregroundColor(DS.tertiaryText)` - used in disabled states

### Hard-Coded Colors

#### Orange
- **Location:** `MessageBubbleContent.swift:40,44` - Error messages
- **Location:** `ContextInspectorFileRow.swift:38` - Warning indicators
- **Location:** `FileRow.swift:39` - Exclusion reasons
- **Location:** `FilesSidebarErrorView.swift:10,23` - Error view (text and background)
- **Location:** `ContextBudgetDiagnosticsView.swift:54` - Warning states
- **Location:** `BudgetRow.swift:16` - Progress indicators
- **Location:** `CodexStatusBanner.swift:50` - Warning status

#### Red
- **Location:** `ContextInspectorFileRow.swift:43` - Error indicators
- **Location:** `BudgetRow.swift:14` - Error states
- **Location:** `ContextBudgetDiagnosticsView.swift:88` - Error states
- **Location:** `CodexStatusBanner.swift:51` - Error status

#### Yellow
- **Location:** `ContextErrorBanner.swift:10` - Warning icon
- **Location:** `CodexStatusBanner.swift:26` - Warning status

#### Blue
- **Location:** `RecentProjectRow.swift:18,47` - Project name and hover stroke

#### White
- **Location:** `NavigatorModeButton.swift:30` - Badge text on accent background

#### Green
- **Location:** `CodexStatusBanner.swift:49` - Success status

### Accent Color Usage
- **System:** `.accentColor` - used for:
  - Active button states (`NavigatorModeButton.swift:21,29`)
  - Enabled action buttons (`ChatInputView.swift:151,163`)
  - Interactive elements (`FileIconView.swift:28`, `SendButton.swift:11`)
  - Progress indicators (`BudgetRow.swift:11,18`)
  - Status indicators (`CodexStatusBanner.swift:18,42`)

### No Explicit ForegroundColor (Uses System Default)
- Most text elements rely on SwiftUI's default `.primary` text color
- Icons use system semantic colors by default

---

## 5. Centralization

### Color Palette Files

#### AppTheme.swift
- **Location:** `ChatUI/Sources/ChatUI/UI/Theme/AppTheme.swift`
- **Type:** Struct with static computed properties
- **Colors Defined:**
  - `windowBackground`: `Color(nsColor: .windowBackgroundColor)`
  - `editorBackground`: `Color(nsColor: .textBackgroundColor)`
  - `panelBackground`: `Color(nsColor: .controlBackgroundColor)`
  - `inputBackground`: `Color(nsColor: .controlBackgroundColor)`
- **Usage:** Root surfaces, main containers
- **Pattern:** All use NSColor system semantic colors

#### DesignSystem.swift (DS)
- **Location:** `ChatUI/Sources/ChatUI/Design/DesignSystem.swift`
- **Type:** Enum with static properties
- **Colors Defined:**
  - `background`: `Color(nsColor: .windowBackgroundColor)`
  - `stroke`: `Color(nsColor: .separatorColor)`
  - `secondaryText`: `Color(nsColor: .secondaryLabelColor)`
  - `tertiaryText`: `Color(nsColor: .tertiaryLabelColor)`
- **Usage:** Cards, containers, text styling
- **Pattern:** All use NSColor system semantic colors

### Design System File
- **Location:** `ChatUI/Sources/ChatUI/Design/DesignSystem.swift`
- **Contains:** Spacing, corners, fonts, colors
- **Not a comprehensive design system:** Only basic tokens, no material definitions

### Extensions Defining Semantic Colors
- **None found:** No Color extensions defining semantic colors
- **No material extensions:** No SwiftUI Material extensions

### Ad-Hoc Color Usage
- **Hard-coded colors:** Orange, red, yellow, blue, white, green used directly in 15+ locations
- **Direct NSColor usage:** `Color(NSColor.windowBackgroundColor)` in `ContextErrorBanner.swift:25`
- **Direct system colors:** `.accentColor`, `.primary`, `.secondary` used throughout
- **Opacity variations:** Many ad-hoc opacity adjustments (e.g., `.opacity(0.2)`, `.opacity(0.95)`)

### Material Usage
- **Single material usage:** Only `VisualEffectView` uses NSVisualEffectView.Material (`.sidebar`)
- **No SwiftUI Material:** No use of SwiftUI's `.material()` modifier
- **No Material extensions:** No custom material definitions

---

## Summary

### Root Surfaces
- Window: Flat color (system semantic)
- Sidebar: Material (NSVisualEffectView.sidebar)
- Main content: Flat color (system semantic)
- Inspector: Transparent

### Selection & Highlighting
- Navigator: System selection style (.sourceList)
- Sidebar: System selection style (.sidebar)
- Active states: Accent color with opacity
- Tabs: Flat color fill

### Containers & Cards
- All use `RoundedRectangle` shapes
- All use flat color fills (DS.background or variations)
- All use flat color strokes (DS.stroke)
- No material backgrounds on cards

### Text & Icon Coloring
- Primary: System semantic colors (.primary, .secondary)
- Design system: DS.secondaryText, DS.tertiaryText
- Hard-coded: Orange, red, yellow, blue, white, green (15+ locations)
- Accent: System .accentColor

### Centralization
- Two color files: AppTheme.swift, DesignSystem.swift
- Both use NSColor system semantic colors
- No material system
- Significant ad-hoc color usage (hard-coded colors, opacity variations)
