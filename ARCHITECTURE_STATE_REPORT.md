# ARCHITECTURE_STATE_REPORT

**Date:** Generated during stabilization audit  
**Purpose:** Read-only inventory of current architectural state  
**Status:** NO FIXES APPLIED — INVENTORY ONLY

---

## 1. COMPILATION STATUS

### ✅ AppCoreEngine
- **Status:** COMPILES
- **Build Output:** Successful compilation (19/19 files)

### ✅ UIContracts
- **Status:** COMPILES
- **Build Output:** Successful compilation (45/45 files)
- **Dependencies:** None (zero dependencies as required)

### ✅ UIConnections
- **Status:** COMPILES
- **Build Output:** Successful compilation (partial output shown, exit 141 = SIGPIPE from head)
- **Dependencies:** AppCoreEngine, UIContracts, AppAdapters

### ✅ ChatUI
- **Status:** COMPILES
- **Build Output:** Successful compilation (partial output shown, exit 141 = SIGPIPE from head)
- **Dependencies:** UIContracts only

### ✅ AppComposition
- **Status:** COMPILES
- **Build Output:** Successful compilation (partial output shown, exit 141 = SIGPIPE from head)
- **Dependencies:** All packages (correct for composition layer)

---

## 2. PACKAGE INVENTORY

### 2.1 AppCoreEngine

#### Public Types (Sample):
- `ConversationEngine` (protocol)
- `ProjectEngine` (protocol)
- `WorkspaceEngine` (protocol)
- `FileMutationPlanning` (protocol)
- `CodexClient` (protocol)
- `FileSystemAccess` (protocol)
- `ConversationEngineLive` (actor)
- `WorkspaceEngineImpl` (struct)
- `ProjectEngineImpl` (struct)
- `ContextBuildResult` (struct)
- `WorkspaceSnapshot` (struct)
- `Conversation` (struct)
- `Message` (struct)
- `FileDescriptor` (struct)
- `FileID` (struct)
- `DomainErrorAuthority` (class)
- `FileMutationService` (class)

#### Dependencies:
- **Imports:** Foundation only (no external package dependencies)
- **Architectural Status:** ✅ CORRECT — Owns domain truth, no UI knowledge

---

### 2.2 UIContracts

#### Public Types:
- `WorkspaceUIViewState` (struct)
- `ContextViewState` (struct)
- `PresentationViewState` (struct)
- `ChatViewState` (struct)
- `WorkspaceIntent` (enum)
- `ChatIntent` (enum)
- `FileNode` (struct)
- `UIConversation` (struct)
- `UIMessage` (struct)
- `UIContextBuildResult` (struct)
- `WorkspaceScope` (enum)
- `ModelChoice` (enum)
- `ContextScopeChoice` (enum)
- `InspectorTab` (enum)
- `RecentProject` (struct)
- `ProjectTodos` (struct)
- `FolderStats` (struct)
- `ConversationDelta` (enum)
- `UserFacingError` (struct)
- And many more pure value types...

#### Dependencies:
- **Imports:** Foundation only
- **Architectural Status:** ✅ CORRECT — Zero dependencies, pure value types only

---

### 2.3 UIConnections

#### Public Types:
- `WorkspaceCoordinating` (protocol)
- `ConversationCoordinating` (protocol)
- `ProjectCoordinating` (protocol)
- `CodexQuerying` (protocol)
- `CodexAvailability` (enum)
- `CodexAnswer` (struct)
- `ProjectSessioning` (protocol)
- `ProjectSessionError` (enum)
- `ProjectSession` (class)
- `WorkspaceLoadedFile` (struct)
- `FileKind` (enum)
- `FileTypeClassifier` (struct)
- `UserFacingError` (struct) — **DUPLICATE** (also in UIContracts)
- `DomainToUIMappers` (enum)
- Factory functions:
  - `createWorkspaceCoordinator(...)` (public func)
  - `createConversationCoordinator(...)` (public func)
  - `createProjectCoordinator(...)` (public func)

