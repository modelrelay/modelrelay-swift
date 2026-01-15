import Foundation

public struct AuthHeaders: Equatable {
    public let apiKey: String?
    public let accessToken: String?

    public init(apiKey: String? = nil, accessToken: String? = nil) {
        self.apiKey = apiKey
        self.accessToken = accessToken
    }
}
