## 대화 창 (SD-12 §6, 견본 art/samples/18_ui_dialogue). 대화 실행기(DialogueRunner)의 결과를 그리고 입력을 받는다.
## 배치(논리 640×360 기준, 화면이 넓으면 아래 가운데에 붙는다): 대사 상자 (16,248) 608×104 검정 85% + P07 테두리,
## 초상화 (24,252) 96×96(바탕 P17), 이름표 (124,230), 본문 (128,258)부터 18px 간격 4줄(40자), 선택지 창은 상자 위 (128, …) 488폭.
## 글자: 갈무리11 12px, 초당 40자(옵션), 결정 키 = 출력 중이면 즉시 완성 · 완성이면 다음 쪽. 판정 결과 [성공]/[실패] 0.6초.
## L = 대화 기록(최근 400줄). 터치: 아무 곳이나 누르면 결정, 선택지는 그 줄을 누른다.
## 연출 명령(cmd)은 command 신호로 넘기고 resume()을 기다린다. 받는 곳이 없으면 바로 넘어간다.
class_name DialogueBox
extends CanvasLayer

signal command(name: String, args: Array)
signal finished
signal line_shown(state: Dictionary)

const C := {
	"P01": Color("1A181D"), "P02": Color("2B2830"), "P05": Color("6E6966"), "P06": Color("8B857D"), "P07": Color("ABA49A"),
	"P09": Color("E9E4D8"), "P17": Color("46331F"), "P46": Color("4C7DC8"), "P48": Color("B08A1C"), "P49": Color("E8C23A"),
	"P54": Color("E04A35"), "P56": Color("7CD62B"), "P60": Color("FFC24A"),
}
const TAG_COL := {"speech": "P09", "stat": "P46", "karma": "P49", "admin": "P60", "plain": "P09"}
const BOX := Rect2(16, 248, 608, 104)
const TEXT_X := 128
const TEXT_Y := 258
const LINE_H := 18
const LINES := 4
const TEXT_W := 484.0
const CPS := 40.0

var runner: DialogueRunner
var font: Font
var font_small: Font
var view: Control
var face_rect: TextureRect            ## 초상화는 노드로 그린다(직접 그리기 draw_texture는 앞에 그린 타일·바닥이 있으면 흰 사각형이 됐다)
var portraits := {}
var cps := CPS
var state: Dictionary = {}
var pages: Array = []                ## [[{"text", "off"}...줄], ...쪽]
var page_i := 0
var reveal := 0.0
var page_len := 0
var pause_left := 0.0
var pauses: Array = []
var colors: Array = []
var sel := 0
var choice_rows: Array = []          ## [{"lines": [...], "y", "h", "enabled", "kind", "tag"}]
var flash_t := 0.0
var flash_ok := false
var log_open := false
var log_scroll := 0
var waiting_cmd := false
var blink := 0.0
var talk_t := 0.0
var active := false
var prev_line: Dictionary = {}       ## 선택지가 뜰 때 상자에 남겨 둘 직전 대사(질문)
var history: Array[String] = []      ## 대화 기록(장면을 넘어 이어진다, 최근 400줄 — SD-12 §6.6)


func _init() -> void:
	layer = 10
	font = load("res://assets/fonts/Galmuri11.ttf")
	font_small = load("res://assets/fonts/Galmuri9.ttf")
	var idx := "res://assets/portraits/portraits.json"
	if FileAccess.file_exists(idx):
		portraits = JSON.parse_string(FileAccess.get_file_as_string(idx))["portraits"]
	view = Control.new()
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.draw.connect(_draw_view)
	add_child(view)
	face_rect = TextureRect.new()
	face_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face_rect.size = Vector2(96, 96)
	add_child(face_rect)
	visible = false


## 장면 하나를 연다. st: 이야기 상태, graph: 원고 변환기가 만든 장면, label: 시작 라벨
func open(st: StoryState, graph: Dictionary, label: String = "START") -> void:
	prev_line = {}
	runner = DialogueRunner.new(st)
	runner.log = history
	active = true
	visible = true
	_take(runner.start(graph, label))


func resume() -> void:
	if waiting_cmd:
		waiting_cmd = false
		_take(runner.advance())


