import SwiftUI
import AppKit

@main
struct BiezniaApp: App {
    @StateObject private var treadmill = Treadmill()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Bieżnia") {
            ContentView()
                .environmentObject(treadmill)
                .frame(minWidth: 700, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
