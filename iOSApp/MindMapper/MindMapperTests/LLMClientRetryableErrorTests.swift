import XCTest
@testable import MindMapper

final class LLMClientRetryableErrorTests: XCTestCase {
    func test_isRetryableHTTPStatus_rateLimitAndQuota() {
        XCTAssertTrue(LLMClient.isRetryableHTTPStatus(429))
        XCTAssertTrue(LLMClient.isRetryableHTTPStatus(402))
        XCTAssertTrue(LLMClient.isRetryableHTTPStatus(403))
        XCTAssertTrue(LLMClient.isRetryableHTTPStatus(404))
        XCTAssertFalse(LLMClient.isRetryableHTTPStatus(400))
        XCTAssertFalse(LLMClient.isRetryableHTTPStatus(500))
    }

    func test_isRetryableProviderPayload_resourceExhausted() {
        let data = Data(#"{"error":{"status":"RESOURCE_EXHAUSTED"}}"#.utf8)
        XCTAssertTrue(LLMClient.isRetryableProviderPayload(data))
    }

    func test_isRetryableProviderPayload_insufficientQuota() {
        let data = Data(#"{"error":{"code":"insufficient_quota"}}"#.utf8)
        XCTAssertTrue(LLMClient.isRetryableProviderPayload(data))
    }

    func test_isRetryableProviderPayload_unrelated() {
        let data = Data(#"{"error":{"message":"invalid argument"}}"#.utf8)
        XCTAssertFalse(LLMClient.isRetryableProviderPayload(data))
    }

    func test_modelTier_geminiDevMapping() {
        XCTAssertEqual(LLMModelTier.nano.primary, "gemini-flash-lite-latest")
        XCTAssertEqual(LLMModelTier.nano.fallback, "gemini-3.5-flash-lite")
        XCTAssertEqual(LLMModelTier.mini.primary, "gemini-flash-latest")
        XCTAssertEqual(LLMModelTier.mini.fallback, "gemini-flash-lite-latest")
        XCTAssertEqual(LLMModelTier.full.primary, "gemini-3.6-flash")
        XCTAssertEqual(LLMModelTier.full.fallback, "gemini-flash-latest")
        XCTAssertEqual(LLMModelTier.embed.primary, "gemini-embedding-001")
        XCTAssertEqual(LLMModelTier.embed.fallback, "gemini-embedding-001")
    }
}
