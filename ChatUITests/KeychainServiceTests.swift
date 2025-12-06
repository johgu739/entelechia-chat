import XCTest
@testable import ChatUI

final class KeychainServiceTests: XCTestCase {
    func testSaveLoadAndDeletePassword() throws {
        let service = KeychainService.shared
        let credential = KeychainCredential(
            service: "chat.entelechia.tests.\(UUID().uuidString)",
            account: UUID().uuidString
        )

        defer { try? service.deletePassword(for: credential) }

        XCTAssertNil(try service.loadPassword(for: credential))

        try service.savePassword("secret-value", for: credential)
        XCTAssertEqual(try service.loadPassword(for: credential), "secret-value")

        try service.deletePassword(for: credential)
        XCTAssertNil(try service.loadPassword(for: credential))
    }
}
