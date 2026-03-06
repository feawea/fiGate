// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "fiGate",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "fiGateCore",
            targets: ["fiGateCore"]
        ),
        .executable(
            name: "fiGateApp",
            targets: ["fiGateApp"]
        ),
    ],
    targets: [
        .target(
            name: "fiGateCore",
            path: "fiGateApp",
            exclude: [
                "App.swift",
                "ContentView.swift",
                "HostServices",
                "Views",
            ],
            sources: [
                "Models",
                "Services",
                "Utilities",
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
        .executableTarget(
            name: "fiGateApp",
            dependencies: ["fiGateCore"],
            path: "fiGateApp",
            exclude: [
                "Models",
                "Services",
                "Utilities",
            ],
            sources: [
                "App.swift",
                "ContentView.swift",
                "HostServices",
                "Views",
            ]
        ),
        .testTarget(
            name: "fiGateCoreTests",
            dependencies: ["fiGateCore"],
            path: "Tests/fiGateCoreTests",
            linkerSettings: [
                .linkedLibrary("sqlite3"),
            ]
        ),
    ]
)
