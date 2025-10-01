// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmoothScrollConfigurator",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SmoothScrollConfigurator", targets: ["SmoothScrollConfigurator"])
    ],
    targets: [
        .executableTarget(
            name: "SmoothScrollConfigurator",
            dependencies: [],
            path: "Sources/SmoothScrollConfigurator"
        )
    ]
)
