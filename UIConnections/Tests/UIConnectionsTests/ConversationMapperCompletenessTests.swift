import XCTest
@testable import UIConnections
import CoreEngine

final class ConversationMapperCompletenessTests: XCTestCase {

    func testConversationViewStateMapsAllFields() {
        let conversationID = UUID()
        let message = Message(role: .assistant, text: "hi")
        let context = ContextBuildResult(
            attachments: [],
            truncatedFiles: [],
            excludedFiles: [],
            totalBytes: 0,
            totalTokens: 0,
            budget: .default
        )

        let base = ConversationViewState(
            id: conversationID,
            messages: [message],
            streamingText: "partial",
            lastContext: context
        )

        let streamed = ConversationDeltaMapper.apply(to: base, delta: .assistantStreaming(" more"))
        XCTAssertEqual(streamed.streamingText, " more")
        XCTAssertEqual(streamed.messages.count, 1)
        XCTAssertEqual(streamed.lastContext, context)

        let committed = ConversationDeltaMapper.apply(to: streamed, delta: .assistantCommitted(message))
        XCTAssertEqual(committed.messages.last, message)
        XCTAssertEqual(committed.streamingText, "")
        XCTAssertEqual(committed.lastContext, context)
    }
}

