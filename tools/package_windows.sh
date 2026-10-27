#!/usr/bin/env bash
# 플레이용 윈도우 시험판 묶기 — 압축을 풀고 exe를 두 번 누르면 된다(자료 내장 단일 exe).
# 먼저: bash tools/setup_godot.sh + 내보내기 템플릿(~/.local/share/godot/export_templates/4.7.2.stable).
# 결과: export/FalloutSeoul_win64.zip (export/는 .gitignore — 저장소에 올리지 않는다)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TPL="$HOME/.local/share/godot/export_templates/4.7.2.stable"
if [[ ! -f "$TPL/windows_release_x86_64.exe" ]]; then
  mkdir -p "$TPL" && cd /tmp
  curl -sSL -o tpl.tpz "https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz"
  unzip -o -q tpl.tpz && cp templates/* "$TPL/" && rm -rf tpl.tpz templates
fi
cd "$ROOT/game"
godot --headless --path . --import >/dev/null 2>&1
mkdir -p ../export/windows
godot --headless --path . --export-release "Windows Desktop" ../export/windows/seoul_fallout_t.exe
PKG="$ROOT/export/pkg/FalloutSeoul"
rm -rf "$ROOT/export/pkg" && mkdir -p "$PKG"
cp ../export/windows/seoul_fallout_t.exe "$PKG/FalloutSeoul.exe"
cp "$ROOT/tools/package/READ_ME.txt" "$PKG/READ_ME.txt"
sed -i "s/@BUILD@/$(date +%Y-%m-%d) · 커밋 $(git -C "$ROOT" rev-parse --short HEAD)/" "$PKG/READ_ME.txt"
cd "$ROOT/export/pkg" && rm -f ../FalloutSeoul_win64.zip && zip -9 -r -q ../FalloutSeoul_win64.zip FalloutSeoul
ls -la "$ROOT/export/FalloutSeoul_win64.zip"
