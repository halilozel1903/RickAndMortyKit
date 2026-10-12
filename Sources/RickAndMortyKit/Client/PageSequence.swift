import Foundation

/// The pages of a list endpoint, loaded one at a time as you iterate, following `info.next`
/// until the last page.
///
/// ```swift
/// for try await page in client.characterPages(filter: CharacterFilter(status: .dead)) {
///     print("page \(page.number) of \(page.info.pages)", page.results.count)
/// }
/// ```
///
/// The sequence asks for the next page number on the client's own base URL, so it works the same
/// behind a proxy or a stub. It stops at the first empty page (a filter that matches nothing).
public struct PageSequence<Item: Sendable>: AsyncSequence, Sendable {
    public typealias Element = Page<Item>

    private let firstPage: Int
    private let load: @Sendable (Int) async throws -> Page<Item>

    /// - Parameters:
    ///   - firstPage: The page to start from.
    ///   - load: Loads one page by number.
    public init(startingAt firstPage: Int = 1, load: @escaping @Sendable (Int) async throws -> Page<Item>) {
        self.firstPage = max(1, firstPage)
        self.load = load
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(nextPage: firstPage, load: load)
    }

    /// The items of every page, one by one.
    ///
    /// ```swift
    /// for try await character in client.characterPages().items { … }
    /// ```
    public var items: PagedItems<Item> {
        PagedItems(pages: self)
    }

    /// Loads every page and returns all their items.
    public func collect() async throws -> [Item] {
        var all: [Item] = []
        for try await page in self {
            all.append(contentsOf: page.results)
        }
        return all
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var nextPage: Int?
        private let load: @Sendable (Int) async throws -> Page<Item>

        init(nextPage: Int?, load: @escaping @Sendable (Int) async throws -> Page<Item>) {
            self.nextPage = nextPage
            self.load = load
        }

        public mutating func next() async throws -> Page<Item>? {
            guard let number = nextPage else { return nil }
            try Task.checkCancellation()
            let page: Page<Item>
            do {
                page = try await load(number)
            } catch {
                nextPage = nil
                throw error
            }
            // Stop at the end, and never go back or loop on a page already seen.
            if let following = page.info.nextPage, following > number {
                nextPage = following
            } else {
                nextPage = nil
            }
            if page.results.isEmpty {
                nextPage = nil
                return nil
            }
            return page
        }
    }
}

/// Every item of a ``PageSequence``, loading the next page when the previous one is used up.
///
/// ```swift
/// for try await episode in client.allEpisodes() {
///     print(episode.codeString, episode.name)
/// }
/// ```
public struct PagedItems<Item: Sendable>: AsyncSequence, Sendable {
    public typealias Element = Item

    public let pages: PageSequence<Item>

    public init(pages: PageSequence<Item>) {
        self.pages = pages
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(pages: pages.makeAsyncIterator())
    }

    /// Loads every page and returns all the items.
    public func collect() async throws -> [Item] {
        try await pages.collect()
    }

    public struct AsyncIterator: AsyncIteratorProtocol {
        private var pages: PageSequence<Item>.AsyncIterator
        private var buffer: [Item] = []
        private var index = 0

        init(pages: PageSequence<Item>.AsyncIterator) {
            self.pages = pages
        }

        public mutating func next() async throws -> Item? {
            while index >= buffer.count {
                guard let page = try await pages.next() else { return nil }
                buffer = page.results
                index = 0
            }
            let item = buffer[index]
            index += 1
            return item
        }
    }
}
