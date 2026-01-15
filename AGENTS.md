# Swift SDK Component

Swift Package for ModelRelay API (Swift 6.2).

## Key Information

- Package name: `ModelRelay` (Swift Package Manager)
- Entry point: `ModelRelayClient` in `Sources/ModelRelay/Client.swift`
- Default base URL: `https://api.modelrelay.ai/api/v1/`
- Auth headers: `X-ModelRelay-Api-Key` or `Authorization: Bearer <token>`
- Responses API client: `ResponsesClient` in `Sources/ModelRelay/Responses.swift`
- Request builder: `ResponseBuilder` in `Sources/ModelRelay/ResponseBuilder.swift`
- Streaming: `ResponsesStream` in `Sources/ModelRelay/Streaming.swift` (NDJSON parsing)
- Runs/workflows/state handles clients: `RunsClient`, `WorkflowsClient`, `StateHandlesClient`
- Structured output: `Structured.swift` adds `object`/`structured` helpers
- Extract assistant text via `Response.text()` / `Response.textChunks()`
- `ResponsesClient.create` validates `input` is non-empty and applies `X-ModelRelay-Customer-Id` / `X-ModelRelay-Request-Id` headers from options
- `ResponseBuilder` stores both request payload and per-call options (headers, timeout, customerId, requestId, retry)
