import XCTest
@testable import AppCoreEngine

final class WorkspaceContextEncodingTests: XCTestCase {

    func testEncodingIsDeterministic() {
        let files = [
            LoadedFile(name: "b.swift", url: URL(fileURLWithPath: "/root/b.swift"), content: "print(\"b\")"),
            LoadedFile(name: "a.swift", url: URL(fileURLWithPath: "/root/a.swift"), content: "print(\"a\")")
        ]

        let encoder = WorkspaceContextEncoder()
        let first = encoder.encode(files: files)
        let second = encoder.encode(files: files.reversed())

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.map(\.path), ["/root/a.swift", "/root/b.swift"])
    }

    func testSegmenterSplitsByTokenAndByteLimitWithoutMidFileSplit() {
        // Each file ~14 bytes, 2 tokens for simplicity (TokenEstimator is stubbed here via the LoadedFile tokenEstimate field)
        let file1 = EncodedContextFile(path: "/root/a", language: "text", hash: "h1", size: 9000, tokenEstimate: 2000, content: String(repeating: "a", count: 9000))
        let file2 = EncodedContextFile(path: "/root/b", language: "text", hash: "h2", size: 9000, tokenEstimate: 2000, content: String(repeating: "b", count: 9000))
        let file3 = EncodedContextFile(path: "/root/c", language: "text", hash: "h3", size: 9000, tokenEstimate: 2000, content: String(repeating: "c", count: 9000))

        let segmenter = WorkspaceContextSegmenter(maxTokensPerSegment: 4000, maxBytesPerSegment: 18000)
        let segments = segmenter.segment(files: [file1, file2, file3])

        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments[0].files.map(\.path), ["/root/a", "/root/b"])
        XCTAssertEqual(segments[1].files.map(\.path), ["/root/c"])
        XCTAssertLessThanOrEqual(segments[0].totalTokens, 4000)
        XCTAssertLessThanOrEqual(segments[0].totalBytes, 18000)
        XCTAssertEqual(segments[0].totalBytes, file1.size + file2.size)
    }

    func testUtf8IntegrityPreservedInEncoding() {
        let unicode = "🙂 emoji"
        let file = LoadedFile(name: "u.txt", url: URL(fileURLWithPath: "/root/u.txt"), content: unicode)
        let encoder = WorkspaceContextEncoder()
        let encoded = encoder.encode(files: [file])
        XCTAssertEqual(encoded.first?.content, unicode)
    }
}

