import AppKit

/// หน้าต่างโปร่งใสลอยอยู่บนสุด ไม่แย่งโฟกัสจาก Finder
final class RadialPanel: NSPanel {
    static let size: CGFloat = 400
    let radial = RadialView(frame: NSRect(x: 0, y: 0, width: RadialPanel.size, height: RadialPanel.size))

    convenience init() {
        self.init(
            contentRect: NSRect(x: 0, y: 0, width: Self.size, height: Self.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        contentView = radial
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(at point: NSPoint, files: [URL], options: [FormatOption], preview: Bool = false) {
        radial.configure(files: files, options: options)
        radial.isPreview = preview

        var origin = NSPoint(x: point.x - Self.size / 2, y: point.y - Self.size / 2)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) {
            let f = screen.visibleFrame
            origin.x = min(max(origin.x, f.minX), f.maxX - Self.size)
            origin.y = min(max(origin.y, f.minY), f.maxY - Self.size)
        }
        setFrameOrigin(origin)

        alphaValue = 0
        orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            animator().alphaValue = 1
        }
    }
}

/// วงล้อเลือกฟอร์แมต — ลากไฟล์ไปปล่อยบนช่องที่ต้องการ ปล่อยตรงกลาง = ยกเลิก
final class RadialView: NSView {
    var onPick: ((FormatOption, [URL]) -> Void)?
    var isPreview = false

    private var files: [URL] = []
    private var options: [FormatOption] = []
    private var hovered: Int?

    private let innerRadius: CGFloat = 72
    private let outerRadius: CGFloat = 190
    private let gapDegrees: CGFloat = 1.6

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    // โหมดตัวอย่าง: ชี้เมาส์แล้วไฮไลต์ คลิกเพื่อปิด
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        guard isPreview else { return }
        let new = index(at: convert(event.locationInWindow, from: nil))
        if new != hovered { hovered = new; needsDisplay = true }
    }

    override func mouseDown(with event: NSEvent) {
        if isPreview { window?.orderOut(nil) }
    }

    func configure(files: [URL], options: [FormatOption]) {
        self.files = files
        self.options = options
        hovered = nil
        needsDisplay = true
    }

    private var center: NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }
    private var step: CGFloat { 360 / CGFloat(max(options.count, 1)) }

    /// หาว่าเมาส์อยู่ช่องไหน (0 องศา = ด้านบน วนตามเข็มนาฬิกา)
    private func index(at point: NSPoint) -> Int? {
        let dx = point.x - center.x, dy = point.y - center.y
        let dist = hypot(dx, dy)
        guard dist > innerRadius, dist < outerRadius + 40, !options.isEmpty else { return nil }
        var deg = atan2(dx, dy) * 180 / .pi
        if deg < 0 { deg += 360 }
        return min(Int(deg / step), options.count - 1)
    }

    // MARK: วาด

    override func draw(_ dirtyRect: NSRect) {
        guard !options.isEmpty else { return }
        let dark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let fill = dark ? NSColor(white: 0.16, alpha: 0.96) : NSColor(white: 0.98, alpha: 0.97)
        let text = dark ? NSColor.white : NSColor(white: 0.12, alpha: 1)
        let subtle = text.withAlphaComponent(0.55)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowBlurRadius = 14
        shadow.shadowOffset = NSSize(width: 0, height: -3)

        for (i, option) in options.enumerated() {
            let start = CGFloat(i) * step + gapDegrees / 2
            let end = CGFloat(i + 1) * step - gapDegrees / 2
            let isHover = hovered == i

            // แปลงจาก "0 = บน, ตามเข็ม" เป็นมุมแบบ AppKit (0 = ขวา, ทวนเข็ม)
            let path = NSBezierPath()
            path.appendArc(withCenter: center, radius: outerRadius - 10, startAngle: 90 - start, endAngle: 90 - end, clockwise: true)
            path.appendArc(withCenter: center, radius: innerRadius, startAngle: 90 - end, endAngle: 90 - start, clockwise: false)
            path.close()

            NSGraphicsContext.saveGraphicsState()
            shadow.set()
            (isHover ? NSColor.controlAccentColor : fill).setFill()
            path.fill()
            NSGraphicsContext.restoreGraphicsState()

            let mid = (start + end) / 2 * .pi / 180
            let r = (innerRadius + outerRadius - 10) / 2
            let p = NSPoint(x: center.x + sin(mid) * r, y: center.y + cos(mid) * r)
            let titleColor = isHover ? NSColor.white : text
            let detailColor = isHover ? NSColor.white.withAlphaComponent(0.8) : subtle
            drawCentered(option.title, at: NSPoint(x: p.x, y: p.y + 8),
                         font: .systemFont(ofSize: 15, weight: .semibold), color: titleColor)
            drawCentered(option.detail, at: NSPoint(x: p.x, y: p.y - 10),
                         font: .systemFont(ofSize: 11, weight: .medium), color: detailColor)
        }

        // วงกลมตรงกลาง
        let hub = NSBezierPath(ovalIn: NSRect(x: center.x - innerRadius + 8, y: center.y - innerRadius + 8,
                                              width: (innerRadius - 8) * 2, height: (innerRadius - 8) * 2))
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        fill.setFill()
        hub.fill()
        NSGraphicsContext.restoreGraphicsState()

        let ext = files.first?.pathExtension.uppercased() ?? ""
        drawCentered("\(files.count) × \(ext)", at: NSPoint(x: center.x, y: center.y + 10),
                     font: .systemFont(ofSize: 17, weight: .bold), color: text)
        drawCentered("ปล่อยตรงนี้ = ยกเลิก", at: NSPoint(x: center.x, y: center.y - 12),
                     font: .systemFont(ofSize: 10, weight: .regular), color: subtle)
    }

    private func drawCentered(_ string: String, at point: NSPoint, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (string as NSString).size(withAttributes: attrs)
        (string as NSString).draw(at: NSPoint(x: point.x - size.width / 2, y: point.y - size.height / 2),
                                  withAttributes: attrs)
    }

    // MARK: รับไฟล์ที่ลากมาปล่อย

    private func update(_ sender: NSDraggingInfo) -> NSDragOperation {
        let point = convert(sender.draggingLocation, from: nil)
        let new = index(at: point)
        if new != hovered {
            hovered = new
            needsDisplay = true
            if new != nil {
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
        return hovered == nil ? [] : .copy
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        hovered = nil
        needsDisplay = true
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { hovered != nil }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let i = hovered, i < options.count else { return false }
        let dropped = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        let kind = files.first.map(FileKind.of)
        let targets = dropped.isEmpty ? files : dropped.filter { FileKind.of($0) == kind }
        onPick?(options[i], targets)
        return true
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        hovered = nil
        window?.orderOut(nil)
    }
}
