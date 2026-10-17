## 용기 창(SD-12 §7.3·§11.1 '2단 아이템 창', 단계 0-9): 왼쪽 = 내 소지품, 오른쪽 = 용기. 열려 있는 동안 시간이 멈춘다(모달).
## 조작: 위·아래 = 고르기, 왼쪽·오른쪽 = 칸 바꾸기, E·Enter = 하나 옮기기, Shift+E·오른쪽 클릭 = 그 줄 전부, Q = 모두 가져가기,
##        Tab·Esc = 닫기. 마우스·터치: 줄을 누르면 고르고, 고른 줄을 다시 누르면 옮긴다. 아래 단추 셋(옮기기·모두 가져가기·닫기).
## 소유 용기(이름 붉게 + [소유])에서 꺼내면 절도다(SD-12 §9.2): 꺼낼 때마다 stole 신호, first는 이 용기의 이 시대 첫 절도만
## (SD-10 §6.3 '같은 용기는 게임 1일 1회' — 프롤로그는 시대 하나가 하루다) → 진행기가 first일 때 카르마 −5, 목격은 매번 본다.
## 꺼낸 물건은 [장물]로 표시되고, 다시 넣으면 장물 수가 줄어든다. 퀘스트 아이템은 넣을 수 없다.
class_name ContainerScreen
extends DocScreen

signal stole(first: bool)                        ## 소유 용기에서 꺼냈다(first: 이 용기의 이 시대 첫 절도)
signal stash_act(what: String)                   ## 보관 자리(1-L §3 · §9.3): "claim" 내 자리로 삼기 · "release" 자리 놓기 · "bell" 방울 줄 매기

const U := DocScreen.GREEN
const ROWS_VISIBLE := 11
var db := {}                                     ## 아이템 ID -> 이름·분류·무게·가치·설명(InteriorHost.items_db)
var bdef: Dictionary                              ## 맵 용기 정의(종류·소유·이름)
var state: Dictionary                            ## st.boxes의 이 용기 {"items", "opened", "taken"}
var title := ""
var owner_name := ""
var side := 1                                    ## 0 내 소지품 · 1 용기
var sel := [0, 0]
var scroll := [0, 0]
var carry_max := 150.0
var stash_mode := ""                             ## "" · "claim"(비운 용기 — 삼을 수 있다) · "release"(내 자리)
var stash_line := ""                             ## 그 자리의 위험을 세계 말로 한 줄(§9.3)
var bell_ok := false                             ## 방울 줄을 맬 수 있다(내 자리 · M-195 소지 · 아직 안 맴)


func setup(state_: StoryState, b: Dictionary, contents: Dictionary, items_db: Dictionary, owner_label: String, cmax: float) -> ContainerScreen:
	st = state_
	bdef = b
	state = contents
	db = items_db
	owner_name = owner_label
	carry_max = cmax
	title = str(b.get("name", "")) if str(b.get("name", "")) != "" else Loot.kind_name(str(b["kind"]))
	state["opened"] = int(state.get("opened", 0)) + 1
	side = 1 if not _list(1).is_empty() else 0
	cancel_ok = true
	return self


func _list(s: int) -> Array:
	var src: Dictionary = st.items if s == 0 else state["items"]
	var ids := src.keys().filter(func(id): return int(src[id]) > 0)
	if s == 0:
		ids = ids.filter(func(id): return str(db.get(id, {}).get("tag", "")) != "퀘스트")   # 퀘스트 아이템은 넣지 않는다
	ids.sort_custom(func(a, b): return _name(a) < _name(b))
	return ids


func _name(id: String) -> String:
	return str(db.get(id, {}).get("name", id))


func _weight() -> float:
	var w := 0.0
	for id in st.items:
		w += float(db.get(id, {}).get("weight", 0)) * int(st.items[id])
	return w


# ---------------------------------------------------------------- 옮기기
func move_sel(all := false) -> void:
	var l := _list(side)
	if l.is_empty():
		return
	var id: String = l[clampi(sel[side], 0, l.size() - 1)]
	var src: Dictionary = st.items if side == 0 else state["items"]
	var n: int = int(src[id]) if all else 1
	_transfer(id, n, side == 1)
	var l2 := _list(side)
	sel[side] = clampi(sel[side], 0, maxi(0, l2.size() - 1))
	if l2.is_empty():
		side = 1 - side if not _list(1 - side).is_empty() else side


func take_all() -> void:
	for id in _list(1):
		_transfer(id, int(state["items"][id]), true)
	sel[1] = 0
	side = 0


