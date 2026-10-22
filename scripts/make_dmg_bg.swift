// วาดพื้นหลังหน้าติดตั้ง DMG (660×400) → <out>.png และ <out>@2x.png
// รัน: swift scripts/make_dmg_bg.swift <out-without-ext>
import AppKit

let W: CGFloat = 660, H: CGFloat = 400
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background"

// ตำแหน่งไอคอน (วัดจากมุมซ้ายบน ต้องตรงกับ make_dmg.sh)
let appX: CGFloat = 170, appsX: CGFloat = 490, iconY: CGFloat = 190

func render(scale: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: W, height: H)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // พื้นไล่สีโทนเดียวกับไอคอน (ส้ม → ชมพู) อ่อนลงให้ตัวหนังสือชื่อไฟล์อ่านง่าย
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [NSColor(red: 1.00, green: 0.80, blue: 0.58, alpha: 1).cgColor,
                                 NSColor(red: 0.98, green: 0.62, blue: 0.64, alpha: 1).cgColor] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

    // แผ่นกระจกขาวใสรองไอคอนทั้งสอง
    let y = H - iconY
    for x in [appX, appsX] {
        let r = NSRect(x: x - 78, y: y - 92, width: 156, height: 168)
        NSColor.white.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: r, xRadius: 28, yRadius: 28).fill()
        NSColor.white.withAlphaComponent(0.7).setStroke()
        let edge = NSBezierPath(roundedRect: r.insetBy(dx: 0.5, dy: 0.5), xRadius: 28, yRadius: 28)
        edge.lineWidth = 1
        edge.stroke()
    }

    // ลูกศรประ ชี้จากแอปไปหา Applications
    let ink = NSColor(red: 0.30, green: 0.14, blue: 0.20, alpha: 0.75)
    let x0 = appX + 92, x1 = appsX - 100
    let line = NSBezierPath()
    line.move(to: NSPoint(x: x0, y: y))
    line.line(to: NSPoint(x: x1, y: y))
    line.lineWidth = 5
    line.lineCapStyle = .round
    line.setLineDash([2, 13], count: 2, phase: 0)
    ink.setStroke()
    line.stroke()

    let head = NSBezierPath()
    head.move(to: NSPoint(x: x1 + 18, y: y))
    head.line(to: NSPoint(x: x1 - 2, y: y + 14))
    head.line(to: NSPoint(x: x1 - 2, y: y - 14))
    head.close()
    ink.setFill()
    head.fill()

    func text(_ s: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, y: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: NSColor(red: 0.25, green: 0.10, blue: 0.16, alpha: alpha),
        ]
        let sz = (s as NSString).size(withAttributes: attrs)
        (s as NSString).draw(at: NSPoint(x: (W - sz.width) / 2, y: y), withAttributes: attrs)
    }

    text("ลาก DragConvert ไปวางที่ Applications", size: 20, weight: .bold, alpha: 0.9, y: H - 62)
    text("เปิดครั้งแรก: คลิกขวาที่แอป → Open  ·  ต้องมี brew install ffmpeg webp",
         size: 12, weight: .medium, alpha: 0.6, y: 26)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

try! render(scale: 1).write(to: URL(fileURLWithPath: out + ".png"))
try! render(scale: 2).write(to: URL(fileURLWithPath: out + "@2x.png"))
print("✓ \(out).png, \(out)@2x.png")
