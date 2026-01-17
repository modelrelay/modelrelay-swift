import Foundation

public struct CustomerTokenProviderConfig {
    public let baseURL: URL
    public let secretKey: String
    public let request: CustomerTokenRequest
    public let clientHeader: String
    public let timeout: TimeInterval
    public let defaultHeaders: [String: String]
    public let session: URLSession
    public let refreshSkewSeconds: TimeInterval

    public init(
        baseURL: URL = defaultBaseURL,
        secretKey: String,
        request: CustomerTokenRequest,
        clientHeader: String = defaultClientHeader,
        timeout: TimeInterval = 60,
        defaultHeaders: [String: String] = [:],
        session: URLSession = .shared,
        refreshSkewSeconds: TimeInterval = 60
    ) {
        self.baseURL = baseURL
        self.secretKey = secretKey
        self.request = request
        self.clientHeader = clientHeader
        self.timeout = timeout
        self.defaultHeaders = defaultHeaders
        self.session = session
        self.refreshSkewSeconds = refreshSkewSeconds
    }
}

public final class CustomerTokenProvider: TokenProvider {
    private let auth: AuthClient
    private let request: CustomerTokenRequest
    private let refreshSkewSeconds: TimeInterval
    private let lock = NSLock()
    private var cached: CustomerToken?

    public init(_ config: CustomerTokenProviderConfig) throws {
        let normalizedBase = normalizeTokenProviderBaseURL(config.baseURL)
        guard normalizedBase.scheme == "https" || normalizedBase.scheme == "http" else {
            throw ModelRelayError.invalidConfiguration("baseURL must start with http:// or https://")
        }
        let trimmedKey = config.secretKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedKey.isEmpty {
            throw ModelRelayError.invalidConfiguration("secretKey is required")
        }
        let http = HTTPClient(
            baseURL: normalizedBase,
            clientHeaderValue: config.clientHeader,
            defaultHeaders: config.defaultHeaders,
            session: config.session,
            defaultTimeout: config.timeout
        )
        self.auth = AuthClient(http: http, config: AuthConfig(apiKey: trimmedKey))
        self.request = config.request
        self.refreshSkewSeconds = config.refreshSkewSeconds
    }

    public func getToken() async throws -> String? {
        if let cached = cachedToken(), isReusable(cached) {
            return cached.token
        }
        let token = try await auth.customerToken(request: request)
        setCachedToken(token)
        return token.token
    }

    private func isReusable(_ token: CustomerToken) -> Bool {
        let trimmed = token.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return token.expiresAt.timeIntervalSinceNow > refreshSkewSeconds
    }

    private func cachedToken() -> CustomerToken? {
        lock.lock()
        defer { lock.unlock() }
        return cached
    }

    private func setCachedToken(_ token: CustomerToken) {
        lock.lock()
        cached = token
        lock.unlock()
    }
}

extension CustomerTokenProvider: @unchecked Sendable {}

private func normalizeTokenProviderBaseURL(_ url: URL) -> URL {
    let trimmed = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return URL(string: trimmed + "/") ?? url
}
