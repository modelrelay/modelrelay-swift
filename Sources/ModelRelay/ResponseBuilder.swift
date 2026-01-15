import Foundation

public struct ResponseBuilder: Equatable {
    public var request: ResponsesRequest
    public var options: ResponsesRequestOptions

    public init(request: ResponsesRequest = ResponsesRequest(), options: ResponsesRequestOptions = ResponsesRequestOptions()) {
        self.request = request
        self.options = options
    }

    public func provider(_ provider: String) -> ResponseBuilder {
        var copy = self
        copy.request.provider = provider
        return copy
    }

    public func model(_ model: String) -> ResponseBuilder {
        var copy = self
        copy.request.model = model
        return copy
    }

    public func stateId(_ stateId: String) -> ResponseBuilder {
        var copy = self
        copy.request.stateId = stateId
        return copy
    }

    public func input(_ items: [InputItem]) -> ResponseBuilder {
        var copy = self
        copy.request.input = items
        return copy
    }

    public func item(_ item: InputItem) -> ResponseBuilder {
        var copy = self
        copy.request.input.append(item)
        return copy
    }

    public func message(role: MessageRole, content: String, toolCalls: [ToolCall]? = nil, toolCallId: String? = nil) -> ResponseBuilder {
        let item = InputItem(role: role, content: [.text(content)], toolCalls: toolCalls, toolCallId: toolCallId)
        return self.item(item)
    }

    public func system(_ content: String) -> ResponseBuilder {
        message(role: .system, content: content)
    }

    public func user(_ content: String) -> ResponseBuilder {
        message(role: .user, content: content)
    }

    public func assistant(_ content: String) -> ResponseBuilder {
        message(role: .assistant, content: content)
    }

    public func toolResultText(toolCallId: String, content: String) -> ResponseBuilder {
        message(role: .tool, content: content, toolCallId: toolCallId)
    }

    public func outputFormat(_ format: OutputFormat) -> ResponseBuilder {
        var copy = self
        copy.request.outputFormat = format
        return copy
    }

    public func maxOutputTokens(_ max: Int) -> ResponseBuilder {
        var copy = self
        copy.request.maxOutputTokens = max
        return copy
    }

    public func temperature(_ value: Double) -> ResponseBuilder {
        var copy = self
        copy.request.temperature = value
        return copy
    }

    public func stop(_ sequences: [String]) -> ResponseBuilder {
        var copy = self
        copy.request.stop = sequences
        return copy
    }

    public func stop(_ sequences: String...) -> ResponseBuilder {
        stop(sequences)
    }

    public func tools(_ tools: [Tool]) -> ResponseBuilder {
        var copy = self
        copy.request.tools = tools
        return copy
    }

    public func tool(_ tool: Tool) -> ResponseBuilder {
        var copy = self
        if copy.request.tools == nil {
            copy.request.tools = []
        }
        copy.request.tools?.append(tool)
        return copy
    }

    public func toolChoice(_ choice: ToolChoice) -> ResponseBuilder {
        var copy = self
        copy.request.toolChoice = choice
        return copy
    }

    public func toolChoiceAuto() -> ResponseBuilder {
        toolChoice(ToolChoice(type: .auto))
    }

    public func toolChoiceRequired(functionName: String? = nil) -> ResponseBuilder {
        toolChoice(ToolChoice(type: .required, function: functionName))
    }

    public func toolChoiceNone() -> ResponseBuilder {
        toolChoice(ToolChoice(type: .none))
    }

    public func customerId(_ customerId: String) -> ResponseBuilder {
        var copy = self
        copy.options.customerId = customerId
        return copy
    }

    public func requestId(_ requestId: String) -> ResponseBuilder {
        var copy = self
        copy.options.requestId = requestId
        return copy
    }

    public func header(_ key: String, _ value: String) -> ResponseBuilder {
        var copy = self
        copy.options.headers[key] = value
        return copy
    }

    public func headers(_ values: [String: String]) -> ResponseBuilder {
        var copy = self
        for (key, value) in values {
            copy.options.headers[key] = value
        }
        return copy
    }

    public func timeout(_ seconds: TimeInterval) -> ResponseBuilder {
        var copy = self
        copy.options.timeout = seconds
        return copy
    }

    public func retry(_ config: RetryConfig) -> ResponseBuilder {
        var copy = self
        copy.options.retry = config
        return copy
    }

    public func build() -> ResponsesRequest {
        request
    }
}
