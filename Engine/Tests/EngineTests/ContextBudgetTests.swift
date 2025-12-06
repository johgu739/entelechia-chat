import XCTest
@testable import Engine

final class ContextBudgetTests: XCTestCase {

    func testPerFileTrim() {
        let long = String(repeating: "a", count: 40_000)
        let file = LoadedFile(
            name: "long.txt",
            url: URL(fileURLWithPath: "/long.txt"),
            content: long,
            fileTypeIdentifier: nil
        )
        let budget = ContextBudget(maxPerFileBytes: 1024, maxPerFileTokens: 1_000, maxTotalBytes: 1_000_000, maxTotalTokens: 1_000_000)
        let result = ContextBuilder(budget: budget).build(from: [file])
        XCTAssertEqual(result.truncatedFiles.count, 1)
        XCTAssertLessThanOrEqual(result.attachments.first?.byteCount ?? 0, budget.maxPerFileBytes)
    }

    func testTotalByteExclusion() {
        let file = LoadedFile(
            name: "huge.txt",
            url: URL(fileURLWithPath: "/huge.txt"),
            content: String(repeating: "b", count: 10_000),
            fileTypeIdentifier: nil
        )
        let budget = ContextBudget(maxPerFileBytes: 50_000, maxPerFileTokens: 50_000, maxTotalBytes: 1_000, maxTotalTokens: 50_000)
        let result = ContextBuilder(budget: budget).build(from: [file])
        XCTAssertEqual(result.attachments.count, 0)
        XCTAssertEqual(result.excludedFiles.count, 1)
    }
}

