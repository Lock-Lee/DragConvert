# DragConvert

แปลงไฟล์บน Mac แค่ลากไฟล์ใน Finder แล้วกด **Shift** ค้างไว้ จะมีวงล้อฟอร์แมตขึ้นรอบเมาส์ ลากไปปล่อยบนช่องที่ต้องการ ไฟล์ใหม่จะไปอยู่ข้างไฟล์ต้นฉบับ ฟรี ไม่จำกัด ทำงานในเครื่องทั้งหมด

## ติดตั้งจาก DragConvert.dmg

1. ดับเบิลคลิก `DragConvert-1.0.dmg`
2. ลากไอคอน DragConvert ไปใส่โฟลเดอร์ Applications
3. เปิดครั้งแรก: คลิกขวาที่แอป → Open → Open (เพราะแอปไม่ได้เซ็นกับ Apple)
   ถ้ายังเปิดไม่ได้ ให้รันใน Terminal: `xattr -dr com.apple.quarantine /Applications/DragConvert.app`
4. ติดตั้งตัวแปลง: `brew install ffmpeg webp`

ต้องเป็น Mac ชิป Apple silicon (M1 ขึ้นไป) และ macOS 13 ขึ้นไป

## วิธีใช้

1. คลิกค้างที่ไฟล์ใน Finder แล้วเริ่มลาก (เลือกหลายไฟล์ประเภทเดียวกันได้)
2. กด **Shift** ค้าง → วงล้อโผล่
3. ลากไปปล่อยบนช่องที่ต้องการ (ปล่อยตรงกลาง = ยกเลิก)
4. เสร็จแล้วจะมีเสียง "ติ๊ง" และ Finder เปิดไฟล์ใหม่ให้ดู

ดูหน้าตาวงล้อได้จากไอคอนบน Menu Bar → "ดูตัวอย่างวงล้อ"

## ฟอร์แมตที่รองรับ

| ไฟล์ต้นทาง | แปลงเป็น |
|---|---|
| วิดีโอ | MP4, MP4 720p, บีบอัด, MOV, GIF, MP3, M4A, ตัดเสียง, ดึงซับ SRT, ภาพปก |
| เสียง | MP3, M4A, WAV, FLAC, AIFF |
| รูป | JPG, PNG, HEIC, WebP, TIFF, PDF, ย่อ 1920/1080px |
| PDF | PNG/JPG ทุกหน้า, ข้อความ TXT |

## สำหรับนักพัฒนา

```bash
./build.sh       # build + ติดตั้งลง /Applications
./make_dmg.sh    # สร้างไฟล์ติดตั้ง dist/DragConvert-1.0.dmg
open Package.swift   # เปิดใน Xcode
```

เปิดใน Xcode แล้วอยากเห็นวงล้อทันที: Product → Scheme → Edit Scheme… → Run → Arguments → เพิ่ม `--preview` แล้วกด ⌘R

ไอคอนวาดด้วย `scripts/make_icon.swift` (แก้สีหรือรูปทรงแล้วรันใหม่ได้)

```
Sources/DragConvert/
├── App.swift          เริ่มแอป + เมนูบน Menu Bar
├── DragMonitor.swift  ตรวจว่ากำลังลากไฟล์ + กด Shift
├── RadialPanel.swift  วงล้อเลือกฟอร์แมต
├── Formats.swift      รายการฟอร์แมตและคำสั่งแปลง
└── Converter.swift    รัน ffmpeg / sips / cwebp / PDFKit
```
