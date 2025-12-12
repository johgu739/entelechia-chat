# SwiftUI Mutation Discipline: Foundational Correction Plan

**Date**: December 2025  
**Phase**: 2 - Architectural Design (Pre-Implementation)  
**Status**: 🟡 **DESIGN PHASE - AWAITING APPROVAL**

---

## 1) RE-STATED OUGHT: Canonical SwiftUI Causal Model

### The Pure Projection Principle

SwiftUI views are **pure mathematical projections** of state onto a render surface. A view's `body` is a function `State → View`, and this function must be **referentially transparent**: given the same state, it must produce the same view, with no side effects, no mutations, no hidden dependencies.

### The Causal Order Invariant

The system enforces a strict temporal ordering:

```
Render (pure read) → Intent (event) → Mutation (state write) → Next Render
```

This is not a suggestion or a best practice. It is a **categorical requirement** of SwiftUI's architecture. Violations produce undefined behavior because they break the assumption that view evaluation is idempotent and side-effect-free.

### Intent Boundaries vs. Render Boundaries

**Render boundaries** are where SwiftUI evaluates view hierarchies:
- View `body` evaluation
- Lifecycle modifier execution (`.onAppear`, `.onChange`, `.onReceive`)
- Preference propagation
- Animation interpolation

**Intent boundaries** are where external events enter the system:
- User gestures (button taps, text input, drags)
- System events (notifications, timers)
- Async operation completions (network responses, file I/O)

**Critical distinction**: Render boundaries are **observational** and **read-only**. Intent boundaries are **imperative** and **write-capable**.

### State Transition Loci

State mutation is legitimate **only** at a single, explicit mutation layer that:
1. Receives intents from intent boundaries
2. Operates outside the render cycle
3. Performs atomic state transitions
4. Emits state changes that trigger re-renders

This mutation layer must be **decoupled from view update timing**. It cannot be:
- A method called directly from view code
- A closure executed during `body` evaluation
- A callback fired synchronously from lifecycle modifiers
- A Combine sink that mutates state directly

### The Observer Pattern Constraint

Lifecycle modifiers (`.onAppear`, `.onChange`, `.onReceive`) are **observers**, not **actors**. They observe state changes and may:
- Read state
- Enqueue intents for later processing
- Trigger side effects that do not mutate SwiftUI-observed state

They may **not**:
- Mutate `@State`, `@Binding`, or `@Published` properties
- Call methods that mutate state synchronously
- Trigger mutations that could occur during the update pass

### Combine as Signal Transport

Combine subscriptions are **signal transport mechanisms**, not **state mutation surfaces**. A `.sink` may:
- Forward signals to an intent dispatcher
- Transform and route events
- Trigger side effects that do not mutate SwiftUI-observed state

A `.sink` may **not**:
- Mutate `@Published` properties directly
- Call methods that mutate state synchronously
- Assume it executes outside the render cycle

---

## 2) TARGET ARCHITECTURE

### 2.1 Intent Boundary: Command Dispatcher Pattern

**Location**: `ChatViewModel` and `WorkspaceConversationBindingViewModel` expose an intent API.

**Structure**:
```swift
// Intent types (value types, no mutation)
enum ChatIntent {
    case sendMessage(String)
    case askCodex(String)
    case clearText
    case selectModel(ModelChoice)
    case selectScope(ContextScopeChoice)
    case loadConversation(Conversation)
}

// ViewModel exposes intent handler, not mutation methods
@MainActor
class ChatViewModel: ObservableObject {
    func handle(_ intent: ChatIntent) { /* mutation boundary */ }
}
```

**Invariant**: Views may only call `handle(_ intent:)`. They may never call methods that mutate state directly (e.g., `commitMessage()`, `clearText()`, property setters).

**Rationale**: This creates a **single mutation boundary** per ViewModel. All state changes flow through one method, which can enforce timing guarantees and atomicity.

### 2.2 Mutation Discipline: Laws

**Law 1: View Purity**
Views may **request** mutations via intent dispatch. Views may **never** perform mutations.

**Law 2: Intent Isolation**
Intent handlers execute in a context decoupled from view update timing. They may:
- Mutate `@Published` properties
- Trigger async operations
- Coordinate with other ViewModels

