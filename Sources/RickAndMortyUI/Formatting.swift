import Foundation
import RickAndMortyKit

/// Text formatting shared by the views.
public enum RickAndMortyFormat {
    /// `"Alive – Human"`, or `"Unknown – Alien"`.
    public static func statusLine(_ character: RMCharacter) -> String {
        character.status.displayName + " – " + character.species
    }

    /// `"Dec 2, 2013"` in the current locale, from the API's `"December 2, 2013"`. Falls back
    /// to the API's text.
    public static func airDate(_ episode: RMEpisode, locale: Locale = .current) -> String {
        guard let date = episode.airDateValue else { return episode.airDate }
        var style = Date.FormatStyle.dateTime.month(.abbreviated).day().year()
        style.timeZone = TimeZone(identifier: "UTC") ?? .current
        style.locale = locale
        return date.formatted(style)
    }

    /// `"Season 1 · Episode 3"`, or the API's code when it can't be read.
    public static func seasonAndEpisode(_ episode: RMEpisode) -> String {
        guard let code = episode.code else { return episode.codeString }
        return "Season \(code.season) · Episode \(code.episode)"
    }

    /// `"1 character"`, `"27 characters"`.
    public static func count(_ value: Int, _ singular: String, _ plural: String? = nil) -> String {
        "\(value) " + (value == 1 ? singular : (plural ?? singular + "s"))
    }

    /// `"Planet · Dimension C-137"`, leaving out unknown parts.
    public static func locationLine(_ location: RMLocation) -> String {
        var parts: [String] = []
        if !location.type.isEmpty, location.type != "unknown" { parts.append(location.type) }
        if let dimension = location.knownDimension { parts.append(dimension) }
        return parts.isEmpty ? "Unknown" : parts.joined(separator: " · ")
    }
}