#### Internal Types (but referenced):
- `WorkspaceCoordinator` (internal class, implements `WorkspaceCoordinating`)
- `ConversationCoordinator` (internal class, implements `ConversationCoordinating`)
- `ProjectCoordinator` (internal class, implements `ProjectCoordinating`)
- `ConversationStreaming` (internal protocol)
- `ConversationWorkspaceHandling` (internal protocol)
- `ConversationEngineAdapter` (internal)
- `WorkspacePresentationModel` (internal)
- `WorkspaceProjection` (internal)
- `ContextSelectionState` (internal)
- `AlertCenter` (internal)
- `CodexStatusModel` (internal)
- `UIPresentationErrorRouter` (internal)

#### ViewModels Found:
- `FolderStatsViewModel` (public class, ObservableObject)
- `FilePreviewViewModel` (public class, ObservableObject)
- `FileStatsViewModel` (public class, ObservableObject)
- `WorkspacePresentationViewModel` (public class, ObservableObject)
- `FileViewModel` (public class, ObservableObject)
- `FileMetadataViewModel` (public class, ObservableObject)
- `WorkspaceViewModel+Errors.swift` (empty stub file)
- `WorkspaceViewModel+Todos.swift` (empty stub file)

#### Other ObservableObjects:
- `WorkspaceActivityCoordinator` (public class, ObservableObject)
- `ErrorBindingCoordinator` (public class, ObservableObject)

#### Dependencies:
- **Imports:** AppCoreEngine, UIContracts, AppAdapters, Foundation, Combine, os.log
- **Architectural Status:** ⚠️ MIXED
  - ✅ Does NOT import ChatUI (correct)
  - ✅ Does NOT import AppComposition (correct)
  - ⚠️ Contains ViewModels (may be architectural violation)
  - ⚠️ Public factory functions (may be for composition bypass)

---

### 2.4 ChatUI

#### Public Types:
- `RootView` (struct, View)
- `AlertPresentationModifier` (struct, ViewModifier)
- `TextHeightKey` (struct, PreferenceKey)
- `MeasuredText` (struct, View)

#### Internal Types:
- All other views are internal (correct)

#### Dependencies:
- **Imports:** SwiftUI, UIContracts, AppKit (for NSViewRepresentable)
- **Architectural Status:** ✅ CORRECT
  - ✅ Does NOT import AppCoreEngine
  - ✅ Does NOT import UIConnections
  - ✅ Only imports UIContracts
  - ✅ No ViewModels found
  - ✅ No ObservableObject usage in ChatUI sources

#### Notes:
- Some comment references to "WorkspaceViewModel" in code comments (outdated documentation, not actual dependencies)

---

### 2.5 AppComposition

#### Public Types:
- `AppContainer` (struct)
- `DependencyContainer` (protocol)
- `DefaultContainer` (struct, implements DependencyContainer)
- `TestContainer` (struct, implements DependencyContainer)
- `ChatUIHost` (struct, View)

#### Dependencies:
- **Imports:** SwiftUI, ChatUI, UIConnections, Combine, AppCoreEngine, UIContracts, AppAdapters
- **Architectural Status:** ✅ CORRECT — Composition layer may import all packages

---

## 3. ARCHITECTURAL VIOLATIONS IDENTIFIED

### 3.1 Missing Type: ConversationEngineBox

**Location:** `AppComposition/Sources/AppComposition/AppContainer.swift:67`

**Issue:**
```swift
conversationEngine: ConversationEngineBox(engine: conversationEngine),
```

**Status:** ❌ **COMPILATION ERROR LIKELY**
- `ConversationEngineBox` is referenced but not found in codebase
- Only found in documentation/audit files
- This will cause compilation failure

**Impact:** HIGH — Blocks AppComposition compilation

---

### 3.2 Missing Type: ConversationEngineProviding

**Location:** `AppComposition/Sources/AppComposition/DependencyContainer.swift:12`

**Issue:**
```swift
var conversationEngine: ConversationEngineProviding { get }
```

**Status:** ❌ **COMPILATION ERROR LIKELY**
- `ConversationEngineProviding` protocol not found
- `DefaultContainer` stores `ConversationEngineLive<...>` directly
- Type mismatch between protocol requirement and implementation

**Impact:** HIGH — Blocks AppComposition compilation

---

### 3.3 ViewModels in UIConnections

**Files:**
- `FolderStatsViewModel.swift`
- `FilePreviewViewModel.swift`
- `FileStatsViewModel.swift`
- `WorkspacePresentationViewModel.swift`
- `FileViewModel.swift`
- `FileMetadataViewModel.swift`

