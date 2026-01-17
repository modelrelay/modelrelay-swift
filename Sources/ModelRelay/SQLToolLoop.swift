import Foundation

public typealias SQLRow = [String: JSONValue]

public struct SQLRowView: Equatable, Sendable {
    public let columns: [String]
    public let values: [JSONValue]
    public let raw: SQLRow

    public init(columns: [String], row: SQLRow) {
        self.columns = columns
        self.raw = row
        self.values = columns.map { row[$0] ?? .null }
    }

    public subscript(_ column: String) -> JSONValue? {
        raw[column]
    }

    public func string(_ column: String) -> String? {
        guard case .string(let value)? = raw[column] else { return nil }
        return value
    }

    public func int(_ column: String) -> Int? {
        guard case .number(let value)? = raw[column] else { return nil }
        return Int(value)
    }

    public func double(_ column: String) -> Double? {
        guard case .number(let value)? = raw[column] else { return nil }
        return value
    }

    public func bool(_ column: String) -> Bool? {
        guard case .bool(let value)? = raw[column] else { return nil }
        return value
    }
}

public struct SQLTableInfo: Codable, Equatable, Sendable {
    public let name: String
    public let schema: String?

    public init(name: String, schema: String? = nil) {
        self.name = name
        self.schema = schema
    }
}

public struct SQLColumnInfo: Codable, Equatable, Sendable {
    public let name: String
    public let type: String
    public let nullable: Bool?

    public init(name: String, type: String, nullable: Bool? = nil) {
        self.name = name
        self.type = type
        self.nullable = nullable
    }
}

public struct SQLTableDescription: Codable, Equatable, Sendable {
    public let table: String
    public let columns: [SQLColumnInfo]

    public init(table: String, columns: [SQLColumnInfo]) {
        self.table = table
        self.columns = columns
    }
}

public struct SQLExecuteResult: Codable, Equatable, Sendable {
    public let columns: [String]
    public let rows: [SQLRow]

    public init(columns: [String], rows: [SQLRow]) {
        self.columns = columns
        self.rows = rows
    }
}

public extension SQLExecuteResult {
    func rowViews() -> [SQLRowView] {
        rows.map { SQLRowView(columns: columns, row: $0) }
    }

    func rowView(at index: Int) -> SQLRowView? {
        guard index >= 0 && index < rows.count else { return nil }
        return SQLRowView(columns: columns, row: rows[index])
    }
}

public struct SQLToolLoopHandlers: Sendable {
    public let listTables: @Sendable () async throws -> [SQLTableInfo]
    public let describeTable: @Sendable (SQLDescribeTableArgs) async throws -> SQLTableDescription
    public let sampleRows: (@Sendable (SQLSampleRowsArgs) async throws -> SQLExecuteResult)?
    public let executeSQL: @Sendable (SQLExecuteArgs) async throws -> SQLExecuteResult

    public init(
        listTables: @escaping @Sendable () async throws -> [SQLTableInfo],
        describeTable: @escaping @Sendable (SQLDescribeTableArgs) async throws -> SQLTableDescription,
        sampleRows: (@Sendable (SQLSampleRowsArgs) async throws -> SQLExecuteResult)? = nil,
        executeSQL: @escaping @Sendable (SQLExecuteArgs) async throws -> SQLExecuteResult
    ) {
        self.listTables = listTables
        self.describeTable = describeTable
        self.sampleRows = sampleRows
        self.executeSQL = executeSQL
    }
}

public struct SQLToolLoopOptions: Sendable {
    public let model: String
    public let prompt: String
    public let system: String?
    public let profileId: String?
    public let policy: JSONValue?
    public let maxAttempts: Int?
    public let requireSchemaInspection: Bool?
    public let sampleRows: Bool?
    public let sampleRowsLimit: Int?
    public let resultLimit: Int?
    public let requestOptions: ResponsesRequestOptions?

