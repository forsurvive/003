## 단말 화면(단계 1-4, SD-12 §7.4 터미널 · §8.3 해킹). 단말 외장(세진 크림·청록) 안쪽 528×288 화면에 18행 × 88반칸(한글 2반칸).
## 순서: 머리글(스킨) → 잠겼으면 해킹 덤프(Hack) → 메뉴 [1]~[9] → 항목 읽기(넘기기). 글은 초당 90칸으로 찍히고 키를 누르면 바로 완성.
## 녹색(T1·T3·T4·T5)은 인광체 녹 4단계 밝기 + 주사선 + 1px 번짐. 관제망(T2)은 호박색 고정.
## 결과는 closed(ok)와 함께 hacked(해킹 성공)·locked(영구 잠김)·read(읽은 항목 번호) 신호로 알린다 — 상태 저장은 호출한 쪽(호스트)이 한다.
class_name TerminalScreen
extends DocScreen

signal hacked(xp: int)
signal locked_out
signal read(index: int)

const SCR := Rect2(56, 30, 528, 288)
const CW := 6.0                                   ## 반칸 폭
const RH := 16.0                                  ## 행 높이
const ROWS := 18
const TYPE_RATE := 90.0                           ## 초당 칸
const SKIN_HEAD := {
	"T1": ["세진전자 통합 운영체계 SJ-OS 7.7", "(c) 2075~2077 세진전자(주)"],
	"T2": ["수도 관제망 운용 체계 관제-77", "국가 보안 등급: 2급 비밀"],
	"T3": ["볼트-텍 볼트 관리 체계", "서울 S-07 · 시공 한결건설"],
	"T4": ["연합 전술 단말 ALLIED TACTICAL TERMINAL", "비인가 접속 시 군법에 따라 처벌함"],
	"T5": ["〔중국어〕 야전 휴대 단말", "〔중국어〕 접속 기록은 상급 부대로 전송됨"],
}

var tid := ""
var term: Dictionary
var mode := "boot"                                ## boot · hack · menu · read · done
var hack: Hack
var pal: Array = DocScreen.GREEN
var cur := 0                                      ## 해킹: 고른 칸 · 메뉴: 고른 항목
var page := 0
var shown := 0.0                                  ## 찍힌 칸 수(타자 효과)
var entries: Array = []                           ## 조건이 맞는 항목 [원래 번호, 항목]
var reading := -1
var end_at := -1.0                                ## 해킹 끝(성공·잠김) 뒤 넘어갈 시각
var assist := false
var _hover_cell := -1


## need_hack: 잠겨 있고 아직 안 뚫린 단말(과학 요구치는 호출한 쪽이 이미 확인했다)
func setup(state: StoryState, id: String, data: Dictionary, need_hack: bool, seed := 0) -> TerminalScreen:
	st = state
	tid = id
	term = data
	cancel_ok = true
	if str(term.get("skin", "T1")) == "T2":
		pal = DocScreen.AMBER
	for i in term.get("entries", []).size():
		var e: Dictionary = term["entries"][i]
		if str(e.get("cond", "")) == "" or StoryExpr.test(str(e["cond"]), st):
			entries.append([i, e])
	if need_hack:
		var lv := Hack.REQ.find(int(term.get("lock", 0)))
		hack = Hack.new(maxi(0, lv), st.skill("SCIENCE"), str(term.get("theme", "T1")), seed)
		hack.assist = assist
		mode = "hack"
	else:
		mode = "menu"
	return self


# ---------------------------------------------------------------- 진행
func _tick(dt: float) -> void:
	shown += dt * TYPE_RATE * (6.0 if mode == "hack" else 1.0)     # 덤프는 빠르게 쏟아진다
	if end_at >= 0.0 and time >= end_at:
		end_at = -1.0
		if hack != null and hack.state == "ok":
			mode = "menu"
			cur = 0
			shown = 0.0
		else:
			close(false)


func _skip_typing() -> bool:
	if shown < _visible_cells():
		shown = 1e9
		return true
	return false


