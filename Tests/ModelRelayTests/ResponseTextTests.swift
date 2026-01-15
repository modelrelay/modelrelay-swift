import XCTest
@testable import ModelRelay

final class ResponseTextTests: XCTestCase {
    func testResponseText_ExtractsAssistantTextOnly() throws {
        let json = """
        {
          "id": "resp_123",
          "output": [
            {"type": "message", "role": "assistant", "content": [{"type": "text", "text": "Hello"}]},
            {"type": "message", "role": "user", "content": [{"type": "text", "text": "Ignore"}]},
            {"type": "message", "role": "assistant", "content": [{"type": "text", "text": " world"}]}
          ],
          "stop_reason": "completed",
          "model": "claude-sonnet-4-5",
          "usage": {"input_tokens": 1, "output_tokens": 2, "total_tokens": 3}
        }
        """
        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(Response.self, from: data)

        XCTAssertEqual(response.text(), "Hello world")
        XCTAssertEqual(response.textChunks(), ["Hello", " world"])
    }
}