    public init(
        model: String,
        prompt: String,
        system: String? = nil,
        profileId: String? = nil,
        policy: JSONValue? = nil,
        maxAttempts: Int? = nil,
        requireSchemaInspection: Bool? = nil,
        sampleRows: Bool? = nil,
        sampleRowsLimit: Int? = nil,
        resultLimit: Int? = nil,
        requestOptions: ResponsesRequestOptions? = nil
    ) {
        self.model = model
        self.prompt = prompt
        self.system = system
        self.profileId = profileId
        self.policy = policy
        self.maxAttempts = maxAttempts
        self.requireSchemaInspection = requireSchemaInspection
        self.sampleRows = sampleRows
        self.sampleRowsLimit = sampleRowsLimit
        self.resultLimit = resultLimit
        self.requestOptions = requestOptions
    }

    public static func quickstart(
        model: String,
        prompt: String,
        profileId: String? = nil,
        policy: JSONValue? = nil,
        system: String? = nil,
        requestOptions: ResponsesRequestOptions? = nil
    ) -> SQLToolLoopOptions {
        SQLToolLoopOptions(
            model: model,
            prompt: prompt,
            system: system,
            profileId: profileId,
            policy: policy,
            requestOptions: requestOptions
        )
    }
}

public struct SQLToolLoopUsage: Equatable, Sendable {
    public var inputTokens: Int
    public var outputTokens: Int
    public var totalTokens: Int
    public var llmCalls: Int
    public var toolCalls: Int
}

public struct SQLToolLoopResult: Equatable, Sendable {
    public let summary: String
    public let sql: String
    public let columns: [String]
    public let rows: [SQLRow]
    public let usage: SQLToolLoopUsage
    public let attempts: Int
    public let notes: String?
}

public struct SQLValidationEvent: Equatable, Sendable {
    public let query: String
    public let response: SQLValidateResponse?
    public let error: String?

    public init(query: String, response: SQLValidateResponse?, error: String?) {
        self.query = query
        self.response = response
        self.error = error
    }
}

public struct SQLSampleRowsEvent: Equatable, Sendable {
    public let table: String
    public let limit: Int
    public let result: SQLExecuteResult

    public init(table: String, limit: Int, result: SQLExecuteResult) {
        self.table = table
        self.limit = limit
        self.result = result
    }
}

public struct SQLExecuteEvent: Equatable, Sendable {
    public let query: String
    public let limit: Int
    public let result: SQLExecuteResult

    public init(query: String, limit: Int, result: SQLExecuteResult) {
        self.query = query
        self.limit = limit
        self.result = result
    }
}

public enum SQLToolLoopStreamEvent: Equatable, Sendable {
    case summaryDelta(String)
    case listTables([SQLTableInfo])
    case describeTable(SQLTableDescription)
    case sampleRows(SQLSampleRowsEvent)
    case validation(SQLValidationEvent)
    case executeSQL(SQLExecuteEvent)
    case result(SQLToolLoopResult)
}

public struct SQLDescribeTableArgs: Sendable {
    public let table: String
    public init(table: String) { self.table = table }
}

public struct SQLSampleRowsArgs: Sendable {
    public let table: String
    public let limit: Int
    public init(table: String, limit: Int) {
        self.table = table
        self.limit = limit
    }
}

public struct SQLExecuteArgs: Sendable {
    public let query: String
    public let limit: Int
    public init(query: String, limit: Int) {
        self.query = query
        self.limit = limit
    }
}

private let defaultMaxAttempts = 3
private let defaultSampleRowsLimit = 3
private let maxSampleRowsLimit = 10
private let defaultResultLimit = 100
private let maxResultLimit = 1000
private let defaultMaxTurns = 100

private struct SQLToolLoopConfig {
    let maxAttempts: Int
    let resultLimit: Int
    let sampleRowsLimit: Int
    let requireSchemaInspection: Bool
    let sampleRowsEnabled: Bool
    let profileId: String?
    let policy: JSONValue?
}

private struct SQLToolLoopState {
    var attempts: Int = 0
    var listTablesCalled = false
    var describedTables: Set<String> = []
    var lastSQL = ""
    var lastColumns: [String] = []
    var lastRows: [SQLRow] = []
    var lastNotes = ""
}

private struct ToolExecutionResult {
    let toolCallId: String
    let content: String
}

private struct ToolExecutionOutcome {
    let result: ToolExecutionResult
    let events: [SQLToolLoopStreamEvent]
}

struct AnyResponseEventStream: AsyncSequence {
    typealias Element = ResponseEvent

    private let makeIterator: () -> AnyAsyncIterator

