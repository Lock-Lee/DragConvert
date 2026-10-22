import AppKit

/// คอยดูว่ามีการลากไฟล์อยู่ไหม และผู้ใช้กด Shift หรือเปล่า
///
/// ใช้วิธีเช็กสถานะทุก ๆ 1/30 วินาที แทนการดักคีย์บอร์ดทั้งระบบ
/// ข้อดีคือไม่ต้องขอสิทธิ์ Accessibility / Input Monitoring เลย
/// - `NSEvent.pressedMouseButtons` บอกว่ากดเมาส์ค้างอยู่ไหม
/// - `NSEvent.modifierFlags` บอกว่ากด Shift อยู่ไหม
/// - drag pasteboard จะเปลี่ยน changeCount ทุกครั้งที่เริ่มลากของชิ้นใหม่
@MainActor
final class DragMonitor: NSObject {
    var onShow: ((NSPoint, [URL]) -> Void)?
    var onEnd: (() -> Void)?

    private let dragPasteboard = NSPasteboard(name: .drag)
    private var timer: Timer?
    private var mouseWasDown = false
    private var countAtMouseDown = 0
    private var shownThisDrag = false

    func start() {
        let t = Timer(timeInterval: 1.0 / 30.0, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)   // .common = ยังทำงานระหว่างที่มีการลาก
        timer = t
    }

    @objc private func tick() {
        let mouseDown = NSEvent.pressedMouseButtons & 1 != 0

        // เพิ่งเริ่มกดเมาส์ → จำ changeCount ไว้ ถ้ามันเปลี่ยนแปลว่าเริ่มลากของใหม่
        if mouseDown && !mouseWasDown {
            countAtMouseDown = dragPasteboard.changeCount
            shownThisDrag = false
        }

        // ปล่อยเมาส์แล้ว → จบการลาก
        if !mouseDown && mouseWasDown {
            if shownThisDrag { onEnd?() }
            shownThisDrag = false
        }

        mouseWasDown = mouseDown

        guard mouseDown, !shownThisDrag,
              dragPasteboard.changeCount != countAtMouseDown,
              NSEvent.modifierFlags.contains(.shift)
        else { return }

        let urls = dragPasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []

        guard !urls.isEmpty else { return }
        shownThisDrag = true
        onShow?(NSEvent.mouseLocation, urls)
    }
}
