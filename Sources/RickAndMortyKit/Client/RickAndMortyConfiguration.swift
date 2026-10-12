import Foundation

/// Settings of a ``RickAndMortyClient``.
public struct RickAndMortyConfiguration: Sendable {
    /// `https://rickandmortyapi.com/api`.
    public static let defaultBaseURL = URL(string: "https://rickandmortyapi.com/api")!

    /// Where REST requests go: the folder that contains `character`, `location` and `episode`.
    /// Change it to point at a proxy or a local stub server.
    public var baseURL: URL
    /// The GraphQL endpoint. By default `graphql` next to the REST folder
    /// (`https://rickandmortyapi.com/graphql`).
    public var graphQLURL: URL
    /// The session that performs requests. Give it a `URLProtocol` subclass to stub responses.
    public var session: URLSession
    /// Sent as `User-Agent`, so the API's maintainers can tell where traffic comes from.
    public var userAgent: String?
    /// The request timeout in seconds.
    public var timeout: TimeInterval

    public init(
        baseURL: URL = RickAndMortyConfiguration.defaultBaseURL,
        graphQLURL: URL? = nil,
        session: URLSession = .shared,
        userAgent: String? = "RickAndMortyKit (+https://github.com/halilozel1903/RickAndMortyKit)",
        timeout: TimeInterval = 20
    ) {
        self.baseURL = baseURL
        self.graphQLURL = graphQLURL ?? baseURL.deletingLastPathComponent().appendingPathComponent("graphql")
        self.session = session
        self.userAgent = userAgent
        self.timeout = timeout
    }
}
