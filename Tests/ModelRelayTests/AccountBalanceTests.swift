import XCTest
@testable import ModelRelay

final class AccountBalanceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        resetStubs()
    }

    func testAccountBalanceDeserializes() throws {
        let json = """
        {
            "balance_cents": 5000,
            "balance_formatted": "$50.00",
            "currency": "usd",
            "low_balance_threshold_cents": 1000
        }
        """

        let decoder = JSONDecoder()
        let balance = try decoder.decode(AccountBalanceResponse.self, from: Data(json.utf8))

        XCTAssertEqual(balance.balanceCents, 5000)
        XCTAssertEqual(balance.balanceFormatted, "$50.00")
        XCTAssertEqual(balance.currency, "usd")
        XCTAssertEqual(balance.lowBalanceThresholdCents, 1000)
    }

    func testAccountBalanceFetchesWithApiKey() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            apiKey: "mr_sk_test",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/account/balance")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-ModelRelay-Api-Key"), "mr_sk_test")

            let json = """
            {
                "balance_cents": 12345,
                "balance_formatted": "$123.45",
                "currency": "usd",
                "low_balance_threshold_cents": 500
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let balance = try await client.accountBalance()

        XCTAssertEqual(balance.balanceCents, 12345)
        XCTAssertEqual(balance.balanceFormatted, "$123.45")
        XCTAssertEqual(balance.currency, "usd")
        XCTAssertEqual(balance.lowBalanceThresholdCents, 500)
    }

    func testAccountBalanceFetchesWithBearerToken() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "my_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/account/balance")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.contains("Bearer") ?? false)

            let json = """
            {
                "balance_cents": 9999,
                "balance_formatted": "$99.99",
                "currency": "usd",
                "low_balance_threshold_cents": 100
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let balance = try await client.accountBalance()

        XCTAssertEqual(balance.balanceCents, 9999)
        XCTAssertEqual(balance.balanceFormatted, "$99.99")
    }
}
