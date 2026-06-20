// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iMon",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "iMonCore", targets: ["iMonCore"]),
        .executable(name: "iMon", targets: ["iMon"]),
        .executable(name: "iMonCoreSelfTests", targets: ["iMonCoreSelfTests"])
    ],
    targets: [
        .target(name: "iMonCore"),
        .executableTarget(name: "iMon", dependencies: ["iMonCore"]),
        .executableTarget(name: "iMonCoreSelfTests", dependencies: ["iMonCore"])
    ],
    swiftLanguageModes: [.v6]
)
