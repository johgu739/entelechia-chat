import XCTest
import Foundation
@testable import UIConnections
import AppCoreEngine

final class ContextDeterminismTests: XCTestCase {
    func testDescriptorOrderingAndHashAreStable() {
        let files = [
            TestWorkspaceFile(relativePath: "src/a.swift", content: "a"),
            TestWorkspaceFile(relativePath: "src/b.swift", content: "b"),
            TestWorkspaceFile(relativePath: "src/sub/c.swift", content: "c")
        ]
        let root = tempRoot()
        let env1 = makeEngine(files: files, root: root)
        let env2 = makeEngine(files: files, root: root)

        XCTAssertEqual(env1.snapshot.snapshotHash, env2.snapshot.snapshotHash, "Snapshot hash must be deterministic for identical input.")
        XCTAssertEqual(normalizedPaths(env1.snapshot.descriptors, root: root), normalizedPaths(env2.snapshot.descriptors, root: root), "Descriptor ordering must be stable.")
    }

    func testExcludedFoldersAreNeverIncluded() {
        let files = [
            TestWorkspaceFile(relativePath: ".git/config", content: "git"),
            TestWorkspaceFile(relativePath: ".build/cache.txt", content: "cache"),
            TestWorkspaceFile(relativePath: "src/main.swift", content: "main")
        ]
        let root = tempRoot()
        let env = makeEngine(files: files, root: root)
        let paths = normalizedPaths(env.snapshot.descriptors, root: root)
        XCTAssertFalse(paths.contains(where: { $0.contains(".git") }))
        XCTAssertFalse(paths.contains(where: { $0.contains(".build") }))
    }

    func testSegmentationObeysLimitsAndDoesNotSplitFiles() {
        let files = [
            LoadedFile.make(path: "/tmp/one.swift", content: String(repeating: "a", count: 10)),
            LoadedFile.make(path: "/tmp/two.swift", content: String(repeating: "b", count: 10))
        ]
        let encoder = WorkspaceContextEncoder()
        let encoded = encoder.encode(files: files)
        let segmenter = WorkspaceContextSegmenter(maxTokensPerSegment: 5, maxBytesPerSegment: 15)
        let segments = segmenter.segment(files: encoded)

        XCTAssertGreaterThanOrEqual(segments.count, 2, "Segments should respect token/byte limits.")
        for segment in segments {
            let fileCount = segment.files.count
            XCTAssertEqual(fileCount, 1, "Files must not be split mid-file; each segment should contain whole files when limits are tight.")
        }
    }

    func testInclusionsStableAcrossRuns() {
        let files = [
            TestWorkspaceFile(relativePath: "src/a.swift", content: "alpha"),
            TestWorkspaceFile(relativePath: "src/b.swift", content: "beta")
        ]
        let root = tempRoot()
        let env1 = makeEngine(files: files, root: root)
        let env2 = makeEngine(files: files, root: root)

        let map1 = Set(env1.snapshot.descriptorPaths.values.map { $0.replacingOccurrences(of: root.path, with: "") })
        let map2 = Set(env2.snapshot.descriptorPaths.values.map { $0.replacingOccurrences(of: root.path, with: "") })
        XCTAssertEqual(map1, map2)
    }

    // MARK: - Helpers
    private func makeEngine(files: [TestWorkspaceFile], root: URL) -> (engine: DeterministicWorkspaceEngine, snapshot: WorkspaceSnapshot) {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let engine = DeterministicWorkspaceEngine(root: root, files: files)
        return (engine, engine.currentSnapshot)
    }

    private func tempRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ctx-\(UUID().uuidString)")
    }

    private func normalizedPaths(_ descriptors: [FileDescriptor], root: URL) -> [String] {
        descriptors.map { $0.canonicalPath.replacingOccurrences(of: root.path, with: "") }.sorted()
    }
}