They execute **after** the view update pass completes, not during it.

**Law 3: Lifecycle Modifier Constraint**
Lifecycle modifiers (`.onAppear`, `.onChange`, `.onReceive`) may:
- Read state
- Enqueue intents via `Task { @MainActor in viewModel.handle(.loadConversation(...)) }`
- Trigger side effects that do not mutate SwiftUI-observed state

They may **never**:
- Mutate `@State`, `@Binding`, or `@Published` properties
- Call methods that mutate state synchronously

**Law 4: Combine Sink Constraint**
Combine `.sink` closures may:
- Forward events to intent dispatchers: `viewModel.handle(.streamingUpdate(...))`
- Transform and route signals

They may **never**:
- Mutate `@Published` properties directly
- Call methods that mutate state synchronously

**Law 5: Binding Mutability**
`@Binding` properties are **read-write conduits** to state. Views may:
- Read from bindings
- Write to bindings **only** in response to user input (text field changes, toggle flips)

Views may **not**:
- Write to bindings in lifecycle modifiers
- Write to bindings in response to state changes (creates feedback loops)
- Write to bindings after dispatching intents (intent handler should update state, not view)

**Law 6: Async Mutation Guarantee**
If a mutation must occur after an async operation completes, the mutation must:
- Be enqueued in the async completion handler
- Execute via `Task { @MainActor in }` or `await MainActor.run { }`
- Not be triggered from a lifecycle modifier's synchronous closure

---

## 3) VIOLATION → STRUCTURAL CAUSE MAPPING

### Category A: Direct Mutation from View Actions (V001-V003, V022, V028-V031)

**Violations**: V001, V002, V003, V022, V028, V029, V030, V031

**Structural Cause**: ViewModels expose mutation methods (`commitMessage()`, `clearText()`, property setters) that are called directly from view action closures. These methods execute synchronously in the same call stack as the view update, violating the causal order.

**Missing Abstraction**: An intent dispatcher that decouples mutation timing from view update timing.

**Architectural Rule Violated**: Law 1 (View Purity) and Law 2 (Intent Isolation).

**Correction**: 
- Remove public mutation methods from ViewModels
- Introduce `ChatIntent` enum and `handle(_ intent:)` method
- Views dispatch intents instead of calling mutation methods
- Intent handler performs mutations in a guaranteed post-update context

**Eliminated Mutation Sites**:
- `ChatViewModel.commitMessage()` → becomes `handle(.sendMessage(text))`
- `ChatViewModel.clearText()` → becomes `handle(.clearText)`
- `ChatViewModel.text = value` → becomes `handle(.updateText(value))`
- `ChatInputBar.send()` → dispatches intent, does not mutate binding
- `ChatView.sendMessage()` → dispatches intent, does not call `commitMessage()`

---

### Category B: Lifecycle Modifier Mutations (V004-V008, V017-V018, V019-V021)

**Violations**: V004, V005, V006, V007, V008, V017, V018, V019, V020, V021

**Structural Cause**: Lifecycle modifiers (`.onAppear`, `.onChange`, `.onPreferenceChange`) execute during the view update pass. Mutations triggered from these closures occur synchronously during rendering, violating the causal order.

**Missing Abstraction**: A mechanism to enqueue intents from lifecycle modifiers without executing mutations synchronously.

**Architectural Rule Violated**: Law 3 (Lifecycle Modifier Constraint).

**Correction**:
- Lifecycle modifiers enqueue intents via `Task { @MainActor in viewModel.handle(...) }`
- Intent handler executes mutations after the update pass completes
- Remove all direct state mutations from lifecycle modifier closures
- For `.onChange` observing a binding: do not mutate the same binding; instead, observe the underlying state and dispatch intents

**Eliminated Mutation Sites**:
- `ChatInputView.onChange(of: text)` → enqueues intent instead of mutating binding
- `ChatView.onChange(of: conversationBinding?.wrappedValue.id)` → enqueues intent
- `ChatView.onAppear` → enqueues intent
- `ContextInspector.onChange(of: lastContextResult)` → enqueues intent
- `ContextInspector.onChange(of: selectedNode?.path)` → enqueues intent
- `ChatMessagesList.onChange(of: messages.count)` → animation-only (no state mutation)
- `InputTextArea.onPreferenceChange` → enqueues intent if mutation needed

