import AppKit

/// หน้าต่างโปร่งใสลอยอยู่บนสุด ไม่แย่งโฟกัสจาก Finder
final class RadialPanel: NSPanel {
    static let size: CGFloat = 600
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
        acceptsMouseMovedEvents = true


        contentView = radial
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(at point: NSPoint, files: [URL], options: [FormatOption], preview: Bool = false) {
        radial.configure(files: files, options: options)
        radial.isPreview = preview

        // ให้วงล้อ (รัศมีราว 260px รวมป้ายชื่อ) อยู่ในจอเสมอ
        var c = point
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) {
            let f = screen.visibleFrame, keep: CGFloat = 260
            c.x = min(max(c.x, f.minX + keep), f.maxX - keep)
            c.y = min(max(c.y, f.minY + keep), f.maxY - keep)
        }
        setFrameOrigin(NSPoint(x: c.x - Self.size / 2, y: c.y - Self.size / 2))

        alphaValue = 1
        orderFrontRegardless()
        radial.playAppear()
    }
}

/// วงล้อเลือกฟอร์แมต ขยายแบบ Dock — ช่องที่ชี้จะใหญ่ขึ้น ช่องข้าง ๆ ขยายลดหลั่นตาม
final class RadialView: NSView {
    var onPick: ((FormatOption, [URL]) -> Void)?
    var isPreview = false

    private var files: [URL] = []
    private var options: [FormatOption] = []
    private var hovered: Int?

    // รูปทรงปกติ
    private let innerRadius: CGFloat = 96      // ขอบในของช่อง (วงกลมกลางใหญ่)
    private let outerRadius: CGFloat = 206     // ขอบนอกของช่อง
    private let hubRadius: CGFloat = 86
    private let gap: CGFloat = 9               // ร่องระหว่างช่อง (px เท่ากันตลอดความยาว)
    private let corner: CGFloat = 16           // ความมนของมุมช่อง
    private let gapDegrees: CGFloat = 0        // ไม่ใช้แล้ว (ร่องคิดเป็น px ด้านล่าง)

    // ปรับความแรงของการขยาย (แบบ Dock)
    private let maxGrow: CGFloat = 44      // ช่องที่ชี้ยื่นออกไปอีกกี่ px
    private let maxWiden: CGFloat = 0.6    // ช่องที่ชี้กว้างขึ้นกี่เท่า (0.6 = +60%)
    private let spread: CGFloat = 1.7      // ผลการขยายลามไปกี่ช่องข้าง ๆ
    private let smoothing: Double = 16     // ยิ่งมากยิ่งตามเมาส์เร็ว

    // สีครีมแบบกระดาษ มีลายเส้นเฉียง
    private let paper = NSColor(red: 0.953, green: 0.937, blue: 0.910, alpha: 1)
    private let paperHover = NSColor(red: 1.0, green: 0.995, blue: 0.985, alpha: 1)
    private let stripe = NSColor(red: 0.55, green: 0.50, blue: 0.42, alpha: 0.10)
    private let ink = NSColor(red: 0.13, green: 0.12, blue: 0.11, alpha: 1)
    private let inkSoft = NSColor(red: 0.13, green: 0.12, blue: 0.11, alpha: 0.5)

    // สถานะแอนิเมชัน
    private var pointer: NSPoint?
    private var anchor: CGFloat = 0        // ตำแหน่งเมาส์ล่าสุด หน่วยเป็น "ช่อง" บนวงล้อปกติ
    private var mag: [CGFloat] = []        // ค่าขยายปัจจุบัน 0...1 ต่อช่อง
    private var tipAlpha: CGFloat = 0
    private var tipIndex: Int?
    private var appear: CGFloat = 1
    private var appearStart: CFTimeInterval = 0
    private var lastTick: CFTimeInterval = 0
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(files: [URL], options: [FormatOption]) {
        self.files = files
        self.options = options
        mag = Array(repeating: 0, count: options.count)
        hovered = nil
        pointer = nil
        tipAlpha = 0
        tipIndex = nil
        needsDisplay = true
    }

    func playAppear() {
        appear = 0
        appearStart = CACurrentMediaTime()
        startAnimating()
    }

    private var center: NSPoint { NSPoint(x: bounds.midX, y: bounds.midY) }
    private var step: CGFloat { 360 / CGFloat(max(options.count, 1)) }

