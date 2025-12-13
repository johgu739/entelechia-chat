# TEST ARCHITECTURE STRATA AUDIT

**Date:** 2024  
**Auditor:** Independent Architectural Auditor  
**Scope:** Test files only — no production code changes

---

## 1. EXECUTIVE SUMMARY

The test architecture exhibits significant stratification violations. ChatUI tests import UIConnections and use domain types (FileID, WorkspaceSnapshot, Conversation, etc.) and ViewModels (WorkspaceViewModel, ChatViewModel, ConversationCoordinator), violating Stratum 1 purity. UIConnections tests correctly import AppCoreEngine but test ViewModel behavior rather than pure mapping. AppCoreEngine tests are pure. AppComposition tests mix all layers. The architecture does not support clean test stratification as defined.

---

## 2. TEST TARGET INVENTORY

| Target Name | Path | Module Imports |
|------------|------|----------------|
| ChatUITests | ChatUI/Tests/ChatUITests | ChatUI, UIContracts, UIConnections (violation) |
| UIConnectionsTests | UIConnections/Tests/UIConnectionsTests | UIConnections, AppCoreEngine, AppAdapters, UIContracts (implicit via UIConnections) |
| UIContractsTests | UIContracts/Tests/UIContractsTests | UIContracts only |
| AppCoreEngineTests | AppCoreEngine/Tests/CoreEngineTests | AppCoreEngine only |
| AppAdaptersTests | AppAdapters/Tests/AppAdaptersTests | AppAdapters, AppCoreEngine |
| AppCompositionTests | AppComposition/Tests/AppCompositionTests | AppComposition, UIConnections, ChatUI, AppCoreEngine, AppAdapters |
| ArchitectureGuardianTests | ArchitectureGuardian/Tests/ArchitectureGuardianTests | ArchitectureGuardian only |
| OntologyActTests | OntologyAct/Tests | OntologyAct only |
| OntologyCoreTests | OntologyCore/Tests | OntologyCore only |
| OntologyDomainTests | OntologyDomain/Tests | OntologyDomain only |
| OntologyFractalTests | OntologyFractal/Tests | OntologyFractal only |
| OntologyIntegrationTests | OntologyIntegration/Tests | OntologyIntegration only |
| OntologyIntelligenceTests | OntologyIntelligence/Tests | OntologyIntelligence only |
| OntologyStateTests | OntologyState/Tests | OntologyState only |
| OntologyTeleologyTests | OntologyTeleology/Tests | OntologyTeleology only |

**Note:** ChatUITests target also includes `ChatUITests/JSONRenderingTests.swift` at workspace root.

---

## 3. FILE-LEVEL CLASSIFICATION

### ChatUI Tests (Stratum 1 — Should be pure UIContracts)

| File | Imports | Uses UIContracts | Uses UIConnections | Uses AppCoreEngine | Uses Domain Types | Uses ViewModels | Uses Coordinators | Uses Async/Await | Current Stratum |
|------|---------|------------------|-------------------|-------------------|------------------|----------------|------------------|-----------------|----------------|
| ChatUIViewInitializationTests.swift | XCTest, SwiftUI, Foundation, ChatUI, **UIConnections** | No | **Yes** | **Yes** (via stubs) | **Yes** (FileID, WorkspaceSnapshot, FileDescriptor, Conversation) | **Yes** (WorkspaceViewModel, ChatViewModel) | **Yes** (ConversationCoordinator) | **Yes** | **Mixed/Invalid** |
| DomainTypeLeakageTest.swift | XCTest, SwiftUI, Foundation, ChatUI, UIContracts | Yes | No | No | No | No | No | No | **Stratum 1** ✓ |
| EmptyTests.swift | XCTest | No | No | No | No | No | No | No | **Stratum 1** ✓ |
| LifecycleGuardTests.swift | XCTest, Foundation | No | No | No | No | No | No | No | **Stratum 1** ✓ |
| JSONRenderingTests.swift | XCTest, ChatUI, UIContracts | Yes | No | No | No | No | No | No | **Stratum 1** ✓ |

