#!/bin/bash
# สร้างไฟล์ติดตั้ง dist/DragConvert-<version>.dmg (ลากแอปไปใส่ Applications)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.0"
NAME="DragConvert"
DMG="dist/$NAME-$VERSION.dmg"

./build.sh --no-install

STAGE="$(mktemp -d)/$NAME"
mkdir -p "$STAGE" dist
cp -R "build/$NAME.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp README.md "$STAGE/อ่านก่อนติดตั้ง.md"

rm -f "$DMG"
hdiutil create -volname "$NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null

# ใช้ไอคอนแอปเป็นไอคอนของไฟล์ .dmg ด้วย
osascript -l JavaScript -e "
ObjC.import('AppKit');
const img = \$.NSImage.alloc.initWithContentsOfFile('$PWD/Resources/AppIcon.icns');
\$.NSWorkspace.sharedWorkspace.setIconForFileOptions(img, '$PWD/$DMG', 0);
" >/dev/null

rm -rf "$(dirname "$STAGE")"
echo "✓ สร้างไฟล์ติดตั้งแล้ว: $PWD/$DMG"