    /// มุมของจุด: 0 = ด้านบน วนตามเข็มนาฬิกา (องศา 0..<360)
    private func angle(of p: NSPoint) -> CGFloat {
        var deg = atan2(p.x - center.x, p.y - center.y) * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }

    // MARK: เลย์เอาต์ที่ขยายแล้ว

    private struct Slice { var start: CGFloat; var end: CGFloat; var outer: CGFloat }

    /// คำนวณมุมของแต่ละช่องตามค่าขยายปัจจุบัน
    /// แล้วหมุนทั้งวงให้จุดใต้เมาส์อยู่กับที่ (เหมือน Dock ที่ไอคอนใต้เมาส์ไม่ไหล)
    private func sliceLayout() -> [Slice] {
        let n = options.count
        guard n > 0, mag.count == n else { return [] }
        let weights = mag.map { 1 + $0 * maxWiden }
        let total = weights.reduce(0, +)
        let unit = 360 / total

        var starts: [CGFloat] = []
        var a: CGFloat = 0
        for w in weights { starts.append(a); a += w * unit }

        let i = min(Int(anchor), n - 1)
        let frac = anchor - CGFloat(i)
        let dynamicAnchor = starts[i] + frac * weights[i] * unit
        let rotate = anchor * step - dynamicAnchor

        return (0..<n).map { k in
            Slice(start: starts[k] + rotate,
                  end: starts[k] + weights[k] * unit + rotate,
                  outer: outerRadius + mag[k] * maxGrow)
        }
    }

    private func index(at p: NSPoint, in slices: [Slice]) -> Int? {
        guard !slices.isEmpty else { return nil }
        let dist = hypot(p.x - center.x, p.y - center.y)
        guard dist > innerRadius else { return nil }
        let a = angle(of: p)
        for (k, s) in slices.enumerated() {
            let rel = (a - s.start).truncatingRemainder(dividingBy: 360)
            let r = rel < 0 ? rel + 360 : rel
            if r < s.end - s.start {
                return dist < s.outer + 36 ? k : nil
            }
        }
        return nil
    }

    /// ช่องรูปพัดมุมมน: หดเข้าด้านในเท่ากับ corner แล้วขยายกลับด้วยเส้นขอบปลายมน
    private func sliceCGPath(_ s: Slice) -> CGPath {
        let rIn = innerRadius + corner, rOut = s.outer - 10 - corner
        let halfGap = gap / 2 + corner
        // มุมที่ต้องหดเพื่อให้ร่องกว้างเท่ากันทั้งด้านในและด้านนอก
        let dIn = asin(min(1, halfGap / rIn)) * 180 / .pi
        let dOut = asin(min(1, halfGap / rOut)) * 180 / .pi
        func rad(_ deg: CGFloat) -> CGFloat { (90 - deg) * .pi / 180 }

        let core = CGMutablePath()
        core.addArc(center: center, radius: rOut, startAngle: rad(s.start + dOut), endAngle: rad(s.end - dOut), clockwise: true)
        core.addArc(center: center, radius: rIn, startAngle: rad(s.end - dIn), endAngle: rad(s.start + dIn), clockwise: false)
        core.closeSubpath()

        let rim = core.copy(strokingWithWidth: corner * 2, lineCap: .round, lineJoin: .round, miterLimit: 10)
        let shape = CGMutablePath()
        shape.addPath(core)
        shape.addPath(rim)
        return shape
    }

    private var hubCGPath: CGPath {
        CGPath(ellipseIn: CGRect(x: center.x - hubRadius, y: center.y - hubRadius,
                                 width: hubRadius * 2, height: hubRadius * 2), transform: nil)
    }

