## 거래 창(SD-15 §3·§4, SD-12 §11.1 '2단 아이템 창'·§17.5 터치, 단계 0-10c): 왼쪽 = 내 소지품(파는 값), 오른쪽 = 상인 진열(사는 값).
## 원작처럼 **바구니 거래**다: 물건을 '담으면' 거래 목록에 오르고(줄에 담은 수가 붙는다), 아래 줄에 `내 캡 / 상인 캡 / 이번 거래 차액`이
## 바뀐다. `거래 확정`을 눌러야 캡과 물건이 오간다(차액이 맞지 않으면 확정이 켜지지 않는다). 창을 닫으면 담은 것은 없던 일이 된다.
## 조작: 위·아래 = 고르기 · 왼쪽·오른쪽 = 칸 바꾸기 · E·Enter = 하나 담기 · Shift+E = 그 줄 전부 담기 · R·Backspace = 하나 빼기 ·
##        F·Space = 거래 확정 · Tab·Esc = 닫기. 마우스·터치: 줄을 누르면 고르고, 고른 줄을 다시 누르면 담는다(오른쪽 클릭 = 빼기).
##        아래 단추(담기·빼기·거래 확정·닫기). 단추로 하는 거래 확정은 두 번 누른다(§17.1 오조작 방지 — 되돌릴 수 없는 결정).
## 값은 공통 함수 price_of 하나가 낸다(§3.1): 구매가 = 반올림(V×B×F×K) ≥ V×G, 판매가 = 반올림(V×S×F×K) ≤ 내림(V×G×0.95).
## 0-10에서 M(판도·공급)·W(수배)는 1.0이다(봉천은 판도 '지배'가 아니고, 수배 등급은 2에 못 미친다 — STAGE_0 0-10 정합).
## 배수 내역은 숫자로 보이지 않고, 창 위 상인 인사 한 줄이 가장 큰 보정 하나를 말로 알린다(§3.10).
class_name TradeScreen
extends ContainerScreen

signal traded(id: String, n: int, caps: int, buying: bool)

var vid := ""                                     ## 상인 V번호
var mdef: Dictionary                              ## data/merchants.json의 이 상인
var barter := 0                                   ## 주인공 물물교환 스킬
var f := [1.0, 1.0]                               ## 호감도 단계 배수 [구매, 판매]
var k := [1.0, 1.0]                               ## 개인 보정 [구매, 판매]
var greet := ""
var total := 0                                    ## 이번에 오간 캡(단골 누적·MQ101_TRADE)
var item_k := {}                                  ## 품목별 사는 값 배수(퀘스트 결과: MQ-101 '마을을 판다' → 물값 2배)
var cart := [{}, {}]                              ## 담은 물건: [0] 내가 파는 것 {ID: 수} · [1] 내가 사는 것 {ID: 수}
var _armed := false                               ## 거래 확정 단추를 한 번 눌렀다(한 번 더 누르면 확정)
var _flash := 0.0                                 ## 확정이 안 될 때 아래 줄을 잠깐 붉게
var _why := ""


func setup_trade(state_: StoryState, merchant_id: String, m: Dictionary, shop: Dictionary, items_db: Dictionary, cmax: float,
		barter_: int, f_: Array, k_: Array, greet_: String) -> TradeScreen:
	st = state_
	vid = merchant_id
	mdef = m
	state = shop
	db = items_db
	carry_max = cmax
	barter = barter_
	f = f_
	k = k_
	greet = greet_
	title = str(m.get("name", merchant_id))
	bdef = {"kind": "shop"}
	side = 1
	cancel_ok = true
	return self


## 호감도 값 → 단계 배수 [F구매, F판매](SD-15 §3.3 기본표 · SD-06 §4.2 단계 경계). 적대면 빈 배열(거래 불가)
static func tier_f(aff: int) -> Array:
	if aff <= -60:
		return []
	if aff <= -20:
		return [1.25, 0.75]
	if aff < 20:
		return [1.0, 1.0]
	if aff < 50:
		return [0.90, 1.05]
	if aff < 80:
		return [0.80, 1.10]
	return [0.75, 1.15]


## PriceOf(아이템, 상인, 방향)(SD-15 §3.1·§3.7): value = 기준가 V, buying = 주인공이 사는 쪽. G(공급)는 0-10에서 1.0
static func price_of(value: int, buying: bool, barter_: int, f_: Array, k_: Array, g := 1.0) -> int:
	if value <= 0:
		return 0 if buying else -1                                      # 가치 0 물건은 팔 수 없다
	var sk := clampf(float(barter_), 0.0, 100.0) / 100.0
	if buying:
		var b := 1.55 - 0.45 * sk
		return maxi(roundi(value * b * float(f_[0]) * float(k_[0]) * g), roundi(value * g))
	var s := 0.45 + 0.45 * sk
	return clampi(roundi(value * s * float(f_[1]) * float(k_[1]) * g), 1, maxi(1, floori(value * g * 0.95)))