---

### Category C: Combine Subscription Mutations (V009-V010, V013-V014)

**Violations**: V009, V010, V013, V014

**Structural Cause**: Combine `.sink` closures mutate `@Published` properties directly. These closures may fire synchronously when publishers emit, which can occur during a view update pass, creating nested mutations.

**Missing Abstraction**: A routing layer that forwards Combine signals to intent dispatchers instead of mutating state directly.

**Architectural Rule Violated**: Law 4 (Combine Sink Constraint).

**Correction**:
- Combine sinks forward events to intent dispatchers: `viewModel.handle(.streamingUpdate(...))`
- Intent handler performs mutations in a guaranteed post-update context
- Remove all direct `@Published` mutations from `.sink` closures

**Eliminated Mutation Sites**:
- `ChatViewModel.bindSelection()` → sinks forward to intent dispatcher
- `ConversationCoordinator.handleStreamingUpdate()` → forwards to intent dispatcher
- `ConversationCoordinator.handleCodexError()` → forwards to intent dispatcher

---

### Category D: Async Callback Mutations (V015-V016, V023-V027, V032)

**Violations**: V015, V016, V023, V024, V025, V026, V027, V032

**Structural Cause**: Async operation completion handlers mutate state. While wrapped in `Task { @MainActor in }`, these mutations are still triggered from callbacks that may fire during view updates or from lifecycle modifiers.

**Missing Abstraction**: Async operations should complete by dispatching intents, not by mutating state directly.

**Architectural Rule Violated**: Law 6 (Async Mutation Guarantee) and Law 3 (if triggered from lifecycle).

**Correction**:
- Async operations complete by dispatching intents: `viewModel.handle(.asyncOperationComplete(result))`
- Intent handler performs mutations
- Remove direct state mutations from async completion handlers

**Eliminated Mutation Sites**:
- `WorkspaceConversationBindingViewModel.askCodex()` streaming callback → dispatches intent
- `WorkspaceConversationBindingViewModel.buildStreamHandler()` → dispatches intent
- `ChatView.sendMessage()` async completion → dispatches intent
- `ChatView.reask()` async completion → dispatches intent
- `ChatViewModel.askCodex()` async completion → dispatches intent

---

## 4) CORRECTED FLOW DIAGRAMS

### Flow 1: Sending a Message

**BEFORE (Violating)**:
```
User Tap "Send" Button
  → ChatInputBar.send() [button action]
    → onSend() closure
      → ChatView.sendMessage() [button action]
        → chatViewModel.commitMessage() ❌ SYNCHRONOUS MUTATION
          → text = "" ❌ @Published mutation during update
          → isSending = true ❌ @Published mutation during update
        → Task { await startStreaming() }
          → [async work]
            → await MainActor.run { mutations } ❌ Still triggered from view action
```

**AFTER (Correct)**:
```
User Tap "Send" Button
  → ChatInputBar.send() [button action - intent boundary]
    → chatViewModel.handle(.sendMessage(text)) ✅ INTENT DISPATCH
      → [Intent handler executes AFTER update pass]
        → text = "" ✅ @Published mutation (post-update)
        → isSending = true ✅ @Published mutation (post-update)
        → messages.append(userMessage) ✅ @Published mutation (post-update)
        → Task { await coordinator.stream(...) }
          → [async work]
            → coordinator emits streaming deltas
              → Combine publisher emits
                → ConversationCoordinator.sink
                  → chatViewModel.handle(.streamingDelta(...)) ✅ INTENT DISPATCH
                    → streamingText = aggregate ✅ @Published mutation (post-update)
```

**Key Changes**:
- `commitMessage()` eliminated
- `send()` dispatches intent, does not mutate binding
- `sendMessage()` dispatches intent, does not call mutation methods
- Streaming updates flow through intent dispatcher
- All mutations occur in intent handler, guaranteed post-update

---

### Flow 2: Streaming Updates

**BEFORE (Violating)**:
```
WorkspaceConversationBindingViewModel.streamingMessages changes
  → @Published publisher emits
    → ConversationCoordinator.sink ❌ EXECUTES DURING UPDATE PASS
      → handleStreamingUpdate()
        → viewModel.applyDelta(.assistantStreaming(...)) ❌ SYNCHRONOUS MUTATION
          → streamingText = aggregate ❌ @Published mutation during update
```

