## 일시 정지 메뉴(SD-12 §13.5·§13.1, 단계 0-11): 계속 / 저장 / 빠른 저장 / 불러오기 / 조작 안내 / 메인 메뉴로.
## 열려 있는 동안 게임 시간이 멈춘다(모달). 저장·불러오기는 칸 목록 쪽(수동 60칸, 스크롤)으로 넘어가고, 덮어쓰기·불러오기·메인 메뉴로는
## 되돌릴 수 없으니 두 번 누른다(§17.1 오조작 방지). 저장할 수 없는 때(대화·연출·핍-보이 중 — §13.1)는 저장 줄이 어둡고 까닭이 붙는다.
## 게임 쪽은 콜백 넷을 넘긴다: can_save() -> 까닭(빈 글 = 가능) · do_save(kind, idx) -> Error · do_load(path) · to_title().
## 조작: 위·아래 = 고르기, E·Enter·Space = 결정, Esc·Tab = 뒤로(맨 위 목록이면 닫기). 마우스·터치: 줄을 누르면 고르고 다시 누르면 결정.
class_name PauseMenu
extends DocScreen

const U := DocScreen.GREEN
const ROWS := 10

var can_save: Callable
var do_save: Callable
var do_load: Callable
var to_title: Callable
var page := "main"                                ## main · save · load · keys
var sel := 0
var scroll := 0
var armed := ""                                   ## 한 번 누른 되돌릴 수 없는 결정(같은 줄을 한 번 더 누르면 실행)
var note := ""                                    ## 아래 알림 줄
var note_t := 0.0
var _slots: Array = []                            ## 불러오기 목록 · 저장 칸 정보(칸 번호 -> 정보)
var subtitle := ""                                ## 머리 오른쪽 줄(게임 날짜)
var _thumbs := {}                                 ## 경로 → 축소 그림 텍스처(칸 정보의 160×90 PNG)
var title_mode := false                           ## 제목 화면에서 연 불러오기(뒤로 = 닫기)
var now := {}                                     ## 지금 게임의 칸 정보(+ goal) — 첫 쪽 오른쪽 '지금' 미리 보기


func setup(state_: StoryState, can_save_: Callable, do_save_: Callable, do_load_: Callable, to_title_: Callable) -> PauseMenu:
	st = state_
	can_save = can_save_
	do_save = do_save_
	do_load = do_load_
	to_title = to_title_
	cancel_ok = true
	return self


func _main_rows() -> Array:
	var why: String = can_save.call() if can_save.is_valid() else ""
	return [["resume", "계속", ""], ["save", "저장", why], ["quick", "빠른 저장", why], ["load", "불러오기", ""],
		["keys", "조작 안내", ""], ["title", "메인 메뉴로", ""]]


func _rows() -> Array:
	match page:
		"save":
			var out := []
			var info := {}
			for e in SaveSlots.list():
				if e["kind"] == "manual":
					info[int(e["idx"])] = e
			for i in SaveSlots.MANUAL:
				out.append(["slot%d" % i, SaveSlots.short(info[i]) if info.has(i) else "수동 %d — (빈 칸)" % (i + 1), "" if not info.has(i) else "full"])
			return out
		"load":
			return _slots.map(func(e): return ["path:" + str(e["path"]), SaveSlots.short(e), "" if e["ok"] else "bad"])
		"keys":
			return []
	return _main_rows()


func _open(p: String) -> void:
	page = p
	_thumbs.clear()
	sel = 0
	scroll = 0
	armed = ""
	if p == "load":
		_slots = SaveSlots.list()


func _say(t: String) -> void:
	note = t
	note_t = 3.0


func _tick(dt: float) -> void:
	note_t = maxf(0.0, note_t - dt)


# ---------------------------------------------------------------- 결정
func _choose() -> void:
	var rows := _rows()
	if rows.is_empty():
		return
	var r: Array = rows[clampi(sel, 0, rows.size() - 1)]
	var id: String = r[0]
	match page:
		"main":
			if id in ["save", "quick"] and str(r[2]) != "":
				_say(str(r[2]))
				return
			match id:
				"resume":
					close(true)
				"save":
					_open("save")
				"quick":
					var err: Error = do_save.call("quick", 0)
					_say("빠른 저장을 했다" if err == OK else "저장하지 못했다(%s)" % error_string(err))
				"load":
					_open("load")
				"keys":
					_open("keys")
				"title":
					if armed != "title":
						armed = "title"
						_say("한 번 더 누르면 메인 메뉴로 — 저장하지 않은 진행은 사라진다")
					else:
						to_title.call()
		"save":
			var idx := int(id.substr(4))
			if str(r[2]) == "full" and armed != id:
				armed = id
				_say("한 번 더 누르면 수동 %d 칸을 덮어쓴다" % (idx + 1))
				return
			var err: Error = do_save.call("manual", idx)
			armed = ""
			_say("수동 %d 칸에 저장했다" % (idx + 1) if err == OK else "저장하지 못했다(%s)" % error_string(err))
		"load":
			if str(r[2]) == "bad":
				_say("손상된 저장은 불러올 수 없다")
				return
			if armed != id:
				armed = id
				_say("한 번 더 누르면 불러온다 — 지금 진행은 사라진다")
				return
			do_load.call(id.substr(5))


