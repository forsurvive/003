## 학교생활기록부 — S.P.E.C.I.A.L. 배분 (MQ-P2 단계 10, SD-10 §2.6, SD-03a §7.2, 견본 18_ui_record).
## 7행: 기록부 항목 + 능력치 이름, 1~10 눈금, 값, ◀▶, 담임 의견(값 구간마다 빨간 펜으로 다시 쓴다).
## 오른쪽: 실시간 미리보기(최대 HP·AP·소지 한도·탐지 반경·레벨업 스킬 포인트, 스킬 13종 초기값).
## 아래: 남은 점수, [되돌리기](한 칸 전으로) [기본값] [확정](남은 점수 0일 때만). 확정하면 학생 서명이 써지고 담임 도장이 찍힌다.
## 출구 점검표에서 열면 [그대로]가 붙고 취소 키로도 닫힌다(고친 값은 버린다).
class_name RecordBook
extends DocScreen

const ROW_Y := 60
const ROW_H := 38

var stats: Dictionary
var undo: Array = []
var rewrite := {}             ## 능력치 → 담임 의견을 다시 쓰기 시작한 시각
var signed_at := -1.0
var year := 2268


func setup(state: StoryState, from_exit := false) -> DocScreen:
	st = state
	stats = CharDocs.stats_of(st)
	cancel_ok = from_exit
	return self


func _draw_doc() -> void:
	desk()
	var L := Rect2(16, 10, 436, 340)
	paper(L)
	text(Vector2(234, 16), "볼트 S-07 초등과정 학교생활기록부", f15, 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(24, 38), "성명  " + str(st.vars.get_v("P_FULL")), f12, 12, C["P02"])
	text(Vector2(140, 38), "등록번호  " + CharDocs.REGNO, f12, 12, C["P02"])
	text(Vector2(360, 38), "학년도 %d" % year, f12, 12, C["P02"])
	hline(20, 448, 54, INK, 2.0)
	for i in CharDocs.ORDER.size():
		var c: String = CharDocs.ORDER[i]
		var y := float(ROW_Y + i * ROW_H)
		var row := Rect2(20, y, 428, 34)
		var lr := Rect2(304, y + 2, 12, 14)
		var rr := Rect2(318, y + 2, 14, 14)
		var sel := item(c, row, true, true, lr, rr)
		if sel:
			box(Rect2(21, y + 1, 426, 32), C["P09"])
		box(row, C["P06"], false)
		text(Vector2(26, y + 3), CharDocs.record_item(c), f12b, 12, INK2)
		text(Vector2(26, y + 18), StoryState.STATS[c], f10, 10, C["P05"])
		var v := int(stats[c])
		for k in 10:
			var bx := 136.0 + k * 15.0
			box(Rect2(bx, y + 4, 12, 11), INK, false)
			if k < v:
				box(Rect2(bx + 2, y + 6, 8, 7), INK)
		text(Vector2(300, y + 3), str(v), f12b, 12, C["P02"], HORIZONTAL_ALIGNMENT_RIGHT)
		var on_l := C["P02"] if CharDocs.can_lower(stats, c) else C["P07"]
		var on_r := C["P02"] if CharDocs.can_raise(stats, c) else C["P07"]
		if not sel:
			on_l = C["P05"] if CharDocs.can_lower(stats, c) else C["P07"]
			on_r = C["P05"] if CharDocs.can_raise(stats, c) else C["P07"]
		arrows(308, y + 5, on_l, on_r)
		text(Vector2(136, y + 19), "담임 의견:", f10, 10, C["P05"])
		var cm := CharDocs.comment(c, v)
		if rewrite.has(c):
			var n := int((time - float(rewrite[c])) * 40.0)
			if n >= cm.length():
				rewrite.erase(c)
			else:
				cm = cm.substr(0, n)
		text(Vector2(186, y + 19), cm, f10, 10, RED)
	var left := CharDocs.points_left(stats)
	text(Vector2(24, 330), "남은 점수  %d" % left, f12b, 12, RED if left > 0 else INK)
	var labels := [["undo", "되돌리기", not undo.is_empty()], ["default", "기본값", true], ["ok", "확정", left == 0]]
	if cancel_ok:
		labels.insert(0, ["back", "그대로", true])                         # 출구 점검표에서 열었을 때: 고치지 않고 돌아가기
	for i in labels.size():
		var r := Rect2(448 - 84 * (labels.size() - i), 326, 76, 18)
		var s := item(labels[i][0], r, labels[i][2])
		paper_button(r, labels[i][1], labels[i][0] == "ok", s, labels[i][2])
	if signed_at >= 0.0:
		stamp(Vector2(420, 306), "담임", 14.0, (time - signed_at - 0.5) / 0.25)
	_draw_preview()