**AFTER (Correct)**:
```
WorkspaceConversationBindingViewModel.streamingMessages changes
  → @Published publisher emits
    → ConversationCoordinator.sink ✅ SIGNAL TRANSPORT
      → chatViewModel.handle(.streamingDelta(.assistantStreaming(...))) ✅ INTENT DISPATCH
        → [Intent handler executes AFTER update pass]
          → streamingText = aggregate ✅ @Published mutation (post-update)
```

**Key Changes**:
- `.sink` forwards to intent dispatcher, does not mutate
- `applyDelta()` eliminated or made private (only called from intent handler)
- Mutations occur in intent handler, guaranteed post-update

---

### Flow 3: Conversation Switching

**BEFORE (Violating)**:
```
Conversation binding changes
  → ChatView.onChange(of: conversationBinding?.wrappedValue.id) ❌ EXECUTES DURING UPDATE PASS
    → Task { @MainActor in
        conversation = current ❌ @State mutation (triggered from lifecycle)
        chatViewModel.loadConversation(current) ❌ @Published mutation (triggered from lifecycle)
      }
```

**AFTER (Correct)**:
```
Conversation binding changes
  → ChatView.onChange(of: conversationBinding?.wrappedValue.id) ✅ OBSERVER
    → Task { @MainActor in
        chatViewModel.handle(.loadConversation(current)) ✅ INTENT DISPATCH
      }
      → [Intent handler executes AFTER update pass]
        → messages = conversation.messages ✅ @Published mutation (post-update)
        → streamingText = nil ✅ @Published mutation (post-update)
      → [Separate intent for @State update]
        → chatViewModel.handle(.updateLocalConversation(current)) ✅ INTENT DISPATCH
          → [View observes ViewModel state, updates @State if needed]
```

**Key Changes**:
- `.onChange` enqueues intent, does not mutate state
- `loadConversation()` eliminated or made private
- `@State` updates flow through ViewModel state (single source of truth)
- Mutations occur in intent handler, guaranteed post-update

---

### Flow 4: Context Selection

**BEFORE (Violating)**:
```
ContextSelectionState.modelChoice changes
  → @Published publisher emits
    → ChatViewModel.sink ❌ EXECUTES DURING UPDATE PASS
      → self.model = choice ❌ @Published mutation during update
```

**AFTER (Correct)**:
```
ContextSelectionState.modelChoice changes
  → @Published publisher emits
    → ChatViewModel.sink ✅ SIGNAL TRANSPORT
      → self.handle(.selectModel(choice)) ✅ INTENT DISPATCH
        → [Intent handler executes AFTER update pass]
          → model = choice ✅ @Published mutation (post-update)
```

**Key Changes**:
- `.sink` forwards to intent dispatcher, does not mutate
- Mutations occur in intent handler, guaranteed post-update

---

### Flow 5: Text Input with Newline Handling

**BEFORE (Violating)**:
```
User types Enter in TextEditor
  → TextEditor updates text binding
    → ChatInputView.onChange(of: text) ❌ EXECUTES DURING UPDATE PASS
      → text = trimmed ❌ @Binding mutation during update
      → send() ❌ Additional mutation
```

**AFTER (Correct)**:
```
User types Enter in TextEditor
  → TextEditor updates text binding ✅ USER INPUT (intent boundary)
    → ChatInputView.onChange(of: text) ✅ OBSERVER (reads only)
      → if newline detected:
          → chatViewModel.handle(.sendMessage(text)) ✅ INTENT DISPATCH
            → [Intent handler executes AFTER update pass]
              → text = "" ✅ @Published mutation (post-update)
              → [message sending logic]
```

**Key Changes**:
- `.onChange` does not mutate binding
- `.onChange` dispatches intent if action needed
- Intent handler clears text, guaranteed post-update

---

## 5) CONVERSION STRATEGY

### Phase 1: Introduce Intent Abstraction (Non-Breaking)

**Step 1.1**: Define intent types alongside existing code
- Create `ChatIntent` enum
- Create `WorkspaceIntent` enum (if needed)
- Add `handle(_ intent:)` methods to ViewModels
- Implement intent handlers that call existing mutation methods internally

