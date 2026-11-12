import AppKit

let destination = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: destination, withIntermediateDirectories: true)

func icon(size: Int) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    let base = NSBezierPath(roundedRect: NSRect(x: 56, y: 56, width: 912, height: 912), xRadius: 208, yRadius: 208)
    // Warm paper, deep ink, and a single clay accent. The empty space is intentional.
    NSGradient(starting: NSColor(srgbRed: 0.98, green: 0.97, blue: 0.94, alpha: 1),
               ending: NSColor(srgbRed: 0.93, green: 0.91, blue: 0.86, alpha: 1))!.draw(in: base, angle: -90)
    let ink = NSColor(srgbRed: 0.14, green: 0.20, blue: 0.17, alpha: 1)
    let clay = NSColor(srgbRed: 0.64, green: 0.39, blue: 0.25, alpha: 1)
    let stroke: CGFloat = size <= 32 ? 44 : 32

    ink.setStroke()
    let bowl = NSBezierPath()
    bowl.move(to: NSPoint(x: 239, y: 498))
    bowl.curve(to: NSPoint(x: 512, y: 277),
               controlPoint1: NSPoint(x: 257, y: 359), controlPoint2: NSPoint(x: 352, y: 277))
    bowl.curve(to: NSPoint(x: 785, y: 498),
               controlPoint1: NSPoint(x: 672, y: 277), controlPoint2: NSPoint(x: 767, y: 359))
    bowl.lineWidth = stroke
    bowl.lineCapStyle = .round
    bowl.lineJoinStyle = .round
    bowl.stroke()

    let rim = NSBezierPath(ovalIn: NSRect(x: 239, y: 465, width: 546, height: 66))
    rim.lineWidth = stroke
    rim.stroke()

    let foot = NSBezierPath()
    foot.move(to: NSPoint(x: 416, y: 216))
    foot.line(to: NSPoint(x: 608, y: 216))
    foot.lineWidth = stroke
    foot.lineCapStyle = .round
    foot.stroke()

    let handle = NSBezierPath()
    handle.move(to: NSPoint(x: 578, y: 660))
    handle.line(to: NSPoint(x: 737, y: 812))
    handle.lineWidth = stroke
    handle.lineCapStyle = .round
    handle.stroke()

    let striker = NSBezierPath()
    striker.move(to: NSPoint(x: 548, y: 632))
    striker.line(to: NSPoint(x: 591, y: 673))
    striker.lineWidth = size <= 32 ? 76 : 66
    striker.lineCapStyle = .round
    clay.setStroke()
    striker.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let bitmap = icon(size: points * scale)
        let suffix = scale == 2 ? "@2x" : ""
        let url = URL(fileURLWithPath: destination).appendingPathComponent("icon_\(points)x\(points)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}
