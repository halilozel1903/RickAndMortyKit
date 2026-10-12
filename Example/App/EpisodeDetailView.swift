import SwiftUI
import RickAndMortyKit
import RickAndMortyUI

/// An episode's page: code, name, air date, and the characters in it (resolved in one request).
struct EpisodeDetailView: View {
    let episodeID: Int

    @Environment(Multiverse.self) private var multiverse
    @State private var episode: RMEpisode?
    @State private var characters: [RMCharacter]?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let episode {
                content(episode)
            } else if let errorMessage {
                ContentUnavailableView("Couldn't load this episode", systemImage: "tv.slash", description: Text(errorMessage))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(episode?.codeString ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .multiverseNavigationBar()
        .task(id: episodeID) {
            await load()
        }
    }

    private func load() async {
        errorMessage = nil
        do {
            let loaded = try await multiverse.episode(id: episodeID)
            episode = loaded
            characters = (try? await multiverse.characters(in: loaded)) ?? []
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func content(_ episode: RMEpisode) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    EpisodeCodeBadge(episode: episode)
                        .scaleEffect(1.3)
                        .frame(width: 68, height: 68)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(episode.name)
                            .font(.title2.bold())
                            .foregroundStyle(Color.primary)
                            .lineLimit(3)
                        Text(RickAndMortyFormat.seasonAndEpisode(episode))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(EpisodeCodeBadge.tint(for: episode.season ?? 0))
                        Label(RickAndMortyFormat.airDate(episode), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Characters", count: episode.characterURLs.count)
                    if let characters {
                        CharacterGrid(characters: characters)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 20)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
    }
}

/// Character tiles that open the character's page.
struct CharacterGrid: View {
    let characters: [RMCharacter]

    var body: some View {
        if characters.isEmpty {
            Text("No characters found.")
                .foregroundStyle(Color.secondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                ForEach(characters) { character in
                    NavigationLink(value: Route.character(character.id)) {
                        CharacterCard(character: character)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