**Violations in ChatUIViewInitializationTests.swift:**
- Imports `UIConnections` (line 5)
- Creates `WorkspaceViewModel` instances (line 28, 56, 123, 177, 208, 260)
- Creates `ChatViewModel` instances (line 34, 129, 183, 214)
- Creates `ConversationCoordinator` instances (line 30, 125, 179, 210)
- Uses domain types: `FileID`, `WorkspaceSnapshot`, `FileDescriptor`, `Conversation` (lines 286-334)
- Implements stubs that conform to domain protocols: `WorkspaceEngine`, `ConversationStreaming` (lines 279-335)
- Uses async/await in stub implementations

### UIConnections Tests (Stratum 2 — Should test mapping/mediation)

| File | Imports | Uses UIContracts | Uses UIConnections | Uses AppCoreEngine | Uses Domain Types | Uses ViewModels | Uses Coordinators | Uses Async/Await | Current Stratum |
|------|---------|------------------|-------------------|-------------------|------------------|----------------|------------------|-----------------|----------------|
| MappingTests.swift | XCTest, UIConnections, **AppCoreEngine** | No | Yes | **Yes** | **Yes** (FileID, WorkspaceSnapshot, FileDescriptor, ContextBuildResult) | No | No | No | **Stratum 2** ✓ |
| ConversationViewStateTests.swift | XCTest, UIConnections, **AppCoreEngine** | No | Yes | **Yes** | **Yes** (ContextBuildResult, Message) | No | No | No | **Stratum 2** ✓ |
| ConversationMapperCompletenessTests.swift | XCTest, UIConnections, **AppCoreEngine** | No | Yes | **Yes** | **Yes** (Message, ContextBuildResult) | No | No | No | **Stratum 2** ✓ |
| WorkspaceMapperCompletenessTests.swift | XCTest, UIConnections, **AppCoreEngine** | No | Yes | **Yes** | **Yes** (FileID, WorkspaceSnapshot, FileDescriptor, WorkspaceTreeProjection) | No | No | No | **Stratum 2** ✓ |
| ChatViewModelTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** (Conversation, Message) | **Yes** (ChatViewModel, WorkspaceViewModel fake) | **Yes** (ConversationCoordinator) | **Yes** | **Mixed/Invalid** |
| ChatViewModelBehaviorTests.swift | XCTest, UIConnections, **AppCoreEngine** | No | Yes | **Yes** | **Yes** (Conversation) | **Yes** (ChatViewModel) | **Yes** (ConversationCoordinator) | **Yes** | **Mixed/Invalid** |
| WorkspaceViewModelBehaviorTests.swift | XCTest, UIConnections, **AppCoreEngine** | No | Yes | **Yes** | **Yes** (Conversation, FileID, etc.) | **Yes** (WorkspaceViewModel) | No | **Yes** | **Mixed/Invalid** |
| WorkspaceViewModelInitializationTests.swift | XCTest, Combine, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** (WorkspaceViewModel) | No | **Yes** | **Mixed/Invalid** |
| WorkspaceViewModelContextTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** (WorkspaceViewModel) | No | **Yes** | **Mixed/Invalid** |
| WorkspaceViewModelContextErrorTests.swift | XCTest, Combine, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** (WorkspaceViewModel) | No | **Yes** | **Mixed/Invalid** |
| WorkspaceViewModelIntegrationTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** (WorkspaceViewModel) | No | **Yes** | **Mixed/Invalid** |
| WorkspaceViewModelLifecycleTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** (WorkspaceViewModel) | No | **Yes** | **Mixed/Invalid** |
| WorkspaceViewModelLifecycleEnforcementTests.swift | XCTest, Foundation, UIConnections | No | Yes | No | No | **Yes** (WorkspaceViewModel) | No | No | **Mixed/Invalid** |
| WorkspaceViewModelMutationSafetyTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** (WorkspaceViewModel) | No | **Yes** | **Mixed/Invalid** |
| WorkspaceViewModelWatcherErrorTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** (WorkspaceViewModel) | No | **Yes** | **Mixed/Invalid** |
| ConversationCoordinatorTests.swift | XCTest, UIConnections, **AppCoreEngine** | No | Yes | **Yes** | **Yes** | **Yes** | **Yes** (ConversationCoordinator) | **Yes** | **Mixed/Invalid** |
| CodexServiceTests.swift | XCTest, **AppCoreEngine**, **AppAdapters**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| AskCodexPipelineTests.swift | XCTest, UIConnections, **AppCoreEngine**, **AppAdapters** | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| AskCodexTraceTests.swift | XCTest, UIConnections, **AppAdapters**, **AppCoreEngine** | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| ContextPipelineEvidenceTests.swift | XCTest, Foundation, UIConnections, **AppCoreEngine**, **AppAdapters** | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| ContextDeterminismTests.swift | XCTest, Foundation, UIConnections, **AppCoreEngine** | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| ContextSnapshotPresentationTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| ConversationEngineBoxIsolationTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| NavigatorIntegrationTests.swift | XCTest, Foundation, **AppCoreEngine**, **AppAdapters**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| ModelAndScopeBindingTests.swift | XCTest, Combine, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| NegativeBehaviorTests.swift | XCTest, UIConnections, **AppCoreEngine**, **AppAdapters** | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| ProjectCoordinatorSessionTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** | **Mixed/Invalid** |
| WorkspaceBootstrapTests.swift | XCTest, Foundation, **AppCoreEngine**, **AppAdapters**, UIConnections | No | Yes | **Yes** | **Yes** | **Yes** | No | **Yes** | **Mixed/Invalid** |
| ArchitectureBoundariesTests.swift | XCTest, UIConnections | No | Yes | No | No | No | No | No | **Stratum 2** ✓ |
| FormViolationTests.swift | XCTest, **AppCoreEngine**, UIConnections | No | Yes | **Yes** | **Yes** | No | No | No | **Stratum 2** ✓ |

