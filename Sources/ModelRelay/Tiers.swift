import Foundation

/// Client for tier management operations.
///
/// The TiersClient provides access to project-level tier endpoints.
/// These endpoints require API key authentication (secret key).
///
/// Example usage:
/// ```swift
/// let client = try ModelRelayClient.fromAPIKey("mr_sk_...")
///
/// // List all tiers
/// let tiers = try await client.tiers.list(projectId: myProjectId)
/// for tier in tiers {
///     print("\(tier.tierCode ?? ""): \(tier.displayName ?? "")")
/// }
/// ```
public struct TiersClient {
    private let http: HTTPClient
    private let auth: AuthClient

    init(http: HTTPClient, auth: AuthClient) {
        self.http = http
        self.auth = auth
    }

    /// List all tiers in the project.
    ///
    /// - Parameter projectId: The project ID to list tiers for.
    /// - Returns: Array of tiers configured for the project.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    public func list(projectId: UUID) async throws -> [Tier] {
        let authHeaders = try await auth.authForBilling()
        let response: TierListResponse = try await http.json(
            path: "/projects/\(projectId.uuidString)/tiers",
            method: "GET",
            body: Optional<String>.none,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
        return response.tiers
    }
}
