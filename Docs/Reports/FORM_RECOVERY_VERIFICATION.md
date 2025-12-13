# FORM RECOVERY — ARCHITECTURAL VERIFICATION REPORT

**Date**: 2025-01-27  
**Scope**: Verification of form recovery implementation against plan requirements  
**Method**: Static code analysis, dependency tracing, power verification

---

## VERDICT: **FAIL**

The implementation is **incomplete**. Critical violations remain that prevent the system from meeting the success conditions.

---

## VIOLATIONS

### **VIOLATION 1: WorkspaceViewModel Extensions Still Contain Orchestration Logic**

**Location**: `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Conversation.swift`

**Evidence**:
- Lines 49-204: Full implementation of `sendMessage()` and `askCodex()` remains in extension
- Lines 83-139: Private orchestration methods (`hasContextAnchor`, `buildContextRequest`, `sendMessageWithContext`, `buildStreamHandler`, `handleSendMessageError`) still present
- Direct access to `workspaceSnapshot`, `codexContextByMessageID`, `conversationEngine`, `codexService`

**Required State**: These methods should delegate to `WorkspaceCoordinator` or be removed entirely.

**Severity**: **CRITICAL** — Violates Contradiction 2 (WorkspaceViewModel exercises multiple powers)

---

### **VIOLATION 2: WorkspaceViewModel Extensions Still Contain State Management Logic**

**Location**: `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Loading.swift`

**Evidence**:
- Lines 5-48: `openWorkspace()`, `selectPath()`, `applyUpdate()`, `subscribeToUpdates()` still implemented in extension
- Direct access to `workspaceEngine`, `workspaceSnapshot`
- Line 51: `workspaceSnapshot = update.snapshot` — direct state mutation

**Required State**: These should be in `WorkspaceCoordinator` (orchestration) or `WorkspaceStateObserver` (observation).

**Severity**: **CRITICAL** — Violates Contradiction 2

---

### **VIOLATION 3: WorkspaceViewModel Extensions Still Contain Decision Logic**

**Location**: `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+Context.swift`

**Evidence**:
- Lines 34-60: `currentWorkspaceScope()` implemented in extension
- Lines 62-157: `buildContextSnapshot()` and helper methods still in extension
- Direct access to `workspaceSnapshot`, `workspaceEngine`

**Required State**: Decision logic should be in `WorkspaceCoordinator`.

**Severity**: **CRITICAL** — Violates Contradiction 2

---

### **VIOLATION 4: Direct Error Publishing in WorkspaceViewModel Extensions**

**Location**: Multiple extension files

**Evidence**:
- `WorkspaceViewModel+Conversation.swift` lines 90-96, 145-151, 167, 201: Direct `alertCenter?.publish()` and `contextErrorSubject.send()`
- `WorkspaceViewModel+Errors.swift` line 12: `alertCenter?.publish()` in `handleFileSystemError()`
- `WorkspaceViewModel+Conversation.swift` lines 29, 45: Direct error publishing in `ensureConversation()` methods

**Required State**: All errors must flow through `DomainErrorAuthority`.

**Severity**: **CRITICAL** — Violates Contradiction 4 (Error authority is multiple)

---

### **VIOLATION 5: WorkspaceViewModel Creates Its Own DomainErrorAuthority**

**Location**: `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift` line 172

**Evidence**:
```swift
// Note: DomainErrorAuthority will be injected via ChatUIHost in the future
// For now, create a temporary one (this will be fixed when ChatUIHost is updated)
let errorAuthority = DomainErrorAuthority()
```

**Required State**: `DomainErrorAuthority` must be injected via dependency injection, not created internally.

**Severity**: **HIGH** — Violates composition order and single error authority principle

---

### **VIOLATION 6: CodexMutationPipeline Still Exists in UIConnections**

**Location**: `UIConnections/Sources/UIConnections/Codex/CodexMutationPipeline.swift`

**Evidence**: File still exists with full implementation (lines 1-51)

**Required State**: Per plan step 2.10, this file should have been deleted. The `UnifiedDiffParser` logic was moved to `FileMutationService`, but the pipeline wrapper remains.

