import Foundation

final class StubState: @unchecked Sendable {
    typealias Handler = (URLRequest) throws -> (HTTPURLResponse, Data)

    static let shared = StubState()

    private let lock = NSLock()
    private var handlers: [Handler] = []
    private var requests: [URLRequest] = []

    func reset() {
        lock.lock()
        handlers.removeAll()
        requests.removeAll()
        lock.unlock()
    }

    func enqueue(_ handler: @escaping Handler) {
        lock.lock()
        handlers.append(handler)
        lock.unlock()
    }

    func dequeue() throws -> Handler {
        lock.lock()
        defer { lock.unlock() }
        guard !handlers.isEmpty else {
            throw NSError(domain: "StubState", code: 0, userInfo: [NSLocalizedDescriptionKey: "No handler"])
        }
        return handlers.removeFirst()
    }

    func record(_ request: URLRequest) {
        lock.lock()
        requests.append(request)
        lock.unlock()
    }

    func allRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }
}

final class StubURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            let handler = try StubState.shared.dequeue()
            StubState.shared.record(request)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

func makeStubbedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    return URLSession(configuration: config)
}

func resetStubs() {
    StubState.shared.reset()
}

func enqueueStub(_ handler: @escaping StubState.Handler) {
    StubState.shared.enqueue(handler)
}

func stubRequests() -> [URLRequest] {
    StubState.shared.allRequests()
}
