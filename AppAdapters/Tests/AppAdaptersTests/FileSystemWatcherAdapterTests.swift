import XCTest
@testable import AppAdapters

final class FileSystemWatcherAdapterTests: XCTestCase {
    func testWatchFinishesWhenRootMissing() async {
        let watcher = FileSystemWatcherAdapter()
        let stream = watcher.watch(rootPath: "/nonexistent-\(UUID().uuidString)")

        let expectation = expectation(description: "Stream finishes")
        let task = Task {
            var iterator = stream.makeAsyncIterator()
            let next: Void? = await iterator.next()
            XCTAssertNil(next)
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 1.0)
        task.cancel()
    }

    func testWatchEmitsOnFileChange() async throws {
        let temp = try makeTemporaryDirectory()
        let watcher = FileSystemWatcherAdapter()
        let stream = watcher.watch(rootPath: temp.path)

        let expectation = expectation(description: "Receive change event")
        expectation.expectedFulfillmentCount = 1

        let task = Task {
            for await _ in stream {
                expectation.fulfill()
                break
            }
        }

        // Trigger a change
        let fileURL = temp.appendingPathComponent("event.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 200_000_000) // allow watcher to observe

        await fulfillment(of: [expectation], timeout: 6.0)
        task.cancel()
    }

    func testCoalescesRapidEventsAndStopsOnCancel() async throws {
        let temp = try makeTemporaryDirectory()
        let watcher = FileSystemWatcherAdapter()
        let stream = watcher.watch(rootPath: temp.path)
        var iterator = stream.makeAsyncIterator()

        let eventExpectation = expectation(description: "Initial/coalesced tick received")

        var received = 0
        let consumer = Task {
            while let _ = await iterator.next() {
                received += 1
                if received == 1 {
                    eventExpectation.fulfill()
                }
            }
        }

        await fulfillment(of: [eventExpectation], timeout: 4.0)

        // Allow watcher to arm
        try await Task.sleep(nanoseconds: 200_000_000)

        // Produce multiple events rapidly (create, modify, delete)
        let fileA = temp.appendingPathComponent("a.txt")
        let fileB = temp.appendingPathComponent("b.txt")
        try "one".write(to: fileA, atomically: true, encoding: .utf8)
        try "two".write(to: fileB, atomically: true, encoding: .utf8)
        try await Task.sleep(nanoseconds: 20_000_000)
        try "three".write(to: fileA, atomically: true, encoding: .utf8)
        try FileManager.default.removeItem(at: fileB)
        try FileManager.default.createDirectory(at: temp.appendingPathComponent("dir"), withIntermediateDirectories: true)

        // Wait for potential coalesced emission; expect no additional beyond first tick
        try await Task.sleep(nanoseconds: 800_000_000)
        XCTAssertEqual(received, 1, "Rapid events should coalesce into one tick")

        consumer.cancel()
        let currentCount = received
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(received, currentCount, "No events should arrive after cancellation")
    }

    // MARK: - Helpers
    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

