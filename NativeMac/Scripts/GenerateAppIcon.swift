import AppKit
import Foundation
import ImageIO

guard CommandLine.arguments.count == 3 else {
    fatalError("Usage: GenerateAppIcon.swift <glass-background.png> <iconset-output>")
}

let backgroundURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let masterURL = iconsetURL.appendingPathComponent("icon_1024x1024.png")
let iconSize: CGFloat = 1024
let symbols = [
    "archivebox", "arrow.clockwise", "chevron.left", "arrow.down.to.line", "arrow.left.arrow.right",
    "arrow.left.arrow.right.circle", "arrow.up.arrow.down", "arrow.up.to.line", "checkmark.circle.fill",
    "clock", "doc", "doc.richtext", "doc.text.magnifyingglass", "exclamationmark.circle.fill",
    "exclamationmark.triangle", "externaldrive", "externaldrive.connected.to.line.below", "film",
    "folder.badge.plus", "folder.fill", "gearshape", "info.circle", "internaldrive", "internaldrive.fill",
    "iphone", "list.bullet", "music.note", "photo", "sidebar.right", "square.and.arrow.down",
    "square.and.arrow.up", "square.grid.2x2", "xmark",
]

let unavailableSymbols = symbols.filter {
    NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil
}
guard unavailableSymbols.isEmpty else {
    fatalError("Missing Apple SF Symbols: \(unavailableSymbols.joined(separator: ", "))")
}

guard let background = NSImage(contentsOf: backgroundURL) else {
    fatalError("Could not load icon background at \(backgroundURL.path)")
}

let canvas = NSImage(size: NSSize(width: iconSize, height: iconSize))
canvas.lockFocus()
NSGraphicsContext.current?.imageInterpolation = .high
background.draw(
    in: NSRect(x: 0, y: 0, width: iconSize, height: iconSize),
    from: NSRect(origin: .zero, size: background.size),
    operation: .copy,
    fraction: 1
)

let glassRect = NSRect(x: 216, y: 216, width: 592, height: 592)
let glassPath = NSBezierPath(roundedRect: glassRect, xRadius: 170, yRadius: 170)
let shadow = NSShadow()
shadow.shadowColor = NSColor(calibratedWhite: 0.05, alpha: 0.24)
shadow.shadowBlurRadius = 42
shadow.shadowOffset = NSSize(width: 0, height: -18)
shadow.set()
NSColor.white.withAlphaComponent(0.16).setFill()
glassPath.fill()
NSShadow().set()

if let gradient = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.28),
    NSColor(calibratedRed: 0.72, green: 0.92, blue: 1, alpha: 0.08),
    NSColor(calibratedRed: 0.2, green: 0.46, blue: 0.92, alpha: 0.11),
]) {
    gradient.draw(in: glassPath, angle: -55)
}

NSColor.white.withAlphaComponent(0.56).setStroke()
glassPath.lineWidth = 3
glassPath.stroke()

guard let symbol = NSImage(systemSymbolName: "externaldrive.connected.to.line.below", accessibilityDescription: "OpenMTP")?
    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 350, weight: .regular, scale: .large)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))) else {
    fatalError("Required Apple SF Symbol is unavailable on this macOS runner")
}

let symbolRect = NSRect(x: 332, y: 332, width: 360, height: 360)
let symbolShadow = NSShadow()
symbolShadow.shadowColor = NSColor(calibratedRed: 0.02, green: 0.18, blue: 0.4, alpha: 0.42)
symbolShadow.shadowBlurRadius = 18
symbolShadow.shadowOffset = NSSize(width: 0, height: -8)
symbolShadow.set()
symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
NSShadow().set()
canvas.unlockFocus()

try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
guard let cgImage = canvas.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let destination = CGImageDestinationCreateWithURL(masterURL as CFURL, "public.png" as CFString, 1, nil) else {
    fatalError("Could not encode the composed app icon")
}
CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write the app icon") }
