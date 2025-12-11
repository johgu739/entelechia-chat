import XCTest
import Foundation

/// Guard tests that enforce ChatUI lifecycle modifier rules.
/// These tests will fail if violations exist, ensuring guards are working.
final class LifecycleGuardTests: XCTestCase {
    
    private let chatUISourcePath = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources")
        .appendingPathComponent("ChatUI")
    
    // MARK: - Lifecycle Modifier Detection
    
    /// Scans ChatUI source files for lifecycle modifiers and asserts no side effects exist.
    func testNoSideEffectsInLifecycleModifiers() throws {
        let violations = try scanForLifecycleSideEffects()
        
        if !violations.isEmpty {
            let message = """
            Found \(violations.count) violation(s) of lifecycle modifier side effect rules:
            
            \(violations.map { "  - \($0.file):\($0.line): \($0.message)" }.joined(separator: "\n"))
            
            Lifecycle modifiers (.onAppear, .onChange, .task, .onReceive) must not contain 
            side effects with engines, coordinators, or domain mutators. Move logic to view models.
            """
            XCTFail(message)
        }
    }
    
    /// Asserts no async `.onChange` patterns exist.
    func testNoAsyncOnChange() throws {
        let violations = try scanForAsyncOnChange()
        
        if !violations.isEmpty {
            let message = """
            Found \(violations.count) violation(s) of async onChange rule:
            
            \(violations.map { "  - \($0.file):\($0.line): \($0.message)" }.joined(separator: "\n"))
            
            .onChange blocks must not contain await. Use view-model async flows instead.
            """
            XCTFail(message)
        }
    }
    
    /// Asserts no `.task` usage exists.
    func testNoTaskModifier() throws {
        let violations = try scanForTaskModifier()
        
        if !violations.isEmpty {
            let message = """
            Found \(violations.count) violation(s) of .task modifier rule:
            
            \(violations.map { "  - \($0.file):\($0.line): \($0.message)" }.joined(separator: "\n"))
            
            .task modifier is forbidden in ChatUI. Use view-model async flows instead.
            """
            XCTFail(message)
        }
    }
    
    /// Asserts no forbidden `.onReceive` patterns exist (except keyboard/animation/size publishers).
    func testNoForbiddenOnReceive() throws {
        let allowedPaths = [
            "ChatUI/Sources/ChatUI/Design/KeyboardAdaptiveInset.swift"
        ]
        let violations = try scanForForbiddenOnReceive(excluding: allowedPaths)
        
        if !violations.isEmpty {
            let message = """
            Found \(violations.count) violation(s) of .onReceive rule:
            
            \(violations.map { "  - \($0.file):\($0.line): \($0.message)" }.joined(separator: "\n"))
            
            .onReceive is forbidden in ChatUI except for keyboard/animation/size publishers. 
            Move event handling to view models.
            """
            XCTFail(message)
        }
    }
    
    // MARK: - Scanning Implementation
    
    private struct Violation {
        let file: String
        let line: Int
        let message: String
    }
    
    private func scanForLifecycleSideEffects() throws -> [Violation] {
        let forbiddenPatterns = [
            "WorkspaceViewModel",
            "ChatViewModel",
            "ConversationCoordinator",
            "CodexService",
            "WorkspaceEngine",
            "ProjectEngine",
            "ConversationEngine",
            "CodexMutationPipeline",
            "ContextSnapshot",
            "FileDescriptor"
        ]
        
        let lifecycleModifiers = ["onAppear", "onChange", "task", "onReceive"]
        var violations: [Violation] = []
        
        try scanSwiftFiles { fileURL, content in
            let lines = content.components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                // Check if line contains a lifecycle modifier
                let hasLifecycleModifier = lifecycleModifiers.contains { modifier in
                    line.contains(".\(modifier)(")
                }
                
                if hasLifecycleModifier {
                    // Check subsequent lines for forbidden patterns
                    var inBlock = false
                    var braceCount = 0
                    var blockStartLine = index + 1
                    
                    for scanIndex in index..<min(index + 50, lines.count) {
                        let scanLine = lines[scanIndex]
                        
                        // Track brace balance to find block boundaries
                        for char in scanLine {
                            if char == "{" {
                                braceCount += 1
                                inBlock = true
                            } else if char == "}" {
                                braceCount -= 1
                                if braceCount == 0 && inBlock {
                                    break
                                }
                            }
                        }
                        
                        // Check for forbidden patterns in the block
                        for pattern in forbiddenPatterns {
                            if scanLine.contains(pattern) {
                                violations.append(Violation(
                                    file: fileURL.lastPathComponent,
                                    line: scanIndex + 1,
                                    message: "Found \(pattern) in lifecycle modifier block"
                                ))
                            }
                        }
                        
                        if braceCount == 0 && inBlock {
                            break
                        }
                    }
                }
            }
        }
        
