# Lifecycle Violations Report

**Generated**: December 11, 2025 07:19:15 WET  
**Guard Status**: ❌ **BUILD FAILING**  
**Total Violations**: 4 (ArchitectureGuardian detected)

---

## Executive Summary

The lifecycle enforcement guards have detected **4 violations** that must be fixed before the build can pass:

- **3 violations**: `.task` modifier usage (forbidden in ChatUI)
- **1 violation**: `.onReceive` usage (forbidden except keyboard/animation/size publishers)

All violations are detected by **ArchitectureGuardian** and will cause the build to fail until resolved.

---

## Detailed Violations

### Violation #1: `.task` Modifier in AsyncFilePreviewView.swift

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFilePreviewView.swift`  
**Line**: 29  
**Rule**: `task_forbidden_chatui_strict`  
**Severity**: Error

**Code**:
```swift
.task(id: url) {
    isLoading = true
    error = nil
    content = nil
    do {
        let fileKind = FileTypeClassifier.kind(for: url)
        guard FileTypeClassifier.isTextLike(fileKind) else {
            error = FilePreviewError.notATextFile
            isLoading = false
            return
        }
        
        let loadTask = Task(priority: .utility) {
            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) {
                let lines = text.components(separatedBy: .newlines)
                return lines.prefix(1000).joined(separator: "\n")
            }
            return try String(contentsOf: url, encoding: .utf8)
        }
        content = try await loadTask.value
    } catch {
        self.error = error
    }
    isLoading = false
}
```

**Issue**: Uses `.task` modifier to load file content asynchronously. This violates the rule that async work must be handled in view models, not views.

**Recommended Fix**:
1. Create a method in `FileMetadataViewModel` (or a new view model) for loading file preview content
2. Call the method explicitly from the view (e.g., in a button action or from parent view)
3. Use `@State` or `@Binding` to observe the result

---

### Violation #2: `.task` Modifier in AsyncFileStatsRowView.swift

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFileStatsRowView.swift`  
**Line**: 41  
**Rule**: `task_forbidden_chatui_strict`  
**Severity**: Error

**Code**:
```swift
.task(id: url) {
    isLoading = true
    size = nil
    lineCount = nil
    tokenEstimate = nil
    do {
        let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
        size = resourceValues.fileSize.map(Int64.init)
        if let fileSize = resourceValues.fileSize {
            tokenEstimate = TokenEstimator.estimateTokens(forByteCount: fileSize)
        }
    } catch {
        print("Failed to get file size: \(error.localizedDescription)")
    }
    lineCount = await metadataViewModel.lineCount(for: url)
    isLoading = false
}
```

**Issue**: Uses `.task` modifier to load file statistics (size, line count, token estimate) asynchronously.

**Recommended Fix**:
1. Add a method to `FileMetadataViewModel` that loads all file stats at once
2. Call this method from the parent view or use explicit state observation
3. Remove the `.task` modifier

---

### Violation #3: `.task` Modifier in AsyncFolderStatsView.swift

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFolderStatsView.swift`  
**Line**: 39  
**Rule**: `task_forbidden_chatui_strict`  
**Severity**: Error

**Code**:
```swift
.task(id: url) {
    isLoading = true
    stats = await metadataViewModel.folderStats(for: url)
    isLoading = false
}
```

**Issue**: Uses `.task` modifier to load folder statistics asynchronously.

**Recommended Fix**:
1. Add a method to `FileMetadataViewModel` for loading folder stats
2. Call this method explicitly from the parent view
3. Use state observation to update the view when stats are loaded

---

### Violation #4: `.onReceive` in ContextInspector.swift

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift`  
**Line**: 70  
**Rule**: `onreceive_forbidden_chatui_strict`  
**Severity**: Error

**Code**:
```swift
.onReceive(workspaceViewModel.contextErrorPublisher) { message in
    withAnimation { contextErrorBanner = message }
}
```

**Issue**: Uses `.onReceive` to handle view model publisher events. This violates the rule that event handling should be done through explicit state binding or view model methods, not lifecycle modifiers.

**Recommended Fix**:
1. Expose `contextErrorBanner` as a `@Published` property in `WorkspaceViewModel` or a dedicated view model
2. Use `@ObservedObject` or `@StateObject` to observe the property directly
3. Remove the `.onReceive` modifier

**Additional Note**: The same file also has `.onChange(of: workspaceViewModel.lastContextResult)` on line 65, which may need review for potential side effects.

---

## Additional Lifecycle Modifier Usage (Not Violations)

These files use lifecycle modifiers but are either explicitly allowed or contain only UI-only side effects:

### ✅ Allowed: Keyboard Publishers

**File**: `ChatUI/Sources/ChatUI/Design/KeyboardAdaptiveInset.swift`  
**Lines**: 12, 18  
**Usage**: `.onReceive(NotificationCenter.default.publisher(...))`  
**Status**: ✅ **Explicitly Allowed**  
**Reason**: Keyboard publishers are explicitly excluded from the `.onReceive` ban.

### ✅ Allowed: UI-Only Side Effects

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatInputView.swift`  
**Line**: 125  
**Usage**: `.onChange(of: text) { ... }`  
**Status**: ✅ **Allowed**  
**Reason**: UI-only text change handling (removing newlines on Enter key).

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ChatMessagesList.swift`  
**Lines**: 23, 30  
**Usage**: `.onChange(of: conversation.messages.count)` and `.onChange(of: streamingText)`  
**Status**: ✅ **Allowed**  
**Reason**: UI-only scroll animations, no domain logic side effects.

