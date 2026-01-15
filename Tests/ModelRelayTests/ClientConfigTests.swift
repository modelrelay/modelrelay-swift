import XCTest
@testable import ModelRelay

final class ClientConfigTests: XCTestCase {
    func testClientConfig_RequiresAuth() {
        let cfg = ClientConfig(apiKey: nil, accessToken: nil)
        XCTAssertThrowsError(try ModelRelayClient(cfg)) { error in
            XCTAssertEqual(error as? ModelRelayError, .invalidConfiguration("api key or access token is required"))
        }
    }

    func testClientConfig_AllowsTokenProvider() throws {
        struct Provider: TokenProvider {
            func getToken() async throws -> String? { "token" }
        }
        let cfg = ClientConfig(tokenProvider: Provider())
        _ = try ModelRelayClient(cfg)
    }
}
