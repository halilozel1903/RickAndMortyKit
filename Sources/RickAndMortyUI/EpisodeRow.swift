import SwiftUI
import RickAndMortyKit

/// An episode's code, name and air date, with an optional character count.
///
/// ```swift
/// List(episodes) { EpisodeRow(episode: $0) }
/// ```
public struct EpisodeRow: View {
    private let episode: RMEpisode
    private let showsCharacterCount: Bool

    public init(episode: RMEpisode, showsCharacterCount: Bool = true) {
        self.episode = episode
        self.showsCharacterCount = showsCharacterCount
    }

    public var body: some View {
        HStack(spacing: 14) {
            EpisodeCodeBadge(episode: episode)
            VStack(alignment: .leading, spacing: 3) {
                Text(episode.name)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(RickAndMortyFormat.airDate(episode))
                    if showsCharacterCount, !episode.characterURLs.isEmpty {
                        Text("·")
                        Text(RickAndMortyFormat.count(episode.characterURLs.count, "character"))
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(episode.name), \(RickAndMortyFormat.seasonAndEpisode(episode)), aired \(RickAndMortyFormat.airDate(episode))")
    }
}

/// The episode code on two lines, `S01` over `E03`, in a rounded square.
public struct EpisodeCodeBadge: View {
    private let episode: RMEpisode

    public init(episode: RMEpisode) {
        self.episode = episode
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let code = episode.code {
                Text(code.seasonCode)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                Text("E" + EpisodeCodeBadge.pad(code.episode))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(Color.primary)
            } else {
                Text(episode.codeString)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primary)
            }
        }
        .frame(width: 52, height: 52)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(EpisodeCodeBadge.tint(for: episode.season ?? 0).opacity(0.22))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(EpisodeCodeBadge.tint(for: episode.season ?? 0).opacity(0.5))
        }
        .accessibilityHidden(true)
    }

    static func pad(_ number: Int) -> String {
        number < 10 ? "0\(number)" : "\(number)"
    }

    /// One color per season, so a long list reads in blocks.
    public static func tint(for season: Int) -> Color {
        let tints: [Color] = [
            Color(red: 0.33, green: 0.86, blue: 0.42),
            Color(red: 0.30, green: 0.74, blue: 0.95),
            Color(red: 0.75, green: 0.45, blue: 0.98),
            Color(red: 0.98, green: 0.62, blue: 0.26),
            Color(red: 0.98, green: 0.40, blue: 0.62),
            Color(red: 0.95, green: 0.85, blue: 0.30),
        ]
        return tints[abs(season - 1) % tints.count]
    }
}
