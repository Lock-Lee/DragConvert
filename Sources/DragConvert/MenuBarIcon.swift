import AppKit

/// ไอคอนบน Menu Bar เป็นวงล้อเหมือนไอคอนแอป (ขาวดำแบบ template ให้ macOS ใส่สีตามธีมเอง)
enum MenuBarIcon {
    /// - Parameter highlight: ช่องที่ทึบ (ใช้ทำแอนิเมชันหมุนตอนกำลังแปลง)
    static func make(highlight: Int = 1) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            let c = NSPoint(x: size / 2, y: size / 2)
            let n = 8
            let inner: CGFloat = 3.6, outer: CGFloat = 8.4
            let step = 360 / CGFloat(n), gap: CGFloat = 9

            for i in 0..<n {
                let a0 = 90 - CGFloat(i) * step - gap / 2
                let a1 = 90 - CGFloat(i + 1) * step + gap / 2
                let p = NSBezierPath()
                p.appendArc(withCenter: c, radius: outer, startAngle: a0, endAngle: a1, clockwise: true)
                p.appendArc(withCenter: c, radius: inner, startAngle: a1, endAngle: a0, clockwise: false)
                p.close()
                NSColor.black.withAlphaComponent(i == highlight % n ? 1 : 0.45).setFill()
                p.fill()
            }
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - 1.6, y: c.y - 1.6, width: 3.2, height: 3.2)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "DragConvert"
        return image
    }
}
