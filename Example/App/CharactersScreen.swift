import SwiftUI
import RickAndMortyKit
import RickAndMortyUI

/// iPhone: every character in a grid, searchable by name and filtered by status and gender,
/// loading the next page as you scroll.
struct CharactersScreen: View {
    let scene: ScreenshotScene?
    @Binding var path: [Route]

    @Environment(Multiverse.self) private var multiverse
    @State private var searchText = ""
    @State private var status: CharacterStatus?
    @State private var gender: CharacterGender?

    private let columns = [GridItem(.adaptive(minimum: 156), spacing: 14)]

    private var filter: CharacterFilter {
        CharacterFilter(name: searchText, status: status, gender: gender)
    }

    var body: some View {
        let list = multiverse.characters
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    FilterBar(status: $status, gender: $gender)
                    content(list)
                }
                .padding(.bottom, 16)
            }
            .background(Theme.background)
            .navigationTitle("Characters")
            .multiverseNavigationBar()
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by name")
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .task(id: filter) {
                // Wait for a pause in typing, except for the first load.
                await list.show(filter, debounce: list.loadedFilter != nil && scene == nil)
            }
            .refreshable {
                await list.show(filter, reload: true)
            }
            .navigationDestination(for: Route.self) { route in
                RouteDestination(route, scene: scene == .character ? scene : nil)
            }
        }
        .signalsScreenshotReady(scene == .characters ? scene : nil, when: !list.items.isEmpty)
    }

    @ViewBuilder
    private func content(_ list: PagedList<RMCharacter, CharacterFilter>) -> some View {
        if let message = list.errorMessage {
            ContentUnavailableView("Couldn't load characters", systemImage: "wifi.exclamationmark", description: Text(message))
                .padding(.top, 40)
        } else if list.items.isEmpty, list.loadedFilter == filter {
            ContentUnavailableView(
                "Nobody here",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("No character in the multiverse matches these filters.")
            )
            .padding(.top, 40)
        } else if list.items.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
        } else {
            if let total = list.total {
                Text(RickAndMortyFormat.count(total, "character"))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal)
            }
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(list.items) { character in
                    NavigationLink(value: Route.character(character.id)) {
                        CharacterCard(character: character)
                    }
                    .buttonStyle(.plain)
                    .onAppear {
                        if list.isLast(character) {
                            Task { await list.loadMore() }
                        }
                    }
                }
            }
            .padding(.horizontal)
            if list.hasMore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                DataCredit()
            }
        }
    }
}