    init<S: AsyncSequence>(_ base: S) where S.Element == ResponseEvent {
        self.makeIterator = { AnyAsyncIterator(base.makeAsyncIterator()) }
    }

    func makeAsyncIterator() -> AnyAsyncIterator {
        makeIterator()
    }

    struct AnyAsyncIterator: AsyncIteratorProtocol {
        private var nextFn: () async throws -> ResponseEvent?

        init<I: AsyncIteratorProtocol>(_ iterator: I) where I.Element == ResponseEvent {
            var iterator = iterator
            self.nextFn = {
                try await iterator.next()
            }
        }

        mutating func next() async throws -> ResponseEvent? {
            try await nextFn()
        }
    }
}

private struct StreamFactoryBox: @unchecked Sendable {
    let call: (ResponseBuilder) async throws -> AnyResponseEventStream
}

private struct ResponsesClientBox: @unchecked Sendable {
    let value: ResponsesClient
}

private struct SQLClientBox: @unchecked Sendable {
    let value: SQLClient
}

private func validateSQLToolLoopOptions(_ options: SQLToolLoopOptions, handlers: SQLToolLoopHandlers) throws {
    if options.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw ModelRelayError.invalidConfiguration("model is required")
    }
    if options.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        throw ModelRelayError.invalidConfiguration("prompt is required")
    }
    if options.profileId == nil && options.policy == nil {
        throw ModelRelayError.invalidConfiguration("profileId or policy is required")
    }
    if options.sampleRows == true && handlers.sampleRows == nil {
        throw ModelRelayError.invalidConfiguration("sampleRows handler is required when sampleRows is enabled")
    }
}

private func normalizeSQLToolLoopConfig(_ options: SQLToolLoopOptions, handlers: SQLToolLoopHandlers) -> SQLToolLoopConfig {
    let maxAttempts = max(options.maxAttempts ?? defaultMaxAttempts, 1)
    let requireSchemaInspection = options.requireSchemaInspection ?? true
    let sampleRowsEnabled = options.sampleRows ?? (handlers.sampleRows != nil)
    return SQLToolLoopConfig(
        maxAttempts: maxAttempts,
        resultLimit: capLimit(options.resultLimit, defaultResultLimit, maxResultLimit),
        sampleRowsLimit: capLimit(options.sampleRowsLimit, defaultSampleRowsLimit, maxSampleRowsLimit),
        requireSchemaInspection: requireSchemaInspection,
        sampleRowsEnabled: sampleRowsEnabled,
        profileId: options.profileId,
        policy: options.policy
    )
}

private func capLimit(_ value: Int?, _ fallback: Int, _ maxValue: Int) -> Int {
    guard let value, value > 0 else { return fallback }
    return min(value, maxValue)
}

private func normalizeTableName(_ name: String) -> String {
    name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
}

private func encodeJSON<T: Encodable>(_ value: T) -> String {
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(value) else { return "" }
    return String(data: data, encoding: .utf8) ?? ""
}

private func decodeJSONValue(_ raw: String) -> JSONValue? {
    guard let data = raw.data(using: .utf8) else { return nil }
    return try? JSONDecoder().decode(JSONValue.self, from: data)
}

private func extractString(_ args: [String: JSONValue], key: String) -> String? {
    guard let value = args[key] else { return nil }
    if case .string(let string) = value { return string }
    return nil
}

private func extractInt(_ args: [String: JSONValue], key: String) -> Int? {
    guard let value = args[key] else { return nil }
    if case .number(let number) = value { return Int(number) }
    return nil
}

private func toolListTables() -> Tool {
    let parameters: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([:]),
        "additionalProperties": .bool(false)
    ])
    return Tool(function: FunctionTool(name: ToolName.listTables.rawValue, description: "List available tables in the database.", parameters: parameters))
}

private func toolDescribeTable() -> Tool {
    let parameters: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "table": .object([
                "type": .string("string"),
                "description": .string("Table name.")
            ])
        ]),
        "required": .array([.string("table")]),
        "additionalProperties": .bool(false)
    ])
    return Tool(function: FunctionTool(name: ToolName.describeTable.rawValue, description: "Describe a table's columns and types.", parameters: parameters))
}

