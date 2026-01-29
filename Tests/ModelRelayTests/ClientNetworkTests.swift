import XCTest
@testable import ModelRelay

final class ClientNetworkTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        resetStubs()
    }

    func testResponsesClientAddsCustomerAndRequestHeaders() async throws {
        let session = makeStubbedSession()
        let http = HTTPClient(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            clientHeaderValue: "test-client",
            defaultHeaders: [:],
            session: session,
            defaultTimeout: 5
        )
        let auth = AuthClient(http: http, config: AuthConfig(apiKey: "mr_sk_test"))
        let client = ResponsesClient(http: http, auth: auth)

        enqueueStub { request in
            let json = """
            {"id":"resp_1","output":[{"type":"message","role":"assistant","content":[{"type":"text","text":"ok"}]}],"stop_reason":"completed","model":"claude","usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let builder = ResponseBuilder()
            .model("claude")
            .user("hi")
            .customerId("cust_123")
            .requestId("req_456")

        _ = try await client.create(builder)

        let request = try XCTUnwrap(stubRequests().first)
        XCTAssertEqual(request.value(forHTTPHeaderField: customerIdHeader), "cust_123")
        XCTAssertEqual(request.value(forHTTPHeaderField: requestIdHeader), "req_456")
    }

    func testRunsClientEncodesModelOverrides() async throws {
        let session = makeStubbedSession()
        let http = HTTPClient(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            clientHeaderValue: "test-client",
            defaultHeaders: [:],
            session: session,
            defaultTimeout: 5
        )
        let auth = AuthClient(http: http, config: AuthConfig(apiKey: "mr_sk_test"))
        let client = RunsClient(http: http, auth: auth)

        enqueueStub { request in
            let json = """
            {"run_id":"run_1","plan_hash":"plan_1","status":"running"}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let spec: JSONValue = .object([
            "version": .string("v1"),
            "nodes": .array([])
        ])

        let overrides = RunsModelOverrides(
            nodes: ["node_a": "claude"],
            fanoutSubnodes: [RunsFanoutSubnodeOverride(parentId: "p", subnodeId: "s", model: "gpt")]
        )

        _ = try await client.create(spec: spec, options: RunsCreateOptions(modelOverride: "claude", modelOverrides: overrides))

        let request = try XCTUnwrap(stubRequests().first)
        let body: Data
        if let httpBody = request.httpBody {
            body = httpBody
        } else if let stream = request.httpBodyStream {
            body = readBody(stream)
        } else {
            XCTFail("Expected request body")
            return
        }
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let modelOverride = object?["model_override"] as? String
        XCTAssertEqual(modelOverride, "claude")
        let modelOverrides = object?["model_overrides"] as? [String: Any]
        let nodes = modelOverrides?["nodes"] as? [String: String]
        XCTAssertEqual(nodes?["node_a"], "claude")
    }

    func testWorkflowsClientReturnsValidationError() async throws {
        let session = makeStubbedSession()
        let http = HTTPClient(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            clientHeaderValue: "test-client",
            defaultHeaders: [:],
            session: session,
            defaultTimeout: 5
        )
        let auth = AuthClient(http: http, config: AuthConfig(apiKey: "mr_sk_test"))
        let client = WorkflowsClient(http: http, auth: auth)

        enqueueStub { request in
            let json = """
            {"error":{"issues":[{"path":"nodes[0]","message":"bad"}]}}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 422, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let spec: JSONValue = .object(["version": .string("v1"), "nodes": .array([])])
        let result = try await client.compile(spec: spec)

        switch result {
        case .validationError(let issues):
            XCTAssertEqual(issues.first?.path, "nodes[0]")
        default:
            XCTFail("Expected validationError")
        }
    }

    func testStructuredRetriesOnce() async throws {
        let session = makeStubbedSession()
        let http = HTTPClient(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            clientHeaderValue: "test-client",
            defaultHeaders: [:],
            session: session,
            defaultTimeout: 5
        )
        let auth = AuthClient(http: http, config: AuthConfig(apiKey: "mr_sk_test"))
        let client = ResponsesClient(http: http, auth: auth)

        enqueueStub { request in
            let json = """
            {"id":"resp_1","output":[{"type":"message","role":"assistant","content":[{"type":"text","text":"not json"}]}],"stop_reason":"completed","model":"claude","usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        enqueueStub { request in
            let json = """
            {"id":"resp_2","output":[{"type":"message","role":"assistant","content":[{"type":"text","text":"{\\\"ok\\\":true}"}]}],"stop_reason":"completed","model":"claude","usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        struct Output: Decodable { let ok: Bool }
        let schema: JSONValue = .object([
            "type": .string("object"),
            "properties": .object(["ok": .object(["type": .string("boolean")])]),
            "required": .array([.string("ok")])
        ])

        let result: StructuredResult<Output> = try await client.objectWithMetadata(
            model: "claude",
            schema: schema,
            prompt: "return ok",
            options: StructuredOptions(maxRetries: 1)
        )

        XCTAssertTrue(result.value.ok)
        XCTAssertEqual(result.attempts, 2)
    }

    func testResponsesBatchSendsHeadersAndOptions() async throws {
        let session = makeStubbedSession()
        let http = HTTPClient(
            baseURL: URL(string: "https://example.com/api/v1/")!,
            clientHeaderValue: "test-client",
            defaultHeaders: [:],
            session: session,
            defaultTimeout: 5
        )
        let auth = AuthClient(http: http, config: AuthConfig(apiKey: "mr_sk_test"))
        let client = ResponsesClient(http: http, auth: auth)

        enqueueStub { request in
            let json = """
            {"id":"batch_1","results":[{"id":"one","status":"success","response":{"id":"resp_1","output":[{"type":"message","role":"assistant","content":[{"type":"text","text":"ok"}]}],"stop_reason":"completed","model":"claude","usage":{"input_tokens":1,"output_tokens":1,"total_tokens":2}}},{"id":"two","status":"error","error":{"status":400,"message":"bad request","code":"INVALID"}}],"usage":{"total_input_tokens":2,"total_output_tokens":1,"total_requests":2,"successful_requests":1,"failed_requests":1}}
            """
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data(json.utf8))
        }

        let first = ResponseBuilder().model("claude").user("hi")
        let second = ResponseBuilder().model("claude").user("yo")
        let options = ResponsesBatchRequestOptions(
            customerId: "cust_123",
            requestId: "req_456",
            maxConcurrent: 5,
            failFast: true,
            itemTimeoutMs: 1500
        )

        _ = try await client.batch(
            [
                ResponsesBatchItem(id: "one", request: first.request),
                ResponsesBatchItem(id: "two", request: second.request),
            ],
            options: options
        )

        let request = try XCTUnwrap(stubRequests().first)
        XCTAssertEqual(request.value(forHTTPHeaderField: customerIdHeader), "cust_123")
        XCTAssertEqual(request.value(forHTTPHeaderField: requestIdHeader), "req_456")

        let body: Data
        if let httpBody = request.httpBody {
            body = httpBody
        } else if let stream = request.httpBodyStream {
            body = readBody(stream)
        } else {
            XCTFail("Expected request body")
            return
        }
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        let optionsPayload = object?["options"] as? [String: Any]
        XCTAssertEqual(optionsPayload?["max_concurrent"] as? Int, 5)
        XCTAssertEqual(optionsPayload?["fail_fast"] as? Bool, true)
        XCTAssertEqual(optionsPayload?["timeout_ms"] as? Int, 1500)
        let requestsPayload = object?["requests"] as? [[String: Any]]
        XCTAssertEqual(requestsPayload?.count, 2)
        XCTAssertEqual(requestsPayload?.first?["id"] as? String, "one")
    }
}

private func readBody(_ stream: InputStream) -> Data {
    stream.open()
    defer { stream.close() }
    var data = Data()
    let bufferSize = 1024
    var buffer = [UInt8](repeating: 0, count: bufferSize)
    while stream.hasBytesAvailable {
        let read = stream.read(&buffer, maxLength: bufferSize)
        if read > 0 {
            data.append(buffer, count: read)
        } else {
            break
        }
    }
    return data
}