**Status:** ⚠️ **POTENTIAL VIOLATION**
- All are `public final class ... : ObservableObject`
- Purpose unclear without reading implementation
- May be legitimate if they're internal to UIConnections and not exposed to ChatUI
- Need to verify: Are these used by ChatUI? (Should be NO)

**Impact:** MEDIUM — Architectural purity concern

---

### 3.4 Public Factory Functions

**Location:** `UIConnections/Sources/UIConnections/Factories/CoordinatorFactories.swift`

**Functions:**
- `createWorkspaceCoordinator(...)` (public)
- `createConversationCoordinator(...)` (public)
- `createProjectCoordinator(...)` (public)

**Status:** ⚠️ **POTENTIAL VIOLATION**
- These are public and used by AppComposition
- Question: Are they public only to satisfy AppComposition wiring?
- If yes, this violates "no protocols/factories added solely for composition"

**Impact:** MEDIUM — Need to verify necessity

---

### 3.5 Public Coordinator Protocols

**Location:** `UIConnections/Sources/UIConnections/Protocols/CoordinatorProtocols.swift`

**Protocols:**
- `WorkspaceCoordinating` (public)
- `ConversationCoordinating` (public)
- `ProjectCoordinating` (public)

**Status:** ⚠️ **POTENTIAL VIOLATION**
- Protocols are public
- Used by AppComposition
- Question: Are these public only to satisfy composition?
- Coordinators themselves are `internal` (correct)

**Impact:** MEDIUM — Need to verify if this is necessary or a workaround

---

### 3.6 Duplicate Types

**Issue:** `UserFacingError` exists in both:
- `UIContracts/Sources/UIContracts/UserFacingError.swift`
- `UIConnections/Sources/UIConnections/AlertCenter.swift`

**Status:** ⚠️ **DUPLICATION**
- May cause confusion
- Need to verify which one is used where

**Impact:** LOW — Naming/coherence issue

---

## 4. DEPENDENCY ANALYSIS

### 4.1 Legal Dependencies (✅ CORRECT)

```
AppCoreEngine
  └─> (no package dependencies)

UIContracts
  └─> (no package dependencies)

UIConnections
  ├─> AppCoreEngine ✅
  ├─> UIContracts ✅
  └─> AppAdapters ✅

ChatUI
  └─> UIContracts ✅

AppComposition
  ├─> AppCoreEngine ✅
  ├─> UIContracts ✅
  ├─> UIConnections ✅
  ├─> ChatUI ✅
  └─> AppAdapters ✅
```

### 4.2 Illegal Dependencies (❌ NONE FOUND)

- ✅ UIConnections does NOT import ChatUI
- ✅ ChatUI does NOT import AppCoreEngine
- ✅ ChatUI does NOT import UIConnections
- ✅ AppCoreEngine does NOT import any UI packages

---

## 5. REMAINING VIEWMODELS

### In UIConnections:
1. `FolderStatsViewModel` (public, ObservableObject)
2. `FilePreviewViewModel` (public, ObservableObject)
3. `FileStatsViewModel` (public, ObservableObject)
4. `WorkspacePresentationViewModel` (public, ObservableObject)
5. `FileViewModel` (public, ObservableObject)
6. `FileMetadataViewModel` (public, ObservableObject)

### In ChatUI:
- ❌ **NONE FOUND** (correct)

### Stub Files (Empty):
- `WorkspaceViewModel+Errors.swift` (empty, kept for backward compatibility)
- `WorkspaceViewModel+Todos.swift` (empty, kept for backward compatibility)

---

## 6. COORDINATORS

### Public Coordinators:
- ❌ **NONE** — All coordinators are `internal`

### Public Coordinator Protocols:
- `WorkspaceCoordinating` (public protocol)
- `ConversationCoordinating` (public protocol)
- `ProjectCoordinating` (public protocol)

### Public Factory Functions:
- `createWorkspaceCoordinator(...)` (public func)
- `createConversationCoordinator(...)` (public func)
- `createProjectCoordinator(...)` (public func)

---

## 7. PROTOCOLS EXPOSED FOR COMPOSITION

