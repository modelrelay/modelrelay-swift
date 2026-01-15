import Foundation

public typealias RunId = String
public typealias PlanHash = String

public struct RunsCreateResponse: Decodable, Equatable {
    public let runId: RunId
    public let planHash: PlanHash
    public let status: String

    private enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case planHash = "plan_hash"
        case status
    }
}

public struct RunsGetResponse: Decodable, Equatable {
    public let runId: RunId
    public let status: String
    public let output: JSONValue?
    public let error: JSONValue?
    public let createdAt: Date?
    public let updatedAt: Date?
    public let planHash: PlanHash?
    public let parentRunId: RunId?

    private enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case status
        case output
        case error
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case planHash = "plan_hash"
        case parentRunId = "parent_run_id"
    }
}

public struct RunsPendingToolsResponse: Decodable, Equatable {
    public let runId: RunId
    public let pendingTools: [JSONValue]

    private enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case pendingTools = "pending_tools"
    }
}

public struct RunsToolResultsResponse: Decodable, Equatable {
    public let runId: RunId
    public let status: String

    private enum CodingKeys: String, CodingKey {
        case runId = "run_id"
        case status
    }
}

public struct RunsCreateOptions: Equatable {
    public var customerId: String?
    public var sessionId: String?
    public var idempotencyKey: String?
    public var input: [String: JSONValue]?
    public var modelOverride: String?
    public var modelOverrides: RunsModelOverrides?
    public var stream: Bool?
    public var headers: [String: String]
    public var timeout: TimeInterval?
    public var retry: RetryConfig?

    public init(
        customerId: String? = nil,
        sessionId: String? = nil,
        idempotencyKey: String? = nil,
        input: [String: JSONValue]? = nil,
        modelOverride: String? = nil,
        modelOverrides: RunsModelOverrides? = nil,
        stream: Bool? = nil,
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        retry: RetryConfig? = nil
    ) {
        self.customerId = customerId
        self.sessionId = sessionId
        self.idempotencyKey = idempotencyKey
        self.input = input
        self.modelOverride = modelOverride
        self.modelOverrides = modelOverrides
        self.stream = stream
        self.headers = headers
        self.timeout = timeout
        self.retry = retry
    }
}

public struct RunsModelOverrides: Encodable, Equatable {
    public let nodes: [String: String]?
    public let fanoutSubnodes: [RunsFanoutSubnodeOverride]?

    public init(nodes: [String: String]? = nil, fanoutSubnodes: [RunsFanoutSubnodeOverride]? = nil) {
        self.nodes = nodes
        self.fanoutSubnodes = fanoutSubnodes
    }

    private enum CodingKeys: String, CodingKey {
        case nodes
        case fanoutSubnodes = "fanout_subnodes"
    }
}

public struct RunsFanoutSubnodeOverride: Encodable, Equatable {
    public let parentId: String
    public let subnodeId: String
    public let model: String

    public init(parentId: String, subnodeId: String, model: String) {
        self.parentId = parentId
        self.subnodeId = subnodeId
        self.model = model
    }

    private enum CodingKeys: String, CodingKey {
        case parentId = "parent_id"
        case subnodeId = "subnode_id"
        case model
    }
}

public struct RunsToolResultsRequest: Encodable, Equatable {
    public let toolResults: [JSONValue]

    public init(toolResults: [JSONValue]) {
        self.toolResults = toolResults
    }

    private enum CodingKeys: String, CodingKey {
        case toolResults = "tool_results"
    }
}

public struct RunsEventsResponse: Decodable, Equatable {
    public let events: [JSONValue]
    public let nextSeq: Int?

    private enum CodingKeys: String, CodingKey {
        case events
        case nextSeq = "next_seq"
    }
}

public struct RunsEventsOptions: Equatable {
    public let customerId: String?
    public let afterSeq: Int?
    public let limit: Int?
    public let wait: Bool?
    public let headers: [String: String]
    public let timeout: TimeInterval?
    public let retry: RetryConfig?

    public init(customerId: String? = nil, afterSeq: Int? = nil, limit: Int? = nil, wait: Bool? = nil, headers: [String: String] = [:], timeout: TimeInterval? = nil, retry: RetryConfig? = nil) {
        self.customerId = customerId
        self.afterSeq = afterSeq
        self.limit = limit
        self.wait = wait
        self.headers = headers
        self.timeout = timeout
        self.retry = retry
    }
}

public struct RunsClient {
    private let http: HTTPClient
    private let auth: AuthClient

    init(http: HTTPClient, auth: AuthClient) {
        self.http = http
        self.auth = auth
    }