**Analysis:** Only 4 of 31 UIConnections test files are pure Stratum 2 (mapping-only). The remaining 27 test ViewModel behavior, coordinators, async workflows, and integration patterns, which violates the Stratum 2 telos of "translation and mediation only."

### AppCoreEngine Tests (Stratum 3 — Should test domain truth)

| File | Imports | Uses UIContracts | Uses UIConnections | Uses AppCoreEngine | Uses Domain Types | Uses ViewModels | Uses Coordinators | Uses Async/Await | Current Stratum |
|------|---------|------------------|-------------------|-------------------|------------------|----------------|------------------|-----------------|----------------|
| EngineTests.swift | XCTest, AppCoreEngine | No | No | Yes | Yes | No | No | No | **Stratum 3** ✓ |
| WorkspaceEngineImplTests.swift | XCTest, AppCoreEngine | No | No | Yes | Yes | No | No | **Yes** | **Stratum 3** ✓ |
| WorkspaceContextEncodingTests.swift | XCTest, AppCoreEngine | No | No | Yes | Yes | No | No | **Yes** | **Stratum 3** ✓ |
| WorkspaceContextPreparerTests.swift | XCTest, AppCoreEngine | No | No | Yes | Yes | No | No | **Yes** | **Stratum 3** ✓ |
| ContextBudgetTests.swift | XCTest, AppCoreEngine | No | No | Yes | Yes | No | No | No | **Stratum 3** ✓ |
| ProjectEngineImplTests.swift | XCTest, AppCoreEngine | No | No | Yes | Yes | No | No | **Yes** | **Stratum 3** ✓ |
| WorkspaceEngineUpdatesTests.swift | XCTest, AppCoreEngine | No | No | Yes | Yes | No | No | **Yes** | **Stratum 3** ✓ |
| ConversationEngineLiveTests.swift | XCTest, AppCoreEngine | No | No | Yes | Yes | No | No | **Yes** | **Stratum 3** ✓ |

**Analysis:** All AppCoreEngine tests are pure Stratum 3. They test domain behavior without UI concerns.

### UIContracts Tests (Not in target architecture — contract validation)

| File | Imports | Uses UIContracts | Uses UIConnections | Uses AppCoreEngine | Uses Domain Types | Uses ViewModels | Uses Coordinators | Uses Async/Await | Current Stratum |
|------|---------|------------------|-------------------|-------------------|------------------|----------------|------------------|-----------------|----------------|
| UIContractsTests.swift | XCTest, UIContracts | Yes | No | No | No | No | No | No | **Contract-only** |
| FormViolationTests.swift | XCTest, UIContracts | Yes | No | No | No | No | No | No | **Contract-only** |

