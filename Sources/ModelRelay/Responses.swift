import Foundation

public let defaultBaseURL = URL(string: "https://api.modelrelay.ai/api/v1/")!
public let defaultClientHeader = "modelrelay-swift"
public let apiKeyHeader = "X-ModelRelay-Api-Key"
public let clientHeader = "X-ModelRelay-Client"
public let customerIdHeader = "X-ModelRelay-Customer-Id"
public let requestIdHeader = "X-ModelRelay-Request-Id"

public struct ResponsesRequest: Encodable, Equatable {
    public var provider: String?
    public var model: String?
    public var stateId: String?
    public var input: [InputItem]
    public var outputFormat: OutputFormat?
    public var maxOutputTokens: Int?
    public var temperature: Double?
    public var stop: [String]?
    public var tools: [Tool]?
    public var toolChoice: ToolChoice?

    public init(
        provider: String? = nil,
        model: String? = nil,
        stateId: String? = nil,
        input: [InputItem] = [],
        outputFormat: OutputFormat? = nil,
        maxOutputTokens: Int? = nil,
        temperature: Double? = nil,
        stop: [String]? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil
    ) {
        self.provider = provider
        self.model = model
        self.stateId = stateId
        self.input = input
        self.outputFormat = outputFormat
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
        self.stop = stop
        self.tools = tools
        self.toolChoice = toolChoice
    }

    private enum CodingKeys: String, CodingKey {
        case provider
        case model
        case stateId = "state_id"
        case input
        case outputFormat = "output_format"
        case maxOutputTokens = "max_output_tokens"
        case temperature
        case stop
        case tools
        case toolChoice = "tool_choice"
    }
}

public struct ResponsesBatchItem: Encodable, Equatable {
    public let id: String
    public let request: ResponsesRequest

    public init(id: String, request: ResponsesRequest) {
        self.id = id
        self.request = request
    }

    private enum CodingKeys: String, CodingKey {
        case id
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try request.encode(to: encoder)
    }
}

public struct ResponsesBatchOptions: Encodable, Equatable {
    public let maxConcurrent: Int?
    public let failFast: Bool?
    public let timeoutMs: Int?

    public init(maxConcurrent: Int? = nil, failFast: Bool? = nil, timeoutMs: Int? = nil) {
        self.maxConcurrent = maxConcurrent
        self.failFast = failFast
        self.timeoutMs = timeoutMs
    }

    fileprivate var isEmpty: Bool {
        maxConcurrent == nil && failFast == nil && timeoutMs == nil
    }

    private enum CodingKeys: String, CodingKey {
        case maxConcurrent = "max_concurrent"
        case failFast = "fail_fast"
        case timeoutMs = "timeout_ms"
    }
}

public struct ResponsesBatchRequestOptions: Equatable {
    public var headers: [String: String]
    public var timeout: TimeInterval?
    public var customerId: String?
    public var requestId: String?
    public var retry: RetryConfig?
    public var maxConcurrent: Int?
    public var failFast: Bool?
    public var itemTimeoutMs: Int?

    public init(
        headers: [String: String] = [:],
        timeout: TimeInterval? = nil,
        customerId: String? = nil,
        requestId: String? = nil,
        retry: RetryConfig? = nil,
        maxConcurrent: Int? = nil,
        failFast: Bool? = nil,
        itemTimeoutMs: Int? = nil
    ) {
        self.headers = headers
        self.timeout = timeout
        self.customerId = customerId
        self.requestId = requestId
        self.retry = retry
        self.maxConcurrent = maxConcurrent
        self.failFast = failFast
        self.itemTimeoutMs = itemTimeoutMs
    }

    public func merging(_ override: ResponsesBatchRequestOptions?) -> ResponsesBatchRequestOptions {
        guard let override else { return self }
        var merged = self
        merged.headers.merge(override.headers) { _, new in new }
        if let timeout = override.timeout { merged.timeout = timeout }
        if let customerId = override.customerId { merged.customerId = customerId }
        if let requestId = override.requestId { merged.requestId = requestId }
        if let retry = override.retry { merged.retry = retry }
        if let maxConcurrent = override.maxConcurrent { merged.maxConcurrent = maxConcurrent }
        if let failFast = override.failFast { merged.failFast = failFast }
        if let itemTimeoutMs = override.itemTimeoutMs { merged.itemTimeoutMs = itemTimeoutMs }
        return merged
    }
}

extension ResponsesBatchRequestOptions: Sendable {}

public struct ResponsesRequestOptions: Equatable {
    public var headers: [String: String]
    public var timeout: TimeInterval?
    public var customerId: String?
    public var requestId: String?
    public var retry: RetryConfig?

    public init(headers: [String: String] = [:], timeout: TimeInterval? = nil, customerId: String? = nil, requestId: String? = nil, retry: RetryConfig? = nil) {
        self.headers = headers
        self.timeout = timeout
        self.customerId = customerId
        self.requestId = requestId
        self.retry = retry
    }

