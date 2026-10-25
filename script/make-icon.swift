// Renders the HexBar app icon (a 3D stack of color chips) with SceneKit
// and writes Resources/AppIcon.png and Resources/AppIcon.icns.
// Usage: swift script/make-icon.swift
import AppKit
import SceneKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

func hex(_ s: String) -> NSColor {
    let v = UInt64(s.dropFirst(), radix: 16)!
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255, green: CGFloat((v >> 8) & 0xff) / 255,
                   blue: CGFloat(v & 0xff) / 255, alpha: 1)
}

func glossy(_ c: NSColor) -> SCNMaterial {
    let m = SCNMaterial()
    m.lightingModel = .physicallyBased
    m.diffuse.contents = c
    m.roughness.contents = 0.24
    m.metalness.contents = 0.0
    m.clearCoat.contents = 1.0
    m.clearCoatRoughness.contents = 0.06
    return m
}

/// Soft studio environment for reflections: bright top, two softboxes, grey floor.
func environment() -> NSImage {
    let size = NSSize(width: 1024, height: 512)
    let img = NSImage(size: size)
    img.lockFocus()
    NSGradient(colors: [hex("#ffffff"), hex("#d8dbe2"), hex("#5a5e68")], atLocations: [0, 0.5, 1],
               colorSpace: .sRGB)!.draw(in: NSRect(origin: .zero, size: size), angle: -90)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: NSRect(x: 180, y: 340, width: 260, height: 110), xRadius: 40, yRadius: 40).fill()
    NSBezierPath(roundedRect: NSRect(x: 640, y: 300, width: 160, height: 90), xRadius: 30, yRadius: 30).fill()
    img.unlockFocus()
    return img
}

func renderStack() -> NSImage {
    let scene = SCNScene()
    scene.background.contents = NSColor.clear
    scene.lightingEnvironment.contents = environment()
    scene.lightingEnvironment.intensity = 0.9

    let key = SCNLight()
    key.type = .directional
    key.intensity = 950
    let keyNode = SCNNode()
    keyNode.light = key
    keyNode.eulerAngles = SCNVector3(-1.15, 0.45, 0)
    scene.rootNode.addChildNode(keyNode)

    let fill = SCNLight()
    fill.type = .ambient
    fill.intensity = 180
    let fillNode = SCNNode()
    fillNode.light = fill
    scene.rootNode.addChildNode(fillNode)

    // Bottom to top, each chip turned a little more.
    let colors = ["#2f5bea", "#3fbf9f", "#f5c542", "#ef5b5b"].map(hex)
    for (i, c) in colors.enumerated() {
        let slab = SCNNode(geometry: SCNBox(width: 1.7, height: 0.26, length: 1.7, chamferRadius: 0.13))
        slab.geometry?.materials = [glossy(c)]
        slab.position.y = CGFloat(i) * 0.34 - 0.5
        slab.eulerAngles.y = CGFloat(i) * 0.2
        scene.rootNode.addChildNode(slab)
    }

    let cam = SCNCamera()
    cam.fieldOfView = 19
    cam.wantsHDR = false
    let camNode = SCNNode()
    camNode.camera = cam
    camNode.position = SCNVector3(6.2, 5.6, 6.2)
    camNode.look(at: SCNVector3(0, 0.05, 0))
    scene.rootNode.addChildNode(camNode)

    let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
    renderer.scene = scene
    renderer.pointOfView = camNode
    renderer.autoenablesDefaultLighting = false
    return renderer.snapshot(atTime: 0, with: CGSize(width: 1024, height: 1024), antialiasingMode: .multisampling4X)
}

/// Places the render on a macOS icon tile: 824pt rounded square, light gradient, soft shadows.
func compose(_ object: NSImage) -> NSImage {
    let img = NSImage(size: NSSize(width: 1024, height: 1024))
    img.lockFocus()
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let path = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let tileShadow = NSShadow()
    tileShadow.shadowColor = NSColor(white: 0, alpha: 0.3)
    tileShadow.shadowBlurRadius = 28
    tileShadow.shadowOffset = NSSize(width: 0, height: -10)
    tileShadow.set()
    hex("#d9dee7").setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(starting: hex("#f3f5f9"), ending: hex("#d9dee7"))!.draw(in: tile, angle: -90)
    let drop = NSShadow()
    drop.shadowColor = NSColor(white: 0, alpha: 0.22)
    drop.shadowBlurRadius = 34
    drop.shadowOffset = NSSize(width: 0, height: -22)
    drop.set()
    object.draw(in: tile.insetBy(dx: 10, dy: 10))
    NSGraphicsContext.restoreGraphicsState()

    NSColor(white: 1, alpha: 0.10).setStroke()
    path.lineWidth = 2
    path.stroke()
    img.unlockFocus()
    return img
}

func png(_ img: NSImage, size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    ctx.imageInterpolation = .high
    NSGraphicsContext.current = ctx
    img.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let icon = compose(renderStack())
try png(icon, size: 1024).write(to: root.appendingPathComponent("Resources/AppIcon.png"))

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try png(icon, size: base * scale).write(to: iconset.appendingPathComponent(name))
    }
}

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try p.run()
p.waitUntilExit()
print(p.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
