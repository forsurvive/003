## 세진전자 SJ-RT7 진공관 등록 단말 — 출생신고서(MQ-P1 단계 10)와 출구 점검표·전출 신고서(MQ-P4 단계 60).
## SD-10 §8.2·§8.3·§8.6, SD-03a §7.1·§7.4, SD-18 §9.1.4, 견본 18_ui_birth.
## 출생신고서: 신고인 · 성명(성 1~2자 + 이름 1~4자) · 성별 · 부/모 · 등록번호 · 출생 일시 · 출생 장소 · 외형 · 관제망 회선 확인.
##   오른쪽 '세진 성장 예측기'에 19세 모습(맵 페이퍼돌 4방향 + 크게 돌아가는 상반신)을 색으로 띄우고 머리 모양·머리색·피부를 고른다.
##   [신고] → 6번 칸 램프가 '삑' 두 번에 맞춰 초록으로 깜박이고 '응답 1회' → 승인 도장 → '등록 완료' (복선, SD-03a §7.1).
## 출구 점검표: 성명·성별·외형은 이 화면에서, S.P.E.C.I.A.L.·태그는 [고치기]로 생활기록부·태그 화면을 다시 연다.
##   등록번호 칸은 고칠 수 없다("성명은 바꿀 수 있어도 등록번호는 바뀌지 않습니다"). [변경 없음]은 열 때 상태로 되돌리고 닫는다.
class_name RegisterTerminal
extends DocScreen

const ROW_X := 38
const VAL_X := 120
const ROW_Y := 64
const ROW_H := 19
const PANEL := Rect2(374, 64, 232, 132)
const LOOK_ROWS := [["hair", "머리 모양"], ["hcol", "머리색"], ["skin", "피부"]]
const SMALL_DIRS := [2, 0, 6, 4]
const SPIN := [2, 1, 0, 7, 6, 5, 4, 3]
const SIGNAL_SEQ := [0.5, 0.7, 0.9, 1.1]          ## 6번 칸 램프: 켜짐·꺼짐·켜짐·꺼짐(삑 두 번)

var mode := "birth"
var look: Dictionary
var sur_edit: LineEdit
var given_edit: LineEdit
var error := ""
var preview: SubViewport
var preview_rect: TextureRect
var overlay: Control
var dolls: Array = []
var big: Paperdoll
var rng := RandomNumberGenerator.new()
var submit_at := -1.0
var regno_msg_at := -1.0
var snapshot := {}
var sub: DocScreen
var _pool_name := ""          ## 무작위로 넣은 이름(성별을 바꾸면 그 성별 이름으로 바꿔 준다 — 직접 고친 이름은 그대로)
var _bezel: StyleBoxFlat
var _tube: StyleBoxFlat


func setup(state: StoryState, m := "birth", seed := 0) -> DocScreen:
	st = state
	mode = m
	rng.seed = seed if seed != 0 else int(Time.get_ticks_usec())
	look = CharDocs.look_of(st)
	var sur: String = st.vars.get_v("P_SURNAME")
	var given: String = st.vars.get_v("P_GIVEN")
	if sur == "":
		sur = CharDocs.default_surname()
	if given == "":
		given = CharDocs.random_given(look["sex"], rng)
		_pool_name = given
	if mode == "exit":
		for k in ["P_SURNAME", "P_GIVEN", "P_FULL", "P_REGNO", "PC_SEX", "PC_HAIR", "PC_HCOL", "PC_SKIN", "PC_TAG1", "PC_TAG2", "PC_TAG3"] \
				+ CharDocs.ORDER.map(func(c): return "PC_" + c):
			snapshot[k] = st.vars.get_v(k)
	_build_nodes(sur, given)
	return self


