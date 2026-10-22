#!/bin/bash
# สร้างไฟล์ติดตั้ง dist/DragConvert-<version>.dmg
# เปิดแล้วเป็นหน้าลากแอปไปวางที่ Applications พร้อมพื้นหลังและลูกศร
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.0"
NAME="DragConvert"
VOL="$NAME"
DMG="dist/$NAME-$VERSION.dmg"
WORK="$(mktemp -d)"
trap 'hdiutil detach "/Volumes/$VOL" -quiet 2>/dev/null || true; rm -rf "$WORK"' EXIT

./build.sh --no-install

# 1) พื้นหลัง (รวม 1x + 2x เป็น tiff ไฟล์เดียว ให้คมบนจอ Retina)
swift scripts/make_dmg_bg.swift "$WORK/bg" >/dev/null
tiffutil -cathidpicheck "$WORK/bg.png" "$WORK/bg@2x.png" -out "$WORK/background.tiff" 2>/dev/null

# 2) ของในดิสก์
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background" dist
cp -R "build/$NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp "$WORK/background.tiff" "$STAGE/.background/background.tiff"

# 3) สร้าง DMG แบบเขียนได้ก่อน เพื่อจัดหน้าตาหน้าต่าง
hdiutil detach "/Volumes/$VOL" -quiet 2>/dev/null || true
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg" >/dev/null
hdiutil attach "$WORK/rw.dmg" -readwrite -noverify -noautoopen -mountpoint "/Volumes/$VOL" >/dev/null

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOL"
        open
        set w to container window
        set current view of w to icon view
        set toolbar visible of w to false
        set statusbar visible of w to false
        set bounds of w to {200, 120, 860, 548}
        delay 1
        set opts to icon view options of w
        set arrangement of opts to not arranged
        set icon size of opts to 112
        set text size of opts to 13
        set background picture of opts to file ".background:background.tiff"
        set position of item "$NAME.app" of w to {170, 190}
        set position of item "Applications" of w to {490, 190}
        update without registering applications
        delay 1
        close
        -- เปิดซ้ำแล้วตั้งขนาดอีกรอบ ให้ Finder บันทึกขนาดหน้าต่างลง .DS_Store จริง
        open
        delay 1
        set bounds of container window to {200, 120, 860, 548}
        delay 1
        close
    end tell
end tell
APPLESCRIPT

# ไอคอนของดิสก์ตอนเปิด = ไอคอนแอป
cp Resources/AppIcon.icns "/Volumes/$VOL/.VolumeIcon.icns"
SetFile -a C "/Volumes/$VOL" 2>/dev/null || xattr -wx com.apple.FinderInfo \
  "0000000000000000040000000000000000000000000000000000000000000000" "/Volumes/$VOL"

sync
hdiutil detach "/Volumes/$VOL" -quiet

# 4) บีบอัดเป็นไฟล์จริง
rm -f "$DMG"
hdiutil convert "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

# ไอคอนของไฟล์ .dmg = ไอคอนแอป
osascript -l JavaScript -e "
ObjC.import('AppKit');
const img = \$.NSImage.alloc.initWithContentsOfFile('$PWD/Resources/AppIcon.icns');
\$.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, '$PWD/$DMG', 0);
" >/dev/null

echo "✓ สร้างไฟล์ติดตั้งแล้ว: $PWD/$DMG"
