import Foundation

public enum ResponseEventType: String, Codable {
    case messageStart = "message_start"
    case messageDelta = "message_delta"
    case messageStop = "message_stop"
    case toolUseStart = "tool_use_start"
    case toolUseDelta = "tool_use_delta"
    case toolUseStop = "tool_use_stop"
    case ping
    case custom
}

public struct ResponseEvent: Equatable {
    public let type: ResponseEventType
    public let event: String
    public let data: JSONValue
    public let textDelta: String?
    public let toolCallDelta: ToolCallDelta?
    public let toolCalls: [ToolCall]?
    public let toolResult: ToolResult?
    public let responseId: String?
    public let model: String?
    public let stopReason: StopReason?
    public let usage: Usage?
    public let requestId: String?
    public let raw: String
}

public struct StreamTimeouts: Equatable {
    public let ttft: TimeInterval?
    public let idle: TimeInterval?
    public let total: TimeInterval?

    public init(ttft: TimeInterval? = nil, idle: TimeInterval? = nil, total: TimeInterval? = nil) {
        self.ttft = ttft
        self.idle = idle
        self.total = total
    }
}

public struct ResponsesStream: AsyncSequence {
    public typealias Element = ResponseEvent
    public typealias AsyncIterator = Iterator

    private let response: StreamResponse
    private let requestId: String?
    private let timeouts: StreamTimeouts

    init(response: StreamResponse, requestId: String?, timeouts: StreamTimeouts) {
        self.response = response
        self.requestId = requestId
        self.timeouts = timeouts
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(bytes: response.bytes.makeAsyncIterator(), requestId: requestId, timeouts: timeouts)
    }

    public func collect() async throws -> Response {
        var responseId: String?
        var model: String?
        var stopReason: StopReason?
        var usage: Usage?
        var outputText = ""
        var provider: String?

        for try await event in self {
            responseId = event.responseId ?? responseId
            model = event.model ?? model
            if event.type == .messageDelta, let delta = event.textDelta {
                outputText.append(delta)
            }
            if event.type == .messageStop {
                stopReason = event.stopReason
                usage = event.usage
                if let final = event.textDelta {
                    outputText = final
                }
                if case .object(let obj) = event.data, let providerValue = obj["provider"], case .string(let value) = providerValue {
                    provider = value
                }
            }
        }

        guard let responseId, let model, let usage else {
            throw ModelRelayError.transport("stream ended without required response fields")
        }
        let output: [OutputItem] = [.message(role: .assistant, content: [.text(outputText)], toolCalls: nil)]
        let response = Response(id: responseId, output: output, stopReason: stopReason, model: model, usage: usage, requestId: requestId, provider: provider)
        return response
    }

    public struct Iterator: AsyncIteratorProtocol {
        private var bytes: URLSession.AsyncBytes.AsyncIterator
        private let requestId: String?
        private let timeouts: StreamTimeouts
        private let startTime: Date
        private var lastActivity: Date
        private var sawFirstToken = false
        private var buffer: [UInt8] = []

        init(bytes: URLSession.AsyncBytes.AsyncIterator, requestId: String?, timeouts: StreamTimeouts) {
            self.bytes = bytes
            self.requestId = requestId
            self.timeouts = timeouts
            self.startTime = Date()
            self.lastActivity = Date()
        }

        public mutating func next() async throws -> ResponseEvent? {
            while true {
                if let line = popLine() {
                    let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    if trimmed.isEmpty { continue }
                    if let event = try parseNDJSONResponseEvent(line: trimmed, requestId: requestId) {
                        if !sawFirstToken && countsForTTFT(event) {
                            sawFirstToken = true
                        }
                        try checkTimeouts(start: startTime, lastActivity: lastActivity, sawFirstToken: sawFirstToken, timeouts: timeouts)
                        return event
                    }
                    continue
                }
                guard let byte = try await bytes.next() else {
                    if !buffer.isEmpty {
                        let line = String(decoding: buffer, as: UTF8.self)
                        buffer.removeAll()
                        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                        if trimmed.isEmpty { return nil }
                        if let event = try parseNDJSONResponseEvent(line: trimmed, requestId: requestId) {
                            return event
                        }
                    }
                    return nil
                }
                lastActivity = Date()
                buffer.append(byte)
            }
        }

