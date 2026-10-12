import Foundation

/// A location (`/location`): a planet, a space station, a dream…
///
/// ```json
/// {
///   "id": 1, "name": "Earth (C-137)", "type": "Planet", "dimension": "Dimension C-137",
///   "residents": ["https://rickandmortyapi.com/api/character/38", …],
///   "url": "https://rickandmortyapi.com/api/location/1",
///   "created": "2017-11-10T12:42:04.162Z"
/// }
/// ```
public struct RMLocation: Identifiable, Hashable, Sendable, Codable {
    public var id: Int
    public var name: String
    /// The kind of location, such as `"Planet"`, `"Space station"` or `"Microverse"`.
    public var type: String
    /// The dimension it is in, such as `"Dimension C-137"`; `"unknown"` when the API doesn't know.
    public var dimension: String
    /// Characters last seen here (the API's `residents` field).
    public var residentURLs: [URL]
    /// The location's own endpoint.
    public var url: URL?
    /// When the location was added to the database.
    public var created: Date?

    public init(
        id: Int,
        name: String,
        type: String = "",
        dimension: String = "",
        residentURLs: [URL] = [],
        url: URL? = nil,
        created: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.dimension = dimension
        self.residentURLs = residentURLs
        self.url = url
        self.created = created
    }

    /// The ids of the residents, in the API's order.
    public var residentIDs: [Int] {
        ResourceURL.ids(residentURLs)
    }

    /// The dimension, or `nil` when it is empty or `"unknown"`.
    public var knownDimension: String? {
        dimension.isEmpty || dimension == "unknown" ? nil : dimension
    }

    /// A reference to this location, as characters carry it in `origin` and `location`.
    public var reference: LocationReference {
        LocationReference(name: name, url: url)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, type, dimension
        case residentURLs = "residents"
        case url, created
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? ""
        dimension = try container.decodeIfPresent(String.self, forKey: .dimension) ?? ""
        residentURLs = try container.decodeURLList(forKey: .residentURLs)
        url = try container.decodeLenientURL(forKey: .url)
        created = try container.decodeTimestamp(forKey: .created)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(type, forKey: .type)
        try container.encode(dimension, forKey: .dimension)
        try container.encodeURLList(residentURLs, forKey: .residentURLs)
        try container.encodeLenientURL(url, forKey: .url)
        try container.encodeTimestamp(created, forKey: .created)
    }
}