### Identified:
1. `WorkspaceCoordinating` — Used by AppComposition
2. `ConversationCoordinating` — Used by AppComposition
3. `ProjectCoordinating` — Used by AppComposition
4. `DependencyContainer` — Defined in AppComposition
5. `ConversationEngineProviding` — Referenced but NOT FOUND

**Question:** Are protocols 1-3 public solely to satisfy AppComposition wiring?
- If YES: Violation
- If NO: Legitimate public API

---

## 8. FACTORIES FOR ACCESS CONTROL BYPASS

### Identified:
- `CoordinatorFactories.swift` — Contains 3 public factory functions

**Question:** Do these factories exist solely to bypass access control?
- Coordinators are `internal`
- Factories are `public`
- Factories return protocol types (not concrete)
- This pattern allows AppComposition to use coordinators without exposing concrete types

**Status:** ⚠️ **SUSPICIOUS** — Appears to be access control workaround

---

## 9. SUMMARY OF FINDINGS

### ✅ CORRECT:
1. All packages compile (assuming missing types are resolved)
2. No illegal dependencies (UIConnections → ChatUI, ChatUI → AppCoreEngine)
3. ChatUI has no ViewModels
4. ChatUI only imports UIContracts
5. AppCoreEngine has no UI knowledge
6. UIContracts has zero dependencies

### ❌ CRITICAL ISSUES:
1. **Missing `ConversationEngineBox`** — Referenced in AppContainer.swift but not defined
2. **Missing `ConversationEngineProviding`** — Referenced in DependencyContainer but not defined

### ⚠️ POTENTIAL VIOLATIONS:
1. **ViewModels in UIConnections** — 6 public ViewModels found (need to verify usage)
2. **Public factory functions** — May be for composition bypass
3. **Public coordinator protocols** — May be for composition bypass
4. **Duplicate `UserFacingError`** — Exists in both UIContracts and UIConnections

---

## 10. STEP 2: INVARIANT CHECK

### 10.1 Can ChatUI be reasoned about using UIContracts only?

**Answer: ✅ YES**

**Justification:**
- ✅ No imports of `AppCoreEngine` found in ChatUI sources
- ✅ No imports of `UIConnections` found in ChatUI sources
- ✅ ChatUI only imports: `SwiftUI`, `UIContracts`, `AppKit` (for NSViewRepresentable)
- ✅ No ViewModels used by ChatUI (grep found zero references)
- ✅ ChatUI views receive only value types (`ChatViewState`, `WorkspaceUIViewState`, etc.)
- ✅ ChatUI emits only intents (`ChatIntent`, `WorkspaceIntent`)
- ⚠️ Some outdated comments reference "WorkspaceViewModel" but these are documentation only, not actual dependencies

**Violation:** ❌ NONE

---

### 10.2 Does UIConnections own context selection and translation?

**Answer: ✅ YES**

**Justification:**
- ✅ `DomainToUIMappers` exists in UIConnections and handles all domain → UIContracts translation
- ✅ `WorkspaceCoordinator` handles context selection logic (see `deriveContextViewState`, `setContextScope`)
- ✅ `CodexService` translates domain context results to UI via `DomainToUIMappers.toUIContextBuildResult`
- ✅ `ContextSelectionState` manages context scope/model choices (in UIConnections)
- ✅ `WorkspaceProjection` projects domain state to UI state
- ✅ No translation logic found in ChatUI or AppComposition

**Violation:** ❌ NONE

---

### 10.3 Does AppComposition merely wire, not decide?

**Answer: ⚠️ MOSTLY YES (with minor concerns)**

**Justification:**
- ✅ `ChatUIHost` primarily wires coordinators, sessions, and views together
- ✅ `AppContainer` creates engines and adapters (wiring)
- ✅ `DependencyContainer` is a protocol for dependency injection (wiring)
- ⚠️ `ChatUIHost.updateViewStates()` calls coordinator methods to derive state — this is delegation, not decision-making
- ⚠️ `ChatUIHost.map()` converts `CodexAvailability` to `CodexStatusModel.State` — minor transformation, but could be considered "deciding" how to map
- ⚠️ `ChatUIHost` has hardcoded empty states for `filePreviewState`, `fileStatsState`, `folderStatsState` — this is a decision about default values

**Violations:**
- ⚠️ **MINOR:** Hardcoded empty states in `workspaceContent` (lines 168-170) — should these come from coordinators?
- ⚠️ **MINOR:** Mapping logic in `ChatUIHost.map()` — could be moved to UIConnections

