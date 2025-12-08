import XCTest
@testable import AppAdapters

final class KeychainServiceAdapterTests: XCTestCase {

    func testSaveLoadDeletePasswordRoundTrip() throws {
        let adapter = KeychainServiceAdapter()
        let service = "chat.entelechia.tests.\(UUID().uuidString)"
        let account = UUID().uuidString
        defer { try? adapter.deletePassword(service: service, account: account) }

        XCTAssertNil(try adapter.loadPassword(service: service, account: account))

        try adapter.savePassword("secret", service: service, account: account)
        XCTAssertEqual(try adapter.loadPassword(service: service, account: account), "secret")

        try adapter.deletePassword(service: service, account: account)
        XCTAssertNil(try adapter.loadPassword(service: service, account: account))
    }
}

