import Foundation
import RickAndMortyKit
import RickAndMortyUI

/// Recorded responses for the screenshot scenes, so CI never depends on the network. The JSON is
/// hand-written in the API's exact shapes; the avatars are abstract artwork generated for the demo
/// (`Artwork/avatar-<id>.jpg`), not the show's.
enum DemoFixtures {
    /// A client whose requests are answered from `Fixtures/*.json` in the app bundle.
    static func makeClient() -> RickAndMortyClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FixtureURLProtocol.self]
        return RickAndMortyClient(configuration: RickAndMortyConfiguration(session: URLSession(configuration: configuration)))
    }

    /// Loads `…/character/avatar/<id>.jpeg` from the bundled artwork, and everything else from the
    /// network.
    static let imageLoader = RickAndMortyImageLoader { url in
        if url.path.contains("/character/avatar/") {
            let id = url.deletingPathExtension().lastPathComponent
            guard let file = Bundle.main.url(forResource: "avatar-" + id, withExtension: "jpg") else {
                throw URLError(.fileDoesNotExist)
            }
            return try Data(contentsOf: file)
        }
        return try await RickAndMortyImageLoader.urlSession.data(for: url)
    }
}

/// The bundled fixtures, indexed by resource and id, serialized back to JSON per object.
struct FixtureLibrary: Sendable {
    static let shared = FixtureLibrary()

    /// `"character-1"`, `"episode-2"`… for list pages.
    private let pages: [String: Data]
    /// Single objects by resource name and id.
    private let objects: [String: [Int: Data]]

    init() {
        var pages: [String: Data] = [:]
        var objects: [String: [Int: Data]] = [:]
        let files: [(file: String, resource: String, page: Int?)] = [
            ("characters-page-1", "character", 1),
            ("episodes-page-1", "episode", 1),
            ("episodes-page-2", "episode", 2),
            ("episodes-page-3", "episode", 3),
            ("locations-page-1", "location", 1),
            ("locations-extra", "location", nil),
        ]
        for entry in files {
            guard let url = Bundle.main.url(forResource: entry.file, withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let json = try? JSONSerialization.jsonObject(with: data)
            else { continue }
            if let page = entry.page {
                pages[entry.resource + "-" + String(page)] = data
            }
            let results: [Any]
            if let object = json as? [String: Any] {
                results = object["results"] as? [Any] ?? []
            } else {
                results = json as? [Any] ?? []
            }
            for case let item as [String: Any] in results {
                guard let id = item["id"] as? Int,
                      let itemData = try? JSONSerialization.data(withJSONObject: item)
                else { continue }
                objects[entry.resource, default: [:]][id] = itemData
            }
        }
        self.pages = pages
        self.objects = objects
    }

    /// The status and body the API would answer for a URL.
    func response(for url: URL) -> (status: Int, body: Data) {
        let parts = url.pathComponents.filter { $0 != "/" }
        guard let apiIndex = parts.firstIndex(of: "api"), apiIndex + 1 < parts.count else {
            return Self.error(404, "There is nothing here")
        }
        let resource = parts[apiIndex + 1]
        let rest = Array(parts[(apiIndex + 2)...])

        if rest.isEmpty {
            // A list page. The filters are ignored: the scenes don't filter.
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let page = components?.queryItems?.first(where: { $0.name == "page" })?.value ?? "1"
            if let data = pages[resource + "-" + page] {
                return (200, data)
            }
            return Self.error(404, "There is nothing here")
        }

        let idList = rest[0]
        let ids = idList.split(separator: ",").compactMap { Int($0) }
        let pool = objects[resource] ?? [:]
        if !idList.contains(",") {
            guard let id = ids.first, let data = pool[id] else {
                return Self.error(404, resource.prefix(1).uppercased() + resource.dropFirst() + " not found")
            }
            return (200, data)
        }
        let found = ids.compactMap { pool[$0] }
        var body = Data("[".utf8)
        for (index, item) in found.enumerated() {
            if index > 0 { body.append(contentsOf: Array(",".utf8)) }
            body.append(item)
        }
        body.append(contentsOf: Array("]".utf8))
        return (200, body)
    }

    private static func error(_ status: Int, _ message: String) -> (status: Int, body: Data) {
        let body = (try? JSONSerialization.data(withJSONObject: ["error": message])) ?? Data()
        return (status, body)
    }
}

/// Serves the bundled fixtures for API paths.
final class FixtureURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        let answer = FixtureLibrary.shared.response(for: url)
        let response = HTTPURLResponse(
            url: url,
            statusCode: answer.status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: answer.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