    /// เติมสีกระดาษ + ลายเส้นเฉียง + เงา ให้รูปทรงที่ส่งมา
    private func fillPaper(_ ctx: CGContext, _ path: CGPath, color: NSColor, lift: CGFloat) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2 - lift * 4), blur: 6 + lift * 14,
                      color: NSColor.black.withAlphaComponent(0.16 + lift * 0.10).cgColor)
        ctx.addPath(path)
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let box = path.boundingBox
        ctx.setStrokeColor(stripe.cgColor)
        ctx.setLineWidth(0.8)
        var x = box.minX - box.height
        while x < box.maxX {
            ctx.move(to: CGPoint(x: x, y: box.minY))
            ctx.addLine(to: CGPoint(x: x + box.height, y: box.maxY))
            x += 3.2
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    // MARK: แอนิเมชัน

    private func setPointer(_ p: NSPoint?) {
        pointer = p
        if let p {
            anchor = min(angle(of: p) / step, CGFloat(options.count) - 0.0001)
        }
        refreshHover()
        startAnimating()
    }

    private func refreshHover() {
        let new = pointer.flatMap { index(at: $0, in: sliceLayout()) }
        if new != hovered {
            hovered = new
            if let new {
                tipIndex = new
                NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
        }
    }

    /// ค่าขยายเป้าหมายของแต่ละช่อง ตามระยะห่างเชิงมุมจากเมาส์ (โค้งแบบ smoothstep)
    private func targets() -> [CGFloat] {
        let n = options.count
        guard let p = pointer, n > 0 else { return Array(repeating: 0, count: n) }
        let dist = hypot(p.x - center.x, p.y - center.y)
        guard dist > hubRadius, dist < outerRadius + maxGrow + 60 else {
            return Array(repeating: 0, count: n)
        }
        return (0..<n).map { k in
            var d = abs(anchor - (CGFloat(k) + 0.5))
            d = min(d, CGFloat(n) - d)
            let t = max(0, 1 - d / spread)
            return t * t * (3 - 2 * t)
        }
    }

    private func startAnimating() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 120.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTick, 1.0 / 20.0)
        lastTick = now
        if advance(dt: dt, now: now) {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: ขับแอนิเมชันเองทีละเฟรม (ใช้เรนเดอร์ GIF ตัวอย่าง)

    func demoAppear(at now: CFTimeInterval) {
        appear = 0
        appearStart = now
    }

    func demoStep(pointer p: NSPoint?, dt: Double, now: CFTimeInterval) {
        pointer = p
        if let p { anchor = min(angle(of: p) / step, CGFloat(options.count) - 0.0001) }
        _ = advance(dt: dt, now: now)
    }

    var hoveredOption: FormatOption? { hovered.map { options[$0] } }

    /// เดินแอนิเมชันไป dt วินาที คืนค่า true เมื่อทุกอย่างหยุดนิ่งแล้ว
    private func advance(dt: Double, now: CFTimeInterval) -> Bool {
        let k = CGFloat(1 - exp(-dt * smoothing))

        var settled = true
        let goal = targets()
        for i in mag.indices {
            mag[i] += (goal[i] - mag[i]) * k
            if abs(goal[i] - mag[i]) > 0.002 { settled = false } else { mag[i] = goal[i] }
        }

        refreshHover()

        let tipGoal: CGFloat = hovered == nil ? 0 : 1
        tipAlpha += (tipGoal - tipAlpha) * CGFloat(1 - exp(-dt * 22))
        if abs(tipGoal - tipAlpha) > 0.01 { settled = false } else { tipAlpha = tipGoal }

        if appear < 1 || now - appearStart < 0.4 {
            let t = min(CGFloat((now - appearStart) / 0.32), 1)
            appear = t >= 1 ? 1 : Self.easeOutBack(t)
            if t < 1 { settled = false }
        }

        needsDisplay = true
        return settled
    }

    /// เด้งเกินนิดหนึ่งแล้วกลับ ตอนวงล้อโผล่
    private static func easeOutBack(_ t: CGFloat) -> CGFloat {
        let c1: CGFloat = 1.5, c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
    }

    // MARK: วาด

    override func draw(_ dirtyRect: NSRect) {
        guard !options.isEmpty, let ctx = NSGraphicsContext.current?.cgContext else { return }

        let scale = max(appear, 0.01)
        let baseAlpha = min(1, max(0, appear * 1.6))

        ctx.saveGState()
        ctx.setAlpha(baseAlpha)
        ctx.translateBy(x: center.x, y: center.y)
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -center.x, y: -center.y)

        let slices = sliceLayout()
        let order = slices.indices.sorted { mag[$0] < mag[$1] }   // ช่องที่ใหญ่สุดวาดทีหลัง อยู่บนสุด

        for i in order {
            let s = slices[i]
            let m = mag[i]
            fillPaper(ctx, sliceCGPath(s), color: hovered == i ? paperHover : paper, lift: m)

            let mid: CGFloat = (s.start + s.end) / 2 * CGFloat.pi / 180
            let r = (innerRadius + s.outer - 10) / 2 + m * 2
            let p = NSPoint(x: center.x + sin(mid) * r, y: center.y + cos(mid) * r)
            let grow = 1 + m * 0.28
            drawCentered(options[i].title, at: NSPoint(x: p.x, y: p.y + 9 * grow),
                         font: .systemFont(ofSize: 19 * grow, weight: .regular), color: ink)
            drawCentered(options[i].detail, at: NSPoint(x: p.x, y: p.y - 12 * grow),
                         font: .systemFont(ofSize: 13 * grow, weight: .regular), color: inkSoft)
        }

        // วงกลมกลาง
        fillPaper(ctx, hubCGPath, color: paper, lift: 0)
        let ext = files.first?.pathExtension.uppercased() ?? ""
        drawCentered("\(files.count) × \(ext)", at: NSPoint(x: center.x, y: center.y + 13),
                     font: .systemFont(ofSize: 24, weight: .regular), color: ink)
        drawCentered(isPreview ? "คลิกเพื่อปิด" : "ปล่อยตรงนี้ = ยกเลิก",
                     at: NSPoint(x: center.x, y: center.y - 17),
                     font: .systemFont(ofSize: 13, weight: .regular), color: inkSoft)

        // ป้ายชื่อแบบ Dock
        if let t = tipIndex, t < slices.count, tipAlpha > 0.01 {
            ctx.setAlpha(baseAlpha * tipAlpha)
            drawTooltip(for: options[t], slice: slices[t])
        }

        ctx.restoreGState()
    }

    /// ป้ายชื่อเม็ดยาสีเข้ม ลอยถัดจากขอบนอกของช่อง (แบบป้ายชื่อใน Dock)
    private func drawTooltip(for option: FormatOption, slice s: Slice) {
        let label = "\(option.title) · \(option.detail)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: NSColor.white,
        ]
        let size = (label as NSString).size(withAttributes: attrs)
        let w = size.width + 24, h = size.height + 10

        let mid: CGFloat = (s.start + s.end) / 2 * CGFloat.pi / 180
        let u = CGPoint(x: sin(mid), y: cos(mid))
        let lift = (1 - tipAlpha) * 8
        let edge = s.outer - 10 + 10 + lift
        // ระยะจากจุดกลางกล่องถึงขอบ ในทิศ u (ใช้กล่องเม็ดยา ≈ วงรี)
        let reach = 1 / sqrt(pow(u.x / (w / 2), 2) + pow(u.y / (h / 2), 2))
        let c = CGPoint(x: center.x + u.x * (edge + reach), y: center.y + u.y * (edge + reach))
        let rect = NSRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
        let bubble = NSBezierPath(roundedRect: rect, xRadius: h / 2, yRadius: h / 2)

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = NSSize(width: 0, height: -2)

        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor(white: 0.2, alpha: 0.92).setFill()
        bubble.fill()
        NSGraphicsContext.restoreGraphicsState()

        (label as NSString).draw(at: NSPoint(x: c.x - size.width / 2, y: c.y - size.height / 2), withAttributes: attrs)
    }

    private func drawCentered(_ string: String, at point: NSPoint, font: NSFont, color: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
        let size = (string as NSString).size(withAttributes: attrs)
        (string as NSString).draw(at: NSPoint(x: point.x - size.width / 2, y: point.y - size.height / 2),
                                  withAttributes: attrs)
    }

    // MARK: โหมดตัวอย่าง: ชี้เมาส์ดูแอนิเมชัน คลิกเพื่อปิด

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                       options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        guard isPreview else { return }
        setPointer(convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) {
        if isPreview { setPointer(nil) }
    }

    override func mouseDown(with event: NSEvent) {
        if isPreview { window?.orderOut(nil) }
    }

    // MARK: รับไฟล์ที่ลากมาปล่อย

    private func update(_ sender: NSDraggingInfo) -> NSDragOperation {
        setPointer(convert(sender.draggingLocation, from: nil))
        return hovered == nil ? [] : .copy
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { update(sender) }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        setPointer(nil)
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
        setPointer(nil)
        window?.orderOut(nil)
    }
}
