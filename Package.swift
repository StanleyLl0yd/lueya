// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "lueya",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "LueyaApp", targets: ["LueyaApp"]),
        .executable(name: "LueyaEmbedProbe", targets: ["LueyaEmbedProbe"]),
        .library(name: "LueyaCore", targets: ["LueyaCore"])
    ],
    targets: [
        .target(name: "LueyaCore"),
        .executableTarget(name: "LueyaApp", dependencies: ["LueyaCore"]),
        .executableTarget(name: "LueyaEmbedProbe", dependencies: ["LueyaCore"]),
        .testTarget(name: "LueyaCoreTests", dependencies: ["LueyaCore"])
    ],
    swiftLanguageModes: [.v6]
)