func _draw_preview() -> void:
	var R := Rect2(464, 10, 162, 340)
	paper(R)
	text(Vector2(545, 16), "미리보기", f12b, 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var d := CharDocs.derived(stats)
	var rows := [["최대 HP", str(d["hp"])], ["최대 AP", str(d["ap"])], ["소지 한도", str(d["carry"])], ["탐지 반경", "%d칸" % d["detect"]],
		["레벨업 스킬", str(d["skill_pts"])]]
	for i in rows.size():
		text(Vector2(472, 34 + i * 15), rows[i][0], f10, 10, C["P03"])
		text(Vector2(618, 34 + i * 15), rows[i][1], f10, 10, C["P02"], HORIZONTAL_ALIGNMENT_RIGHT)
	hline(470, 620, 110, C["P06"])
	var sk := CharDocs.base_skills(stats)
	var fc: String = items[focus]["id"] if focus < items.size() and items[focus]["id"] in CharDocs.ORDER else ""
	for i in StoryState.SKILL_ORDER.size():
		var k: String = StoryState.SKILL_ORDER[i]
		var y := 115 + i * 15
		var linked: bool = fc != "" and (StoryState.SKILLS[k][1] == fc or fc == "LK")
		text(Vector2(472, y), StoryState.SKILLS[k][0], f10, 10, INK if linked else C["P03"])
		text(Vector2(618, y), str(sk[k]), f10, 10, INK if linked else C["P02"], HORIZONTAL_ALIGNMENT_RIGHT)
	hline(470, 620, 312, C["P06"])
	text(Vector2(472, 318), "학생 서명", f10, 10, C["P05"])
	hline(472, 618, 342, C["P05"])
	if signed_at >= 0.0:
		var nm := str(st.vars.get_v("P_FULL"))
		var n := clampi(int((time - signed_at) * 12.0), 0, nm.length())
		text(Vector2(500, 328), nm.substr(0, n), f12b, 12, INK2)


func _adjust(id: String, d: int) -> void:
	if not id in CharDocs.ORDER or signed_at >= 0.0:
		return
	if (d > 0 and not CharDocs.can_raise(stats, id)) or (d < 0 and not CharDocs.can_lower(stats, id)):
		return
	undo.append(stats.duplicate())
	var before := CharDocs.comment(id, int(stats[id]))
	stats[id] = int(stats[id]) + d
	if CharDocs.comment(id, int(stats[id])) != before:
		rewrite[id] = time


func _press(id: String) -> void:
	match id:
		"back":
			close(false)
		"undo":
			if not undo.is_empty():
				var prev: Dictionary = undo.pop_back()
				for c in CharDocs.ORDER:
					if prev[c] != stats[c]:
						rewrite[c] = time
				stats = prev
		"default":
			undo.append(stats.duplicate())
			stats = CharDocs.default_stats()
		"ok":
			if CharDocs.points_left(stats) == 0 and signed_at < 0.0:
				CharDocs.write_stats(st, stats)
				signed_at = time
				busy = 1.4


func _busy_done() -> void:
	close(true)
