// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KlawaCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "KlawaCore", targets: ["KlawaCore"])],
    targets: [
        .target(name: "KlawaCore"),
        .testTarget(name: "KlawaCoreTests", dependencies: ["KlawaCore"]),
    ]
)
