// Draws the HexBar app icon (a fanned swatch deck) and writes Resources/AppIcon.icns.
// Usage: swift script/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func hex(_ s: String) -> CGColor {
    let v = UInt64(s.dropFirst(), radix: 16)!
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                   blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

func draw(size: Int) -> Data {
    let s = CGFloat(size) / 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!.cgContext
    ctx.scaleBy(x: s, y: s)

    // Base tile on the macOS icon grid: 824pt rounded square, centered, soft drop shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: CGColor(gray: 0, alpha: 0.28))
    ctx.addPath(tilePath)
    ctx.setFillColor(hex("#16181d"))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [hex("#2a2e38"), hex("#121318")] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // Fanned swatch cards pivoting near the bottom of the tile.
    let pivot = CGPoint(x: 512, y: 236)
    let cards: [(angle: CGFloat, color: String)] = [
        (27, "#ef5b5b"), (9, "#f5c542"), (-9, "#3fbf9f"), (-27, "#2f5bea"),
    ]
    let card = CGRect(x: -98, y: 0, width: 196, height: 530)
    for c in cards {
        ctx.saveGState()
        ctx.translateBy(x: pivot.x, y: pivot.y)
        ctx.rotate(by: c.angle * .pi / 180)
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 22, color: CGColor(gray: 0, alpha: 0.45))
        let body = CGPath(roundedRect: card, cornerWidth: 34, cornerHeight: 34, transform: nil)
        ctx.addPath(body)
        ctx.setFillColor(hex("#fafaf7"))
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        // Color block on the top of the card, label lines below it.
        let block = CGRect(x: card.minX + 16, y: 150, width: card.width - 32, height: card.height - 166)
        ctx.addPath(CGPath(roundedRect: block, cornerWidth: 22, cornerHeight: 22, transform: nil))
        ctx.setFillColor(hex(c.color))
        ctx.fillPath()
        ctx.setFillColor(hex("#16181d"))
        ctx.fill(CGRect(x: card.minX + 26, y: 96, width: 104, height: 18))
        ctx.setFillColor(hex("#9a9da5"))
        ctx.fill(CGRect(x: card.minX + 26, y: 62, width: 70, height: 14))
        ctx.restoreGState()
    }
    ctx.restoreGState()

    // Hairline highlight on the tile edge.
    ctx.addPath(tilePath)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.08))
    ctx.setLineWidth(2)
    ctx.strokePath()

    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try draw(size: base * scale).write(to: iconset.appendingPathComponent(name))
    }
}
try draw(size: 1024).write(to: root.appendingPathComponent("Resources/AppIcon.png"))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
