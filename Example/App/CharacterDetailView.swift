import SwiftUI
import RickAndMortyKit
import RickAndMortyUI

/// A character's page: avatar and status, facts, origin and last known location (resolved from
/// their URLs), and every episode the character appears in.
struct CharacterDetailView: View {
    let characterID: Int
    let scene: ScreenshotScene?

    @Environment(Multiverse.self) private var multiverse
    @State private var character: RMCharacter?
    @State private var episodes: [RMEpisode] = []
    @State private var episodesLoaded = false
    @State private var origin: RMLocation?
    @State private var location: RMLocation?
    @State private var errorMessage: String?
    /// Whether the origin, location or episodes failed to load; the page then shows what it has.
    @State private var partFailed = false

    init(characterID: Int, scene: ScreenshotScene? = nil) {
        self.characterID = characterID
        self.scene = scene
    }

    var body: some View {
        Group {
            if let character {
                content(character)
            } else if let errorMessage {
                ContentUnavailableView(
                    "Couldn't load this character",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(character?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .multiverseNavigationBar()
        .task(id: characterID) {
            await load()
        }
        .signalsScreenshotReady(scene, when: isComplete)
    }

    /// Whether everything on the page has loaded, and on iPad the character list beside it.
    private var isComplete: Bool {
        guard character != nil, episodesLoaded, !partFailed else { return false }
        return scene != .browser || !multiverse.characters.items.isEmpty
    }

    private func load() async {
        errorMessage = nil
        let loaded: RMCharacter
        do {
            loaded = try await multiverse.character(id: characterID)
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
            return
        }
        character = loaded
        partFailed = false
        // The origin and location are URLs; resolve them to show their type and dimension.
        do {
            origin = try await multiverse.location(loaded.origin)
            if loaded.location.id == loaded.origin.id {
                location = origin
            } else {
                location = try await multiverse.location(loaded.location)
            }
        } catch {
            partFailed = true
        }
        do {
            episodes = try await multiverse.episodes(of: loaded)
        } catch {
            episodes = []
            partFailed = true
        }
        episodesLoaded = true
    }

    private func content(_ character: RMCharacter) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header(character)
                facts(character)
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Origin")
                    place(character.origin, resolved: origin)
                }
                VStack(alignment: .leading, spacing: 10) {
                    SectionHeader("Last known location")
                    place(character.location, resolved: location)
                }
                episodesSection(character)
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }

    private func header(_ character: RMCharacter) -> some View {
        HStack(alignment: .center, spacing: 18) {
            RickAndMortyImage(url: character.image, name: character.name)
                .frame(width: 128, height: 128)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(character.status.color.opacity(0.7), lineWidth: 2)
                }
            VStack(alignment: .leading, spacing: 8) {
                Text(character.name)
                    .font(.title.bold())
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                StatusLine(character)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.secondary)
                if !character.type.isEmpty {
                    Text(character.type)
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func facts(_ character: RMCharacter) -> some View {
        let first = episodes.first
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            FactTile("Species", value: character.species.isEmpty ? "Unknown" : character.species, systemImage: "pawprint.fill")
            FactTile("Gender", value: character.gender.displayName, systemImage: "person.fill")
            FactTile("Episodes", value: String(character.episodeURLs.count), systemImage: "play.tv.fill")
            FactTile("First seen", value: first?.codeString ?? "–", detail: first?.name, systemImage: "eye.fill")
        }
    }

    @ViewBuilder
    private func place(_ reference: LocationReference, resolved: RMLocation?) -> some View {
        if let resolved {
            NavigationLink(value: Route.location(resolved.id)) {
                LocationCard(location: resolved)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .cardBackground()
            }
            .buttonStyle(.plain)
        } else {
            HStack(spacing: 14) {
                Image(systemName: reference.isUnknown ? "questionmark" : "mappin.and.ellipse")
                    .font(.title2)
                    .foregroundStyle(Color.secondary)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
                Text(reference.displayName)
                    .font(.headline)
                    .foregroundStyle(reference.isUnknown ? Color.secondary : Color.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .cardBackground()
        }
    }

    private func episodesSection(_ character: RMCharacter) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Episodes", count: character.episodeURLs.count)
            if !episodesLoaded {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if episodes.isEmpty {
                Text("No episodes found.")
                    .foregroundStyle(Color.secondary)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(episodes) { episode in
                        NavigationLink(value: Route.episode(episode.id)) {
                            EpisodeRow(episode: episode)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        if episode.id != episodes.last?.id {
                            Divider()
                                .padding(.leading, 78)
                        }
                    }
                }
                .cardBackground()
            }
        }
    }
}
