import XCTest
@testable import ModelRelay

final class BillingTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        resetStubs()
    }

    // MARK: - me()

    func testMeReturnsCustomerProfile() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/customers/me")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertTrue(request.value(forHTTPHeaderField: "Authorization")?.contains("Bearer") ?? false)

            let json = """
            {
                "customer": {
                    "customer": {
                        "id": "550e8400-e29b-41d4-a716-446655440000",
                        "project_id": "660e8400-e29b-41d4-a716-446655440000",
                        "external_id": "user_123",
                        "email": "user@example.com"
                    },
                    "subscription": {
                        "tier_code": "pro"
                    },
                    "tier": {
                        "tier_code": "pro",
                        "display_name": "Pro"
                    }
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let profile = try await client.billing.me()

        XCTAssertEqual(profile.customer.email, "user@example.com")
        XCTAssertEqual(profile.customer.externalId, "user_123")
        XCTAssertEqual(profile.subscription?.tierCode, "pro")
        XCTAssertEqual(profile.tier?.displayName, "Pro")
    }

    // MARK: - subscription()

    func testSubscriptionReturnsDetails() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/customers/me/subscription")
            XCTAssertEqual(request.httpMethod, "GET")

            let json = """
            {
                "subscription": {
                    "tier_code": "pro",
                    "tier_display_name": "Pro Plan",
                    "subscription_status": "active",
                    "price_amount_cents": 2900,
                    "price_currency": "usd",
                    "price_interval": "month"
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let subscription = try await client.billing.subscription()

        XCTAssertEqual(subscription.tierCode, "pro")
        XCTAssertEqual(subscription.tierDisplayName, "Pro Plan")
        XCTAssertEqual(subscription.subscriptionStatus, .active)
        XCTAssertEqual(subscription.priceAmountCents, 2900)
        XCTAssertEqual(subscription.priceCurrency, "usd")
        XCTAssertEqual(subscription.priceInterval, .month)
    }

    // MARK: - usage()

    func testUsageReturnsMetrics() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/customers/me/usage")
            XCTAssertEqual(request.httpMethod, "GET")

            let json = """
            {
                "usage": {
                    "window_start": "2025-01-01T00:00:00Z",
                    "window_end": "2025-02-01T00:00:00Z",
                    "requests": 1000,
                    "tokens": 500000,
                    "images": 50,
                    "total_cost_cents": 1500,
                    "daily": [],
                    "spend_limit_cents": 5000,
                    "spend_remaining_cents": 3500,
                    "percentage_used": 30.0,
                    "low": false
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let usage = try await client.billing.usage()

        XCTAssertEqual(usage.requests, 1000)
        XCTAssertEqual(usage.tokens, 500000)
        XCTAssertEqual(usage.images, 50)
        XCTAssertEqual(usage.totalCostCents, 1500)
        XCTAssertEqual(usage.spendLimitCents, 5000)
        XCTAssertEqual(usage.spendRemainingCents, 3500)
        XCTAssertEqual(usage.percentageUsed, 30.0)
        XCTAssertEqual(usage.low, false)
    }

    // MARK: - balance()

    func testBalanceReturnsWalletInfo() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/customers/me/balance")
            XCTAssertEqual(request.httpMethod, "GET")

            let json = """
            {
                "customer_id": "550e8400-e29b-41d4-a716-446655440000",
                "billing_profile_id": "660e8400-e29b-41d4-a716-446655440000",
                "balance_cents": 10000,
                "reserved_cents": 500,
                "currency": "usd"
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let balance = try await client.billing.balance()

        XCTAssertEqual(balance.balanceCents, 10000)
        XCTAssertEqual(balance.reservedCents, 500)
        XCTAssertEqual(balance.currency, "usd")
    }

    // MARK: - balanceHistory()

    func testBalanceHistoryReturnsLedger() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertTrue(request.url?.path.contains("/customers/me/balance/history") ?? false)
            XCTAssertEqual(request.httpMethod, "GET")

            let json = """
            {
                "entries": [
                    {
                        "id": "550e8400-e29b-41d4-a716-446655440000",
                        "direction": "credit",
                        "reason": "topup",
                        "amount_cents": 5000,
                        "description": "Top-up via Stripe",
                        "occurred_at": "2025-01-15T10:30:00Z"
                    }
                ]
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let history = try await client.billing.balanceHistory()

        XCTAssertEqual(history.entries.count, 1)
        XCTAssertEqual(history.entries[0].direction, "credit")
        XCTAssertEqual(history.entries[0].reason, "topup")
        XCTAssertEqual(history.entries[0].amountCents, 5000)
    }

    func testBalanceHistoryWithPagination() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertTrue(request.url?.absoluteString.contains("limit=10") ?? false)
            XCTAssertTrue(request.url?.absoluteString.contains("cursor=abc123") ?? false)

            let json = """
            { "entries": [] }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        _ = try await client.billing.balanceHistory(limit: 10, cursor: "abc123")

        XCTAssertEqual(stubRequests().count, 1)
    }

    // MARK: - topup()

    func testTopupCreatesCheckoutSession() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/customers/me/topup")
            XCTAssertEqual(request.httpMethod, "POST")

            let json = """
            {
                "session_id": "cs_123",
                "checkout_url": "https://checkout.stripe.com/pay/cs_123",
                "gross_amount_cents": 5500,
                "credit_amount_cents": 5000,
                "owner_revenue_cents": 4750,
                "platform_fee_cents": 250,
                "status": "open"
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let request = CustomerTopupRequest(
            creditAmountCents: 5000,
            successUrl: "https://example.com/success",
            cancelUrl: "https://example.com/cancel"
        )
        let topup = try await client.billing.topup(request)

        XCTAssertEqual(topup.sessionId, "cs_123")
        XCTAssertEqual(topup.checkoutUrl, "https://checkout.stripe.com/pay/cs_123")
        XCTAssertEqual(topup.creditAmountCents, 5000)
        XCTAssertEqual(topup.grossAmountCents, 5500)
    }

    // MARK: - changeTier()

    func testChangeTierReturnsUpdatedSubscription() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/customers/me/change-tier")
            XCTAssertEqual(request.httpMethod, "POST")

            let json = """
            {
                "subscription": {
                    "tier_code": "enterprise",
                    "tier_display_name": "Enterprise Plan",
                    "subscription_status": "active"
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let subscription = try await client.billing.changeTier(tierCode: "enterprise")

        XCTAssertEqual(subscription.tierCode, "enterprise")
        XCTAssertEqual(subscription.tierDisplayName, "Enterprise Plan")
    }

    // MARK: - checkout()

    func testCheckoutCreatesSession() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            accessToken: "customer_token",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.url?.path, "/api/v1/customers/me/checkout")
            XCTAssertEqual(request.httpMethod, "POST")

            let json = """
            {
                "session_id": "cs_456",
                "url": "https://checkout.stripe.com/pay/cs_456"
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        let request = CustomerMeCheckoutRequest(
            tierCode: "pro",
            successUrl: "https://example.com/success",
            cancelUrl: "https://example.com/cancel"
        )
        let checkout = try await client.billing.checkout(request)

        XCTAssertEqual(checkout.sessionId, "cs_456")
        XCTAssertEqual(checkout.url, "https://checkout.stripe.com/pay/cs_456")
    }

    // MARK: - Authentication

    func testBillingUsesApiKeyAuth() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1")!,
            apiKey: "mr_sk_test",
            session: session
        ))

        enqueueStub { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-ModelRelay-Api-Key"), "mr_sk_test")

            let json = """
            {
                "customer": {
                    "customer": { "email": "test@example.com" }
                }
            }
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data(json.utf8))
        }

        _ = try await client.billing.me()

        XCTAssertEqual(stubRequests().count, 1)
    }
}
