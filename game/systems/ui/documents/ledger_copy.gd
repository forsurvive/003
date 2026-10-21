## 출근부 옮겨 치기 2쪽 — 봉천 '미수금' 아홉 줄(FQ-SB-01, SD-04d §6.3 · 단계 1-12f · 계획 _plans/1-12f §4.2 · §6).
## 왼쪽: 올해 옛 출근부(줄 끝 붉은 '미수' · '완납' 도장 줄은 흐리게). 오른쪽: 새 장부(타자기 정리본) — 줄마다 ◀▶로 [그대로 친다] / [건너뛴다].
## 건너뛰기는 실장 구만호가 감독 책상을 비웠을 때만(FQ_SB01_AWAY — 이 화면을 연 순간 한 번 읽는다). 보고 있으면 줄은 '그대로'로 묶인다.
## [타자 친다]를 누르면 오른쪽 장이 한 줄씩 쳐지고 닫힌다 — 고른 줄을 FQ_SB01_X1~X9에, 친 쪽 수 FQ_SB01_TYPED = 2. [나중에]는 아무것도 바꾸지 않는다.
class_name LedgerCopy
extends DocScreen

## [변수 꼬리, 이름, 사유, 금액, 인물 ID(이름 없는 줄은 "")] — 이름 없는 넷은 칸마다 다르게(재미 검수 §6: 같은 글 넷 금지)
const LINES := [
	["1", "오봉수", "고물상 · 고철 납품 선금 받고 미납(6월)", 180, "N-R01-026"],
	["2", "남무진", "대장간 · 숯 · 고철 선대(3월)", 200, "N-R01-030"],
	["3", "오재윤", "인력 등록 뒤 무단 불참 2회 · 위약금", 60, "N-R01-035"],
	["4", "남건희", "선급 일당 받고 안 나옴(9월)", 90, "N-R01-039"],
	["5", "오영자", "계단 미용실 · 약품 대납(5월)", 120, "N-R01-501"],
	["6", "번호 218", "등록지 신림 · 목걸이 번호 재발급 2회", 50, ""],
	["7", "번호 233", "아랫문 텃밭 · 나이 칸 '60?'", 70, ""],
	["8", "번호 240", "물지게 · 이름 칸에 지운 자국", 40, ""],
	["9", "번호 251", "이름 대신 '할머니'", 30, ""],
]
const ROW_Y := 62
const ROW_H := 27

var skip := {}               ## 줄 꼬리 → 건너뛸까
var watched := true
var typed_at := -1.0


func setup(state: StoryState) -> DocScreen:
	st = state
	watched = int(st.vars.get_v("FQ_SB01_AWAY")) == 0
	for l in LINES:
		skip[l[0]] = int(st.vars.get_v("FQ_SB01_X" + l[0])) == 1 and not watched
	cancel_ok = true
	return self


func stamped(tail: String) -> bool:
	return int(st.vars.get_v("FQ_SB01_PD" + tail)) == 1


