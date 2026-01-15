import Foundation

public struct CustomerScopedModelRelayClient {
    public let responses: CustomerResponsesClient

    init(responses: ResponsesClient, customerId: String) {
        self.responses = CustomerResponsesClient(responses: responses, customerId: customerId)
    }
}

public struct CustomerResponsesClient {
    private let responses: ResponsesClient
    private let customerId: String

    init(responses: ResponsesClient, customerId: String) {
        self.responses = responses
        self.customerId = customerId
    }

    private func assertCustomerMatch(_ options: ResponsesRequestOptions?) throws {
        if let provided = options?.customerId, provided != customerId {
            throw ModelRelayError.invalidConfiguration("customerId mismatch")
        }
    }

    public func builder() -> ResponseBuilder {
        ResponseBuilder().customerId(customerId)
    }

    public func create(_ request: ResponsesRequest, options: ResponsesRequestOptions? = nil) async throws -> Response {
        try assertCustomerMatch(options)
        var merged = ResponsesRequestOptions(customerId: customerId).merging(options)
        merged.customerId = customerId
        return try await responses.create(request, options: merged)
    }

    public func create(_ builder: ResponseBuilder, options: ResponsesRequestOptions? = nil) async throws -> Response {
        try assertCustomerMatch(options)
        let merged = builder.options.merging(ResponsesRequestOptions(customerId: customerId).merging(options))
        return try await responses.create(builder.request, options: merged)
    }

    public func text(model: String, system: String? = nil, user: String) async throws -> String {
        var builder = ResponseBuilder().model(model).user(user).customerId(customerId)
        if let system {
            builder = builder.system(system)
        }
        let response = try await responses.create(builder)
        return response.text()
    }

    public func stream(_ builder: ResponseBuilder, timeouts: StreamTimeouts = StreamTimeouts()) async throws -> ResponsesStream {
        try assertCustomerMatch(builder.options)
        let merged = builder.options.merging(ResponsesRequestOptions(customerId: customerId))
        let scoped = ResponseBuilder(request: builder.request, options: merged)
        return try await responses.stream(scoped, timeouts: timeouts)
    }

    public func streamTextDeltas(_ builder: ResponseBuilder, timeouts: StreamTimeouts = StreamTimeouts()) async throws -> TextDeltaStream {
        try assertCustomerMatch(builder.options)
        let merged = builder.options.merging(ResponsesRequestOptions(customerId: customerId))
        let scoped = ResponseBuilder(request: builder.request, options: merged)
        return try await responses.streamTextDeltas(scoped, timeouts: timeouts)
    }
}
