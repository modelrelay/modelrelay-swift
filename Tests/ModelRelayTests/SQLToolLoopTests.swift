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

        var executed = false
        let handlers = SQLToolLoopHandlers(
            listTables: { [SQLTableInfo(name: "users")] },
            describeTable: { _ in SQLTableDescription(table: "users", columns: []) },
            executeSQL: { _ in
                executed = true
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
        XCTAssertFalse(executed)
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
