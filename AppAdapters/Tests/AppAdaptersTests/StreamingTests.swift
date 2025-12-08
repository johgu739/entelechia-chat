import XCTest
@testable import AppAdapters
import CoreEngine

final class StreamingTests: XCTestCase {

    func testSSEParserEmitsEventsWithCommentsAndMultilineData() throws {
        var parser = ServerSentEventParser()
        let payload = """
        :comment to ignore

        data: first line
        data: second line
        event: message

        """
        let events = try parser.feed(Data(payload.utf8))
        XCTAssertEqual(events.count, 1)
        let event = try XCTUnwrap(events.first)
        XCTAssertEqual(event.event, "message")
        XCTAssertEqual(event.dataLines, ["first line", "second line"])
        XCTAssertEqual(event.dataPayload, "first line\nsecond line")
    }

    func testSSEParserDrainsPendingEventWithoutTrailingNewline() throws {
        var parser = ServerSentEventParser()
        let payload = "data: trailing"
        let events = try parser.feed(Data(payload.utf8))
        XCTAssertTrue(events.isEmpty)
        let drained = parser.drainPendingEvent()
        XCTAssertNotNil(drained)
        XCTAssertEqual(drained?.dataPayload, "trailing")
    }

    func testStubCodexClientStreamsTokensThenDone() async throws {
        let client = CodexClientAdapter()
        var received: [StreamChunk<ModelResponse>] = []

        let stream = try await client.stream(messages: [], contextFiles: [])
        for try await chunk in stream {
            received.append(chunk)
        }

        XCTAssertEqual(received.count, 3)
        guard received.count == 3 else { return }
        if case .token(let first) = received[0] {
            XCTAssertEqual(first, "Stub ")
        } else {
            XCTFail("Expected first token")
        }
        if case .token(let second) = received[1] {
            XCTAssertEqual(second, "response")
        } else {
            XCTFail("Expected second token")
        }
        if case .done = received[2] {
            // ok
        } else {
            XCTFail("Expected done")
        }
    }

    func testStubCodexClientCancellationStopsStreaming() async throws {
        let client = CodexClientAdapter()
        let stream = try await client.stream(messages: [], contextFiles: [])
        let task = Task { () -> [StreamChunk<ModelResponse>] in
            var collected: [StreamChunk<ModelResponse>] = []
            for try await chunk in stream {
                collected.append(chunk)
            }
            return collected
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
    }
}

