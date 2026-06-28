// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iMon",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "iMonCore", targets: ["iMonCore"]),
        .library(name: "iMonApp", targets: ["iMonApp"]),
        .executable(name: "iMon", targets: ["iMon"]),
        .executable(name: "iMonCoreSelfTests", targets: ["iMonCoreSelfTests"])
    ],
    targets: [
        .target(name: "iMonCore"),
        .target(name: "iMonApp", dependencies: ["iMonCore"]),
        .executableTarget(name: "iMon", dependencies: ["iMonCore", "iMonApp"]),
        .executableTarget(name: "iMonCoreSelfTests", dependencies: ["iMonCore", "iMonApp"])
    ],
    swiftLanguageModes: [.v6]
)
