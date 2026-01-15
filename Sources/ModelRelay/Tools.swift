import Foundation

public struct ToolBuilder: Equatable {
    public private(set) var tools: [Tool]

    public init(tools: [Tool] = []) {
        self.tools = tools
    }

    public func addFunction(name: String, description: String? = nil, parameters: JSONValue? = nil) -> ToolBuilder {
        var copy = self
        let function = FunctionTool(name: name, description: description, parameters: parameters)
        copy.tools.append(Tool(function: function))
        return copy
    }
}

public func extractAssistantText(from output: [OutputItem]) -> String {
    output.flatMap { item -> [String] in
        switch item {
        case .message(let role, let content, _):
            guard role == .assistant else { return [] }
            return content.compactMap { part in
                if case .text(let text) = part { return text }
                return nil
            }
        case .other:
            return []
        }
    }.joined()
}
