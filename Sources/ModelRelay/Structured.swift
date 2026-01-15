import Foundation

public struct StructuredOptions: Equatable {
    public let maxRetries: Int
    public let schemaName: String
    public let retryPrompt: String?
    public let requestOptions: ResponsesRequestOptions?

    public init(maxRetries: Int = 0, schemaName: String = "response", retryPrompt: String? = nil, requestOptions: ResponsesRequestOptions? = nil) {
        self.maxRetries = maxRetries
        self.schemaName = schemaName
        self.retryPrompt = retryPrompt
        self.requestOptions = requestOptions
    }
}

public struct StructuredResult<T: Decodable> {
    public let value: T
    public let attempts: Int
    public let requestId: String?
}

public enum StructuredError: Error, Equatable {
    case decoding(String)
    case retriesExhausted
}

extension ResponsesClient {
    public func object<T: Decodable>(model: String, schema: JSONValue, prompt: String, system: String? = nil, customerId: String? = nil, options: StructuredOptions = StructuredOptions()) async throws -> T {
        let result: StructuredResult<T> = try await objectWithMetadata(model: model, schema: schema, prompt: prompt, system: system, customerId: customerId, options: options)
        return result.value
    }

    public func objectWithMetadata<T: Decodable>(model: String, schema: JSONValue, prompt: String, system: String? = nil, customerId: String? = nil, options: StructuredOptions = StructuredOptions()) async throws -> StructuredResult<T> {
        var builder = ResponseBuilder().model(model)
        if let system {
            builder = builder.system(system)
        }
        builder = builder.user(prompt)
        if let customerId {
            builder = builder.customerId(customerId)
        }
        let format = OutputFormat.jsonSchema(JSONSchemaFormat(name: options.schemaName, schema: schema, strict: true))
        builder = builder.outputFormat(format)
        return try await structured(schema: schema, request: builder.request, options: options)
    }

    public func structured<T: Decodable>(schema: JSONValue, request: ResponsesRequest, options: StructuredOptions = StructuredOptions()) async throws -> StructuredResult<T> {
        let retries = max(0, options.maxRetries)
        var attempts = 0
        var lastError: Error?
        var currentRequest = request
        if currentRequest.outputFormat == nil {
            currentRequest.outputFormat = OutputFormat.jsonSchema(JSONSchemaFormat(name: options.schemaName, schema: schema, strict: true))
        }

        while attempts <= retries {
            attempts += 1
            do {
                let response = try await create(currentRequest, options: options.requestOptions)
                let text = response.text()
                let data = Data(text.utf8)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let value = try decoder.decode(T.self, from: data)
                return StructuredResult(value: value, attempts: attempts, requestId: response.requestId)
            } catch {
                lastError = error
                if attempts > retries { break }
                let retryMessage = options.retryPrompt ?? "Your previous response did not match the expected JSON schema. Return ONLY valid JSON that matches the schema."
                currentRequest.input.append(InputItem(role: .user, content: [.text(retryMessage)]))
            }
        }

        if lastError == nil {
            throw StructuredError.retriesExhausted
        }
        throw lastError ?? StructuredError.retriesExhausted
    }
}
