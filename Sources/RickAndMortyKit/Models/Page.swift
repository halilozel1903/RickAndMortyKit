import Foundation

/// One page of a list endpoint: up to 20 results and where the list goes on.
///
/// ```json
/// {
///   "info": { "count": 826, "pages": 42,
///             "next": "https://rickandmortyapi.com/api/character/?page=2", "prev": null },
///   "results": [ … ]
/// }
/// ```
public struct Page<Item: Sendable>: Sendable {
    public var info: PageInfo
    public var results: [Item]

    public init(info: PageInfo, results: [Item]) {
        self.info = info
        self.results = results
    }

    /// A page with no results, what a filter that matches nothing returns.
    public static var empty: Page<Item> {
        Page(info: .empty, results: [])
    }

    /// This page's number, worked out from its neighbours (`1` for a single page).
    public var number: Int {
        if let previous = info.previousPage {
            return previous + 1
        }
        if let next = info.nextPage {
            return next - 1
        }
        return info.pages == 0 ? 0 : 1
    }

    /// Whether there is a page after this one.
    public var hasNextPage: Bool {
        info.nextPage != nil
    }

    /// Whether the list has no results at all.
    public var isEmpty: Bool {
        results.isEmpty
    }

    enum CodingKeys: String, CodingKey {
        case info, results
    }
}

extension Page: Equatable where Item: Equatable {}
extension Page: Hashable where Item: Hashable {}

extension Page: Decodable where Item: Decodable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        info = try container.decode(PageInfo.self, forKey: .info)
        results = try container.decodeIfPresent([Item].self, forKey: .results) ?? []
    }
}

extension Page: Encodable where Item: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(info, forKey: .info)
        try container.encode(results, forKey: .results)
    }
}

/// The `info` of a page: how many results the whole list has, how many pages, and the
/// neighbouring pages' URLs.
public struct PageInfo: Hashable, Sendable, Codable {
    /// Results in the whole list, on every page.
    public var count: Int
    /// Pages in the list.
    public var pages: Int
    /// The next page's URL, `nil` on the last page.
    public var next: URL?
    /// The previous page's URL, `nil` on the first page.
    public var prev: URL?

    public init(count: Int, pages: Int, next: URL? = nil, prev: URL? = nil) {
        self.count = count
        self.pages = pages
        self.next = next
        self.prev = prev
    }

    /// No results, no pages.
    public static let empty = PageInfo(count: 0, pages: 0)

    /// The next page's number, read from ``next``.
    public var nextPage: Int? {
        next.flatMap { PageInfo.pageNumber(in: $0) }
    }

    /// The previous page's number, read from ``prev``.
    public var previousPage: Int? {
        prev.flatMap { PageInfo.pageNumber(in: $0) }
    }

    /// The `page` query value of a URL.
    public static func pageNumber(in url: URL) -> Int? {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        return components?.queryItems?.first(where: { $0.name == "page" })?.value.flatMap { Int($0) }
    }

    enum CodingKeys: String, CodingKey {
        case count, pages, next, prev
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        count = try container.decodeIfPresent(Int.self, forKey: .count) ?? 0
        pages = try container.decodeIfPresent(Int.self, forKey: .pages) ?? 0
        next = try container.decodeLenientURL(forKey: .next)
        prev = try container.decodeLenientURL(forKey: .prev)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(count, forKey: .count)
        try container.encode(pages, forKey: .pages)
        try container.encode(next?.absoluteString, forKey: .next)
        try container.encode(prev?.absoluteString, forKey: .prev)
    }
}
