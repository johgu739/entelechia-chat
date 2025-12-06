import XCTest
@testable import entelechia_chat

@MainActor
final class CodexBannerVisibilityTests: XCTestCase {
    func testBannerShownWhenConfigurationFallsBack() async throws {
        let appEnvironment = AppEnvironment(
            configurationStatus: .mockFallback(reason: "Testing fallback"),
            assistant: MockCodeAssistant(),
            loader: MockFailingConfigLoader()
        )
        if case .mockFallback = appEnvironment.configurationStatus {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected mock fallback configuration status")
        }
        XCTAssertTrue(RootView.shouldShowCodexBanner(for: appEnvironment.configurationStatus))
        XCTAssertNotNil(RootView.codexBannerReason(for: appEnvironment.configurationStatus))
    }
}