func _value(id: String) -> int:
	return int(db.get(id, {}).get("value", 0))


func price(id: String, buying: bool) -> int:
	if buying and item_k.has(id):
		return price_of(_value(id), true, barter, f, [float(k[0]) * float(item_k[id]), k[1]])
	return price_of(_value(id), buying, barter, f, k)


## 이 상인이 사는 물건인가(§4.1): 퀘스트 아이템·가치 0은 안 산다. 전문 상인은 취급 분류만
func buys(id: String) -> bool:
	var it: Dictionary = db.get(id, {})
	if str(it.get("tag", "")) == "퀘스트" or str(it.get("cat", "")) == "quest" or _value(id) <= 0:
		return false
	if id == worn() and int(st.items.get(id, 0)) <= 1:
		return false                                                    # 입고 있는 한 벌은 팔지 않는다
	var cats: Array = mdef.get("buys", ["*"])
	return "*" in cats or str(it.get("cat", "misc")) in cats


func worn() -> String:
	return str(st.vars.get_v("PC_TORSO")) if st.vars.has("PC_TORSO") else ""


func _list(s: int) -> Array:
	var l := super._list(s)
	if s == 0:
		l = l.filter(func(id): return buys(id))
	return l


func _caps() -> int:
	return int(st.vars.get_v("PC_CAPS"))


func _have(s: int, id: String) -> int:
	return int((st.items if s == 0 else state["items"]).get(id, 0))


# ---------------------------------------------------------------- 바구니
## 이번 거래 차액(주인공 쪽): 판 값 합 − 산 값 합
func balance() -> int:
	var b := 0
	for id in cart[0]:
		b += price(id, false) * int(cart[0][id])
	for id in cart[1]:
		b -= price(id, true) * int(cart[1][id])
	return b


## 확정할 수 있나: 내 캡·상인 캡이 차액을 감당하고, 담은 것이 하나라도 있다. 안 되면 까닭 글
func can_confirm() -> String:
	if cart[0].is_empty() and cart[1].is_empty():
		return "담은 물건이 없다"
	var b := balance()
	if b < 0 and _caps() < -b:
		return "캡이 모자라다"
	if b > 0 and int(state.get("caps", 0)) < b:
		return "상인 캡이 모자라다"
	return ""


## s 쪽 id를 n개 담는다(가진 수까지). 담은 수를 돌려준다
func offer(s: int, id: String, n := 1) -> int:
	if s == 0 and not buys(id):
		return 0
	var room := _have(s, id) - int(cart[s].get(id, 0))
	var add := mini(n, room)
	if add <= 0:
		return 0
	cart[s][id] = int(cart[s].get(id, 0)) + add
	_armed = false
	return add


func unoffer(s: int, id: String, n := 1) -> int:
	var cur := int(cart[s].get(id, 0))
	var take := mini(n, cur)
	if take <= 0:
		return 0
	if cur - take <= 0:
		cart[s].erase(id)
	else:
		cart[s][id] = cur - take
	_armed = false
	return take


## 거래 확정: 담은 것을 한 번에 주고받는다. 성공하면 true
func confirm() -> bool:
	_why = can_confirm()
	if _why != "":
		_flash = 1.4
		return false
	for id in cart[0].keys():
		for i in int(cart[0][id]):
			deal(id, false, true)
	for id in cart[1].keys():
		for i in int(cart[1][id]):
			deal(id, true, true)
	cart = [{}, {}]
	_armed = false
	return true


## 물건 하나를 바로 주고받는다(바구니 확정과 시험이 쓴다). skip_caps: 바구니 확정 — 캡 검사는 차액으로 이미 했다
func deal(id: String, buying: bool, skip_caps := false) -> bool:
	if buying:
		var p := price(id, true)
		if int(state["items"].get(id, 0)) <= 0:
			return false
		if not skip_caps and _caps() < p:
			_why = "캡이 모자라다"
			return false
		state["items"][id] = int(state["items"][id]) - 1
		if int(state["items"][id]) <= 0:
			state["items"].erase(id)
		st.vars.set_v("PC_CAPS", _caps() - p)
		state["caps"] = int(state.get("caps", 0)) + p
		st.items[id] = int(st.items.get(id, 0)) + 1
		total += p
		traded.emit(id, 1, p, true)
		return true
	var s := price(id, false)
	if s < 0 or not buys(id) or int(st.items.get(id, 0)) <= 0:
		return false
	if not skip_caps and int(state.get("caps", 0)) < s:
		_why = "상인 캡이 모자라다"
		return false
	st.items[id] = int(st.items[id]) - 1
	if int(st.items[id]) <= 0:
		st.items.erase(id)
	if st.stolen.has(id):
		st.stolen[id] = int(st.stolen[id]) - 1
		if int(st.stolen[id]) <= 0:
			st.stolen.erase(id)
	state["items"][id] = int(state["items"].get(id, 0)) + 1
	state["caps"] = int(state.get("caps", 0)) - s
	st.vars.set_v("PC_CAPS", _caps() + s)
	total += s
	traded.emit(id, 1, s, false)
	return true


