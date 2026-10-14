## 거래 창(SD-15 §3·§4, SD-12 §11.1 '2단 아이템 창', 단계 0-10c): 왼쪽 = 내 소지품(파는 값), 오른쪽 = 상인 진열(사는 값).
## 용기 창을 이어받는다(조작·스크롤·모달 같음): 위·아래 = 고르기, 왼쪽·오른쪽 = 칸 바꾸기, E·Enter = 하나 사고팔기,
## Shift+E·오른쪽 클릭 = 그 줄 전부(캡이 닿는 만큼), Tab·Esc = 닫기. 마우스·터치는 고른 줄을 다시 누르면 사고판다.
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


## 고른 줄을 하나(또는 캡이 닿는 만큼 전부) 사고판다
func move_sel(all := false) -> void:
	var l := _list(side)
	if l.is_empty():
		return
	var id: String = l[clampi(sel[side], 0, l.size() - 1)]
	var src: Dictionary = st.items if side == 0 else state["items"]
	var want: int = int(src[id]) if all else 1
	var n := 0
	for i in want:
		if not deal(id, side == 1):
			break
		n += 1
	if n == 0:
		_flash = 1.2
	var l2 := _list(side)
	sel[side] = clampi(sel[side], 0, maxi(0, l2.size() - 1))


var _flash := 0.0                                 ## 캡이 모자랄 때 캡 숫자를 잠깐 붉게
var _why := ""


## 한 개 거래. 성공하면 true
func deal(id: String, buying: bool) -> bool:
	if buying:
		var p := price(id, true)
		if int(state["items"].get(id, 0)) <= 0:
			return false
		if _caps() < p:
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
	if int(state.get("caps", 0)) < s:
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
	text(Vector2(44, 39), "내 캡 %d" % _caps(), f10, 10, warn if _flash > 0.0 else U[5])
	text(Vector2(596, 22), title, f12b, 12, U[6], HORIZONTAL_ALIGNMENT_RIGHT)
	text(Vector2(596, 39), "상인 캡 %d" % int(state.get("caps", 0)), f10, 10, U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	if greet != "":
		text(Vector2(320, 30), "“" + greet + "”", f10, 10, U[4], HORIZONTAL_ALIGNMENT_CENTER)
	v.draw_line(Vector2(36, 58), Vector2(604, 58), U[3])
	v.draw_line(Vector2(320, 62), Vector2(320, 286), U[2])
	for s in [0, 1]:
		_column(s, 36.0 if s == 0 else 328.0)
	v.draw_line(Vector2(36, 290), Vector2(604, 290), U[3])
	var l := _list(side)
	if not l.is_empty():
		var id: String = l[clampi(sel[side], 0, l.size() - 1)]
		var it: Dictionary = db.get(id, {})
		var info := "무게 %s · %s %d캡" % [_num(float(it.get("weight", 0))), "사는 값" if side == 1 else "파는 값", price(id, side == 1)]
		text(Vector2(40, 295), _name(id) + "  —  " + info, f10, 10, U[5])
	text(Vector2(600, 295), "무게 %s/%d" % [_num(_weight()), int(carry_max)], f10, 10, U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	var bx := 40.0
	for b in [["move", "E 사기" if side == 1 else "E 팔기"], ["close", "Tab 닫기"]]:
		var w := tw(b[1], f10, 10) + 20.0
		var r := Rect2(bx, 314, w, 20)
		var on := item(str(b[0]), r)
		v.draw_rect(r, U[5] if on else U[1])
		v.draw_rect(Rect2(r.position + Vector2(0.5, 0.5), r.size - Vector2.ONE), U[4], false, 1.0)
		text(Vector2(r.position.x + 10, r.position.y + 4), b[1], f10, 10, U[0] if on else U[6])
		bx += w + 8.0
	if _flash > 0.0 and _why != "":
		text(Vector2(600, 318), _why, f10, 10, warn, HORIZONTAL_ALIGNMENT_RIGHT)


func _column(s: int, x: float) -> void:
	var l := _list(s)
	var active := s == side
	sel[s] = clampi(sel[s], 0, maxi(0, l.size() - 1))
	if sel[s] < scroll[s]:
		scroll[s] = sel[s]
	elif sel[s] >= scroll[s] + ROWS_VISIBLE:
		scroll[s] = sel[s] - ROWS_VISIBLE + 1
	if l.is_empty():
		text(Vector2(x + 8, 70), "(팔 것이 없다)" if s == 0 else "(진열대가 비었다)", f10, 10, U[3])
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
		var nm := _name(id) + (" ×%d" % n if n > 1 else "")
		var dim := s == 1 and price(id, true) > _caps()                 # 못 사는 줄은 한 단 어둡게
		text(Vector2(x + 6, y + 3), nm, f10, 10, U[0] if on else (U[4] if dim else U[6]))
		if int(st.stolen.get(id, 0)) > 0 and s == 0:
			text(Vector2(x + 10 + tw(nm, f10, 10), y + 3), "[장물]", f10, 10, U[0] if on else DocScreen.C["P54"])
		text(Vector2(x + 270, y + 3), "%d캡" % price(id, s == 1), f10, 10, U[0] if on else U[5], HORIZONTAL_ALIGNMENT_RIGHT)
	if l.size() > ROWS_VISIBLE:
		var h := 220.0 * ROWS_VISIBLE / l.size()
		var y0: float = 64.0 + (220.0 - h) * int(scroll[s]) / maxf(1.0, float(l.size() - ROWS_VISIBLE))
		view.draw_rect(Rect2(x + 280, y0, 2, h), U[4])
