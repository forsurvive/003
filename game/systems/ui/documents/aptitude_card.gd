## 재건 행정 요원 적성 평가 — 진공관 판독 카드 (MQ-P3 단계 30, SD-03a §7.3 '시험지는 OMR 카드 비슷한 진공관 판독 카드 UI').
## 왼쪽 시험지: 문항(요지)과 답 ①~④. 고르면 오른쪽 판독 카드의 그 칸이 연필로 칠해지고 다음 문항으로 넘어간다.
## 오른쪽 판독 카드: 10행 × 4칸(붉은 인쇄), 가장자리 타이밍 표시, 칠한 칸. 카드의 행을 누르면 그 문항으로 돌아간다.
## 10번 문항은 원판 문항(차명수: "바꾸지 말라는 메모가 붙어 있어") — 카드 그 행에 '원판·수정 금지' 쪽지가 붙어 있다.
## [제출]은 10문항을 다 칠해야 켜진다. 제출하면 '판독' 도장이 찍히고 답(PC_APT)과 V_Q10을 적는다.
class_name AptitudeCard
extends DocScreen

const MARKS := ["①", "②", "③", "④"]
const CARD := Rect2(452, 10, 174, 340)

var qs: Array
var answers: Array = []
var q := 0
var fill_t := -1.0            ## 연필로 칠하는 중(시각)
var fill_q := -1
var submitted_at := -1.0
var _layout := {}             ## 문항 → 줄바꿈 결과(그릴 때마다 다시 하지 않는다)


func setup(state: StoryState) -> DocScreen:
	st = state
	qs = CharDocs.load_data().get("aptitude", [])
	answers = CharDocs.aptitude_of(st)
	answers.resize(qs.size())
	for i in answers.size():
		answers[i] = int(answers[i]) if answers[i] != null else 0
	return self


