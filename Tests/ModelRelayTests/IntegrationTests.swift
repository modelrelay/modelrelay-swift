import XCTest
@testable import ModelRelay

final class IntegrationTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        loadEnvIfNeeded()
    }

    func testIntegrationResponsesText() async throws {
        let (client, model) = try integrationClient()
        let text = try await client.responses.text(model: model, user: "Say hi")
        XCTAssertFalse(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testIntegrationStreamingDeltas() async throws {
        let (client, model) = try integrationClient()
        let builder = client.responses.builder().model(model).user("Write two words")
        let stream = try await client.responses.streamTextDeltas(builder)
        var collected = ""
        var count = 0
        for try await delta in stream {
            collected += delta
            count += 1
            if count >= 3 { break }
        }
        XCTAssertFalse(collected.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    func testIntegrationWorkflowsAndRuns() async throws {
        let (client, model) = try integrationClient()
        let spec: JSONValue = .object([
            "kind": .string("workflow"),
            "name": .string("swift-integration"),
            "nodes": .array([
                .object([
                    "id": .string("node1"),
                    "type": .string("llm"),
                    "model": .string(model),
                    "user": .string("Say hello")
                ])
            ]),
            "outputs": .array([
                .object([
                    "name": .string("result"),
                    "from": .string("node1")
                ])
            ])
        ])

        let compile = try await client.workflows.compile(spec: spec)
        let planHash: PlanHash
        switch compile {
        case .success(_, let hash):
            planHash = hash
        case .validationError(let issues):
            XCTFail("Workflow validation failed: \(issues)")
            return
        case .internalError(let status, let message, _, _):
            XCTFail("Workflow compile failed: \(status) \(message ?? "")")
            return
        }

        let run = try await client.runs.createFromPlan(planHash: planHash)
        XCTAssertFalse(run.runId.isEmpty)
    }

    func testIntegrationStateHandles() async throws {
        let (client, _) = try integrationClient()
        let state = try await client.stateHandles.create(request: StateHandleCreateRequest(ttlSeconds: 60))
        XCTAssertFalse(state.id.isEmpty)
        _ = try await client.stateHandles.list(limit: 1)
        try await client.stateHandles.delete(stateId: state.id)
    }
}

private func integrationClient() throws -> (ModelRelayClient, String) {
    let env = ProcessInfo.processInfo.environment
    guard env["MODELRELAY_SWIFT_INTEGRATION"] == "1" else {
        throw XCTSkip("Integration tests disabled (set MODELRELAY_SWIFT_INTEGRATION=1)")
    }
    guard let apiKey = env["MODELRELAY_API_KEY"], !apiKey.isEmpty else {
        throw XCTSkip("MODELRELAY_API_KEY not set")
    }
    let baseURL = env["MODELRELAY_API_BASE_URL"] ?? env["MODELRELAY_API_URL"] ?? "https://api.modelrelay.ai/api/v1"
    let normalized = normalizeBaseURL(baseURL)
    guard let url = URL(string: normalized) else {
        throw XCTSkip("Invalid MODELRELAY_API_BASE_URL")
    }
    let model = env["MODELRELAY_TEST_MODEL"] ?? "claude-sonnet-4-5"
    let client = try ModelRelayClient(ClientConfig(baseURL: url, apiKey: apiKey))
    return (client, model)
}

private func loadEnvIfNeeded() {
    if ProcessInfo.processInfo.environment["MODELRELAY_API_KEY"] != nil {
        return
    }
    let current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    let envURL = current.appendingPathComponent("../../.env.llm-int").standardizedFileURL
    guard let data = try? Data(contentsOf: envURL),
          let content = String(data: data, encoding: .utf8) else {
        return
    }
    for line in content.split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        let parts = trimmed.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { continue }
        let key = String(parts[0])
        let value = String(parts[1]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        setenv(key, value, 0)
    }
}

private func normalizeBaseURL(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    guard let url = URL(string: trimmed) else { return value }
    let path = url.path
    if path.isEmpty || path == "/" {
        return trimmed + "/api/v1"
    }
    if path.contains("/api/v1") {
        return trimmed
    }
    return trimmed + "/api/v1"
}
