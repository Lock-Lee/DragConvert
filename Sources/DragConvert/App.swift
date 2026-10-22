import AppKit
import ServiceManagement

@main
@MainActor
enum DragConvertApp {
    static let delegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)   // ไม่มีไอคอนใน Dock อยู่แค่ Menu Bar
        app.delegate = delegate
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let monitor = DragMonitor()
    private let panel = RadialPanel()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(busy: false)
        buildMenu()

        Converter.shared.onChange = { [weak self] count in
            self?.setIcon(busy: count > 0)
        }

        panel.radial.onPick = { [weak self] option, files in
            self?.panel.orderOut(nil)
            Converter.shared.convert(files, with: option)
        }

        monitor.onShow = { [weak self] point, urls in
            guard let first = urls.first else { return }
            let kind = FileKind.of(first)
            let options = Formats.options(for: first)
            guard !options.isEmpty else { return }
            let files = urls.filter { FileKind.of($0) == kind }
            self?.panel.show(at: point, files: files, options: options)
        }

        monitor.onEnd = { [weak self] in
            // รอให้การปล่อยไฟล์ลงวงล้อทำงานเสร็จก่อนค่อยซ่อน
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 400_000_000)
                if NSEvent.pressedMouseButtons & 1 == 0 {
                    self?.panel.orderOut(nil)
                }
            }
        }

        monitor.start()

        // รันจาก Xcode ใส่ argument --preview เพื่อโชว์วงล้อทันที
        if CommandLine.arguments.contains("--preview") { showPreview() }

        if Converter.findTool("ffmpeg") == nil {
            Converter.alert(
                "ยังไม่ได้ติดตั้ง ffmpeg",
                "แปลงรูปได้ แต่วิดีโอกับเสียงต้องใช้ ffmpeg\nติดตั้งด้วยคำสั่ง: brew install ffmpeg"
            )
        }
    }

    private func setIcon(busy: Bool) {
        let name = busy ? "hourglass" : "arrow.triangle.2.circlepath"
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "DragConvert")
    }

    private func buildMenu() {
        let menu = NSMenu()

        let hint = NSMenuItem(title: "ลากไฟล์ใน Finder แล้วกด Shift ค้างไว้", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        let ffmpegFound = Converter.findTool("ffmpeg") != nil
        let ffmpeg = NSMenuItem(
            title: ffmpegFound ? "ffmpeg: พร้อมใช้งาน ✓" : "ffmpeg: ไม่พบ (brew install ffmpeg)",
            action: nil, keyEquivalent: ""
        )
        ffmpeg.isEnabled = false
        menu.addItem(ffmpeg)

        let preview = NSMenuItem(title: "ดูตัวอย่างวงล้อ", action: #selector(showPreview), keyEquivalent: "p")
        preview.target = self
        menu.addItem(preview)

        menu.addItem(.separator())

        let login = NSMenuItem(title: "เปิดอัตโนมัติตอนเข้าเครื่อง", action: #selector(toggleLogin(_:)), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "ออก", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    /// โชว์วงล้อกลางจอโดยไม่ต้องลากไฟล์ (ชี้เมาส์ดู hover ได้ คลิกเพื่อปิด)
    @objc func showPreview() {
        let sample = URL(fileURLWithPath: "/tmp/IMG_0001.MOV")
        let frame = NSScreen.main?.visibleFrame ?? .zero
        panel.show(at: NSPoint(x: frame.midX, y: frame.midY), files: [sample],
                   options: Formats.options(for: sample), preview: true)
    }

    @objc private func toggleLogin(_ item: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            Converter.alert("ตั้งค่าไม่สำเร็จ", "ลองย้ายแอปไปไว้ใน Applications ก่อน\n\(error.localizedDescription)")
        }
        item.state = service.status == .enabled ? .on : .off
    }
}
