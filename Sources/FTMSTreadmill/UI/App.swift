import SwiftUI
import AppKit

@main
struct FTMSTreadmillApp: App {
    @StateObject private var treadmill = Treadmill()

    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup("FTMS Treadmill") {
            ContentView()
                .environmentObject(treadmill)
                .frame(minWidth: 700, minHeight: 480)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
    }
}
