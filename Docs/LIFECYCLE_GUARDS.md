# ChatUI Lifecycle Enforcement Guards

## Overview

This document describes the enforcement mechanisms (SwiftLint rules, ArchitectureGuardian rules, and tests) that prevent side effects in ChatUI lifecycle modifiers. These guards will fail on existing violations, ensuring that lifecycle refactoring is required before the build can pass.

## Implementation Summary

### 1. SwiftLint Custom Rules (`.swiftlint.yml`)

Four new custom rules have been added:

#### `forbidden_chatui_lifecycle_side_effects`
- **Purpose**: Detect engines/coordinators/domain mutators in `.onAppear`, `.onChange`, `.task`, `.onReceive` bodies
- **Pattern**: Detects lifecycle modifiers containing references to `WorkspaceViewModel`, `ChatViewModel`, `ConversationCoordinator`, or `CodexService`
- **Severity**: Error
- **Excluded**: Test files

#### `onchange_async_forbidden`
- **Purpose**: Detect `await` inside `.onChange` blocks
- **Pattern**: Detects `.onChange` blocks containing `await` keyword
- **Severity**: Error
- **Excluded**: Test files

#### `task_forbidden_chatui_strict`
- **Purpose**: Detect `.task(` usage (strict, no allowlist)
- **Pattern**: Detects any `.task(` modifier usage
- **Severity**: Error
- **Excluded**: Test files

#### `onreceive_forbidden_chatui_strict`
- **Purpose**: Detect `.onReceive` except keyboard/animation/size publishers
- **Pattern**: Detects `.onReceive(` usage
- **Severity**: Error
- **Excluded**: Test files, `ChatUI/Sources/ChatUI/Design/KeyboardAdaptiveInset.swift`

### 2. ArchitectureGuardian Rules (`ArchitectureGuardian/ArchitectureRules.json`)

Extended the `ChatUI` target's `forbidden` array with rules blocking:

- References to `WorkspaceViewModel`, `ChatViewModel`, `ConversationCoordinator`, `CodexService` inside lifecycle modifier bodies
- Pattern matching for lifecycle modifiers containing domain logic
- `.onChange` blocks containing `await`
- `.task` modifier usage
- `.onReceive` usage (except in KeyboardAdaptiveInset.swift)

### 3. Guard Tests

#### ChatUI Guard Tests (`ChatUI/Tests/ChatUITests/LifecycleGuardTests.swift`)

Test suite that scans ChatUI source files for lifecycle modifier violations:

- `testNoSideEffectsInLifecycleModifiers()`: Asserts no side effects in lifecycle modifiers
- `testNoAsyncOnChange()`: Asserts no async `.onChange` patterns exist
- `testNoTaskModifier()`: Asserts no `.task` usage exists
- `testNoForbiddenOnReceive()`: Asserts no forbidden `.onReceive` patterns exist

#### UIConnections VM Tests (`UIConnections/Tests/UIConnectionsTests/WorkspaceViewModelLifecycleEnforcementTests.swift`)

Test suite that ensures view models expose explicit methods:

- `testViewModelExposesExplicitMethods()`: Tests that VMs expose explicit methods (no lifecycle triggers needed)
- `testAsyncWorkHandledInViewModels()`: Tests that async work is handled in VMs, not views
- `testViewModelInitializationDoesNotRequireOnAppear()`: Tests that VM initialization doesn't require `.onAppear` hacks
- `testChatViewModelExposesExplicitMethods()`: Tests ChatViewModel API
- `testStateChangesThroughExplicitMethods()`: Tests that state changes happen through explicit methods

## Current Violations

As of implementation, the following violations were detected:

### ArchitectureGuardian Violations

1. **`.task` modifier violations** (3 files):
   - `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFolderStatsView.swift`
   - `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFilePreviewView.swift`
   - `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFileStatsRowView.swift`

2. **`.onReceive` violation** (1 file):
   - `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift`

### Expected Behavior

- **Build Status**: The build will be red until lifecycle refactoring is completed
- **ArchitectureGuardian**: Will fail with exit code 1 when violations are detected
- **SwiftLint**: Will report errors for lifecycle modifier violations
- **Tests**: Guard tests will fail if violations exist

## Verification

To verify the guards are working:

```bash
# Run ArchitectureGuardian
./scripts/layering-guard.sh

# Run SwiftLint
swiftlint lint --config .swiftlint.yml ChatUI

# Run guard tests
swift test --package-path ChatUI --filter LifecycleGuardTests
swift test --package-path UIConnections --filter WorkspaceViewModelLifecycleEnforcementTests
```

## Next Steps

1. Refactor lifecycle modifiers to remove side effects
2. Move async work to view models
3. Replace `.task` modifiers with view-model async flows
4. Replace `.onReceive` with view-model event handling (except keyboard/animation/size publishers)
5. Ensure all guards pass before merging

## Notes

- The guards are intentionally strict and will fail on existing violations
- No code refactoring was performed—only guards were added
- The build will remain red until lifecycle refactoring is completed
- Keyboard/animation/size publishers in `KeyboardAdaptiveInset.swift` are explicitly allowed