**Analysis:** UIContracts tests are pure contract validation, which is appropriate.

### AppComposition Tests (Integration — Not in target architecture)

| File | Imports | Uses UIContracts | Uses UIConnections | Uses AppCoreEngine | Uses Domain Types | Uses ViewModels | Uses Coordinators | Uses Async/Await | Current Stratum |
|------|---------|------------------|-------------------|-------------------|------------------|----------------|------------------|-----------------|----------------|
| AppCompositionIntegrationTests.swift | XCTest, SwiftUI, Foundation, AppComposition, **UIConnections**, **ChatUI**, **AppCoreEngine**, **AppAdapters** | No | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** | **Integration (all layers)** |
| AppSmokeTests.swift | XCTest, SwiftUI, Foundation, AppComposition, **UIConnections**, **ChatUI**, **AppCoreEngine**, **AppAdapters** | No | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** | **Yes** | **Integration (all layers)** |
| EmptyTests.swift | XCTest | No | No | No | No | No | No | No | **Empty** |

**Analysis:** AppComposition tests are integration tests mixing all layers, which is expected for composition-level testing but not part of the three-stratum model.

### AppAdapters Tests (Adapter layer — Not in target architecture)

| File | Imports | Uses UIContracts | Uses UIConnections | Uses AppCoreEngine | Uses Domain Types | Uses ViewModels | Uses Coordinators | Uses Async/Await | Current Stratum |
|------|---------|------------------|-------------------|-------------------|------------------|----------------|------------------|-----------------|----------------|
| All 10 files | XCTest, AppAdapters, **AppCoreEngine** (most) | No | No | **Yes** | **Yes** | No | No | **Yes** | **Adapter layer** |

**Analysis:** AppAdapters tests are adapter-layer tests, not part of the three-stratum model.

---

## 4. STRATUM VIOLATION MATRIX

| Test File | Violates Stratum 1 | Violates Stratum 2 | Violates Stratum 3 | Reason |
|-----------|-------------------|-------------------|-------------------|--------|
| ChatUIViewInitializationTests.swift | **YES** | N/A | N/A | Imports UIConnections; uses ViewModels (WorkspaceViewModel, ChatViewModel), Coordinators (ConversationCoordinator), domain types (FileID, WorkspaceSnapshot, Conversation), async/await |
| DomainTypeLeakageTest.swift | No | N/A | N/A | Pure Stratum 1 |
| EmptyTests.swift | No | N/A | N/A | Pure Stratum 1 |
| LifecycleGuardTests.swift | No | N/A | N/A | Pure Stratum 1 |
| JSONRenderingTests.swift | No | N/A | N/A | Pure Stratum 1 |
| MappingTests.swift | N/A | No | N/A | Pure Stratum 2 (mapping only) |
| ConversationViewStateTests.swift | N/A | No | N/A | Pure Stratum 2 (mapping only) |
| ConversationMapperCompletenessTests.swift | N/A | No | N/A | Pure Stratum 2 (mapping only) |
| WorkspaceMapperCompletenessTests.swift | N/A | No | N/A | Pure Stratum 2 (mapping only) |
| ChatViewModelTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await, coordinators |
| ChatViewModelBehaviorTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await, coordinators |
| WorkspaceViewModelBehaviorTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| WorkspaceViewModelInitializationTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| WorkspaceViewModelContextTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| WorkspaceViewModelContextErrorTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| WorkspaceViewModelIntegrationTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| WorkspaceViewModelLifecycleTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| WorkspaceViewModelLifecycleEnforcementTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping |
| WorkspaceViewModelMutationSafetyTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| WorkspaceViewModelWatcherErrorTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| ConversationCoordinatorTests.swift | N/A | **YES** | N/A | Tests Coordinator behavior, not mapping; uses async/await |
| CodexServiceTests.swift | N/A | **YES** | N/A | Tests service behavior, not mapping; uses async/await |
| AskCodexPipelineTests.swift | N/A | **YES** | N/A | Tests pipeline behavior, not mapping; uses async/await |
| AskCodexTraceTests.swift | N/A | **YES** | N/A | Tests trace behavior, not mapping; uses async/await |
| ContextPipelineEvidenceTests.swift | N/A | **YES** | N/A | Tests pipeline behavior, not mapping; uses async/await |
| ContextDeterminismTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| ContextSnapshotPresentationTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| ConversationEngineBoxIsolationTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| NavigatorIntegrationTests.swift | N/A | **YES** | N/A | Tests integration behavior, not mapping; uses async/await |
| ModelAndScopeBindingTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| NegativeBehaviorTests.swift | N/A | **YES** | N/A | Tests ViewModel behavior, not mapping; uses async/await |
| ProjectCoordinatorSessionTests.swift | N/A | **YES** | N/A | Tests Coordinator behavior, not mapping; uses async/await |
| WorkspaceBootstrapTests.swift | N/A | **YES** | N/A | Tests bootstrap behavior, not mapping; uses async/await |
| ArchitectureBoundariesTests.swift | N/A | No | N/A | Pure Stratum 2 (boundary validation) |
| FormViolationTests.swift | N/A | No | N/A | Pure Stratum 2 (form validation) |
| All AppCoreEngine tests | N/A | N/A | No | Pure Stratum 3 |

