import Foundation

public protocol TokenProvider: Sendable {
    func getToken() async throws -> String?
}

public struct AuthConfig {
    public let apiKey: String?
    public let accessToken: String?
    public let tokenProvider: TokenProvider?

    public init(apiKey: String? = nil, accessToken: String? = nil, tokenProvider: TokenProvider? = nil) {
        self.apiKey = apiKey
        self.accessToken = accessToken
        self.tokenProvider = tokenProvider
    }
}

final class AuthClient {
    private let http: HTTPClient
    private let apiKey: String?
    private let accessToken: String?
    private let tokenProvider: TokenProvider?

    init(http: HTTPClient, config: AuthConfig) {
        self.http = http
        self.apiKey = config.apiKey
        self.accessToken = config.accessToken
        self.tokenProvider = config.tokenProvider
    }

    func authForResponses() async throws -> AuthHeaders {
        if let token = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            return AuthHeaders(apiKey: nil, accessToken: token)
        }
        if let provider = tokenProvider {
            let token = try await provider.getToken()?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let token, !token.isEmpty {
                return AuthHeaders(apiKey: nil, accessToken: token)
            }
            throw ModelRelayError.invalidConfiguration("tokenProvider returned an empty token")
        }
        if let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty {
            return AuthHeaders(apiKey: apiKey, accessToken: nil)
        }
        throw ModelRelayError.invalidConfiguration("api key or access token is required")
    }

    func authForBilling() async throws -> AuthHeaders {
        if let token = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            return AuthHeaders(apiKey: nil, accessToken: token)
        }
        if let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !apiKey.isEmpty {
            return AuthHeaders(apiKey: apiKey, accessToken: nil)
        }
        throw ModelRelayError.invalidConfiguration("api key or access token is required")
    }

    func customerToken(request: CustomerTokenRequest) async throws -> CustomerToken {
        let customerId = request.customerId?.trimmingCharacters(in: .whitespacesAndNewlines)
        let externalId = request.customerExternalId?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (customerId?.isEmpty == false) == (externalId?.isEmpty == false) {
            throw ModelRelayError.invalidRequest("Provide exactly one of customerId or customerExternalId")
        }
        if let ttl = request.ttlSeconds, ttl < 0 {
            throw ModelRelayError.invalidRequest("ttlSeconds must be non-negative when provided")
        }
        let auth = try await authForResponses()
        guard auth.apiKey != nil else {
            throw ModelRelayError.invalidConfiguration("Secret API key is required to mint customer tokens")
        }

        return try await http.json(
            path: "/auth/customer-token",
            method: "POST",
            body: request,
            headers: [:],
            auth: auth,
            timeout: nil,
            retry: nil
        )
    }

    func getOrCreateCustomerToken(request: GetOrCreateCustomerTokenRequest) async throws -> CustomerToken {
        let externalId = request.externalId.trimmingCharacters(in: .whitespacesAndNewlines)
        let email = request.email.trimmingCharacters(in: .whitespacesAndNewlines)
        if externalId.isEmpty {
            throw ModelRelayError.invalidRequest("externalId is required")
        }
        if email.isEmpty {
            throw ModelRelayError.invalidRequest("email is required")
        }
        let auth = try await authForResponses()
        guard auth.apiKey != nil else {
            throw ModelRelayError.invalidConfiguration("Secret API key is required to get or create customer tokens")
        }

        let payload = CustomerUpsertRequest(externalId: externalId, email: email, metadata: request.metadata)
        try await http.requestVoid(
            path: "/customers",
            method: "PUT",
            body: payload,
            headers: [:],
            auth: auth,
            timeout: nil,
            retry: nil
        )

        return try await customerToken(request: CustomerTokenRequest(
            customerExternalId: externalId,
            ttlSeconds: request.ttlSeconds,
            tierCode: request.tierCode
        ))
    }
}

private struct CustomerUpsertRequest: Encodable {
    let externalId: String
    let email: String
    let metadata: JSONValue?

    private enum CodingKeys: String, CodingKey {
        case externalId = "external_id"
        case email
        case metadata
    }
}
