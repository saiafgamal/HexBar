import ServiceManagement
import SwiftUI

struct RootView: View {
    @EnvironmentObject var store: PaletteStore
    @FocusState private var searchFocused: Bool
    @State private var renamingID: UUID?
    @State private var confirmDeleteID: UUID?

    static let width: CGFloat = 368
    static let gridHeight: CGFloat = 392

    var body: some View {
        VStack(spacing: 0) {
            TopBar(searchFocused: $searchFocused)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 12)

            if let hex = store.queryHex {
                AddCard(hex: hex)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if store.isSearching {
                SearchResults()
            } else {
                TabsBar(renamingID: $renamingID, confirmDeleteID: $confirmDeleteID)
                if let id = confirmDeleteID, let p = store.palettes.first(where: { $0.id == id }) {
                    DeleteBanner(palette: p) { confirmDeleteID = nil }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                }
                PaletteGrid()
            }

            Footer()
        }
        .frame(width: Self.width)
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .font(Theme.font(13))
        .overlay(alignment: .bottom) { ToastView() }
        .animation(.snappy(duration: 0.22), value: store.queryHex)
        .animation(.snappy(duration: 0.22), value: store.toast)
        .onAppear { searchFocused = true }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject var store: PaletteStore
    var searchFocused: FocusState<Bool>.Binding
    @AppStorage("copyFormat") private var format: CopyFormat = .hash

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: store.queryHex == nil ? "magnifyingglass" : "plus.circle.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(store.queryHex == nil ? Theme.tertiary : Theme.ink)
                    .frame(width: 14)
                TextField("", text: $store.query, prompt: Text("Search, or paste a hex").foregroundStyle(Theme.tertiary))
                    .textFieldStyle(.plain)
                    .font(Theme.font(13.5))
                    .focused(searchFocused)
                    .onSubmit(submit)
                    .onExitCommand { store.query = "" }
                if !store.query.isEmpty {
                    Button { store.query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(searchFocused.wrappedValue ? Theme.ink.opacity(0.3) : Theme.hairline)
            )

            Button { store.sampleScreen() } label: { Image(systemName: "eyedropper") }
                .buttonStyle(IconButtonStyle())
                .help("Pick a color from the screen")

            Menu {
                Picker("Copy as", selection: $format) {
                    ForEach(CopyFormat.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Open at login", isOn: launchAtLogin)
                Divider()
                Button("Paste hex from clipboard") { store.pasteFromClipboard() }
                Button("Restore brand palettes") { store.restoreSeeds() }
                Button("Show palettes file") {
                    NSWorkspace.shared.activateFileViewerSelecting([store.fileURL])
                }
                Divider()
                Button("Quit HexBar") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 34, height: 34)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.hairline))
        }
    }

    private func submit() {
        if store.queryHex != nil {
            store.addQueryHex(to: store.selected?.id)
        } else if let first = store.searchResults.first?.swatches.first {
            store.copy(first)
        }
    }

    private var launchAtLogin: Binding<Bool> {
        Binding(
            get: { SMAppService.mainApp.status == .enabled },
            set: { on in
                try? on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
            }
        )
    }
}

// MARK: - Add card (shown when the field holds a hex)

struct AddCard: View {
    @EnvironmentObject var store: PaletteStore
    let hex: String
    @State private var targetID: UUID?
    @FocusState private var nameFocused: Bool

    var body: some View {
        let target = targetID ?? store.selected?.id
        let dupes = store.existing(hex)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Hex.color(hex))
                    .frame(width: 44, height: 44)
                    .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Theme.hairline))
                VStack(alignment: .leading, spacing: 2) {
                    Text(hex.uppercased()).font(Theme.mono(14, .semibold))
                    Text(dupes.isEmpty ? Hex.rgb(hex) : "Already in \(dupes.joined(separator: ", "))")
                        .font(Theme.font(11.5))
                        .foregroundStyle(dupes.isEmpty ? Theme.secondary : Theme.danger)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                TextField("", text: $store.draftName, prompt: Text("Name (optional)").foregroundStyle(Theme.tertiary))
                    .font(Theme.font(12.5))
                    .focused($nameFocused)
                    .fieldShell(focused: nameFocused)
                    .onSubmit { store.addQueryHex(to: target) }

                Menu {
                    ForEach(store.palettes) { p in
                        Button(p.name) { targetID = p.id }
                    }
                } label: {
                    Text(store.palettes.first { $0.id == target }?.name ?? "Palette")
                }
                .menuStyle(.borderlessButton)
                .font(Theme.font(12.5))
                .fixedSize()
                .padding(.horizontal, 8)
                .frame(height: 30)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.hairline))

                Button("Add") { store.addQueryHex(to: target) }
                    .buttonStyle(InkButtonStyle())
                    .disabled(store.palettes.isEmpty)
            }
        }
        .padding(12)
        .background(Theme.card.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline))
    }
}

// MARK: - Palette tabs

struct TabsBar: View {
    @EnvironmentObject var store: PaletteStore
    @Binding var renamingID: UUID?
    @Binding var confirmDeleteID: UUID?

