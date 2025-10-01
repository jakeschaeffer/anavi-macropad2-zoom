// swift-tools-version:5.8
import PackageDescription

let package = Package(
    name: "SmoothScrollDaemon",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "smooth-scroll-daemon", targets: ["SmoothScrollDaemon"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SmoothScrollDaemon",
            dependencies: [],
            path: "Sources/SmoothScrollDaemon"
        )
    ]
)
