// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ModelRelay",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9)],
    products: [
        .library(name: "ModelRelay", targets: ["ModelRelay"]),
    ],
    targets: [
        .target(
            name: "ModelRelay",
            dependencies: []
        ),
        .testTarget(
            name: "ModelRelayTests",
            dependencies: ["ModelRelay"]
        ),
    ]
)
