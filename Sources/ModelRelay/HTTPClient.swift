import Foundation

struct HTTPClient {
    private let baseURL: URL
    private let clientHeaderValue: String
    private let defaultHeaders: [String: String]
    private let session: URLSession
    private let defaultTimeout: TimeInterval

    init(
        baseURL: URL,
        clientHeaderValue: String,
        defaultHeaders: [String: String],
        session: URLSession,
        defaultTimeout: TimeInterval
    ) {
        self.baseURL = baseURL
        self.clientHeaderValue = clientHeaderValue
        self.defaultHeaders = defaultHeaders
        self.session = session
        self.defaultTimeout = defaultTimeout
    }

    func json<T: Decodable>(
        path: String,
        method: String,
        body: Encodable?,
        headers: [String: String],
        auth: AuthHeaders,
        timeout: TimeInterval?,
        retry: RetryConfig?
    ) async throws -> T {
        let normalizedRetry = RetryPolicy(config: retry)
        var attempt = 0
        while true {
            attempt += 1
            let url = buildURL(path: path)
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.timeoutInterval = timeout ?? defaultTimeout

            var finalHeaders = defaultHeaders
            for (key, value) in headers {
                finalHeaders[key] = value
            }
            finalHeaders["Accept"] = finalHeaders["Accept"] ?? "application/json"
            if finalHeaders[clientHeader] == nil {
                finalHeaders[clientHeader] = clientHeaderValue
            }
            if let accessToken = auth.accessToken, !accessToken.isEmpty {
                let bearer = accessToken.lowercased().hasPrefix("bearer ") ? accessToken : "Bearer \(accessToken)"
                finalHeaders["Authorization"] = bearer
            }
            if let apiKey = auth.apiKey, !apiKey.isEmpty {
                finalHeaders[apiKeyHeader] = apiKey
            }

            if let body {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(AnyEncodable(body))
                finalHeaders["Content-Type"] = finalHeaders["Content-Type"] ?? "application/json"
            }

            for (key, value) in finalHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ModelRelayError.transport("invalid response")
                }

                if (200..<300).contains(httpResponse.statusCode) {
                    do {
                        let decoder = JSONDecoder()
                        decoder.dateDecodingStrategy = .iso8601
                        var decoded = try decoder.decode(T.self, from: data)
                        if var response = decoded as? Response {
                            response.requestId = httpResponse.value(forHTTPHeaderField: requestIdHeader)
                            decoded = response as! T
                        }
                        return decoded
                    } catch {
                        throw ModelRelayError.decoding("failed to decode response: \(error)")
                    }
                }

                let requestId = httpResponse.value(forHTTPHeaderField: requestIdHeader)
                let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                if let issues = apiError?.error?.issues, !issues.isEmpty {
                    throw ModelRelayError.workflowValidation(issues)
                }
                let message = apiError?.error?.message ?? String(data: data, encoding: .utf8)
                let error = ModelRelayError.apiError(status: httpResponse.statusCode, message: message?.isEmpty == false ? message : nil, requestId: requestId)
                if normalizedRetry.shouldRetry(statusCode: httpResponse.statusCode, method: method, attempt: attempt) {
                    try await Task.sleep(for: .milliseconds(normalizedRetry.backoffMs(for: attempt)))
                    continue
                }
                throw error
            } catch {
                if normalizedRetry.shouldRetry(error: error, method: method, attempt: attempt) {
                    try await Task.sleep(for: .milliseconds(normalizedRetry.backoffMs(for: attempt)))
                    continue
                }
                throw error
            }
        }
    }

    func stream(
        path: String,
        method: String,
        body: Encodable?,
        headers: [String: String],
        auth: AuthHeaders,
        timeout: TimeInterval?,
        retry: RetryConfig?
    ) async throws -> StreamResponse {
        _ = retry
        let url = buildURL(path: path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout ?? defaultTimeout

        var finalHeaders = defaultHeaders
        for (key, value) in headers {
            finalHeaders[key] = value
        }
        if finalHeaders[clientHeader] == nil {
            finalHeaders[clientHeader] = clientHeaderValue
        }
        if let accessToken = auth.accessToken, !accessToken.isEmpty {
            let bearer = accessToken.lowercased().hasPrefix("bearer ") ? accessToken : "Bearer \(accessToken)"
            finalHeaders["Authorization"] = bearer
        }
        if let apiKey = auth.apiKey, !apiKey.isEmpty {
            finalHeaders[apiKeyHeader] = apiKey
        }

        if let body {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(AnyEncodable(body))
            finalHeaders["Content-Type"] = finalHeaders["Content-Type"] ?? "application/json"
        }

        for (key, value) in finalHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ModelRelayError.transport("invalid response")
        }
        if !(200..<300).contains(httpResponse.statusCode) {
            let data = try await readAllBytes(bytes)
            let requestId = httpResponse.value(forHTTPHeaderField: requestIdHeader)
            let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
            let message = apiError?.error?.message ?? String(data: data, encoding: .utf8)
            throw ModelRelayError.apiError(status: httpResponse.statusCode, message: message?.isEmpty == false ? message : nil, requestId: requestId)
        }
        let requestId = httpResponse.value(forHTTPHeaderField: requestIdHeader)
        return StreamResponse(bytes: bytes, requestId: requestId)
    }

    func requestVoid(
        path: String,
        method: String,
        body: Encodable?,
        headers: [String: String],
        auth: AuthHeaders,
        timeout: TimeInterval?,
        retry: RetryConfig?
    ) async throws {
        let normalizedRetry = RetryPolicy(config: retry)
        var attempt = 0
        while true {
            attempt += 1
            let url = buildURL(path: path)
            var request = URLRequest(url: url)
            request.httpMethod = method
            request.timeoutInterval = timeout ?? defaultTimeout

            var finalHeaders = defaultHeaders
            for (key, value) in headers {
                finalHeaders[key] = value
            }
            if finalHeaders[clientHeader] == nil {
                finalHeaders[clientHeader] = clientHeaderValue
            }
            if let accessToken = auth.accessToken, !accessToken.isEmpty {
                let bearer = accessToken.lowercased().hasPrefix("bearer ") ? accessToken : "Bearer \(accessToken)"
                finalHeaders["Authorization"] = bearer
            }
            if let apiKey = auth.apiKey, !apiKey.isEmpty {
                finalHeaders[apiKeyHeader] = apiKey
            }
            if let body {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                request.httpBody = try encoder.encode(AnyEncodable(body))
                finalHeaders["Content-Type"] = finalHeaders["Content-Type"] ?? "application/json"
            }
            for (key, value) in finalHeaders {
                request.setValue(value, forHTTPHeaderField: key)
            }

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ModelRelayError.transport("invalid response")
                }
                if (200..<300).contains(httpResponse.statusCode) {
                    return
                }
                let requestId = httpResponse.value(forHTTPHeaderField: requestIdHeader)
                let apiError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
                if let issues = apiError?.error?.issues, !issues.isEmpty {
                    throw ModelRelayError.workflowValidation(issues)
                }
                let message = apiError?.error?.message ?? String(data: data, encoding: .utf8)
                let error = ModelRelayError.apiError(status: httpResponse.statusCode, message: message?.isEmpty == false ? message : nil, requestId: requestId)
                if normalizedRetry.shouldRetry(statusCode: httpResponse.statusCode, method: method, attempt: attempt) {
                    try await Task.sleep(for: .milliseconds(normalizedRetry.backoffMs(for: attempt)))
                    continue
                }
                throw error
            } catch {
                if normalizedRetry.shouldRetry(error: error, method: method, attempt: attempt) {
                    try await Task.sleep(for: .milliseconds(normalizedRetry.backoffMs(for: attempt)))
                    continue
                }
                throw error
            }
        }
    }
}

struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void

    init(_ value: Encodable) {
        self.encodeFunc = { encoder in
            try value.encode(to: encoder)
        }
    }

    func encode(to encoder: Encoder) throws {
        try encodeFunc(encoder)
    }
}

private struct RetryPolicy {
    let maxAttempts: Int
    let baseBackoffMs: Int
    let maxBackoffMs: Int
    let retryPost: Bool

    init(config: RetryConfig?) {
        self.maxAttempts = max(1, config?.maxAttempts ?? 3)
        self.baseBackoffMs = max(50, config?.baseBackoffMs ?? 200)
        self.maxBackoffMs = max(baseBackoffMs, config?.maxBackoffMs ?? 2000)
        self.retryPost = config?.retryPost ?? false
    }

    func shouldRetry(statusCode: Int, method: String, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        if method.uppercased() == "POST" && !retryPost { return false }
        return statusCode == 429 || (500...599).contains(statusCode)
    }

    func shouldRetry(error: Error, method: String, attempt: Int) -> Bool {
        guard attempt < maxAttempts else { return false }
        if method.uppercased() == "POST" && !retryPost { return false }
        if error is URLError { return true }
        if case ModelRelayError.transport = error { return true }
        return false
    }

    func backoffMs(for attempt: Int) -> Int {
        let exp = min(maxBackoffMs, baseBackoffMs * Int(pow(2.0, Double(attempt - 1))))
        let jitter = Int.random(in: 0...min(250, exp / 2))
        return exp + jitter
    }
}

struct StreamResponse {
    let bytes: URLSession.AsyncBytes
    let requestId: String?
}

private func readAllBytes(_ bytes: URLSession.AsyncBytes) async throws -> Data {
    var data = Data()
    for try await byte in bytes {
        data.append(byte)
    }
    return data
}

private extension HTTPClient {
    func buildURL(path: String) -> URL {
        if path.lowercased().hasPrefix("http://") || path.lowercased().hasPrefix("https://") {
            return URL(string: path) ?? baseURL
        }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return URL(string: trimmed, relativeTo: baseURL) ?? baseURL
    }
}