func _sel_id() -> String:
	var l := _list(side)
	return "" if l.is_empty() else str(l[clampi(sel[side], 0, l.size() - 1)])


## E: 고른 줄을 담는다(all = 그 줄 남은 것 전부)
func move_sel(all := false) -> void:
	var id := _sel_id()
	if id == "":
		return
	if offer(side, id, 1 << 20 if all else 1) == 0:
		_why = "더 담을 수 없다" if side == 1 or buys(id) else "이 상인은 사지 않는다"
		_flash = 1.0


func unmove_sel() -> void:
	var id := _sel_id()
	if id != "":
		unoffer(side, id, 1)


func take_all() -> void:
	pass                                                                # 거래 창에는 '모두 가져가기'가 없다


func _tick(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt)
		view.queue_redraw()


# ---------------------------------------------------------------- 그리기
func _draw_doc() -> void:
	var v := view
	v.draw_rect(Rect2(0, 0, 640, 360), Color(U[0], 1.0))
	var p := Rect2(24, 14, 592, 332)
	v.draw_rect(p, U[1])
	v.draw_rect(p.grow(-1), U[0])
	v.draw_rect(Rect2(p.position + Vector2(0.5, 0.5), p.size - Vector2.ONE), U[4], false, 1.0)
	for y in range(int(p.position.y) + 2, int(p.end.y) - 1, 2):
		v.draw_line(Vector2(p.position.x + 1, y), Vector2(p.end.x - 1, y), Color(U[1], 0.55))
	var warn: Color = DocScreen.C["P54"]
	text(Vector2(44, 22), "소지품", f12b, 12, U[6])
	text(Vector2(596, 22), title, f12b, 12, U[6], HORIZONTAL_ALIGNMENT_RIGHT)
	if greet != "":
		text(Vector2(320, 30), "“" + greet + "”", f10, 10, U[4], HORIZONTAL_ALIGNMENT_CENTER)
	v.draw_line(Vector2(36, 50), Vector2(604, 50), U[3])
	v.draw_line(Vector2(320, 54), Vector2(320, 264), U[2])
	for s in [0, 1]:
		_column(s, 36.0 if s == 0 else 328.0)
	# 가운데 아래(§11.1): 내 캡 / 상인 캡 / 이번 거래 차액 — 확정하면 어떻게 되는지까지
	v.draw_line(Vector2(36, 268), Vector2(604, 268), U[3])
	var b := balance()
	var bad := can_confirm()
	var empty: bool = cart[0].is_empty() and cart[1].is_empty()
	text(Vector2(40, 273), "내 캡 %d%s" % [_caps(), "" if empty else " → %d" % (_caps() + b)], f10, 10,
		warn if (b < 0 and _caps() < -b) else U[6])
	text(Vector2(320, 273), "이번 거래 차액 %s캡" % ("%+d" % b if b != 0 else "0"), f10, 10,
		U[6] if empty or bad == "" else warn, HORIZONTAL_ALIGNMENT_CENTER)
	var mc := int(state.get("caps", 0))
	text(Vector2(600, 273), "상인 캡 %d%s" % [mc, "" if empty else " → %d" % (mc - b)], f10, 10,
		warn if (b > 0 and mc < b) else U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	var id := _sel_id()
	if id != "":
		var it: Dictionary = db.get(id, {})
		var info := "무게 %s · %s %d캡" % [_num(float(it.get("weight", 0))), "사는 값" if side == 1 else "파는 값", price(id, side == 1)]
		text(Vector2(40, 289), _name(id) + "  —  " + info, f10, 10, U[5])
	text(Vector2(600, 289), "무게 %s/%d" % [_num(_weight()), int(carry_max)], f10, 10, U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	var bx := 40.0
	for bt in [["move", "E 담기"], ["unmove", "R 빼기"], ["confirm", "한 번 더 = 확정" if _armed else "F 거래 확정"], ["close", "Tab 닫기"]]:
		var w := maxf(tw(bt[1], f10, 10) + 20.0, 64.0)
		var r := Rect2(bx, 308, w, 24)
		var on := item(str(bt[0]), r)
		var lit: bool = on or (bt[0] == "confirm" and _armed)
		var dim: bool = bt[0] == "confirm" and bad != ""
		v.draw_rect(r, U[5] if lit else U[1])
		v.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), U[3] if dim else U[4], false, 1.0)
		text(Vector2(r.position.x + 10, r.position.y + 6), bt[1], f10, 10, U[0] if lit else (U[3] if dim else U[6]))
		bx += w + 6.0
	if _flash > 0.0 and _why != "":
		text(Vector2(600, 314), _why, f10, 10, warn, HORIZONTAL_ALIGNMENT_RIGHT)


