## 적성 평가 결과 통지서 + 태그 스킬 선택 (MQ-P3 단계 40, SD-03a §7.3 S3, SD-10 §3.4·§8.5, 견본 18_ui_aptitude).
## 왼쪽 통지서: 성명·등록번호·응시일·감독관, 참고 적성 직무(1위 스킬), 추천 태그 1~3과 점수, 차명수의 한마디(빨간 펜),
##   아래 칸 '배정: 관리동 — 관리 후보 1순위'(시험과 상관없이 처음부터 인쇄된 칸), '평가' 도장.
## 오른쪽 태그 선택: 추천 3개가 미리 체크된 채 열린다. 13행을 눌러 체크·해제(3개까지), 체크한 스킬은 값 → 값+15.
## [추천으로] [확정](정확히 3개). 출구 점검표에서 열면(from_exit) 지금 태그로 시작하고 취소할 수 있다.
class_name ResultSheet
extends DocScreen

var answers: Array
var ranking: Array
var picks: Array = []
var full_flash := -1.0        ## 4번째를 고르려 할 때 '선택 3 / 3'을 깜박인다
var confirmed_at := -1.0
var from_exit := false


func setup(state: StoryState, exit_mode := false) -> DocScreen:
	st = state
	from_exit = exit_mode
	cancel_ok = exit_mode
	answers = CharDocs.aptitude_of(st)
	ranking = CharDocs.ranking(answers)
	picks = CharDocs.tags_of(st) if exit_mode and CharDocs.tags_of(st).size() == 3 else _recommended()
	return self


func _recommended() -> Array:
	return ranking.slice(0, 3) if not answers.is_empty() else []


func _draw_doc() -> void:
	desk()
	_draw_notice()
	_draw_tags()


func _draw_notice() -> void:
	var L := Rect2(16, 10, 296, 340)
	paper(L)
	text(Vector2(164, 16), "재건 행정 요원 적성 평가", f12b, 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(164, 32), "결과 통지서", f15, 15, INK, HORIZONTAL_ALIGNMENT_CENTER)
	hline(24, 304, 52, INK, 2.0)
	var rows := [["성명", str(st.vars.get_v("P_FULL"))], ["등록번호", CharDocs.REGNO], ["응시일", "2274. 09. 02."], ["감독관", "차명수"]]
	for i in rows.size():
		text(Vector2(28, 60 + i * 16), rows[i][0], f10, 10, C["P05"])
		text(Vector2(100, 59 + i * 16), rows[i][1], f12, 12, C["P02"])
	box(Rect2(24, 128, 280, 44), INK, false)
	text(Vector2(32, 132), "참고 적성 직무", f10, 10, C["P05"])
	var top: String = ranking[0] if not answers.is_empty() else ""
	var jd := CharDocs.job(top)
	text(Vector2(164, 148), jd["job"] if top != "" else "미응시", f15, 15, C["P02"], HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(28, 178), "추천 태그", f10, 10, C["P05"])
	var sc := CharDocs.score(answers)
	for i in mini(3, ranking.size()):
		if answers.is_empty():
			break
		var k: String = ranking[i]
		text(Vector2(40, 192 + i * 16), "%d. %s" % [i + 1, StoryState.SKILLS[k][0]], f12, 12, C["P02"])
		text(Vector2(200, 194 + i * 16), "%d점" % int(sc.get(k, {"score": 0})["score"]), f10, 10, C["P05"])
	if top != "":
		text(Vector2(40, 242), "— \"%s\"" % jd["line"], f10, 10, RED)
	hline(24, 304, 260, C["P06"])
	text(Vector2(28, 266), "배정", f10, 10, C["P05"])
	text(Vector2(164, 280), "관리동 — 관리 후보 1순위", f15, 15, RED, HORIZONTAL_ALIGNMENT_CENTER)
	stamp(Vector2(274, 314), "평가", 16.0)
	text(Vector2(28, 318), "※ 적성 직무는 배정 참고용입니다.", f10, 10, C["P05"])
	text(Vector2(28, 332), "   배정 칸은 평가 위원회가 정합니다.", f10, 10, C["P05"])


func _draw_tags() -> void:
	var R := Rect2(324, 10, 302, 340)
	paper(R)
	text(Vector2(475, 16), "태그 스킬 선택  (3개)", f12b, 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(475, 32), "추천은 참고일 뿐입니다. 자유롭게 바꾸세요.", f10, 10, C["P05"], HORIZONTAL_ALIGNMENT_CENTER)
	var base := CharDocs.base_skills(CharDocs.stats_of(st))
	var rec := _recommended()
	for i in StoryState.SKILL_ORDER.size():
		var k: String = StoryState.SKILL_ORDER[i]
		var y := 50.0 + i * 19.0
		var r := Rect2(330, y - 2, 290, 17)
		var sel := item(k, r, confirmed_at < 0.0)
		var on := k in picks
		if sel:
			box(r, C["P09"])
			box(r, INK, false)
		box(Rect2(334, y + 1, 11, 11), INK, false)
		if on:
			check_mark(Vector2(335, y + 1), RED)
		text(Vector2(352, y), StoryState.SKILLS[k][0], f12, 12, C["P02"])
		if k in rec:
			text(Vector2(462, y + 2), "추천", f8, 8, INK)
		text(Vector2(540, y), str(base[k]), f12, 12, C["P05"], HORIZONTAL_ALIGNMENT_RIGHT)
		if on:
			text(Vector2(548, y), "→", f12, 12, C["P05"])
			text(Vector2(612, y), str(int(base[k]) + 15), f12b, 12, RED, HORIZONTAL_ALIGNMENT_RIGHT)
	var blink := full_flash >= 0.0 and time - full_flash < 0.6 and fmod(time - full_flash, 0.2) < 0.1
	text(Vector2(334, 304), "선택 %d / 3" % picks.size(), f12b, 12, C["P09"] if blink else (RED if picks.size() == 3 else INK))
	var btns := [["rec", "추천으로" if not answers.is_empty() else "모두 해제", true], ["ok", "확정", picks.size() == 3]]
	if from_exit:
		btns.insert(0, ["back", "그대로", true])
	var x := 620.0 - 90.0 * btns.size()
	for b in btns:
		var r := Rect2(x + 10, 322, 80, 18)
		var s := item(b[0], r, b[2] and confirmed_at < 0.0)
		paper_button(r, b[1], b[0] == "ok", s, b[2])
		x += 90.0
	if confirmed_at >= 0.0:
		stamp(Vector2(586, 290), "확정", 14.0, (time - confirmed_at) / 0.25)


func _press(id: String) -> void:
	if id in StoryState.SKILLS:
		if id in picks:
			picks.erase(id)
		elif picks.size() < 3:
			picks.append(id)
		else:
			full_flash = time
		return
	match id:
		"rec":
			picks = _recommended()
		"back":
			close(false)
		"ok":
			if picks.size() == 3:
				var ordered := StoryState.SKILL_ORDER.filter(func(k): return k in picks)
				CharDocs.write_tags(st, ordered)
				confirmed_at = time
				busy = 0.8


func _busy_done() -> void:
	close(true)