func _build_nodes(sur: String, given: String) -> void:
	_bezel = StyleBoxFlat.new()
	_bezel.bg_color = C["P02"]
	_bezel.set_corner_radius_all(10)
	_tube = StyleBoxFlat.new()
	_tube.bg_color = AMBER[0]
	_tube.set_corner_radius_all(8)
	sur_edit = _edit(sur, 2, Rect2(VAL_X, _row_y(1) - 2, 34, 17))
	given_edit = _edit(given, 4, Rect2(VAL_X + 64, _row_y(1) - 2, 62, 17))
	preview = SubViewport.new()
	preview.size = Vector2i(232, 104)
	preview.transparent_bg = true
	preview.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST   # 선형이면 팔레트 색인이 섞인다
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(preview)
	for i in 4:
		var d := Paperdoll.new()
		d.position = Vector2(24 + i * 30, 70)
		preview.add_child(d)
		dolls.append(d)
	big = Paperdoll.new()
	big.position = Vector2(184, 100)                                         # 3배 전신(머리 24·몸 14픽셀 → 96픽셀)
	big.scale = Vector2(3, 3)
	preview.add_child(big)
	preview_rect = TextureRect.new()
	preview_rect.texture = preview.get_texture()
	preview_rect.position = PANEL.position + Vector2(0, 16)
	preview_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.add_child(preview_rect)
	overlay = Control.new()
	overlay.size = Vector2(640, 360)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_scanlines)
	view.add_child(overlay)
	_apply_look()