private func toolSampleRows() -> Tool {
    let parameters: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "table": .object([
                "type": .string("string"),
                "description": .string("Table name.")
            ]),
            "limit": .object([
                "type": .string("integer"),
                "description": .string("Max rows to return.")
            ])
        ]),
        "required": .array([.string("table")]),
        "additionalProperties": .bool(false)
    ])
    return Tool(function: FunctionTool(name: ToolName.sampleRows.rawValue, description: "Return a small sample of rows from a table.", parameters: parameters))
}

private func toolExecuteSQL() -> Tool {
    let parameters: JSONValue = .object([
        "type": .string("object"),
        "properties": .object([
            "query": .object([
                "type": .string("string"),
                "description": .string("SQL query to run.")
            ]),
            "limit": .object([
                "type": .string("integer"),
                "description": .string("Max rows to return.")
            ])
        ]),
        "required": .array([.string("query")]),
        "additionalProperties": .bool(false)
    ])
    return Tool(function: FunctionTool(name: ToolName.executeSQL.rawValue, description: "Execute a read-only SQL query against the database.", parameters: parameters))
}

private func buildSQLToolDefinitions(_ cfg: SQLToolLoopConfig) -> [Tool] {
    var tools = [toolListTables(), toolDescribeTable()]
    if cfg.sampleRowsEnabled {
        tools.append(toolSampleRows())
    }
    tools.append(toolExecuteSQL())
    return tools
}

private func sqlLoopSystemPrompt(_ cfg: SQLToolLoopConfig, extra: String?) -> String {
    var steps = [
        "Use list_tables to see available tables.",
        "Use describe_table on any table you query."
    ]
    if cfg.sampleRowsEnabled {
        steps.append("Use sample_rows for quick context if needed.")
    }
    steps.append("Generate a read-only SELECT query.")
    steps.append("Call execute_sql to run it.")
    var lines = [
        "You are a SQL assistant that must follow this workflow:",
        "- " + steps.joined(separator: "\n- "),
        "- Maximum SQL attempts: \(cfg.maxAttempts).",
        "- Always keep result size <= \(cfg.resultLimit) rows."
    ]
    if cfg.requireSchemaInspection {
        lines.append("- Do not execute SQL until schema inspection is complete.")
    } else {
        lines.append("- Schema inspection is optional but recommended.")
    }
    lines.append("Return a concise summary of the results when done.")
    if let extra, !extra.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        lines.append("")
        lines.append(extra.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    return lines.joined(separator: "\n")
}

private func extractToolCalls(from response: Response) -> [ToolCall] {
    var calls: [ToolCall] = []
    for item in response.output {
        if case .message(_, _, let toolCalls) = item, let toolCalls {
            calls.append(contentsOf: toolCalls)
        }
    }
    return calls
}

private func executeToolCall(
    _ call: ToolCall,
    cfg: SQLToolLoopConfig,
    state: inout SQLToolLoopState,
    handlers: SQLToolLoopHandlers,
    sqlClient: SQLClient
) async -> ToolExecutionResult {
    let name = call.function?.name ?? ""
    let rawArgs = call.function?.arguments ?? "{}"
    guard let json = decodeJSONValue(rawArgs),
          case .object(let args) = json else {
        return ToolExecutionResult(toolCallId: call.id, content: "Error: invalid tool arguments")
    }

    switch name {
    case ToolName.listTables.rawValue:
        state.listTablesCalled = true
        do {
            let result = try await handlers.listTables()
            return ToolExecutionResult(toolCallId: call.id, content: encodeJSON(result))
        } catch {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: \(error)")
        }
    case ToolName.describeTable.rawValue:
        guard let table = extractString(args, key: "table"), !table.isEmpty else {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: describe_table requires table")
        }
        state.describedTables.insert(normalizeTableName(table))
        do {
            let result = try await handlers.describeTable(SQLDescribeTableArgs(table: table))
            return ToolExecutionResult(toolCallId: call.id, content: encodeJSON(result))
        } catch {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: \(error)")
        }
    case ToolName.sampleRows.rawValue:
        guard cfg.sampleRowsEnabled, let sampleRows = handlers.sampleRows else {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: sample_rows is disabled")
        }
        guard let table = extractString(args, key: "table"), !table.isEmpty else {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: sample_rows requires table")
        }
        let limit = capLimit(extractInt(args, key: "limit"), cfg.sampleRowsLimit, cfg.sampleRowsLimit)
        do {
            let result = try await sampleRows(SQLSampleRowsArgs(table: table, limit: limit))
            return ToolExecutionResult(toolCallId: call.id, content: encodeJSON(result))
        } catch {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: \(error)")
        }
    case ToolName.executeSQL.rawValue:
        guard let query = extractString(args, key: "query"), !query.isEmpty else {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: execute_sql requires query")
        }
        if state.attempts >= cfg.maxAttempts {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: max_attempts exceeded for execute_sql")
        }
        let limit = capLimit(extractInt(args, key: "limit"), cfg.resultLimit, cfg.resultLimit)
        let request = SQLValidateRequest(
            sql: query,
            profileId: cfg.profileId,
            policy: cfg.policy,
            overrides: nil
        )
        let validation: SQLValidateResponse
        do {
            validation = try await sqlClient.validate(request)
        } catch {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: sql.validate failed: \(error)")
        }
        guard validation.valid else {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: sql.validate rejected query")
        }
        guard validation.readOnly else {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: sql.validate rejected query: read_only=false")
        }
        guard !validation.normalizedSQL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: sql.validate rejected query: missing normalized_sql")
        }
        if cfg.requireSchemaInspection {
            if !state.listTablesCalled {
                return ToolExecutionResult(toolCallId: call.id, content: "Error: list_tables must be called before execute_sql")
            }
            if let tables = validation.tables {
                let missing = tables.filter { !state.describedTables.contains(normalizeTableName($0)) }
                if !missing.isEmpty {
                    return ToolExecutionResult(toolCallId: call.id, content: "Error: describe_table required for: \(missing.joined(separator: ", "))")
                }
            }
        }
        state.attempts += 1
        state.lastSQL = validation.normalizedSQL
        do {
            let result = try await handlers.executeSQL(SQLExecuteArgs(query: validation.normalizedSQL, limit: limit))
            state.lastColumns = result.columns
            state.lastRows = result.rows
            state.lastNotes = result.rows.isEmpty ? "query returned no rows" : ""
            return ToolExecutionResult(toolCallId: call.id, content: encodeJSON(result))
        } catch {
            return ToolExecutionResult(toolCallId: call.id, content: "Error: \(error)")
        }
    default:
        return ToolExecutionResult(toolCallId: call.id, content: "Error: unknown tool \(name)")
    }
}