func _transfer(id: String, n: int, taking: bool) -> void:
	if n <= 0:
		return
	if taking:
		state["items"][id] = int(state["items"][id]) - n
		if int(state["items"][id]) <= 0:
			state["items"].erase(id)
		if id == "M-001":
			st.call_fn("caps", [n])                                     # 캡(병뚜껑)은 소지 캡이 된다(1-4 파밍)
		else:
			st.call_fn("give", [id, n])
		state["taken"] = int(state.get("taken", 0)) + n
		if Loot.owned(bdef):
			st.stolen[id] = int(st.stolen.get(id, 0)) + n
			var first := not bool(state.get("karma_done", false))
			state["karma_done"] = true
			stole.emit(first)
	else:
		st.items[id] = int(st.items[id]) - n
		if int(st.items[id]) <= 0:
			st.items.erase(id)
		state["items"][id] = int(state["items"].get(id, 0)) + n
		if st.stolen.has(id):                                          # 장물을 돌려놓으면 장물 수가 줄어든다
			st.stolen[id] = maxi(0, int(st.stolen[id]) - n)
			if int(st.stolen[id]) == 0:
				st.stolen.erase(id)


# ---------------------------------------------------------------- 그리기
func _draw_doc() -> void:
	var v := view
	v.draw_rect(Rect2(0, 0, 640, 360), Color(U[0], 1.0))
	var p := Rect2(24, 20, 592, 320)
	v.draw_rect(p, U[1])
	v.draw_rect(p.grow(-1), U[0])
	v.draw_rect(Rect2(p.position + Vector2(0.5, 0.5), p.size - Vector2.ONE), U[4], false, 1.0)
	for y in range(int(p.position.y) + 2, int(p.end.y) - 1, 2):              # 화면 줄(CRT) — 짝수 줄을 한 단 어둡게
		v.draw_line(Vector2(p.position.x + 1, y), Vector2(p.end.x - 1, y), Color(U[1], 0.55))
	var owned := Loot.owned(bdef)
	text(Vector2(44, 30), "소지품", f12b, 12, U[6])
	var tcol: Color = DocScreen.C["P54"] if owned else U[6]
	var head := title + ("  [소유]" if owned else "") + ("  [빈 상자]" if _list(1).is_empty() else "")
	text(Vector2(596, 30), head, f12b, 12, tcol, HORIZONTAL_ALIGNMENT_RIGHT)
	if owned and owner_name != "":
		text(Vector2(596, 45), "주인: " + owner_name, f10, 10, Color(DocScreen.C["P54"], 0.9), HORIZONTAL_ALIGNMENT_RIGHT)
	elif stash_line != "":
		text(Vector2(596, 45), ("[내 자리] " if stash_mode == "release" else "") + stash_line, f10, 10, U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	v.draw_line(Vector2(36, 58), Vector2(604, 58), U[3])
	v.draw_line(Vector2(320, 62), Vector2(320, 286), U[2])
	for s in [0, 1]:
		_column(s, 36.0 if s == 0 else 328.0)
	# 아래: 고른 물건 설명 · 무게 · 단추
	v.draw_line(Vector2(36, 290), Vector2(604, 290), U[3])
	var l := _list(side)
	if not l.is_empty():
		var id: String = l[clampi(sel[side], 0, l.size() - 1)]
		var it: Dictionary = db.get(id, {})
		var info := "무게 %s · 가치 %d" % [_num(float(it.get("weight", 0))), int(it.get("value", 0))]
		text(Vector2(40, 295), _name(id) + "  —  " + info, f10, 10, U[5])
	text(Vector2(600, 295), "무게 %s/%d" % [_num(_weight()), int(carry_max)], f10, 10, U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	var bx := 40.0
	var btns := [["move", "E 옮기기"], ["all", "Q 모두 가져가기"], ["close", "Tab 닫기"]]
	if stash_mode != "":
		btns.append(["mine", "C 내 자리로 삼기" if stash_mode == "claim" else "C 자리 놓기"])
	if bell_ok:
		btns.append(["bell", "B 방울 줄 매기"])
	for b in btns:
		var w := tw(b[1], f10, 10) + 20.0
		var r := Rect2(bx, 312, w, 20)
		var on := item(str(b[0]), r)
		v.draw_rect(r, U[5] if on else U[1])
		v.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), U[4], false, 1.0)
		text(Vector2(r.position.x + 10, r.position.y + 4), b[1], f10, 10, U[0] if on else U[6])
		bx += w + 8.0
	if owned:
		text(Vector2(600, 316), "남의 물건 — 꺼내면 절도", f10, 10, DocScreen.C["P54"], HORIZONTAL_ALIGNMENT_RIGHT)