---

## 5. DEPENDENCY LEAK ANALYSIS

### Which ChatUI tests import UIConnections?

**File:** `ChatUI/Tests/ChatUITests/ChatUIViewInitializationTests.swift`
- **Line 5:** `import UIConnections`
- **Usage:** Creates `WorkspaceViewModel`, `ChatViewModel`, `ConversationCoordinator` instances
- **Impact:** Violates Stratum 1 purity; test cannot run without UIConnections module

### Which ChatUI tests import AppCoreEngine?

**File:** `ChatUI/Tests/ChatUITests/ChatUIViewInitializationTests.swift`
- **Implicit import:** Via UIConnections dependency
- **Direct usage:** Creates stubs that conform to AppCoreEngine protocols (`WorkspaceEngine`, `ConversationStreaming`)
- **Domain types used:** `FileID`, `WorkspaceSnapshot`, `FileDescriptor`, `Conversation`, `WorkspaceTreeProjection`, `WorkspaceUpdate`, `ConversationDelta`, `ContextBuildResult`
- **Impact:** Test requires full domain knowledge to construct test doubles

### Which tests would break if AppCoreEngine were rewritten?

**ChatUI Tests:**
- `ChatUIViewInitializationTests.swift` — would break (uses domain types in stubs)

**UIConnections Tests (all 31 files):**
- All files import AppCoreEngine directly or via UIConnections
- All ViewModel behavior tests would break
- All mapping tests would break (they use domain types as input)

**AppComposition Tests:**
- `AppCompositionIntegrationTests.swift` — would break
- `AppSmokeTests.swift` — would break

**AppAdapters Tests:**
- All 10 files import AppCoreEngine — would break

**Total:** 44 test files depend on AppCoreEngine structure.

### Which tests depend on semantic knowledge rather than contracts?

**ChatUI Tests:**
- `ChatUIViewInitializationTests.swift` — depends on:
  - `WorkspaceViewModel` initialization semantics
  - `ChatViewModel` initialization semantics
  - `ConversationCoordinator` initialization semantics
  - Domain protocol semantics (`WorkspaceEngine`, `ConversationStreaming`)

**UIConnections Tests:**
- All 27 ViewModel behavior tests depend on:
  - ViewModel state machine semantics
  - Coordinator orchestration semantics
  - Async workflow semantics
  - Domain effect routing semantics

**AppComposition Tests:**
- Both integration tests depend on:
  - Full composition semantics
  - Lifecycle semantics
  - Environment object propagation semantics

**Total:** 30 test files depend on semantic knowledge beyond contracts.

---

## 6. REDUNDANCY & COUPLING DETECTION

### Tests that duplicate coverage across strata

1. **ChatUIViewInitializationTests.swift** duplicates:
   - View construction testing that should be in Stratum 1 (pure contract)
   - ViewModel initialization that should be in Stratum 2
   - Domain stub creation that should be in Stratum 3

