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
            exclude: [
                "IPC.md",
                "Features/Dashboard/Dashboard.md",
                "Features/Hotkey/Hotkey.md",
                "Features/Lifecycle/Lifecycle.md",
                "Features/Onboarding/Onboarding.md",
                "Features/Onboarding/OnboardingUI.md",
                "Features/Permissions/Permissions.md",
                "Features/Startup/Startup.md"
            ],
            linkerSettings: [
                .linkedFramework("Network")
            ]
        )
    ]
)
