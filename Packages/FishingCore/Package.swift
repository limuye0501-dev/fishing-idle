// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "FishingCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "FishingCore", targets: ["FishingCore"])],
    targets: [
        .target(name: "FishingCore"),
        .testTarget(name: "FishingCoreTests", dependencies: ["FishingCore"])
    ]
)
