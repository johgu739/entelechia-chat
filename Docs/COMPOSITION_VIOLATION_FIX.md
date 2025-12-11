# Composition Violation Fix - ConversationCoordinator

**Date**: December 11, 2025  
**Status**: ✅ **COMPLETE - ARCHITECTURALLY CORRECT SOLUTION**

---

## Executive Summary

Fixed critical architectural violation in `ChatUIHost.swift` where `ConversationCoordinator` was being created in the view's `body`, causing it to be recreated on every view recomputation. The coordinator now has stable identity and is created once in `init()`.

---

## Problem

### Violation
```swift
public var body: some View {
    let coordinator = ConversationCoordinator(  // ❌ Created on every recomputation
        workspace: workspaceViewModel,
        contextSelection: contextSelectionState
    )
    // ...
}
```

### Why This Is Wrong
1. **Identity Instability**: Coordinator is recreated on every `body` recomputation
2. **Lost State**: Any internal state in the coordinator is lost
3. **Broken References**: Views holding references to the coordinator get stale instances
4. **Composition Violation**: Composition root must create stable dependencies exactly once

---

## Solution

### 1. Made ConversationCoordinator ObservableObject

**File**: `UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift`

**Change**:
```swift
@MainActor
public final class ConversationCoordinator: ObservableObject {  // ✅ Added ObservableObject
    // ...
}
```

**Reason**: Required for use with `@StateObject` property wrapper.

---

### 2. Added @StateObject Property

**File**: `AppComposition/Sources/AppComposition/ChatUIHost.swift`

**Change**:
```swift
@StateObject private var conversationCoordinator: ConversationCoordinator  // ✅ Added
```

**Reason**: Ensures coordinator has stable identity managed by SwiftUI.

---

### 3. Created Coordinator in init()

**File**: `AppComposition/Sources/AppComposition/ChatUIHost.swift`

**Change**:
```swift
public init(container: DependencyContainer = DefaultContainer()) {
    // ... existing initialization ...
    
    // Create ConversationCoordinator with stable identity
    let conversationCoord = ConversationCoordinator(
        workspace: workspaceVM,
        contextSelection: contextSelection
    )
    _conversationCoordinator = StateObject(wrappedValue: conversationCoord)  // ✅ Created once
}
```

**Reason**: Coordinator is created exactly once during initialization, ensuring stable identity.

---

### 4. Updated body to Use Stable Coordinator

**File**: `AppComposition/Sources/AppComposition/ChatUIHost.swift`

**Before**:
```swift
public var body: some View {
    let coordinator = ConversationCoordinator(  // ❌ Created in body
        workspace: workspaceViewModel,
        contextSelection: contextSelectionState
    )
    
    let context = WorkspaceContext(
        // ...
        chatViewModelFactory: { _ in
            ChatViewModel(
                coordinator: coordinator,  // ❌ Transient instance
                contextSelection: contextSelectionState
            )
        },
        coordinator: coordinator,  // ❌ Transient instance
        // ...
    )
}
```

**After**:
```swift
public var body: some View {
    let context = WorkspaceContext(
        workspaceViewModel: workspaceViewModel,
        chatViewModelFactory: { _ in
            ChatViewModel(
                coordinator: conversationCoordinator,  // ✅ Stable instance
                contextSelection: contextSelectionState
            )
        },
        coordinator: conversationCoordinator,  // ✅ Stable instance
        // ...
    )
}
```

**Reason**: Body now uses the stable coordinator instance, never creating new ones.

---

## Verification

### ✅ Build Status
```bash
swift build --package-path AppComposition
```
**Result**: ✅ **Build complete!**

### ✅ No Coordinator Creation in Body
```bash
grep "ConversationCoordinator(" AppComposition/Sources/AppComposition/ChatUIHost.swift
```
**Result**: Only 1 match (in `init()`, line 71) - ✅ **Correct**

### ✅ Coordinator Stored as @StateObject
```bash
grep "@StateObject.*conversationCoordinator" AppComposition/Sources/AppComposition/ChatUIHost.swift
```
**Result**: Found - ✅ **Correct**

### ✅ Factory Closure Captures Stable References
- `conversationCoordinator`: Stable `@StateObject` instance
- `contextSelectionState`: Stable `let` property
- ✅ **No transient state captured**

### ✅ ArchitectureGuardian
- No violations for coordinator creation in ChatUI
- No violations for coordinator creation in AppComposition
- ✅ **All architectural rules satisfied**

---

## Architectural Principles Enforced

### 1. ✅ Identity Stability
- Coordinator has stable identity for lifetime of `ChatUIHost`
- Never recreated on view recomputation

### 2. ✅ Composition Root Responsibility
- All non-value dependencies created in `init()`
- No dependency creation in `body`

### 3. ✅ Factory Closure Purity
- Factory captures only stable references
- No transient mutable state captured

### 4. ✅ Proper Lifecycle Management
- Coordinator managed by SwiftUI via `@StateObject`
- Clean deallocation when view is removed

---

## Files Modified

1. **`UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift`**
   - Added `ObservableObject` conformance

2. **`AppComposition/Sources/AppComposition/ChatUIHost.swift`**
   - Added `@StateObject private var conversationCoordinator`
   - Created coordinator in `init()`
   - Updated `body` to use stable coordinator

---

## Result

**Status**: ✅ **COMPLETE - ARCHITECTURALLY CORRECT**

- ✅ Coordinator has stable identity
- ✅ Created once in `init()`
- ✅ Never recreated in `body`
- ✅ Factory captures stable references
- ✅ All architectural rules satisfied
- ✅ Build successful

The composition root now correctly manages coordinator lifecycle, ensuring architectural purity and preventing identity instability issues.

---

**Fix Complete** ✅