    public func merging(_ override: ResponsesRequestOptions?) -> ResponsesRequestOptions {
        guard let override else { return self }
        var merged = self
        merged.headers.merge(override.headers) { _, new in new }
        if let timeout = override.timeout { merged.timeout = timeout }
        if let customerId = override.customerId { merged.customerId = customerId }
        if let requestId = override.requestId { merged.requestId = requestId }
        if let retry = override.retry { merged.retry = retry }
        return merged
    }
}

extension ResponsesRequestOptions: Sendable {}

private struct ResponsesBatchRequest: Encodable {
    let requests: [ResponsesBatchItem]
    let options: ResponsesBatchOptions?
}

public struct ResponsesClient {
    private let http: HTTPClient
    private let auth: AuthClient

    init(http: HTTPClient, auth: AuthClient) {
        self.http = http
        self.auth = auth
    }

    public func builder() -> ResponseBuilder {
        ResponseBuilder()
    }

    public func create(_ request: ResponsesRequest, options: ResponsesRequestOptions? = nil) async throws -> Response {
        if request.input.isEmpty {
            throw ModelRelayError.invalidRequest("responses request input must not be empty")
        }
        let mergedOptions = ResponsesRequestOptions().merging(options)
        var headers = mergedOptions.headers
        if let customerId = mergedOptions.customerId {
            headers[customerIdHeader] = customerId
        }
        if let requestId = mergedOptions.requestId {
            headers[requestIdHeader] = requestId
        }

        let authHeaders = try await auth.authForResponses()
        let response: Response = try await http.json(
            path: "/responses",
            method: "POST",
            body: request,
            headers: headers,
            auth: authHeaders,
            timeout: mergedOptions.timeout,
            retry: mergedOptions.retry
        )
        return response
    }

    public func batch(_ requests: [ResponsesBatchItem], options: ResponsesBatchRequestOptions? = nil) async throws -> ResponsesBatchResponse {
        if requests.isEmpty {
            throw ModelRelayError.invalidRequest("responses batch requests must not be empty")
        }
        let mergedOptions = ResponsesBatchRequestOptions().merging(options)
        var headers = mergedOptions.headers
        if let customerId = mergedOptions.customerId {
            headers[customerIdHeader] = customerId
        }
        if let requestId = mergedOptions.requestId {
            headers[requestIdHeader] = requestId
        }

        var seen = Set<String>()
        var payloadItems: [ResponsesBatchItem] = []
        payloadItems.reserveCapacity(requests.count)
        for item in requests {
            let trimmedId = item.id.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedId.isEmpty {
                throw ModelRelayError.invalidRequest("request id must not be empty")
            }
            if seen.contains(trimmedId) {
                throw ModelRelayError.invalidRequest("request ids must be unique")
            }
            seen.insert(trimmedId)
            if item.request.input.isEmpty {
                throw ModelRelayError.invalidRequest("responses batch item input must not be empty")
            }
            payloadItems.append(ResponsesBatchItem(id: trimmedId, request: item.request))
        }

        let batchOptions = ResponsesBatchOptions(
            maxConcurrent: mergedOptions.maxConcurrent,
            failFast: mergedOptions.failFast,
            timeoutMs: mergedOptions.itemTimeoutMs
        )
        let payload = ResponsesBatchRequest(
            requests: payloadItems,
            options: batchOptions.isEmpty ? nil : batchOptions
        )

        let authHeaders = try await auth.authForResponses()
        let response: ResponsesBatchResponse = try await http.json(
            path: "/responses/batch",
            method: "POST",
            body: payload,
            headers: headers,
            auth: authHeaders,
            timeout: mergedOptions.timeout,
            retry: mergedOptions.retry
        )
        return response
    }

    public func create(_ builder: ResponseBuilder, options: ResponsesRequestOptions? = nil) async throws -> Response {
        let merged = builder.options.merging(options)
        return try await create(builder.request, options: merged)
    }

    public func text(model: String, system: String? = nil, user: String) async throws -> String {
        var builder = ResponseBuilder().model(model).user(user)
        if let system {
            builder = builder.system(system)
        }
        let response = try await create(builder)
        return response.text()
    }

    public func text(_ builder: ResponseBuilder) async throws -> String {
        let response = try await create(builder)
        return response.text()
    }

    public func stream(_ builder: ResponseBuilder, timeouts: StreamTimeouts = StreamTimeouts()) async throws -> ResponsesStream {
        let merged = builder.options
        let authHeaders = try await auth.authForResponses()
        var headers = merged.headers
        if let customerId = merged.customerId {
            headers[customerIdHeader] = customerId
        }
        if let requestId = merged.requestId {
            headers[requestIdHeader] = requestId
        }
        headers["Accept"] = "application/x-ndjson; profile=\"responses-stream/v2\""
        let response = try await http.stream(
            path: "/responses",
            method: "POST",
            body: builder.request,
            headers: headers,
            auth: authHeaders,
            timeout: merged.timeout,
            retry: merged.retry
        )
        return ResponsesStream(response: response, requestId: response.requestId, timeouts: timeouts)
    }

    public func streamTextDeltas(_ builder: ResponseBuilder, timeouts: StreamTimeouts = StreamTimeouts()) async throws -> TextDeltaStream {
        let stream = try await stream(builder, timeouts: timeouts)
        return TextDeltaStream(base: stream)
    }
}
