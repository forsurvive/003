## 종이 기록물 창(단계 1-5, SD-12 §7.x 노트 '종이 바탕 그림 + 줄 간격(손글씨 글꼴 안 씀)', 공문체 §7.4): 책상 위에 종이 한 장.
## 양식: official(공문 — 머리 기관 · 제목 · 번호 개조식 · 붉은 결재 도장) · ledger(장부 — 줄 친 종이에 '|' 칸) · scrap(쪽지 — 작고 누런 종이).
## 넘치면 쪽을 나눈다(↑↓·←→·마우스 휠). E·Esc = 닫기. 읽은 기록은 st.boxes["notes"]에 남는다(핍-보이 기록 탭이 읽을 자리).
class_name NoteScreen
extends DocScreen

var note: Dictionary = {}
var page := 0
var _pages: Array = []                            ## 쪽마다 [줄...] — 줄은 {"t": 글, "cells": [칸...] 또는 []}


static func load_note(id: String) -> Dictionary:
	if not FileAccess.file_exists("res://data/notes.json"):
		return {}
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/notes.json"))
	return d["notes"].get(id, {})


func setup(state: StoryState, id: String) -> NoteScreen:
	st = state
	note = load_note(id)
	cancel_ok = true
	if st != null:
		if not st.boxes.has("notes"):
			st.boxes["notes"] = {"read": []}
		var rd: Array = st.boxes["notes"]["read"]
		if not rd.has(id):
			rd.append(id)
	return self


func _paper_rect() -> Rect2:
	match str(note.get("style", "official")):
		"scrap":
			return Rect2(170, 40, 300, 270)
	return Rect2(130, 12, 380, 336)


## 본문을 종이 폭에 맞춰 줄로 나누고(띄어쓰기에서 끊는다), 쪽으로 나눈다
func _layout() -> void:
	_pages = []
	var r := _paper_rect()
	var width := r.size.x - 44.0
	var style := str(note.get("style", "official"))
	var lines: Array = []
	for raw in note.get("body", []):
		var s: String = str(raw)
		if style == "ledger" and s.contains("|"):
			lines.append({"t": s, "cells": Array(s.split("|")).map(func(c): return str(c).strip_edges())})
			continue
		if s == "":
			lines.append({"t": "", "cells": []})
			continue
		var cur := ""
		for word in s.split(" "):
			var trial := word if cur == "" else cur + " " + word
			if tw(trial, f10, 10) > width and cur != "":
				lines.append({"t": cur, "cells": []})
				cur = "  " + word if style == "official" and s.length() > 1 and s[1] == "." else word
			else:
				cur = trial
		lines.append({"t": cur, "cells": []})
	var head_rows := 5 if style == "official" else (3 if style == "ledger" else 1)
	var per := int((r.size.y - 30.0) / 14.0) - head_rows - (3 if str(note.get("stamp", "")) != "" else 0)
	per = maxi(6, per)
	var i := 0
	while i < lines.size():
		_pages.append(lines.slice(i, i + per))
		i += per
	if _pages.is_empty():
		_pages.append([])


func _draw_doc() -> void:
	if _pages.is_empty():
		_layout()
	desk()
	var r := _paper_rect()
	var style := str(note.get("style", "official"))
	if style == "scrap":                                                 # 누런 쪽지: 구김 그림자
		view.draw_rect(Rect2(r.position + Vector2(4, 4), r.size), C["P03"])
		view.draw_rect(r, Color("D8C9A0"))
		for k in 5:
			var y := r.position.y + 30 + k * 47
			view.draw_line(Vector2(r.position.x + 6, y), Vector2(r.end.x - 10, y + 6), Color(0, 0, 0, 0.06), 1.0)
	else:
		paper(r)
	var x0 := r.position.x + 22
	var y := r.position.y + 14
	var ink := INK
	if style == "official":
		text(Vector2(x0, y), str(note.get("head", "")), f8, 8, C["P05"])
		text(Vector2(r.end.x - 22, y), str(note.get("date", "")), f8, 8, C["P05"], HORIZONTAL_ALIGNMENT_RIGHT)
		y += 16
		text(Vector2(r.position.x + r.size.x / 2.0, y), str(note.get("title", "")), f12b, 12, INK2, HORIZONTAL_ALIGNMENT_CENTER)
		y += 20
		hline(x0, r.end.x - 22, y, C["P06"])
		y += 8
	elif style == "ledger":
		text(Vector2(x0, y), str(note.get("head", note.get("title", ""))), f12b, 12, INK2)
		text(Vector2(r.end.x - 22, y + 2), str(note.get("date", "")), f8, 8, C["P05"], HORIZONTAL_ALIGNMENT_RIGHT)
		y += 22
		hline(x0, r.end.x - 22, y, C["P53"])
		y += 6
	else:
		text(Vector2(x0, y), str(note.get("date", "")), f8, 8, C["P18"])
		y += 18
		ink = C["P17"]
	var cols := [0.0, 0.18, 0.52, 0.80]
	for ln in _pages[clampi(page, 0, _pages.size() - 1)]:
		var cells: Array = ln["cells"]
		if style == "ledger":
			hline(x0, r.end.x - 22, y + 13, C["P07"])
		if cells.is_empty():
			text(Vector2(x0, y), str(ln["t"]), f10, 10, ink)
		else:
			var w := r.size.x - 44.0
			for ci in mini(cells.size(), cols.size()):
				var cs := str(cells[ci])
				var col := ink if cs != "출석" else C["P53"]
				text(Vector2(x0 + w * cols[ci], y), cs, f10, 10, col)
			if cells.size() > 2 and str(cells[2]) == "출석":                # 서명 자리: 짧은 펜 획
				var sx: float = x0 + w * 0.66
				view.draw_line(Vector2(sx, y + 9), Vector2(sx + 14, y + 4), INK, 1.0)
				view.draw_line(Vector2(sx + 14, y + 4), Vector2(sx + 22, y + 10), INK, 1.0)
		y += 14
	if str(note.get("stamp", "")) != "" and page == _pages.size() - 1:      # 붉은 결재 도장(테두리 두 겹)
		var stx := str(note["stamp"])
		var sw := tw(stx, f10, 10) + 16.0
		var sr := Rect2(r.end.x - 22 - sw, r.end.y - 52, sw, 26)
		view.draw_rect(sr, Color(C["P53"], 0.08))
		box(sr, Color(C["P53"], 0.85), false)
		box(sr.grow(-2), Color(C["P53"], 0.6), false)
		text(sr.position + Vector2(8, 7), stx, f10, 10, Color(C["P53"], 0.9))
	if _pages.size() > 1:
		text(Vector2(r.position.x + r.size.x / 2.0, r.end.y - 16), "%d / %d" % [page + 1, _pages.size()], f8, 8, C["P05"], HORIZONTAL_ALIGNMENT_CENTER)
	text(Vector2(320, 350), "(↑↓) 넘기기   (E·Esc) 닫기", f8, 8, C["P08"], HORIZONTAL_ALIGNMENT_CENTER)
	item("paper", r)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_down") or e.is_action_pressed("ui_right") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		page = mini(page + 1, _pages.size() - 1)
	elif e.is_action_pressed("ui_up") or e.is_action_pressed("ui_left") or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP):
		page = maxi(page - 1, 0)
	elif e.is_action_pressed("ui_accept") or e.is_action_pressed("ui_cancel") or (e is InputEventKey and e.pressed and e.keycode == KEY_E) \
			or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		if page < _pages.size() - 1 and not e.is_action_pressed("ui_cancel"):
			page += 1
		else:
			close(true)
	else:
		return
	get_viewport().set_input_as_handled()
