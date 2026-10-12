import Foundation
import Observation
import RickAndMortyKit

/// The app's data, all from one `RickAndMortyClient` on the live API: paged character and
/// location lists, every episode, and caches for the pages you open.
@Observable
@MainActor
final class Multiverse {
    let client: RickAndMortyClient
    /// The character list of the grid (iPhone) and the content column (iPad).
    let characters: PagedList<RMCharacter, CharacterFilter>
    /// The location list.
    let locations: PagedList<RMLocation, LocationFilter>

    /// Every episode, loaded once (three pages).
    private(set) var episodes: [RMEpisode] = []
    private(set) var episodesError: String?

    @ObservationIgnored private var characterCache: [Int: RMCharacter] = [:]
    @ObservationIgnored private var locationCache: [Int: RMLocation] = [:]
    /// How many times a request is tried before the error is shown.
    private let attempts: Int

    init(client: RickAndMortyClient, attempts: Int = 1) {
        self.client = client
        let attempts = max(1, attempts)
        self.attempts = attempts
        characters = PagedList<RMCharacter, CharacterFilter> { page, filter in
            try await Multiverse.retrying(attempts: attempts) {
                try await client.characters(page: page, filter: filter)
            }
        }
        locations = PagedList<RMLocation, LocationFilter> { page, filter in
            try await Multiverse.retrying(attempts: attempts) {
                try await client.locations(page: page, filter: filter)
            }
        }
    }

    /// The live API. Screenshot scenes retry failed requests a few times, since a capture must not
    /// show an error.
    static func make(for scene: ScreenshotScene?) -> Multiverse {
        Multiverse(client: .shared, attempts: scene == nil ? 1 : 4)
    }

    /// Runs `operation`, trying again after a pause when it fails, up to `attempts` times.
    nonisolated static func retrying<T: Sendable>(
        attempts: Int,
        _ operation: @Sendable () async throws -> T
    ) async throws -> T {
        var attempt = 1
        while true {
            do {
                return try await operation()
            } catch {
                guard attempt < attempts, !Task.isCancelled else { throw error }
                print("Request failed (attempt \(attempt) of \(attempts)): \(error)")
                try await Task.sleep(for: .seconds(Double(attempt) * 2))
                attempt += 1
            }
        }
    }

    // MARK: - Characters

    func character(id: Int) async throws -> RMCharacter {
        if let cached = characterCache[id] ?? characters.items.first(where: { $0.id == id }) {
            return cached
        }
        let client = self.client
        let character = try await Self.retrying(attempts: attempts) {
            try await client.character(id: id)
        }
        characterCache[id] = character
        return character
    }

    /// The characters in an episode.
    func characters(in episode: RMEpisode) async throws -> [RMCharacter] {
        let client = self.client
        let found = try await Self.retrying(attempts: attempts) {
            try await client.characters(in: episode)
        }
        remember(found)
        return found
    }

    /// The characters last seen at a location.
    func residents(of location: RMLocation) async throws -> [RMCharacter] {
        let client = self.client
        let found = try await Self.retrying(attempts: attempts) {
            try await client.residents(of: location)
        }
        remember(found)
        return found
    }

    private func remember(_ found: [RMCharacter]) {
        for character in found {
            characterCache[character.id] = character
        }
    }

    // MARK: - Locations

    func location(id: Int) async throws -> RMLocation {
        if let cached = locationCache[id] ?? locations.items.first(where: { $0.id == id }) {
            return cached
        }
        let client = self.client
        let location = try await Self.retrying(attempts: attempts) {
            try await client.location(id: id)
        }
        locationCache[id] = location
        return location
    }

    /// The location behind a character's origin or last known location; `nil` when unknown.
    func location(_ reference: LocationReference) async throws -> RMLocation? {
        guard let id = reference.id else { return nil }
        return try await location(id: id)
    }

    // MARK: - Episodes

    /// Loads every episode, once.
    func loadEpisodes() async {
        guard episodes.isEmpty else { return }
        do {
            let client = self.client
            let all = try await Self.retrying(attempts: attempts) {
                try await client.allEpisodes().collect()
            }
            episodes = all
            episodesError = nil
        } catch {
            guard !Task.isCancelled else { return }
            episodesError = error.localizedDescription
        }
    }

    func episode(id: Int) async throws -> RMEpisode {
        if let known = episodes.first(where: { $0.id == id }) {
            return known
        }
        let client = self.client
        return try await Self.retrying(attempts: attempts) {
            try await client.episode(id: id)
        }
    }

    /// The episodes a character appears in: from the loaded list when it has them all, else in
    /// one request.
    func episodes(of character: RMCharacter) async throws -> [RMEpisode] {
        let ids = character.episodeIDs
        if !episodes.isEmpty {
            let byID = Dictionary(episodes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let found = ids.compactMap { byID[$0] }
            if found.count == ids.count {
                return found
            }
        }
        let client = self.client
        return try await Self.retrying(attempts: attempts) {
            try await client.episodes(of: character)
        }
    }
}

/// A paged, filtered list: the first page for a filter, then the next pages as the user scrolls.
@Observable
@MainActor
final class PagedList<Item: Identifiable & Sendable, Filter: Hashable & Sendable> {
    typealias Loader = @Sendable (Int, Filter) async throws -> Page<Item>

    private(set) var items: [Item] = []
    /// Results for the filter on every page, from the API's `info.count`.
    private(set) var total: Int?
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// The filter `items` belong to.
    private(set) var loadedFilter: Filter?

    @ObservationIgnored private var requestedFilter: Filter?
    @ObservationIgnored private var nextPage: Int?
    @ObservationIgnored private var isLoadingMore = false
    private let loader: Loader

    init(loader: @escaping Loader) {
        self.loader = loader
    }

    /// Shows the first page for `filter`, unless it is already shown (or `reload` is set). With
    /// `debounce`, waits for a pause in typing first; a newer call cancels the wait.
    func show(_ filter: Filter, debounce: Bool = false, reload: Bool = false) async {
        if !reload, filter == loadedFilter, errorMessage == nil {
            // Back to what is on screen: let a load for another filter finish unseen.
            requestedFilter = filter
            isLoading = false
            return
        }
        requestedFilter = filter
        if debounce {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, requestedFilter == filter else { return }
        }
        isLoading = true
        do {
            let page = try await loader(1, filter)
            guard requestedFilter == filter else { return }
            items = page.results
            total = page.info.count
            nextPage = page.info.nextPage
            hasMore = nextPage != nil
            errorMessage = nil
            loadedFilter = filter
            isLoading = false
        } catch {
            guard requestedFilter == filter else { return }
            isLoading = false
            // A cancelled load (the view went away) is retried the next time it appears.
            guard !Task.isCancelled else { return }
            items = []
            total = nil
            nextPage = nil
            hasMore = false
            errorMessage = error.localizedDescription
            loadedFilter = filter
        }
    }

    /// Loads the next page, if there is one.
    func loadMore() async {
        guard let page = nextPage, let filter = loadedFilter, requestedFilter == filter, !isLoadingMore else {
            return
        }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let next = try await loader(page, filter)
            guard loadedFilter == filter, requestedFilter == filter else { return }
            let known = Set(items.map(\.id))
            items.append(contentsOf: next.results.filter { !known.contains($0.id) })
            nextPage = next.info.nextPage
            hasMore = nextPage != nil
        } catch {
            // Scrolling to the end again retries.
        }
    }

    /// Whether `item` is the last loaded item, so the next page should load.
    func isLast(_ item: Item) -> Bool {
        items.last?.id == item.id
    }
}
