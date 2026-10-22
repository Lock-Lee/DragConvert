import AppKit
import UniformTypeIdentifiers

/// เรนเดอร์เฟรมตัวอย่างการใช้งาน (ใช้วงล้อตัวจริง) เป็น PNG ทีละเฟรม
/// รัน: DragConvert --render-demo <โฟลเดอร์>  แล้วต่อเป็น GIF ด้วย scripts/make_gifs.sh
@MainActor
enum DemoRenderer {
    static let W: CGFloat = 640, H: CGFloat = 600, fps = 30.0, scale: CGFloat = 2

    static func run(outDir: String) {
        let out = URL(fileURLWithPath: outDir)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let sample = URL(fileURLWithPath: "/tmp/My Movie.mov")
        let options = Formats.options(for: sample)
        let view = RadialView(frame: NSRect(x: 0, y: 0, width: RadialPanel.size, height: RadialPanel.size))
        view.appearance = NSAppearance(named: .aqua)
        view.configure(files: [sample], options: options)

        let movIcon = NSWorkspace.shared.icon(for: .quickTimeMovie)
        let mp4Icon = NSWorkspace.shared.icon(for: .mpeg4Movie)

        // ตำแหน่งต่าง ๆ (พิกัด AppKit: ล่างซ้าย = 0,0)
        let wheelC = NSPoint(x: W / 2 + 24, y: H / 2 - 6)
        let fileAt = NSPoint(x: 78, y: H - 92)
        let newFileAt = NSPoint(x: 78, y: H - 210)
        let ringR: CGFloat = 150

        // จุดเมาส์บนวงล้อ ตามมุม (0 = บน วนตามเข็ม)
        func onRing(_ deg: CGFloat) -> NSPoint {
            let a = deg * .pi / 180
            return NSPoint(x: wheelC.x + sin(a) * ringR, y: wheelC.y + cos(a) * ringR)
        }

        // คีย์เฟรมมุม (วินาที, องศา) ระหว่างกวาดดูตัวเลือก — จบที่ "MP4 720p"
        let step = 360 / CGFloat(options.count)
        let target = CGFloat(options.firstIndex { $0.detail == "720p" } ?? 1)
        let sweep: [(Double, CGFloat)] = [
            (1.45, 290), (2.3, 345), (2.8, 360 + step * 0.5),
            (3.6, 360 + step * 3.5), (4.0, 360 + step * 3.5),
            (4.7, 360 + step * (target + 0.5)), (5.3, 360 + step * (target + 0.5)),
        ]

        func ease(_ t: Double) -> CGFloat { let x = CGFloat(max(0, min(1, t))); return x * x * (3 - 2 * x) }
        func lerp(_ a: NSPoint, _ b: NSPoint, _ t: CGFloat) -> NSPoint {
            NSPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
        }
        func angleAt(_ t: Double) -> CGFloat {
            for i in 1..<sweep.count where t <= sweep[i].0 {
                let (t0, a0) = sweep[i - 1], (t1, a1) = sweep[i]
                return a0 + (a1 - a0) * ease((t - t0) / (t1 - t0))
            }
            return sweep.last!.1
        }

        let duration = 7.4, dropAt = 5.35
        let appearAt = 1.15, enterStart = 0.55, enterEnd = 1.4
        let entry = onRing(sweep[0].1)
        let frames = Int(duration * fps)
        var resultName = "My Movie-720p.mp4"

        for f in 0..<frames {
            let t = Double(f) / fps
            if abs(t - appearAt) < 0.5 / fps { view.demoAppear(at: t) }

            // ตำแหน่งเมาส์
            var cursor: NSPoint
            if t < enterStart { cursor = fileAt }
            else if t < enterEnd { cursor = lerp(fileAt, entry, ease((t - enterStart) / (enterEnd - enterStart))) }
            else if t < dropAt { cursor = onRing(angleAt(t)) }
            else { cursor = onRing(angleAt(dropAt)) }

            let wheelVisible = t >= appearAt && t < dropAt + 0.25
            if t >= appearAt && t < dropAt {
                let local = NSPoint(x: cursor.x - wheelC.x + view.bounds.midX, y: cursor.y - wheelC.y + view.bounds.midY)
                view.demoStep(pointer: t >= enterEnd - 0.1 ? local : nil, dt: 1 / fps, now: t)
                if let o = view.hoveredOption { resultName = "My Movie\(o.suffix).\(o.ext)" }
            } else if t >= appearAt {
                view.demoStep(pointer: nil, dt: 1 / fps, now: t)
            }

            let dragging = t >= enterStart && t < dropAt
            let shiftAlpha: CGFloat = t < 0.95 ? 0 : (t < dropAt ? min(1, CGFloat((t - 0.95) / 0.15)) : max(0, 1 - CGFloat((t - dropAt) / 0.2)))
            let wheelAlpha: CGFloat = t < dropAt ? 1 : max(0, 1 - CGFloat((t - dropAt) / 0.25))
            let newFile: CGFloat = t < dropAt + 0.35 ? 0 : min(1, CGFloat((t - dropAt - 0.35) / 0.3))

            let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                                       bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                       colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            rep.size = NSSize(width: W, height: H)
            NSGraphicsContext.saveGraphicsState()
            let gctx = NSGraphicsContext(bitmapImageRep: rep)!
            NSGraphicsContext.current = gctx
            let ctx = gctx.cgContext

            drawBackdrop(ctx)
            drawFile(movIcon, name: "My Movie.mov", at: fileAt, alpha: 1, selected: dragging)
            if newFile > 0 {
                drawFile(mp4Icon, name: resultName, at: newFileAt, alpha: newFile,
                         selected: true, pop: 0.85 + 0.15 * newFile)
            }

            if wheelVisible {
                ctx.saveGState()
                ctx.setAlpha(wheelAlpha)
                ctx.beginTransparencyLayer(auxiliaryInfo: nil)
                ctx.translateBy(x: wheelC.x - view.bounds.midX, y: wheelC.y - view.bounds.midY)
                view.draw(view.bounds)
                ctx.endTransparencyLayer()
                ctx.restoreGState()
            }

            if dragging { drawGhost(movIcon, at: cursor) }
            if shiftAlpha > 0 { drawKeycap("⇧ shift", at: NSPoint(x: W - 96, y: 38), alpha: shiftAlpha) }
            if newFile > 0 { drawToast("✓  แปลงเสร็จ: \(resultName)", alpha: newFile) }
            drawCursor(at: cursor)

            NSGraphicsContext.restoreGraphicsState()
            let name = String(format: "f%04d.png", f)
            try? rep.representation(using: .png, properties: [:])?.write(to: out.appendingPathComponent(name))
        }
        print("✓ \(frames) frames → \(outDir)")
    }

