import Foundation

public struct WrapperV1Page: Codable {
    public let cursor: String?
    public let limit: Int?

    public init(cursor: String? = nil, limit: Int? = nil) {
        self.cursor = cursor
        self.limit = limit
    }
}

public struct WrapperV1SearchRequest: Codable {
    public let query: String
    public let filters: [String: JSONValue]?
    public let page: WrapperV1Page?

    public init(query: String, filters: [String: JSONValue]? = nil, page: WrapperV1Page? = nil) {
        self.query = query
        self.filters = filters
        self.page = page
    }
}

public struct WrapperV1Item: Codable {
    public let id: String
    public let title: String?
    public let type: String?
    public let snippet: String?
    public let updatedAt: String?
    public let sourceURL: String?
    public let metadata: [String: JSONValue]?

    public init(
        id: String,
        title: String? = nil,
        type: String? = nil,
        snippet: String? = nil,
        updatedAt: String? = nil,
        sourceURL: String? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.snippet = snippet
        self.updatedAt = updatedAt
        self.sourceURL = sourceURL
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case snippet
        case updatedAt = "updated_at"
        case sourceURL = "source_url"
        case metadata
    }
}

public struct WrapperV1SearchResponse: Codable {
    public let items: [WrapperV1Item]
    public let nextCursor: String?

    public init(items: [WrapperV1Item], nextCursor: String? = nil) {
        self.items = items
        self.nextCursor = nextCursor
    }

    enum CodingKeys: String, CodingKey {
        case items
        case nextCursor = "next_cursor"
    }
}

public struct WrapperV1GetRequest: Codable {
    public let id: String

    public init(id: String) {
        self.id = id
    }
}

public struct WrapperV1GetResponse: Codable {
    public let id: String
    public let title: String?
    public let type: String?
    public let updatedAt: String?
    public let sizeBytes: Int?
    public let mimeType: String?
    public let metadata: [String: JSONValue]?

    public init(
        id: String,
        title: String? = nil,
        type: String? = nil,
        updatedAt: String? = nil,
        sizeBytes: Int? = nil,
        mimeType: String? = nil,
        metadata: [String: JSONValue]? = nil
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.updatedAt = updatedAt
        self.sizeBytes = sizeBytes
        self.mimeType = mimeType
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case updatedAt = "updated_at"
        case sizeBytes = "size_bytes"
        case mimeType = "mime_type"
        case metadata
    }
}

public struct WrapperV1ContentRequest: Codable {
    public let id: String
    public let format: String?
    public let maxBytes: Int?

    public init(id: String, format: String? = nil, maxBytes: Int? = nil) {
        self.id = id
        self.format = format
        self.maxBytes = maxBytes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case format
        case maxBytes = "max_bytes"
    }
}

public struct WrapperV1ContentResponse: Codable {
    public let id: String
    public let format: String?
    public let content: String
    public let truncated: Bool?

    public init(id: String, format: String? = nil, content: String, truncated: Bool? = nil) {
        self.id = id
        self.format = format
        self.content = content
        self.truncated = truncated
    }
}

public struct WrapperV1ErrorBody: Codable {
    public let code: String
    public let message: String
    public let retryAfterMs: Int?

    public init(code: String, message: String, retryAfterMs: Int? = nil) {
        self.code = code
        self.message = message
        self.retryAfterMs = retryAfterMs
    }

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case retryAfterMs = "retry_after_ms"
    }
}

public struct WrapperV1ErrorResponse: Codable {
    public let error: WrapperV1ErrorBody

    public init(error: WrapperV1ErrorBody) {
        self.error = error
    }
}

public struct WrapperV1ValidationError: Error {
    public let message: String

    public init(message: String) {
        self.message = message
    }
}

public enum WrapperV1Validator {
    public static func validate(_ response: WrapperV1SearchResponse) throws {
        for (idx, item) in response.items.enumerated() {
            if item.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw WrapperV1ValidationError(message: "items[\(idx)].id is required")
            }
        }
    }

    public static func validate(_ response: WrapperV1GetResponse) throws {
        if response.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw WrapperV1ValidationError(message: "id is required")
        }
    }

    public static func validate(_ response: WrapperV1ContentResponse) throws {
        if response.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw WrapperV1ValidationError(message: "id is required")
        }
    }

    public static func validate(_ response: WrapperV1ErrorResponse) throws {
        if response.error.code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw WrapperV1ValidationError(message: "error.code is required")
        }
        if response.error.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw WrapperV1ValidationError(message: "error.message is required")
        }
    }
}
