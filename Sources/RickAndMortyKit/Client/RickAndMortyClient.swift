import Foundation

/// A client for the free [Rick and Morty API](https://rickandmortyapi.com/documentation).
///
/// Every endpoint is an `async throws` method that returns typed models: characters, locations
/// and episodes one by one, several by id, or a page at a time with filters. Page sequences walk
/// every page for you, and the resource URLs inside a model (a character's episodes, a location's
/// residents) resolve with one request.
///
/// ```swift
/// let api = RickAndMortyClient()
/// let rick = try await api.character(id: 1)
/// let page = try await api.characters(filter: CharacterFilter(name: "rick", status: .alive))
/// let episodes = try await api.episodes(of: rick)          // [RMEpisode]
///
/// for try await episode in api.allEpisodes() {
///     print(episode.codeString, episode.name)              // "S01E01 Pilot"
/// }
/// ```
///
/// One client can be shared by the whole app; it is `Sendable` and keeps no per-request state.
public final class RickAndMortyClient: Sendable {
    /// A client with the default configuration.
    public static let shared = RickAndMortyClient()

    /// The most ids sent in one multiple-resource request; longer lists are split.
    public static let maxIDsPerRequest = 100

    public let configuration: RickAndMortyConfiguration

    public init(configuration: RickAndMortyConfiguration = RickAndMortyConfiguration()) {
        self.configuration = configuration
    }

    /// A client using `session`, with the default settings otherwise.
    public convenience init(session: URLSession) {
        self.init(configuration: RickAndMortyConfiguration(session: session))
    }

    // MARK: - Characters

    /// One page of characters, 20 per page, optionally filtered (`/character/?page=&name=…`).
    /// Returns an empty page when the filter matches nothing or the page is past the end.
    public func characters(page: Int = 1, filter: CharacterFilter = CharacterFilter()) async throws -> Page<RMCharacter> {
        try await list(.character, page: page, query: filter.queryItems)
    }

    /// A character (`/character/:id`).
    public func character(id: Int) async throws -> RMCharacter {
        try await get(ResourceKind.character.path + "/" + String(id))
    }

    /// Several characters by id (`/character/1,2,3`), in the order of `ids`. Ids the API doesn't
    /// know are left out; duplicates are fetched once.
    public func characters(ids: [Int]) async throws -> [RMCharacter] {
        try await many(.character, ids: ids)
    }

    /// Every page of characters matching `filter`, loaded as you iterate.
    public func characterPages(filter: CharacterFilter = CharacterFilter(), startingAt page: Int = 1) -> PageSequence<RMCharacter> {
        PageSequence(startingAt: page) { [self] number in
            try await self.characters(page: number, filter: filter)
        }
    }

    /// Every character matching `filter`, one by one, loading pages as you iterate.
    public func allCharacters(filter: CharacterFilter = CharacterFilter()) -> PagedItems<RMCharacter> {
        characterPages(filter: filter).items
    }

    // MARK: - Locations

    /// One page of locations, optionally filtered (`/location/?page=&name=&type=&dimension=`).
    /// Returns an empty page when the filter matches nothing or the page is past the end.
    public func locations(page: Int = 1, filter: LocationFilter = LocationFilter()) async throws -> Page<RMLocation> {
        try await list(.location, page: page, query: filter.queryItems)
    }

    /// A location (`/location/:id`).
    public func location(id: Int) async throws -> RMLocation {
        try await get(ResourceKind.location.path + "/" + String(id))
    }

    /// Several locations by id (`/location/1,2,3`), in the order of `ids`.
    public func locations(ids: [Int]) async throws -> [RMLocation] {
        try await many(.location, ids: ids)
    }

    /// Every page of locations matching `filter`.
    public func locationPages(filter: LocationFilter = LocationFilter(), startingAt page: Int = 1) -> PageSequence<RMLocation> {
        PageSequence(startingAt: page) { [self] number in
            try await self.locations(page: number, filter: filter)
        }
    }

