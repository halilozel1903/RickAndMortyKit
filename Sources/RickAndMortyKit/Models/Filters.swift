import Foundation

/// Filters for `/character`. Every filter that is set must match; `nil` or blank filters are not
/// sent. Text filters match anywhere in the value, ignoring case.
///
/// ```swift
/// CharacterFilter(name: "rick", status: .alive)          // ?name=rick&status=alive
/// CharacterFilter(species: "Alien", gender: .genderless) // ?species=Alien&gender=genderless
/// ```
public struct CharacterFilter: Hashable, Sendable {
    public var name: String?
    public var status: CharacterStatus?
    public var species: String?
    public var type: String?
    public var gender: CharacterGender?

    public init(
        name: String? = nil,
        status: CharacterStatus? = nil,
        species: String? = nil,
        type: String? = nil,
        gender: CharacterGender? = nil
    ) {
        self.name = name
        self.status = status
        self.species = species
        self.type = type
        self.gender = gender
    }

    /// The query items, in the API's documented order.
    public var queryItems: [URLQueryItem] {
        FilterQuery.items([
            ("name", name),
            ("status", status?.queryValue),
            ("species", species),
            ("type", type),
            ("gender", gender?.queryValue),
        ])
    }

    /// Whether no filter is set.
    public var isEmpty: Bool {
        queryItems.isEmpty
    }
}

/// Filters for `/location`.
///
/// ```swift
/// LocationFilter(type: "Planet", dimension: "C-137")
/// ```
public struct LocationFilter: Hashable, Sendable {
    public var name: String?
    public var type: String?
    public var dimension: String?

    public init(name: String? = nil, type: String? = nil, dimension: String? = nil) {
        self.name = name
        self.type = type
        self.dimension = dimension
    }

    public var queryItems: [URLQueryItem] {
        FilterQuery.items([
            ("name", name),
            ("type", type),
            ("dimension", dimension),
        ])
    }

    public var isEmpty: Bool {
        queryItems.isEmpty
    }
}

/// Filters for `/episode`. `episode` matches the code: `"S01E01"` for one episode, `"S01"` for a
/// whole season.
///
/// ```swift
/// EpisodeFilter(name: "rick")
/// EpisodeFilter(season: 3)                                  // ?episode=S03
/// EpisodeFilter(code: EpisodeCode(season: 1, episode: 5))   // ?episode=S01E05
/// ```
public struct EpisodeFilter: Hashable, Sendable {
    public var name: String?
    /// All or part of an episode code.
    public var episode: String?

    public init(name: String? = nil, episode: String? = nil) {
        self.name = name
        self.episode = episode
    }

    /// Every episode of a season.
    public init(name: String? = nil, season: Int) {
        self.init(name: name, episode: "S" + EpisodeCode.pad(season))
    }

    /// One episode, by its code.
    public init(name: String? = nil, code: EpisodeCode) {
        self.init(name: name, episode: code.description)
    }

    public var queryItems: [URLQueryItem] {
        FilterQuery.items([
            ("name", name),
            ("episode", episode),
        ])
    }

    public var isEmpty: Bool {
        queryItems.isEmpty
    }
}

enum FilterQuery {
    /// Query items for the values that are set and not blank, trimmed.
    static func items(_ pairs: [(String, String?)]) -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        for (name, value) in pairs {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                continue
            }
            items.append(URLQueryItem(name: name, value: trimmed))
        }
        return items
    }
}
