import Foundation

public struct ClientConfig {
    public var baseURL: URL
    public var apiKey: String?
    public var accessToken: String?
    public var tokenProvider: TokenProvider?
    public var clientHeader: String
    public var timeout: TimeInterval
    public var defaultHeaders: [String: String]
    public var session: URLSession

    public init(
        baseURL: URL = defaultBaseURL,
        apiKey: String? = nil,
        accessToken: String? = nil,
        tokenProvider: TokenProvider? = nil,
        clientHeader: String = defaultClientHeader,
        timeout: TimeInterval = 60,
        defaultHeaders: [String: String] = [:],
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.accessToken = accessToken
        self.tokenProvider = tokenProvider
        self.clientHeader = clientHeader
        self.timeout = timeout
        self.defaultHeaders = defaultHeaders
        self.session = session
    }
}

public struct ChatOptions: Equatable {
    public let system: String?

    public init(system: String? = nil) {
        self.system = system
    }
}

public struct ModelRelayClient {
    private let http: HTTPClient
    private let auth: AuthClient

    public let responses: ResponsesClient
    public let runs: RunsClient
    public let workflows: WorkflowsClient
    public let stateHandles: StateHandlesClient
    public let sql: SQLClient
    public let billing: BillingClient
    public let tiers: TiersClient

    public init(_ config: ClientConfig) throws {
        let normalizedBase = normalizeBaseURL(config.baseURL)
        guard normalizedBase.scheme == "https" || normalizedBase.scheme == "http" else {
            throw ModelRelayError.invalidConfiguration("baseURL must start with http:// or https://")
        }
        let apiKey = config.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let accessToken = config.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (apiKey?.isEmpty ?? true) && (accessToken?.isEmpty ?? true) && config.tokenProvider == nil {
            throw ModelRelayError.invalidConfiguration("api key or access token is required")
        }
        self.http = HTTPClient(
            baseURL: normalizedBase,
            clientHeaderValue: config.clientHeader,
            defaultHeaders: config.defaultHeaders,
            session: config.session,
            defaultTimeout: config.timeout
        )
        self.auth = AuthClient(http: http, config: AuthConfig(apiKey: apiKey, accessToken: accessToken, tokenProvider: config.tokenProvider))
        self.responses = ResponsesClient(http: http, auth: auth)
        self.runs = RunsClient(http: http, auth: auth)
        self.workflows = WorkflowsClient(http: http, auth: auth)
        self.stateHandles = StateHandlesClient(http: http, auth: auth)
        self.sql = SQLClient(http: http, auth: auth)
        self.billing = BillingClient(http: http, auth: auth)
        self.tiers = TiersClient(http: http, auth: auth)
    }

    public static func fromAPIKey(_ apiKey: String, baseURL: URL = defaultBaseURL) throws -> ModelRelayClient {
        try ModelRelayClient(ClientConfig(baseURL: baseURL, apiKey: apiKey))
    }

    public static func fromAccessToken(_ accessToken: String, baseURL: URL = defaultBaseURL) throws -> ModelRelayClient {
        try ModelRelayClient(ClientConfig(baseURL: baseURL, accessToken: accessToken))
    }

    public static func fromTokenProvider(_ tokenProvider: TokenProvider, baseURL: URL = defaultBaseURL) throws -> ModelRelayClient {
        try ModelRelayClient(ClientConfig(baseURL: baseURL, tokenProvider: tokenProvider))
    }

    public func forCustomer(_ customerId: String) throws -> CustomerScopedModelRelayClient {
        let trimmed = customerId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw ModelRelayError.invalidConfiguration("customerId must be non-empty")
        }
        return CustomerScopedModelRelayClient(responses: responses, customerId: trimmed)
    }

    public func ask(model: String, prompt: String) async throws -> String {
        try await responses.text(model: model, user: prompt)
    }

    public func chat(model: String, prompt: String, options: ChatOptions? = nil) async throws -> Response {
        var builder = responses.builder().model(model).user(prompt)
        if let system = options?.system {
            builder = builder.system(system)
        }
        return try await responses.create(builder)
    }

    public func customerToken(request: CustomerTokenRequest) async throws -> CustomerToken {
        try await auth.customerToken(request: request)
    }

    public func getOrCreateCustomerToken(request: GetOrCreateCustomerTokenRequest) async throws -> CustomerToken {
        try await auth.getOrCreateCustomerToken(request: request)
    }

    /// Returns the authenticated account's PAYGO balance.
    ///
    /// This method accepts both API key (`X-ModelRelay-Api-Key`) and bearer token
    /// authentication, enabling programmatic balance checks from backend services.
    ///
    /// - Returns: The account balance information.
    /// - Throws: `ModelRelayError` if authentication fails or the request fails.
    ///
    /// ```swift
    /// let client = try ModelRelayClient.fromAPIKey("mr_sk_...")
    /// let balance = try await client.accountBalance()
    /// print("Balance: \(balance.balanceCents) cents")
    /// print("Formatted: \(balance.balanceFormatted)")
    /// ```
    public func accountBalance() async throws -> AccountBalanceResponse {
        let authHeaders = try await auth.authForBilling()
        return try await http.json(
            path: "/account/balance",
            method: "GET",
            body: Optional<String>.none,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }
}

private func normalizeBaseURL(_ url: URL) -> URL {
    let trimmed = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return URL(string: trimmed + "/") ?? url
}
