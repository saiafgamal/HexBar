import AppKit
import SwiftUI

struct HexBarApp: App {
    @StateObject private var store = PaletteStore()

    var body: some Scene {
        MenuBarExtra("HexBar", systemImage: "swatchpalette") {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
        }
        .menuBarExtraStyle(.window)
    }
}

// `HexBar --snapshot <dir>` renders the main states to PNGs for visual checks.
if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
    Snapshot.run(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
} else {
    HexBarApp.main()
}
