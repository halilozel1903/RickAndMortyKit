import Foundation

/// An episode (`/episode`).
///
/// ```json
/// {
///   "id": 1, "name": "Pilot", "air_date": "December 2, 2013", "episode": "S01E01",
///   "characters": ["https://rickandmortyapi.com/api/character/1", …],
///   "url": "https://rickandmortyapi.com/api/episode/1",
///   "created": "2017-11-10T12:56:33.798Z"
/// }
/// ```
public struct RMEpisode: Identifiable, Hashable, Sendable, Codable {
    public var id: Int
    public var name: String
    /// The air date as the API writes it: `"December 2, 2013"`. See ``airDateValue``.
    public var airDate: String
    /// The episode code as the API writes it: `"S01E01"` (the API's `episode` field). See
    /// ``code``.
    public var codeString: String
    /// The characters in the episode (the API's `characters` field).
    public var characterURLs: [URL]
    /// The episode's own endpoint.
    public var url: URL?
    /// When the episode was added to the database.
    public var created: Date?

    public init(
        id: Int,
        name: String,
        airDate: String = "",
        codeString: String = "",
        characterURLs: [URL] = [],
        url: URL? = nil,
        created: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.airDate = airDate
        self.codeString = codeString
        self.characterURLs = characterURLs
        self.url = url
        self.created = created
    }

    /// The parsed episode code, such as season 1, episode 1 for `"S01E01"`.
    public var code: EpisodeCode? {
        EpisodeCode(codeString)
    }

    /// The season number, from the episode code.
    public var season: Int? {
        code?.season
    }

    /// The episode's number within its season, from the episode code.
    public var number: Int? {
        code?.episode
    }

    /// The air date as midnight UTC, or `nil` when the API's text can't be read.
    public var airDateValue: Date? {
        APIDate.airDate(from: airDate)
    }

    /// The ids of the characters in the episode, in the API's order.
    public var characterIDs: [Int] {
        ResourceURL.ids(characterURLs)
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case airDate = "air_date"
        case codeString = "episode"
        case characterURLs = "characters"
        case url, created
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        airDate = try container.decodeIfPresent(String.self, forKey: .airDate) ?? ""
        codeString = try container.decodeIfPresent(String.self, forKey: .codeString) ?? ""
        characterURLs = try container.decodeURLList(forKey: .characterURLs)
        url = try container.decodeLenientURL(forKey: .url)
        created = try container.decodeTimestamp(forKey: .created)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(airDate, forKey: .airDate)
        try container.encode(codeString, forKey: .codeString)
        try container.encodeURLList(characterURLs, forKey: .characterURLs)
        try container.encodeLenientURL(url, forKey: .url)
        try container.encodeTimestamp(created, forKey: .created)
    }
}

/// A season and episode number, written `S01E01`.
///
/// ```swift
/// let code = EpisodeCode("S03E07")       // season 3, episode 7
/// code?.description                      // "S03E07"
/// EpisodeCode(season: 1, episode: 10).seasonCode   // "S01"
/// ```
public struct EpisodeCode: Hashable, Comparable, Sendable, Codable, LosslessStringConvertible {
    public var season: Int
    public var episode: Int

    public init(season: Int, episode: Int) {
        self.season = season
        self.episode = episode
    }

    /// Parses `"S01E01"`, in any case and with any number of digits (`"s1e1"`, `"S10E120"`).
    /// Returns `nil` for anything else.
    public init?(_ description: String) {
        let text = description.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard text.hasPrefix("S"), let separator = text.firstIndex(of: "E") else {
            return nil
        }
        let seasonDigits = text[text.index(after: text.startIndex)..<separator]
        let episodeDigits = text[text.index(after: separator)...]
        guard !seasonDigits.isEmpty, !episodeDigits.isEmpty,
              seasonDigits.allSatisfy({ $0.isASCII && $0.isNumber }),
              episodeDigits.allSatisfy({ $0.isASCII && $0.isNumber }),
              let season = Int(seasonDigits), let episode = Int(episodeDigits)
        else {
            return nil
        }
        self.init(season: season, episode: episode)
    }

    /// `"S01E01"`: two digits at least for each number.
    public var description: String {
        seasonCode + "E" + EpisodeCode.pad(episode)
    }

    /// `"S01"`, the value the `episode` filter takes for a whole season.
    public var seasonCode: String {
        "S" + EpisodeCode.pad(season)
    }

    public static func < (lhs: EpisodeCode, rhs: EpisodeCode) -> Bool {
        (lhs.season, lhs.episode) < (rhs.season, rhs.episode)
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let code = EpisodeCode(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an episode code: \(text)")
        }
        self = code
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    static func pad(_ number: Int) -> String {
        number < 10 && number >= 0 ? "0" + String(number) : String(number)
    }
}

extension Sequence where Element == RMEpisode {
    /// The episodes grouped by season, seasons in order, episodes in order within each.
    /// Episodes without a readable code are left out.
    public func groupedBySeason() -> [(season: Int, episodes: [RMEpisode])] {
        var seasons: [Int: [RMEpisode]] = [:]
        for episode in self {
            guard let season = episode.season else { continue }
            seasons[season, default: []].append(episode)
        }
        return seasons.keys.sorted().map { season in
            let episodes = (seasons[season] ?? []).sorted { ($0.number ?? 0, $0.id) < ($1.number ?? 0, $1.id) }
            return (season: season, episodes: episodes)
        }
    }
}