func _back() -> void:
	if page == "main" or title_mode:
		close(true)
	else:
		_open("main")


# ---------------------------------------------------------------- 그리기
func _draw_doc() -> void:
	var v := view
	v.draw_rect(Rect2(0, 0, 640, 360), Color(0, 0, 0, 0.55))
	var p := Rect2(40, 24, 560, 312)                                       # 모든 쪽이 같은 창(쪽을 넘겨도 테두리가 흔들리지 않게)
	v.draw_rect(p, U[1])
	v.draw_rect(p.grow(-1), U[0])
	v.draw_rect(Rect2(p.position + Vector2(0.5, 0.5), p.size - Vector2.ONE), U[4], false, 1.0)
	for y in range(int(p.position.y) + 2, int(p.end.y) - 1, 2):
		v.draw_line(Vector2(p.position.x + 1, y), Vector2(p.end.x - 1, y), Color(U[1], 0.55))
	var head: String = {"main": "일시 정지", "save": "저장 — 수동 칸", "load": "불러오기", "keys": "조작 안내"}[page]
	text(Vector2(p.position.x + 16, p.position.y + 10), head, f12b, 12, U[6])
	if page == "main":
		var who := st.player_full() if st != null else ""
		text(Vector2(p.end.x - 16, p.position.y + 12), who + (" · " + subtitle.strip_edges() if subtitle != "" else ""), f10, 10, U[4],
			HORIZONTAL_ALIGNMENT_RIGHT)
	v.draw_line(Vector2(p.position.x + 12, p.position.y + 32), Vector2(p.end.x - 12, p.position.y + 32), U[3])
	if page == "keys":
		_draw_keys(p)
	else:
		var rows := _rows()
		sel = clampi(sel, 0, maxi(0, rows.size() - 1))
		if sel < scroll:
			scroll = sel
		elif sel >= scroll + ROWS:
			scroll = sel - ROWS + 1
		if rows.is_empty():
			text(Vector2(p.position.x + 20, p.position.y + 44), "저장이 없다", f10, 10, U[3])
		var rh := 26.0 if page == "main" else 24.0
		var list_w := p.size.x - 204.0                                         # 목록 오른쪽에 축소 그림 자리
		if page == "main" and not now.is_empty():
			_draw_preview(Rect2(p.end.x - 184, p.position.y + 40, 172, 230), ["now"])
		elif page != "main" and not rows.is_empty():
			_draw_preview(Rect2(p.end.x - 184, p.position.y + 40, 172, 230), rows[clampi(sel, 0, rows.size() - 1)])
		for i in range(scroll, mini(rows.size(), scroll + ROWS)):
			var r: Array = rows[i]
			var y := p.position.y + 40 + (i - scroll) * rh
			var rect := Rect2(p.position.x + 12, y, list_w, rh - 3)
			item("row%d" % i, rect)
			var on := i == sel
			var dim := page == "main" and str(r[2]) != "" or str(r[2]) == "bad"
			var empty := page == "save" and str(r[2]) == ""
			if on:
				v.draw_rect(rect, U[5] if armed != str(r[0]) else DocScreen.C["P54"])
			var col: Color = U[0] if on else (U[3] if dim else (U[4] if empty else U[6]))
			text(Vector2(rect.position.x + 8, rect.position.y + (5 if page == "main" else 4)), str(r[1]), f12 if page == "main" else f10,
				12 if page == "main" else 10, col)
			if page == "main" and dim and on:
				text(Vector2(rect.end.x - 8, rect.position.y + 6), str(r[2]), f10, 10, U[0], HORIZONTAL_ALIGNMENT_RIGHT)
		if rows.size() > ROWS:
			var h := (ROWS * rh) * ROWS / rows.size()
			var y0 := p.position.y + 40 + (ROWS * rh - h) * scroll / maxf(1.0, float(rows.size() - ROWS))
			v.draw_rect(Rect2(p.end.x - 8, y0, 2, h), U[4])
	var foot := "E 결정 · Esc 뒤로" if page != "main" else "E 결정 · Esc 계속"
	text(Vector2(p.position.x + 16, p.end.y - 20), note if note_t > 0.0 else foot, f10, 10,
		DocScreen.C["P60"] if note_t > 0.0 else U[4])


