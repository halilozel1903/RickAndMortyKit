import Foundation

/// Reads and writes the API's dates.
public enum APIDate {
    /// `created` timestamps: `"2017-11-04T18:48:46.250Z"`.
    static let timestampStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
    /// The same without fractional seconds, accepted when reading.
    static let timestampStyleWithoutFraction = Date.ISO8601FormatStyle()

    /// Episode air dates: `"December 2, 2013"`, in English, read as midnight UTC.
    static let airDateStrategy = Date.ParseStrategy(
        format: "\(month: .wide) \(day: .defaultDigits), \(year: .defaultDigits)",
        locale: Locale(identifier: "en_US_POSIX"),
        timeZone: TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
    )

    /// Parses a `created` timestamp, or returns `nil`.
    public static func timestamp(from string: String) -> Date? {
        if let date = try? timestampStyle.parse(string) {
            return date
        }
        return try? timestampStyleWithoutFraction.parse(string)
    }

    /// Formats a date the way the API writes `created`.
    public static func string(fromTimestamp date: Date) -> String {
        timestampStyle.format(date)
    }

    /// Parses an air date such as `"December 2, 2013"`, or returns `nil`.
    public static func airDate(from string: String) -> Date? {
        try? airDateStrategy.parse(string.trimmingCharacters(in: .whitespaces))
    }
}

/// Ids in the API's resource URLs.
public enum ResourceURL {
    /// The id at the end of a resource URL: `5` for `https://rickandmortyapi.com/api/episode/5`.
    public static func id(_ url: URL) -> Int? {
        Int(url.lastPathComponent)
    }

    /// The ids of the URLs that have one, in order.
    public static func ids(_ urls: [URL]) -> [Int] {
        urls.compactMap { id($0) }
    }

    /// The path of an API URL below the REST folder (`"episode/5"`), so it can be requested from
    /// another base URL; `nil` when the URL is not below an `api` folder.
    static func relativePath(_ url: URL) -> String? {
        let components = url.pathComponents.filter { $0 != "/" }
        guard let index = components.firstIndex(of: "api"), index + 1 < components.count else {
            return nil
        }
        return components[(index + 1)...].joined(separator: "/")
    }
}

/// A URL from the API, where an unknown value is an empty string.
func apiURL(_ string: String?) -> URL? {
    guard let trimmed = string?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
        return nil
    }
    return URL(string: trimmed)
}

extension KeyedDecodingContainer {
    /// A URL that may be an empty string or missing.
    func decodeLenientURL(forKey key: Key) throws -> URL? {
        try apiURL(decodeIfPresent(String.self, forKey: key))
    }

    /// A list of URLs, skipping empty or malformed entries.
    func decodeURLList(forKey key: Key) throws -> [URL] {
        let strings = try decodeIfPresent([String].self, forKey: key) ?? []
        return strings.compactMap { apiURL($0) }
    }

    /// A `created` timestamp; `nil` when missing or unreadable.
    func decodeTimestamp(forKey key: Key) throws -> Date? {
        guard let string = try decodeIfPresent(String.self, forKey: key) else { return nil }
        return APIDate.timestamp(from: string)
    }
}

extension KeyedEncodingContainer {
    /// Writes a URL the way the API does: an empty string when there is none.
    mutating func encodeLenientURL(_ url: URL?, forKey key: Key) throws {
        try encode(url?.absoluteString ?? "", forKey: key)
    }

    mutating func encodeURLList(_ urls: [URL], forKey key: Key) throws {
        try encode(urls.map(\.absoluteString), forKey: key)
    }

    mutating func encodeTimestamp(_ date: Date?, forKey key: Key) throws {
        if let date {
            try encode(APIDate.string(fromTimestamp: date), forKey: key)
        }
    }
}
