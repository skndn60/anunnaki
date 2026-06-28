// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Me",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Me", targets: ["Me"]),
        .library(name: "MeCore", targets: ["MeCore"])
    ],
    targets: [
        .target(
            name: "MeCore",
            path: "Sources/MeCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "Me",
            dependencies: ["MeCore"],
            path: "Sources/Me",
            resources: [
                .process("Resources")                 
            ]
        ),
        .testTarget(
            name: "MeCoreTests",
            dependencies: ["MeCore"]
        )
    ]
)
