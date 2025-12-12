# SwiftUI Mutation Discipline Audit

**Date**: December 2025  
**Scope**: ChatUI + UIConnections  
**Status**: 🔴 **AUDIT COMPLETE - VIOLATIONS IDENTIFIED**

---

## A) OUGHT Statement

SwiftUI requires a strict causal order:
**Render (pure) → Intent (event) → Mutation (state write) → Next render.**

Violations occur when `@State`/`@Binding`/`@Published` is mutated during the render/update pass or synchronously from lifecycle hooks/callbacks that execute inside that pass.

**Theoretical Requirement**:
- View `body` evaluation must be **pure** (no side effects, no mutations)
- Lifecycle modifiers (`.onAppear`, `.onChange`, `.onReceive`) execute **during** the view update cycle
- Mutations triggered synchronously from these contexts violate the causal order
- User intent handlers (button actions, gestures) are **outside** the update cycle and may mutate, but only if they don't trigger immediate re-renders that cause nested mutations

**Violation Classification**:
1. **Certain**: Synchronous mutation from view `body` evaluation
2. **Certain**: Synchronous mutation from lifecycle modifier closure (`.onAppear`, `.onChange`, `.onReceive`)
3. **Likely**: Synchronous mutation from button action that triggers view update which then triggers another mutation
4. **Possible**: Mutation from `Task { @MainActor in }` inside lifecycle modifier (depends on SwiftUI's scheduling)

---

## B) Violation Ledger

| ID | Mutation Site | Trigger Path | Classification | Risk Level | Evidence |
|----|---------------|--------------|----------------|------------|----------|
| **V001** | `ChatViewModel.swift:72-73` | Button action → `commitMessage()` → `text = ""`, `isSending = true` | User-intent | **Certain** | Synchronous `@Published` mutation in user action handler |
| **V002** | `ChatInputBar.swift:79` | Button action → `send()` → `text = ""` | User-intent | **Certain** | Synchronous `@Binding` mutation in user action handler |
| **V003** | `ChatView.swift:125` | Button action → `sendMessage()` → `commitMessage()` → `@Published` mutations | User-intent | **Certain** | Calls `commitMessage()` which mutates `@Published` synchronously |
| **V004** | `ChatInputView.swift:128-132` | `.onChange(of: text)` → `text = trimmed` → `send()` | Lifecycle | **Certain** | Synchronous `@Binding` mutation inside `.onChange` closure |
| **V005** | `ChatView.swift:59-63` | `.onChange(of: conversationBinding?.wrappedValue.id)` → `Task { @MainActor in }` → `conversation = current`, `loadConversation()` | Lifecycle | **Likely** | Mutation wrapped in `Task` but still triggered from `.onChange` |
| **V006** | `ChatView.swift:67-71` | `.onAppear` → `Task { @MainActor in }` → `conversation = current`, `loadConversation()` | Lifecycle | **Likely** | Mutation wrapped in `Task` but still triggered from `.onAppear` |
| **V007** | `ChatInputBar.swift:36` | `.onAppear` → `isFocused = true` | Lifecycle | **Possible** | `@FocusState` mutation in `.onAppear` (may be safe, but technically during update) |
| **V008** | `ChatInputView.swift:35` | `.onAppear` → `isFocused = true` | Lifecycle | **Possible** | `@FocusState` mutation in `.onAppear` |
| **V009** | `ChatViewModel.swift:140-144` | Combine `.sink` → `self.model = choice` | Subscription | **Likely** | `@Published` mutation from Combine subscription callback (may fire during update) |
| **V010** | `ChatViewModel.swift:149-153` | Combine `.sink` → `self.contextScope = choice` | Subscription | **Likely** | `@Published` mutation from Combine subscription callback |
| **V011** | `WorkspaceConversationBindingViewModel.swift:70-73` | Combine `.sink` → no mutation (empty closure) | Subscription | **None** | No mutation, safe |
| **V012** | `WorkspaceConversationBindingViewModel.swift:77-80` | Combine `.sink` → no mutation (empty closure) | Subscription | **None** | No mutation, safe |
| **V013** | `ConversationCoordinator.swift:62-64` | Combine `.sink` → `handleStreamingUpdate()` → `viewModel.applyDelta()` | Subscription | **Likely** | `@Published` mutation via `applyDelta()` from subscription callback |
| **V014** | `ConversationCoordinator.swift:70-72` | Combine `.sink` → `handleCodexError()` → `viewModel.applyDelta()` | Subscription | **Likely** | `@Published` mutation via `applyDelta()` from subscription callback |
| **V015** | `WorkspaceConversationBindingViewModel.swift:164-166` | Async callback → `Task { @MainActor in }` → `streamingMessages[conversation.id] = streaming` | Async callback | **Possible** | Mutation wrapped in `Task` but triggered from async callback |
| **V016** | `WorkspaceConversationBindingViewModel.swift:273-283` | Async callback → `Task { @MainActor in }` → `@Published` mutations | Async callback | **Possible** | Multiple `@Published` mutations wrapped in `Task` |
| **V017** | `ContextInspector.swift:80-83` | `.onChange(of: lastContextResult)` → `clearBanner()` | Lifecycle | **Likely** | Calls `clearBanner()` which may mutate `@Published` |
| **V018** | `ContextInspector.swift:85-87` | `.onChange(of: selectedNode?.path)` → `handleSelectionChange()` → `Task` → mutations | Lifecycle | **Likely** | Triggers async mutations from `.onChange` |
| **V019** | `ChatMessagesList.swift:23-28` | `.onChange(of: messages.count)` → `withAnimation` → `proxy.scrollTo()` | Lifecycle | **Possible** | Animation trigger from `.onChange` (may be safe) |
| **V020** | `ChatMessagesList.swift:30-35` | `.onChange(of: streamingText)` → `withAnimation` → `proxy.scrollTo()` | Lifecycle | **Possible** | Animation trigger from `.onChange` (may be safe) |
| **V021** | `InputTextArea.swift:49-53` | `.onPreferenceChange` → `measuredHeight = clamped` | Preference change | **Possible** | `@Binding` mutation from preference change (may be safe) |
| **V022** | `ChatView.swift:119` | Button action → `chatViewModel.text = $0` | User-intent | **Certain** | Direct `@Published` mutation from button action |
| **V023** | `ChatView.swift:134` | `Task { @MainActor in }` → `conversation = refreshed` | Async callback | **Possible** | `@State` mutation in `Task` (deferred, but still from async callback) |
| **V024** | `ChatView.swift:142` | `Task { @MainActor in }` → `conversation = refreshed` | Async callback | **Possible** | `@State` mutation in `Task` |
| **V025** | `ChatView.swift:151` | Async callback → `conversation = updated` | Async callback | **Possible** | `@State` mutation from async callback |
| **V026** | `ChatView.swift:162` | `Task { @MainActor in }` → `chatViewModel.text = text` | Async callback | **Possible** | `@Published` mutation in `Task` |
| **V027** | `ChatView.swift:164` | `Task { @MainActor in }` → `conversation = updated` | Async callback | **Possible** | `@State` mutation in `Task` |
| **V028** | `ChatView.swift:170` | Button action → `contextPopoverData = ctx`, `showMessageContextPopover = true` | User-intent | **Certain** | Synchronous `@State` mutations from button action |
| **V029** | `ChatInputBar.swift:86` | Button action → `ask()` → `text = ""` | User-intent | **Certain** | Synchronous `@Binding` mutation in `ask()` (same pattern as V002) |
| **V030** | `ChatInputView.swift:42` | Button action → `send()` → `text = ""` | User-intent | **Certain** | Synchronous `@Binding` mutation in `send()` (same pattern as V002) |
| **V031** | `ChatInputView.swift:49` | Button action → `ask()` → `text = ""` | User-intent | **Certain** | Synchronous `@Binding` mutation in `ask()` (same pattern as V002) |
| **V032** | `ChatViewModel.swift:132` | Async callback → `Task { @MainActor in }` → `self.text = ""` | Async callback | **Possible** | `@Published` mutation in deferred `Task` from async callback |

---

## C) Causal Chains

### V001: ChatViewModel.commitMessage() - Synchronous @Published Mutation

**File**: `UIConnections/Sources/UIConnections/Conversation/ChatViewModel.swift:66-76`

**Mutation Statements**:
```swift
72: text = ""
73: isSending = true
```

**Causal Chain**:
```
User gesture (button tap)
  → ChatInputBar.send() [button action closure]
    → onSend() [closure passed from ChatView]
      → ChatView.sendMessage() [line 123]
        → chatViewModel.commitMessage() [line 125]
          → text = "" [line 72] ❌ @Published mutation
          → isSending = true [line 73] ❌ @Published mutation
```

**Thread/Actor**: MainActor (all view code is @MainActor)

**Mechanism**: Button action closures execute synchronously on the main thread. When `commitMessage()` is called, it immediately mutates `@Published` properties, which triggers SwiftUI's observation system. If this occurs during a view update pass (which can happen if the button tap was triggered by a previous state change), this violates the causal order.

**Evidence**: Direct synchronous assignment to `@Published` properties from a call chain originating in a button action.

---

### V002: ChatInputBar.send() - Synchronous @Binding Mutation

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatInputBar.swift:75-80`

**Mutation Statement**:
```swift
79: text = ""
```

**Causal Chain**:
```
User gesture (button tap)
  → ChatInputBar.send() [button action closure, line 75]
    → onSend() [line 78]
    → text = "" [line 79] ❌ @Binding mutation
```

**Thread/Actor**: MainActor

**Mechanism**: The `text` parameter is a `@Binding` to `chatViewModel.text` (which is `@Published`). Mutating the binding synchronously in a button action can trigger a view update. If this update occurs during SwiftUI's update pass, it violates the causal order.

**Evidence**: Direct synchronous assignment to `@Binding` from button action.

---

### V003: ChatView.sendMessage() → commitMessage() Chain

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:123-125`

**Mutation Statements**:
```swift
125: guard let userMessage = chatViewModel.commitMessage() else { return }
```

**Causal Chain**:
```
User gesture (button tap)
  → ChatView.sendMessage() [button action closure, line 123]
    → chatViewModel.commitMessage() [line 125]
      → [See V001 for full chain]
        → text = "" ❌ @Published mutation
        → isSending = true ❌ @Published mutation
```

**Thread/Actor**: MainActor

**Mechanism**: `sendMessage()` calls `commitMessage()` synchronously, which mutates `@Published` properties. This is a double violation: both the direct call and the indirect mutations occur synchronously from a user action.

**Evidence**: Direct call to `commitMessage()` which contains synchronous `@Published` mutations.

---

### V004: ChatInputView.onChange - Synchronous @Binding Mutation

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatInputView.swift:128-138`

**Mutation Statements**:
```swift
132: text = trimmed
134: send() [which also mutates text]
```

**Causal Chain**:
```
SwiftUI view update pass
  → ChatInputView.body evaluation
    → TextEditor(text: $text) [line 116]
      → User types newline
        → .onChange(of: text) [line 128] ❌ EXECUTES DURING UPDATE PASS
          → text = trimmed [line 132] ❌ @Binding mutation during update
          → send() [line 134]
            → text = "" [additional mutation]
```

**Thread/Actor**: MainActor (during view update)

**Mechanism**: `.onChange` modifiers execute **during** the view update cycle when the observed value changes. Mutating the same `@Binding` that triggered the change creates a synchronous mutation during the update pass, violating the causal order.

**Evidence**: Direct `@Binding` mutation inside `.onChange` closure that observes the same binding.

---

### V005: ChatView.onChange - Deferred but Lifecycle-Triggered

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:57-64`

**Mutation Statements**:
```swift
61: conversation = current
62: chatViewModel.loadConversation(current)
```

**Causal Chain**:
```
SwiftUI view update pass
  → ChatView.body evaluation
    → .onChange(of: conversationBinding?.wrappedValue.id) [line 57] ❌ EXECUTES DURING UPDATE PASS
      → Task { @MainActor in } [line 59]
        → conversation = current [line 61] ❌ @State mutation (deferred but triggered from lifecycle)
        → chatViewModel.loadConversation(current) [line 62]
          → messages = conversation.messages [ChatViewModel:59] ❌ @Published mutation
          → streamingText = nil [ChatViewModel:60] ❌ @Published mutation
```

**Thread/Actor**: MainActor (Task schedules on next runloop, but triggered from update pass)

**Mechanism**: While the mutations are deferred via `Task`, they are still **triggered** from `.onChange`, which executes during the update pass. The `Task` schedules the work for the next runloop, but the causal chain originates in the update pass, creating a potential violation.

**Evidence**: Mutations wrapped in `Task` but triggered from lifecycle modifier.

---

### V006: ChatView.onAppear - Deferred but Lifecycle-Triggered

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:65-72`

**Mutation Statements**:
```swift
69: conversation = current
70: chatViewModel.loadConversation(current)
```

**Causal Chain**:
```
SwiftUI view update pass (view appears)
  → ChatView.body evaluation
    → .onAppear [line 65] ❌ EXECUTES DURING UPDATE PASS
      → Task { @MainActor in } [line 67]
        → conversation = current [line 69] ❌ @State mutation (deferred but triggered from lifecycle)
        → chatViewModel.loadConversation(current) [line 70]
          → [Same as V005]
```

**Thread/Actor**: MainActor (Task schedules on next runloop)

**Mechanism**: Same as V005 - mutations are deferred but triggered from `.onAppear`, which executes during the update pass.

**Evidence**: Mutations wrapped in `Task` but triggered from lifecycle modifier.

---

### V009: ChatViewModel.bindSelection() - Combine Subscription Mutation

**File**: `UIConnections/Sources/UIConnections/Conversation/ChatViewModel.swift:138-156`

**Mutation Statements**:
```swift
143: self.model = choice
152: self.contextScope = choice
```

**Causal Chain**:
```
ContextSelectionState.modelChoice changes
  → @Published publisher emits
    → Combine .sink [line 140] ❌ MAY FIRE DURING UPDATE PASS
      → self.model = choice [line 143] ❌ @Published mutation
      
ContextSelectionState.scopeChoice changes
  → @Published publisher emits
    → Combine .sink [line 149] ❌ MAY FIRE DURING UPDATE PASS
      → self.contextScope = choice [line 152] ❌ @Published mutation
```

**Thread/Actor**: MainActor (Combine publishers on main thread)

**Mechanism**: Combine subscriptions can fire synchronously when the publisher emits, which can occur during a view update pass if the source `@Published` property was mutated as part of that update. The `.sink` closure then mutates another `@Published` property, creating a nested mutation during the update pass.

**Evidence**: `@Published` mutation from Combine subscription callback that may fire during update pass.

---

### V013: ConversationCoordinator.handleStreamingUpdate() - Subscription Mutation

**File**: `UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift:62-64, 101-114`

**Mutation Statements**:
```swift
109: viewModel.applyDelta(.assistantStreaming(streaming))
112: viewModel.finishStreaming()
```

**Causal Chain**:
```
WorkspaceConversationBindingViewModel.streamingMessages changes
  → @Published publisher emits
    → Combine .sink [line 62] ❌ MAY FIRE DURING UPDATE PASS
      → handleStreamingUpdate() [line 63]
        → viewModel.applyDelta(.assistantStreaming(streaming)) [line 109] ❌ @Published mutation
          → streamingText = aggregate [ChatViewModel:85] ❌ @Published mutation
        → viewModel.finishStreaming() [line 112] ❌ @Published mutation
          → messages.append(assistantMessage) [ChatViewModel:97] ❌ @Published mutation
          → streamingText = nil [ChatViewModel:99] ❌ @Published mutation
          → isSending = false [ChatViewModel:100] ❌ @Published mutation
```

**Thread/Actor**: MainActor (Combine publishers on main thread)

**Mechanism**: Same as V009 - Combine subscription fires when `streamingMessages` changes, which can occur during an update pass. The callback then mutates `@Published` properties via `applyDelta()` and `finishStreaming()`.

**Evidence**: `@Published` mutations from Combine subscription callback.

---

### V017: ContextInspector.onChange - clearBanner() Call

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift:80-84`

**Mutation Statements**:
```swift
82: contextPresentationViewModel.clearBanner()
```

**Causal Chain**:
```
SwiftUI view update pass
  → ContextInspector.body evaluation
    → .onChange(of: lastContextResult) [line 80] ❌ EXECUTES DURING UPDATE PASS
      → contextPresentationViewModel.clearBanner() [line 82]
        → bannerMessage = nil [ContextPresentationViewModel:24] ❌ @Published mutation
```

**Thread/Actor**: MainActor

**Mechanism**: `.onChange` executes during the update pass. `clearBanner()` mutates `@Published bannerMessage`, creating a synchronous mutation during the update pass.

**Evidence**: Verified - `clearBanner()` mutates `@Published bannerMessage` (ContextPresentationViewModel.swift:24).

---

### V018: ContextInspector.onChange - handleSelectionChange() with Task

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift:85-87, 275-303`

**Mutation Statements**:
```swift
277: filePreviewViewModel.clear()
278: fileStatsViewModel.clear()
279: folderStatsViewModel.clear()
280: currentFileURL = nil
281: currentFolderURL = nil
287: currentFolderURL = url
295: currentFileURL = url
```

**Causal Chain**:
```
SwiftUI view update pass
  → ContextInspector.body evaluation
    → .onChange(of: selectedNode?.path) [line 85] ❌ EXECUTES DURING UPDATE PASS
      → handleSelectionChange(newURL) [line 86]
        → [Synchronous @State mutations: lines 277-281, 287, 295]
        → Task { [line 289, 297]
          → await folderStatsViewModel.loadStats(for: url) [line 290]
          → await filePreviewViewModel.loadPreview(for: url) [line 298]
          → await fileStatsViewModel.loadStats(for: url) [line 299]
            → [These methods likely mutate @Published properties]
```

**Thread/Actor**: MainActor

**Mechanism**: `.onChange` triggers synchronous `@State` mutations and async tasks that may mutate `@Published` properties. The synchronous mutations occur during the update pass.

**Evidence**: `@State` mutations and async task triggers from `.onChange`.

---

### V022: ChatView.emptyState - Direct @Published Mutation

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:119`

**Mutation Statement**:
```swift
119: chatViewModel.text = $0
```

**Causal Chain**:
```
User gesture (button tap in ChatEmptyStateView)
  → onQuickAction closure [line 119]
    → chatViewModel.text = $0 ❌ @Published mutation
```

**Thread/Actor**: MainActor

**Mechanism**: Direct assignment to `@Published` property from button action closure.

**Evidence**: Direct `@Published` mutation from user action.

---

### V028: ChatView.handleMessageContext() - @State Mutations

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatView.swift:168-173`

**Mutation Statements**:
```swift
170: contextPopoverData = ctx
171: showMessageContextPopover = true
```

**Causal Chain**:
```
User gesture (button tap)
  → handleMessageContext(message) [line 168]
    → contextPopoverData = ctx [line 170] ❌ @State mutation
    → showMessageContextPopover = true [line 171] ❌ @State mutation
```

**Thread/Actor**: MainActor

**Mechanism**: Synchronous `@State` mutations from button action. While `@State` mutations from user actions are generally acceptable, if this triggers a view update that causes nested mutations, it could be problematic.

**Evidence**: Direct `@State` mutations from user action.

---

## D) Repro Steps + Correlation to Console Warnings

### Warning 1: ChatViewModel.swift:72-73

**Console Warning** (expected):
```
Publishing changes from within view updates is not allowed; this will cause undefined behavior.
```

**Repro Steps**:
1. Launch app
2. Open chat view
3. Type a message in the input field
4. Click "Send" button
5. **Observe**: Warning appears because `commitMessage()` mutates `@Published text` and `@Published isSending` synchronously from the button action

**Correlation to Ledger**: **V001** - Direct synchronous `@Published` mutations in `commitMessage()`

**Exact Code Path**:
```
Button tap → ChatInputBar.send() → onSend() → ChatView.sendMessage() → chatViewModel.commitMessage()
  → Line 72: text = "" ❌
  → Line 73: isSending = true ❌
```

---

### Warning 2: ChatInputBar.swift:79

**Console Warning** (expected):
```
Publishing changes from within view updates is not allowed; this will cause undefined behavior.
```

**Repro Steps**:
1. Launch app
2. Open chat view
3. Type a message in the input field
4. Click "Send" button
5. **Observe**: Warning appears because `send()` mutates `@Binding text` synchronously after calling `onSend()`

**Correlation to Ledger**: **V002** - Synchronous `@Binding` mutation in `send()`

**Exact Code Path**:
```
Button tap → ChatInputBar.send() [line 75]
  → onSend() [line 78]
  → text = "" [line 79] ❌ (mutates @Binding which is bound to @Published chatViewModel.text)
```

---

### Warning 3: ChatView.swift:125

**Console Warning** (expected):
```
Publishing changes from within view updates is not allowed; this will cause undefined behavior.
```

**Repro Steps**:
1. Launch app
2. Open chat view
3. Type a message in the input field
4. Click "Send" button
5. **Observe**: Warning appears because `sendMessage()` calls `commitMessage()` which mutates `@Published` properties

**Correlation to Ledger**: **V003** - Calls `commitMessage()` which contains synchronous `@Published` mutations

**Exact Code Path**:
```
Button tap → ChatView.sendMessage() [line 123]
  → chatViewModel.commitMessage() [line 125] ❌
    → [See V001 for mutations]
```

**Note**: This warning may be the same as Warning 1, as they share the same root cause (`commitMessage()`).

---

### Additional Repro: ChatInputView.onChange Violation

**Repro Steps**:
1. Launch app
2. Open chat view
3. Type text in input field
4. Press Enter (without Shift)
5. **Observe**: `.onChange(of: text)` fires, mutates `text` binding synchronously, then calls `send()`

**Correlation to Ledger**: **V004** - Synchronous `@Binding` mutation inside `.onChange` closure

**Exact Code Path**:
```
User types Enter → TextEditor updates text binding
  → .onChange(of: text) fires [line 128] ❌ (executes during update pass)
    → text = trimmed [line 132] ❌ (mutates @Binding during update)
    → send() [line 134]
      → text = "" [additional mutation]
```

---

### Additional Repro: Lifecycle Modifier Violations

**Repro Steps**:
1. Launch app
2. Navigate to chat view (triggers `.onAppear`)
3. Change conversation binding (triggers `.onChange`)
4. **Observe**: Mutations occur from lifecycle modifiers, potentially during update pass

**Correlation to Ledger**: **V005**, **V006** - Mutations triggered from lifecycle modifiers

---

## E) Next Fix Plan

Ready to propose corrections once audit is accepted.

