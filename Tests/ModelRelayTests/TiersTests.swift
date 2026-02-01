import XCTest
@testable import ModelRelay

final class TiersTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        resetStubs()
    }

    // MARK: - list()

    func testListReturnsTiers() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            apiKey: "mr_sk_test",
            session: session
        ))

        let projectId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/projects/550E8400-E29B-41D4-A716-446655440000/tiers")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-ModelRelay-Api-Key"), "mr_sk_test")

            let json = """
            {
                "tiers": [
                    {
                        "id": "660e8400-e29b-41d4-a716-446655440000",
                        "project_id": "550e8400-e29b-41d4-a716-446655440000",
                        "tier_code": "free",
                        "display_name": "Free",
                        "billing_mode": "subscription",
                        "spend_limit_cents": 0,
                        "models": []
                    },
                    {
                        "id": "770e8400-e29b-41d4-a716-446655440000",
                        "project_id": "550e8400-e29b-41d4-a716-446655440000",
                        "tier_code": "pro",
                        "display_name": "Pro",
                        "billing_mode": "subscription",
                        "price_amount_cents": 2900,
                        "price_currency": "usd",
                        "price_interval": "month",
                        "spend_limit_cents": 5000,
                        "models": [
                            {
                                "id": "990e8400-e29b-41d4-a716-446655440000",
                                "tier_id": "770e8400-e29b-41d4-a716-446655440000",
                                "model_id": "gpt-5.2",
                                "model_display_name": "GPT-5.2",
                                "description": "OpenAI GPT-5.2 model",
                                "capabilities": ["chat", "function_calling"],
                                "context_window": 128000,
                                "max_output_tokens": 4096,
                                "deprecated": false,
                                "model_input_cost_cents": 250,
                                "model_output_cost_cents": 1000,
                                "is_default": true,
                                "created_at": "2025-01-01T00:00:00Z",
                                "updated_at": "2025-01-01T00:00:00Z"
                            }
                        ]
                    },
                    {
                        "id": "880e8400-e29b-41d4-a716-446655440000",
                        "project_id": "550e8400-e29b-41d4-a716-446655440000",
                        "tier_code": "paygo",
                        "display_name": "Pay As You Go",
                        "billing_mode": "paygo",
                        "models": []
                    }
                ]
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let tiers = try await client.tiers.list(projectId: projectId)

        XCTAssertEqual(tiers.count, 3)

        XCTAssertEqual(tiers[0].tierCode, "free")
        XCTAssertEqual(tiers[0].displayName, "Free")
        XCTAssertEqual(tiers[0].billingMode, .subscription)

        XCTAssertEqual(tiers[1].tierCode, "pro")
        XCTAssertEqual(tiers[1].displayName, "Pro")
        XCTAssertEqual(tiers[1].priceAmountCents, 2900)
        XCTAssertEqual(tiers[1].priceCurrency, "usd")
        XCTAssertEqual(tiers[1].priceInterval, .month)
        XCTAssertEqual(tiers[1].models?.count, 1)
        XCTAssertEqual(tiers[1].models?[0].modelId, "gpt-5.2")
        XCTAssertEqual(tiers[1].models?[0].isDefault, true)

        XCTAssertEqual(tiers[2].tierCode, "paygo")
        XCTAssertEqual(tiers[2].billingMode, .paygo)
    }

    func testListReturnsEmptyArray() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            apiKey: "mr_sk_test",
            session: session
        ))

        let projectId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!

        enqueueStub { _ in
            let json = """
            { "tiers": [] }
            """
            let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let tiers = try await client.tiers.list(projectId: projectId)

        XCTAssertEqual(tiers.count, 0)
    }

    // MARK: - Authentication

    func testListRequiresApiKey() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        let projectId = UUID(uuidString: "550e8400-e29b-41d4-a716-446655440000")!

        enqueueStub { request in
            // Verify bearer token is used (works but may have limited access)
            XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.contains("Bearer") ?? false)

            let json = """
            { "tiers": [] }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        _ = try await client.tiers.list(projectId: projectId)

        XCTAssertEqual(stubRequests().count, 1)
    }
}