func _visible_cells() -> float:
	match mode:
		"hack":
			return Hack.TOTAL + 200.0
		"menu":
			var n := 0
			for e in entries:
				n += _cells(str(e[1]["title"])) + 4
			return n + 120.0
		"read":
			var n := 0
			for l in _read_lines():
				n += _cells(str(l)) + 1
			return n + 40.0
	return 0.0


static func _cells(s: String) -> int:
	var n := 0
	for i in s.length():
		n += _w(s.unicode_at(i))
	return n


## 반칸 수: 한글·전각·도형(■ □ ▮)은 2
static func _w(code: int) -> int:
	return 2 if code >= 0x1100 or (code >= 0x2500 and code <= 0x25FF) else 1


func _read_lines() -> Array:
	if reading < 0:
		return []
	return entries[reading][1].get("body", [])


func _body_rows() -> int:
	return ROWS - _head_rows() - 3


func _head_rows() -> int:
	return 3 + term.get("head", []).size()


# ---------------------------------------------------------------- 그리기
func _draw_doc() -> void:
	_bezel()
	view.draw_rect(SCR, pal[0])
	match mode:
		"hack":
			_draw_hack()
		"menu", "read":
			_draw_menu()
	_scanlines()


func _bezel() -> void:
	var full := Rect2(-view.position, get_viewport().get_visible_rect().size)
	view.draw_rect(full, C["P01"])
	var outer := Rect2(28, 8, 584, 344)
	view.draw_rect(outer.grow(2), C["P03"])
	view.draw_rect(outer, C["P08"])
	view.draw_rect(Rect2(outer.position.x, outer.position.y, outer.size.x, 3), C["P09"])          # 윗면 빛
	view.draw_rect(Rect2(outer.position.x, outer.end.y - 4, outer.size.x, 4), C["P06"])          # 아랫면 그늘
	view.draw_rect(Rect2(outer.position.x, outer.end.y - 30, outer.size.x, 22), C["P61"])        # 청록 띠
	view.draw_rect(Rect2(outer.position.x, outer.end.y - 30, outer.size.x, 1), C["P62"])
	var bez := SCR.grow(8)
	view.draw_rect(bez, C["P05"])
	view.draw_rect(SCR.grow(4), C["P02"])
	view.draw_rect(SCR.grow(2), C["P00"])
	# 'SJ' 표지(동심원 셋) · 전원 램프 · 다이얼
	var lc := Vector2(outer.position.x + 22, outer.end.y - 19)
	for r in [8.0, 5.5, 3.0]:
		view.draw_arc(lc, r, 0, TAU, 24, C["P09"], 1.0)
	text(Vector2(lc.x + 13, lc.y - 7), "SJ-링크", f10, 10, C["P09"])
	var lamp := Vector2(outer.end.x - 20, outer.end.y - 19)
	var on := hack == null or hack.state != "locked"
	view.draw_circle(lamp, 4.0, (C["P62"] if on else C["P53"]) if fmod(time, 1.2) < 1.0 else C["P61"].darkened(0.3))
	view.draw_circle(lamp + Vector2(-1, -1), 1.2, Color(1, 1, 1, 0.6))
	text(Vector2(outer.position.x + 300, outer.end.y - 26), _hint(), f10, 10, C["P09"], HORIZONTAL_ALIGNMENT_CENTER)


func _hint() -> String:
	match mode:
		"hack":
			return "(방향키·마우스) 고르기   (E) 입력   (Esc) 나가기"
		"read":
			return "(↑↓) 넘기기   (E·Esc) 메뉴로"
	return "(↑↓·숫자) 고르기   (E) 열기   (Esc) 나가기"


func _scanlines() -> void:
	var y := SCR.position.y
	while y < SCR.end.y:
		view.draw_rect(Rect2(SCR.position.x, y + 1, SCR.size.x, 1), Color(0, 0, 0, 0.22))
		y += 2
	view.draw_rect(Rect2(SCR.position.x, SCR.position.y + fmod(time * 40.0, SCR.size.y), SCR.size.x, 3), Color(pal[6], 0.05))


