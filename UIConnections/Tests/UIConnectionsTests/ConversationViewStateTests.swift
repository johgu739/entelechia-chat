import XCTest
@testable import UIConnections
import AppCoreEngine

final class ConversationViewStateTests: XCTestCase {

    func testStreamingUpdatesArePure() {
        let convoID = UUID()
        let initial = ConversationViewState(
            id: convoID,
            messages: [],
            streamingText: "",
            lastContext: nil
        )

        let context = ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 0,
            totalTokens: 0,
            budget: .default,
            encodedSegments: []
        )
        let withContext = ConversationDeltaMapper.apply(to: initial, delta: .context(context))
        XCTAssertEqual(withContext.lastContext, context)
        XCTAssertEqual(withContext.messages.count, 0)

        let streaming = ConversationDeltaMapper.apply(to: withContext, delta: .assistantStreaming("hi"))
        XCTAssertEqual(streaming.streamingText, "hi")
        XCTAssertEqual(streaming.messages.count, 0)

        let message = Message(role: .assistant, text: "done")
        let committed = ConversationDeltaMapper.apply(to: streaming, delta: .assistantCommitted(message))
        XCTAssertEqual(committed.messages.count, 1)
        XCTAssertEqual(committed.messages.first?.text, "done")
        XCTAssertEqual(committed.streamingText, "")
    }
}