func _take(s: Dictionary) -> void:
	state = s
	match s.get("type", "end"):
		"line":
			prev_line = s
			_layout_line(s)
			line_shown.emit(s)
		"choices":
			if not prev_line.is_empty():
				_layout_line(prev_line)                            # 직전 대사를 다 드러낸 채 상자에 남긴다
				page_i = pages.size() - 1
				reveal = float(_page_chars())
				page_len = _page_chars()
			_layout_choices(s)
		"cmd":
			waiting_cmd = true
			if command.get_connections().is_empty():
				resume.call_deferred()
			else:
				command.emit(s["name"], s["args"])
		_:
			active = false
			visible = false
			finished.emit()
	view.queue_redraw()


func _origin() -> Vector2:
	var vs := view.get_viewport_rect().size
	return Vector2(floorf((vs.x - 640.0) / 2.0), vs.y - 360.0)


func _measure() -> Callable:
	return func(s: String) -> float: return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x


func _layout_line(s: Dictionary) -> void:
	var w := TEXT_W if s["who"] != "SYS" else TEXT_W + 100.0
	var lines := TextWrap.wrap(s["text"], _measure(), w)
	pages = []
	var off := 0
	var src: String = s["text"]
	var cur: Array = []
	for ln in lines:
		var at := src.find(ln, off)
		if at < 0:
			at = off
		cur.append({"text": ln, "off": at})
		off = at + ln.length()
		if cur.size() == LINES:
			pages.append(cur)
			cur = []
	if cur.size() > 0 or pages.is_empty():
		pages.append(cur)
	pauses = s.get("pauses", [])
	colors = s.get("colors", [])
	page_i = 0
	_start_page()


func _page_chars() -> int:
	var n := 0
	for ln in pages[page_i]:
		n += ln["text"].length()
	return n


func _start_page() -> void:
	page_len = 0
	for ln in pages[page_i]:
		page_len += ln["text"].length()
	reveal = 0.0 if cps < 1000.0 else float(page_len)
	pause_left = 0.0


func _layout_choices(s: Dictionary) -> void:
	choice_rows = []
	var y := 0
	for o in s["opts"]:
		var tag := ""
		var body: String = o["text"]
		if body.begins_with("["):
			var k := body.find("] ")
			while k >= 0 and body.substr(k + 2).begins_with("["):
				k = body.find("] ", k + 2)
			if k >= 0:
				tag = body.substr(0, k + 1)
				body = body.substr(k + 2)
		var tag_w := font.get_string_size(tag + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x if tag != "" else 0.0
		var lines := TextWrap.wrap(body, _measure(), 488.0 - 34.0 - tag_w)
		choice_rows.append({"tag": tag, "tag_w": tag_w, "lines": lines.slice(0, 2), "y": y, "h": LINE_H * mini(2, lines.size()),
			"enabled": o["enabled"], "kind": o["kind"]})
		y += LINE_H * mini(2, lines.size())
	sel = 0
	while sel < choice_rows.size() - 1 and not choice_rows[sel]["enabled"]:
		sel += 1


func _process(dt: float) -> void:
	if not active:
		return
	blink += dt
	if flash_t > 0.0:
		flash_t -= dt
	if state.get("type", "") == "line" and reveal < page_len:
		talk_t += dt
		if pause_left > 0.0:
			pause_left -= dt
		else:
			var before := int(reveal)
			reveal = minf(float(page_len), reveal + cps * dt)
			var shown_from := _orig_index(before)
			var shown_to := _orig_index(int(reveal))
			for p in pauses:
				if int(p[0]) > shown_from and int(p[0]) <= shown_to:
					pause_left = float(p[1])
					reveal = float(_page_index_of(int(p[0])))
					break
	view.queue_redraw()


## 쪽 안의 드러난 글자 수 → 원문 위치
func _orig_index(n: int) -> int:
	var left := n
	for ln in pages[page_i]:
		if left <= ln["text"].length():
			return int(ln["off"]) + left
		left -= ln["text"].length()
	return int(pages[page_i][-1]["off"]) + pages[page_i][-1]["text"].length() if not pages[page_i].is_empty() else 0


func _page_index_of(orig: int) -> int:
	var n := 0
	for ln in pages[page_i]:
		if orig <= int(ln["off"]) + ln["text"].length():
			return n + maxi(0, orig - int(ln["off"]))
		n += ln["text"].length()
	return n


# ---------------------------------------------------------------- 입력
func _unhandled_input(e: InputEvent) -> void:
	if not active or waiting_cmd:
		return
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_L:
		log_open = not log_open
		log_scroll = 0
		_handled()
		return
	if log_open:
		if e.is_action_pressed("ui_cancel") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			log_open = false
		elif e.is_action_pressed("ui_up") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP):
			log_scroll += 1
		elif e.is_action_pressed("ui_down") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
			log_scroll = maxi(0, log_scroll - 1)
		_handled()
		return
	if state.get("type", "") == "choices":
		if e.is_action_pressed("ui_up"):
			_move_sel(-1)
		elif e.is_action_pressed("ui_down"):
			_move_sel(1)
		elif e.is_action_pressed("ui_accept"):
			pick(sel)
		elif e is InputEventKey and e.pressed and e.keycode >= KEY_1 and e.keycode <= KEY_9:
			pick(e.keycode - KEY_1)
		elif (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) or (e is InputEventScreenTouch and e.pressed):
			var i := _row_at(_to_logical(e.position))
			if i >= 0:
				pick(i)
		elif e is InputEventMouseMotion:
			var i := _row_at(_to_logical(e.position))
			if i >= 0 and choice_rows[i]["enabled"]:
				sel = i
		else:
			return
		_handled()
		return
	if state.get("type", "") == "line":
		if e.is_action_pressed("ui_accept") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and e.pressed):
			next()
			_handled()