const ROWS := 10


func _column(s: int, x: float) -> void:
	var l := _list(s)
	var active := s == side
	sel[s] = clampi(sel[s], 0, maxi(0, l.size() - 1))
	if sel[s] < scroll[s]:
		scroll[s] = sel[s]
	elif sel[s] >= scroll[s] + ROWS:
		scroll[s] = sel[s] - ROWS + 1
	if l.is_empty():
		text(Vector2(x + 8, 62), "(팔 것이 없다)" if s == 0 else "(진열대가 비었다)", f10, 10, U[3])
	for i in range(scroll[s], mini(l.size(), scroll[s] + ROWS)):
		var id: String = l[i]
		var y: float = 56.0 + (i - int(scroll[s])) * 21.0
		var r := Rect2(x, y, 276, 19)
		item("row%d_%d" % [s, i], r)
		var on: bool = active and i == sel[s]
		var n_in := int(cart[s].get(id, 0))
		if on:
			view.draw_rect(r, U[5])
		elif n_in > 0:
			view.draw_rect(r, Color(U[3], 0.55))                          # 담은 줄은 한 단 밝게
		if not on and i == sel[s]:
			view.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), U[3], false, 1.0)
		var n := _have(s, id)
		var nm := _name(id) + (" ×%d" % n if n > 1 else "")
		var dim := s == 1 and n_in == 0 and price(id, true) > _caps() + balance()      # 지금 차액으로는 못 사는 줄
		text(Vector2(x + 6, y + 4), nm, f10, 10, U[0] if on else (U[4] if dim else U[6]))
		var tag_x := x + 10 + tw(nm, f10, 10)
		if int(st.stolen.get(id, 0)) > 0 and s == 0:
			text(Vector2(tag_x, y + 4), "[장물]", f10, 10, U[0] if on else DocScreen.C["P54"])
			tag_x += tw("[장물]", f10, 10) + 4
		if n_in > 0:
			text(Vector2(tag_x, y + 4), ("판다 %d" if s == 0 else "산다 %d") % n_in, f10, 10, U[0] if on else U[6])
		text(Vector2(x + 270, y + 4), "%d캡" % price(id, s == 1), f10, 10, U[0] if on else U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	if l.size() > ROWS:
		var h := 210.0 * ROWS / l.size()
		var y0: float = 56.0 + (210.0 - h) * int(scroll[s]) / maxf(1.0, float(l.size() - ROWS))
		view.draw_rect(Rect2(x + 280, y0, 2, h), U[4])


# ---------------------------------------------------------------- 입력(용기 창의 입력을 바구니 거래에 맞게 바꾼다)
func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	var handled := true
	var kc: int = e.keycode if e is InputEventKey and e.pressed and not e.echo else -1
	if kc in [KEY_TAB, KEY_ESCAPE]:
		close(true)
	elif kc in [KEY_F, KEY_SPACE]:
		confirm()
	elif kc in [KEY_R, KEY_BACKSPACE]:
		unmove_sel()
	elif kc in [KEY_E, KEY_ENTER, KEY_KP_ENTER]:
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
		var iid: String = items[i]["id"]
		if iid.begins_with("row"):
			var s := int(iid.substr(3, 1))
			var r := int(iid.get_slice("_", 1))
			if e.button_index == MOUSE_BUTTON_RIGHT:
				side = s
				sel[s] = r
				unmove_sel()
			elif s == side and r == sel[s]:
				move_sel()
			else:
				side = s
				sel[s] = r
		else:
			_press(iid)
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
		"unmove":
			unmove_sel()
		"confirm":
			if not _armed and can_confirm() == "":
				_armed = true                                            # 단추 확정은 두 번(§17.1)
			else:
				confirm()
		"close":
			close(true)
