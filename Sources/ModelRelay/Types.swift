import Foundation

public enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}

public enum ContentPart: Codable, Equatable {
    case text(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        default:
            throw ModelRelayError.decoding("Unsupported content part: \(type)")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        }
    }
}

public struct InputItem: Encodable, Equatable {
    public let type: String
    public let role: MessageRole
    public let content: [ContentPart]
    public let toolCalls: [ToolCall]?
    public let toolCallId: String?

    public init(role: MessageRole, content: [ContentPart], toolCalls: [ToolCall]? = nil, toolCallId: String? = nil) {
        self.type = "message"
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case role
        case content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}

public enum OutputItem: Decodable, Equatable {
    case message(role: MessageRole, content: [ContentPart], toolCalls: [ToolCall]?)
    case other

    private enum CodingKeys: String, CodingKey {
        case type
        case role
        case content
        case toolCalls = "tool_calls"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = (try? container.decode(String.self, forKey: .type)) ?? ""
        if type == "message" {
            let role = try container.decode(MessageRole.self, forKey: .role)
            let content = try container.decode([ContentPart].self, forKey: .content)
            let toolCalls = try container.decodeIfPresent([ToolCall].self, forKey: .toolCalls)
            self = .message(role: role, content: content, toolCalls: toolCalls)
        } else {
            self = .other
        }
    }
}

public enum ToolType: String, Codable {
    case function
    case xSearch = "x_search"
    case codeExecution = "code_execution"
}

public struct FunctionTool: Codable, Equatable {
    public let name: String
    public let description: String?
    public let parameters: JSONValue?

    public init(name: String, description: String? = nil, parameters: JSONValue? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

public struct Tool: Codable, Equatable {
    public let type: ToolType
    public let function: FunctionTool?

    public init(function: FunctionTool) {
        self.type = .function
        self.function = function
    }

    public init(type: ToolType, function: FunctionTool? = nil) {
        self.type = type
        self.function = function
    }
}

public enum ToolChoiceType: String, Codable {
    case auto
    case required
    case none
}

public struct ToolChoice: Codable, Equatable {
    public let type: ToolChoiceType
    public let function: String?

    public init(type: ToolChoiceType, function: String? = nil) {
        self.type = type
        self.function = function
    }
}

public struct FunctionCall: Codable, Equatable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

public struct ToolCall: Codable, Equatable {
    public let id: String
    public let type: ToolType
    public let function: FunctionCall?

    public init(id: String, type: ToolType, function: FunctionCall? = nil) {
        self.id = id
        self.type = type
        self.function = function
    }
}

public struct ToolCallDelta: Codable, Equatable {
    public let index: Int
    public let id: String?
    public let type: ToolType?
    public let function: FunctionCall?

    public init(index: Int, id: String?, type: ToolType?, function: FunctionCall?) {
        self.index = index
        self.id = id
        self.type = type
        self.function = function
    }
}

public struct ToolResult: Codable, Equatable {
    public let toolCallId: String
    public let output: JSONValue

    public init(toolCallId: String, output: JSONValue) {
        self.toolCallId = toolCallId
        self.output = output
    }

    private enum CodingKeys: String, CodingKey {
        case toolCallId = "tool_call_id"
        case output
    }
}

public enum OutputFormat: Encodable, Equatable {
    case text
    case jsonSchema(JSONSchemaFormat)

    private enum CodingKeys: String, CodingKey {
        case type
        case jsonSchema = "json_schema"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text:
            try container.encode("text", forKey: .type)
        case .jsonSchema(let schema):
            try container.encode("json_schema", forKey: .type)
            try container.encode(schema, forKey: .jsonSchema)
        }
    }
}

public struct JSONSchemaFormat: Codable, Equatable {
    public let name: String
    public let description: String?
    public let schema: JSONValue
    public let strict: Bool?

    public init(name: String, description: String? = nil, schema: JSONValue, strict: Bool? = nil) {
        self.name = name
        self.description = description
        self.schema = schema
        self.strict = strict
    }
}

public struct Usage: Codable, Equatable {
    public let inputTokens: Int
    public let outputTokens: Int
    public let totalTokens: Int

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }

    public init(inputTokens: Int, outputTokens: Int, totalTokens: Int? = nil) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.totalTokens = totalTokens ?? inputTokens + outputTokens
    }
}

public struct Response: Decodable, Equatable {
    public let id: String
    public let output: [OutputItem]
    public let stopReason: StopReason?
    public let model: String
    public let usage: Usage
    public var requestId: String?
    public let provider: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case output
        case stopReason = "stop_reason"
        case model
        case usage
        case requestId = "request_id"
        case provider
    }

    public func text() -> String {
        return textChunks().joined()
    }

    public func textChunks() -> [String] {
        var chunks: [String] = []
        for item in output {
            switch item {
            case .message(let role, let content, _):
                guard role == .assistant else { continue }
                for part in content {
                    if case .text(let text) = part {
                        chunks.append(text)
                    }
                }
            case .other:
                continue
            }
        }
        return chunks
    }
}

public struct StopReason: RawRepresentable, Codable, Equatable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct RetryConfig: Codable, Equatable {
    public let maxAttempts: Int?
    public let baseBackoffMs: Int?
    public let maxBackoffMs: Int?
    public let retryPost: Bool?

    public init(maxAttempts: Int? = nil, baseBackoffMs: Int? = nil, maxBackoffMs: Int? = nil, retryPost: Bool? = nil) {
        self.maxAttempts = maxAttempts
        self.baseBackoffMs = baseBackoffMs
        self.maxBackoffMs = maxBackoffMs
        self.retryPost = retryPost
    }
}

public struct CustomerTokenRequest: Encodable, Equatable {
    public let customerId: String?
    public let customerExternalId: String?
    public let ttlSeconds: Int?
    public let tierCode: String?

    public init(customerId: String? = nil, customerExternalId: String? = nil, ttlSeconds: Int? = nil, tierCode: String? = nil) {
        self.customerId = customerId
        self.customerExternalId = customerExternalId
        self.ttlSeconds = ttlSeconds
        self.tierCode = tierCode
    }

    private enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case customerExternalId = "customer_external_id"
        case ttlSeconds = "ttl_seconds"
        case tierCode = "tier_code"
    }
}

public struct GetOrCreateCustomerTokenRequest: Encodable, Equatable {
    public let externalId: String
    public let email: String
    public let metadata: JSONValue?
    public let ttlSeconds: Int?
    public let tierCode: String?

    public init(externalId: String, email: String, metadata: JSONValue? = nil, ttlSeconds: Int? = nil, tierCode: String? = nil) {
        self.externalId = externalId
        self.email = email
        self.metadata = metadata
        self.ttlSeconds = ttlSeconds
        self.tierCode = tierCode
    }

    private enum CodingKeys: String, CodingKey {
        case externalId = "external_id"
        case email
        case metadata
        case ttlSeconds = "ttl_seconds"
        case tierCode = "tier_code"
    }
}

public struct CustomerToken: Decodable, Equatable {
    public let token: String
    public let expiresAt: Date
    public let expiresIn: Int
    public let tokenType: String
    public let projectId: String
    public let customerId: String?
    public let billingProfileId: String?
    public let customerExternalId: String
    public let tierCode: String?

    private enum CodingKeys: String, CodingKey {
        case token
        case expiresAt = "expires_at"
        case expiresIn = "expires_in"
        case tokenType = "token_type"
        case projectId = "project_id"
        case customerId = "customer_id"
        case billingProfileId = "billing_profile_id"
        case customerExternalId = "customer_external_id"
        case tierCode = "tier_code"
    }
}
