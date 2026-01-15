import XCTest
@testable import ModelRelay

final class ResponseBuilderTests: XCTestCase {
    func testResponseBuilder_BuildsRequestWithModelAndInput() {
        let builder = ResponseBuilder()
            .model("claude-sonnet-4-5")
            .system("System")
            .user("Hello")

        XCTAssertEqual(builder.request.model, "claude-sonnet-4-5")
        XCTAssertEqual(builder.request.input.count, 2)

        let first = builder.request.input[0]
        XCTAssertEqual(first.role, .system)
        XCTAssertEqual(first.content.count, 1)

        let second = builder.request.input[1]
        XCTAssertEqual(second.role, .user)
        XCTAssertEqual(second.content.count, 1)
        if case .text(let text) = second.content[0] {
            XCTAssertEqual(text, "Hello")
        } else {
            XCTFail("Expected text content")
        }
    }
}
