import XCTest
@testable import UIContracts

final class UIContractsTests: XCTestCase {
    func testUIContractsCompiles() {
        // Verify UIContracts compiles with zero dependencies
        let scope = ContextScopeChoice.selection
        XCTAssertEqual(scope, .selection)
    }
}


