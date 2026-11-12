// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BellOfMindfulness",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "BellOfMindfulness", targets: ["BellOfMindfulness"])],
    targets: [
        .target(name: "BellCore"),
        .executableTarget(name: "BellOfMindfulness", dependencies: ["BellCore"]),
        .testTarget(name: "BellCoreTests", dependencies: ["BellCore"])
    ]
)
