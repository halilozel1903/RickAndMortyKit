import SwiftUI
import RickAndMortyKit
import RickAndMortyUI

@main
struct MultiverseApp: App {
    @State private var multiverse: Multiverse
    private let scene = ScreenshotScene.current

    init() {
        _multiverse = State(initialValue: Multiverse.make(for: ScreenshotScene.current))
    }

    var body: some Scene {
        WindowGroup {
            RootView(scene: scene)
                .environment(multiverse)
                // Screenshot scenes use the avatars generated for the demo; a normal launch loads
                // the API's own images.
                .rickAndMortyImageLoader(scene == nil ? .urlSession : DemoFixtures.imageLoader)
                .preferredColorScheme(.dark)
                .tint(Theme.portal)
        }
    }
}

/// A split view with a sidebar where there is room (iPad), tabs otherwise (iPhone).
struct RootView: View {
    let scene: ScreenshotScene?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        if usesSplitView {
            BrowserView(scene: scene)
        } else {
            PhoneRootView(scene: scene)
        }
    }

    private var usesSplitView: Bool {
        switch scene {
        case .browser: return true
        case .some: return false
        case nil: return horizontalSizeClass == .regular
        }
    }
}

/// A page the app can push: a character, an episode or a location, by id.
enum Route: Hashable {
    case character(Int)
    case episode(Int)
    case location(Int)
}

/// The page for a route.
struct RouteDestination: View {
    let route: Route
    let scene: ScreenshotScene?

    init(_ route: Route, scene: ScreenshotScene? = nil) {
        self.route = route
        self.scene = scene
    }

    var body: some View {
        switch route {
        case let .character(id):
            CharacterDetailView(characterID: id, scene: scene)
        case let .episode(id):
            EpisodeDetailView(episodeID: id)
        case let .location(id):
            LocationDetailView(locationID: id)
        }
    }
}

/// iPhone: tabs for characters, episodes and locations, each with its own navigation stack.
struct PhoneRootView: View {
    enum Tab: Hashable {
        case characters
        case episodes
        case locations
    }

    let scene: ScreenshotScene?
    @State private var tab: Tab
    @State private var charactersPath: [Route]
    @State private var episodesPath: [Route] = []
    @State private var locationsPath: [Route] = []

    init(scene: ScreenshotScene?) {
        self.scene = scene
        _tab = State(initialValue: scene == .episodes ? .episodes : .characters)
        // The character scene starts on Rick's page, pushed without an animation.
        _charactersPath = State(initialValue: scene == .character ? [.character(ScreenshotScene.characterID)] : [])
    }

    var body: some View {
        TabView(selection: $tab) {
            CharactersScreen(scene: scene, path: $charactersPath)
                .tabItem { Label("Characters", systemImage: "person.3.fill") }
                .tag(Tab.characters)
            EpisodesScreen(scene: scene == .episodes ? scene : nil, path: $episodesPath)
                .tabItem { Label("Episodes", systemImage: "play.tv.fill") }
                .tag(Tab.episodes)
            LocationsScreen(path: $locationsPath)
                .tabItem { Label("Locations", systemImage: "globe.americas.fill") }
                .tag(Tab.locations)
        }
    }
}
