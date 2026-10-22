import AppKit

/// ขอสิทธิ์เข้าถึงโฟลเดอร์ที่ macOS ปกป้อง (Desktop, Documents, Downloads)
///
/// macOS จะเด้งหน้าต่างถามสิทธิ์ครั้งแรกที่แอปพยายามอ่านโฟลเดอร์นั้น
/// เราเลยลองอ่านทั้งสามโฟลเดอร์ตอนเปิดแอป ให้ผู้ใช้กด Allow ไว้ก่อนเลย
/// ไม่ต้องรอไปเจอ error ตอนแปลงไฟล์
@MainActor
enum Permissions {
    struct Folder: Sendable {
        let name: String
        let url: URL
    }

    nonisolated static let folders: [Folder] = {
        let fm = FileManager.default
        return [
            Folder(name: "Desktop", url: fm.urls(for: .desktopDirectory, in: .userDomainMask)[0]),
            Folder(name: "Documents", url: fm.urls(for: .documentDirectory, in: .userDomainMask)[0]),
            Folder(name: "Downloads", url: fm.urls(for: .downloadsDirectory, in: .userDomainMask)[0]),
        ]
    }()

    private static let askedKey = "askedFolderAccess"

    /// อ่านโฟลเดอร์ได้ไหม (ถ้ายังไม่เคยถาม การเรียกนี้จะทำให้ macOS เด้งถาม)
    nonisolated static func canRead(_ url: URL) -> Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil
    }

    /// สถานะของทุกโฟลเดอร์
    static func status() -> [(Folder, Bool)] {
        folders.map { ($0, canRead($0.url)) }
    }

    /// เปิดแอปครั้งแรก: อธิบายก่อน แล้วค่อยให้ macOS ถามทีละโฟลเดอร์
    static func requestOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: askedKey) else { return }
        UserDefaults.standard.set(true, forKey: askedKey)

        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.icon = NSApp.applicationIconImage
        a.messageText = "อนุญาตให้ DragConvert เข้าถึงไฟล์"
        a.informativeText = """
            DragConvert ต้องอ่านไฟล์ที่คุณลากมา และบันทึกไฟล์ที่แปลงแล้วไว้ข้างไฟล์เดิม

            ต่อจากนี้ macOS จะถามสิทธิ์ Desktop, Documents และ Downloads ทีละโฟลเดอร์ \
            กด "Allow" ทุกอัน ไฟล์ไม่ถูกส่งออกจากเครื่อง
            """
        a.addButton(withTitle: "ตกลง")
        a.addButton(withTitle: "ไว้ทีหลัง")
        guard a.runModal() == .alertFirstButtonReturn else { return }
        request()
    }

    /// ให้ macOS ถามสิทธิ์ทุกโฟลเดอร์ที่ยังไม่ได้ แล้วสรุปผล
    static func request() {
        // อ่านทีละโฟลเดอร์ (macOS ถามทีละอันแบบรอคำตอบ) ทำนอก main thread กันแอปค้าง
        Task.detached {
            for f in folders { _ = canRead(f.url) }
            await MainActor.run { showStatus(onlyIfMissing: true) }
        }
    }

    /// แสดงสถานะสิทธิ์ ถ้ายังขาดให้พาไปหน้า System Settings
    static func showStatus(onlyIfMissing: Bool = false) {
        let s = status()
        let missing = s.filter { !$0.1 }
        if onlyIfMissing && missing.isEmpty { return }

        NSApp.activate(ignoringOtherApps: true)
        let a = NSAlert()
        a.icon = NSApp.applicationIconImage
        let lines = s.map { "\($0.1 ? "✅" : "⛔️")  \($0.0.name)" }.joined(separator: "\n")

        if missing.isEmpty {
            a.messageText = "ได้สิทธิ์ครบแล้ว"
            a.informativeText = lines
            a.addButton(withTitle: "ตกลง")
            a.runModal()
            return
        }

        a.messageText = "ยังไม่ได้สิทธิ์บางโฟลเดอร์"
        a.informativeText = """
            \(lines)

            ไปที่ System Settings → Privacy & Security → Files and Folders \
            → DragConvert แล้วเปิดสวิตช์โฟลเดอร์ที่ยังปิดอยู่
            """
        a.addButton(withTitle: "เปิด System Settings")
        a.addButton(withTitle: "ไว้ทีหลัง")
        if a.runModal() == .alertFirstButtonReturn { openSettings() }
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!
        NSWorkspace.shared.open(url)
    }
}
