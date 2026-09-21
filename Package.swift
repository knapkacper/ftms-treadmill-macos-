
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Treadmill",

    platforms: [.macOS(.v13)],

    targets: [
        .executableTarget(name: "Treadmill", path: "Sources/Treadmill")
    ]
)
