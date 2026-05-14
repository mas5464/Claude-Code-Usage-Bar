import AppKit

let iconColor = NSColor(calibratedRed: 217.0 / 255.0, green: 119.0 / 255.0, blue: 87.0 / 255.0, alpha: 1.0)

func makeClaudeCodePath() -> NSBezierPath {
    let path = NSBezierPath()
    path.windingRule = .evenOdd

    path.move(to: NSPoint(x: 20.998, y: 10.949))
    path.line(to: NSPoint(x: 24.0, y: 10.949))
    path.line(to: NSPoint(x: 24.0, y: 14.051))
    path.line(to: NSPoint(x: 21.0, y: 14.051))
    path.line(to: NSPoint(x: 21.0, y: 17.079))
    path.line(to: NSPoint(x: 19.513, y: 17.079))
    path.line(to: NSPoint(x: 19.513, y: 20.0))
    path.line(to: NSPoint(x: 18.0, y: 20.0))
    path.line(to: NSPoint(x: 18.0, y: 17.079))
    path.line(to: NSPoint(x: 16.513, y: 17.079))
    path.line(to: NSPoint(x: 16.513, y: 20.0))
    path.line(to: NSPoint(x: 15.0, y: 20.0))
    path.line(to: NSPoint(x: 15.0, y: 17.079))
    path.line(to: NSPoint(x: 9.0, y: 17.079))
    path.line(to: NSPoint(x: 9.0, y: 20.0))
    path.line(to: NSPoint(x: 7.488, y: 20.0))
    path.line(to: NSPoint(x: 7.488, y: 17.079))
    path.line(to: NSPoint(x: 6.0, y: 17.079))
    path.line(to: NSPoint(x: 6.0, y: 20.0))
    path.line(to: NSPoint(x: 4.487, y: 20.0))
    path.line(to: NSPoint(x: 4.487, y: 17.079))
    path.line(to: NSPoint(x: 3.0, y: 17.079))
    path.line(to: NSPoint(x: 3.0, y: 14.05))
    path.line(to: NSPoint(x: 0.0, y: 14.05))
    path.line(to: NSPoint(x: 0.0, y: 10.95))
    path.line(to: NSPoint(x: 3.0, y: 10.95))
    path.line(to: NSPoint(x: 3.0, y: 5.0))
    path.line(to: NSPoint(x: 20.998, y: 5.0))
    path.close()

    path.move(to: NSPoint(x: 6.0, y: 10.949))
    path.line(to: NSPoint(x: 7.488, y: 10.949))
    path.line(to: NSPoint(x: 7.488, y: 8.102))
    path.line(to: NSPoint(x: 6.0, y: 8.102))
    path.close()

    path.move(to: NSPoint(x: 16.51, y: 10.949))
    path.line(to: NSPoint(x: 18.0, y: 10.949))
    path.line(to: NSPoint(x: 18.0, y: 8.102))
    path.line(to: NSPoint(x: 16.51, y: 8.102))
    path.close()

    return path
}

func makeIcon(size: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext.current?.cgContext else {
            NSGraphicsContext.restoreGraphicsState()
            return false
        }

        context.translateBy(x: rect.minX, y: rect.minY + rect.height)
        context.scaleBy(x: rect.width / 24.0, y: -rect.height / 24.0)
        iconColor.setFill()
        makeClaudeCodePath().fill()
        NSGraphicsContext.restoreGraphicsState()
        return true
    }
    image.isTemplate = false
    return image
}

func writePNG(size: Int, filename: String, outputDirectory: URL) throws {
    let image = makeIcon(size: size)
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGenerator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not render \(filename)"])
    }
    try pngData.write(to: outputDirectory.appendingPathComponent(filename), options: .atomic)
}

guard CommandLine.arguments.count == 2 else {
    fputs("usage: IconGenerator <iconset-directory>\n", stderr)
    exit(64)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let icons = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for icon in icons {
    try writePNG(size: icon.0, filename: icon.1, outputDirectory: outputDirectory)
}
