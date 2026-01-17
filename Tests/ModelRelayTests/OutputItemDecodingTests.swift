import XCTest
@testable import ModelRelay

final class OutputItemDecodingTests: XCTestCase {
    func testOutputItem_DecodesMissingContentAsEmptyArray() throws {
        let json = """
        {
          "id": "resp_123",
          "output": [
            {
              "type": "message",
              "role": "assistant",
              "tool_calls": [
                {
                  "id": "call_1",
                  "type": "function",
                  "function": { "name": "do", "arguments": "{}" }
                }
              ]
            }
          ],
          "stop_reason": "completed",
          "model": "claude-sonnet-4-5",
          "usage": { "input_tokens": 1, "output_tokens": 2, "total_tokens": 3 }
        }
        """
        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(Response.self, from: data)

        guard case .message(let role, let content, let toolCalls) = response.output[0] else {
            XCTFail("Expected message output item")
            return
        }

        XCTAssertEqual(role, .assistant)
        XCTAssertEqual(content, [])
        XCTAssertEqual(toolCalls?.count, 1)
        XCTAssertNil(response.decodingWarnings)
    }

    func testOutputItem_PartialMessageDecodesAsOther() throws {
        let json = """
        {
          "id": "resp_456",
          "output": [
            {
              "type": "message",
              "content": [{ "type": "text", "text": "Missing role" }]
            }
          ],
          "stop_reason": "completed",
          "model": "claude-sonnet-4-5",
          "usage": { "input_tokens": 1, "output_tokens": 2, "total_tokens": 3 }
        }
        """
        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(Response.self, from: data)

        XCTAssertEqual(response.output[0], .other)
        XCTAssertEqual(response.decodingWarnings?.count, 1)
    }
}