**Step 1.2**: Verify no behavior change
- All existing code paths still work
- Intent handlers are thin wrappers around existing methods
- No SwiftUI warnings yet (we haven't changed call sites)

**Deliverable**: Intent abstraction exists but is unused.

---

### Phase 2: Migrate View Actions (One Flow at a Time)

**Step 2.1**: Migrate message sending
- Update `ChatInputBar.send()` to dispatch intent
- Update `ChatView.sendMessage()` to dispatch intent
- Remove `commitMessage()` public API
- Verify: zero SwiftUI warnings for message sending
- Verify: behavior unchanged

**Step 2.2**: Migrate streaming updates
- Update `ConversationCoordinator` sinks to dispatch intents
- Remove `applyDelta()` public API (or make private)
- Verify: zero SwiftUI warnings for streaming
- Verify: behavior unchanged

**Step 2.3**: Migrate conversation loading
- Update `ChatView.onChange` to dispatch intent
- Update `ChatView.onAppear` to dispatch intent
- Remove `loadConversation()` public API (or make private)
- Verify: zero SwiftUI warnings for conversation switching
- Verify: behavior unchanged

**Step 2.4**: Migrate context selection
- Update `ChatViewModel.bindSelection()` sinks to dispatch intents
- Verify: zero SwiftUI warnings for context selection
- Verify: behavior unchanged

**Deliverable**: All view actions route through intent dispatcher.

---

### Phase 3: Migrate Lifecycle Modifiers

**Step 3.1**: Migrate `.onChange` modifiers
- Update `ChatInputView.onChange(of: text)` to dispatch intent
- Update `ContextInspector.onChange` modifiers to dispatch intents
- Verify: zero SwiftUI warnings from lifecycle modifiers
- Verify: behavior unchanged

**Step 3.2**: Migrate `.onAppear` modifiers
- Update `ChatView.onAppear` to dispatch intent
- Verify: zero SwiftUI warnings from `.onAppear`
- Verify: behavior unchanged

**Deliverable**: All lifecycle modifiers enqueue intents, never mutate.

---

### Phase 4: Migrate Combine Subscriptions

**Step 4.1**: Migrate ViewModel subscriptions
- Update `ChatViewModel.bindSelection()` to forward intents
- Verify: zero SwiftUI warnings from subscriptions
- Verify: behavior unchanged

**Step 4.2**: Migrate Coordinator subscriptions
- Update `ConversationCoordinator` sinks to forward intents
- Verify: zero SwiftUI warnings from subscriptions
- Verify: behavior unchanged

**Deliverable**: All Combine subscriptions forward to intent dispatcher.

---

### Phase 5: Migrate Async Callbacks

**Step 5.1**: Migrate streaming callbacks
- Update `WorkspaceConversationBindingViewModel` streaming callbacks to dispatch intents
- Verify: zero SwiftUI warnings from async callbacks
- Verify: behavior unchanged

**Step 5.2**: Migrate async operation completions
- Update `ChatView.sendMessage()` async completion to dispatch intent
- Update `ChatView.reask()` async completion to dispatch intent
- Verify: zero SwiftUI warnings from async completions
- Verify: behavior unchanged

**Deliverable**: All async callbacks dispatch intents, never mutate directly.

---

### Phase 6: Cleanup and Verification

**Step 6.1**: Remove obsolete mutation methods
- Delete `commitMessage()` (replaced by intent)
- Delete `clearText()` (replaced by intent)
- Delete `loadConversation()` (replaced by intent)
- Make `applyDelta()` private (only called from intent handler)

**Step 6.2**: Final verification
- Zero SwiftUI mutation warnings
- All tests pass
- Behavior unchanged
- Code review: no mutation sites outside intent handlers

**Deliverable**: System is architecturally correct.

---

## 6) SUCCESS CRITERIA

### Criterion 1: Warnings Eliminated by Architecture

SwiftUI mutation warnings disappear **because violations are architecturally impossible**, not because they are hidden or deferred.

**Verification**:
- Search codebase for direct `@Published` property assignments outside intent handlers: **zero results**
- Search for `@Binding` mutations in lifecycle modifiers: **zero results**
- Search for mutation method calls from view code: **zero results**

**Not acceptable**:
- Warnings suppressed via `#warning` or compiler flags
- Mutations wrapped in `DispatchQueue.main.async` as a band-aid
- Mutations wrapped in `Task { @MainActor in }` without architectural justification

---

### Criterion 2: View Purity

Views contain zero state mutation logic.

**Verification**:
- Views only call `viewModel.handle(_ intent:)`
- Views never call methods that mutate state
- Views never assign to `@Published` properties directly
- Views never mutate `@Binding` except in response to user input (text field, toggle)

**Not acceptable**:
- Views calling `commitMessage()`, `clearText()`, `loadConversation()`
- Views assigning to `viewModel.text`, `viewModel.isSending`, etc.
- Views mutating bindings in lifecycle modifiers

---

### Criterion 3: Lifecycle Modifier Constraint

Lifecycle modifiers only enqueue intents or read state.

**Verification**:
- `.onAppear` closures only dispatch intents or read state
- `.onChange` closures only dispatch intents or read state
- `.onReceive` closures only dispatch intents or read state
- No direct state mutations in lifecycle modifier closures

**Not acceptable**:
- `.onChange` mutating the same binding it observes
- `.onAppear` calling mutation methods
- Lifecycle modifiers triggering synchronous mutations

---

### Criterion 4: Combine Sink Constraint

Combine sinks never mutate published state directly.

**Verification**:
- `.sink` closures only forward to intent dispatchers
- No direct `@Published` property assignments in `.sink` closures
- No calls to mutation methods from `.sink` closures

**Not acceptable**:
- `.sink { self.property = value }`
- `.sink { self.mutate() }`

---

### Criterion 5: Causal Structure Explainable

The system's causal structure can be explained without referencing SwiftUI scheduling quirks.

**Verification**:
- Intent flow is explicit and traceable
- Mutation sites are enumerated and justified
- No reliance on "SwiftUI usually schedules this later"
- No reliance on "In practice this is fine"
- No reliance on "This avoids the warning"

**Explanation**:
- User actions → intent dispatcher → mutation handler → state update → re-render
- Lifecycle events → intent dispatcher → mutation handler → state update → re-render
- Combine signals → intent dispatcher → mutation handler → state update → re-render
- Async completions → intent dispatcher → mutation handler → state update → re-render

**Not acceptable**:
- "This works because SwiftUI schedules mutations later"
- "This is fine in practice even though it's technically during update"
- "We wrapped it in Task so it's safe"

---

## 7) WHY THIS RESTORES CAUSAL CORRECTNESS

### The Category Error

The current system commits a **category error**: it treats mutation as a **callable operation** rather than a **state transition event**. Views call mutation methods as if they were functions, but mutation is not a function—it is a **side effect** that must occur at a specific point in the causal chain.

### The Intent Abstraction

By introducing an intent dispatcher, we restore the correct category:
- **Intents** are value types (events, not operations)
- **Mutation** is a side effect handled by a dedicated layer
- **Views** are pure projections that emit intents, never perform mutations

### The Temporal Decoupling

The intent dispatcher decouples mutation timing from view update timing:
- Views emit intents synchronously (acceptable at intent boundary)
- Intent handler executes mutations **after** the update pass completes
- This restores the causal order: Render → Intent → Mutation → Next Render

### The Single Mutation Boundary

By routing all mutations through a single boundary (the intent handler), we:
- Eliminate scattered mutation sites
- Enforce timing guarantees in one place
- Make the causal structure explicit and verifiable

### The Observer Pattern Restoration

Lifecycle modifiers and Combine subscriptions are restored to their correct role:
- They **observe** state changes
- They **forward** events to intent dispatchers
- They **never** mutate state directly

This restores the separation of concerns: observation vs. mutation.

---

## CONCLUSION

This plan restores causal correctness by:
1. **Introducing intent abstraction** to separate observation from mutation
2. **Decoupling mutation timing** from view update timing
3. **Enforcing single mutation boundary** per ViewModel
4. **Restoring observer pattern** for lifecycle modifiers and Combine subscriptions
5. **Making causal structure explicit** and verifiable

The result is a system where SwiftUI mutation warnings are **impossible** because violations are **architecturally forbidden**, not hidden or deferred.

**Status**: Ready for implementation approval.