    // MARK: ชิ้นส่วนภาพ

    private static func drawBackdrop(_ ctx: CGContext) {
        // ฟ้าเรียบ ๆ แบบในคลิปต้นแบบ (สีน้อย = GIF เล็ก)
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [NSColor(red: 0.49, green: 0.64, blue: 0.81, alpha: 1).cgColor,
                                    NSColor(red: 0.40, green: 0.56, blue: 0.75, alpha: 1).cgColor] as CFArray,
                           locations: [0, 1])!
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: H), end: CGPoint(x: 0, y: 0), options: [])
    }

    private static func drawFile(_ icon: NSImage, name: String, at p: NSPoint, alpha: CGFloat,
                                 selected: Bool, pop: CGFloat = 1) {
        let s: CGFloat = 64 * pop
        if selected {
            NSColor.black.withAlphaComponent(0.18 * alpha).setFill()
            NSBezierPath(roundedRect: NSRect(x: p.x - 40, y: p.y - 36, width: 80, height: 76), xRadius: 8, yRadius: 8).fill()
        }
        icon.draw(in: NSRect(x: p.x - s / 2, y: p.y - s / 2 + 4, width: s, height: s),
                  from: .zero, operation: .sourceOver, fraction: alpha)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
            .shadow: { let sh = NSShadow(); sh.shadowColor = .black.withAlphaComponent(0.6); sh.shadowBlurRadius = 3; return sh }(),
        ]
        let size = (name as NSString).size(withAttributes: attrs)
        (name as NSString).draw(at: NSPoint(x: p.x - size.width / 2, y: p.y - 52), withAttributes: attrs)
    }

    private static func drawGhost(_ icon: NSImage, at p: NSPoint) {
        icon.draw(in: NSRect(x: p.x + 6, y: p.y - 46, width: 34, height: 34),
                  from: .zero, operation: .sourceOver, fraction: 0.55)
    }

    private static func drawCursor(at p: NSPoint) {
        // ลูกศรเมาส์แบบ macOS (ปลายอยู่ที่ p)
        let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, -17), (4, -13), (7, -20), (10, -19), (7, -12), (12, -12)]
        let path = NSBezierPath()
        path.move(to: NSPoint(x: p.x + pts[0].0, y: p.y + pts[0].1))
        for q in pts.dropFirst() { path.line(to: NSPoint(x: p.x + q.0, y: p.y + q.1)) }
        path.close()
        let sh = NSShadow(); sh.shadowColor = .black.withAlphaComponent(0.4); sh.shadowBlurRadius = 2; sh.shadowOffset = NSSize(width: 0, height: -1)
        NSGraphicsContext.saveGraphicsState()
        sh.set()
        NSColor.black.setFill(); path.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.setStroke(); path.lineWidth = 1.2; path.stroke()
    }

    private static func drawKeycap(_ text: String, at c: NSPoint, alpha: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor(white: 0.15, alpha: alpha),
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let r = NSRect(x: c.x - size.width / 2 - 16, y: c.y - 17, width: size.width + 32, height: 34)
        let sh = NSShadow(); sh.shadowColor = .black.withAlphaComponent(0.3 * alpha); sh.shadowBlurRadius = 6; sh.shadowOffset = NSSize(width: 0, height: -3)
        NSGraphicsContext.saveGraphicsState()
        sh.set()
        NSColor.white.withAlphaComponent(0.92 * alpha).setFill()
        NSBezierPath(roundedRect: r, xRadius: 8, yRadius: 8).fill()
        NSGraphicsContext.restoreGraphicsState()
        (text as NSString).draw(at: NSPoint(x: c.x - size.width / 2, y: c.y - size.height / 2), withAttributes: attrs)
    }

    private static func drawToast(_ text: String, alpha: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        ]
        let size = (text as NSString).size(withAttributes: attrs)
        let y: CGFloat = 34 + (1 - alpha) * -10
        let r = NSRect(x: W / 2 - size.width / 2 - 18, y: y, width: size.width + 36, height: 34)
        NSColor(white: 0.15, alpha: 0.88 * alpha).setFill()
        NSBezierPath(roundedRect: r, xRadius: 17, yRadius: 17).fill()
        (text as NSString).draw(at: NSPoint(x: W / 2 - size.width / 2, y: y + 17 - size.height / 2), withAttributes: attrs)
    }
}