**Severity**: **MEDIUM** — Dead code, but not blocking

---

### **VIOLATION 7: WorkspaceViewModel Still Exposes Legacy Error Publisher**

**Location**: `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel+State.swift` lines 59-61

**Evidence**:
```swift
var contextErrorPublisher: AnyPublisher<Error, Never> {
    contextErrorSubject.eraseToAnyPublisher()
}
```

**Required State**: This should be removed. `ChatUIHost` was updated to use `errorRouter.contextErrorPublisher`, but the legacy publisher remains.

**Severity**: **MEDIUM** — Backward compatibility, but should be removed

---

### **VIOLATION 8: WorkspaceViewModel Still Holds Direct Engine Dependencies**

**Location**: `UIConnections/Sources/UIConnections/Workspaces/WorkspaceViewModel.swift` lines 127-135

**Evidence**:
```swift
let workspaceEngine: WorkspaceEngine
let conversationEngine: ConversationStreaming
let projectTodosLoader: ProjectTodosLoading
let codexService: CodexQuerying
var alertCenter: AlertCenter?
let contextSelection: ContextSelectionState
let logger = Logger(subsystem: "UIConnections", category: "WorkspaceViewModel")
let contextErrorSubject = PassthroughSubject<Error, Never>()
```

**Required State**: These should be removed from `WorkspaceViewModel`. The extensions access them directly, but they should only exist in `WorkspaceCoordinator`.

**Severity**: **HIGH** — Enables violations in extensions

---

### **VIOLATION 9: WorkspacePresentationModel Contains Domain-Derived State**

**Location**: `UIConnections/Sources/UIConnections/Workspaces/WorkspacePresentationModel.swift` line 23

**Evidence**:
```swift
@Published public var workspaceState: WorkspaceViewState = WorkspaceViewState(...)
```

`WorkspaceViewState` contains `WorkspaceTreeProjection` and `WorkspaceSnapshot` data, which are domain-derived, not user-controlled UI state.

**Required State**: Domain-derived projections should be in `WorkspaceProjection`, not `WorkspacePresentationModel`.

**Severity**: **MEDIUM** — Form violation, but functional

---

### **VIOLATION 10: ConversationCoordinator Uses Task.sleep for Fallback**

**Location**: `UIConnections/Sources/UIConnections/Conversation/ConversationCoordinator.swift` line 90

**Evidence**:
```swift
try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
```

