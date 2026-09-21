
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Bieznia",

    platforms: [.macOS(.v13)],

    targets: [
        .executableTarget(name: "Bieznia", path: "Sources/Bieznia")
    ]
)
