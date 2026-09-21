import AppKit
import Foundation

struct MenuRow {
    enum Kind {
        case item(String, checked: Bool, shortcut: String?)
        case separator
    }

    let kind: Kind
}

/// Labels must match GameModeBar.swift (example shows both features enabled → Toggle → OFF).
enum MenuScreenshot {
    static let rows: [MenuRow] = [
        .init(kind: .item("Toggle → OFF", checked: false, shortcut: nil)),
        .init(kind: .separator),
        .init(kind: .item("macOS Game Mode", checked: true, shortcut: nil)),
        .init(kind: .item("No AirDrop", checked: true, shortcut: nil)),
        .init(kind: .separator),
        .init(kind: .item("Check Permissions…", checked: false, shortcut: nil)),
        .init(kind: .separator),
        .init(kind: .item("Quit", checked: false, shortcut: "⌘Q")),
    ]

    static func render(to output: URL) throws {
        let width: CGFloat = 248
        let rowHeight: CGFloat = 22
        let separatorHeight: CGFloat = 9
        let pad: CGFloat = 6
        var height = pad * 2
        for row in rows {
            switch row.kind {
            case .separator:
                height += separatorHeight
            case .item:
                height += rowHeight
            }
        }

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        let bg = NSColor(calibratedWhite: 0.16, alpha: 0.98)
        let path = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: width, height: height), xRadius: 8, yRadius: 8)
        bg.setFill()
        path.fill()

        let textColor = NSColor(calibratedWhite: 0.92, alpha: 1)
        let shortcutColor = NSColor(calibratedWhite: 0.55, alpha: 1)
        let titleFont = NSFont.menuFont(ofSize: NSFont.systemFontSize)
        let shortcutFont = NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)

        var y = height - pad
        for row in rows {
            switch row.kind {
            case .separator:
                y -= separatorHeight
                NSColor(calibratedWhite: 0.28, alpha: 1).setFill()
                NSRect(x: 12, y: y + 4, width: width - 24, height: 1).fill()
            case let .item(title, checked, shortcut):
                y -= rowHeight
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: titleFont,
                    .foregroundColor: textColor,
                ]
                var x: CGFloat = 16
                if checked {
                    "✓".draw(at: NSPoint(x: x, y: y + 3), withAttributes: attrs)
                    x += 16
                }
                title.draw(at: NSPoint(x: x, y: y + 3), withAttributes: attrs)
                if let shortcut {
                    let sAttrs: [NSAttributedString.Key: Any] = [
                        .font: shortcutFont,
                        .foregroundColor: shortcutColor,
                    ]
                    let size = (shortcut as NSString).size(withAttributes: sAttrs)
                    (shortcut as NSString).draw(
                        at: NSPoint(x: width - pad - size.width, y: y + 4),
                        withAttributes: sAttrs
                    )
                }
            }
        }

        image.unlockFocus()

        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else {
            throw NSError(
                domain: "MenuScreenshot",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "PNG encode failed."]
            )
        }
        try png.write(to: output)
    }
}

let outputPath = CommandLine.arguments.dropFirst().first
guard let outputPath else {
    fputs("Usage: render-menu-screenshot <output.png>\n", stderr)
    exit(64)
}

do {
    try MenuScreenshot.render(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("\(error.localizedDescription)\n", stderr)
    exit(1)
}
