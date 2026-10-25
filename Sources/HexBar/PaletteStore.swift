import AppKit
import Foundation

@MainActor
final class PaletteStore: ObservableObject {
    @Published var palettes: [Palette] = [] {
        didSet { save() }
    }
    // UI state lives here so it survives the menu window closing (the eyedropper closes it).
    @Published var query = ""
    @Published var draftName = ""
    @Published var selectedID: UUID?
    @Published var toast: String?
    @Published var lastCopiedID: UUID?

    let fileURL: URL
    private var toastTask: Task<Void, Never>?

    static var defaultURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HexBar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("palettes.json")
    }

    init(fileURL: URL = PaletteStore.defaultURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Palette].self, from: data) {
            palettes = saved
        } else {
            palettes = Seed.palettes
            save()
        }
        selectedID = palettes.first?.id
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(palettes).write(to: fileURL, options: .atomic)
    }

    // MARK: Derived

    var selected: Palette? {
        palettes.first { $0.id == selectedID } ?? palettes.first
    }

    var queryHex: String? { Hex.normalize(query) }

    var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty && queryHex == nil
    }

    var searchResults: [(palette: Palette, swatches: [Swatch])] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: "#", with: "")
        guard !q.isEmpty else { return [] }
        return palettes.compactMap { p in
            let hits = p.swatches.filter {
                $0.name.lowercased().contains(q) || $0.hex.lowercased().contains(q)
            }
            return hits.isEmpty ? nil : (p, hits)
        }
    }

    /// Where this hex already lives, e.g. "Example Brand · Accent".
    func existing(_ hex: String) -> [String] {
        palettes.flatMap { p in
            p.swatches.filter { $0.hex == hex }.map { "\(p.name) · \($0.name)" }
        }
    }

    // MARK: Palettes

    @discardableResult
    func addPalette() -> UUID {
        let palette = Palette(name: "Untitled", swatches: [])
        palettes.append(palette)
        selectedID = palette.id
        return palette.id
    }

    func deletePalette(_ id: UUID) {
        guard let i = palettes.firstIndex(where: { $0.id == id }) else { return }
        palettes.remove(at: i)
        if selectedID == id { selectedID = palettes[safe: max(0, i - 1)]?.id }
    }

    func renamePalette(_ id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let i = palettes.firstIndex(where: { $0.id == id }) else { return }
        palettes[i].name = trimmed
    }

    func restoreSeeds() {
        for seed in Seed.palettes where !palettes.contains(where: { $0.name == seed.name }) {
            palettes.append(Palette(name: seed.name, swatches: seed.swatches.map { Swatch(name: $0.name, hex: $0.hex) }))
        }
    }

    // MARK: Swatches

    func addQueryHex(to paletteID: UUID?) {
        guard let hex = queryHex,
              let id = paletteID ?? selected?.id,
              let i = palettes.firstIndex(where: { $0.id == id }) else { return }
        let name = draftName.trimmingCharacters(in: .whitespaces)
        let swatch = Swatch(name: name.isEmpty ? hex.uppercased() : name, hex: hex)
        palettes[i].swatches.append(swatch)
        selectedID = id
        query = ""
        draftName = ""
        flash("Added to \(palettes[i].name)", swatchID: swatch.id)
    }

    func updateSwatch(_ swatch: Swatch) {
        for p in palettes.indices {
            if let s = palettes[p].swatches.firstIndex(where: { $0.id == swatch.id }) {
                palettes[p].swatches[s] = swatch
                return
            }
        }
    }

    func deleteSwatch(_ id: UUID) {
        for p in palettes.indices {
            palettes[p].swatches.removeAll { $0.id == id }
        }
    }

    /// Moves a swatch before `targetID`, or to the end of `paletteID` when no target is given.
    func move(_ id: UUID, before targetID: UUID? = nil, into paletteID: UUID? = nil) {
        guard id != targetID,
              let from = palettes.firstIndex(where: { $0.swatches.contains { $0.id == id } }),
              let s = palettes[from].swatches.firstIndex(where: { $0.id == id }) else { return }
        var copy = palettes
        let swatch = copy[from].swatches.remove(at: s)
        if let targetID,
           let to = copy.firstIndex(where: { $0.swatches.contains { $0.id == targetID } }),
           let t = copy[to].swatches.firstIndex(where: { $0.id == targetID }) {
            copy[to].swatches.insert(swatch, at: t)
        } else if let paletteID, let to = copy.firstIndex(where: { $0.id == paletteID }) {
            copy[to].swatches.append(swatch)
        } else {
            return
        }
        palettes = copy
    }

    // MARK: Clipboard, feedback, sampler

    func copy(_ swatch: Swatch, as format: CopyFormat = .current) {
        let text = format.format(swatch.hex)
        copyText(text)
        flash("Copied \(text)", swatchID: swatch.id)
    }

    func copyText(_ text: String, toast message: String? = nil) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        if let message { flash(message) }
    }

    func flash(_ message: String, swatchID: UUID? = nil) {
        toast = message
        lastCopiedID = swatchID
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.4))
            guard !Task.isCancelled else { return }
            self?.toast = nil
            self?.lastCopiedID = nil
        }
    }

    func pasteFromClipboard() {
        if let s = NSPasteboard.general.string(forType: .string), let hex = Hex.normalize(s) {
            query = hex.uppercased()
        }
    }

    func sampleScreen() {
        NSColorSampler().show { [weak self] color in
            guard let color, let hex = Hex.from(color) else { return }
            Task { @MainActor in
                self?.query = hex.uppercased()
                StatusItem.open()
            }
        }
    }
}

/// Reopens the menu bar window after the eyedropper closes it.
enum StatusItem {
    @MainActor static func open() {
        for window in NSApp.windows where String(describing: type(of: window)).contains("StatusBarWindow") {
            if let button = find(in: window.contentView) {
                button.performClick(nil)
                return
            }
        }
    }

    @MainActor private static func find(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let button = view as? NSButton { return button }
        for sub in view.subviews {
            if let b = find(in: sub) { return b }
        }
        return nil
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
