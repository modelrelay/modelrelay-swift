import Foundation

public struct SQLValidateOverrides: Encodable, Equatable {
    public let limit: Int64?
    public let timeoutMs: Int64?

    public init(limit: Int64? = nil, timeoutMs: Int64? = nil) {
        self.limit = limit
        self.timeoutMs = timeoutMs
    }

    private enum CodingKeys: String, CodingKey {
        case limit
        case timeoutMs = "timeout_ms"
    }
}

public struct SQLValidateRequest: Encodable, Equatable {
    public let sql: String
    public let profileId: String?
    public let policy: JSONValue?
    public let overrides: SQLValidateOverrides?

    public init(sql: String, profileId: String? = nil, policy: JSONValue? = nil, overrides: SQLValidateOverrides? = nil) {
        self.sql = sql
        self.profileId = profileId
        self.policy = policy
        self.overrides = overrides
    }

    private enum CodingKeys: String, CodingKey {
        case sql
        case profileId = "profile_id"
        case policy
        case overrides
    }
}

public struct SQLValidateResponse: Decodable, Equatable, Sendable {
    public let valid: Bool
    public let normalizedSQL: String
    public let tables: [String]?
    public let limit: Int?
    public let timeoutMs: Int?
    public let orderBy: [String]?
    public let readOnly: Bool

    private enum CodingKeys: String, CodingKey {
        case valid
        case normalizedSQL = "normalized_sql"
        case tables
        case limit
        case timeoutMs = "timeout_ms"
        case orderBy = "order_by"
        case readOnly = "read_only"
    }
}

public struct SQLClient {
    private let http: HTTPClient
    private let auth: AuthClient

    init(http: HTTPClient, auth: AuthClient) {
        self.http = http
        self.auth = auth
    }

    public func validate(_ request: SQLValidateRequest) async throws -> SQLValidateResponse {
        let trimmed = request.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw ModelRelayError.invalidConfiguration("sql is required")
        }
        let headers = [String: String]()
        let authHeaders = try await auth.authForResponses()
        return try await http.json(
            path: "/sql/validate",
            method: "POST",
            body: request,
            headers: headers,
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }
}
