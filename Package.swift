// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MJKit",
    // String form is valid in tools 5.10. `.iOS(.v18)` is PackageDescription 6.0 only.
    platforms: [.iOS("18.0")],
    products: [
        .library(name: "MJKit", targets: ["MJKit"])
    ],
    targets: [
        .target(name: "MJKit", path: "Sources/MJKit"),
        .testTarget(name: "MJKitTests", dependencies: ["MJKit"], path: "Tests/MJKitTests")
    ]
)