## 글자 하나(번짐: 둘레에 흐린 같은 색)
func glyph(x: float, row_y: float, s: String, col: Color, w := CW) -> void:
	var gw := tw(s, f12, 12)
	var p := Vector2(x + floorf((w - gw) / 2.0), row_y + 2)
	if col != pal[0]:
		text(p + Vector2(1, 0), s, f12, 12, Color(col, 0.18))
	text(p, s, f12, 12, col)


## 한 줄(왼쪽 정렬, 반칸 격자, limit = 찍을 칸 수)
func line(cx: int, row: int, s: String, col: Color, limit := 1 << 30) -> int:
	var x := SCR.position.x + 6 + cx * CW
	var y := SCR.position.y + 2 + row * RH
	var used := 0
	for i in s.length():
		var ch := s[i]
		var w := _w(s.unicode_at(i))
		if used + w > limit:
			break
		if ch != " ":
			glyph(x, y, ch, col, CW * w)
		x += CW * w
		used += w
	return used


func row_rect(row: int, cx := 0, cells := 86) -> Rect2:
	return Rect2(SCR.position.x + 6 + cx * CW - 2, SCR.position.y + 2 + row * RH, cells * CW + 4, RH)


func _draw_header(limit: int) -> int:
	var hd: Array = SKIN_HEAD.get(str(term.get("skin", "T1")), SKIN_HEAD["T1"])
	var used := line(0, 0, hd[0], pal[6], limit)
	used += line(0, 1, hd[1], pal[4], limit - used)
	used += line(0, 2, "=".repeat(86), pal[3], limit - used)
	var r := 3
	for h in term.get("head", []):
		used += line(0, r, ">> " + str(h), pal[5], limit - used)
		r += 1
	return used


func _draw_menu() -> void:
	var limit := int(shown)
	var used := _draw_header(limit)
	var r0 := _head_rows() + 1
	if mode == "menu":
		for k in entries.size():
			var e: Dictionary = entries[k][1]
			var rr := row_rect(r0 + k)
			var sel := item("e%d" % k, rr)
			if sel:
				view.draw_rect(rr, pal[5])
			used += line(0, r0 + k, "[%d] %s" % [k + 1, e["title"]], pal[0] if sel else pal[5], limit - used)
		if used >= limit - 1 or fmod(time, 1.0) < 0.5:
			line(0, r0 + entries.size() + 1, ">", pal[5])
			if fmod(time, 1.0) < 0.5:
				_cursor(2, r0 + entries.size() + 1)
	else:
		var e: Dictionary = entries[reading][1]
		used += line(0, r0, "[%s]" % e["title"], pal[6], limit - used)
		var body := _read_lines()
		var rows := _body_rows() - 1
		var pages := maxi(1, ceili(body.size() / float(rows)))
		page = clampi(page, 0, pages - 1)
		for i in rows:
			var bi := page * rows + i
			if bi >= body.size():
				break
			used += line(0, r0 + 1 + i, str(body[bi]), pal[5], limit - used)
		item("back", Rect2(SCR.position, SCR.size))
		if pages > 1:
			line(70, ROWS - 1, "%d / %d쪽" % [page + 1, pages], pal[4])
		if fmod(time, 1.0) < 0.5:
			_cursor(0, ROWS - 1)


func _cursor(cx: int, row: int) -> void:
	var r := row_rect(row, cx, 1)
	view.draw_rect(Rect2(r.position.x + 2, r.position.y + 2, CW, RH - 4), pal[6])


# ---------------------------------------------------------------- 해킹 화면
const DUMP_ROW := 2
const LOG_X := 44                                  ## 기록창 시작 반칸

func _col_x(col: int) -> int:
	return col * 21                                ## 주소 6 + 빈칸 1 + 12칸 + 틈 2


