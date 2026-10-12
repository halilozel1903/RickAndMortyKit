import Foundation
import SwiftUI

/// Scenes used by CI to capture the README screenshots on iPhone and iPad.
/// Launch with `-screenshot <scene>`; normal launches are unaffected and use the live API.
///
/// Every scene loads the hand-written fixtures in `Fixtures/` (see `DemoFixtures`) and the
/// avatars generated for the demo in `Artwork/`, so the captures never depend on the network.
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

    /// The character the `character` and `browser` scenes open.
    static let characterID = 1
}

extension View {
    /// Tells scripts/screenshots.sh that the scene is on screen by writing `tmp/screenshot-ready`
    /// into the app container, once `isReady` is true and images had time to fade in.
    func signalsScreenshotReady(_ scene: ScreenshotScene?, when isReady: Bool) -> some View {
        task(id: isReady) {
            guard let scene, isReady else { return }
            try? await Task.sleep(for: .seconds(2.5))
            guard !Task.isCancelled else { return }
            let marker = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("screenshot-ready")
            try? scene.rawValue.write(to: marker, atomically: true, encoding: .utf8)
        }
    }
}
