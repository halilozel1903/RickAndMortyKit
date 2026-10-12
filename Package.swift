// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "RickAndMortyKit",
    platforms: [
        .iOS(.v17),
        // macOS only so `swift test` runs on CI; the views are made for iPhone and iPad.
        .macOS(.v14),
    ],
    products: [
        .library(name: "RickAndMortyKit", targets: ["RickAndMortyKit"]),
        .library(name: "RickAndMortyUI", targets: ["RickAndMortyUI"]),
    ],
    targets: [
        .target(name: "RickAndMortyKit"),
        .target(name: "RickAndMortyUI", dependencies: ["RickAndMortyKit"]),
        .testTarget(
            name: "RickAndMortyKitTests",
            dependencies: ["RickAndMortyKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
