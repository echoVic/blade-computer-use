// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BladeComputerUseHelper",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BladeComputerUseHelper", targets: ["BladeComputerUseHelper"]),
        .executable(
            name: "BladeComputerUseHelperSelfTest",
            targets: ["BladeComputerUseHelperSelfTest"]
        ),
    ],
    targets: [
        .target(name: "BladeComputerUseCore"),
        .executableTarget(
            name: "BladeComputerUseHelper",
            dependencies: ["BladeComputerUseCore"]
        ),
        .executableTarget(
            name: "BladeComputerUseHelperSelfTest",
            dependencies: ["BladeComputerUseCore"]
        ),
    ]
)
