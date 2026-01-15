import Foundation

public enum ModelRelayError: Error, Equatable {
    case invalidConfiguration(String)
    case invalidRequest(String)
    case transport(String)
    case apiError(status: Int, message: String?, requestId: String?)
    case decoding(String)
    case workflowValidation([WorkflowValidationIssue])
}

public struct APIErrorResponse: Decodable {
    public let error: APIErrorDetail?
}

public struct APIErrorDetail: Decodable {
    public let message: String?
    public let code: String?
    public let issues: [WorkflowValidationIssue]?
}

public struct WorkflowValidationIssue: Decodable, Equatable, Sendable {
    public let path: String?
    public let message: String?
}
