// เรนเดอร์เฟรมตัวอย่างการติดตั้ง (ลากแอปไปวางที่ Applications ในหน้าต่าง DMG)
// รัน: swift scripts/render_install_demo.swift <bg@2x.png> <AppIcon.png> <โฟลเดอร์>
import AppKit

let args = CommandLine.arguments
let bg = NSImage(contentsOfFile: args[1])!
let appIcon = NSImage(contentsOfFile: args[2])!
let outDir = URL(fileURLWithPath: args[3])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let folderIcon = NSWorkspace.shared.icon(forFile: "/Applications")

let W: CGFloat = 660, content: CGFloat = 400, bar: CGFloat = 28
let H = content + bar, scale: CGFloat = 2, fps = 30.0

// ตำแหน่งในหน้าต่าง (ซ้ายบนของพื้นที่เนื้อหา = 0,0) ตรงกับ make_dmg.sh
let appPos = CGPoint(x: 170, y: 182), appsPos = CGPoint(x: 490, y: 182)
func toAK(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x, y: content - p.y) }

func ease(_ t: Double) -> CGFloat { let x = CGFloat(max(0, min(1, t))); return x * x * (3 - 2 * x) }
func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint { CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t) }

func label(_ s: String, at c: CGPoint, alpha: CGFloat = 1) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13),
                                                .foregroundColor: NSColor(white: 0.1, alpha: alpha)]
    let sz = (s as NSString).size(withAttributes: attrs)
    (s as NSString).draw(at: NSPoint(x: c.x - sz.width / 2, y: c.y - sz.height / 2), withAttributes: attrs)
}

func cursor(at p: CGPoint) {
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, -17), (4, -13), (7, -20), (10, -19), (7, -12), (12, -12)]
    let path = NSBezierPath()
    path.move(to: NSPoint(x: p.x, y: p.y))
    for q in pts.dropFirst() { path.line(to: NSPoint(x: p.x + q.0, y: p.y + q.1)) }
    path.close()
    NSColor.black.setFill(); path.fill()
    NSColor.white.setStroke(); path.lineWidth = 1.2; path.stroke()
}

func pill(_ s: String, alpha: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .semibold),
                                                .foregroundColor: NSColor.white.withAlphaComponent(alpha)]
    let sz = (s as NSString).size(withAttributes: attrs)
    let y: CGFloat = 70 - (1 - alpha) * 8
    let r = NSRect(x: W / 2 - sz.width / 2 - 18, y: y, width: sz.width + 36, height: 34)
    NSColor(white: 0.15, alpha: 0.88 * alpha).setFill()
    NSBezierPath(roundedRect: r, xRadius: 17, yRadius: 17).fill()
    (s as NSString).draw(at: NSPoint(x: W / 2 - sz.width / 2, y: y + 17 - sz.height / 2), withAttributes: attrs)
}

let duration = 5.2
let start = CGPoint(x: 330, y: 330), grab = CGPoint(x: appPos.x + 6, y: appPos.y + 8)
let drop = CGPoint(x: appsPos.x + 4, y: appsPos.y + 6)

for f in 0..<Int(duration * fps) {
    let t = Double(f) / fps
    // 0–0.9 เลื่อนไปที่แอป, 0.9–1.1 กด, 1.1–2.6 ลาก, 2.6 ปล่อย, 2.6–3.0 หดเข้าโฟลเดอร์
    var cur: CGPoint
    if t < 0.9 { cur = lerp(start, grab, ease(t / 0.9)) }
    else if t < 1.1 { cur = grab }
    else if t < 2.6 { cur = lerp(grab, drop, ease((t - 1.1) / 1.5)) }
    else { cur = lerp(drop, CGPoint(x: drop.x + 40, y: drop.y + 70), ease((t - 2.9) / 0.8)) }
    let dragging = t >= 1.1 && t < 2.6
    let overApps = dragging && hypot(cur.x - appsPos.x, cur.y - appsPos.y) < 70
    let sink: CGFloat = t < 2.6 ? 0 : min(1, CGFloat((t - 2.6) / 0.35))
    let done: CGFloat = t < 3.0 ? 0 : min(1, CGFloat((t - 3.0) / 0.3))

    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // แถบชื่อหน้าต่าง
    NSColor(white: 0.17, alpha: 1).setFill()
    NSRect(x: 0, y: content, width: W, height: bar).fill()
    for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
        c.setFill()
        NSBezierPath(ovalIn: NSRect(x: 12 + CGFloat(i) * 20, y: content + 8, width: 12, height: 12)).fill()
    }
    appIcon.draw(in: NSRect(x: 76, y: content + 6, width: 16, height: 16))
    let title: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                                                .foregroundColor: NSColor(white: 0.85, alpha: 1)]
    ("DragConvert" as NSString).draw(at: NSPoint(x: 98, y: content + 6), withAttributes: title)

    // พื้นหลัง DMG
    bg.draw(in: NSRect(x: 0, y: 0, width: W, height: content))

    // ไอคอน Applications (ไฮไลต์ตอนลากไปทับ)
    let a = toAK(appsPos)
    if overApps {
        NSColor.black.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect: NSRect(x: a.x - 64, y: a.y - 62, width: 128, height: 124), xRadius: 14, yRadius: 14).fill()
    }
    folderIcon.draw(in: NSRect(x: a.x - 56, y: a.y - 56, width: 112, height: 112))
    label("Applications", at: CGPoint(x: a.x, y: a.y - 80))

    // ไอคอนแอปที่ตำแหน่งเดิม (เลือกอยู่ตอนลาก)
    let p = toAK(appPos)
    if t >= 0.9 && t < 2.6 {
        NSColor.black.withAlphaComponent(0.16).setFill()
        NSBezierPath(roundedRect: NSRect(x: p.x - 64, y: p.y - 62, width: 128, height: 124), xRadius: 14, yRadius: 14).fill()
    }
    appIcon.draw(in: NSRect(x: p.x - 56, y: p.y - 56, width: 112, height: 112))
    label("DragConvert", at: CGPoint(x: p.x, y: p.y - 80))

    // ไอคอนผีที่ติดเมาส์ และหดเข้าโฟลเดอร์ตอนปล่อย
    let c = toAK(cur)
    if dragging {
        appIcon.draw(in: NSRect(x: c.x - 62, y: c.y - 64, width: 112, height: 112),
                     from: .zero, operation: .sourceOver, fraction: 0.6)
    } else if sink > 0 && sink < 1 {
        let s = 112 * (1 - sink)
        let ctr = lerp(CGPoint(x: toAK(drop).x - 6, y: toAK(drop).y - 8), a, sink)
        appIcon.draw(in: NSRect(x: ctr.x - s / 2, y: ctr.y - s / 2, width: s, height: s),
                     from: .zero, operation: .sourceOver, fraction: 0.6 * (1 - sink))
    }

    if done > 0 { pill("✓  ติดตั้งแล้ว — เปิดได้จาก Applications", alpha: done) }
    cursor(at: c)

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!
        .write(to: outDir.appendingPathComponent(String(format: "f%04d.png", f)))
}
print("✓ install frames → \(outDir.path)")
