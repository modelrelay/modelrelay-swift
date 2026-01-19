import XCTest
import ModelRelay

final class WrapperV1PublicInitTests: XCTestCase {
    func testWrapperV1ContentRequestInitIsPublic() {
        let request = WrapperV1ContentRequest(id: "file-1", format: "text", maxBytes: 10)
        XCTAssertEqual(request.id, "file-1")
    }

    func testWrapperV1ResponseInitsArePublic() {
        let item = WrapperV1Item(
            id: "item-1",
            title: "Title",
            type: "doc",
            snippet: "Snippet",
            updatedAt: "2020-01-01T00:00:00Z",
            sourceURL: "https://example.com",
            metadata: ["size_bytes": .number(12)]
        )
        let search = WrapperV1SearchResponse(items: [item], nextCursor: "next")
        XCTAssertEqual(search.items.first?.id, "item-1")

        let get = WrapperV1GetResponse(
            id: "item-2",
            title: "Title",
            type: "doc",
            updatedAt: "2020-01-02T00:00:00Z",
            sizeBytes: 34,
            mimeType: "text/plain",
            metadata: ["web_view_link": .string("https://example.com/doc")]
        )
        XCTAssertEqual(get.id, "item-2")

        let content = WrapperV1ContentResponse(id: "item-3", format: "text", content: "Body", truncated: false)
        XCTAssertEqual(content.content, "Body")

        let errorBody = WrapperV1ErrorBody(code: "not_found", message: "missing", retryAfterMs: 1000)
        let error = WrapperV1ErrorResponse(error: errorBody)
        XCTAssertEqual(error.error.code, "not_found")
    }
}
