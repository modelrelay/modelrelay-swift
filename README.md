# ModelRelay Swift SDK

Native Swift client for the ModelRelay API, modeled after the Rust SDK.

## Install (Swift Package Manager)

```swift
.package(url: "https://github.com/modelrelay/modelrelay-swift", from: "0.5.0"),
```

```swift
import ModelRelay

let client = try ModelRelayClient.fromAPIKey("mr_sk_...")
let answer = try await client.ask(model: "claude-sonnet-4-5", prompt: "What is 2 + 2?")
print(answer)
```

## Responses Builder

```swift
let response = try await client.responses.create(
    client.responses
        .builder()
        .model("claude-sonnet-4-5")
        .system("Answer concisely")
        .user("Write one line about Swift")
)

print(response.text())
```

## Streaming Responses

```swift
let stream = try await client.responses.stream(
    client.responses.builder().model("claude-sonnet-4-5").user("Say hi")
)
for try await event in stream {
    if event.type == .messageDelta, let delta = event.textDelta {
        print(delta, terminator: "")
    }
}
```

## SQL Tool Loop (Options)

```swift
let handlers = SQLToolLoopHandlers(
    listTables: { [SQLTableInfo(name: "users")] },
    describeTable: { _ in SQLTableDescription(table: "users", columns: []) },
    sampleRows: { args in
        SQLExecuteResult(columns: ["id"], rows: [["id": .number(1)]])
    },
    executeSQL: { args in
        SQLExecuteResult(columns: ["id"], rows: [["id": .number(1)]])
    }
)

let result = try await client.sqlToolLoop(
    model: "claude-sonnet-4-5",
    prompt: "Count users",
    handlers: handlers,
    profileId: "profile_1",
    maxAttempts: 3,
    resultLimit: 100,
    requireSchemaInspection: true,
    sampleRows: true,
    sampleRowsLimit: 3,
    system: "Only use read-only queries"
)
print(result.summary)
```

## SQL Tool Loop (Streaming)

```swift
let stream = client.sqlToolLoopStream(
    model: "claude-sonnet-4-5",
    prompt: "List recent users",
    handlers: handlers,
    profileId: "profile_1"
)

for try await event in stream {
    switch event {
    case .summaryDelta(let delta):
        print(delta, terminator: "")
    case .executeSQL(let exec):
        print("Rows:", exec.result.rows.count)
    case .result(let result):
        print("Final SQL:", result.sql)
    default:
        break
    }
}
```

## SQL Row Helpers

```swift
let rows = result.rows
let views = result.rowViews()
if let first = views.first {
    print(first.int("id") ?? 0)
    print(first.string("email") ?? "")
}
```

## Structured Output

```swift
struct Review: Decodable { let risk: String }

let schema: JSONValue = .object([
    "type": .string("object"),
    "properties": .object([
        "risk": .object(["type": .string("string")])
    ]),
    "required": .array([.string("risk")])
])

let review = try await client.responses.object(
    model: "claude-sonnet-4-5",
    schema: schema,
    prompt: "Classify the risk as low/medium/high"
) as Review
```

## Workflows + Runs

```swift
let spec: JSONValue = .object([
    "version": .string("v1"),
    "nodes": .array([])
])

let compile = try await client.workflows.compile(spec: spec)
if case .success(_, let planHash) = compile {
    let run = try await client.runs.createFromPlan(planHash: planHash)
    print(run.runId)
}
```

## Customer-scoped requests

```swift
let customer = try client.forCustomer("customer-123")
let text = try await customer.responses.text(model: "claude-sonnet-4-5", user: "Say hi")
print(text)
```

## Customer Token Provider

```swift
let provider = try CustomerTokenProvider(CustomerTokenProviderConfig(
    secretKey: "mr_sk_...",
    request: CustomerTokenRequest(customerExternalId: "customer-123")
))
let tokenClient = try ModelRelayClient.fromTokenProvider(provider)
let text = try await tokenClient.responses.text(model: "claude-sonnet-4-5", user: "Hi")
print(text)
```
