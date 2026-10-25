// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "HexBar",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "HexBar", targets: ["HexBar"])
    ],
    targets: [
        .executableTarget(
            name: "HexBar",
            path: "Sources/HexBar"
        )
    ]
)
