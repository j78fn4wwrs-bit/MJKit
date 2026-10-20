// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MJKit",
    platforms: [.iOS("18.0")],
    products: [
        .library(name: "MJKit", targets: ["MJKit"])
    ],
    targets: [
        .target(name: "MJKit", path: "Sources/MJKit")
    ]
)
