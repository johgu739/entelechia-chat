# UIConnections ORDER 5 — Remaining Errors Ledger

**Date:** After ORDER 3 & 4 completion  
**Purpose:** Categorize all remaining compilation errors for systematic resolution

---

## 1. Missing Types/Helpers

### WorkspaceStateObserver.swift
- `WorkspaceErrorNotice` - type not found
- `WorkspaceViewStateMapper` - function/type not found

### DomainToUIMappers.swift
- `AppCoreEngine.RecentProject` - no type named 'RecentProject' in module 'AppCoreEngine'

### WorkspaceCoordinator.swift
- `AppCoreEngine.ContextBuildResult.EncodedSegment` - 'EncodedSegment' is not a member type
- `AppCoreEngine.WorkspaceContextEncoder.EncodedFile` - 'EncodedFile' is not a member type (2 occurrences)

### ChatIntentController.swift
- `ChatIntent.selectModel` - type 'ChatIntent' has no member 'selectModel'
- `ChatIntent.selectScope` - type 'ChatIntent' has no member 'selectScope'
- `ConversationCoordinator.setStreamingIntentDispatcher` - value has no member 'setStreamingIntentDispatcher'

**Total:** 8 unique missing type errors

---

## 2. Orphaned References

### Files referencing deleted/non-existent types:
- **WorkspaceStateObserver.swift** - references `WorkspaceErrorNotice` and `WorkspaceViewStateMapper` (likely orphaned)
- **ChatIntentController.swift** - references methods that don't exist on `ConversationCoordinator`
- **WorkspaceViewModel.swift** - references `ConversationWorkspaceHandling` protocol (may be orphaned if ViewModel-centric)

**Assessment Needed:**
- Determine if these files are ViewModel-centric and should be deleted
- Or if they can be rewritten as minimal adapters

**Total:** 3 files potentially orphaned

---

## 3. Type Conversion Issues

### FileID Conversions
- **WorkspaceStateObserver.swift:59** - cannot assign `AppCoreEngine.FileID` to `UIContracts.FileID`
- **WorkspaceStateObserver.swift:84** - cannot convert `UIContracts.FileID` to `AppCoreEngine.FileID`
- **ChatViewModel.swift:195** - cannot convert `FileID` to `UUID` (ambiguous FileID)
- **ChatViewModel.swift:207** - extraneous argument label 'rawValue:' in call (UUID has no rawValue)

### Ambiguous Types
- **WorkspaceCoordinator.swift:369** - 'Conversation' is ambiguous
- **WorkspaceCoordinator.swift:376** - 'Conversation' is ambiguous (2 occurrences)
- **WorkspaceCoordinator.swift:376** - 'FileID' is ambiguous
- **WorkspaceViewModel.swift:141** - 'FileID' is ambiguous

**Total:** 9 type conversion/ambiguity errors

---

## 4. Publisher/Async Surface Mismatches

### WorkspaceProjection.swift
- Line 41: Cannot convert `AnyPublisher<MergeMany<AnyPublisher<(UUID, String), Never>>.Output, ...>` to `AnyPublisher<(UUID, String?), Never>`
- Publisher type mismatch in streaming messages aggregation

**Total:** 1 publisher type mismatch

---

## 5. Hygiene (Swift Syntax / Protocol / Access Control)

### Protocol Conformance
- **WorkspaceViewModel.swift:54** - type 'NullCodexQuerying' does not conform to protocol 'CodexQuerying'
- **WorkspaceViewModel.swift:92** - type 'WorkspaceViewModel' does not conform to protocol 'ConversationWorkspaceHandling'

### Access Control
- **ChatIntentController.swift:36** - 'contextSelection' is inaccessible due to 'private' protection level (2 occurrences)
- **ChatIntentController.swift:46** - 'contextSelection' is inaccessible due to 'private' protection level

**Total:** 4 hygiene errors

---

## Summary by File

### WorkspaceStateObserver.swift
- **Category 1:** 2 missing types
- **Category 3:** 2 FileID conversion errors
- **Status:** Likely orphaned - needs assessment

### WorkspaceCoordinator.swift
- **Category 1:** 3 missing member types
- **Category 3:** 3 ambiguous type errors
- **Status:** Core coordinator - fix missing types and ambiguities

### WorkspaceViewModel.swift
- **Category 3:** 1 ambiguous FileID
- **Category 5:** 2 protocol conformance errors
- **Status:** May be orphaned if ViewModel-centric - needs assessment

### ChatViewModel.swift
- **Category 3:** 4 FileID/UUID conversion errors
- **Status:** Needs type qualification fixes

### ChatIntentController.swift
- **Category 1:** 3 missing members/methods
- **Category 5:** 2 access control errors
- **Status:** Needs API fixes

### DomainToUIMappers.swift
- **Category 1:** 1 missing AppCoreEngine type
- **Status:** Fix or remove if type doesn't exist

### WorkspaceProjection.swift
- **Category 4:** 1 publisher type mismatch
- **Status:** Fix publisher aggregation

### ProjectCoordinator.swift
- **Category 5:** (if any - check separately)
- **Status:** TBD

---

## Total Error Count

- **Category 1 (Missing Types):** 8 errors
- **Category 2 (Orphaned):** 3 files to assess
- **Category 3 (Type Conversion):** 9 errors
- **Category 4 (Publisher/Async):** 1 error
- **Category 5 (Hygiene):** 4 errors

**Grand Total:** ~22 unique errors (many duplicates in compiler output)

---

## Next Steps

1. **ORDER 5.2** - Assess and exorcise orphans (WorkspaceStateObserver, WorkspaceViewModel)
2. **ORDER 5.3** - Resolve missing types (check UIContracts first, then AppCoreEngine)
3. **ORDER 5.4** - Fix type conversions using existing mappers
4. **Defer to ORDER 6** - Publisher/async and protocol conformance issues


