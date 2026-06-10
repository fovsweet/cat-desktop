// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "CatOS",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CatOSKit", path: "Sources/CatOSKit"),
        .executableTarget(
            name: "CatOS",
            dependencies: ["CatOSKit"],
            path: "Sources/CatOS"
        ),
        .testTarget(
            name: "CatOSKitTests",
            dependencies: ["CatOSKit"],
            path: "Tests/CatOSKitTests"
        ),
    ]
)
