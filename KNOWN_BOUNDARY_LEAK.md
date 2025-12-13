# KNOWN BOUNDARY LEAK

**Status:** Identified, Contained, Accepted  
**Date:** Architectural stabilization audit  
**Resolution:** Deferred (requires future AppCoreEngine protocol)

---

## LEAK DESCRIPTION

UIConnections public APIs expose the concrete domain type `ConversationEngineLive` in two locations:

1. **`createWorkspaceCoordinator`** (public function)
   - **File:** `UIConnections/Sources/UIConnections/Factories/CoordinatorFactories.swift:17`
   - **Parameter:** `conversationEngine: ConversationEngineLive<Client, Persistence>`
   - **Usage:** Called from `AppComposition/Sources/AppComposition/ChatUIHost.swift:72`

2. **`ConversationEngineBox.init`** (public initializer)
   - **File:** `UIConnections/Sources/UIConnections/Adapters/ConversationEngineBox.swift:14`
   - **Parameter:** `engine: ConversationEngineLive<Client, Persistence>`
   - **Usage:** Called from `AppComposition/Sources/AppComposition/AppContainer.swift:67`

---

## WHY THIS IS UNAVOIDABLE TODAY

The `ConversationEngine` protocol in AppCoreEngine uses associated types:
- `associatedtype ConversationType`
- `associatedtype MessageType`
- `associatedtype ContextResult`
- `associatedtype StreamEvent`

Swift's type system requires concrete types when working with protocols that have associated types in generic contexts. The factory functions and adapters must accept the concrete `ConversationEngineLive` type to satisfy these generic constraints.

---

## REQUIRED RESOLUTION (FUTURE)

This leak can only be resolved by introducing a protocol in AppCoreEngine that:
1. `ConversationEngineLive` conforms to
2. Represents the capability to be adapted/streamed
3. Does not expose implementation details
4. Can be used in UIConnections public APIs without leaking concrete types

**This is outside the current scope and will be addressed in a future architectural refinement.**

---

## CONTAINMENT STATUS

✅ **Contained:** Only these two public symbols expose the concrete type  
✅ **No Spread:** No other public APIs in UIConnections reference concrete AppCoreEngine implementations  
✅ **Documented:** This document serves as explicit acknowledgment  
✅ **Accepted:** This is a known, contained architectural impurity

---

## ARCHITECTURAL IMPACT

- **Violation:** UIConnections public API exposes concrete domain implementation
- **Severity:** Medium (affects API boundary, but does not break functionality)
- **Mitigation:** Documented and contained; no further spread
- **Future Work:** Requires protocol abstraction in AppCoreEngine

---

**This leak is an accepted architectural impurity until the required abstraction is introduced in AppCoreEngine.**