    var body: some View {
        HStack(spacing: 6) {
            // Plain row while the tabs fit; scroll only when they overflow.
            ViewThatFits(in: .horizontal) {
                pills.padding(.horizontal, 14)
                ScrollView(.horizontal, showsIndicators: false) {
                    pills.padding(.horizontal, 14)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let p = store.selected {
                Menu {
                    Button("Rename") { renamingID = p.id }
                    Button("Copy as CSS variables") {
                        store.copyText(css(p), toast: "Copied \(p.swatches.count) CSS variables")
                    }
                    Button("Copy all hex codes") {
                        store.copyText(p.swatches.map { $0.hex.uppercased() }.joined(separator: "\n"),
                                       toast: "Copied \(p.swatches.count) hex codes")
                    }
                    Divider()
                    Button("Delete palette…", role: .destructive) { confirmDeleteID = p.id }
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(Theme.secondary)
                .padding(.trailing, 16)
                .help("Palette options")
            }
        }
        .frame(height: 30)
    }

    private var pills: some View {
        HStack(spacing: 6) {
            ForEach(store.palettes) { p in
                TabPill(palette: p, renamingID: $renamingID)
            }
            Button {
                renamingID = store.addPalette()
            } label: {
                Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1, dash: [3, 2.5])))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.secondary)
            .help("New palette")
        }
    }

    private func css(_ p: Palette) -> String {
        let prefix = slug(p.name)
        return p.swatches.map { "--\(prefix)-\(slug($0.name)): \($0.hex);" }.joined(separator: "\n")
    }

    private func slug(_ s: String) -> String {
        let out = s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return out.isEmpty ? "color" : out
    }
}

struct TabPill: View {
    @EnvironmentObject var store: PaletteStore
    let palette: Palette
    @Binding var renamingID: UUID?
    @State private var draft = ""
    @State private var dropTargeted = false
    @FocusState private var focused: Bool

    private var isSelected: Bool { store.selected?.id == palette.id }

    var body: some View {
        Group {
            if renamingID == palette.id {
                TextField("", text: $draft)
                    .textFieldStyle(.plain)
                    .font(Theme.font(12.5, 500))
                    .frame(width: max(60, CGFloat(draft.count) * 7.5 + 8))
                    .focused($focused)
                    .onAppear {
                        draft = palette.name
                        focused = true
                    }
                    .onSubmit(commit)
                    .onChange(of: focused) { _, f in if !f { commit() } }
                    .onExitCommand { renamingID = nil }
            } else {
                HStack(spacing: 5) {
                    Text(palette.name).font(Theme.font(12.5, 500))
                    Text("\(palette.swatches.count)")
                        .font(Theme.font(11, 400))
                        .foregroundStyle(isSelected ? .white.opacity(0.55) : Theme.tertiary)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 28)
        .foregroundStyle(isSelected ? .white : Theme.ink)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(isSelected ? Theme.ink : Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(dropTargeted ? Theme.ink : (isSelected ? .clear : Theme.hairline),
                                   lineWidth: dropTargeted ? 1.5 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture { store.selectedID = palette.id }
        .simultaneousGesture(TapGesture(count: 2).onEnded { renamingID = palette.id })
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            store.move(id, into: palette.id)
            return true
        } isTargeted: { dropTargeted = $0 }
        .help("Double-click to rename. Drop a color here to move it.")
    }

    private func commit() {
        store.renamePalette(palette.id, to: draft)
        renamingID = nil
    }
}

struct DeleteBanner: View {
    @EnvironmentObject var store: PaletteStore
    let palette: Palette
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("Delete “\(palette.name)” and its \(palette.swatches.count) colors?")
                .font(Theme.font(12))
                .lineLimit(1)
            Spacer(minLength: 0)
            Button("Cancel", action: dismiss).buttonStyle(GhostButtonStyle())
            Button("Delete") {
                store.deletePalette(palette.id)
                dismiss()
            }
            .buttonStyle(GhostButtonStyle(tint: Theme.danger))
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .frame(height: 38)
        .background(Theme.danger.opacity(0.07), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Grids

private let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

struct PaletteGrid: View {
    @EnvironmentObject var store: PaletteStore

    var body: some View {
        ScrollView {
            if let p = store.selected {
                if p.swatches.isEmpty {
                    EmptyPalette()
                } else {
                    LazyVGrid(columns: gridColumns, spacing: 8) {
                        ForEach(p.swatches) { SwatchCard(swatch: $0) }
                    }
                }
            } else {
                EmptyPalette()
            }
        }
        .contentMargins(14, for: .scrollContent)
        .frame(height: RootView.gridHeight)
    }
}

struct SearchResults: View {
    @EnvironmentObject var store: PaletteStore

    var body: some View {
        let results = store.searchResults
        ScrollView {
            if results.isEmpty {
                VStack(spacing: 6) {
                    Text("No colors match “\(store.query)”").font(Theme.font(13, 500))
                    Text("Paste a hex code to add a new color.")
                        .font(Theme.font(12))
                        .foregroundStyle(Theme.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(results, id: \.palette.id) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.palette.name.uppercased())
                                .font(Theme.font(10.5, 600))
                                .tracking(0.8)
                                .foregroundStyle(Theme.tertiary)
                            LazyVGrid(columns: gridColumns, spacing: 8) {
                                ForEach(group.swatches) { SwatchCard(swatch: $0) }
                            }
                        }
                    }
                }
            }
        }
        .contentMargins(14, for: .scrollContent)
        .frame(height: RootView.gridHeight + 42)
    }
}

struct EmptyPalette: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "eyedropper.halffull")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(Theme.tertiary)
            Text("No colors yet").font(Theme.font(13, 500))
            Text("Paste a hex in the field above,\nor pick one from the screen.")
                .font(Theme.font(12))
                .foregroundStyle(Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }
}

// MARK: - Swatch card

struct SwatchCard: View {
    @EnvironmentObject var store: PaletteStore
    let swatch: Swatch
    @State private var hovering = false
    @State private var dropTargeted = false
    @State private var editing = false