    /// Every location matching `filter`, one by one.
    public func allLocations(filter: LocationFilter = LocationFilter()) -> PagedItems<RMLocation> {
        locationPages(filter: filter).items
    }

    // MARK: - Episodes

    /// One page of episodes, optionally filtered (`/episode/?page=&name=&episode=`).
    /// Returns an empty page when the filter matches nothing or the page is past the end.
    public func episodes(page: Int = 1, filter: EpisodeFilter = EpisodeFilter()) async throws -> Page<RMEpisode> {
        try await list(.episode, page: page, query: filter.queryItems)
    }

    /// An episode (`/episode/:id`).
    public func episode(id: Int) async throws -> RMEpisode {
        try await get(ResourceKind.episode.path + "/" + String(id))
    }

    /// Several episodes by id (`/episode/1,2,3`), in the order of `ids`.
    public func episodes(ids: [Int]) async throws -> [RMEpisode] {
        try await many(.episode, ids: ids)
    }

    /// Every page of episodes matching `filter`.
    public func episodePages(filter: EpisodeFilter = EpisodeFilter(), startingAt page: Int = 1) -> PageSequence<RMEpisode> {
        PageSequence(startingAt: page) { [self] number in
            try await self.episodes(page: number, filter: filter)
        }
    }

    /// Every episode matching `filter`, one by one.
    public func allEpisodes(filter: EpisodeFilter = EpisodeFilter()) -> PagedItems<RMEpisode> {
        episodePages(filter: filter).items
    }

    // MARK: - Resolving resource URLs

    /// The episodes a character appears in, in one request.
    public func episodes(of character: RMCharacter) async throws -> [RMEpisode] {
        try await episodes(ids: character.episodeIDs)
    }

    /// The characters in an episode, in one request.
    public func characters(in episode: RMEpisode) async throws -> [RMCharacter] {
        try await characters(ids: episode.characterIDs)
    }

    /// The characters last seen at a location, in one request.
    public func residents(of location: RMLocation) async throws -> [RMCharacter] {
        try await characters(ids: location.residentIDs)
    }

    /// The location a reference points to (a character's `origin` or `location`), or `nil` when
    /// it is unknown.
    public func location(_ reference: LocationReference) async throws -> RMLocation? {
        guard let id = reference.id else { return nil }
        return try await location(id: id)
    }

    /// The characters behind a list of character URLs.
    public func characters(at urls: [URL]) async throws -> [RMCharacter] {
        try await characters(ids: ResourceURL.ids(urls))
    }

    /// The episodes behind a list of episode URLs.
    public func episodes(at urls: [URL]) async throws -> [RMEpisode] {
        try await episodes(ids: ResourceURL.ids(urls))
    }

    /// The locations behind a list of location URLs.
    public func locations(at urls: [URL]) async throws -> [RMLocation] {
        try await locations(ids: ResourceURL.ids(urls))
    }

    /// Fetches any API URL, such as a `url` field or a page's `next`, and decodes it. URLs below
    /// `…/api/` are requested from this client's base URL.
    public func resource<Value: Decodable>(at url: URL, as type: Value.Type = Value.self) async throws -> Value {
        if let path = ResourceURL.relativePath(url) {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            return try await get(path, query: components?.queryItems ?? [])
        }
        return try await decode(Value.self, from: data(for: makeRequest(url: url)))
    }

    // MARK: - Requests

