import Foundation

public enum MessageRole: String, Codable {
    case user
    case assistant
    case system
    case tool
}

public enum ContentPart: Codable, Equatable {
    case text(String)
    case file(FileContent)

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case file
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "file":
            let file = try container.decode(FileContent.self, forKey: .file)
            self = .file(file)
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
        case .file(let file):
            try container.encode("file", forKey: .type)
            try container.encode(file, forKey: .file)
        }
    }
}

public struct FileContent: Codable, Equatable {
    public let dataBase64: String
    public let mimeType: String
    public let filename: String?
    public let sizeBytes: Int64?

    public init(dataBase64: String, mimeType: String, filename: String? = nil, sizeBytes: Int64? = nil) {
        self.dataBase64 = dataBase64
        self.mimeType = mimeType
        self.filename = filename
        self.sizeBytes = sizeBytes
    }

    private enum CodingKeys: String, CodingKey {
        case dataBase64 = "data_base64"
        case mimeType = "mime_type"
        case filename
        case sizeBytes = "size_bytes"
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
            let content = try container.decodeIfPresent([ContentPart].self, forKey: .content) ?? []
            let toolCalls = try container.decodeIfPresent([ToolCall].self, forKey: .toolCalls)
            self = .message(role: role, content: content, toolCalls: toolCalls)
        } else {
            self = .other
        }
    }
}

public enum ToolType: String, Codable, Sendable {
    case function
    case xSearch = "x_search"
    case codeExecution = "code_execution"
}

public struct FunctionTool: Codable, Equatable, Sendable {
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

public struct FunctionCall: Codable, Equatable, Sendable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

public struct ToolCall: Codable, Equatable, Sendable {
    public let id: String
    public let type: ToolType
    public let function: FunctionCall?

    public init(id: String, type: ToolType, function: FunctionCall? = nil) {
        self.id = id
        self.type = type
        self.function = function
    }
}

public struct ToolCallDelta: Codable, Equatable, Sendable {
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

public struct ToolResult: Codable, Equatable, Sendable {
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

public struct Usage: Codable, Equatable, Sendable {
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

public struct ResponsesBatchUsage: Decodable, Equatable {
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalRequests: Int
    public let successfulRequests: Int
    public let failedRequests: Int

    private enum CodingKeys: String, CodingKey {
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalRequests = "total_requests"
        case successfulRequests = "successful_requests"
        case failedRequests = "failed_requests"
    }
}

public struct ResponsesBatchError: Decodable, Equatable {
    public let status: Int
    public let message: String
    public let detail: String?
    public let code: String?
}

public struct ResponsesBatchResult: Decodable, Equatable {
    public let id: String
    public let status: String
    public let response: Response?
    public let error: ResponsesBatchError?
}

public struct ResponsesBatchResponse: Decodable, Equatable {
    public let id: String
    public let results: [ResponsesBatchResult]
    public let usage: ResponsesBatchUsage
}

public struct Response: Decodable, Equatable {
    public let id: String
    public let output: [OutputItem]
    public let stopReason: StopReason?
    public let model: String
    public let usage: Usage
    public var requestId: String?
    public let provider: String?
    public let decodingWarnings: [ResponseDecodingWarning]?

    private enum CodingKeys: String, CodingKey {
        case id
        case output
        case stopReason = "stop_reason"
        case model
        case usage
        case requestId = "request_id"
        case provider
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        stopReason = try container.decodeIfPresent(StopReason.self, forKey: .stopReason)
        model = try container.decode(String.self, forKey: .model)
        usage = try container.decode(Usage.self, forKey: .usage)
        requestId = try container.decodeIfPresent(String.self, forKey: .requestId)
        provider = try container.decodeIfPresent(String.self, forKey: .provider)

        var outputContainer = try container.nestedUnkeyedContainer(forKey: .output)
        var decodedOutput: [OutputItem] = []
        var warnings: [ResponseDecodingWarning] = []
        var index = 0
        while !outputContainer.isAtEnd {
            do {
                let item = try outputContainer.decode(OutputItem.self)
                decodedOutput.append(item)
            } catch {
                warnings.append(
                    ResponseDecodingWarning(
                        index: index,
                        message: "Failed to decode output item: \(error)"
                    )
                )
                if (try? outputContainer.decode(JSONValue.self)) == nil {
                    throw error
                }
                decodedOutput.append(.other)
            }
            index += 1
        }
        output = decodedOutput
        decodingWarnings = warnings.isEmpty ? nil : warnings
    }

