import AppKit
import SwiftUI

/// Renders RootView in several states to PNG files. Uses a temp data file, never the real one.
@MainActor
enum Snapshot {
    static func run(to dir: URL) {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = FileManager.default.temporaryDirectory.appendingPathComponent("hexbar-snapshot.json")

        let states: [(String, (PaletteStore) -> Void)] = [
            ("1-brand", { _ in }),
            ("3-add", { $0.query = "#3A7BD5" }),
            ("4-duplicate", { $0.query = "#F5C542" }),
            ("5-search", { $0.query = "primary" }),
            ("6-copied", { s in s.flash("Copied #1E3A9E", swatchID: s.palettes[0].swatches[1].id) }),
            ("7-empty", { s in s.addPalette() }),
        ]

        for (name, setup) in states {
            try? FileManager.default.removeItem(at: data)
            let store = PaletteStore(fileURL: data)
            setup(store)
            let host = NSHostingView(rootView: RootView().environmentObject(store).preferredColorScheme(.light))
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: .aqua)
            window.contentView = host
            window.setFrameOrigin(NSPoint(x: -4000, y: -4000))
            window.orderFrontRegardless()
            RunLoop.main.run(until: Date().addingTimeInterval(0.8))
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?
                    .write(to: dir.appendingPathComponent("\(name).png"))
            }
            window.orderOut(nil)
        }
        exit(0)
    }
}
