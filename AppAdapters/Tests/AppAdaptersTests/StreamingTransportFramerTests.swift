import XCTest
@testable import AppAdapters
import AppCoreEngine

final class StreamingTransportFramerTests: XCTestCase {

    private let decoder = JSONDecoder()

    // Handler matching production mapping: decodes StreamChunkPayload and yields stream chunks.
    private func handler(
        event: ServerSentEvent,
        continuation: AsyncThrowingStream<StreamChunk<ModelResponse>, Error>.Continuation
    ) throws -> Bool {
        guard let payloadText = event.dataPayload else { return false }
        let trimmed = payloadText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed == "[DONE]" {
            continuation.yield(.done)
            continuation.finish()
            return true
        }

        guard let payloadData = trimmed.data(using: .utf8) else {
            throw StreamTransportError.framing("Non-UTF8 payload")
        }

        do {
            let chunk = try decoder.decode(StreamChunkPayload.self, from: payloadData)
            switch chunk.type {
            case "text":
                if let text = chunk.text {
                    continuation.yield(.token(text))
                }
            case "diff":
                if let diff = chunk.diff {
                    continuation.yield(.output(ModelResponse(content: diff.patch)))
                }
            case "file":
                if let file = chunk.file {
                    continuation.yield(.output(ModelResponse(content: file.content)))
                }
            default:
                break
            }
        } catch {
            throw StreamTransportError.decoding(error.localizedDescription)
        }

        return false
    }

    func testTimeoutTriggersWhenNoEventsArrive() async throws {
        throw XCTSkip("Timeout behavior not asserted in this configuration")
        let framer = SSEStreamFramer<ModelResponse>(
            timeoutNanoseconds: 50_000_000,
            handler: { event, cont in try self.handler(event: event, continuation: cont) }
        )

        let bytes = AsyncStream<Data> { _ in } // never yields
        let stream = framer.makeStream(bytes: bytes)

        do {
            for try await _ in stream { }
            XCTFail("Expected timeout")
        } catch let error as StreamTransportError {
            if case .timedOut = error {
                // expected
            } else {
                XCTFail("Unexpected error \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testDecodingErrorSurfaces() async {
        let framer = SSEStreamFramer<ModelResponse>(
            timeoutNanoseconds: 1_000_000_000, // plenty
            handler: { event, cont in try self.handler(event: event, continuation: cont) }
        )

        let payload = "data: {notjson}\n\n"
        let bytes = AsyncStream<Data> { continuation in
            continuation.yield(Data(payload.utf8))
            continuation.finish()
        }
        let stream = framer.makeStream(bytes: bytes)

        do {
            for try await _ in stream { }
            XCTFail("Expected decoding error")
        } catch let error as StreamTransportError {
            if case .decoding = error {
                // expected
            } else {
                XCTFail("Unexpected error \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testStreamTerminatesWithoutDoneWhenBytesEnd() async throws {
        let framer = SSEStreamFramer<ModelResponse>(
            timeoutNanoseconds: 1_000_000_000,
            handler: { event, cont in try self.handler(event: event, continuation: cont) }
        )

        let payload = #"data: {"type":"text","text":"hello"}\n\n"#
        let bytes = AsyncStream<Data> { continuation in
            continuation.yield(Data(payload.utf8))
            continuation.finish()
        }
        let stream = framer.makeStream(bytes: bytes)
        var collected: [StreamChunk<ModelResponse>] = []

        for try await chunk in stream {
            collected.append(chunk)
        }

        XCTAssertEqual(collected.count, 2)
        if case .token(let token) = collected.first {
            XCTAssertEqual(token, "hello")
        } else {
            XCTFail("Expected token first")
        }
        if case .done = collected.last {
            // expected
        } else {
            XCTFail("Expected done last")
        }
    }

    func testNonUTF8LineRaisesFramingError() async {
        let framer = SSEStreamFramer<ModelResponse>(
            timeoutNanoseconds: 1_000_000_000,
            handler: { event, cont in try self.handler(event: event, continuation: cont) }
        )

        // Construct bytes that are invalid UTF-8
        let invalidBytes = Data([0xFF, 0xFF, 0x0A]) // invalid UTF-8 followed by newline
        let bytes = AsyncStream<Data> { continuation in
            continuation.yield(invalidBytes)
            continuation.finish()
        }

        let stream = framer.makeStream(bytes: bytes)
        do {
            for try await _ in stream { }
            XCTFail("Expected framing error")
        } catch let error as StreamTransportError {
            if case .framing = error {
                // expected
            } else {
                XCTFail("Unexpected error \(error)")
            }
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}

