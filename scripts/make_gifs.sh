#!/bin/bash
# สร้าง GIF สำหรับ README → docs/demo.gif และ docs/install.gif
set -euo pipefail
cd "$(dirname "$0")/.."
FFMPEG="$(command -v ffmpeg || echo /opt/homebrew/bin/ffmpeg)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p docs

togif() {  # <โฟลเดอร์เฟรม> <ไฟล์ปลายทาง> <ความกว้าง> <fps>
  "$FFMPEG" -v error -y -framerate 30 -i "$1/f%04d.png" \
    -vf "fps=${4},scale=${3}:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 "$2"
}

echo "▸ การใช้งาน"
swift build -c release >/dev/null
"$(swift build -c release --show-bin-path)/DragConvert" --render-demo "$WORK/demo" >/dev/null
togif "$WORK/demo" docs/demo.gif 540 20

echo "▸ การติดตั้ง"
swift scripts/make_dmg_bg.swift "$WORK/bg" >/dev/null
swift scripts/render_install_demo.swift "$WORK/bg@2x.png" Resources/AppIcon.png "$WORK/install" >/dev/null
togif "$WORK/install" docs/install.gif 660 24

# ภาพนิ่งของวงล้อ (หน้าแรก README)
cp "$WORK/demo/f0150.png" "$WORK/wheel.png"
sips -Z 960 "$WORK/wheel.png" --out docs/wheel.png >/dev/null

ls -lh docs