private func executeToolCallStreaming(
    _ call: ToolCall,
    cfg: SQLToolLoopConfig,
    state: inout SQLToolLoopState,
    handlers: SQLToolLoopHandlers,
    sqlClient: SQLClient
) async -> ToolExecutionOutcome {
    let name = call.function?.name ?? ""
    let rawArgs = call.function?.arguments ?? "{}"
    guard let json = decodeJSONValue(rawArgs),
          case .object(let args) = json else {
        return ToolExecutionOutcome(
            result: ToolExecutionResult(toolCallId: call.id, content: "Error: invalid tool arguments"),
            events: []
        )
    }

    switch name {
    case ToolName.listTables.rawValue:
        state.listTablesCalled = true
        do {
            let result = try await handlers.listTables()
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: encodeJSON(result)),
                events: [.listTables(result)]
            )
        } catch {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: \(error)"),
                events: []
            )
        }
    case ToolName.describeTable.rawValue:
        guard let table = extractString(args, key: "table"), !table.isEmpty else {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: describe_table requires table"),
                events: []
            )
        }
        state.describedTables.insert(normalizeTableName(table))
        do {
            let result = try await handlers.describeTable(SQLDescribeTableArgs(table: table))
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: encodeJSON(result)),
                events: [.describeTable(result)]
            )
        } catch {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: \(error)"),
                events: []
            )
        }
    case ToolName.sampleRows.rawValue:
        guard cfg.sampleRowsEnabled, let sampleRows = handlers.sampleRows else {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: sample_rows is disabled"),
                events: []
            )
        }
        guard let table = extractString(args, key: "table"), !table.isEmpty else {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: sample_rows requires table"),
                events: []
            )
        }
        let limit = capLimit(extractInt(args, key: "limit"), cfg.sampleRowsLimit, cfg.sampleRowsLimit)
        do {
            let result = try await sampleRows(SQLSampleRowsArgs(table: table, limit: limit))
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: encodeJSON(result)),
                events: [.sampleRows(SQLSampleRowsEvent(table: table, limit: limit, result: result))]
            )
        } catch {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: \(error)"),
                events: []
            )
        }
    case ToolName.executeSQL.rawValue:
        guard let query = extractString(args, key: "query"), !query.isEmpty else {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: execute_sql requires query"),
                events: []
            )
        }
        if state.attempts >= cfg.maxAttempts {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: max_attempts exceeded for execute_sql"),
                events: []
            )
        }
        let limit = capLimit(extractInt(args, key: "limit"), cfg.resultLimit, cfg.resultLimit)
        let request = SQLValidateRequest(
            sql: query,
            profileId: cfg.profileId,
            policy: cfg.policy,
            overrides: nil
        )
        let validation: SQLValidateResponse
        do {
            validation = try await sqlClient.validate(request)
        } catch {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: sql.validate failed: \(error)"),
                events: [.validation(SQLValidationEvent(query: query, response: nil, error: "\(error)"))]
            )
        }

        var events: [SQLToolLoopStreamEvent] = [
            .validation(SQLValidationEvent(query: query, response: validation, error: nil))
        ]
        guard validation.valid else {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: sql.validate rejected query"),
                events: events
            )
        }
        guard validation.readOnly else {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: sql.validate rejected query: read_only=false"),
                events: events
            )
        }
        guard !validation.normalizedSQL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: sql.validate rejected query: missing normalized_sql"),
                events: events
            )
        }
        if cfg.requireSchemaInspection {
            if !state.listTablesCalled {
                return ToolExecutionOutcome(
                    result: ToolExecutionResult(toolCallId: call.id, content: "Error: list_tables must be called before execute_sql"),
                    events: events
                )
            }
            if let tables = validation.tables {
                let missing = tables.filter { !state.describedTables.contains(normalizeTableName($0)) }
                if !missing.isEmpty {
                    return ToolExecutionOutcome(
                        result: ToolExecutionResult(toolCallId: call.id, content: "Error: describe_table required for: \(missing.joined(separator: ", "))"),
                        events: events
                    )
                }
            }
        }
        state.attempts += 1
        state.lastSQL = validation.normalizedSQL
        do {
            let result = try await handlers.executeSQL(SQLExecuteArgs(query: validation.normalizedSQL, limit: limit))
            state.lastColumns = result.columns
            state.lastRows = result.rows
            state.lastNotes = result.rows.isEmpty ? "query returned no rows" : ""
            events.append(.executeSQL(SQLExecuteEvent(query: validation.normalizedSQL, limit: limit, result: result)))
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: encodeJSON(result)),
                events: events
            )
        } catch {
            return ToolExecutionOutcome(
                result: ToolExecutionResult(toolCallId: call.id, content: "Error: \(error)"),
                events: events
            )
        }
    default:
        return ToolExecutionOutcome(
            result: ToolExecutionResult(toolCallId: call.id, content: "Error: unknown tool \(name)"),
            events: []
        )
    }
}

