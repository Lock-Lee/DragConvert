import AppKit
import PDFKit

@MainActor
final class Converter {
    static let shared = Converter()

    /// เรียกทุกครั้งที่จำนวนงานที่กำลังแปลงเปลี่ยน (ใช้เปลี่ยนไอคอน Menu Bar)
    var onChange: ((Int) -> Void)?
    private var running = 0 { didSet { onChange?(running) } }

    func convert(_ files: [URL], with option: FormatOption) {
        guard !files.isEmpty else { return }
        running += 1

        Task.detached(priority: .userInitiated) {
            var outputs: [URL] = []
            var errors: [String] = []

            for file in files {
                do {
                    outputs += try Self.convertOne(file, option)
                } catch {
                    errors.append("\(file.lastPathComponent): \(error.localizedDescription)")
                }
            }

            let done = outputs, failed = errors
            await MainActor.run {
                self.running -= 1
                if !done.isEmpty {
                    NSSound(named: "Glass")?.play()
                    NSWorkspace.shared.activateFileViewerSelecting(done)
                }
                if !failed.isEmpty {
                    if failed.contains(where: { $0.contains("ยังไม่อนุญาต") }) {
                        Permissions.showStatus()
                    } else {
                        Converter.alert("แปลงไม่สำเร็จบางไฟล์", failed.joined(separator: "\n\n"))
                    }
                }
            }
        }
    }

    // MARK: งานแปลงจริง (ทำนอก main thread)

    nonisolated private static func convertOne(_ input: URL, _ option: FormatOption) throws -> [URL] {
        let base = input.deletingPathExtension().lastPathComponent + option.suffix
        let folder = input.deletingLastPathComponent()

        // เปิดไฟล์จากตัวแอปเองก่อน ให้ macOS ถามสิทธิ์ Desktop/Documents/Downloads
        // (ffmpeg/sips ที่เรียกทีหลังจะได้สิทธิ์ต่อจากแอป)
        do {
            let h = try FileHandle(forReadingFrom: input)
            _ = try h.read(upToCount: 1)
            try h.close()
        } catch {
            throw ConvertError("""
                เปิดไฟล์ไม่ได้ — macOS ยังไม่อนุญาตให้ DragConvert เข้าถึงโฟลเดอร์นี้
                ไปที่ System Settings → Privacy & Security → Files and Folders → DragConvert แล้วเปิดสิทธิ์
                """)
        }

        switch option.tool {
        case .ffmpeg(let args):
            guard let ffmpeg = findTool("ffmpeg") else {
                throw ConvertError("ไม่พบ ffmpeg — ติดตั้งด้วย: brew install ffmpeg")
            }
            let out = uniqueURL(folder, base, option.ext)
            try run(ffmpeg, ["-hide_banner", "-nostdin", "-loglevel", "error", "-i", input.path]
                    + args + ["-y", out.path])
            return [out]

        case .sips(let args):
            let out = uniqueURL(folder, base, option.ext)
            try run("/usr/bin/sips", args + [input.path, "--out", out.path])
            return [out]

        case .cwebp(let args):
            guard let cwebp = findTool("cwebp") else {
                throw ConvertError("ไม่พบ cwebp — ติดตั้งด้วย: brew install webp")
            }
            let out = uniqueURL(folder, base, option.ext)
            try run(cwebp, ["-quiet"] + args + [input.path, "-o", out.path])
            return [out]

        case .pdfPages(let png):
            return try renderPDF(input, folder: folder, base: base, png: png)

        case .pdfText:
            guard let doc = PDFDocument(url: input) else { throw ConvertError("เปิด PDF ไม่ได้") }
            let out = uniqueURL(folder, base, "txt")
            try (doc.string ?? "").write(to: out, atomically: true, encoding: .utf8)
            return [out]
        }
    }

    nonisolated private static func renderPDF(_ input: URL, folder: URL, base: String, png: Bool) throws -> [URL] {
        guard let doc = PDFDocument(url: input) else { throw ConvertError("เปิด PDF ไม่ได้") }
        let ext = png ? "png" : "jpg"
        let scale: CGFloat = 2   // 144 dpi คมพอสำหรับอ่านบนจอ
        var outputs: [URL] = []

        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let box = page.bounds(for: .mediaBox)
            let w = Int(box.width * scale), h = Int(box.height * scale)

            guard let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
            ), let ctx = NSGraphicsContext(bitmapImageRep: rep) else { continue }

            let cg = ctx.cgContext
            cg.setFillColor(NSColor.white.cgColor)
            cg.fill(CGRect(x: 0, y: 0, width: w, height: h))
            cg.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: cg)

            let data = png
                ? rep.representation(using: .png, properties: [:])
                : rep.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            guard let data else { continue }

            let name = doc.pageCount > 1 ? "\(base)-\(i + 1)" : base
            let out = uniqueURL(folder, name, ext)
            try data.write(to: out)
            outputs.append(out)
        }
        if outputs.isEmpty { throw ConvertError("ไม่มีหน้าที่แปลงได้") }
        return outputs
    }

    // MARK: ตัวช่วย

    /// แอปที่เปิดจาก Finder ไม่เห็น PATH ของ Homebrew เลยต้องหาเอง
    nonisolated static func findTool(_ name: String) -> String? {
        ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
            .map { "\($0)/\(name)" }
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// ชื่อไฟล์ไม่ซ้ำ: clip.mp4 → clip 2.mp4 → clip 3.mp4
    nonisolated private static func uniqueURL(_ folder: URL, _ base: String, _ ext: String) -> URL {
        var url = folder.appendingPathComponent(base).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return url
    }

    nonisolated private static func run(_ tool: String, _ args: [String]) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let err = Pipe()
        p.standardError = err
        p.standardOutput = FileHandle.nullDevice
        try p.run()
        let data = err.fileHandleForReading.readDataToEndOfFile()   // อ่านก่อน wait กันค้าง
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            let msg = String(data: data, encoding: .utf8)?
                .split(separator: "\n").suffix(3).joined(separator: "\n") ?? ""
            throw ConvertError(msg.isEmpty ? "exit code \(p.terminationStatus)" : msg)
        }
    }

    static func alert(_ title: String, _ message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.messageText = title
        a.informativeText = message
        a.runModal()
    }
}

struct ConvertError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}
