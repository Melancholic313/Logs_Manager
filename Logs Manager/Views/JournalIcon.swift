import AppKit

enum JournalIcon {
    static func templateImage(size: NSSize = NSSize(width: 18, height: 18)) -> NSImage {
        let image = NSImage(size: size)
        image.isTemplate = true

        image.lockFocus()

        let rect = NSRect(x: 1.5, y: 1.5, width: size.width - 3, height: size.height - 3)
        let journalPath = NSBezierPath(
            roundedRect: rect,
            xRadius: 2.2,
            yRadius: 2.2
        )
        NSColor.black.setFill()
        journalPath.fill()

        guard let context = NSGraphicsContext.current else {
            image.unlockFocus()
            return image
        }

        context.compositingOperation = .destinationOut
        NSColor.white.setFill()

        // Корешок журнала.
        NSBezierPath(rect: NSRect(x: 4.2, y: 3.2, width: 1.1, height: size.height - 6.4)).fill()

        // Строки на странице.
        let lineHeight: CGFloat = 1.15
        let lineStartX: CGFloat = 6.5
        let lineWidth = size.width - 9.0
        var y: CGFloat = 5.0
        while y + lineHeight < size.height - 4 {
            NSBezierPath(rect: NSRect(x: lineStartX, y: y, width: lineWidth, height: lineHeight)).fill()
            y += lineHeight + 2.0
        }

        context.compositingOperation = .sourceOver
        image.unlockFocus()
        return image
    }
}
