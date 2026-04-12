import AppKit
import Foundation

struct IconRenderer {
    let size: CGFloat

    func draw() -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()

        let bounds = NSRect(x: 0, y: 0, width: size, height: size)
        let radius = size * 0.23
        let background = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)

        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.06, green: 0.16, blue: 0.27, alpha: 1.0),
            NSColor(calibratedRed: 0.09, green: 0.48, blue: 0.55, alpha: 1.0),
            NSColor(calibratedRed: 0.95, green: 0.66, blue: 0.24, alpha: 1.0)
        ])!
        gradient.draw(in: background, angle: -35)

        NSGraphicsContext.current?.imageInterpolation = .high

        let glow = NSBezierPath(ovalIn: NSRect(
            x: size * 0.10,
            y: size * 0.58,
            width: size * 0.80,
            height: size * 0.42
        ))
        NSColor(calibratedWhite: 1.0, alpha: 0.10).setFill()
        glow.fill()

        let panel = NSBezierPath(roundedRect: NSRect(
            x: size * 0.15,
            y: size * 0.16,
            width: size * 0.70,
            height: size * 0.58
        ), xRadius: size * 0.08, yRadius: size * 0.08)
        NSColor(calibratedWhite: 0.08, alpha: 0.32).setFill()
        panel.fill()

        let barWidths = size * 0.11
        let gap = size * 0.06
        let startX = size * 0.25
        let baseY = size * 0.24
        let heights: [CGFloat] = [0.18, 0.30, 0.42]
        let colors = [
            NSColor(calibratedRed: 0.76, green: 0.94, blue: 0.92, alpha: 1.0),
            NSColor(calibratedRed: 0.56, green: 0.95, blue: 0.75, alpha: 1.0),
            NSColor(calibratedRed: 1.00, green: 0.95, blue: 0.76, alpha: 1.0)
        ]

        for index in 0..<heights.count {
            let rect = NSRect(
                x: startX + CGFloat(index) * (barWidths + gap),
                y: baseY,
                width: barWidths,
                height: size * heights[index]
            )
            let path = NSBezierPath(roundedRect: rect, xRadius: barWidths * 0.40, yRadius: barWidths * 0.40)
            colors[index].setFill()
            path.fill()
        }

        let check = NSBezierPath()
        check.lineWidth = size * 0.045
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        check.move(to: NSPoint(x: size * 0.31, y: size * 0.60))
        check.line(to: NSPoint(x: size * 0.43, y: size * 0.48))
        check.line(to: NSPoint(x: size * 0.69, y: size * 0.71))
        NSColor.white.setStroke()
        check.stroke()

        let badgeRect = NSRect(x: size * 0.62, y: size * 0.12, width: size * 0.18, height: size * 0.18)
        let badge = NSBezierPath(ovalIn: badgeRect)
        NSColor(calibratedRed: 0.96, green: 0.29, blue: 0.27, alpha: 1.0).setFill()
        badge.fill()

        let plus = NSBezierPath()
        plus.lineWidth = size * 0.028
        plus.lineCapStyle = .round
        let midX = badgeRect.midX
        let midY = badgeRect.midY
        plus.move(to: NSPoint(x: midX, y: midY - size * 0.038))
        plus.line(to: NSPoint(x: midX, y: midY + size * 0.038))
        plus.move(to: NSPoint(x: midX - size * 0.038, y: midY))
        plus.line(to: NSPoint(x: midX + size * 0.038, y: midY))
        NSColor.white.setStroke()
        plus.stroke()

        image.unlockFocus()
        return image
    }
}

func pngData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
        return nil
    }
    return bitmap.representation(using: .png, properties: [:])
}

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
    fputs("usage: generate_app_icon.swift <size> <output.png>\n", stderr)
    exit(1)
}

guard let pointSize = Double(arguments[1]) else {
    fputs("invalid size: \(arguments[1])\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[2])
let image = IconRenderer(size: CGFloat(pointSize)).draw()

guard let data = pngData(from: image) else {
    fputs("failed to encode png\n", stderr)
    exit(1)
}

try data.write(to: outputURL)