### ⚠️ Needs Review

**File**: `ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift`  
**Line**: 65  
**Usage**: `.onChange(of: workspaceViewModel.lastContextResult) { _, newValue in ... }`  
**Status**: ⚠️ **Needs Review**  
**Reason**: Accesses `workspaceViewModel` property in lifecycle modifier. While it only clears a banner (UI-only), it references a view model property which may need refactoring for consistency.

---

## Detection Methods

### ArchitectureGuardian ✅ Active

**Status**: ✅ **Working**  
**Configuration**: `ArchitectureGuardian/ArchitectureRules.json`  
**Detections**:
- ✅ Detects `.task` modifier usage
- ✅ Detects `.onReceive` usage (except excluded paths)
- ✅ Exits with code 1 when violations found

**Output**:
```
/Users/johangunnarsson/Developer/entelechia-chat/ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFileStatsRowView.swift: .task modifier is forbidden in ChatUI. Use view-model async flows instead.
/Users/johangunnarsson/Developer/entelechia-chat/ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFilePreviewView.swift: .task modifier is forbidden in ChatUI. Use view-model async flows instead.
/Users/johangunnarsson/Developer/entelechia-chat/ChatUI/Sources/ChatUI/UI/ConversationUI/Context/AsyncFolderStatsView.swift: .task modifier is forbidden in ChatUI. Use view-model async flows instead.
/Users/johangunnarsson/Developer/entelechia-chat/ChatUI/Sources/ChatUI/UI/ConversationUI/ContextInspector.swift: .onReceive is forbidden in ChatUI except for keyboard/animation/size publishers. Move event handling to view models.
```

### SwiftLint Custom Rules ⚠️ Configured

**Status**: ⚠️ **Configured but may need regex adjustments**  
**Configuration**: `.swiftlint.yml`  
**Rules**:
- `forbidden_chatui_lifecycle_side_effects`
- `onchange_async_forbidden`
- `task_forbidden_chatui_strict`
- `onreceive_forbidden_chatui_strict`

**Note**: SwiftLint shows "Invalid configuration" warnings for these rules, suggesting regex patterns may need adjustment. ArchitectureGuardian is currently the primary detection mechanism.

### Guard Tests ✅ Available

**Status**: ✅ **Implemented**  
**Location**: `ChatUI/Tests/ChatUITests/LifecycleGuardTests.swift`  
**Tests**:
- `testNoSideEffectsInLifecycleModifiers()`
- `testNoAsyncOnChange()`
- `testNoTaskModifier()`
- `testNoForbiddenOnReceive()`

**Note**: Tests scan source files and will fail if violations exist.

---

## Build Status

**Current Status**: ❌ **BUILD FAILING**

The build will fail until all violations are resolved:
- ArchitectureGuardian exits with code 1 when violations are detected
- CI/CD pipeline will fail on `./scripts/layering-guard.sh`
- All 4 violations must be fixed before the build can pass

---

## Fix Priority

### High Priority (Blocking Build)

1. **Violation #4**: `.onReceive` in `ContextInspector.swift`
   - **Impact**: Blocks build
   - **Complexity**: Low-Medium
   - **Fix**: Replace with explicit state binding

2. **Violation #3**: `.task` in `AsyncFolderStatsView.swift`
   - **Impact**: Blocks build
   - **Complexity**: Low
   - **Fix**: Move to view model method

3. **Violation #2**: `.task` in `AsyncFileStatsRowView.swift`
   - **Impact**: Blocks build
   - **Complexity**: Low-Medium
   - **Fix**: Move to view model method

4. **Violation #1**: `.task` in `AsyncFilePreviewView.swift`
   - **Impact**: Blocks build
   - **Complexity**: Medium
   - **Fix**: Move to view model method

### Medium Priority (Code Quality)

5. **Review**: `.onChange` in `ContextInspector.swift` (line 65)
   - **Impact**: Code quality / consistency
   - **Complexity**: Low
   - **Action**: Review for potential refactoring

---

## Verification Steps

After fixing violations, verify with:

```bash
# 1. Run ArchitectureGuardian
./scripts/layering-guard.sh
# Expected: Exit code 0, no violations

# 2. Run SwiftLint
swiftlint lint --config .swiftlint.yml ChatUI
# Expected: No lifecycle-related errors

# 3. Run guard tests
swift test --package-path ChatUI --filter LifecycleGuardTests
# Expected: All tests pass

# 4. Run full test suite
swift test --package-path ChatUI
swift test --package-path UIConnections
# Expected: All tests pass
```

---

## Rules Reference

### Forbidden Patterns

1. **`.task` modifier**: Completely forbidden in ChatUI
2. **`.onReceive`**: Forbidden except for keyboard/animation/size publishers
3. **Side effects in lifecycle modifiers**: Engines, coordinators, domain mutators forbidden
4. **Async `.onChange`**: `await` forbidden in `.onChange` blocks

### Allowed Patterns

1. **UI-only side effects**: Focus state, scroll animations
2. **Keyboard publishers**: `NotificationCenter.default.publisher` for keyboard events
3. **Animation publishers**: Size/animation-related publishers

---

## Notes

- All violations are detected by ArchitectureGuardian
- SwiftLint rules are configured but may need regex pattern adjustments
- Guard tests provide additional verification
- The build will remain red until all violations are fixed
- No code refactoring has been performed—only guards were added

---

**Report End**

