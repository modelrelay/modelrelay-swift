import XCTest
@testable import ModelRelay

final class CustomerTokenProviderTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        resetStubs()
    }

    func testCustomerTokenProviderCachesToken() async throws {
        let session = makeStubbedSession()
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(3600))

        enqueueStub(makeAuthStub(json: """
        {"token":"tok_1","expires_at":"\(expiresAt)","expires_in":3600,"token_type":"bearer","project_id":"proj_1","customer_external_id":"cust_1"}
        """))

        let provider = try CustomerTokenProvider(CustomerTokenProviderConfig(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            secretKey: "mr_sk_test",
            request: CustomerTokenRequest(customerExternalId: "cust_1"),
            session: session
        ))

        let token1 = try await provider.getToken()
        let token2 = try await provider.getToken()

        XCTAssertEqual(token1, "tok_1")
        XCTAssertEqual(token2, "tok_1")
        XCTAssertEqual(stubRequests().count, 1)
    }

    func testCustomerTokenProviderRefreshesWhenExpiring() async throws {
        let session = makeStubbedSession()
        let expiresAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(30))

        enqueueStub(makeAuthStub(json: """
        {"token":"tok_1","expires_at":"\(expiresAt)","expires_in":30,"token_type":"bearer","project_id":"proj_1","customer_external_id":"cust_1"}
        """))
        enqueueStub(makeAuthStub(json: """
        {"token":"tok_2","expires_at":"\(expiresAt)","expires_in":30,"token_type":"bearer","project_id":"proj_1","customer_external_id":"cust_1"}
        """))

        let provider = try CustomerTokenProvider(CustomerTokenProviderConfig(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            secretKey: "mr_sk_test",
            request: CustomerTokenRequest(customerExternalId: "cust_1"),
            session: session,
            refreshSkewSeconds: 3600
        ))

        let token1 = try await provider.getToken()
        let token2 = try await provider.getToken()

        XCTAssertEqual(token1, "tok_1")
        XCTAssertEqual(token2, "tok_2")
        XCTAssertEqual(stubRequests().count, 2)
    }
}

private func makeAuthStub(json: String) -> StubState.Handler {
    return { request in
        let requestPath = request.url?.path ?? ""
        guard requestPath.hasSuffix("/auth/customer-token") else {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, Data(json.utf8))
    }
}
