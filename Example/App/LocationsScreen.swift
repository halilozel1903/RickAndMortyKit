import SwiftUI
import RickAndMortyKit
import RickAndMortyUI

/// iPhone: every location, searchable by name, loading the next page as you scroll.
struct LocationsScreen: View {
    @Binding var path: [Route]

    @Environment(Multiverse.self) private var multiverse
    @State private var searchText = ""

    private var filter: LocationFilter {
        LocationFilter(name: searchText)
    }

    var body: some View {
        let list = multiverse.locations
        NavigationStack(path: $path) {
            Group {
                if let message = list.errorMessage {
                    ContentUnavailableView("Couldn't load locations", systemImage: "wifi.exclamationmark", description: Text(message))
                } else if list.items.isEmpty, list.loadedFilter == filter {
                    ContentUnavailableView.search(text: searchText)
                } else if list.items.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(list.items) { location in
                            NavigationLink(value: Route.location(location.id)) {
                                LocationCard(location: location)
                            }
                            .listRowBackground(Theme.surface)
                            .onAppear {
                                if list.isLast(location) {
                                    Task { await list.loadMore() }
                                }
                            }
                        }
                        if list.hasMore {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background)
            .navigationTitle("Locations")
            .multiverseNavigationBar()
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search by name")
            .autocorrectionDisabled()
            .task(id: filter) {
                await list.show(filter, debounce: list.loadedFilter != nil)
            }
            .refreshable {
                await list.show(filter, reload: true)
            }
            .navigationDestination(for: Route.self) { route in
                RouteDestination(route)
            }
        }
    }
}

/// A location's page: type, dimension, and the characters last seen there.
struct LocationDetailView: View {
    let locationID: Int

    @Environment(Multiverse.self) private var multiverse
    @State private var location: RMLocation?
    @State private var residents: [RMCharacter]?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let location {
                content(location)
            } else if let errorMessage {
                ContentUnavailableView("Couldn't load this location", systemImage: "mappin.slash", description: Text(errorMessage))
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Theme.background)
        .navigationTitle(location?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .multiverseNavigationBar()
        .task(id: locationID) {
            await load()
        }
    }

    private func load() async {
        errorMessage = nil
        do {
            let loaded = try await multiverse.location(id: locationID)
            location = loaded
            residents = (try? await multiverse.residents(of: loaded)) ?? []
        } catch {
            if !Task.isCancelled {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func content(_ location: RMLocation) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    Image(systemName: LocationCard.systemImage(for: location.type))
                        .font(.largeTitle)
                        .foregroundStyle(LocationCard.tint(for: location.type))
                        .frame(width: 76, height: 76)
                        .background(Circle().fill(LocationCard.tint(for: location.type).opacity(0.18)))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(location.name)
                            .font(.title2.bold())
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                        Text(RickAndMortyFormat.locationLine(location))
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer(minLength: 0)
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    FactTile("Type", value: location.type.isEmpty ? "Unknown" : location.type, systemImage: "square.grid.2x2.fill")
                    FactTile("Dimension", value: location.knownDimension ?? "Unknown", systemImage: "circle.hexagongrid.fill")
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader("Residents", count: location.residentURLs.count)
                    if let residents {
                        CharacterGrid(characters: residents)
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
