// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Me",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Me", targets: ["Me"])
    ],
    targets: [
        .executableTarget(
            name: "Me",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
