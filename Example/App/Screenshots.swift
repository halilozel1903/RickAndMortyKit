import Foundation
import SwiftUI
import RickAndMortyUI

/// Scenes used by CI to capture the README screenshots on iPhone and iPad.
/// Launch with `-screenshot <scene>`; normal launches are unaffected.
///
/// Every scene loads real data and the real character images from the live API
/// (rickandmortyapi.com): the first page of characters, Rick Sanchez (character 1) and the
/// episodes, which start with season 1.
enum ScreenshotScene: String {
    /// iPhone: the character grid with the filter bar.
    case characters
    /// iPhone: Rick's page with origin, location and episodes.
    case character
    /// iPhone: every episode, grouped by season.
    case episodes
    /// iPad: the split view with the sidebar, the character list and Rick's page.
    case browser

    static var current: ScreenshotScene? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else {
            return nil
        }
        return ScreenshotScene(rawValue: arguments[index + 1])
    }

    /// The character the `character` and `browser` scenes open: Rick Sanchez.
    static let characterID = 1

    /// The image loader for the screenshot scenes: the network, retried a few times, and counted
    /// so the scene is only reported ready once every image on screen has loaded.
    static let imageLoader = RickAndMortyImageLoader { url in
        await ScreenshotImageTracker.shared.begin()
        var lastError: any Error = URLError(.unknown)
        for attempt in 0..<4 {
            if attempt > 0 {
                try? await Task.sleep(for: .seconds(Double(attempt) * 2))
            }
            if Task.isCancelled { break }
            do {
                let data = try await RickAndMortyImageLoader.urlSession.data(for: url)
                await ScreenshotImageTracker.shared.end(failed: false)
                return data
            } catch {
                lastError = error
                print("Screenshot image \(url) failed (attempt \(attempt + 1)): \(error)")
            }
        }
        // A view that went away cancels its load; that is not a failure.
        await ScreenshotImageTracker.shared.end(failed: !Task.isCancelled)
        throw lastError
    }
}

/// Counts the image loads of a screenshot scene.
actor ScreenshotImageTracker {
    static let shared = ScreenshotImageTracker()

    struct Snapshot: Sendable {
        var started = 0
        var inFlight = 0
        var failed = 0
        var lastChange = Date()
    }

    private var state = Snapshot()

    func begin() {
        state.started += 1
        state.inFlight += 1
        state.lastChange = Date()
    }

    func end(failed: Bool) {
        state.inFlight -= 1
        if failed { state.failed += 1 }
        state.lastChange = Date()
    }

    func snapshot() -> Snapshot {
        state
    }

    /// Waits until no image load started or finished for `quiet` seconds, and with
    /// `expectsImages` until at least one image has loaded. Returns false, and the scene is never
    /// reported ready, when an image failed to load.
    static func waitUntilSettled(expectsImages: Bool, quiet: TimeInterval = 2.5) async -> Bool {
        while !Task.isCancelled {
            let state = await shared.snapshot()
            if state.failed > 0 {
                print("Screenshot scene: \(state.failed) image(s) failed to load; not marking it ready")
                return false
            }
            if state.started > 0 || !expectsImages,
               state.inFlight == 0,
               Date().timeIntervalSince(state.lastChange) >= quiet {
                return true
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return false
    }
}

extension View {
    /// Tells scripts/screenshots.sh that the scene is on screen by writing `tmp/screenshot-ready`
    /// into the app container, once `isReady` is true (the data has loaded) and every image the
    /// scene shows has loaded too. Nothing is written when loading fails, so CI fails instead of
    /// committing a broken capture.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool, expectsImages: Bool = true) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            // Give the views a moment to start loading their images.
            try? await Task.sleep(for: .seconds(1))
            guard await ScreenshotImageTracker.waitUntilSettled(expectsImages: expectsImages), !Task.isCancelled else {
                return
            }
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
        }
    }
}
