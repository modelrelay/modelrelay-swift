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

    public func addFunction(name: ToolName, description: String? = nil, parameters: JSONValue? = nil) -> ToolBuilder {
        addFunction(name: name.rawValue, description: description, parameters: parameters)
    }
}

public enum ToolName: String, CaseIterable {
    case fsReadFile = "fs_read_file"
    case fsListFiles = "fs_list_files"
    case fsSearch = "fs_search"
    case fsEdit = "fs_edit"
    case bash = "bash"
    case writeFile = "write_file"
    case tasksWrite = "tasks_write"
    case kvWrite = "kv_write"
    case kvRead = "kv_read"
    case kvList = "kv_list"
    case kvDelete = "kv_delete"
    case memoryWrite = "memory_write"
    case webFetch = "web_fetch"
    case webSearch = "web_search"
    case userAsk = "user_ask"
    case executeSQL = "execute_sql"
    case listTables = "list_tables"
    case describeTable = "describe_table"
    case sampleRows = "sample_rows"
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