    public init(
        id: String,
        output: [OutputItem],
        stopReason: StopReason?,
        model: String,
        usage: Usage,
        requestId: String?,
        provider: String?,
        decodingWarnings: [ResponseDecodingWarning]? = nil
    ) {
        self.id = id
        self.output = output
        self.stopReason = stopReason
        self.model = model
        self.usage = usage
        self.requestId = requestId
        self.provider = provider
        self.decodingWarnings = decodingWarnings
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

public struct ResponseDecodingWarning: Equatable, Sendable {
    public let index: Int
    public let message: String

    public init(index: Int, message: String) {
        self.index = index
        self.message = message
    }
}

public struct StopReason: RawRepresentable, Codable, Equatable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

public struct RetryConfig: Codable, Equatable, Sendable {
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
    /// Tier code for the customer's subscription (required for new customers).
    public let tierCode: String
    public let metadata: JSONValue?
    public let ttlSeconds: Int?

    public init(externalId: String, email: String, tierCode: String, metadata: JSONValue? = nil, ttlSeconds: Int? = nil) {
        self.externalId = externalId
        self.email = email
        self.tierCode = tierCode
        self.metadata = metadata
        self.ttlSeconds = ttlSeconds
    }

    private enum CodingKeys: String, CodingKey {
        case externalId = "external_id"
        case email
        case tierCode = "tier_code"
        case metadata
        case ttlSeconds = "ttl_seconds"
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

public struct AccountBalanceResponse: Decodable, Equatable {
    /// Current account balance in cents.
    public let balanceCents: Int64
    /// Human-readable balance (e.g., "$50.00").
    public let balanceFormatted: String
    /// Currency code (e.g., "usd").
    public let currency: String
    /// Low balance threshold in cents.
    public let lowBalanceThresholdCents: Int64

    private enum CodingKeys: String, CodingKey {
        case balanceCents = "balance_cents"
        case balanceFormatted = "balance_formatted"
        case currency
        case lowBalanceThresholdCents = "low_balance_threshold_cents"
    }
}

// MARK: - Billing Types

/// Billing mode for a tier.
public enum TierBillingMode: String, Codable, Equatable, Sendable {
    case subscription
    case paygo
}

/// Billing provider backing the subscription or tier.
public enum BillingProvider: String, Codable, Equatable, Sendable {
    case stripe
    case crypto
    case appStore = "app_store"
    case external
}

/// Billing interval for a tier.
public enum PriceInterval: String, Codable, Equatable, Sendable {
    case month
    case year
}

/// Subscription status kind.
public enum SubscriptionStatusKind: String, Codable, Equatable, Sendable {
    case active
    case trialing
    case pastDue = "past_due"
    case canceled
    case unpaid
    case incomplete
    case incompleteExpired = "incomplete_expired"
    case paused
}

/// Customer information.
public struct Customer: Codable, Equatable {
    public let id: UUID?
    public let projectId: UUID?
    public let externalId: String?
    public let email: String?
    public let metadata: JSONValue?
    public let createdAt: Date?
    public let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case externalId = "external_id"
        case email
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Subscription information.
public struct Subscription: Codable, Equatable {
    public let id: UUID?
    public let customerId: UUID?
    public let projectId: UUID?
    public let tierId: UUID?
    public let tierCode: String?
    public let billingProvider: BillingProvider?
    public let billingSubscriptionId: String?
    public let subscriptionStatus: SubscriptionStatusKind?
    public let currentPeriodStart: Date?
    public let currentPeriodEnd: Date?
    public let createdAt: Date?
    public let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case customerId = "customer_id"
        case projectId = "project_id"
        case tierId = "tier_id"
        case tierCode = "tier_code"
        case billingProvider = "billing_provider"
        case billingSubscriptionId = "billing_subscription_id"
        case subscriptionStatus = "subscription_status"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Model configuration for a tier.
public struct TierModel: Codable, Equatable {
    public let id: UUID
    public let tierId: UUID
    public let modelId: String
    public let modelDisplayName: String
    public let description: String
    public let capabilities: [String]
    public let contextWindow: Int32
    public let maxOutputTokens: Int32
    public let deprecated: Bool
    public let modelInputCostCents: Int64
    public let modelOutputCostCents: Int64
    public let isDefault: Bool
    public let createdAt: Date
    public let updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case tierId = "tier_id"
        case modelId = "model_id"
        case modelDisplayName = "model_display_name"
        case description
        case capabilities
        case contextWindow = "context_window"
        case maxOutputTokens = "max_output_tokens"
        case deprecated
        case modelInputCostCents = "model_input_cost_cents"
        case modelOutputCostCents = "model_output_cost_cents"
        case isDefault = "is_default"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Tier configuration.
public struct Tier: Codable, Equatable {
    public let id: UUID?
    public let projectId: UUID?
    public let tierCode: String?
    public let displayName: String?
    public let billingMode: TierBillingMode?
    public let billingProvider: BillingProvider?
    public let billingPriceRef: String?
    public let spendLimitCents: UInt64?
    public let priceAmountCents: UInt64?
    public let priceCurrency: String?
    public let priceInterval: PriceInterval?
    public let trialDays: UInt32?
    public let promoCreditsCents: UInt64?
    public let models: [TierModel]?
    public let createdAt: Date?
    public let updatedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case id
        case projectId = "project_id"
        case tierCode = "tier_code"
        case displayName = "display_name"
        case billingMode = "billing_mode"
        case billingProvider = "billing_provider"
        case billingPriceRef = "billing_price_ref"
        case spendLimitCents = "spend_limit_cents"
        case priceAmountCents = "price_amount_cents"
        case priceCurrency = "price_currency"
        case priceInterval = "price_interval"
        case trialDays = "trial_days"
        case promoCreditsCents = "promo_credits_cents"
        case models
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// Customer profile with optional subscription and tier.
public struct CustomerMe: Codable, Equatable {
    public let customer: Customer
    public let subscription: Subscription?
    public let tier: Tier?
}

/// Response wrapper for CustomerMe.
public struct CustomerMeResponse: Decodable, Equatable {
    public let customer: CustomerMe
}

/// Customer-visible subscription details.
public struct CustomerMeSubscription: Codable, Equatable {
    public let tierCode: String
    public let tierDisplayName: String
    public let subscriptionStatus: SubscriptionStatusKind?
    public let priceAmountCents: Int64?
    public let priceCurrency: String?
    public let priceInterval: PriceInterval?
    public let currentPeriodStart: Date?
    public let currentPeriodEnd: Date?

    private enum CodingKeys: String, CodingKey {
        case tierCode = "tier_code"
        case tierDisplayName = "tier_display_name"
        case subscriptionStatus = "subscription_status"
        case priceAmountCents = "price_amount_cents"
        case priceCurrency = "price_currency"
        case priceInterval = "price_interval"
        case currentPeriodStart = "current_period_start"
        case currentPeriodEnd = "current_period_end"
    }
}

/// Response wrapper for CustomerMeSubscription.
public struct CustomerMeSubscriptionResponse: Decodable, Equatable {
    public let subscription: CustomerMeSubscription
}

/// Daily usage data point.
public struct CustomerUsagePoint: Codable, Equatable {
    public let day: Date
    public let requests: Int64
    public let tokens: Int64
    public let images: Int64?
}

/// Customer-visible usage metrics.
public struct CustomerMeUsage: Codable, Equatable {
    public let windowStart: Date
    public let windowEnd: Date
    public let requests: Int64
    public let tokens: Int64
    public let images: Int64
    public let totalCostCents: Int64
    public let daily: [CustomerUsagePoint]
    public let spendLimitCents: Int64?
    public let spendRemainingCents: Int64?
    public let percentageUsed: Float?
    public let low: Bool?
    public let overageEnabled: Bool?
    public let walletBalanceCents: Int64?
    public let walletReservedCents: Int64?

    private enum CodingKeys: String, CodingKey {
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case requests
        case tokens
        case images
        case totalCostCents = "total_cost_cents"
        case daily
        case spendLimitCents = "spend_limit_cents"
        case spendRemainingCents = "spend_remaining_cents"
        case percentageUsed = "percentage_used"
        case low
        case overageEnabled = "overage_enabled"
        case walletBalanceCents = "wallet_balance_cents"
        case walletReservedCents = "wallet_reserved_cents"
    }
}

/// Response wrapper for CustomerMeUsage.
public struct CustomerMeUsageResponse: Decodable, Equatable {
    public let usage: CustomerMeUsage
}

/// Customer PAYGO balance (customer-scoped endpoint).
public struct CustomerBalanceResponse: Decodable, Equatable {
    public let customerId: UUID
    public let billingProfileId: UUID
    public let balanceCents: Int64
    public let reservedCents: Int64
    public let currency: String

    private enum CodingKeys: String, CodingKey {
        case customerId = "customer_id"
        case billingProfileId = "billing_profile_id"
        case balanceCents = "balance_cents"
        case reservedCents = "reserved_cents"
        case currency
    }
}

/// Ledger entry for PAYGO balance history.
public struct CustomerLedgerEntry: Codable, Equatable {
    public let id: UUID
    public let direction: String
    public let reason: String
    public let amountCents: Int64
    public let description: String
    public let occurredAt: Date
    public let balanceAfterCents: Int64?
    public let grossAmountCents: Int64?
    public let creditAmountCents: Int64?
    public let ownerRevenueCents: Int64?
    public let platformFeeCents: Int64?
    public let inputTokens: Int64?
    public let outputTokens: Int64?
    public let modelId: String?
    public let requestId: UUID?
    public let stripeCheckoutSessionId: String?
    public let stripeInvoiceId: String?
    public let stripePaymentIntentId: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case direction
        case reason
        case amountCents = "amount_cents"
        case description
        case occurredAt = "occurred_at"
        case balanceAfterCents = "balance_after_cents"
        case grossAmountCents = "gross_amount_cents"
        case creditAmountCents = "credit_amount_cents"
        case ownerRevenueCents = "owner_revenue_cents"
        case platformFeeCents = "platform_fee_cents"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case modelId = "model_id"
        case requestId = "request_id"
        case stripeCheckoutSessionId = "stripe_checkout_session_id"
        case stripeInvoiceId = "stripe_invoice_id"
        case stripePaymentIntentId = "stripe_payment_intent_id"
    }
}

/// Response wrapper for ledger history.
public struct CustomerLedgerResponse: Decodable, Equatable {
    public let entries: [CustomerLedgerEntry]
}

/// Request to create a PAYGO top-up checkout session.
public struct CustomerTopupRequest: Encodable, Equatable {
    public let creditAmountCents: Int64
    public let successUrl: String
    public let cancelUrl: String

    public init(creditAmountCents: Int64, successUrl: String, cancelUrl: String) {
        self.creditAmountCents = creditAmountCents
        self.successUrl = successUrl
        self.cancelUrl = cancelUrl
    }

    private enum CodingKeys: String, CodingKey {
        case creditAmountCents = "credit_amount_cents"
        case successUrl = "success_url"
        case cancelUrl = "cancel_url"
    }
}

/// Response from creating a PAYGO top-up checkout session.
public struct CustomerTopupResponse: Decodable, Equatable {
    public let sessionId: String
    public let checkoutUrl: String
    public let grossAmountCents: Int64
    public let creditAmountCents: Int64
    public let ownerRevenueCents: Int64
    public let platformFeeCents: Int64
    public let status: String

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case checkoutUrl = "checkout_url"
        case grossAmountCents = "gross_amount_cents"
        case creditAmountCents = "credit_amount_cents"
        case ownerRevenueCents = "owner_revenue_cents"
        case platformFeeCents = "platform_fee_cents"
        case status
    }
}

/// Request to change subscription tier.
public struct ChangeTierRequest: Encodable, Equatable {
    public let tierCode: String

    public init(tierCode: String) {
        self.tierCode = tierCode
    }

    private enum CodingKeys: String, CodingKey {
        case tierCode = "tier_code"
    }
}

/// Request to create a checkout session.
public struct CustomerMeCheckoutRequest: Encodable, Equatable {
    public let tierCode: String
    public let successUrl: String
    public let cancelUrl: String

    public init(tierCode: String, successUrl: String, cancelUrl: String) {
        self.tierCode = tierCode
        self.successUrl = successUrl
        self.cancelUrl = cancelUrl
    }

    private enum CodingKeys: String, CodingKey {
        case tierCode = "tier_code"
        case successUrl = "success_url"
        case cancelUrl = "cancel_url"
    }
}

/// Response from creating a checkout session.
public struct CheckoutSessionResponse: Decodable, Equatable {
    public let sessionId: String
    public let url: String

    private enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case url
    }
}

/// Response wrapper for tier list.
public struct TierListResponse: Decodable, Equatable {
    public let tiers: [Tier]
}

/// Response wrapper for single tier.
public struct TierResponse: Decodable, Equatable {
    public let tier: Tier
}
