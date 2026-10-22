// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TaskManager",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "TaskManager",
            targets: ["TaskManagerApp"]
        ),
        .library(
            name: "TaskManagerCore",
            targets: ["TaskManagerCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "TaskManagerCore",
            dependencies: [],
            path: "Sources/TaskManagerCore"
        ),
        .executableTarget(
            name: "TaskManagerApp",
            dependencies: [
                "TaskManagerCore"
            ],
            path: "Sources/TaskManagerApp",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
