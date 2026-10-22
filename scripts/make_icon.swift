// วาดไอคอนแอป 1024×1024 → AppIcon.png
// รัน: swift scripts/make_icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

// พื้นหลังสี่เหลี่ยมมุมมน ตามกริดไอคอน macOS (824px กลางผืน 1024)
let inset: CGFloat = 100
let tile = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
ctx.addPath(tilePath)
ctx.setFillColor(NSColor.black.cgColor)
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [NSColor(red: 1.00, green: 0.62, blue: 0.20, alpha: 1).cgColor,
                             NSColor(red: 0.93, green: 0.28, blue: 0.36, alpha: 1).cgColor] as CFArray,
                    locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
let gloss = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                       colors: [NSColor.white.withAlphaComponent(0.22).cgColor,
                                NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                       locations: [0, 1])!
ctx.drawLinearGradient(gloss, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.midY), options: [])
ctx.restoreGState()

// วงล้อ 8 ช่อง
let c = CGPoint(x: size / 2, y: size / 2)
let inner: CGFloat = 132, outer: CGFloat = 318
let n = 8, gap: CGFloat = 5 * .pi / 180
let step = 2 * CGFloat.pi / CGFloat(n)
let highlight = 1

for i in 0..<n {
    let a0 = .pi / 2 - CGFloat(i) * step - gap / 2
    let a1 = .pi / 2 - CGFloat(i + 1) * step + gap / 2
    let wedge = CGMutablePath()
    wedge.addArc(center: c, radius: outer, startAngle: a0, endAngle: a1, clockwise: true)
    wedge.addArc(center: c, radius: inner, startAngle: a1, endAngle: a0, clockwise: false)
    wedge.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor.black.withAlphaComponent(0.18).cgColor)
    ctx.addPath(wedge)
    ctx.setFillColor(i == highlight ? NSColor(red: 0.25, green: 0.18, blue: 0.45, alpha: 1).cgColor
                                    : NSColor.white.withAlphaComponent(0.94).cgColor)
    ctx.fillPath()
    ctx.restoreGState()
}

// วงกลมกลาง + ลูกศรวน
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor.black.withAlphaComponent(0.18).cgColor)
ctx.addEllipse(in: CGRect(x: c.x - 104, y: c.y - 104, width: 208, height: 208))
ctx.setFillColor(NSColor.white.cgColor)
ctx.fillPath()
ctx.restoreGState()

let arrowColor = NSColor(red: 0.93, green: 0.36, blue: 0.30, alpha: 1).cgColor
ctx.setStrokeColor(arrowColor)
ctx.setFillColor(arrowColor)
ctx.setLineWidth(20)
ctx.setLineCap(.round)
let r: CGFloat = 54
for k in 0..<2 {
    let base = CGFloat(k) * .pi
    let start = base + 0.35, end = base + .pi - 0.35
    ctx.addArc(center: c, radius: r, startAngle: start, endAngle: end, clockwise: false)
    ctx.strokePath()
    let tip = CGPoint(x: c.x + cos(end) * r, y: c.y + sin(end) * r)
    let tangent = end + .pi / 2
    let head = CGMutablePath()
    head.move(to: CGPoint(x: tip.x + cos(tangent) * 30, y: tip.y + sin(tangent) * 30))
    head.addLine(to: CGPoint(x: tip.x + cos(end) * 24, y: tip.y + sin(end) * 24))
    head.addLine(to: CGPoint(x: tip.x - cos(end) * 24, y: tip.y - sin(end) * 24))
    head.closeSubpath()
    ctx.addPath(head)
    ctx.fillPath()
}

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("✓ \(out)")