func _edit(v: String, max_len: int, r: Rect2) -> LineEdit:
	var e := LineEdit.new()
	e.text = v
	e.max_length = max_len
	e.position = r.position
	e.custom_minimum_size = r.size
	e.size = r.size
	e.add_theme_font_override("font", f12)
	e.add_theme_font_size_override("font_size", 12)
	e.add_theme_constant_override("minimum_character_width", 0)
	e.add_theme_color_override("font_color", AMBER[7])
	e.add_theme_color_override("caret_color", AMBER[6])
	e.add_theme_color_override("selection_color", AMBER[3])
	e.add_theme_color_override("font_placeholder_color", AMBER[3])
	for st_name in ["normal", "focus", "read_only"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = AMBER[1] if st_name == "focus" else AMBER[0]
		sb.border_color = AMBER[6] if st_name == "focus" else AMBER[3]
		sb.set_border_width_all(1)
		sb.content_margin_left = 4
		sb.content_margin_top = 0
		sb.content_margin_bottom = 0
		e.add_theme_stylebox_override(st_name, sb)
	e.context_menu_enabled = false
	e.text_changed.connect(func(_t: String) -> void:
		_pool_name = ""
		error = "")
	e.text_submitted.connect(func(_t: String) -> void:
		e.release_focus()
		_move(1))
	e.focus_entered.connect(func() -> void: focus_on("sur" if e == sur_edit else "given"))
	view.add_child(e)
	return e


func _ready() -> void:
	super._ready()
	for e in [sur_edit, given_edit]:                                       # 트리에 붙기 전 기본 테마로 잡힌 최소 크기를 풀어 준다
		e.size = e.custom_minimum_size


func _row_y(i: int) -> float:
	return ROW_Y + i * ROW_H


func _apply_look() -> void:
	var pl := CharDocs.paperdoll_look(look)
	for d in dolls:
		d.set_look(pl)
	big.set_look(pl)


func _tick(_dt: float) -> void:
	for i in 4:
		dolls[i].show_frame("idle", SMALL_DIRS[i], 0)
	big.show_frame("idle", SPIN[int(time / 1.2) % SPIN.size()], 0)
	overlay.queue_redraw()


# ---------------------------------------------------------------- 그리기
func _draw_doc() -> void:
	var full := Rect2(-view.position, get_viewport().get_visible_rect().size)
	view.draw_rect(full, C["P08"])                                              # 세진 크림색 외장
	view.draw_rect(Rect2(full.position.x, 0, full.size.x, 15), C["P62"])
	hline(full.position.x, full.end.x, 14, C["P61"])
	var head := "세진전자  SJ-RT7 진공관 등록 단말  ·  볼트 S-07 " + ("행정실" if mode == "birth" else "출입 통제실")
	text(Vector2(8, 1), head, f10, 10, C["P09"])
	for x in [580, 596, 612]:
		view.draw_circle(Vector2(x + 4.5, 7.5), 4.5, C["P61"])
	view.draw_style_box(_bezel, Rect2(18, 22, 604, 312))
	view.draw_style_box(_tube, Rect2(22, 26, 596, 304))
	for x in range(40, 600, 40):                                               # 아래 판의 진공관 창
		view.draw_circle(Vector2(x + 5, 346), 5.0, C["P58"])
		view.draw_rect(Rect2(x + 4, 344, 1, 1), C["P60"])
	var title := "볼트 S-07 출생신고서" if mode == "birth" else "볼트 S-07 전출 신고서"
	text(Vector2(34, 32), title, f15, 15, AMBER[7])
	text(Vector2(604, 36), "서식 제1호 · 2258" if mode == "birth" else "서식 제9호 · 2277", f10, 10, AMBER[4], HORIZONTAL_ALIGNMENT_RIGHT)
	hline(34, 604, 54, AMBER[3])
	if mode == "birth":
		_draw_birth_rows()
	else:
		_draw_exit_rows()
	_draw_panel()
	_draw_bottom()
	sur_edit.editable = submit_at < 0.0
	given_edit.editable = submit_at < 0.0


func _label(i: int, s: String, sel: bool) -> void:
	var y := _row_y(i)
	if sel:
		view.draw_rect(Rect2(ROW_X - 6, y - 3, 3, 15), AMBER[6])
	text(Vector2(ROW_X, y), s, f12, 12, AMBER[6] if sel else AMBER[4])
	hline(VAL_X, 354, y + 15, AMBER[2])


func _value(i: int, s: String, col := 6) -> void:
	text(Vector2(VAL_X + 2, _row_y(i)), s, f12, 12, AMBER[col])


func _name_row(i: int) -> void:
	var y := _row_y(i)
	var s1 := item("sur", Rect2(VAL_X, y - 3, 34, 18))
	var s2 := item("given", Rect2(VAL_X + 64, y - 3, 62, 18))
	_label(i, "성명", s1 or s2)
	text(Vector2(VAL_X + 38, y + 1), "(성)", f10, 10, AMBER[3])
	text(Vector2(VAL_X + 130, y + 1), "(이름)", f10, 10, AMBER[3])
	if submit_at >= 0.0 and time - submit_at > 1.8 and mode == "birth":
		_amber_stamp(Vector2(VAL_X + 206, y + 6), "승인", (time - submit_at - 1.8) / 0.25)


func _sex_row(i: int) -> void:
	var y := _row_y(i)
	var sel := item("sex", Rect2(VAL_X, y - 3, 160, 18), true, true, Rect2(VAL_X, y - 3, 50, 18), Rect2(VAL_X + 60, y - 3, 50, 18))
	_label(i, "성별", sel)
	var m := int(look["sex"]) == CharDocs.SEX_M
	_value(i, "(%s) 남    (%s) 여" % ["●" if m else " ", " " if m else "●"])


func _draw_birth_rows() -> void:
	_label(0, "신고인", false)
	_value(0, "윤정인 (오버시어)")
	_name_row(1)
	_sex_row(2)
	_label(3, "부 / 모", false)
	_value(3, "부 %s이현 (원자로 기사)  ·  모 윤정인" % sur_edit.text, 5)
	_label(4, "등록번호", false)
	_value(4, CharDocs.REGNO + "  (자동 발급)")
	_label(5, "출생 일시", false)
	_value(5, "2258. 03. 02.  04:12")
	_label(6, "출생 장소", false)
	_value(6, "의무과 분만실 (V-08)")
	_look_row(7)
	_label(8, "회선 확인", false)
	var y := _row_y(8)
	var e := time - submit_at if submit_at >= 0.0 else -1.0
	var lamp := false
	for k in range(0, SIGNAL_SEQ.size(), 2):
		if e >= SIGNAL_SEQ[k] and e < SIGNAL_SEQ[k + 1]:
			lamp = true
	view.draw_circle(Vector2(VAL_X + 8, y + 7), 5.0, GREEN[6] if lamp else GREEN[2])
	if lamp:
		view.draw_circle(Vector2(VAL_X + 8, y + 7), 9.0, Color(GREEN[5], 0.35))
	if e >= 1.3:
		text(Vector2(VAL_X + 20, y), "관제망 응답 1회", f12, 12, GREEN[6])
	else:
		text(Vector2(VAL_X + 20, y), "관제망  (입력 불가)", f12, 12, AMBER[3])


func _look_row(i: int) -> void:
	var y := _row_y(i)
	var sel := item("look", Rect2(VAL_X, y - 3, 100, 18))
	_label(i, "외형", sel)
	view.draw_rect(Rect2(VAL_X, y - 3, 100, 18), AMBER[6] if sel else AMBER[4])
	text(Vector2(VAL_X + 50, y), "[성장 예측]", f12, 12, AMBER[0], HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(VAL_X + 108, y + 1), "19세 모습을 미리 봅니다 ▶", f10, 10, AMBER[4])


func _draw_exit_rows() -> void:
	_label(0, "신고인", false)
	_value(0, "본인 (전출)")
	_name_row(1)
	_sex_row(2)
	_look_row(3)
	var y := _row_y(4)
	var s := item("stats", Rect2(VAL_X, y - 3, 234, 18))
	_label(4, "S.P.E.C.I.A.L.", s)
	var parts := []
	for c in CharDocs.ORDER:
		parts.append("%s%d" % ["SPECIAL"[CharDocs.ORDER.find(c)], int(st.vars.get_v("PC_" + c))])
	_value(4, " ".join(parts), 6)
	text(Vector2(352, y), "[고치기]", f10, 10, AMBER[7] if s else AMBER[4], HORIZONTAL_ALIGNMENT_RIGHT)
	y = _row_y(5)
	s = item("tags", Rect2(VAL_X, y - 3, 234, 18))
	_label(5, "태그 스킬", s)
	var tags := CharDocs.tags_of(st).map(func(k): return StoryState.SKILLS[k][0])
	_value(5, " · ".join(tags) if not tags.is_empty() else "(없음)", 6)
	text(Vector2(352, y), "[고치기]", f10, 10, AMBER[7] if s else AMBER[4], HORIZONTAL_ALIGNMENT_RIGHT)
	y = _row_y(6)
	s = item("regno", Rect2(VAL_X, y - 3, 234, 18))
	_label(6, "등록번호", s)
	_value(6, CharDocs.REGNO + "  (변경 불가)", 4)
	if regno_msg_at >= 0.0 and time - regno_msg_at < 3.0:
		text(Vector2(ROW_X, _row_y(7) + 2), "성명은 바꿀 수 있어도 등록번호는 바뀌지 않습니다.", f12, 12, AMBER[7])


func _draw_panel() -> void:
	view.draw_rect(PANEL, AMBER[1])
	box(PANEL, AMBER[4], false)
	text(PANEL.position + Vector2(6, 3), "세진 성장 예측기", f10, 10, AMBER[6])
	text(PANEL.position + Vector2(226, 3), "19세", f10, 10, AMBER[4], HORIZONTAL_ALIGNMENT_RIGHT)
	text(PANEL.position + Vector2(6, 119), "%s · %s · %s" % [look["hair"], look["hcol"], look["skin"]], f10, 10, AMBER[4])
	for i in LOOK_ROWS.size():
		var id: String = LOOK_ROWS[i][0]
		var y := PANEL.end.y + 6 + i * 18
		var r := Rect2(PANEL.position.x, y - 2, PANEL.size.x, 17)
		var sel := item(id, r, submit_at < 0.0, true, Rect2(PANEL.position.x + 66, y - 2, 14, 16), Rect2(PANEL.position.x + 206, y - 2, 16, 16))
		if sel:
			view.draw_rect(r, AMBER[2])
		text(Vector2(PANEL.position.x + 6, y), LOOK_ROWS[i][1], f12, 12, AMBER[6] if sel else AMBER[4])
		arrows(PANEL.position.x + 66, y + 2, AMBER[6] if sel else AMBER[3], Color(0, 0, 0, 0))
		arrows(PANEL.position.x + 202, y + 2, Color(0, 0, 0, 0), AMBER[6] if sel else AMBER[3])
		text(Vector2(PANEL.position.x + 144, y), _look_name(id), f12, 12, AMBER[7] if sel else AMBER[5], HORIZONTAL_ALIGNMENT_CENTER)
		if id == "skin":
			var pal: Dictionary = Paperdoll.meta["palettes"]["skin"]
			view.draw_rect(Rect2(PANEL.position.x + 184, y + 2, 10, 10), Color(pal[look["skin"]][3]))
		if id == "hcol":
			var pal2: Dictionary = Paperdoll.meta["palettes"]["hair"]
			view.draw_rect(Rect2(PANEL.position.x + 184, y + 2, 10, 10), Color(pal2[look["hcol"]][2]))


func _look_name(id: String) -> String:
	match id:
		"hair":
			return CharDocs.HAIR_NAMES[CharDocs.HAIRS.find(look["hair"])]
		"hcol":
			return CharDocs.HCOL_NAMES[CharDocs.HCOLS.find(look["hcol"])]
		_:
			return "%d호" % (CharDocs.SKINS.find(look["skin"]) + 1)


func _draw_bottom() -> void:
	if mode == "birth":
		text(Vector2(38, 252), "※ 신고 내용은 수도 관제망 등록 원부에 영구 기록됩니다.", f10, 10, AMBER[4])
		text(Vector2(38, 266), "※ 등록 성명 표준 목록 외 이름은 오버시어 승인 필요.", f10, 10, AMBER[4])
	else:
		text(Vector2(38, 266), "※ 볼트 문을 나서면 이 신고서는 다시 고칠 수 없습니다.", f10, 10, AMBER[4])
	var fid: String = items[focus]["id"] if focus < items.size() else ""
	if error == "" and submit_at < 0.0 and fid in ["sur", "given"]:
		text(Vector2(38, 284), "성 1~2자 · 이름 1~4자 · 한글 완성형", f10, 10, AMBER[4])
	if error != "" and fmod(time, 1.0) < 0.75:
		text(Vector2(38, 284), "▶ " + error, f12, 12, AMBER[7])
	var e := time - submit_at if submit_at >= 0.0 else -1.0
	var sent := 1.3 if mode == "birth" else 0.5
	if e >= 0.0 and e < sent:
		text(Vector2(38, 284), "관제망으로 전송 중" + ".".repeat(int(e * 4) % 4), f12, 12, AMBER[6])
	elif e >= (2.3 if mode == "birth" else sent):
		text(Vector2(38, 284), "등록 완료." if mode == "birth" else "전출 처리 완료.", f15, 15, AMBER[7])
	text(Vector2(38, 310), "관리자 인증: 오버시어실", f10, 10, AMBER[5])
	view.draw_circle(Vector2(156, 316), 4.0, AMBER[6] if fmod(time, 1.6) < 1.2 else AMBER[3])
	var btns := [["random", "무작위", false], ["default", "기본값", false], ["ok", "신고", true]] if mode == "birth" \
		else [["keep", "변경 없음", false], ["ok", "확정", true]]
	var x := 606.0 - 86.0 * btns.size()
	for b in btns:
		var r := Rect2(x + 10, 284, 76, 20)
		var s := item(b[0], r, submit_at < 0.0)
		amber_button(r, b[1], b[2], s)
		x += 86.0


func _amber_stamp(c: Vector2, label: String, t: float) -> void:
	if t <= 0.0:
		return
	var k := 1.0 + (1.0 - clampf(t, 0.0, 1.0)) * 0.8
	view.draw_arc(c, 11.0 * k, 0, TAU, 32, AMBER[7], 2.0)
	text(c - Vector2(0, 6), label, f10, 10, AMBER[7], HORIZONTAL_ALIGNMENT_CENTER)


func _draw_scanlines() -> void:
	var r := Rect2(22, 26, 596, 304)
	var y := r.position.y
	while y < r.end.y:
		overlay.draw_rect(Rect2(r.position.x, y, r.size.x, 1), Color(0, 0, 0, 0.16))
		y += 2.0


# ---------------------------------------------------------------- 입력
func _focus_changed(by_mouse: bool) -> void:
	if by_mouse:
		return
	var id := focused_id()
	if id == "sur":
		sur_edit.grab_focus()
	elif id == "given":
		given_edit.grab_focus()
	else:
		_release_edits()


func _release_edits() -> void:
	if is_inside_tree():
		sur_edit.release_focus()
		given_edit.release_focus()


func _adjust(id: String, d: int) -> void:
	if submit_at >= 0.0:
		return
	match id:
		"sex":
			_set_sex(CharDocs.SEX_F if int(look["sex"]) == CharDocs.SEX_M else CharDocs.SEX_M)
		"hair":
			look["hair"] = _step(CharDocs.HAIRS, look["hair"], d)
		"hcol":
			look["hcol"] = _step(CharDocs.HCOLS, look["hcol"], d)
		"skin":
			look["skin"] = _step(CharDocs.SKINS, look["skin"], d)
	_apply_look()


func _step(list: Array, cur: String, d: int) -> String:
	return list[posmod(list.find(cur) + d, list.size())]


func _set_sex(sex: int) -> void:
	var old := int(look["sex"])
	if old == sex:
		return
	look["sex"] = sex
	if look["hair"] == CharDocs.DEFAULT_LOOK[old]["hair"]:
		look["hair"] = CharDocs.DEFAULT_LOOK[sex]["hair"]
	if _pool_name != "" and given_edit.text == _pool_name:
		given_edit.text = CharDocs.random_given(sex, rng)
		_pool_name = given_edit.text
	_apply_look()


func _press(id: String) -> void:
	if submit_at >= 0.0:
		return
	match id:
		"sur":
			sur_edit.grab_focus()
		"given":
			given_edit.grab_focus()
		"sex", "hair", "hcol", "skin":
			_adjust(id, 1)
		"look":
			focus_on("hair")
		"random":
			look["hair"] = CharDocs.HAIRS[rng.randi_range(1, CharDocs.HAIRS.size() - 1)]
			look["hcol"] = CharDocs.HCOLS[rng.randi_range(0, 3)] if rng.randf() < 0.8 else CharDocs.HCOLS[rng.randi_range(4, 7)]
			look["skin"] = CharDocs.SKINS[rng.randi_range(0, CharDocs.SKINS.size() - 1)]
			given_edit.text = CharDocs.random_given(look["sex"], rng)
			_pool_name = given_edit.text
			error = ""
			_apply_look()
		"default":
			var sex := int(look["sex"])
			look = CharDocs.DEFAULT_LOOK[sex].duplicate()
			look["sex"] = sex
			sur_edit.text = CharDocs.default_surname()
			error = ""
			_apply_look()
		"stats", "tags":
			if not _commit_name():
				return
			CharDocs.write_look(st, look)
			sub = (RecordBook.new().setup(st, true) if id == "stats" else ResultSheet.new().setup(st, true))
			sub.layer = layer + 1
			sub.closed.connect(func(_ok: bool) -> void:
				sub = null
				visible = true)
			get_parent().add_child(sub)
			visible = false
		"regno":
			regno_msg_at = time
		"keep":
			for k in snapshot:
				st.vars.set_v(k, snapshot[k])
			close(true)
		"ok":
			if not _commit_name():
				return
			CharDocs.write_look(st, look)
			submit_at = time
			busy = 3.2 if mode == "birth" else 1.2
			_release_edits()


## 이름을 검사해 맞으면 이야기 상태에 적는다. 틀리면 오류 문장을 띄우고 그 칸으로 간다.
func _commit_name() -> bool:
	var sur := sur_edit.text.strip_edges()
	var given := given_edit.text.strip_edges()
	error = CharDocs.check_name(sur, given)
	if error != "":
		focus_on("sur" if sur.length() < 1 or sur.length() > 2 else "given")
		return false
	CharDocs.write_name(st, sur, given)
	return true


func _busy_done() -> void:
	close(true)
