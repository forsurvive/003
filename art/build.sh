#!/usr/bin/env bash
# 단계 S 한 줄 재현 (SD-19 §5.1): 텍스트 격자·생성기 → samples/ 출력 → 자동 검수 → 시트 PNG + JSON.
#   ./build.sh          전부 다시 만든다
#   ./build.sh --check  두 번 만들어 출력 해시를 비교한다(같은 입력 = 같은 출력, 바이트 단위)
set -euo pipefail
cd "$(dirname "$0")"
export PYTHONHASHSEED=0
run() {
  python3 tools/make_palette_sheet.py
  python3 tools/tiles_r01.py
  python3 tools/scene_bongcheon.py
  python3 tools/preview.py src/sprites/pc_s07_jumpsuit_S.txt samples/04_pc_s07_idle_x8.png 8 P19
  python3 tools/rig_pc.py
  python3 tools/locomotion_demo.py
  python3 tools/hud_mobile.py
  python3 tools/pipboy.py
  python3 tools/keyart.py
  python3 tools/tiles_s07.py
  python3 tools/scene_s07.py
  python3 tools/outfit_samples.py
  python3 tools/head_samples.py
  python3 tools/weapons.py
  python3 tools/weapons.py split
  python3 tools/creatures.py
  python3 tools/npcs.py
  python3 tools/portraits.py
  python3 tools/ui_screens.py
  python3 tools/effects.py
  python3 tools/signs.py
  python3 tools/scene_birth.py
  python3 tools/filters.py
  python3 tools/legibility_test.py
  python3 tools/style_isaac.py
  python3 tools/compare_sheet.py
  python3 tools/pack.py
  python3 tools/qa.py
}
hashes() { find samples out -type f \( -name '*.png' -o -name '*.gif' -o -name '*.json' -o -name '*.txt' \) -print0 | sort -z | xargs -0 sha256sum; }
if [[ "${1:-}" == "--check" ]]; then
  run > /dev/null
  hashes > /tmp/build_hash_1.txt
  run > /dev/null
  hashes > /tmp/build_hash_2.txt
  if diff -q /tmp/build_hash_1.txt /tmp/build_hash_2.txt > /dev/null; then
    echo "재현 OK: $(wc -l < /tmp/build_hash_1.txt)개 파일 해시 일치"
  else
    echo "재현 실패:"; diff /tmp/build_hash_1.txt /tmp/build_hash_2.txt | head -20; exit 1
  fi
else
  run
fi
