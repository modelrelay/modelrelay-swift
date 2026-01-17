import XCTest
@testable import ModelRelay

final class SQLToolLoopTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        resetStubs()
    }

    func testSQLToolLoopRejectsNonReadOnlyValidation() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            apiKey: "mr_sk_test",
            session: session
        ))

        enqueueStub(makeResponseStub(path: "/responses", json: """
        {"id":"resp_1","output":[{"type":"message","role":"assistant","content":[{"type":"text","text":""}],"tool_calls":[{"id":"call_list","type":"function","function":{"name":"list_tables","arguments":"{}"}},{"id":"call_desc","type":"function","function":{"name":"describe_table","arguments":"{\\"table\\":\\"users\\"}"}}]}],"stop_reason":"tool_calls","model":"test","usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}
        """))

        enqueueStub(makeResponseStub(path: "/responses", json: """
        {"id":"resp_2","output":[{"type":"message","role":"assistant","content":[{"type":"text","text":""}],"tool_calls":[{"id":"call_exec","type":"function","function":{"name":"execute_sql","arguments":"{\\"query\\":\\"DELETE FROM users\\"}"}}]}],"stop_reason":"tool_calls","model":"test","usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}
        """))

        enqueueStub(makeResponseStub(path: "/sql/validate", json: """
        {"valid":true,"normalized_sql":"DELETE FROM users","read_only":false}
        """))

        enqueueStub(makeResponseStub(path: "/responses", json: """
        {"id":"resp_3","output":[{"type":"message","role":"assistant","content":[{"type":"text","text":"Done"}]}],"stop_reason":"completed","model":"test","usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}
        """))

        let executed = BoolBox()
        let handlers = SQLToolLoopHandlers(
            listTables: { [SQLTableInfo(name: "users")] },
            describeTable: { _ in SQLTableDescription(table: "users", columns: []) },
            executeSQL: { _ in
                executed.value = true
                return SQLExecuteResult(columns: [], rows: [])
            }
        )

        let options = SQLToolLoopOptions(
            model: "test-model",
            prompt: "Delete users",
            profileId: "profile_1",
            requireSchemaInspection: false
        )

        let result = try await client.sqlToolLoop(options: options, handlers: handlers)
        XCTAssertFalse(executed.value)
        XCTAssertEqual(result.sql, "")
        XCTAssertEqual(result.notes, "no SQL executed")
        XCTAssertEqual(result.summary, "Done")
    }

    func testSQLToolLoopRequiresSampleRowsHandlerWhenEnabled() async {
        let session = makeStubbedSession()
        let client = try? ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            apiKey: "mr_sk_test",
            session: session
        ))

        let handlers = SQLToolLoopHandlers(
            listTables: { [] },
            describeTable: { _ in SQLTableDescription(table: "t", columns: []) },
            executeSQL: { _ in SQLExecuteResult(columns: [], rows: []) }
        )

        let options = SQLToolLoopOptions(
            model: "test-model",
            prompt: "Query",
            profileId: "profile_1",
            sampleRows: true
        )

        do {
            _ = try await client?.sqlToolLoop(options: options, handlers: handlers)
            XCTFail("Expected error")
        } catch let ModelRelayError.invalidConfiguration(message) {
            XCTAssertTrue(message.contains("sampleRows handler is required"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSQLToolLoopQuickstartBuilderSetsFields() {
        let options = SQLToolLoopOptions.quickstart(
            model: "test-model",
            prompt: "Find users",
            profileId: "profile_1",
            system: "system"
        )
        XCTAssertEqual(options.model, "test-model")
        XCTAssertEqual(options.prompt, "Find users")
        XCTAssertEqual(options.profileId, "profile_1")
        XCTAssertEqual(options.system, "system")
    }

    func testSQLRowViewProvidesOrderedValues() {
        let result = SQLExecuteResult(
            columns: ["id", "name"],
            rows: [
                ["name": .string("Ada"), "id": .number(1)]
            ]
        )
        let view = result.rowView(at: 0)
        XCTAssertEqual(view?.values, [.number(1), .string("Ada")])
        XCTAssertEqual(view?.int("id"), 1)
        XCTAssertEqual(view?.string("name"), "Ada")
        XCTAssertNil(view?.bool("active"))
    }

    func testSQLToolLoopStreamEmitsEvents() async throws {
        let session = makeStubbedSession()
        let client = try ModelRelayClient(ClientConfig(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            apiKey: "mr_sk_test",
            session: session
        ))

        enqueueStub(makeResponseStub(path: "/sql/validate", json: """
        {"valid":true,"normalized_sql":"SELECT 1","read_only":true}
        """))

        let handlers = SQLToolLoopHandlers(
            listTables: { [SQLTableInfo(name: "users")] },
            describeTable: { _ in SQLTableDescription(table: "users", columns: []) },
            executeSQL: { _ in SQLExecuteResult(columns: ["value"], rows: [["value": .number(1)]]) }
        )

        let options = SQLToolLoopOptions(
            model: "test-model",
            prompt: "Query",
            profileId: "profile_1"
        )

        let toolCalls = [
            ToolCall(
                id: "call_list",
                type: .function,
                function: FunctionCall(name: "list_tables", arguments: "{}")
            ),
            ToolCall(
                id: "call_exec",
                type: .function,
                function: FunctionCall(name: "execute_sql", arguments: "{\"query\":\"SELECT 1\"}")
            )
        ]

        let firstUsage = Usage(inputTokens: 1, outputTokens: 1, totalTokens: 2)
        let secondUsage = Usage(inputTokens: 2, outputTokens: 3, totalTokens: 5)

        let firstStream = AsyncStream<ResponseEvent> { continuation in
            continuation.yield(ResponseEvent(
                type: .toolUseStop,
                event: "tool_use_stop",
                data: .object([:]),
                textDelta: nil,
                toolCallDelta: nil,
                toolCalls: toolCalls,
                toolResult: nil,
                responseId: "resp_1",
                model: "test",
                stopReason: StopReason(rawValue: "tool_calls"),
                usage: firstUsage,
                requestId: nil,
                raw: ""
            ))
            continuation.finish()
        }

        let secondStream = AsyncStream<ResponseEvent> { continuation in
            continuation.yield(ResponseEvent(
                type: .messageDelta,
                event: "update",
                data: .object([:]),
                textDelta: "Done",
                toolCallDelta: nil,
                toolCalls: nil,
                toolResult: nil,
                responseId: "resp_2",
                model: "test",
                stopReason: nil,
                usage: nil,
                requestId: nil,
                raw: ""
            ))
            continuation.yield(ResponseEvent(
                type: .messageStop,
                event: "completion",
                data: .object([:]),
                textDelta: "Done",
                toolCallDelta: nil,
                toolCalls: nil,
                toolResult: nil,
                responseId: "resp_2",
                model: "test",
                stopReason: StopReason(rawValue: "completed"),
                usage: secondUsage,
                requestId: nil,
                raw: ""
            ))
            continuation.finish()
        }

        var streamIndex = 0
        let streamFactory: (ResponseBuilder) async throws -> AnyResponseEventStream = { _ in
            defer { streamIndex += 1 }
            let stream = streamIndex == 0 ? firstStream : secondStream
            return AnyResponseEventStream(stream)
        }

        let stream = client.sqlToolLoopStream(
            options: options,
            handlers: handlers,
            timeouts: StreamTimeouts(),
            streamFactory: streamFactory
        )

        var events: [SQLToolLoopStreamEvent] = []
        for try await event in stream {
            events.append(event)
        }

        XCTAssertTrue(events.contains { event in
            if case .listTables(let tables) = event { return tables.first?.name == "users" }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case .validation(let validation) = event { return validation.response?.valid == true }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case .executeSQL(let execution) = event { return execution.result.columns == ["value"] }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case .summaryDelta(let delta) = event { return delta == "Done" }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case .result(let result) = event { return result.summary == "Done" }
            return false
        })
    }
}

private func makeResponseStub(path: String, json: String) -> StubState.Handler {
    return { request in
        let requestPath = request.url?.path ?? ""
        guard requestPath.hasSuffix(path) else {
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, Data(json.utf8))
    }
}

private final class BoolBox: @unchecked Sendable {
    var value = false
}