        return violations
    }
    
    private func scanForAsyncOnChange() throws -> [Violation] {
        var violations: [Violation] = []
        
        try scanSwiftFiles { fileURL, content in
            let lines = content.components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                if line.contains(".onChange(") {
                    // Check subsequent lines for await
                    var inBlock = false
                    var braceCount = 0
                    
                    for scanIndex in index..<min(index + 50, lines.count) {
                        let scanLine = lines[scanIndex]
                        
                        for char in scanLine {
                            if char == "{" {
                                braceCount += 1
                                inBlock = true
                            } else if char == "}" {
                                braceCount -= 1
                                if braceCount == 0 && inBlock {
                                    break
                                }
                            }
                        }
                        
                        if scanLine.contains("await") {
                            violations.append(Violation(
                                file: fileURL.lastPathComponent,
                                line: scanIndex + 1,
                                message: "Found await in .onChange block"
                            ))
                        }
                        
                        if braceCount == 0 && inBlock {
                            break
                        }
                    }
                }
            }
        }
        
        return violations
    }
    
    private func scanForTaskModifier() throws -> [Violation] {
        var violations: [Violation] = []
        
        try scanSwiftFiles { fileURL, content in
            let lines = content.components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                if line.contains(".task(") {
                    violations.append(Violation(
                        file: fileURL.lastPathComponent,
                        line: index + 1,
                        message: "Found .task modifier usage"
                    ))
                }
            }
        }
        
        return violations
    }
    
    private func scanForForbiddenOnReceive(excluding allowedPaths: [String]) throws -> [Violation] {
        var violations: [Violation] = []
        
        try scanSwiftFiles { fileURL, content in
            let relativePath = fileURL.path
            let isExcluded = allowedPaths.contains { relativePath.contains($0) }
            
            if isExcluded {
                return
            }
            
            let lines = content.components(separatedBy: .newlines)
            
            for (index, line) in lines.enumerated() {
                if line.contains(".onReceive(") {
                    // Check if it's a keyboard/animation/size publisher
                    let isAllowed = line.contains("keyboard") ||
                                   line.contains("animation") ||
                                   line.contains("size") ||
                                   line.contains("NotificationCenter.default.publisher")
                    
                    if !isAllowed {
                        violations.append(Violation(
                            file: fileURL.lastPathComponent,
                            line: index + 1,
                            message: "Found forbidden .onReceive usage (not keyboard/animation/size)"
                        ))
                    }
                }
            }
        }
        
        return violations
    }
    
    // MARK: - File Scanning Helpers
    
    private func scanSwiftFiles(_ block: (URL, String) throws -> Void) throws {
        let fileManager = FileManager.default
        
        guard fileManager.fileExists(atPath: chatUISourcePath.path) else {
            XCTFail("ChatUI source path does not exist: \(chatUISourcePath.path)")
            return
        }
        
        let enumerator = fileManager.enumerator(
            at: chatUISourcePath,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension == "swift" else { continue }
            
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            try block(fileURL, content)
        }
    }
}