    /// Builds the request for a path below the base URL. Exposed for tests and debugging.
    public func request(path: String, query: [URLQueryItem] = []) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw RickAndMortyError.transport(URLError(.badURL))
        }
        if !query.isEmpty {
            components.queryItems = query
            // URLComponents leaves "+" as is, but servers read it as a space.
            components.percentEncodedQuery = components.percentEncodedQuery?
                .replacingOccurrences(of: "+", with: "%2B")
        }
        guard let finalURL = components.url else {
            throw RickAndMortyError.transport(URLError(.badURL))
        }
        return makeRequest(url: finalURL)
    }

    /// Fetches and decodes a path below the base URL. Use it for anything this client has no
    /// method for.
    public func get<Value: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: Value.Type = Value.self) async throws -> Value {
        try await decode(Value.self, from: data(for: request(path: path, query: query)))
    }

    func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url, timeoutInterval: configuration.timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let userAgent = configuration.userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        return request
    }

    func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try JSONDecoder().decode(Value.self, from: data)
        } catch {
            throw RickAndMortyError.decoding(type: String(describing: Value.self), description: String(describing: error))
        }
    }

    /// A page of a list; an empty page for the API's 404 "There is nothing here".
    func list<Item: Decodable & Sendable>(_ kind: ResourceKind, page: Int, query: [URLQueryItem]) async throws -> Page<Item> {
        let items = [URLQueryItem(name: "page", value: String(max(1, page)))] + query
        do {
            let result: Page<Item> = try await get(kind.path, query: items)
            return result
        } catch RickAndMortyError.notFound {
            return Page(info: .empty, results: [])
        }
    }

    /// Several resources by id. The API answers an array for several ids and an object for one;
    /// both are read. The result follows the order of `ids`.
    func many<Item: Decodable & Identifiable & Sendable>(_ kind: ResourceKind, ids: [Int]) async throws -> [Item] where Item.ID == Int {
        var seen = Set<Int>()
        let unique = ids.filter { $0 > 0 && seen.insert($0).inserted }
        guard !unique.isEmpty else { return [] }

        var found: [Int: Item] = [:]
        var start = 0
        while start < unique.count {
            let end = min(start + RickAndMortyClient.maxIDsPerRequest, unique.count)
            let chunk = unique[start..<end]
            start = end
            let path = kind.path + "/" + chunk.map { String($0) }.joined(separator: ",")
            let body: Data
            do {
                body = try await data(for: request(path: path))
            } catch RickAndMortyError.notFound {
                // A single unknown id is a 404; several unknown ids are an empty array.
                continue
            }
            let items = try decode(OneOrMany<Item>.self, from: body).items
            for item in items {
                found[item.id] = item
            }
        }
        return unique.compactMap { found[$0] }
    }

    /// Sends a request and maps transport failures; any HTTP status is returned.
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let result: (Data, URLResponse)
        do {
            result = try await configuration.session.data(for: request)
        } catch let error as URLError {
            throw RickAndMortyError.transport(error)
        }
        guard let http = result.1 as? HTTPURLResponse else {
            throw RickAndMortyError.invalidResponse
        }
        return (result.0, http)
    }

    /// Performs a request and returns the body of a successful response; other statuses throw
    /// with the API's error message.
    func data(for request: URLRequest) async throws -> Data {
        let (data, http) = try await send(request)
        let url = request.url ?? configuration.baseURL
        switch http.statusCode {
        case 200..<300:
            return data
        case 404:
            throw RickAndMortyError.notFound(message: Self.errorMessage(in: data), url: url)
        default:
            throw RickAndMortyError.http(statusCode: http.statusCode, message: Self.errorMessage(in: data), url: url)
        }
    }

    /// The `error` of an error body such as `{"error":"Character not found"}`.
    static func errorMessage(in data: Data) -> String? {
        (try? JSONDecoder().decode(APIErrorBody.self, from: data))?.error
    }
}

/// The three resources of the API.
public enum ResourceKind: String, CaseIterable, Sendable {
    case character
    case location
    case episode

    /// The path below the base URL: `"character"`, `"location"` or `"episode"`.
    public var path: String {
        rawValue
    }
}

/// A JSON array of items, or a single item.
struct OneOrMany<Item: Decodable>: Decodable {
    let items: [Item]

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let many = try? container.decode([Item].self) {
            items = many
        } else {
            items = try [container.decode(Item.self)]
        }
    }
}
