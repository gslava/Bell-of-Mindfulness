import AppKit

/// A small template drawing: macOS supplies the foreground color for each menu bar appearance.
@MainActor
enum MenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()

            let bowl = NSBezierPath()
            bowl.move(to: NSPoint(x: 1.75, y: 9))
            bowl.curve(to: NSPoint(x: 9, y: 3.25),
                       controlPoint1: NSPoint(x: 2.2, y: 5.4), controlPoint2: NSPoint(x: 4.7, y: 3.25))
            bowl.curve(to: NSPoint(x: 16.25, y: 9),
                       controlPoint1: NSPoint(x: 13.3, y: 3.25), controlPoint2: NSPoint(x: 15.8, y: 5.4))
            bowl.lineWidth = 1.3
            bowl.lineCapStyle = .round
            bowl.lineJoinStyle = .round
            bowl.stroke()

            let rim = NSBezierPath(ovalIn: NSRect(x: 1.75, y: 8.15, width: 14.5, height: 1.9))
            rim.lineWidth = 1.2
            rim.stroke()

            let base = NSBezierPath()
            base.move(to: NSPoint(x: 6.3, y: 1.25))
            base.line(to: NSPoint(x: 11.7, y: 1.25))
            base.lineWidth = 1.3
            base.lineCapStyle = .round
            base.stroke()

            let handle = NSBezierPath()
            handle.move(to: NSPoint(x: 10.4, y: 11.7))
            handle.line(to: NSPoint(x: 15.4, y: 16.2))
            handle.lineWidth = 1.4
            handle.lineCapStyle = .round
            handle.stroke()

            let head = NSBezierPath()
            head.move(to: NSPoint(x: 10.1, y: 11.4))
            head.line(to: NSPoint(x: 11.3, y: 12.5))
            head.lineWidth = 2.7
            head.lineCapStyle = .round
            head.stroke()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
