import XCTest
@testable import ModelRelay

final class StreamingTests: XCTestCase {
    func testNDJSONParsingMapsEvents() throws {
        let start = "{\"type\":\"start\",\"request_id\":\"resp_1\",\"model\":\"claude\"}"
        let delta = "{\"type\":\"update\",\"delta\":\"hi\"}"
        let completion = "{\"type\":\"completion\",\"content\":\"done\",\"usage\":{\"input_tokens\":1,\"output_tokens\":2,\"total_tokens\":3}}"

        let startEvent = try parseNDJSONResponseEvent(line: start, requestId: nil)
        XCTAssertEqual(startEvent?.type, .messageStart)
        XCTAssertEqual(startEvent?.responseId, "resp_1")
        XCTAssertEqual(startEvent?.model, "claude")

        let deltaEvent = try parseNDJSONResponseEvent(line: delta, requestId: nil)
        XCTAssertEqual(deltaEvent?.type, .messageDelta)
        XCTAssertEqual(deltaEvent?.textDelta, "hi")

        let completionEvent = try parseNDJSONResponseEvent(line: completion, requestId: nil)
        XCTAssertEqual(completionEvent?.type, .messageStop)
        XCTAssertEqual(completionEvent?.textDelta, "done")
        XCTAssertEqual(completionEvent?.usage?.totalTokens, 3)
    }

    func testConsumeNDJSONBufferSplitsLines() {
        let input = "{\"type\":\"start\"}\n{\"type\":\"update\"}\n"
        let result = consumeNDJSONBuffer(input, flush: true)
        XCTAssertEqual(result.records.count, 2)
        XCTAssertEqual(result.remainder, "")
    }
}
