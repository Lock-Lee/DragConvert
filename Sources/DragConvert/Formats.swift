import Foundation
import UniformTypeIdentifiers

enum FileKind: Equatable {
    case video, audio, image, pdf, other

    static func of(_ url: URL) -> FileKind {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return .other }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .image) { return .image }
        return .other
    }
}

/// เครื่องมือที่ใช้แปลง
enum Tool {
    case ffmpeg([String])          // args ระหว่าง input กับ output
    case sips([String])            // คำสั่งที่มากับ macOS อยู่แล้ว
    case cwebp([String])           // แปลงเป็น WebP (brew install webp)
    case pdfPages(png: Bool)       // แปลงทุกหน้า PDF เป็นรูป (ใช้ PDFKit)
    case pdfText                   // ดึงข้อความจาก PDF
}

struct FormatOption {
    let title: String      // ตัวหนังสือใหญ่บนวงล้อ
    let detail: String     // ตัวเล็กข้างใต้
    let ext: String        // นามสกุลไฟล์ผลลัพธ์
    let suffix: String     // ต่อท้ายชื่อไฟล์ เช่น "-720p"
    let tool: Tool

    init(_ title: String, _ detail: String, ext: String, suffix: String = "", _ tool: Tool) {
        self.title = title
        self.detail = detail
        self.ext = ext
        self.suffix = suffix
        self.tool = tool
    }
}

enum Formats {
    static let h264 = ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p",
                       "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]

    static func options(for url: URL) -> [FormatOption] {
        let inputExt = url.pathExtension.lowercased()
        let all: [FormatOption]

        switch FileKind.of(url) {
        case .video:
            all = [
                FormatOption("MP4", "H.264", ext: "mp4", .ffmpeg(h264)),
                FormatOption("MP4", "720p", ext: "mp4", suffix: "-720p",
                             .ffmpeg(["-vf", "scale=-2:720"] + h264)),
                FormatOption("บีบอัด", "MP4", ext: "mp4", suffix: "-compressed",
                             .ffmpeg(["-vf", "scale='min(1920,iw)':-2", "-c:v", "libx264", "-preset", "slow",
                                      "-crf", "28", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "128k",
                                      "-movflags", "+faststart"])),
                FormatOption("MOV", "H.264", ext: "mov", .ffmpeg(h264)),
                FormatOption("GIF", "480px", ext: "gif",
                             .ffmpeg(["-vf", "fps=15,scale=480:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse",
                                      "-loop", "0"])),
                FormatOption("MP3", "เสียง", ext: "mp3", .ffmpeg(["-vn", "-c:a", "libmp3lame", "-q:a", "2"])),
                FormatOption("M4A", "เสียง", ext: "m4a", .ffmpeg(["-vn", "-c:a", "aac", "-b:a", "192k"])),
                FormatOption("ตัดเสียง", "ไม่มีเสียง", ext: inputExt, suffix: "-muted",
                             .ffmpeg(["-an", "-c:v", "copy"])),
                FormatOption("ซับไตเติล", "SRT", ext: "srt", .ffmpeg(["-map", "0:s:0"])),
                FormatOption("ภาพปก", "JPG", ext: "jpg", suffix: "-thumb",
                             .ffmpeg(["-vf", "thumbnail", "-frames:v", "1", "-q:v", "2"])),
            ]

        case .audio:
            all = [
                FormatOption("MP3", "320k", ext: "mp3", .ffmpeg(["-vn", "-c:a", "libmp3lame", "-b:a", "320k"])),
                FormatOption("M4A", "AAC", ext: "m4a", .ffmpeg(["-vn", "-c:a", "aac", "-b:a", "256k"])),
                FormatOption("WAV", "16-bit", ext: "wav", .ffmpeg(["-vn", "-c:a", "pcm_s16le"])),
                FormatOption("FLAC", "Lossless", ext: "flac", .ffmpeg(["-vn", "-c:a", "flac"])),
                FormatOption("AIFF", "Lossless", ext: "aiff", .ffmpeg(["-vn", "-c:a", "pcm_s16be"])),
            ]

        case .image:
            all = [
                FormatOption("JPG", "คุณภาพ 90", ext: "jpg",
                             .sips(["-s", "format", "jpeg", "-s", "formatOptions", "90"])),
                FormatOption("PNG", "ไม่เสียคุณภาพ", ext: "png", .sips(["-s", "format", "png"])),
                FormatOption("HEIC", "ไฟล์เล็ก", ext: "heic", .sips(["-s", "format", "heic"])),
                FormatOption("WebP", "เว็บ", ext: "webp", .cwebp(["-q", "85"])),
                FormatOption("TIFF", "งานพิมพ์", ext: "tiff", .sips(["-s", "format", "tiff"])),
                FormatOption("PDF", "เอกสาร", ext: "pdf", .sips(["-s", "format", "pdf"])),
                FormatOption("ย่อรูป", "1920px", ext: inputExt, suffix: "-1920", .sips(["-Z", "1920"])),
                FormatOption("ย่อรูป", "1080px", ext: inputExt, suffix: "-1080", .sips(["-Z", "1080"])),
            ]

        case .pdf:
            all = [
                FormatOption("PNG", "ทุกหน้า", ext: "png", .pdfPages(png: true)),
                FormatOption("JPG", "ทุกหน้า", ext: "jpg", .pdfPages(png: false)),
                FormatOption("ข้อความ", "TXT", ext: "txt", .pdfText),
            ]

        case .other:
            all = []
        }

        // ไม่ต้องโชว์ตัวเลือกที่ได้ไฟล์แบบเดียวกับต้นฉบับ (เช่น MOV → MOV)
        return all.filter { !($0.ext == inputExt && $0.suffix.isEmpty) }
    }
}