## 고른 칸의 축소 그림(160×90)과 정보 몇 줄
func _draw_preview(r: Rect2, row: Array) -> void:
	var v := view
	v.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), U[3], false, 1.0)
	var e := _entry_of(row)
	var img := Rect2(r.position + Vector2(6, 6), Vector2(160, 90))
	v.draw_rect(img, U[1])
	if e.is_empty():
		text(img.position + Vector2(48, 38), "(빈 칸)", f10, 10, U[3])
		return
	var tex := _thumb(e)
	if tex != null:
		v.draw_texture(tex, img.position)
	else:
		text(img.position + Vector2(40, 38), "그림 없음", f10, 10, U[3])
	var sl: Dictionary = e.get("slot", {})
	var lines := [SaveSlots.label(e), "%s  Lv%d" % [str(sl.get("name", "")), int(sl.get("level", 1))], str(sl.get("act", "")),
		str(sl.get("place", "")), str(sl.get("date", "")).strip_edges(), "플레이 %d:%02d" % [int(sl.get("play_time", 0)) / 3600, (int(sl.get("play_time", 0)) / 60) % 60],
		str(sl.get("real_time", "")).replace("T", " ").left(16)]
	if str(row[0]) == "now":                                                # 지금: 실제 시각 대신 목표 한 줄
		lines[0] = "지금"
		lines[6] = str(sl.get("goal", ""))
	for i in lines.size():
		var ln := str(lines[i])
		while ln.length() > 2 and f10.get_string_size(ln, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x > r.size.x - 14:   # 칸 밖으로 넘치면 줄임표
			ln = ln.left(ln.length() - 2) + "…"
		text(Vector2(r.position.x + 8, r.position.y + 104 + i * 17), ln, f10, 10, U[6] if i < 2 else U[5])


func _entry_of(row: Array) -> Dictionary:
	var id := str(row[0])
	if id == "now":
		return {"kind": "now", "path": "now", "slot": now, "ok": true}
	if id.begins_with("path:"):
		for e in _slots:
			if str(e["path"]) == id.substr(5):
				return e
		return {}
	if id.begins_with("slot"):
		var path := SaveSlots.path_of("manual", int(id.substr(4)))
		if not FileAccess.file_exists(path):
			return {}
		if not _thumbs.has("e:" + path):
			var rd := SaveGame.read(path)
			_thumbs["e:" + path] = {"kind": "manual", "idx": int(id.substr(4)), "path": path, "slot": rd.get("slot", {}), "ok": rd["ok"]}
		return _thumbs["e:" + path]
	return {}


func _thumb(e: Dictionary) -> Texture2D:
	var path := str(e.get("path", ""))
	if _thumbs.has(path):
		return _thumbs[path]
	var b: PackedByteArray = e.get("slot", {}).get("thumb", PackedByteArray())
	var tex: Texture2D = null
	if not b.is_empty():
		var im := Image.new()
		if im.load_png_from_buffer(b) == OK:
			tex = ImageTexture.create_from_image(im)
	_thumbs[path] = tex
	return tex


const KEYS := [["이동", "W A S D · 왼쪽 스틱"], ["조준 · 사격", "마우스 · 왼쪽 클릭"], ["정조준", "마우스 오른쪽"],
	["조사 · 말 걸기", "E"], ["재장전", "R"], ["웅크리기(은신)", "Ctrl"], ["무기 넣기·꺼내기", "H"],
	["핍-보이", "Tab"], ["단축키", "1 ~ 8"], ["빠른 저장 / 불러오기", "F5 / F9"], ["일시 정지", "Esc"],
	["대화 기록", "L(대화 중)"], ["터치", "왼쪽 아래 끌기 = 이동 · 오른쪽 아래 끌기 = 조준·사격"]]


func _draw_keys(p: Rect2) -> void:
	for i in KEYS.size():
		var y := p.position.y + 42 + i * 19
		text(Vector2(p.position.x + 24, y), KEYS[i][0], f10, 10, U[5])
		text(Vector2(p.end.x - 24, y), KEYS[i][1], f10, 10, U[6], HORIZONTAL_ALIGNMENT_RIGHT)


# ---------------------------------------------------------------- 입력
func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	var k: int = e.keycode if e is InputEventKey and e.pressed and not e.echo else -1
	if k in [KEY_ESCAPE, KEY_TAB]:
		_back()
	elif k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_choose()
	elif e.is_action_pressed("ui_up", true):
		sel = maxi(0, sel - 1)
		armed = ""
	elif e.is_action_pressed("ui_down", true):
		sel = mini(maxi(0, _rows().size() - 1), sel + 1)
		armed = ""
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := _item_at(_local(e.position))
		if i < 0:
			if page != "main":
				pass
			return
		var r := int(str(items[i]["id"]).substr(3))
		if r == sel:
			_choose()
		else:
			sel = r
			armed = ""
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		sel = clampi(sel + (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, _rows().size() - 1))
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
		view.queue_redraw()
