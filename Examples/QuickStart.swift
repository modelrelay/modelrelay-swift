// QuickStart.swift
// Basic usage examples for the ModelRelay Swift SDK.
//
// These examples demonstrate the core functionality of the SDK.
// To run: swift run QuickStart (requires MODELRELAY_API_KEY environment variable)

import Foundation
import ModelRelay

@main
struct QuickStart {
    static func main() async throws {
        guard let apiKey = ProcessInfo.processInfo.environment["MODELRELAY_API_KEY"] else {
            print("Error: MODELRELAY_API_KEY environment variable not set")
            return
        }

        let client = try ModelRelayClient.fromAPIKey(apiKey)

        // Example 1: Simple ask
        print("=== Ask Example ===")
        let answer = try await client.ask(model: "claude-sonnet-4-5", prompt: "What is 2 + 2?")
        print("Answer: \(answer)")

        // Example 2: Text with system prompt
        print("\n=== Text with System Prompt ===")
        let response = try await client.responses.text(
            model: "claude-sonnet-4-5",
            system: "You are a helpful assistant. Be concise.",
            user: "What is the capital of France?"
        )
        print("Response: \(response)")

        // Example 3: ResponseBuilder
        print("\n=== ResponseBuilder Example ===")
        let builderResponse = try await client.responses.create(
            client.responses
                .builder()
                .model("claude-sonnet-4-5")
                .system("You are a helpful assistant.")
                .user("Write one sentence about Swift programming.")
                .maxOutputTokens(100)
                .temperature(0.7)
        )
        print("Builder response: \(builderResponse.text())")

        // Example 4: Streaming
        print("\n=== Streaming Example ===")
        print("Streaming: ", terminator: "")
        let stream = try await client.responses.stream(
            client.responses
                .builder()
                .model("claude-sonnet-4-5")
                .user("Count from 1 to 5, one number per line.")
        )
        for try await event in stream {
            if event.type == .messageDelta, let delta = event.textDelta {
                print(delta, terminator: "")
            }
        }
        print()

        print("\n=== Done ===")
    }
}