func _column(s: int, x: float) -> void:
	var l := _list(s)
	var active := s == side
	sel[s] = clampi(sel[s], 0, maxi(0, l.size() - 1))
	if sel[s] < scroll[s]:
		scroll[s] = sel[s]
	elif sel[s] >= scroll[s] + ROWS_VISIBLE:
		scroll[s] = sel[s] - ROWS_VISIBLE + 1
	if l.is_empty():
		text(Vector2(x + 8, 70), "(비어 있음)", f10, 10, U[3])
		var why := Loot.empty_line(state) if s == 1 and state.has("why") else ""
		if why != "":                                                      # 1-L 빈 이유 글: 처음부터 빈 상자는 왜 비었는지 보인다
			var ly := 90.0
			for ln in TextWrap.wrap(why, func(t: String) -> float: return f10.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x, 260.0):
				text(Vector2(x + 8, ly), ln, f10, 10, U[5])
				ly += 15.0
	for i in range(scroll[s], mini(l.size(), scroll[s] + ROWS_VISIBLE)):
		var id: String = l[i]
		var y: float = 64.0 + (i - int(scroll[s])) * 20.0
		var r := Rect2(x, y, 276, 18)
		item("row%d_%d" % [s, i], r)
		var on: bool = active and i == sel[s]
		if on:
			view.draw_rect(r, U[5])
		elif i == sel[s]:
			view.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), U[3], false, 1.0)
		var n := int((st.items if s == 0 else state["items"])[id])
		var nm := _name(id)
		var hot := int(st.stolen.get(id, 0)) > 0 and s == 0
		text(Vector2(x + 6, y + 3), nm, f10, 10, U[0] if on else U[6])
		if hot:
			text(Vector2(x + 10 + tw(nm, f10, 10), y + 3), "[장물]", f10, 10, U[0] if on else DocScreen.C["P54"])
		text(Vector2(x + 270, y + 3), "×%d" % n if n > 1 else "", f10, 10, U[0] if on else U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	if l.size() > ROWS_VISIBLE:                                                # 스크롤 막대
		var h := 220.0 * ROWS_VISIBLE / l.size()
		var y0: float = 64.0 + (220.0 - h) * int(scroll[s]) / maxf(1.0, float(l.size() - ROWS_VISIBLE))
		view.draw_rect(Rect2(x + 280, y0, 2, h), U[4])


static func _num(f: float) -> String:
	return str(int(f)) if is_equal_approx(f, roundf(f)) else "%.1f" % f


# ---------------------------------------------------------------- 입력(DocScreen 기본을 2단 창에 맞게 바꾼다)
func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	var k: int = e.keycode if e is InputEventKey and e.pressed and not e.echo else -1
	if k in [KEY_TAB, KEY_ESCAPE]:
		close(true)
	elif k == KEY_Q:
		take_all()
	elif k == KEY_C and stash_mode != "":
		stash_act.emit(stash_mode)
	elif k == KEY_B and bell_ok:
		stash_act.emit("bell")
	elif k in [KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		move_sel(e.shift_pressed)
	elif e.is_action_pressed("ui_up", true):
		sel[side] = maxi(0, sel[side] - 1)
	elif e.is_action_pressed("ui_down", true):
		sel[side] = mini(maxi(0, _list(side).size() - 1), sel[side] + 1)
	elif e.is_action_pressed("ui_left", true):
		side = 0
	elif e.is_action_pressed("ui_right", true):
		side = 1
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		var i := _item_at(_local(e.position))
		if i < 0:
			return
		var id: String = items[i]["id"]
		if id.begins_with("row"):
			var s := int(id.substr(3, 1))
			var r := int(id.get_slice("_", 1))
			if s == side and r == sel[s]:
				move_sel(e.button_index == MOUSE_BUTTON_RIGHT)
			else:
				side = s
				sel[s] = r
		else:
			_press(id)
	elif e is InputEventMouseButton and e.pressed and e.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		sel[side] = clampi(sel[side] + (1 if e.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0, maxi(0, _list(side).size() - 1))
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
		view.queue_redraw()


func _press(id: String) -> void:
	match id:
		"move":
			move_sel()
		"all":
			take_all()
		"close":
			close(true)
		"mine":
			stash_act.emit(stash_mode)
		"bell":
			stash_act.emit("bell")