public extension ModelRelayClient {
    func sqlToolLoop(
        model: String,
        prompt: String,
        handlers: SQLToolLoopHandlers,
        profileId: String? = nil,
        policy: JSONValue? = nil,
        system: String? = nil,
        maxAttempts: Int? = nil,
        requireSchemaInspection: Bool? = nil,
        sampleRows: Bool? = nil,
        sampleRowsLimit: Int? = nil,
        resultLimit: Int? = nil,
        requestOptions: ResponsesRequestOptions? = nil
    ) async throws -> SQLToolLoopResult {
        let options = SQLToolLoopOptions(
            model: model,
            prompt: prompt,
            system: system,
            profileId: profileId,
            policy: policy,
            maxAttempts: maxAttempts,
            requireSchemaInspection: requireSchemaInspection,
            sampleRows: sampleRows,
            sampleRowsLimit: sampleRowsLimit,
            resultLimit: resultLimit,
            requestOptions: requestOptions
        )
        return try await sqlToolLoop(options: options, handlers: handlers)
    }

    func sqlToolLoop(options: SQLToolLoopOptions, handlers: SQLToolLoopHandlers) async throws -> SQLToolLoopResult {
        try validateSQLToolLoopOptions(options, handlers: handlers)
        let cfg = normalizeSQLToolLoopConfig(options, handlers: handlers)
        var state = SQLToolLoopState()

        let tools = buildSQLToolDefinitions(cfg)
        let systemPrompt = sqlLoopSystemPrompt(cfg, extra: options.system)

        var input: [InputItem] = []
        if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            input.append(InputItem(role: .system, content: [.text(systemPrompt)]))
        }
        input.append(InputItem(role: .user, content: [.text(options.prompt)]))