func _handled() -> void:
	view.get_viewport().set_input_as_handled()
	view.queue_redraw()


func _to_logical(p: Vector2) -> Vector2:
	return view.get_global_transform_with_canvas().affine_inverse() * p


func _row_at(p: Vector2) -> int:
	var o := _origin() + Vector2(128, _choice_top())
	for i in choice_rows.size():
		var r: Dictionary = choice_rows[i]
		if Rect2(o.x, o.y + 6 + r["y"] - 2, 488, r["h"]).has_point(p):
			return i
	return -1


func _move_sel(d: int) -> void:
	var n := choice_rows.size()
	for k in n:
		sel = (sel + d + n) % n
		if choice_rows[sel]["enabled"]:
			return


## 결정 키(줄): 출력 중이면 즉시 완성, 완성이면 다음 쪽, 마지막 쪽이면 다음 줄
func next() -> void:
	if state.get("type", "") != "line":
		return
	if reveal < page_len:
		reveal = float(page_len)
		pause_left = 0.0
	elif page_i < pages.size() - 1:
		page_i += 1
		_start_page()
	else:
		_take(runner.advance())


func pick(i: int) -> void:
	if state.get("type", "") != "choices" or i < 0 or i >= choice_rows.size() or not choice_rows[i]["enabled"]:
		return
	var s := runner.choose(i)
	if not runner.last_check.is_empty():
		flash_t = 0.6
		flash_ok = runner.last_check["ok"]
	_take(s)


# ---------------------------------------------------------------- 그리기
func _choice_top() -> float:
	var h := 12.0
	for r in choice_rows:
		h += float(r["h"])
	return BOX.position.y - 26.0 - h


func _draw_view() -> void:
	face_rect.visible = false
	if not active:
		return
	var o := _origin()
	var t: String = state.get("type", "")
	if log_open:
		_draw_log(o)
		return
	if t == "choices":
		_draw_choices(o)
	# 대사 상자
	var box := Rect2(o + BOX.position, BOX.size)
	view.draw_rect(box, Color(C["P01"], 0.85))
	view.draw_rect(Rect2(box.position + Vector2(0.5, 0.5), box.size - Vector2.ONE), C["P07"], false, 1.0)
	view.draw_rect(Rect2(o + Vector2(14, 234), Vector2(52, 13)), Color(C["P01"], 0.85))
	view.draw_string(font_small, o + Vector2(16, 235 + font_small.get_ascent(10)), "(L) 기록", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, C["P07"])
	var line_state: Dictionary = state if t == "line" else (prev_line if t == "choices" else {})
	if line_state.is_empty():
		return
	var sys: bool = line_state["who"] == "SYS"
	var tx := TEXT_X if not sys else 28
	if not sys:
		var pr := Rect2(o + Vector2(24, 252), Vector2(96, 96))
		view.draw_rect(pr, C["P17"])
		face_rect.texture = _portrait(line_state["who"], _face(line_state["emo"]))
		face_rect.position = pr.position
		face_rect.visible = face_rect.texture != null
		view.draw_rect(Rect2(pr.position + Vector2(0.5, 0.5), pr.size - Vector2.ONE), C["P05"], false, 1.0)
		var name: String = line_state["name"]
		var nw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 16.0
		view.draw_rect(Rect2(o + Vector2(124, 230), Vector2(nw, 16)), Color(C["P01"], 0.85))
		view.draw_string(font, o + Vector2(132, 231 + font.get_ascent(12)), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C["P09"])
	if flash_t > 0.0:
		var ftxt := "[성공]" if flash_ok else "[실패]"
		view.draw_string(font, o + Vector2(560, 231 + font.get_ascent(12)), ftxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			C["P56"] if flash_ok else C["P54"])
	var left := int(reveal)
	var y := TEXT_Y
	for ln in pages[page_i]:
		var s: String = ln["text"]
		var n := mini(left, s.length())
		var x := float(tx)
		for i in n:
			var ch := s[i]
			view.draw_char(font, o + Vector2(x, y + font.get_ascent(12)), ch, 12, _color_at(int(ln["off"]) + i))
			x += font.get_char_size(ch.unicode_at(0), 12).x
		left -= n
		y += LINE_H
	if t == "line" and reveal >= page_len and fmod(blink, 0.8) < 0.5:
		var a := o + Vector2(604, 338)
		view.draw_colored_polygon(PackedVector2Array([a, a + Vector2(8, 0), a + Vector2(4, 6)]), C["P48"])


