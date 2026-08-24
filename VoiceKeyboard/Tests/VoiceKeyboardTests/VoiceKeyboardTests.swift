import XCTest
@testable import VoiceKeyboard

final class VoiceKeyboardTests: XCTestCase {
    func testAIServiceUnavailableOnSimulator() async throws {
        // On simulator AIService.isAvailable should be false
        XCTAssertFalse(AIService.isAvailable)
        let service = AIService()
        await XCTAssertThrowsErrorAsync(try await service.summarize("テスト")) { error in
            XCTAssertTrue(error is AIService.AIServiceError)
        }
    }
}

extension XCTestCase {
    // Helper to test async throws
    func XCTAssertThrowsErrorAsync(_ expression: @autoclosure () async throws -> Void, _ message: @escaping (Error) -> Void) async {
        do {
            try await expression()
            XCTFail("Expected to throw error")
        } catch {
            message(error)
        }
    }
}