        private mutating func popLine() -> String? {
            if let newlineIndex = buffer.firstIndex(where: { $0 == 10 || $0 == 13 }) {
                let lineBytes = buffer.prefix(upTo: newlineIndex)
                var removeCount = newlineIndex + 1
                if buffer[newlineIndex] == 13, buffer.count > newlineIndex + 1, buffer[newlineIndex + 1] == 10 {
                    removeCount += 1
                }
                buffer.removeFirst(removeCount)
                return String(decoding: lineBytes, as: UTF8.self)
            }
            return nil
        }
    }
}

public struct TextDeltaStream: AsyncSequence {
    public typealias Element = String
    public typealias AsyncIterator = Iterator

    private let base: ResponsesStream

    init(base: ResponsesStream) {
        self.base = base
    }

    public func makeAsyncIterator() -> Iterator {
        Iterator(base: base.makeAsyncIterator())
    }

    public struct Iterator: AsyncIteratorProtocol {
        var base: ResponsesStream.AsyncIterator

        public mutating func next() async throws -> String? {
            while let event = try await base.next() {
                if event.type == .messageDelta, let delta = event.textDelta {
                    return delta
                }
            }
            return nil
        }
    }
}

func parseNDJSONResponseEvent(line: String, requestId: String?) throws -> ResponseEvent? {
    let data = Data(line.utf8)
    let decoder = JSONDecoder()
    guard let json = try? decoder.decode(JSONValue.self, from: data) else {
        throw ModelRelayError.transport("failed to parse NDJSON line")
    }
    guard case .object(let obj) = json else {
        throw ModelRelayError.transport("NDJSON record is not an object")
    }
    let recordType = obj["type"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    if recordType == "keepalive" { return nil }
    if recordType.isEmpty {
        throw ModelRelayError.transport("NDJSON record missing type")
    }

    let type: ResponseEventType
    switch recordType {
    case "start": type = .messageStart
    case "update": type = .messageDelta
    case "completion": type = .messageStop
    case "tool_use_start": type = .toolUseStart
    case "tool_use_delta": type = .toolUseDelta
    case "tool_use_stop": type = .toolUseStop
    case "ping": type = .ping
    default: type = .custom
    }

    let usage = obj["usage"]?.decode(Usage.self)
    let responseId = obj["request_id"]?.stringValue
    let model = obj["model"]?.stringValue
    let stopReason = obj["stop_reason"]?.stringValue.map { StopReason(rawValue: $0) }

    var textDelta: String?
    if recordType == "update" {
        textDelta = obj["delta"]?.stringValue
    }
    if recordType == "completion" {
        textDelta = obj["content"]?.stringValue
    }

    let toolCallDelta = extractToolCallDelta(obj: obj, type: type)
    let toolCalls = extractToolCalls(obj: obj, type: type)
    let toolResult = extractToolResult(obj: obj, type: type)

    return ResponseEvent(
        type: type,
        event: recordType,
        data: json,
        textDelta: textDelta,
        toolCallDelta: toolCallDelta,
        toolCalls: toolCalls,
        toolResult: toolResult,
        responseId: responseId,
        model: model,
        stopReason: stopReason,
        usage: usage,
        requestId: requestId,
        raw: line
    )
}

private func extractToolCallDelta(obj: [String: JSONValue], type: ResponseEventType) -> ToolCallDelta? {
    if type != .toolUseStart && type != .toolUseDelta { return nil }
    if case .object(let deltaObj)? = obj["tool_call_delta"] {
        let index = deltaObj["index"]?.intValue ?? 0
        let id = deltaObj["id"]?.stringValue
        let typeValue = deltaObj["type"]?.stringValue.flatMap { ToolType(rawValue: $0) }
        let function: FunctionCall?
        if case .object(let fn)? = deltaObj["function"] {
            let name = fn["name"]?.stringValue ?? ""
            let args = fn["arguments"]?.stringValue ?? ""
            function = FunctionCall(name: name, arguments: args)
        } else {
            function = nil
        }
        return ToolCallDelta(index: index, id: id, type: typeValue, function: function)
    }

    let index = obj["index"]?.intValue ?? 0
    let id = obj["id"]?.stringValue
    let typeValue = obj["tool_type"]?.stringValue.flatMap { ToolType(rawValue: $0) }
    if let name = obj["name"]?.stringValue ?? obj["function"]?.stringValue {
        let args = obj["arguments"]?.stringValue ?? ""
        let function = FunctionCall(name: name, arguments: args)
        return ToolCallDelta(index: index, id: id, type: typeValue, function: function)
    }
    return nil
}

private func extractToolCalls(obj: [String: JSONValue], type: ResponseEventType) -> [ToolCall]? {
    if type != .toolUseStop && type != .messageStop { return nil }
    guard case .array(let items)? = obj["tool_calls"] else { return nil }
    var out: [ToolCall] = []
    for item in items {
        if case .object(let toolObj) = item {
            let id = toolObj["id"]?.stringValue ?? ""
            let type = toolObj["type"]?.stringValue.flatMap { ToolType(rawValue: $0) } ?? .function
            let function: FunctionCall?
            if case .object(let fn)? = toolObj["function"] {
                let name = fn["name"]?.stringValue ?? ""
                let args = fn["arguments"]?.stringValue ?? ""
                function = FunctionCall(name: name, arguments: args)
            } else {
                function = nil
            }
            out.append(ToolCall(id: id, type: type, function: function))
        }
    }
    return out.isEmpty ? nil : out
}

private func extractToolResult(obj: [String: JSONValue], type: ResponseEventType) -> ToolResult? {
    if type != .toolUseStop { return nil }
    guard let toolCallId = obj["tool_call_id"]?.stringValue else { return nil }
    guard let output = obj["output"] else { return nil }
    return ToolResult(toolCallId: toolCallId, output: output)
}

func consumeNDJSONBuffer(_ buffer: String, flush: Bool) -> (records: [String], remainder: String) {
    let lines = buffer.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r" })
    var records: [String] = []
    if lines.isEmpty { return ([], buffer) }
    let lastIndex = lines.count - 1
    let limit = flush ? lines.count : max(0, lastIndex)
    for i in 0..<limit {
        let line = String(lines[i]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !line.isEmpty { records.append(line) }
    }
    let remainder = flush ? "" : String(lines[lastIndex])
    return (records, remainder)
}

private func countsForTTFT(_ event: ResponseEvent) -> Bool {
    switch event.type {
    case .messageDelta, .messageStop, .toolUseStart, .toolUseDelta, .toolUseStop:
        return true
    default:
        return false
    }
}

private func checkTimeouts(start: Date, lastActivity: Date, sawFirstToken: Bool, timeouts: StreamTimeouts) throws {
    let now = Date()
    if let total = timeouts.total, now.timeIntervalSince(start) > total {
        throw ModelRelayError.transport("stream total timeout")
    }
    if let idle = timeouts.idle, now.timeIntervalSince(lastActivity) > idle {
        throw ModelRelayError.transport("stream idle timeout")
    }
    if let ttft = timeouts.ttft, !sawFirstToken, now.timeIntervalSince(start) > ttft {
        throw ModelRelayError.transport("stream ttft timeout")
    }
}

private extension JSONValue {
    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }

    func decode<T: Decodable>(_ type: T.Type) -> T? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(self) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }
}
