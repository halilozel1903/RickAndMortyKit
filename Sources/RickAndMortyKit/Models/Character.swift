import Foundation

/// A character (`/character`).
///
/// Named `RMCharacter` so it never shadows Swift's `Character`.
///
/// ```json
/// {
///   "id": 1, "name": "Rick Sanchez", "status": "Alive", "species": "Human", "type": "",
///   "gender": "Male",
///   "origin": { "name": "Earth (C-137)", "url": "https://rickandmortyapi.com/api/location/1" },
///   "location": { "name": "Citadel of Ricks", "url": "https://rickandmortyapi.com/api/location/3" },
///   "image": "https://rickandmortyapi.com/api/character/avatar/1.jpeg",
///   "episode": ["https://rickandmortyapi.com/api/episode/1", …],
///   "url": "https://rickandmortyapi.com/api/character/1",
///   "created": "2017-11-04T18:48:46.250Z"
/// }
/// ```
public struct RMCharacter: Identifiable, Hashable, Sendable, Codable {
    public var id: Int
    public var name: String
    /// `Alive`, `Dead` or `unknown`.
    public var status: CharacterStatus
    /// The species, such as `"Human"` or `"Alien"`.
    public var species: String
    /// The subspecies or kind, such as `"Genetic experiment"`; often empty.
    public var type: String
    /// `Female`, `Male`, `Genderless` or `unknown`.
    public var gender: CharacterGender
    /// Where the character comes from.
    public var origin: LocationReference
    /// The character's last known location.
    public var location: LocationReference
    /// The 300 × 300 avatar.
    public var image: URL?
    /// The episodes the character appears in (the API's `episode` field).
    public var episodeURLs: [URL]
    /// The character's own endpoint.
    public var url: URL?
    /// When the character was added to the database.
    public var created: Date?

    public init(
        id: Int,
        name: String,
        status: CharacterStatus = .unknown,
        species: String = "",
        type: String = "",
        gender: CharacterGender = .unknown,
        origin: LocationReference = .unknown,
        location: LocationReference = .unknown,
        image: URL? = nil,
        episodeURLs: [URL] = [],
        url: URL? = nil,
        created: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.species = species
        self.type = type
        self.gender = gender
        self.origin = origin
        self.location = location
        self.image = image
        self.episodeURLs = episodeURLs
        self.url = url
        self.created = created
    }

    /// The ids of the episodes the character appears in, in the API's order.
    public var episodeIDs: [Int] {
        ResourceURL.ids(episodeURLs)
    }

    /// `"Human"`, or `"Human · Genetic experiment"` when the character has a type.
    public var speciesDescription: String {
        type.isEmpty ? species : species + " · " + type
    }

    enum CodingKeys: String, CodingKey {
        case id, name, status, species, type, gender, origin, location, image
        case episodeURLs = "episode"
        case url, created
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        status = try container.decodeIfPresent(CharacterStatus.self, forKey: .status) ?? .unknown
        species = try container.decodeIfPresent(String.self, forKey: .species) ?? ""
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        gender = try container.decodeIfPresent(CharacterGender.self, forKey: .gender) ?? .unknown
        origin = try container.decodeIfPresent(LocationReference.self, forKey: .origin) ?? .unknown
        location = try container.decodeIfPresent(LocationReference.self, forKey: .location) ?? .unknown
        image = try container.decodeLenientURL(forKey: .image)
        episodeURLs = try container.decodeURLList(forKey: .episodeURLs)
        url = try container.decodeLenientURL(forKey: .url)
        created = try container.decodeTimestamp(forKey: .created)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(status, forKey: .status)
        try container.encode(species, forKey: .species)
        try container.encode(type, forKey: .type)
        try container.encode(gender, forKey: .gender)
        try container.encode(origin, forKey: .origin)
        try container.encode(location, forKey: .location)
        try container.encodeLenientURL(image, forKey: .image)
        try container.encodeURLList(episodeURLs, forKey: .episodeURLs)
        try container.encodeLenientURL(url, forKey: .url)
        try container.encodeTimestamp(created, forKey: .created)
    }
}

/// Whether a character is alive. The API writes `"Alive"`, `"Dead"` and `"unknown"`; filters
/// take them in any case.
public enum CharacterStatus: String, CaseIterable, Hashable, Sendable, Codable {
    case alive = "Alive"
    case dead = "Dead"
    case unknown = "unknown"

    /// Reads any capitalization; anything else is `.unknown`.
    public init(apiValue: String) {
        switch apiValue.lowercased() {
        case "alive": self = .alive
        case "dead": self = .dead
        default: self = .unknown
        }
    }

    public init(from decoder: any Decoder) throws {
        try self.init(apiValue: decoder.singleValueContainer().decode(String.self))
    }

    /// The value for the `status` filter: `"alive"`, `"dead"` or `"unknown"`.
    public var queryValue: String {
        rawValue.lowercased()
    }

    /// `"Alive"`, `"Dead"` or `"Unknown"`.
    public var displayName: String {
        switch self {
        case .alive: return "Alive"
        case .dead: return "Dead"
        case .unknown: return "Unknown"
        }
    }
}

/// A character's gender. The API writes `"Female"`, `"Male"`, `"Genderless"` and `"unknown"`.
public enum CharacterGender: String, CaseIterable, Hashable, Sendable, Codable {
    case female = "Female"
    case male = "Male"
    case genderless = "Genderless"
    case unknown = "unknown"

    /// Reads any capitalization; anything else is `.unknown`.
    public init(apiValue: String) {
        switch apiValue.lowercased() {
        case "female": self = .female
        case "male": self = .male
        case "genderless": self = .genderless
        default: self = .unknown
        }
    }

    public init(from decoder: any Decoder) throws {
        try self.init(apiValue: decoder.singleValueContainer().decode(String.self))
    }

    /// The value for the `gender` filter: `"female"`, `"male"`, `"genderless"` or `"unknown"`.
    public var queryValue: String {
        rawValue.lowercased()
    }

    /// `"Female"`, `"Male"`, `"Genderless"` or `"Unknown"`.
    public var displayName: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .genderless: return "Genderless"
        case .unknown: return "Unknown"
        }
    }
}

/// A character's origin or last known location: a name and, unless it is unknown, the
/// location's URL.
///
/// ```json
/// { "name": "Earth (C-137)", "url": "https://rickandmortyapi.com/api/location/1" }
/// { "name": "unknown", "url": "" }
/// ```
public struct LocationReference: Hashable, Sendable, Codable {
    public var name: String
    /// The location's endpoint; `nil` when the API sends an empty string.
    public var url: URL?

    public init(name: String, url: URL?) {
        self.name = name
        self.url = url
    }

    /// `{ "name": "unknown", "url": "" }`.
    public static let unknown = LocationReference(name: "unknown", url: nil)

    /// The location's id, when there is a location to load.
    public var id: Int? {
        url.flatMap { ResourceURL.id($0) }
    }

    /// Whether the API knows nothing about this location.
    public var isUnknown: Bool {
        url == nil
    }

    /// The name, with `"unknown"` written as `"Unknown"`.
    public var displayName: String {
        name == "unknown" ? "Unknown" : name
    }

    enum CodingKeys: String, CodingKey {
        case name, url
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "unknown"
        url = try container.decodeLenientURL(forKey: .url)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeLenientURL(url, forKey: .url)
    }
}
