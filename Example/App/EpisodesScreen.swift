import SwiftUI
import RickAndMortyKit
import RickAndMortyUI

/// iPhone: every episode, grouped by season, searchable by name or code.
struct EpisodesScreen: View {
    let scene: ScreenshotScene?
    @Binding var path: [Route]

    @Environment(Multiverse.self) private var multiverse
    @State private var searchText = ""

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if multiverse.episodes.isEmpty {
                    if let message = multiverse.episodesError {
                        ContentUnavailableView("Couldn't load episodes", systemImage: "wifi.exclamationmark", description: Text(message))
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    list
                }
            }
            .background(Theme.background)
            .navigationTitle("Episodes")
            .multiverseNavigationBar()
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Name or code, like S03E07")
            .autocorrectionDisabled()
            .task {
                await multiverse.loadEpisodes()
            }
            .navigationDestination(for: Route.self) { route in
                RouteDestination(route)
            }
        }
        // Episodes have no images.
        .signalsScreenshotReady(scene, when: !multiverse.episodes.isEmpty, expectsImages: false)
    }

    private var seasons: [SeasonGroup] {
        SeasonGroup.make(EpisodeSearch.filter(multiverse.episodes, by: searchText))
    }

    private var list: some View {
        List {
            ForEach(seasons) { group in
                Section {
                    ForEach(group.episodes) { episode in
                        NavigationLink(value: Route.episode(episode.id)) {
                            EpisodeRow(episode: episode)
                        }
                        .listRowBackground(Theme.surface)
                    }
                } header: {
                    SeasonHeader(season: group.season, count: group.episodes.count)
                }
            }
            Section {
                DataCredit()
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .overlay {
            if seasons.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }
}

/// Filters episodes by a search text, matching the name or the code (`"S03"`, `"s3e7"`).
enum EpisodeSearch {
    static func filter(_ episodes: [RMEpisode], by text: String) -> [RMEpisode] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return episodes }
        let code = EpisodeCode(query)
        return episodes.filter { episode in
            if let code, episode.code == code {
                return true
            }
            return episode.name.localizedCaseInsensitiveContains(query)
                || episode.codeString.localizedCaseInsensitiveContains(query)
        }
    }
}
