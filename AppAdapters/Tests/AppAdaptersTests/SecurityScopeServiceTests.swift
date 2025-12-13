import XCTest
@testable import AppAdapters
import AppCoreEngine

final class SecurityScopeServiceTests: XCTestCase {

    func testNoopSecurityScopeLifecycle() throws {
        let handler = NoopSecurityScopeHandler()
        let url = URL(fileURLWithPath: "/")

        let bookmark = try handler.createBookmark(for: url)
        let resolved = try handler.resolveBookmark(bookmark)
        XCTAssertTrue(handler.startAccessing(resolved))
        handler.stopAccessing(resolved)
    }
}



