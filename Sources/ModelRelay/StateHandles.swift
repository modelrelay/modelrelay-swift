import Foundation

public struct StateHandleCreateRequest: Encodable, Equatable {
    public let ttlSeconds: Int?

    public init(ttlSeconds: Int? = nil) {
        self.ttlSeconds = ttlSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case ttlSeconds = "ttl_seconds"
    }
}

public struct StateHandleResponse: Decodable, Equatable {
    public let id: String
    public let projectId: String
    public let customerId: String?
    public let createdAt: Date
    public let expiresAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case customerId = "customer_id"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
    }
}

public struct StateHandleListResponse: Decodable, Equatable {
    public let stateHandles: [StateHandleResponse]
    public let nextCursor: String?

    private enum CodingKeys: String, CodingKey {
        case stateHandles = "state_handles"
        case nextCursor = "next_cursor"
    }
}

public struct StateHandlesClient {
    private let http: HTTPClient
    private let auth: AuthClient

    init(http: HTTPClient, auth: AuthClient) {
        self.http = http
        self.auth = auth
    }

    public func create(request: StateHandleCreateRequest = StateHandleCreateRequest()) async throws -> StateHandleResponse {
        if let ttl = request.ttlSeconds {
            if ttl <= 0 {
                throw ModelRelayError.invalidRequest("ttl_seconds must be positive")
            }
            if ttl > 31_536_000 {
                throw ModelRelayError.invalidRequest("ttl_seconds exceeds maximum (1 year)")
            }
        }
        let authHeaders = try await auth.authForResponses()
        return try await http.json(
            path: "/state-handles",
            method: "POST",
            body: request,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }

    public func list(limit: Int? = nil, offset: Int? = nil) async throws -> StateHandleListResponse {
        if let limit, (limit <= 0 || limit > 100) {
            throw ModelRelayError.invalidRequest("limit must be between 1 and 100")
        }
        if let offset, offset < 0 {
            throw ModelRelayError.invalidRequest("offset must be non-negative")
        }
        var query: [String] = []
        if let limit { query.append("limit=\(limit)") }
        if let offset, offset > 0 { query.append("offset=\(offset)") }
        let path = query.isEmpty ? "/state-handles" : "/state-handles?\(query.joined(separator: "&"))"
        let authHeaders = try await auth.authForResponses()
        return try await http.json(
            path: path,
            method: "GET",
            body: nil,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }

    public func delete(stateId: String) async throws {
        let trimmed = stateId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw ModelRelayError.invalidRequest("state_id is required")
        }
        let authHeaders = try await auth.authForResponses()
        try await http.requestVoid(
            path: "/state-handles/\(trimmed)",
            method: "DELETE",
            body: nil,
            headers: [:],
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }
}
