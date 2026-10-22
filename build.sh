#!/bin/bash
# สร้าง DragConvert.app แล้ววางไว้ใน /Applications
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ กำลัง build..."
swift build -c release

APP="build/DragConvert.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$(swift build -c release --show-bin-path)/DragConvert" "$APP/Contents/MacOS/DragConvert"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>             <string>DragConvert</string>
    <key>CFBundleDisplayName</key>      <string>DragConvert</string>
    <key>CFBundleIdentifier</key>       <string>local.dragconvert</string>
    <key>CFBundleExecutable</key>       <string>DragConvert</string>
    <key>CFBundlePackageType</key>      <string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key>          <string>1</string>
    <key>LSMinimumSystemVersion</key>   <string>13.0</string>
    <key>CFBundleIconFile</key>         <string>AppIcon</string>
    <key>NSDesktopFolderUsageDescription</key>    <string>DragConvert ต้องอ่านไฟล์ที่คุณลากมาแปลง และบันทึกไฟล์ใหม่ไว้ข้างไฟล์เดิม</string>
    <key>NSDocumentsFolderUsageDescription</key>  <string>DragConvert ต้องอ่านไฟล์ที่คุณลากมาแปลง และบันทึกไฟล์ใหม่ไว้ข้างไฟล์เดิม</string>
    <key>NSDownloadsFolderUsageDescription</key>  <string>DragConvert ต้องอ่านไฟล์ที่คุณลากมาแปลง และบันทึกไฟล์ใหม่ไว้ข้างไฟล์เดิม</string>
    <key>NSRemovableVolumesUsageDescription</key> <string>DragConvert ต้องอ่านไฟล์ที่คุณลากมาแปลงจากไดรฟ์ภายนอก</string>
    <key>NSNetworkVolumesUsageDescription</key>   <string>DragConvert ต้องอ่านไฟล์ที่คุณลากมาแปลงจากไดรฟ์ในเครือข่าย</string>
    <key>LSUIElement</key>              <true/>
    <key>NSHighResolutionCapable</key>  <true/>
</dict>
</plist>
PLIST

# เซ็นแบบ ad-hoc ให้ macOS ยอมเปิด (ไม่ต้องมีบัญชี Developer)
# ผูกตัวตนแอปกับ bundle id เพื่อให้สิทธิ์เข้าถึงโฟลเดอร์ที่อนุญาตไว้ ยังอยู่หลัง build ใหม่
codesign --force --deep --sign - \
  --identifier local.dragconvert \
  -r='designated => identifier "local.dragconvert"' "$APP"

[[ "${1:-}" == "--no-install" ]] && { echo "✓ build/DragConvert.app"; exit 0; }

pkill -x DragConvert 2>/dev/null || true
rm -rf /Applications/DragConvert.app
cp -R "$APP" /Applications/
echo "✓ ติดตั้งแล้วที่ /Applications/DragConvert.app"
open /Applications/DragConvert.app