func _color_at(i: int) -> Color:
	for c in colors:
		if i >= int(c[0]) and i < int(c[1]):
			return [C["P09"], C["P49"], C["P46"], C["P54"], C["P56"]][clampi(int(c[2]), 0, 4)]
	return C["P09"]


## 말하는 동안(글자가 나오는 중) 기본·미소 표정은 '말함'과 번갈아 입을 움직인다
func _face(emo: String) -> String:
	if reveal < page_len and pause_left <= 0.0 and emo in ["기본", "미소"] and fmod(talk_t, 0.24) < 0.12:
		return "말함"
	return emo


func _portrait(who: String, emo: String) -> Texture2D:
	if not portraits.has(who):
		return null
	var f: String = portraits[who].get(emo, portraits[who].get("기본", ""))
	return load("res://assets/portraits/" + f) if f != "" else null


func _draw_choices(o: Vector2) -> void:
	var top := _choice_top()
	var h := 12.0
	for r in choice_rows:
		h += float(r["h"])
	var rect := Rect2(o + Vector2(128, top), Vector2(488, h))
	view.draw_rect(rect, Color(C["P01"], 0.85))
	view.draw_rect(Rect2(rect.position + Vector2(0.5, 0.5), rect.size - Vector2.ONE), C["P07"], false, 1.0)
	for i in choice_rows.size():
		var r: Dictionary = choice_rows[i]
		var y := rect.position.y + 6 + float(r["y"])
		var on := i == sel
		if on:
			view.draw_rect(Rect2(rect.position.x + 3, y - 2, 482, float(r["h"])), C["P48"])
		var col: Color = C["P01"] if on else (C["P09"] if r["enabled"] else C["P05"])
		var base := Vector2(rect.position.x + 10, y + font.get_ascent(12))
		view.draw_string(font, base, "%d." % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
		var x := rect.position.x + 28
		if r["tag"] != "":
			var tc: Color = C["P02"] if on else (C[TAG_COL.get(r["kind"], "P09")] if r["enabled"] else C["P05"])
			view.draw_string(font, Vector2(x, base.y), r["tag"], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tc)
			x += r["tag_w"]
		for k in r["lines"].size():
			view.draw_string(font, Vector2(x, base.y + k * LINE_H), r["lines"][k], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


func _draw_log(o: Vector2) -> void:
	var vs := view.get_viewport_rect().size
	view.draw_rect(Rect2(Vector2.ZERO, vs), Color(C["P01"], 0.92))
	view.draw_string(font, o + Vector2(24, 20 + font.get_ascent(12)), "대화 기록  (L 닫기 · ↑↓ 넘기기)", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C["P49"])
	var rows: Array[String] = []
	for l in runner.log:
		for w in TextWrap.wrap(l, _measure(), 590.0):
			rows.append(w)
	var per := 17
	var end := maxi(0, rows.size() - log_scroll)
	var start := maxi(0, end - per)
	log_scroll = clampi(log_scroll, 0, maxi(0, rows.size() - per))
	for i in range(start, end):
		var s: String = rows[i]
		var col: Color = C["P49"] if s.begins_with("▷") else (C["P46"] if s.begins_with("[화술") else C["P09"])
		view.draw_string(font, o + Vector2(24, 44 + (i - start) * LINE_H + font.get_ascent(12)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