        var usage = SQLToolLoopUsage(inputTokens: 0, outputTokens: 0, totalTokens: 0, llmCalls: 0, toolCalls: 0)
        var lastResponseText = ""

        for _ in 0..<defaultMaxTurns {
            var builder = responses.builder().model(options.model).input(input)
            builder = builder.tools(tools)
            let response = try await responses.create(builder, options: options.requestOptions)

            usage.llmCalls += 1
            usage.inputTokens += response.usage.inputTokens
            usage.outputTokens += response.usage.outputTokens
            usage.totalTokens += response.usage.totalTokens
            lastResponseText = response.text()

            let toolCalls = extractToolCalls(from: response)
            if toolCalls.isEmpty {
                let notes = state.lastNotes.isEmpty ? (state.lastSQL.isEmpty ? "no SQL executed" : nil) : state.lastNotes
                return SQLToolLoopResult(
                    summary: lastResponseText,
                    sql: state.lastSQL,
                    columns: state.lastColumns,
                    rows: state.lastRows,
                    usage: usage,
                    attempts: state.attempts,
                    notes: notes
                )
            }

            usage.toolCalls += toolCalls.count
            input.append(InputItem(role: .assistant, content: [.text(lastResponseText)], toolCalls: toolCalls))

            var results: [ToolExecutionResult] = []
            for call in toolCalls {
                let result = await executeToolCall(call, cfg: cfg, state: &state, handlers: handlers, sqlClient: sql)
                results.append(result)
            }

            for result in results {
                input.append(InputItem(role: .tool, content: [.text(result.content)], toolCallId: result.toolCallId))
            }
        }