func _cell_rect(i: int) -> Rect2:
	var p := Hack.cell_pos(i)
	var x := SCR.position.x + 6 + (_col_x(p.x) + 7 + p.z) * CW
	var y := SCR.position.y + 2 + (DUMP_ROW + p.y) * RH
	return Rect2(x, y, CW, RH)


func cell_at(p: Vector2) -> int:
	for col in Hack.COLS:
		var x0 := SCR.position.x + 6 + (_col_x(col) + 7) * CW
		if p.x < x0 or p.x >= x0 + Hack.CELLS * CW:
			continue
		var row := floori((p.y - (SCR.position.y + 2 + DUMP_ROW * RH)) / RH)
		if row < 0 or row >= Hack.ROWS:
			return -1
		var c := floori((p.x - x0) / CW)
		var i := (col * Hack.ROWS + row) * Hack.CELLS + c
		if not hack.cells[i]["head"] and i > 0:
			i -= 1
		return i
	return -1


func _draw_hack() -> void:
	var limit := int(shown)
	line(0, 0, "세진전자 단말연결 규약 (SJ-링크)", pal[6])
	var warn := hack.tries == 1 and hack.state == "play"
	if hack.state == "locked":
		line(0, 1, Hack.LOCK_TEXT, pal[6] if fmod(time, 0.6) < 0.4 else pal[3])
	elif warn:
		line(0, 1, "!!! 경고: 단말기 잠김 직전 !!!", pal[6] if fmod(time, 0.8) < 0.5 else pal[3])
	else:
		line(0, 1, "비밀번호를 입력하십시오.", pal[5])
	var boxes := "시도 가능 횟수:"
	for k in Hack.TRIES:
		boxes += " ■" if k < hack.tries else " □"
	line(LOG_X, 1, boxes, pal[6])
	var t := hack.target_at(cur) if hack.state == "play" else [-1, -1, "none"]
	var drawn := 0
	for col in Hack.COLS:
		for row in Hack.ROWS:
			var ry := SCR.position.y + 2 + (DUMP_ROW + row) * RH
			line(_col_x(col), DUMP_ROW + row, "0x%04X" % (hack.address + (col * Hack.ROWS + row) * Hack.CELLS), pal[4],
				maxi(0, limit - drawn))
			drawn += 6
	for i in Hack.TOTAL:
		if drawn + i > limit:
			break
		var c: Dictionary = hack.cells[i]
		if not c["head"]:
			continue
		var r := _cell_rect(i)
		var wide: bool = c["w"] >= 0
		var w := CW * (2 if wide else 1)
		var on: bool = i >= int(t[0]) and i <= int(t[1])
		var col: Color = pal[5]
		if wide and assist and hack.ruled_out(int(c["w"])):
			col = pal[3]
		if on:
			view.draw_rect(Rect2(r.position.x, r.position.y, w, RH), pal[6])
			col = pal[0]
		glyph(r.position.x, r.position.y, str(c["ch"]), col, w)
	# 기록창(아래에서 위로) + 입력 줄
	var lines: Array = hack.log.slice(maxi(0, hack.log.size() - 14))
	var row0 := ROWS - 1 - lines.size()
	for k in lines.size():
		line(LOG_X, row0 + k, str(lines[k]), pal[5])
	var sel := ""
	if hack.state == "play" and t[2] != "none":
		for j in range(int(t[0]), int(t[1]) + 1):
			sel += str(hack.cells[j]["ch"])
	var used := line(LOG_X, ROWS - 1, "> " + sel, pal[6])
	if fmod(time, 1.0) < 0.5:
		_cursor(LOG_X + used, ROWS - 1)
	# 마우스·터치 칸(그리기마다 다시 만든다)
	item("dump", Rect2(SCR.position.x, SCR.position.y + 2 + DUMP_ROW * RH, (LOG_X - 2) * CW, Hack.ROWS * RH))


