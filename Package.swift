// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AgentVersionBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "AgentVersionBarApp",
            targets: ["AgentVersionBarApp"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", exact: "6.2.4")
    ],
    targets: [
        .executableTarget(
            name: "AgentVersionBarApp"
        ),
        .testTarget(
            name: "AgentVersionBarTests",
            dependencies: [
                "AgentVersionBarApp",
                .product(name: "Testing", package: "swift-testing")
            ]
        )
    ]
)