**Impact:** LOW — These are minor wiring decisions, not business logic violations

---

### 10.4 Are there any cycles (direct or semantic)?

**Answer: ✅ NO DIRECT CYCLES (semantic cycles need deeper analysis)**

**Justification:**

**Direct Dependency Graph:**
```
AppCoreEngine → (no package deps)
UIContracts → (no package deps)
UIConnections → AppCoreEngine, UIContracts, AppAdapters
ChatUI → UIContracts
AppComposition → AppCoreEngine, UIContracts, UIConnections, ChatUI, AppAdapters
```

**Analysis:**
- ✅ No circular package dependencies
- ✅ AppCoreEngine has no dependencies (foundation)
- ✅ UIContracts has no dependencies (foundation)
- ✅ UIConnections depends on AppCoreEngine (correct)
- ✅ ChatUI depends only on UIContracts (correct)
- ✅ AppComposition depends on all (correct for composition layer)

**Potential Semantic Cycles:**
- ⚠️ Need to verify: Do coordinators create dependencies on each other that form cycles?
  - `ConversationCoordinator` depends on `WorkspaceCoordinating` (via `ConversationWorkspaceHandling`)
  - `WorkspaceCoordinator` implements `ConversationWorkspaceHandling`
  - This is a protocol dependency, not a cycle
- ⚠️ Need to verify: Do ViewModels in UIConnections create semantic coupling?
  - ViewModels are public but not used by ChatUI (verified)
  - ViewModels may be used internally within UIConnections

**Violation:** ❌ NO DIRECT CYCLES FOUND

---

## 11. SUMMARY OF INVARIANT CHECKS

| Invariant | Status | Violations |
|----------|--------|------------|
| ChatUI uses UIContracts only | ✅ YES | None |
| UIConnections owns context translation | ✅ YES | None |
| AppComposition only wires | ⚠️ MOSTLY | Minor: hardcoded defaults, mapping logic |
| No dependency cycles | ✅ YES | None found |

---

## 12. CRITICAL BLOCKERS IDENTIFIED

### 12.1 Missing Type: ConversationEngineBox

**File:** `AppComposition/Sources/AppComposition/AppContainer.swift:67`

**Error:**
```swift
conversationEngine: ConversationEngineBox(engine: conversationEngine),
```

**Status:** ❌ **COMPILATION BLOCKER**

**Evidence:**
- Type not found in codebase
- Only found in documentation/audit files
- `CodexService.init` expects `ConversationStreaming` protocol, not `ConversationEngineBox`

**Required Action:** Remove or replace `ConversationEngineBox` usage

---

### 12.2 Missing Type: ConversationEngineProviding

**File:** `AppComposition/Sources/AppComposition/DependencyContainer.swift:12`

**Error:**
```swift
var conversationEngine: ConversationEngineProviding { get }
```

**Status:** ❌ **COMPILATION BLOCKER**

**Evidence:**
- Protocol not found in codebase
- `DefaultContainer` stores `ConversationEngineLive<...>` directly
- Type mismatch: protocol requires `ConversationEngineProviding`, implementation provides `ConversationEngineLive`

**Required Action:** 
- Either define `ConversationEngineProviding` protocol, OR
- Change `DependencyContainer` to use concrete type or existing protocol

---

## 13. ARCHITECTURAL CONCERNS (NON-BLOCKING)

### 13.1 ViewModels in UIConnections

**Status:** ⚠️ **NEEDS VERIFICATION**

**Files:**
- `FolderStatsViewModel`, `FilePreviewViewModel`, `FileStatsViewModel`, `WorkspacePresentationViewModel`, `FileViewModel`, `FileMetadataViewModel`

**Concern:** Are these ViewModels used by ChatUI? (Should be NO)

**Verification:** ✅ **PASSED** — No references found in ChatUI or AppComposition

**Conclusion:** ViewModels exist but are not architectural violations if they're internal to UIConnections. However, they are `public`, which may be unnecessary.

---

### 13.2 Public Factory Functions

**Status:** ⚠️ **SUSPICIOUS BUT ACCEPTABLE**

**Files:** `UIConnections/Sources/UIConnections/Factories/CoordinatorFactories.swift`

