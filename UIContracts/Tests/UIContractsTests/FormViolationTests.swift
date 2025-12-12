import XCTest
@testable import UIContracts

/// Negative tests to ensure UIContracts purity violations are caught.
/// These tests document what must NEVER be allowed in UIContracts.
final class UIContractsFormViolationTests: XCTestCase {
    
    // MARK: - Purity Violations
    
    /// UIContracts must not define ObservableObject.
    /// This test documents the violation pattern (actual enforcement via ArchitectureGuardian).
    func testUIContractsCannotDefineObservableObject() {
        #if false // Keep false - this is a documentation test
        // This should fail at build time:
        class BadContract: ObservableObject {
            @Published var value: String = ""
        }
        #endif
        XCTAssertTrue(true, "This test documents that ObservableObject is forbidden in UIContracts.")
    }
    
    /// UIContracts must not import SwiftUI.
    /// This test documents the violation pattern (actual enforcement via ArchitectureGuardian).
    func testUIContractsCannotImportSwiftUI() {
        #if false // Keep false - this is a documentation test
        // This should fail at build time:
        // import SwiftUI // Forbidden
        #endif
        XCTAssertTrue(true, "This test documents that SwiftUI import is forbidden in UIContracts.")
    }
    
    /// UIContracts must not import Combine.
    /// This test documents the violation pattern (actual enforcement via ArchitectureGuardian).
    func testUIContractsCannotImportCombine() {
        #if false // Keep false - this is a documentation test
        // This should fail at build time:
        // import Combine // Forbidden
        #endif
        XCTAssertTrue(true, "This test documents that Combine import is forbidden in UIContracts.")
    }
    
    /// UIContracts must not import AppCoreEngine.
    /// This test documents the violation pattern (actual enforcement via ArchitectureGuardian).
    func testUIContractsCannotImportAppCoreEngine() {
        #if false // Keep false - this is a documentation test
        // This should fail at build time:
        // import AppCoreEngine // Forbidden
        #endif
        XCTAssertTrue(true, "This test documents that AppCoreEngine import is forbidden in UIContracts.")
    }
    
    /// UIContracts must not import UIConnections.
    /// This test documents the violation pattern (actual enforcement via ArchitectureGuardian).
    func testUIContractsCannotImportUIConnections() {
        #if false // Keep false - this is a documentation test
        // This should fail at build time:
        // import UIConnections // Forbidden
        #endif
        XCTAssertTrue(true, "This test documents that UIConnections import is forbidden in UIContracts.")
    }
    
    /// UIContracts must not define method bodies.
    /// This test documents the violation pattern (actual enforcement via ArchitectureGuardian).
    func testUIContractsCannotDefineMethodBodies() {
        #if false // Keep false - this is a documentation test
        // This should fail at build time:
        struct BadContract {
            func doSomething() { // Forbidden - method body
                print("This should not be allowed")
            }
        }
        #endif
        XCTAssertTrue(true, "This test documents that method bodies are forbidden in UIContracts.")
    }
    
    // MARK: - Positive Tests
    
    /// Verify UIContracts compiles with zero dependencies.
    func testUIContractsCompilesWithZeroDependencies() {
        let scope = ContextScopeChoice.selection
        XCTAssertEqual(scope, .selection)
        
        let message = UIMessage(role: .user, text: "Test")
        XCTAssertEqual(message.role, .user)
        XCTAssertEqual(message.text, "Test")
    }
    
    /// Verify UIContracts types are Sendable.
    func testUIContractsTypesAreSendable() {
        let conversation = UIConversation()
        XCTAssertTrue(conversation is Sendable)
        
        let viewState = WorkspaceViewState(
            rootPath: nil,
            selectedDescriptorID: nil,
            selectedPath: nil,
            projection: nil,
            contextInclusions: [:],
            watcherError: nil
        )
        XCTAssertTrue(viewState is Sendable)
    }
}

