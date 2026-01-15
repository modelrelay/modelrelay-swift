import XCTest
@testable import ModelRelay

final class ValidationTests: XCTestCase {
    func testStateHandleValidation() async {
        let session = makeStubbedSession()
        let http = HTTPClient(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            clientHeaderValue: "test-client",
            defaultHeaders: [:],
            session: session,
            defaultTimeout: 5
        )
        let auth = AuthClient(http: http, config: AuthConfig(apiKey: "mr_sk_test"))
        let client = StateHandlesClient(http: http, auth: auth)

        do {
            _ = try await client.create(request: StateHandleCreateRequest(ttlSeconds: 0))
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(true)
        }

        do {
            _ = try await client.list(limit: 0)
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(true)
        }

        do {
            try await client.delete(stateId: "   ")
            XCTFail("Expected error")
        } catch {
            XCTAssertTrue(true)
        }
    }
}
