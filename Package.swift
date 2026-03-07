// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AkazaIME",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "AkazaIME",
            path: "Sources/AkazaIME",
            linkerSettings: [
                .unsafeFlags(["-framework", "InputMethodKit"])
            ]
        ),
        .testTarget(
            name: "AkazaIMETests",
            dependencies: ["AkazaIME"],
            path: "Tests/AkazaIMETests",
            exclude: ["AkazaInputControllerBackspaceModifierTests.swift"],
            sources: [
                "CandidateWindowVisibilityPolicyTests.swift",
                "SettingsTests.swift"
            ]
        )
    ]
)
