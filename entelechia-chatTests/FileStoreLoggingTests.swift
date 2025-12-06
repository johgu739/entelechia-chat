import XCTest
@testable import entelechia_chat

@MainActor
final class FileStoreLoggingTests: XCTestCase {
    func testSaveAndDeleteDoNotThrow() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let store = FileStore(baseURL: base)
        let tempURL = base.appendingPathComponent(UUID().uuidString).appendingPathExtension("json")
        
        struct Sample: Codable, Equatable { let value: String }
        let sample = Sample(value: "hello")
        
        try await MainActor.run {
            XCTAssertNoThrow(try store.save(sample, to: tempURL))
            let loaded: Sample? = try store.load(Sample.self, from: tempURL)
            XCTAssertEqual(loaded, sample)
            XCTAssertNoThrow(try store.delete(at: tempURL))
            XCTAssertNil(try store.load(Sample.self, from: tempURL))
        }
    }
}