func _draw_doc() -> void:
	desk()
	var L := Rect2(12, 10, 300, 316)
	var R := Rect2(326, 10, 302, 316)
	paper(L)
	paper(R)
	text(Vector2(162, 16), "2277 출근부 — 봉천 계단마을", f12b, 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(477, 16), "출근부 — 정리본", f12b, 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(20, 36), "이름 · 사유", f10, 10, C["P05"])
	text(Vector2(304, 36), "미수", f10, 10, C["P05"], HORIZONTAL_ALIGNMENT_RIGHT)
	text(Vector2(334, 36), "새 장부", f10, 10, C["P05"])
	hline(16, 308, 52, INK, 2.0)
	hline(330, 624, 52, INK, 2.0)
	var shown := 0                                                       # 타자 연출: 친 줄 수
	if typed_at >= 0.0:
		shown = clampi(int((time - typed_at) * 6.0), 0, LINES.size())
	for i in LINES.size():
		var l: Array = LINES[i]
		var tail: String = l[0]
		var y := float(ROW_Y + i * ROW_H)
		var dead_line: bool = str(l[4]) != "" and st.is_dead(str(l[4]))
		var pd: bool = stamped(tail)
		var ink: Color = C["P06"] if pd else INK2
		text(Vector2(20, y), str(l[1]), f12b, 12, ink)
		text(Vector2(20, y + 13), str(l[2]) + (" (사망 — 유족 승계)" if dead_line else ""), f8, 8, C["P06"] if pd else C["P03"])
		text(Vector2(304, y + 2), "%d" % int(l[3]), f10, 10, ink, HORIZONTAL_ALIGNMENT_RIGHT)
		if pd:
			stamp(Vector2(258, y + 10), "완납", 11.0)
		else:
			text(Vector2(262, y + 2), "미수", f10, 10, RED)
		hline(16, 308, y + 24, C["P07"])
		# 오른쪽 장 — 줄 칸(완납 줄은 옮길 줄이 아니다)
		var row := Rect2(330, y - 2, 294, 24)
		var can: bool = not pd and not watched and typed_at < 0.0
		var lr := Rect2(560, y + 2, 12, 14)
		var rr := Rect2(574, y + 2, 14, 14)
		var sel := item(tail, row, not pd and typed_at < 0.0, can, lr, rr)
		if sel and typed_at < 0.0:
			box(Rect2(331, y - 1, 292, 22), C["P09"])
		if pd:
			text(Vector2(336, y + 3), "— 옮길 줄 없음 —", f10, 10, C["P06"])
		elif skip[tail]:
			text(Vector2(336, y + 3), "(건너뜀)", f10, 10, C["P05"])
		else:
			var line := "%s · 미수 %d" % [l[1], int(l[3])]
			if typed_at >= 0.0:
				if i >= shown:
					line = ""
			text(Vector2(336, y + 3), line, f10, 10, INK)
		if not pd and typed_at < 0.0:
			var on: Color = C["P02"] if can else C["P07"]
			arrows(564, y + 5, on, on)
			text(Vector2(620, y + 3), "건너뜀" if skip[tail] else "그대로", f8, 8, C["P05"] if can else C["P07"], HORIZONTAL_ALIGNMENT_RIGHT)
		hline(330, 624, y + 24, C["P07"])
	var n_skip := 0
	for k in skip:
		if skip[k]:
			n_skip += 1
	var loud := not watched and n_skip >= 4                                  # 넷 넘게 빼면 발각 40%(원문) — 치기 전에 셋으로 줄일 여지(1-12f 재미 검수)
	var note := "구만호가 감독 책상에서 이쪽을 본다 — 줄을 건너뛸 수 없다." if watched else \
		("빨간펜이 고개를 든다 — 봉천 묶음 줄을 센다." if loud else "감독 책상이 비었다. 빨간펜은 등을 돌리고 번호를 센다.")
	text(Vector2(16, 332), note, f10, 10, C["P54"] if watched or loud else C["P08"])         # 책상 위 글 — 밝게
	var labels := [["later", "나중에", typed_at < 0.0], ["ok", "타자 친다", typed_at < 0.0]]
	for i in labels.size():
		var r := Rect2(628 - 84 * (labels.size() - i), 328, 78, 18)
		var s := item(labels[i][0], r, labels[i][2])
		paper_button(r, labels[i][1], labels[i][0] == "ok", s, labels[i][2])


func _adjust(id: String, _d: int) -> void:
	if not skip.has(id) or watched or stamped(id) or typed_at >= 0.0:
		return
	skip[id] = not skip[id]


func _press(id: String) -> void:
	if skip.has(id):
		_adjust(id, 1)
		return
	match id:
		"later":
			close(false)
		"ok":
			if typed_at < 0.0:
				for l in LINES:
					st.vars.set_v("FQ_SB01_X" + l[0], 1 if skip[l[0]] and not stamped(l[0]) else 0)
				st.vars.set_v("FQ_SB01_TYPED", 2)
				typed_at = time
				busy = 2.0


func _busy_done() -> void:
	close(true)


## 시험 · 봇: 화면 없이 고른 꼬리만 건너뛰고 친다(보고 있으면 아무것도 건너뛰지 않는다)
static func type_now(state: StoryState, skip_tails: Array) -> void:
	var w: bool = int(state.vars.get_v("FQ_SB01_AWAY")) == 0
	for l in LINES:
		var t: String = l[0]
		var pd: bool = int(state.vars.get_v("FQ_SB01_PD" + t)) == 1
		state.vars.set_v("FQ_SB01_X" + t, 1 if (t in skip_tails) and not w and not pd else 0)
	state.vars.set_v("FQ_SB01_TYPED", 2)
