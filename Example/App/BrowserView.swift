import SwiftUI
import RickAndMortyKit
import RickAndMortyUI

/// iPad: a three-column split view. The sidebar picks characters, episodes or locations, the
/// middle column lists them, and the detail column shows the selection's page.
struct BrowserView: View {
    enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
        case characters
        case episodes
        case locations

        var id: Self { self }

        var title: String {
            switch self {
            case .characters: return "Characters"
            case .episodes: return "Episodes"
            case .locations: return "Locations"
            }
        }

        var systemImage: String {
            switch self {
            case .characters: return "person.3.fill"
            case .episodes: return "play.tv.fill"
            case .locations: return "globe.americas.fill"
            }
        }
    }

    let scene: ScreenshotScene?

    @Environment(Multiverse.self) private var multiverse
    @State private var sidebar: SidebarItem? = .characters
    @State private var selectedCharacter: Int?
    @State private var selectedEpisode: Int?
    @State private var selectedLocation: Int?
    @State private var detailPath: [Route] = []
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(scene: ScreenshotScene?) {
        self.scene = scene
        // The browser scene opens on Rick's page.
        _selectedCharacter = State(initialValue: scene == .browser ? ScreenshotScene.characterID : nil)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebarList
        } content: {
            switch sidebar ?? .characters {
            case .characters:
                CharacterColumn(selection: $selectedCharacter)
            case .episodes:
                EpisodeColumn(selection: $selectedEpisode)
            case .locations:
                LocationColumn(selection: $selectedLocation)
            }
        } detail: {
            NavigationStack(path: $detailPath) {
                detailRoot
                    .navigationDestination(for: Route.self) { route in
                        RouteDestination(route)
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: sidebar) { detailPath = [] }
        .onChange(of: selectedCharacter) { detailPath = [] }
        .onChange(of: selectedEpisode) { detailPath = [] }
        .onChange(of: selectedLocation) { detailPath = [] }
    }

    private var sidebarList: some View {
        List(selection: $sidebar) {
            Section {
                ForEach(SidebarItem.allCases) { item in
                    Label(item.title, systemImage: item.systemImage)
                        .tag(item)
                }
            }
            Section {
                DataCredit()
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Multiverse")
        .navigationSplitViewColumnWidth(min: 200, ideal: 230, max: 280)
    }

    @ViewBuilder
    private var detailRoot: some View {
        switch sidebar ?? .characters {
        case .characters:
            if let id = selectedCharacter {
                CharacterDetailView(characterID: id, scene: scene == .browser ? scene : nil)
                    .id(id)
            } else {
                ContentUnavailableView("Choose a character", systemImage: "person.crop.square", description: Text("Pick someone from the list to see where they come from and where they've been."))
            }
        case .episodes:
            if let id = selectedEpisode {
                EpisodeDetailView(episodeID: id)
                    .id(id)
            } else {
                ContentUnavailableView("Choose an episode", systemImage: "play.tv", description: Text("Pick an episode to see who is in it."))
            }
        case .locations:
            if let id = selectedLocation {
                LocationDetailView(locationID: id)
                    .id(id)
            } else {
                ContentUnavailableView("Choose a location", systemImage: "globe.americas", description: Text("Pick a location to see who was last seen there."))
            }
        }
    }
}

/// iPad: the character list, with search and the status and gender filters.
private struct CharacterColumn: View {
    @Binding var selection: Int?

    @Environment(Multiverse.self) private var multiverse
    @State private var searchText = ""
    @State private var status: CharacterStatus?
    @State private var gender: CharacterGender?

    private var filter: CharacterFilter {
        CharacterFilter(name: searchText, status: status, gender: gender)
    }

    var body: some View {
        let list = multiverse.characters
        List(selection: $selection) {
            if let message = list.errorMessage {
                ContentUnavailableView("Couldn't load characters", systemImage: "wifi.exclamationmark", description: Text(message))
            } else if list.items.isEmpty, list.loadedFilter == filter {
                ContentUnavailableView("Nobody here", systemImage: "person.crop.circle.badge.questionmark")
            } else {
                Section {
                    ForEach(list.items) { character in
                        CharacterCard(character: character, style: .row)
                            .tag(character.id)
                            .onAppear {
                                if list.isLast(character) {
                                    Task { await list.loadMore() }
                                }
                            }
                    }
                    if list.hasMore {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } header: {
                    if let total = list.total {
                        Text(RickAndMortyFormat.count(total, "character"))
                            .textCase(nil)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            FilterBar(status: $status, gender: $gender)
                .background(Theme.background)
        }
        .navigationTitle("Characters")
        .searchable(text: $searchText, prompt: "Search by name")
        .autocorrectionDisabled()
        .task(id: filter) {
            await list.show(filter, debounce: list.loadedFilter != nil)
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
    }
}

/// iPad: every episode, grouped by season.
private struct EpisodeColumn: View {
    @Binding var selection: Int?

    @Environment(Multiverse.self) private var multiverse
    @State private var searchText = ""

    var body: some View {
        let seasons = SeasonGroup.make(EpisodeSearch.filter(multiverse.episodes, by: searchText))
        List(selection: $selection) {
            if let message = multiverse.episodesError, multiverse.episodes.isEmpty {
                ContentUnavailableView("Couldn't load episodes", systemImage: "wifi.exclamationmark", description: Text(message))
            } else if multiverse.episodes.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(seasons) { group in
                    Section {
                        ForEach(group.episodes) { episode in
                            EpisodeRow(episode: episode)
                                .tag(episode.id)
                        }
                    } header: {
                        SeasonHeader(season: group.season, count: group.episodes.count)
                    }
                }
            }
        }
        .navigationTitle("Episodes")
        .searchable(text: $searchText, prompt: "Name or code")
        .task {
            await multiverse.loadEpisodes()
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
    }
}

/// iPad: every location, searchable by name.
private struct LocationColumn: View {
    @Binding var selection: Int?

    @Environment(Multiverse.self) private var multiverse
    @State private var searchText = ""

    private var filter: LocationFilter {
        LocationFilter(name: searchText)
    }

    var body: some View {
        let list = multiverse.locations
        List(selection: $selection) {
            if let message = list.errorMessage {
                ContentUnavailableView("Couldn't load locations", systemImage: "wifi.exclamationmark", description: Text(message))
            } else if list.items.isEmpty, list.loadedFilter == filter {
                ContentUnavailableView.search(text: searchText)
            } else {
                ForEach(list.items) { location in
                    LocationCard(location: location)
                        .tag(location.id)
                        .onAppear {
                            if list.isLast(location) {
                                Task { await list.loadMore() }
                            }
                        }
                }
                if list.hasMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Locations")
        .searchable(text: $searchText, prompt: "Search by name")
        .autocorrectionDisabled()
        .task(id: filter) {
            await list.show(filter, debounce: list.loadedFilter != nil)
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 340, max: 420)
    }
}
