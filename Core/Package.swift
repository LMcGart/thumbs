// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Core",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "Detection", targets: ["Detection"]),
        .library(name: "Rating", targets: ["Rating"]),
        .library(name: "Places", targets: ["Places"]),
    ],
    targets: [
        .target(name: "Detection"),
        .target(name: "Rating"),
        .target(name: "Places"),
        .testTarget(name: "DetectionTests", dependencies: ["Detection"]),
        .testTarget(name: "RatingTests", dependencies: ["Rating"]),
        .testTarget(name: "PlacesTests", dependencies: ["Places"]),
    ]
)