# ---------------------------------------------------------------- 입력
func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if mode == "hack":
		_hack_input(e)
		return
	if e.is_pressed() and not e.is_echo() and not (e is InputEventMouseMotion) and _skip_typing():
		get_viewport().set_input_as_handled()
		return
	if mode == "menu" and e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode - KEY_1
		if k >= 0 and k < mini(9, entries.size()):
			_open_entry(k)
			get_viewport().set_input_as_handled()
			return
	if mode == "read":
		if e.is_action_pressed("ui_up", true) or e.is_action_pressed("ui_left", true):
			page -= 1
			shown = 1e9
		elif e.is_action_pressed("ui_down", true) or e.is_action_pressed("ui_right", true):
			var rows := _body_rows() - 1
			if (page + 1) * rows < _read_lines().size():
				page += 1
				shown = 1e9
			else:
				_back()
		elif e.is_action_pressed("ui_accept") or e.is_action_pressed("ui_cancel") \
				or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
			_back()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	super._unhandled_input(e)


func _hack_input(e: InputEvent) -> void:
	if hack.state != "play":
		if e.is_pressed():
			get_viewport().set_input_as_handled()
		return
	if e.is_pressed() and not e.is_echo() and not (e is InputEventMouseMotion) and shown < Hack.TOTAL + 200:
		shown = 1e9
		get_viewport().set_input_as_handled()
		return
	var t := hack.target_at(cur)
	if e.is_action_pressed("ui_right", true):
		_move_cell(int(t[1]) + 1, 1)
	elif e.is_action_pressed("ui_left", true):
		_move_cell(int(t[0]) - 1, -1)
	elif e.is_action_pressed("ui_down", true):
		_move_cell(cur + Hack.CELLS if (cur / Hack.CELLS) % Hack.ROWS < Hack.ROWS - 1 else cur, 0)
	elif e.is_action_pressed("ui_up", true):
		_move_cell(cur - Hack.CELLS if (cur / Hack.CELLS) % Hack.ROWS > 0 else cur, 0)
	elif e.is_action_pressed("ui_accept"):
		pick(cur)
	elif e.is_action_pressed("ui_cancel"):
		close(false)
	elif e is InputEventMouseMotion:
		var i := cell_at(_local(e.position))
		if i >= 0:
			cur = i
		return
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var i := cell_at(_local(e.position))
		if i < 0:
			return
		cur = i
		pick(i)
	else:
		return
	get_viewport().set_input_as_handled()


## 칸 이동(오른쪽 끝에서 다음 단, 왼쪽 끝에서 앞 단의 같은 행으로)
func _move_cell(i: int, d: int) -> void:
	if d != 0:
		var row := cur / Hack.CELLS
		var nrow := posmod(i, Hack.TOTAL) / Hack.CELLS
		if i < 0 or i >= Hack.TOTAL or nrow != row:
			var col := row / Hack.ROWS
			var r := row % Hack.ROWS
			col = clampi(col + d, 0, Hack.COLS - 1)
			i = (col * Hack.ROWS + r) * Hack.CELLS + (0 if d > 0 else Hack.CELLS - 1)
	i = clampi(i, 0, Hack.TOTAL - 1)
	if not hack.cells[i]["head"]:
		i -= 1
	cur = i


## 칸을 고른다(봇·시험도 부른다)
func pick(i: int) -> void:
	if hack == null or hack.state != "play":
		return
	hack.pick(i)
	if hack.state == "ok":
		end_at = time + 1.2
		hacked.emit(hack.xp())
	elif hack.state == "locked":
		end_at = time + 2.2
		locked_out.emit()


func _press(id: String) -> void:
	if id.begins_with("e"):
		_open_entry(int(id.substr(1)))
	elif id == "back":
		_back()


func _open_entry(k: int) -> void:
	reading = k
	page = 0
	shown = 0.0
	mode = "read"
	read.emit(int(entries[k][0]))


func _back() -> void:
	mode = "menu"
	cur = reading
	shown = 1e9
	focus_on("e%d" % maxi(0, reading))
	reading = -1


func _cancel() -> void:
	close(hack == null or hack.state == "ok")
