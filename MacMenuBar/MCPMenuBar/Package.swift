// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MCPMenuBar",
    platforms: [.macOS(.v13)],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "MCPMenuBar",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("Network")
            ]
        )
    ]
)