**Required State**: This is not polling (it's a one-time delay for fallback), but it's still a time-based wait rather than event-driven.

**Severity**: **LOW** — Not a violation of Contradiction 3 (polling), but could be improved

---

## UNCERTAIN AREAS

### **UNCERTAINTY 1: WorkspaceViewModel Extension Access Pattern**

**Question**: The extensions access `workspaceEngine`, `conversationEngine`, etc. directly via `self.workspaceEngine`. Are these properties still accessible because they're stored in `WorkspaceViewModel`, or should the extensions be removed entirely?

**Evidence**: Extensions are accessing properties that should only exist in `WorkspaceCoordinator`.

**Recommendation**: Extensions should be removed or converted to thin delegation methods.

---

### **UNCERTAINTY 2: WorkspaceSnapshot Storage Location**

**Question**: `WorkspaceViewModel+Conversation.swift` and `WorkspaceViewModel+Loading.swift` both access `workspaceSnapshot`, but this property is not visible in the main `WorkspaceViewModel.swift` file. Where is it stored?

**Evidence**: Extensions reference `workspaceSnapshot` but it's not in the main class definition.

**Recommendation**: Verify if this is a compilation error or if the property exists elsewhere.

---

### **UNCERTAINTY 3: CodexContextByMessageID Storage**

**Question**: `WorkspaceViewModel+Conversation.swift` line 190 references `codexContextByMessageID[assistant.id]`, but this property is not visible in `WorkspaceViewModel.swift`.

**Evidence**: Extension accesses property that should be in `WorkspaceCoordinator` (where it does exist, line 25).

**Recommendation**: This is a duplicate storage violation.

---

## STRUCTURAL HEALTH SUMMARY

### **What Was Successfully Separated**

1. ✅ **FileMutationService** extracted to `AppCoreEngine` — no file mutation in `UIConnections`
2. ✅ **CodexQueryService** separated from mutation — only LLM querying remains
3. ✅ **WorkspaceCoordinator** created with orchestration logic
4. ✅ **WorkspacePresentationModel** created for UI state
5. ✅ **WorkspaceProjection** created for domain projections
6. ✅ **WorkspaceStateObserver** created for observation
7. ✅ **DomainErrorAuthority** created for error classification
8. ✅ **UIPresentationErrorRouter** created for error routing
9. ✅ **ConversationCoordinator** uses Combine observation (no polling)
10. ✅ **ProjectCoordinator** and **ProjectSession** use `DomainErrorAuthority`

### **What Remains Violated**

1. ❌ **WorkspaceViewModel extensions** still contain orchestration, decision, and state management logic
2. ❌ **Direct error publishing** in extensions (bypasses `DomainErrorAuthority`)
3. ❌ **WorkspaceViewModel** creates its own `DomainErrorAuthority` (violates DI)
4. ❌ **Legacy error publisher** still exposed
5. ❌ **CodexMutationPipeline** still exists (dead code)
6. ❌ **WorkspaceViewModel** still holds engine dependencies that extensions access

### **Blocking Issues**

The following violations **block** the success conditions:

1. **WorkspaceViewModel extensions** must be removed or converted to thin delegation
2. **Direct error publishing** must be eliminated
3. **DomainErrorAuthority** must be injected, not created internally

### **Non-Blocking Issues**

The following can be addressed in a follow-up:

1. `CodexMutationPipeline` deletion
2. Legacy `contextErrorPublisher` removal
3. `WorkspaceViewState` in `WorkspacePresentationModel` (form violation, but functional)

---

## RECOMMENDATIONS

### **Immediate Actions Required**

1. **Remove or refactor all `WorkspaceViewModel` extensions**:
   - Move remaining orchestration to `WorkspaceCoordinator`
   - Move remaining state management to `WorkspaceStateObserver`
   - Convert extensions to thin delegation methods

2. **Eliminate direct error publishing**:
   - Replace all `alertCenter?.publish()` calls with `domainErrorAuthority.publish()`
   - Remove `contextErrorSubject` usage
   - Remove legacy `contextErrorPublisher`

3. **Inject `DomainErrorAuthority`**:
   - Add `domainErrorAuthority` parameter to `WorkspaceViewModel.init()`
   - Remove internal creation of `DomainErrorAuthority`
   - Update `ChatUIHost` to pass `domainErrorAuthority` to `WorkspaceViewModel`

4. **Remove engine dependencies from `WorkspaceViewModel`**:
   - Remove `workspaceEngine`, `conversationEngine`, `codexService`, `projectTodosLoader` from `WorkspaceViewModel`
   - Ensure extensions cannot access these (they should delegate to `coordinator`)

5. **Delete `CodexMutationPipeline.swift`**:
   - File is no longer used
   - Logic was moved to `FileMutationService`

### **Follow-Up Actions**

1. Move `WorkspaceViewState` from `WorkspacePresentationModel` to `WorkspaceProjection`
2. Verify `workspaceSnapshot` and `codexContextByMessageID` are not duplicated
3. Remove `Task.sleep` fallback in `ConversationCoordinator` (replace with proper event handling)

---

## CONCLUSION

The form recovery implementation is **approximately 70% complete**. The architectural separation was successfully initiated, but critical violations remain that prevent the system from meeting the success conditions:

- ❌ UI layers cannot be reasoned about without knowing filesystem exists (extensions still access engines)
- ❌ File mutation can be reasoned about without knowing UI exists (✅ achieved)
- ❌ Workspace logic can be replayed without UI (extensions still contain orchestration)
- ✅ LLM querying and material mutation are distinct beings
- ❌ Every component has exactly one dominant power (WorkspaceViewModel still exercises multiple)

**Next Steps**: Complete the removal of orchestration logic from `WorkspaceViewModel` extensions and eliminate direct error publishing.


