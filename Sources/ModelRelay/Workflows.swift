import Foundation

public struct WorkflowsCompileOptions: Equatable {
    public let customerId: String?
    public let headers: [String: String]
    public let timeout: TimeInterval?
    public let retry: RetryConfig?

    public init(customerId: String? = nil, headers: [String: String] = [:], timeout: TimeInterval? = nil, retry: RetryConfig? = nil) {
        self.customerId = customerId
        self.headers = headers
        self.timeout = timeout
        self.retry = retry
    }
}

public enum WorkflowsCompileResult: Equatable {
    case success(planJson: JSONValue, planHash: PlanHash)
    case validationError([WorkflowValidationIssue])
    case internalError(status: Int, message: String?, code: String?, requestId: String?)
}

public struct WorkflowsClient {
    private let http: HTTPClient
    private let auth: AuthClient

    init(http: HTTPClient, auth: AuthClient) {
        self.http = http
        self.auth = auth
    }

    public func compile(spec: JSONValue, options: WorkflowsCompileOptions = WorkflowsCompileOptions()) async throws -> WorkflowsCompileResult {
        let authHeaders = try await auth.authForResponses()
        var headers = options.headers
        if let customerId = options.customerId?.trimmingCharacters(in: .whitespacesAndNewlines), !customerId.isEmpty {
            headers[customerIdHeader] = customerId
        }

        do {
            let response: WorkflowsCompileResponse = try await http.json(
                path: "/workflows/compile",
                method: "POST",
                body: spec,
                headers: headers,
                auth: authHeaders,
                timeout: options.timeout,
                retry: options.retry
            )
            return .success(planJson: response.planJson, planHash: response.planHash)
        } catch ModelRelayError.workflowValidation(let issues) {
            return .validationError(issues)
        } catch ModelRelayError.apiError(let status, let message, let requestId) {
            return .internalError(status: status, message: message, code: nil, requestId: requestId)
        }
    }
}

private struct WorkflowsCompileResponse: Decodable {
    let planJson: JSONValue
    let planHash: PlanHash

    private enum CodingKeys: String, CodingKey {
        case planJson = "plan_json"
        case planHash = "plan_hash"
    }
}
