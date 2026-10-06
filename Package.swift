// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "Loopermn",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "Loopermn",
            targets: ["Loopermn"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Loopermn",
            path: "Loopermn",
            exclude: [
                "Support"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)