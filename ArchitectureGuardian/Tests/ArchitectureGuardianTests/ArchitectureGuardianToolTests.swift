import XCTest
@testable import ArchitectureGuardianLib

final class ArchitectureGuardianToolTests: XCTestCase {

    func testIllegalImportProducesViolation() {
        let rules = ["App": ["SwiftUI"]]
        let files = ["File.swift": "import Foundation\n"]
        let violations = GuardianRunner.findViolations(rules: rules, fileContents: files, targetName: "App")
        XCTAssertEqual(violations.count, 1)
        XCTAssertTrue(violations.first?.contains("illegal import") == true)
    }

    func testAllowedImportPasses() {
        let rules = ["App": ["Foundation", "SwiftUI"]]
        let files = ["File.swift": "import Foundation\nimport SwiftUI\n"]
        let violations = GuardianRunner.findViolations(rules: rules, fileContents: files, targetName: "App")
        XCTAssertTrue(violations.isEmpty)
    }

    func testRulesAbsentProducesNoViolation() {
        let rules = ["Other": ["Foundation"]]
        let files = ["File.swift": "import Foundation\n"]
        let violations = GuardianRunner.findViolations(rules: rules, fileContents: files, targetName: "App")
        XCTAssertTrue(violations.isEmpty)
    }
}