func _wrap(s: String, font: Font, size: int, w: float) -> Array:
	var key := "%s|%d|%d" % [s, size, int(w)]
	if not _layout.has(key):
		_layout[key] = TextWrap.wrap(s, func(x: String) -> float: return font.get_string_size(x, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, w)
	return _layout[key]


func _draw_doc() -> void:
	desk()
	var P := Rect2(16, 10, 424, 340)
	paper(P)
	text(Vector2(228, 16), "재건 행정 요원 적성 평가", f12b, 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(228, 32), "시험지", f15, 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
	hline(24, 432, 52, INK, 2.0)
	var qd: Dictionary = qs[q]
	text(Vector2(28, 62), "문항 %d" % qd["n"], f12b, 12, INK2)
	text(Vector2(428, 62), "%d / %d" % [q + 1, qs.size()], f10, 10, C["P05"], HORIZONTAL_ALIGNMENT_RIGHT)
	var y := 82.0
	for ln in _wrap(str(qd["q"]) + ".", f12, 12, 392.0):
		text(Vector2(36, y), ln, f12, 12, C["P02"])
		y += 18.0
	y = maxf(y + 10.0, 150.0)
	for i in 4:
		var lines := _wrap(str(qd["opts"][i]["text"]), f12, 12, 340.0)
		var h := 10.0 + 16.0 * lines.size()
		var r := Rect2(28, y, 400, h)
		var sel := item("opt%d" % i, r, submitted_at < 0.0)
		var chosen := int(answers[q]) == i + 1
		if sel:
			box(r, C["P09"])
			box(r, INK, false)
		_bubble(Vector2(40, y + 5 + 7), i, chosen, fill_q == q and chosen)
		var ty := y + 5.0
		for ln in lines:
			text(Vector2(58, ty), ln, f12, 12, INK2 if chosen else C["P02"])
			ty += 16.0
		y += h + 6.0
	if int(qd["n"]) == 10:
		text(Vector2(28, 292), "※ 이 문항은 원판 문항입니다. 문구를 고치지 마십시오.", f10, 10, C["P05"])
	var done := answers.count(0) == 0
	var btns := [["prev", "이전 문항", q > 0], ["next", "다음 문항", q < qs.size() - 1 and int(answers[q]) > 0], ["submit", "제출", done]]
	for i in btns.size():
		var r := Rect2(120 + i * 106, 318, 96, 18)
		var s := item(btns[i][0], r, btns[i][2] and submitted_at < 0.0)
		paper_button(r, btns[i][1], btns[i][0] == "submit", s, btns[i][2])
	_draw_card()


## 시험지의 답 동그라미(①~④): 고른 답은 연필로 칠한다
func _bubble(c: Vector2, i: int, chosen: bool, filling: bool) -> void:
	view.draw_arc(c, 6.5, 0, TAU, 24, RED, 1.0)
	if chosen:
		var k := 1.0 if not filling else clampf((time - fill_t) / 0.3, 0.0, 1.0)
		view.draw_circle(c, 5.0 * k, C["P02"])
	else:
		text(c - Vector2(0, 6), str(i + 1), f10, 10, RED, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_card() -> void:
	var R := CARD
	view.draw_rect(Rect2(R.position + Vector2(3, 3), R.size), C["P03"])
	view.draw_rect(R, Color("D9D2C2"))
	box(R, RED, false)
	text(Vector2(R.get_center().x, R.position.y + 6), "진공관 판독 카드", f12b, 12, RED, HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(R.get_center().x, R.position.y + 22), "세진전자 SJ-OMR 2 · 연필만 쓰시오", f8, 8, RED, HORIZONTAL_ALIGNMENT_CENTER)
	hline(R.position.x + 6, R.end.x - 6, R.position.y + 34, RED)
	text(Vector2(R.position.x + 10, R.position.y + 40), "성명", f10, 10, RED)
	text(Vector2(R.position.x + 44, R.position.y + 40), str(st.vars.get_v("P_FULL")), f12, 12, C["P02"])
	text(Vector2(R.position.x + 10, R.position.y + 56), "등록번호", f10, 10, RED)
	text(Vector2(R.position.x + 58, R.position.y + 56), CharDocs.REGNO, f10, 10, C["P02"])
	hline(R.position.x + 6, R.end.x - 6, R.position.y + 72, RED)
	for j in 4:
		text(Vector2(R.position.x + 62 + j * 24, R.position.y + 78), MARKS[j], f10, 10, RED, HORIZONTAL_ALIGNMENT_CENTER)
	for i in qs.size():
		var y := R.position.y + 92 + i * 21
		var row := Rect2(R.position.x + 4, y - 4, R.size.x - 8, 20)
		var sel := item("row%d" % i, row, submitted_at < 0.0)
		if i == q:
			box(row, Color(RED, 0.10))
		if sel:
			box(row, RED, false)
		view.draw_rect(Rect2(R.end.x - 10, y + 2, 6, 4), C["P01"])          # 타이밍 표시
		text(Vector2(R.position.x + 26, y), "%d" % (i + 1), f10, 10, RED, HORIZONTAL_ALIGNMENT_RIGHT)
		for j in 4:
			var c := Vector2(R.position.x + 62 + j * 24, y + 6)
			var on := int(answers[i]) == j + 1
			view.draw_rect(Rect2(c - Vector2(7, 5), Vector2(14, 10)), RED, false, 1.0)
			if on:
				var k := 1.0 if fill_q != i else clampf((time - fill_t) / 0.3, 0.0, 1.0)
				view.draw_rect(Rect2(c - Vector2(5, 3), Vector2(10.0 * k, 6)), C["P01"])
		if i == 9:
			view.draw_rect(Rect2(R.position.x + 30, y + 13, 50, 9), Color("E8DDA0"))     # 붙여 둔 쪽지
			text(Vector2(R.position.x + 32, y + 13), "원판·수정 금지", f8, 8, C["P03"])
	text(Vector2(R.position.x + 10, R.end.y - 18), "칠한 칸  %d / %d" % [answers.size() - answers.count(0), qs.size()], f10, 10, RED)
	if submitted_at >= 0.0:
		stamp(Vector2(R.end.x - 26, R.end.y - 18), "판독", 12.0, (time - submitted_at - 0.2) / 0.25)


func _press(id: String) -> void:
	if id.begins_with("opt"):
		var a := int(id.substr(3)) + 1
		answers[q] = a
		fill_t = time
		fill_q = q
		busy = 0.35
	elif id.begins_with("row"):
		q = int(id.substr(3))
		focus_on("opt%d" % maxi(0, int(answers[q]) - 1))
	elif id == "prev" and q > 0:
		q -= 1
	elif id == "next" and q < qs.size() - 1:
		q += 1
	elif id == "submit" and answers.count(0) == 0:
		CharDocs.write_aptitude(st, answers)
		submitted_at = time
		busy = 1.0


func _busy_done() -> void:
	if submitted_at >= 0.0:
		close(true)
		return
	fill_q = -1
	var after := answers.slice(q + 1).find(0)                             # 뒤쪽 빈 문항 → 앞쪽 빈 문항 → 다 칠했으면 [제출]
	if after >= 0:
		q = q + 1 + after
		focus_on("opt0")
	elif answers.find(0) >= 0:
		q = answers.find(0)
		focus_on("opt0")
	else:
		focus_on("submit")
