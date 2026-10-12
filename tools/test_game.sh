#!/usr/bin/env bash
# 게임 헤드리스 단위 시험 (SD-19 §6.17). 스크립트 오류(파싱·실행)도 실패로 센다.
set -uo pipefail
cd "$(dirname "$0")/../game"
godot --headless --import > /dev/null 2>&1
out=$(godot --headless --path . -s res://tests/run_tests.gd 2>&1)
code=$?
echo "$out" | grep -E "단위 시험|FAIL|SCRIPT ERROR|Parse Error" 
if echo "$out" | grep -q "SCRIPT ERROR"; then
  echo "스크립트 오류 있음 → 실패"; exit 1
fi
exit $code
