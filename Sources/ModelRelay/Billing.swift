import Foundation

/// Client for customer billing operations.
///
/// The BillingClient provides access to customer-scoped billing endpoints that require
/// authentication with a customer bearer token (obtained via `customerToken` or OAuth).
///
/// Example usage:
/// ```swift
/// // Using a customer token
/// let client = try ModelRelayClient(ClientConfig(
///     accessToken: customerToken.token
/// ))
///
/// // Get customer profile
/// let profile = try await client.billing.me()
/// print("Customer: \(profile.customer.email ?? "unknown")")
///
/// // Get subscription details
/// let subscription = try await client.billing.subscription()
/// print("Tier: \(subscription.tierCode)")
///
/// // Get usage metrics
/// let usage = try await client.billing.usage()
/// print("Tokens used: \(usage.tokens)")
/// ```
public struct BillingClient {
    private let http: HTTPClient
    private let auth: AuthClient

    init(http: HTTPClient, auth: AuthClient) {
        self.http = http
        self.auth = auth
    }

    /// Get the authenticated customer's profile.
    ///
    /// Returns the customer information along with their subscription and tier when available.
    ///
    /// - Returns: The customer profile with optional subscription and tier.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    public func me() async throws -> CustomerMe {
        let authHeaders = try await auth.authForBilling()
        let response: CustomerMeResponse = try await http.json(
            path: "/customers/me",
            method: "GET",
            body: Optional<String>.none,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
        return response.customer
    }

    /// Get the authenticated customer's subscription details.
    ///
    /// Returns customer-visible subscription details including tier name and pricing.
    /// Does not include developer-private usage cost accounting.
    ///
    /// - Returns: The subscription details.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    public func subscription() async throws -> CustomerMeSubscription {
        let authHeaders = try await auth.authForBilling()
        let response: CustomerMeSubscriptionResponse = try await http.json(
            path: "/customers/me/subscription",
            method: "GET",
            body: Optional<String>.none,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
        return response.subscription
    }

    /// Get the authenticated customer's usage metrics.
    ///
    /// Returns customer-visible usage metrics for the current billing window.
    /// Includes request/token counts and (for paid tiers) remaining subscription credits.
    ///
    /// - Returns: The usage metrics.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    public func usage() async throws -> CustomerMeUsage {
        let authHeaders = try await auth.authForBilling()
        let response: CustomerMeUsageResponse = try await http.json(
            path: "/customers/me/usage",
            method: "GET",
            body: Optional<String>.none,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
        return response.usage
    }

    /// Get the authenticated customer's PAYGO balance.
    ///
    /// Returns the current PAYGO wallet balance and reserved amount.
    ///
    /// - Returns: The balance information.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    public func balance() async throws -> CustomerBalanceResponse {
        let authHeaders = try await auth.authForBilling()
        return try await http.json(
            path: "/customers/me/balance",
            method: "GET",
            body: Optional<String>.none,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }

    /// Get the authenticated customer's PAYGO ledger history.
    ///
    /// Returns the transaction history for the customer's PAYGO wallet.
    ///
    /// - Parameters:
    ///   - limit: Maximum number of entries to return.
    ///   - cursor: Pagination cursor from a previous response.
    /// - Returns: The ledger entries.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    public func balanceHistory(limit: Int? = nil, cursor: String? = nil) async throws -> CustomerLedgerResponse {
        let authHeaders = try await auth.authForBilling()
        var path = "/customers/me/balance/history"
        var queryItems: [String] = []
        if let limit = limit {
            queryItems.append("limit=\(limit)")
        }
        if let cursor = cursor {
            queryItems.append("cursor=\(cursor)")
        }
        if !queryItems.isEmpty {
            path += "?" + queryItems.joined(separator: "&")
        }
        return try await http.json(
            path: path,
            method: "GET",
            body: Optional<String>.none,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }

    /// Create a PAYGO top-up checkout session.
    ///
    /// Creates a Stripe checkout session for the customer to add funds to their PAYGO wallet.
    ///
    /// - Parameter request: The top-up request with amount and redirect URLs.
    /// - Returns: The checkout session details including the redirect URL.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    public func topup(_ request: CustomerTopupRequest) async throws -> CustomerTopupResponse {
        let authHeaders = try await auth.authForBilling()
        return try await http.json(
            path: "/customers/me/topup",
            method: "POST",
            body: request,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }

    /// Change the authenticated customer's subscription tier.
    ///
    /// Allows customers to upgrade or downgrade their subscription tier. Supports:
    /// - Paid-to-paid (with proration)
    /// - Free-to-paid (requires payment method on file)
    /// - Paid-to-free (cancels at period end)
    /// - Free-to-free transitions
    ///
    /// - Parameter tierCode: The tier code to switch to.
    /// - Returns: The updated subscription details.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    public func changeTier(tierCode: String) async throws -> CustomerMeSubscription {
        let authHeaders = try await auth.authForBilling()
        let request = ChangeTierRequest(tierCode: tierCode)
        let response: CustomerMeSubscriptionResponse = try await http.json(
            path: "/customers/me/change-tier",
            method: "POST",
            body: request,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
        return response.subscription
    }

    /// Create a checkout session for the authenticated customer.
    ///
    /// Creates a Stripe checkout session using the customer-first flow.
    /// A Stripe Customer is created with the verified OAuth email before checkout,
    /// preventing email spoofing.
    ///
    /// - Parameter request: The checkout request with tier and redirect URLs.
    /// - Returns: The checkout session details including the redirect URL.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    public func checkout(_ request: CustomerMeCheckoutRequest) async throws -> CheckoutSessionResponse {
        let authHeaders = try await auth.authForBilling()
        return try await http.json(
            path: "/customers/me/checkout",
            method: "POST",
            body: request,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }
}