    private var copied: Bool { store.lastCopiedID == swatch.id }
    private var light: Bool { Hex.isLight(swatch.hex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Hex.color(swatch.hex))
                .frame(height: 62)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.black.opacity(light ? 0.07 : 0))
                )
                .overlay {
                    if copied {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(light ? Theme.ink : .white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if hovering && !copied {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundStyle(light ? Theme.ink.opacity(0.7) : .white.opacity(0.9))
                            .padding(6)
                            .transition(.opacity)
                    }
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(swatch.name)
                    .font(Theme.font(12, 500))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(swatch.hex.uppercased())
                    .font(Theme.mono(10.5))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.top, 7)
            .padding(.bottom, 3)
        }
        .padding(5)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(dropTargeted ? Theme.ink : (hovering ? Theme.hairlineStrong : Theme.hairline),
                              lineWidth: dropTargeted ? 1.5 : 1)
        )
        .shadow(color: .black.opacity(hovering ? 0.07 : 0), radius: 8, y: 3)
        .scaleEffect(copied ? 0.97 : 1)
        .animation(.snappy(duration: 0.18), value: hovering)
        .animation(.snappy(duration: 0.18), value: copied)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onHover { hovering = $0 }
        .onTapGesture { store.copy(swatch) }
        .help("\(swatch.name)  ·  \(swatch.hex.uppercased())\nClick to copy. Drag to reorder.")
        .draggable(swatch.id.uuidString) {
            RoundedRectangle(cornerRadius: 8).fill(Hex.color(swatch.hex)).frame(width: 40, height: 40)
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            store.move(id, before: swatch.id)
            return true
        } isTargeted: { dropTargeted = $0 }
        .contextMenu {
            ForEach(CopyFormat.allCases) { f in
                Button("Copy \(f.format(swatch.hex))") { store.copy(swatch, as: f) }
            }
            Divider()
            Button("Edit…") { editing = true }
            Menu("Move to") {
                ForEach(store.palettes.filter { !$0.swatches.contains { $0.id == swatch.id } }) { p in
                    Button(p.name) { store.move(swatch.id, into: p.id) }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { store.deleteSwatch(swatch.id) }
        }
        .popover(isPresented: $editing, arrowEdge: .bottom) {
            SwatchEditor(swatch: swatch, isPresented: $editing)
                .environmentObject(store)
        }
    }
}

struct SwatchEditor: View {
    @EnvironmentObject var store: PaletteStore
    let swatch: Swatch
    @Binding var isPresented: Bool
    @State private var name = ""
    @State private var hex = ""

    var body: some View {
        let valid = Hex.normalize(hex)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(valid.map(Hex.color) ?? .clear)
                    .frame(width: 30, height: 30)
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Theme.hairline))
                Text("Edit color").font(Theme.font(13, 600))
            }
            TextField("", text: $name, prompt: Text("Name"))
                .font(Theme.font(12.5))
                .fieldShell()
            TextField("", text: $hex, prompt: Text("#000000"))
                .font(Theme.mono(12))
                .fieldShell()
            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }.buttonStyle(GhostButtonStyle())
                Button("Save") {
                    guard let valid else { return }
                    store.updateSwatch(Swatch(id: swatch.id, name: name, hex: valid))
                    isPresented = false
                }
                .buttonStyle(InkButtonStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(valid == nil)
            }
        }
        .padding(14)
        .frame(width: 240)
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .onAppear {
            name = swatch.name
            hex = swatch.hex.uppercased()
        }
    }
}

// MARK: - Footer and toast

struct Footer: View {
    var body: some View {
        Text("Click to copy  ·  Drag to reorder  ·  Right-click for more")
            .font(Theme.font(11))
            .foregroundStyle(Theme.tertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }
}

struct ToastView: View {
    @EnvironmentObject var store: PaletteStore

    var body: some View {
        if let message = store.toast {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                Text(message).font(Theme.font(12.5, 500))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Theme.ink, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
            .padding(.bottom, 46)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