        let notes = state.lastNotes.isEmpty ? (state.lastSQL.isEmpty ? "no SQL executed" : nil) : state.lastNotes
        return SQLToolLoopResult(
            summary: lastResponseText,
            sql: state.lastSQL,
            columns: state.lastColumns,
            rows: state.lastRows,
            usage: usage,
            attempts: state.attempts,
            notes: notes
        )
    }

    func sqlToolLoopStream(
        model: String,
        prompt: String,
        handlers: SQLToolLoopHandlers,
        profileId: String? = nil,
        policy: JSONValue? = nil,
        system: String? = nil,
        maxAttempts: Int? = nil,
        requireSchemaInspection: Bool? = nil,
        sampleRows: Bool? = nil,
        sampleRowsLimit: Int? = nil,
        resultLimit: Int? = nil,
        requestOptions: ResponsesRequestOptions? = nil,
        timeouts: StreamTimeouts = StreamTimeouts()
    ) -> AsyncThrowingStream<SQLToolLoopStreamEvent, Error> {
        let options = SQLToolLoopOptions(
            model: model,
            prompt: prompt,
            system: system,
            profileId: profileId,
            policy: policy,
            maxAttempts: maxAttempts,
            requireSchemaInspection: requireSchemaInspection,
            sampleRows: sampleRows,
            sampleRowsLimit: sampleRowsLimit,
            resultLimit: resultLimit,
            requestOptions: requestOptions
        )
        return sqlToolLoopStream(options: options, handlers: handlers, timeouts: timeouts)
    }

    func sqlToolLoopStream(
        options: SQLToolLoopOptions,
        handlers: SQLToolLoopHandlers,
        timeouts: StreamTimeouts = StreamTimeouts()
    ) -> AsyncThrowingStream<SQLToolLoopStreamEvent, Error> {
        sqlToolLoopStream(
            options: options,
            handlers: handlers,
            timeouts: timeouts,
            streamFactory: { [responses] builder in
                let stream = try await responses.stream(builder, timeouts: timeouts)
                return AnyResponseEventStream(stream)
            }
        )
    }

    internal func sqlToolLoopStream(
        options: SQLToolLoopOptions,
        handlers: SQLToolLoopHandlers,
        timeouts: StreamTimeouts,
        streamFactory: @escaping (ResponseBuilder) async throws -> AnyResponseEventStream
    ) -> AsyncThrowingStream<SQLToolLoopStreamEvent, Error> {
        let factory = StreamFactoryBox(call: streamFactory)
        let responsesBox = ResponsesClientBox(value: responses)
        let sqlBox = SQLClientBox(value: sql)
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    try validateSQLToolLoopOptions(options, handlers: handlers)
                    let cfg = normalizeSQLToolLoopConfig(options, handlers: handlers)
                    var state = SQLToolLoopState()

                    let tools = buildSQLToolDefinitions(cfg)
                    let systemPrompt = sqlLoopSystemPrompt(cfg, extra: options.system)

                    var input: [InputItem] = []
                    if !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        input.append(InputItem(role: .system, content: [.text(systemPrompt)]))
                    }
                    input.append(InputItem(role: .user, content: [.text(options.prompt)]))

                    var usage = SQLToolLoopUsage(inputTokens: 0, outputTokens: 0, totalTokens: 0, llmCalls: 0, toolCalls: 0)
                    var lastResponseText = ""

                    for _ in 0..<defaultMaxTurns {
                        var builder = responsesBox.value.builder().model(options.model).input(input)
                        builder = builder.tools(tools)
                        builder.options = builder.options.merging(options.requestOptions)
                        let stream = try await factory.call(builder)

                        var toolCalls: [ToolCall] = []
                        var responseUsage: Usage?
                        lastResponseText = ""

                        for try await event in stream {
                            if event.type == .messageDelta, let delta = event.textDelta {
                                lastResponseText.append(delta)
                                continuation.yield(SQLToolLoopStreamEvent.summaryDelta(delta))
                            }
                            if event.type == .messageStop, let final = event.textDelta {
                                lastResponseText = final
                            }
                            if let calls = event.toolCalls {
                                toolCalls = calls
                            }
                            if let eventUsage = event.usage {
                                responseUsage = eventUsage
                            }
                        }

                        guard let responseUsage else {
                            throw ModelRelayError.transport("stream ended without usage")
                        }

                        usage.llmCalls += 1
                        usage.inputTokens += responseUsage.inputTokens
                        usage.outputTokens += responseUsage.outputTokens
                        usage.totalTokens += responseUsage.totalTokens

                        if toolCalls.isEmpty {
                            let notes = state.lastNotes.isEmpty ? (state.lastSQL.isEmpty ? "no SQL executed" : nil) : state.lastNotes
                            let result = SQLToolLoopResult(
                                summary: lastResponseText,
                                sql: state.lastSQL,
                                columns: state.lastColumns,
                                rows: state.lastRows,
                                usage: usage,
                                attempts: state.attempts,
                                notes: notes
                            )
                            continuation.yield(SQLToolLoopStreamEvent.result(result))
                            continuation.finish()
                            return
                        }

                        usage.toolCalls += toolCalls.count
                        input.append(InputItem(role: .assistant, content: [.text(lastResponseText)], toolCalls: toolCalls))

                        var results: [ToolExecutionResult] = []
                        for call in toolCalls {
                            let outcome = await executeToolCallStreaming(call, cfg: cfg, state: &state, handlers: handlers, sqlClient: sqlBox.value)
                            results.append(outcome.result)
                            for event in outcome.events {
                                continuation.yield(event)
                            }
                        }

                        for result in results {
                            input.append(InputItem(role: .tool, content: [.text(result.content)], toolCallId: result.toolCallId))
                        }
                    }

                    let notes = state.lastNotes.isEmpty ? (state.lastSQL.isEmpty ? "no SQL executed" : nil) : state.lastNotes
                    let result = SQLToolLoopResult(
                        summary: lastResponseText,
                        sql: state.lastSQL,
                        columns: state.lastColumns,
                        rows: state.lastRows,
                        usage: usage,
                        attempts: state.attempts,
                        notes: notes
                    )
                    continuation.yield(SQLToolLoopStreamEvent.result(result))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
