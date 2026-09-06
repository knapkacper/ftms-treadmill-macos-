
import PackageDescription

let package = Package(
    name: "Bieznia",

    // Minimalna wersja macOS. 13, bo tyle wymaga używane tu API SwiftUI.
    platforms: [.macOS(.v13)],

    targets: [
        .executableTarget(name: "Bieznia", path: "Sources/Bieznia")
    ]
)
