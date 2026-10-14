#!/usr/bin/env bash
# 분기 봇(단계 0-12, SD-19 §10.2 봇 플레이): 탈출 4가지 × MQ-101 해법 5가지 = 20판을 처음(개방의 날 관리동 호출)부터
# 1막 아침까지 한 번에 돌린다(--chain). 판마다 로그·스크린샷을 OUT/e<탈출>s<해법>/ 에 남기고, 끝에 결과 표를 찍는다.
# 쓰는 법: tools/qa/branch_matrix.sh [OUT=/tmp/matrix] [동시=3] [탈출 목록="1 2 3 4"] [해법 목록="1 2 3 4 5"]
# 화면(스크린샷)이 필요하므로 xvfb-run으로 돌린다. 봇은 실시간으로 움직여 한 판 약 8~10분.
set -uo pipefail
cd "$(dirname "$0")/../.."
OUT=${1:-/tmp/matrix}
JOBS=${2:-3}
ESCS=${3:-"1 2 3 4"}
SOLS=${4:-"1 2 3 4 5"}
mkdir -p "$OUT"
run_one() {
	local e=$1 s=$2 d="$OUT/e${1}s${2}"
	rm -rf "$d"; mkdir -p "$d"
	timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path game --resolution 1280x720 \
		res://scenes/story/prologue.tscn -- --auto --from=p4e --esc="$e" --sol="$s" --chain --log --shots="$d" > "$d/log.txt" 2>&1
	echo $? > "$d/exit.txt"
}
export -f run_one
export OUT
for e in $ESCS; do for s in $SOLS; do echo "$e $s"; done; done | xargs -P "$JOBS" -L 1 bash -c 'run_one $0 $1'
printf "%-6s %-4s %-6s %s\n" "판" "끝" "오류" "결과"
fail=0
for e in $ESCS; do for s in $SOLS; do
	d="$OUT/e${e}s${s}"
	p4=$(grep -o "MQ-P4 완료: 탈출 [0-9]" "$d/log.txt" | head -1)
	mq=$(grep "MQ-101 완료" "$d/log.txt" | head -1 | sed 's/MQ-101 완료: //')
	err=$(grep -c "SCRIPT ERROR" "$d/log.txt")
	ok="○"
	if [ -z "$p4" ] || [ -z "$mq" ] || [ "$err" != "0" ]; then ok="×"; fail=1; fi
	printf "%-6s %-4s %-6s %s | %s\n" "e${e}s${s}" "$ok" "$err" "$p4" "$mq"
done; done
exit $fail