2. **UIConnections ViewModel tests** duplicate:
   - ViewModel behavior testing (should be in Stratum 2 as adapter tests)
   - Domain effect testing (should be in Stratum 3)
   - Integration testing (should be in AppComposition)

3. **AppCompositionIntegrationTests.swift** duplicates:
   - View construction (should be in Stratum 1)
   - ViewModel injection (should be in Stratum 2)
   - Domain engine usage (should be in Stratum 3)

### Tests that implicitly test multiple layers at once

1. **ChatUIViewInitializationTests.swift:**
   - Tests ChatUI view construction (Stratum 1)
   - Tests ViewModel creation (Stratum 2)
   - Tests domain protocol conformance (Stratum 3)

2. **UIConnections ViewModel behavior tests:**
   - Test ViewModel state (Stratum 2)
   - Test domain effect routing (Stratum 3)
   - Test async coordination (cross-cutting)

3. **AppCompositionIntegrationTests.swift:**
   - Tests view hierarchy (Stratum 1)
   - Tests ViewModel injection (Stratum 2)
   - Tests domain engine integration (Stratum 3)
   - Tests composition wiring (integration layer)

### Tests that cannot be cleanly assigned to any stratum

1. **ChatUIViewInitializationTests.swift** — violates Stratum 1, cannot be Stratum 2 or 3
2. **UIConnections ViewModel behavior tests (27 files)** — test behavior, not mapping; cannot be Stratum 2
3. **AppCompositionIntegrationTests.swift** — integration test, not part of three-stratum model
4. **AppAdapters tests** — adapter layer, not part of three-stratum model

---

## 7. GAP ANALYSIS

### Missing ChatUI contract coverage

**Gap:** ChatUI tests do not comprehensively test view rendering with fake ViewState structs.

**Present:**
- `DomainTypeLeakageTest.swift` — proves views can be constructed with fake ViewState
- `JSONRenderingTests.swift` — proves ViewState can be deserialized from JSON

**Missing:**
- Snapshot tests for each major view with various ViewState configurations
- Interaction contract tests (intent closure invocation)
- View hierarchy tests with fake ViewState only
- Edge case rendering tests (empty states, error states, loading states)

**Count:** 4 test files exist, but only 2 are pure Stratum 1. Missing ~10-15 contract-focused test files.

### Missing adapter-level mapping tests

**Gap:** Only 4 of 31 UIConnections test files test pure mapping. Missing comprehensive mapping coverage.

**Present:**
- `MappingTests.swift` — basic mapping logic
- `ConversationViewStateTests.swift` — conversation state mapping
- `ConversationMapperCompletenessTests.swift` — conversation mapper completeness
- `WorkspaceMapperCompletenessTests.swift` — workspace mapper completeness

**Missing:**
- Intent → domain effect mapping tests (comprehensive)
- Domain error → UIContracts error mapping tests
- Domain state transitions → ViewState transitions mapping tests
- Edge case mapping tests (nil values, empty collections, boundary conditions)
- Mapping performance tests (if relevant)

**Count:** 4 mapping test files exist. Missing ~15-20 mapping-focused test files.

### Missing pure domain tests

**Gap:** AppCoreEngine tests exist but may not cover all domain behaviors comprehensively.

**Present:**
- 8 AppCoreEngine test files covering engines, context, budget, encoding, etc.

**Missing:**
- Comprehensive domain invariant tests
- Domain behavior specification tests
- Domain error handling tests
- Domain concurrency safety tests
- Domain determinism tests (beyond what exists)

**Note:** This gap is less severe than the ChatUI and UIConnections gaps, as AppCoreEngine tests are already pure Stratum 3.

---

## 8. VERDICT

**Architecture supports clean test stratification: NO**

**Justification:** ChatUI tests import UIConnections and use ViewModels/Coordinators/domain types, violating Stratum 1. UIConnections tests primarily test ViewModel behavior rather than mapping, violating Stratum 2. Only AppCoreEngine tests are pure Stratum 3. The architecture does not support clean test stratification as defined in the target model.

---

**END OF AUDIT**


