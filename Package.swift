// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MilyonusComputerUse",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ComputerUseContracts", targets: ["ComputerUseContracts"]),
        .library(name: "ComputerUseClient", targets: ["ComputerUseClient"]),
        .library(name: "ComputerUseAgent", targets: ["ComputerUseAgent"]),
        .library(name: "ComputerUseIntegration", targets: ["ComputerUseIntegration"]),
        .executable(name: "milyonus-cu", targets: ["ComputerUseCLI"]),
        .executable(name: "MilyonusComputerUse", targets: ["ComputerUseApp"]),
        .executable(name: "ComputerUseFixture", targets: ["ComputerUseFixture"]),
        .executable(name: "computer-use-selftest", targets: ["ComputerUseSelfTest"])
    ],
    targets: [
        .target(name: "ComputerUseContracts"),
        .target(name: "ComputerUseCore", dependencies: ["ComputerUseContracts"]),
        .target(name: "ComputerUseMacOS", dependencies: ["ComputerUseContracts", "ComputerUseCore"]),
        .target(name: "ComputerUseAcceptance", dependencies: ["ComputerUseContracts", "ComputerUseCore", "ComputerUseClient"]),
        .target(name: "ComputerUseClient", dependencies: ["ComputerUseContracts"]),
        .target(name: "ComputerUseIntegration", dependencies: ["ComputerUseContracts", "ComputerUseClient", "ComputerUseAgent"]),
        .target(name: "ComputerUseAgent", dependencies: ["ComputerUseContracts", "ComputerUseClient"]),
        .executableTarget(name: "ComputerUseCLI", dependencies: ["ComputerUseAcceptance", "ComputerUseMacOS", "ComputerUseClient", "ComputerUseAgent"]),
        .executableTarget(name: "ComputerUseApp", dependencies: ["ComputerUseMacOS", "ComputerUseCore"]),
        .executableTarget(name: "ComputerUseFixture"),
        .executableTarget(name: "ComputerUseSelfTest", dependencies: ["ComputerUseAcceptance", "ComputerUseContracts", "ComputerUseCore", "ComputerUseAgent", "ComputerUseClient", "ComputerUseIntegration"], path: "Tests")
    ]
)
