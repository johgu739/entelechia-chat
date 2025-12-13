# UIConnections ORDER 6 — OSLogMessage Error Log

**Date:** After ORDER 5 completion  
**Purpose:** Capture exact OSLogMessage compiler errors for systematic resolution

---

## Error 1: ProjectCoordinator.swift

**File Path:** `UIConnections/Sources/UIConnections/Projects/ProjectCoordinator.swift`  
**Line Number:** 72  
**Error Message:** `cannot convert value of type 'String' to expected argument type 'OSLogMessage'`

**Offending Code:**
```swift
logger.error(
    "Failed to open recent project \(project.representation.rootPath): " +
    "\(error.localizedDescription)"
)
```

**Context:**
- Line 70-74: Error handling block in `openRecentProject` method
- The issue is string concatenation (`+`) being used with Logger interpolation
- Logger expects OSLogMessage, not concatenated String

---

## Error 2: FileNode.swift

**File Path:** `UIConnections/Sources/UIConnections/Workspaces/FileNode.swift`  
**Line Number:** 120  
**Error Message:** `binary operator '+' cannot be applied to two 'OSLogMessage' operands`

**Offending Code:**
```swift
FileNode.logger.error(
    "Could not read resource values for \(url.path, privacy: .private): " +
    "\(error.localizedDescription, privacy: .public)"
)
```

**Context:**
- Line 118-122: Error handling in file reading logic
- The issue is attempting to concatenate two OSLogMessage expressions with `+`
- Logger interpolation creates OSLogMessage, not String, so concatenation fails

---

## Summary

**Total Errors:** 2  
**Error Type:** OSLogMessage API misuse  
**Root Cause:** String concatenation (`+`) used with Logger interpolation, which returns OSLogMessage not String

**Fix Strategy:**
- Replace string concatenation with single interpolation expression
- Combine both values into one Logger call with proper interpolation

---

## Fix Pattern

**Before (incorrect):**
```swift
logger.error("Message \(value1): " + "\(value2)")
```

**After (correct):**
```swift
logger.error("Message \(value1): \(value2)")
```

Or if privacy is needed:
```swift
logger.error("Message \(value1, privacy: .public): \(value2, privacy: .public)")
```