    public func create(spec: JSONValue, options: RunsCreateOptions = RunsCreateOptions()) async throws -> RunsCreateResponse {
        let authHeaders = try await auth.authForResponses()
        var headers = options.headers
        if let customerId = options.customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            headers[customerIdHeader] = customerId
        }
        let payload = RunsCreateRequest(
            spec: spec,
            sessionId: options.sessionId,
            idempotencyKey: options.idempotencyKey,
            input: options.input,
            modelOverride: options.modelOverride,
            modelOverrides: options.modelOverrides,
            stream: options.stream
        )
        return try await http.json(
            path: "/runs",
            method: "POST",
            body: payload,
            headers: headers,
            auth: authHeaders,
            timeout: options.timeout,
            retry: options.retry
        )
    }

    public func createFromPlan(planHash: PlanHash, options: RunsCreateOptions = RunsCreateOptions()) async throws -> RunsCreateResponse {
        let authHeaders = try await auth.authForResponses()
        var headers = options.headers
        if let customerId = options.customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            headers[customerIdHeader] = customerId
        }
        let payload = RunsCreateFromPlanRequest(
            planHash: planHash,
            sessionId: options.sessionId,
            idempotencyKey: options.idempotencyKey,
            input: options.input,
            modelOverride: options.modelOverride,
            modelOverrides: options.modelOverrides,
            stream: options.stream
        )
        return try await http.json(
            path: "/runs",
            method: "POST",
            body: payload,
            headers: headers,
            auth: authHeaders,
            timeout: options.timeout,
            retry: options.retry
        )
    }

    public func get(runId: RunId, customerId: String? = nil) async throws -> RunsGetResponse {
        let authHeaders = try await auth.authForResponses()
        var headers: [String: String] = [:]
        if let customerId = customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            headers[customerIdHeader] = customerId
        }
        return try await http.json(
            path: "/runs/\(runId)",
            method: "GET",
            body: nil,
            headers: headers,
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }

    public func pendingTools(runId: RunId, customerId: String? = nil) async throws -> RunsPendingToolsResponse {
        let authHeaders = try await auth.authForResponses()
        var headers: [String: String] = [:]
        if let customerId = customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            headers[customerIdHeader] = customerId
        }
        return try await http.json(
            path: "/runs/\(runId)/pending-tools",
            method: "GET",
            body: nil,
            headers: headers,
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }

    public func submitToolResults(runId: RunId, toolResults: [JSONValue], customerId: String? = nil) async throws -> RunsToolResultsResponse {
        let authHeaders = try await auth.authForResponses()
        var headers: [String: String] = [:]
        if let customerId = customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            headers[customerIdHeader] = customerId
        }
        let payload = RunsToolResultsRequest(toolResults: toolResults)
        return try await http.json(
            path: "/runs/\(runId)/tool-results",
            method: "POST",
            body: payload,
            headers: headers,
            auth: authHeaders,
            timeout: nil,
            retry: nil
        )
    }

    public func events(runId: RunId, options: RunsEventsOptions = RunsEventsOptions()) async throws -> RunsEventsResponse {
        let authHeaders = try await auth.authForResponses()
        var headers = options.headers
        if let customerId = options.customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            headers[customerIdHeader] = customerId
        }
        var query: [String] = []
        if let afterSeq = options.afterSeq { query.append("after_seq=\(afterSeq)") }
        if let limit = options.limit { query.append("limit=\(limit)") }
        if let wait = options.wait { query.append("wait=\(wait ? "true" : "false")") }
        let path = query.isEmpty ? "/runs/\(runId)/events" : "/runs/\(runId)/events?\(query.joined(separator: "&"))"
        return try await http.json(
            path: path,
            method: "GET",
            body: nil,
            headers: headers,
            auth: authHeaders,
            timeout: options.timeout,
            retry: options.retry
        )
    }
}

private struct RunsCreateRequest: Encodable {
    let spec: JSONValue
    let sessionId: String?
    let options: RunsCreateRequestOptions?
    let input: [String: JSONValue]?
    let modelOverride: String?
    let modelOverrides: RunsModelOverrides?
    let stream: Bool?

    init(spec: JSONValue, sessionId: String?, idempotencyKey: String?, input: [String: JSONValue]?, modelOverride: String?, modelOverrides: RunsModelOverrides?, stream: Bool?) {
        self.spec = spec
        self.sessionId = sessionId
        if let key = idempotencyKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            self.options = RunsCreateRequestOptions(idempotencyKey: key)
        } else {
            self.options = nil
        }
        self.input = input
        self.modelOverride = modelOverride
        self.modelOverrides = modelOverrides
        self.stream = stream
    }

    private enum CodingKeys: String, CodingKey {
        case spec
        case sessionId = "session_id"
        case options
        case input
        case modelOverride = "model_override"
        case modelOverrides = "model_overrides"
        case stream
    }
}

private struct RunsCreateFromPlanRequest: Encodable {
    let planHash: PlanHash
    let sessionId: String?
    let options: RunsCreateRequestOptions?
    let input: [String: JSONValue]?
    let modelOverride: String?
    let modelOverrides: RunsModelOverrides?
    let stream: Bool?

    init(planHash: PlanHash, sessionId: String?, idempotencyKey: String?, input: [String: JSONValue]?, modelOverride: String?, modelOverrides: RunsModelOverrides?, stream: Bool?) {
        self.planHash = planHash
        self.sessionId = sessionId
        if let key = idempotencyKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            self.options = RunsCreateRequestOptions(idempotencyKey: key)
        } else {
            self.options = nil
        }
        self.input = input
        self.modelOverride = modelOverride
        self.modelOverrides = modelOverrides
        self.stream = stream
    }

    private enum CodingKeys: String, CodingKey {
        case planHash = "plan_hash"
        case sessionId = "session_id"
        case options
        case input
        case modelOverride = "model_override"
        case modelOverrides = "model_overrides"
        case stream
    }
}

private struct RunsCreateRequestOptions: Encodable {
    let idempotencyKey: String

    private enum CodingKeys: String, CodingKey {
        case idempotencyKey = "idempotency_key"
    }
}
