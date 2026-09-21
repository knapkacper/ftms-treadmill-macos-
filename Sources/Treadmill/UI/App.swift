import SwiftUI
import AppKit

@main
struct TreadmillApp: App {
    @StateObject private var treadmill = Treadmill()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("Treadmill") {
            ContentView()
                .environmentObject(treadmill)
                .frame(minWidth: 700, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
