import XCTest
@testable import ModelRelay

final class WrapperV1Tests: XCTestCase {
    func testValidateSearchResponseRequiresIDs() {
        let item = WrapperV1Item(id: "", title: nil, type: nil, snippet: nil, updatedAt: nil, sourceURL: nil, metadata: nil)
        let response = WrapperV1SearchResponse(items: [item], nextCursor: nil)
        XCTAssertThrowsError(try WrapperV1Validator.validate(response))
    }

    func testValidateGetResponseRequiresID() {
        let response = WrapperV1GetResponse(id: "", title: nil, type: nil, updatedAt: nil, sizeBytes: nil, mimeType: nil, metadata: nil)
        XCTAssertThrowsError(try WrapperV1Validator.validate(response))
    }

    func testValidateErrorResponseRequiresFields() {
        let response = WrapperV1ErrorResponse(error: WrapperV1ErrorBody(code: "", message: "", retryAfterMs: nil))
        XCTAssertThrowsError(try WrapperV1Validator.validate(response))
    }
}
