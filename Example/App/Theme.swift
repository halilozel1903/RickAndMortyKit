import SwiftUI
import RickAndMortyKit
import RickAndMortyUI

/// The look of *Multiverse*, the demo app: a dark sky with portal green.
enum Theme {
    static let background = Color(red: 0.03, green: 0.05, blue: 0.06)
    static let surface = Color(red: 0.08, green: 0.11, blue: 0.12)
    static let portal = Color(red: 0.42, green: 0.93, blue: 0.47)
    static let cornerRadius: CGFloat = 18
}

extension View {
    /// The app's dark, opaque navigation bar. iOS 26 bars are transparent by default, and an
    /// inline title over scrolled content would be unreadable.
    @MainActor
    func multiverseNavigationBar() -> some View {
        toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }

    /// A rounded surface behind grouped content.
    @MainActor
    func cardBackground() -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// A section title with an optional count: "Episodes 51".
struct SectionHeader: View {
    let title: String
    let count: Int?

    init(_ title: String, count: Int? = nil) {
        self.title = title
        self.count = count
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(Color.primary)
            if let count {
                Text(String(count))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Color.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// A small labelled value on a card: "Species / Human".
struct FactTile: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String

    init(_ title: String, value: String, detail: String? = nil, systemImage: String) {
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .cardBackground()
        .accessibilityElement(children: .combine)
    }
}

/// The season header of an episode list: "Season 3 · 10 episodes" in the season's color.
struct SeasonHeader: View {
    let season: Int
    let count: Int

    var body: some View {
        HStack {
            Text("Season " + String(season))
                .font(.headline)
                .foregroundStyle(EpisodeCodeBadge.tint(for: season))
            Spacer()
            Text(RickAndMortyFormat.count(count, "episode"))
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
        }
        .textCase(nil)
    }
}

/// The episodes of one season, for lists.
struct SeasonGroup: Identifiable {
    let season: Int
    let episodes: [RMEpisode]

    var id: Int { season }

    static func make(_ episodes: [RMEpisode]) -> [SeasonGroup] {
        episodes.groupedBySeason().map { SeasonGroup(season: $0.season, episodes: $0.episodes) }
    }
}

/// The data credit shown under lists. Verbatim, so the domain is not turned into a link.
struct DataCredit: View {
    var body: some View {
        Text(verbatim: "Data from rickandmortyapi.com")
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }
}