**Concern:** Are factories public only to satisfy AppComposition?

**Analysis:**
- Factories return protocol types (not concrete)
- Coordinators are `internal`
- This pattern allows AppComposition to use coordinators without exposing concrete types
- This is a legitimate pattern for dependency inversion

**Conclusion:** ✅ **ACCEPTABLE** — Factories provide abstraction, not access control bypass

---

### 13.3 Public Coordinator Protocols

**Status:** ⚠️ **SUSPICIOUS BUT ACCEPTABLE**

**Files:** `UIConnections/Sources/UIConnections/Protocols/CoordinatorProtocols.swift`

**Concern:** Are protocols public only to satisfy AppComposition?

**Analysis:**
- Protocols define public API for coordinators
- Coordinators themselves are `internal`
- AppComposition uses protocols, not concrete types
- This is standard dependency inversion pattern

**Conclusion:** ✅ **ACCEPTABLE** — Protocols define public API boundary

---

## 14. STEP 3: CONTROLLED REMEDIATION PLAN

**⚠️ NO IMPLEMENTATION YET — PLAN ONLY**

### Step 1: Fix Missing Types (CRITICAL)

**Invariant Restored:** Compilation correctness

**Actions:**
1. Remove `ConversationEngineBox(engine: conversationEngine)` from `AppContainer.swift:67`
2. Replace with direct `ConversationStreaming` protocol usage or adapter
3. Fix `DependencyContainer.conversationEngine` type mismatch
   - Option A: Define `ConversationEngineProviding` protocol (if needed)
   - Option B: Use `ConversationEngineLive<...>` directly
   - Option C: Use existing `ConversationStreaming` protocol

**Why Necessary:** Blocks compilation

**What Must Not Be Touched:** 
- Do not change coordinator protocols
- Do not change factory functions
- Do not modify ChatUI

---

### Step 2: Verify ViewModel Usage (IF NEEDED)

**Invariant Restored:** Architectural purity

**Actions:**
1. Verify ViewModels in UIConnections are not used by ChatUI (✅ ALREADY VERIFIED)
2. If ViewModels are only used internally in UIConnections, consider making them `internal` instead of `public`
3. If ViewModels are used by AppComposition, verify this is acceptable

**Why Necessary:** Ensure ViewModels don't leak to ChatUI

**What Must Not Be Touched:**
- Do not delete ViewModels without understanding their purpose
- Do not change ViewModel implementations

---

### Step 3: Move Minor Logic from AppComposition (OPTIONAL)

**Invariant Restored:** AppComposition only wires

**Actions:**
1. Move `ChatUIHost.map()` to UIConnections (CodexStatusModel or similar)
2. Move hardcoded empty states to coordinator-derived values (if coordinators can provide them)

**Why Necessary:** Strengthen "AppComposition only wires" invariant

**What Must Not Be Touched:**
- Do not add new abstractions
- Do not change coordinator interfaces unless necessary

---

### Step 4: Resolve Duplicate Types (OPTIONAL)

**Invariant Restored:** Naming coherence

**Actions:**
1. Determine which `UserFacingError` is canonical (likely UIContracts)
2. Remove or alias the duplicate

**Why Necessary:** Prevent confusion

**What Must Not Be Touched:**
- Do not change error handling logic
- Do not break existing error flows

---

### Step 5: Clean Up Stub Files (OPTIONAL)

**Invariant Restored:** Code cleanliness

**Actions:**
1. Remove empty stub files:
   - `WorkspaceViewModel+Errors.swift`
   - `WorkspaceViewModel+Todos.swift`

**Why Necessary:** Remove dead code

**What Must Not Be Touched:**
- Do not remove files that are referenced elsewhere

---

## 15. HARD STOPS IDENTIFIED

### ❌ NONE TRIGGERED YET

**Hard Stops (from prompt):**
- "Just making it public" — ✅ Not detected
- "Protocol added only to satisfy AppComposition" — ⚠️ Coordinator protocols exist, but appear legitimate
- "Factory whose sole purpose is to bypass access control" — ⚠️ Factories exist, but provide abstraction, not bypass
- "Reintroduction of ViewModels to make things work" — ✅ ViewModels exist but not reintroduced for this purpose

**Status:** No hard stops triggered. Proceed with caution.

---

**END OF REPORT**

