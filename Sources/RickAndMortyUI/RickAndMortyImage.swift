import SwiftUI
import RickAndMortyKit
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Loads the bytes of an image URL. The views in this module load avatars through the loader in
/// the environment, so you can swap in your own cache or, in previews and tests, bundled artwork.
///
/// ```swift
/// ContentView()
///     .rickAndMortyImageLoader(RickAndMortyImageLoader { url in
///         try await MyImageCache.shared.data(for: url)
///     })
/// ```
public struct RickAndMortyImageLoader: Sendable {
    private let load: @Sendable (URL) async throws -> Data

    public init(_ load: @escaping @Sendable (URL) async throws -> Data) {
        self.load = load
    }

    public func data(for url: URL) async throws -> Data {
        try await load(url)
    }

    /// Loads over `URLSession.shared` (or from disk for file URLs), keeping recent images in
    /// memory.
    public static let urlSession = RickAndMortyImageLoader { url in
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        if let cached = await ImageDataCache.shared.data(for: url) {
            return cached
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        await ImageDataCache.shared.insert(data, for: url)
        return data
    }
}

/// Recently loaded image bytes, so scrolling back doesn't hit the network again.
actor ImageDataCache {
    static let shared = ImageDataCache()

    private var entries: [URL: Data] = [:]
    private var order: [URL] = []
    private let limit = 300

    func data(for url: URL) -> Data? {
        entries[url]
    }

    func insert(_ data: Data, for url: URL) {
        if entries[url] == nil {
            order.append(url)
        }
        entries[url] = data
        while order.count > limit {
            entries[order.removeFirst()] = nil
        }
    }
}

/// Decoded images, so an avatar that scrolls back into view appears at once.
@MainActor
final class DecodedImageCache {
    static let shared = DecodedImageCache()

    private var images: [URL: Image] = [:]
    private var order: [URL] = []
    private let limit = 300

    func image(for url: URL) -> Image? {
        images[url]
    }

    func insert(_ image: Image, for url: URL) {
        if images[url] == nil {
            order.append(url)
        }
        images[url] = image
        while order.count > limit {
            images[order.removeFirst()] = nil
        }
    }

    static func decode(_ data: Data) -> Image? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        return Image(uiImage: image)
        #elseif canImport(AppKit)
        guard let image = NSImage(data: data) else { return nil }
        return Image(nsImage: image)
        #else
        return nil
        #endif
    }
}

private struct RickAndMortyImageLoaderKey: EnvironmentKey {
    static let defaultValue: RickAndMortyImageLoader = .urlSession
}

extension EnvironmentValues {
    /// The loader ``RickAndMortyImage`` uses. Defaults to ``RickAndMortyImageLoader/urlSession``.
    public var rickAndMortyImageLoader: RickAndMortyImageLoader {
        get { self[RickAndMortyImageLoaderKey.self] }
        set { self[RickAndMortyImageLoaderKey.self] = newValue }
    }
}

extension View {
    /// Loads every avatar below this view with `loader`.
    public func rickAndMortyImageLoader(_ loader: RickAndMortyImageLoader) -> some View {
        environment(\.rickAndMortyImageLoader, loader)
    }
}

/// An image from a URL that fills the space it is given, with a placeholder while it loads or
/// when there is no image.
///
/// Give it a frame or an aspect ratio; the image is scaled to fill and clipped.
public struct RickAndMortyImage<Placeholder: View>: View {
    private let url: URL?
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @Environment(\.rickAndMortyImageLoader) private var loader
    @State private var loaded: LoadedImage?

    public init(url: URL?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.url = url
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    public var body: some View {
        Color.clear
            .overlay {
                if let image = currentImage {
                    image
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .transition(.opacity)
                } else {
                    placeholder
                }
            }
            .clipped()
            .task(id: url) {
                await load()
            }
    }

    private var currentImage: Image? {
        guard let url else { return nil }
        if let loaded, loaded.url == url {
            return loaded.image
        }
        return DecodedImageCache.shared.image(for: url)
    }

    private func load() async {
        guard let url, DecodedImageCache.shared.image(for: url) == nil else { return }
        guard let data = try? await loader.data(for: url), !Task.isCancelled else { return }
        guard let image = DecodedImageCache.decode(data) else { return }
        DecodedImageCache.shared.insert(image, for: url)
        withAnimation(.easeOut(duration: 0.2)) {
            loaded = LoadedImage(url: url, image: image)
        }
    }
}

private struct LoadedImage {
    let url: URL
    let image: Image
}

extension RickAndMortyImage where Placeholder == AvatarPlaceholder {
    /// An image with a generated placeholder: a gradient picked from `name`, with initials.
    public init(url: URL?, name: String?, contentMode: ContentMode = .fill) {
        self.init(url: url, contentMode: contentMode) {
            AvatarPlaceholder(name: name)
        }
    }
}

/// A gradient with initials, the same colors every time for the same name.
public struct AvatarPlaceholder: View {
    private let name: String?

    public init(name: String?) {
        self.name = name
    }

    public var body: some View {
        let palette = AvatarPlaceholder.palette(for: name ?? "")
        LinearGradient(colors: [palette.0, palette.1], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                GeometryReader { proxy in
                    Text(AvatarPlaceholder.initials(of: name ?? ""))
                        .font(.system(size: max(12, proxy.size.width * 0.32), weight: .bold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .accessibilityHidden(true)
    }

    /// "RS" for "Rick Sanchez", "A" for "Annie".
    static func initials(of name: String) -> String {
        let words = name.split(separator: " ").filter { $0.first?.isLetter == true }
        return words.prefix(2).compactMap { $0.first.map { String($0) } }.joined().uppercased()
    }

    /// A stable (not per-launch) hash of the name picks one of a few dark gradients.
    static func palette(for name: String) -> (Color, Color) {
        let seed = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        let palettes: [(Color, Color)] = [
            (Color(red: 0.12, green: 0.36, blue: 0.24), Color(red: 0.04, green: 0.12, blue: 0.10)),
            (Color(red: 0.16, green: 0.24, blue: 0.42), Color(red: 0.05, green: 0.07, blue: 0.16)),
            (Color(red: 0.36, green: 0.16, blue: 0.38), Color(red: 0.10, green: 0.04, blue: 0.12)),
            (Color(red: 0.40, green: 0.26, blue: 0.10), Color(red: 0.12, green: 0.07, blue: 0.04)),
            (Color(red: 0.10, green: 0.30, blue: 0.34), Color(red: 0.03, green: 0.10, blue: 0.12)),
        ]
        return palettes[seed % palettes.count]
    }
}
