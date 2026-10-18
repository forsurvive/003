## U04 여의도 지하(단계 1-D10, 1-D 계획 §16.6~§16.8 · SD-09f L-UG-06 · 07 · 08): 5호선 영등포시장 → 신길 → 여의도 → 여의나루.
## 동사 — 레일에 귀를 대고, 레일로 말한다.
## · 운반조 레일 수레: 레일 줄에서 수레 쪽으로 걸어 들어가면 한 칸씩 민다(발 고정 걸음 그대로 — 수레가 비켜야 내가 간다). 바퀴가 이음매(6칸마다)를 칠 때
##   소리가 레일을 타고 '진행 방향 앞' 휴면 무리를 먼저 깨운다(뒤는 가까이만). 바퀴 천을 감으면 조용하고 느리다. 내리막에서는 올라타 질주 · 조사 키로 브레이크.
## · 귀 대기: 레일 위에서 아무것도 없는 데 조사 키 → 앞뒤 소리(잠든 숨 · 발소리 · 수레 · 사람)를 방향과 거리로.
## · 두드림: 두 번 간다 · 세 번 서라 · 길게 한 번 사람 · 길게 하나 둘 운반조 지나감(여의도 공병 통제선) · 네 번 빠르게 = 깬다.
## · 밤 22~23시 운반조 수레가 터널을 지난다 — '두 번'이면 옆 선로로 비켜 가고, 아니면 앞에서 서서 레일 말을 가르친다.
## · 운송(소민서): 편도 · 짐마다 성질(진공관 덜컹 · 닭 울음 · 전지 무게) · 여의나루 차막이부터 손으로 · 셋째에 쉼터 · 중계 사물함.
## · UG-H03 대기 명단 · 신길 '미입장' 대피민을 수레로 모셔 대기 줄 빈자리에(엉뚱한 짓) · 정리 = 두 무리가 더는 없음.
## 사실은 변수 한 곳(P1) — 뜻은 script/act1/U04.txt 머리 주석.
class_name U04
extends Node

const MAPS := ["", "U4-01", "U4-02", "U4-03", "U4-04", "U4-05"]
const RAIL := {"U4-01": 18, "U4-02": 7, "U4-03": 18, "U4-04": 7, "U4-05": 20}      ## 수레가 다니는 레일 줄
const ALT := {"U4-01": 21, "U4-02": 10, "U4-03": 21, "U4-04": 10, "U4-05": 23}      ## 옆 선로(운반조가 비켜 가는 줄)
const WID := {"U4-01": 44, "U4-02": 110, "U4-03": 48, "U4-04": 100, "U4-05": 52}
const NEXT := {"U4-01": {"E": "U4-02"}, "U4-02": {"W": "U4-01", "E": "U4-03"}, "U4-03": {"W": "U4-02", "E": "U4-04"},
	"U4-04": {"W": "U4-03", "E": "U4-05"}, "U4-05": {"W": "U4-04"}}
const SLOPE := {"U4-02": [90, 108], "U4-04": [6, 70]}                               ## 동쪽으로 내려가는 내리막(칸 x 범위)
const SINGIL := "U4-02"
const NARU := "U4-05"
const YD := "U4-03"
const JOINT := 6
const R_AHEAD := 40                                  ## 덜컹이 레일을 타고 닿는 앞쪽 칸 수(천 감으면 ×0.35)
const R_BACK := 4
const CLOTH_LIFE := 20                               ## 바퀴 천이 닳아 풀리는 이음매 수(타면 두 배로 닳는다)
const FLAT_FRIC := 1.0                               ## 평지 감속(칸/초²) — 터널
const STATION_FRIC := 0.25                           ## 역 구간 감속 — 브레이크를 안 잡으면 끝까지 굴러 '쿵'
const SANDBAG := Vector2i(40, 18)                    ## 여의도 공병 통제선 레일 칸
const PAY := {6: 45, 7: 40, 8: 60}                   ## 운임(캡) — 진공관은 덜컹 둘을 넘을 때마다 −6
const BACK_PAY := 20
const S_SHEETS := ["en_cr204_loco", "en_cr204b_loco", "en_cr204c_loco"]
const CARRIER_SHEETS := ["st_look_e1_s3_hr04_h3_t03_2_pf12_hd00_ey00_pr011", "st_look_f1_s4_hr06_h2_t05_1_pf12_hd00_ey00"]
const CARGO := {6: "M-406", 7: "M-407", 8: "M-408", 9: "M-409"}
const LIST_ITEM := "M-410"

var host: InteriorHost
var st: StoryState
var log_on := false
var _cart: Dictionary = {}                          ## 지금 맵의 수레 소품(런타임)
var _cd := 0.0                                      ## 다음 한 칸까지 남은 초
var _tween_t := 0.0
var _tween_from := Vector2.ZERO                     ## 옛 자리 − 새 자리(그림만 남은 거리)
var _tween_base := Vector2.ZERO                     ## 새 자리 그림 위치
var _riding := false
var _ride_v := 0.0                                  ## 칸/초
var _ride_acc := 0.0
var _braking := false
var _ride_dir := 1
var _ride_carry := false                            ## 맵 끝을 넘어 타고 들어온다
var _last_map := ""
var _last_near := false                             ## 지난 프레임 수레 곁이었나(맵을 넘을 때 수레를 데려간다)
var _stayers: Array = []                            ## 신길 · 여의나루 휴면 무리
var _carrier: Dictionary = {}                       ## 밤 운반조 {actors, prop, row, dir, x, stopped}
var _cluck_t := 0.0
var _last_tile := Vector2i(-999, -999)
var _run_tiles := 0                                 ## 진공관을 들고 뛴 칸
var _back_tiles := 0                                ## 대피민을 업고 걸은 칸
var _said := {}
var _listen_at := -99.0

signal want_save(why: String)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["u04"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.enemy_down.connect(_on_down)
	host.interact_pre.append(_pre_interact)
	host.interact_post.append(_post_interact)
	host.combat.pc.hit.connect(_on_pc_hit)


func v(k: String) -> int:
	return int(st.vars.get_v("U04_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("U04_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[U04] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func _hour() -> int:
	return int(TimeOfDay.minute(host.date_text) / 60)


func _say_once(k: String, s: String, t := 4.0) -> void:
	if _said.has(k):
		return
	_said[k] = true
	host.hint(s, t)


# ---------------------------------------------------------------- 수레(사실: CART_MAP · CART_X · CART_LOAD)
func cart_map() -> String:
	return MAPS[maxi(1, v("CART_MAP"))]


func cart_x() -> int:
	return v("CART_X") if v("CART_MAP") > 0 else 3                 # 차고: 차막이(1) 앞 한 칸 비워 밀 자리


func _here() -> bool:
	return RAIL.has(_mid()) and cart_map() == _mid()


func _row() -> int:
	return int(RAIL.get(_mid(), 0))


## 수레 소품을 지금 자리에 세운다(조사하면 수레 장면)
func _place_cart() -> void:
	_drop_cart()
	if not _here():
		return
	var c := Vector2i(cart_x(), _row())
	_cart = host.map.add_runtime_prop("rail_cart_ug", c)
	if _cart.is_empty():
		return
	if v("CART_LOAD") > 0:
		host.map.set_prop_state(c, "load")
	for i in 2:
		var cc := c + Vector2i(i, 0)
		host.map.texts[cc] = "운반조 레일 수레."
		host.map.text_meta[cc] = {"cond": "", "seq": [], "scene": "U04_CART", "key": "u04cart", "plain": ""}
	_near_flags()


func _drop_cart() -> void:
	if _cart.is_empty():
		return
	for cc in _cart.get("cells", []):
		host.map.texts.erase(cc)
		host.map.text_meta.erase(cc)
	if host.map != null:
		host.map.remove_runtime_prop(_cart)
	_cart = {}


func _near_flags() -> void:
	var x := cart_x()
	_sv("CART_NEAR", 1 if _mid() == SINGIL and x >= 44 and x <= 65 else 0)
	var s: Array = SLOPE.get(_mid(), [])
	var p: Vector2i = host.map.tile_of(host.player.loco.logical)
	_sv("RIDE", 1 if not s.is_empty() and x >= int(s[0]) and x <= int(s[1]) - 2 and absi(p.y - _row()) <= 1 and absi(p.x - x) <= 3 else 0)


## 한 칸 민다(d = ±1). 앞 칸이 막혔으면 false
func _step(d: int, ride := false) -> bool:
	var x := cart_x()
	var lead := x + 2 if d > 0 else x - 1
	var row := _row()
	if lead < 0 or lead >= int(WID[_mid()]):
		return false
	if not _free(Vector2i(lead, row)):
		return false
	var p: Vector2i = host.map.tile_of(host.player.loco.logical)
	if not ride and p == Vector2i(lead, row):
		return false
	_sv("CART_X", x + d)
	if v("CART_MAP") == 0:
		_sv("CART_MAP", MAPS.find(_mid()))
	var old: Vector2 = _cart["node"].position if not _cart.is_empty() and is_instance_valid(_cart.get("node")) else Vector2.ZERO
	_place_cart()
	if not ride and not _cart.is_empty() and is_instance_valid(_cart.get("node")):
		_tween_base = _cart["node"].position
		_tween_from = old - _tween_base if old != Vector2.ZERO else Vector2.ZERO
		_cart["node"].position = _tween_base + _tween_from
		_tween_t = 1.0
	else:
		_tween_t = 0.0
	var nl := x + d + 1 if d > 0 else x + d
	if posmod(nl, JOINT) == 0:
		_clack(nl, d, ride)
	return true


func _free(c: Vector2i) -> bool:
	if host.map.is_solid(c):
		return false
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and host.map.tile_of(e.loco.logical) == c:
			return false
	return true


## 이음매 덜컹: 레일을 타고 앞 무리를 먼저 깨운다
func _clack(at: int, d: int, ride := false) -> void:
	var loud := 0.35 if v("CLOTH") == 1 else 1.0
	if ride:
		loud *= 1.6
	if v("CART_LOAD") == 8:
		loud *= 1.2                                                  # 무거운 짐 — 바퀴가 더 세게 친다
	var rows := 6 if v("CLOTH") == 0 else (3 if ride else 1)          # 천을 감으면 소리가 레일 곁을 못 벗어난다(신길 승강장 줄은 두 줄 위)
	var woke := _wake_along(at, d, int(R_AHEAD * loud), R_BACK, rows)
	if woke > 0:
		host.hint("덜컹 — 레일이 운다. %s 어둠에서 여럿이 일어나는 소리." % ("저 앞" if v("CLOTH") == 0 else "가까운"), 3.5)
		if _mid() == SINGIL:
			_sv("LOUD", 1)                                           # 신길을 깨웠다(반장이 안다 — 소리가 넘어온다)
		_log("덜컹 %d → %d 깸" % [at, woke])
	if v("CLOTH") == 1:                                              # 천은 닳는다(이음매 스물 · 타면 두 배)
		_sv("WEAR", v("WEAR") + (2 if ride else 1))
		if v("WEAR") >= CLOTH_LIFE:
			_sv("CLOTH", 0)
			_sv("WEAR", 0)
			host.hint("바퀴 천이 닳아 풀려 나간다 — 이제 덜컹이 그대로 운다.", 4.0)
	if v("CART_LOAD") == 6 and (v("CLOTH") == 0 or ride):
		_sv("JOB_DMG", v("JOB_DMG") + 1)
		if v("JOB_DMG") == 3:
			host.hint("상자 안에서 유리 깨지는 소리. 진공관 몇 알이 갔다.", 3.0)
	if v("CART_LOAD") == 10 and v("CLOTH") == 0 and randf() < 0.5:
		_ghoul_wakes()
	if v("CLOTH") == 0 or ride:
		_noise_near_yd()


## 레일을 타고 번지는 소리: at에서 진행 방향 d로 ahead칸 · 반대로 back칸, 레일 줄에서 rows줄 안의 잠든 적을 깨운다. 깬 수
func _wake_along(at: int, d: int, ahead: int, back: int, rows: int) -> int:
	var woke := 0
	for e in host.combat.enemies:
		if not is_instance_valid(e) or e.cmb.dead or not e.asleep:
			continue
		var t: Vector2i = host.map.tile_of(e.loco.logical)
		if absi(t.y - _row()) > rows:
			continue
		var dx := t.x - at
		if (d != 0 and signi(dx) == d and absi(dx) <= ahead) or absi(dx) <= back:
			e.wake()
			e.brain.gauge = AIBrain.DETECT_AT * 0.7
			e.brain.last_seen = Vector2(at * 32 + 16, _row() * 32 + 16)
			woke += 1
	return woke


## 내 소리가 여의도 배전실에 닿았다 — 만난 적 있는 우다현이 점검구를 서두른다(다음에 들면 점검구 앞 지뢰)
func _noise_near_yd() -> void:
	if _mid() == YD and v("WOO") == 1 and v("HATCH") == 0 and v("RUSH") == 0:
		_sv("RUSH", 1)
		host.hint("배전실 쪽에서 우다현의 목소리: '…누구야? 서둘러, 점검구부터!'", 4.0)


## 닭이 운다 — 바퀴와 상관없이 앞뒤로 멀리(수레 위든 손이든)
func _cluck(at: int) -> void:
	var n := _wake_along(at, 1, 24, 24, 6)
	host.hint("닭 상자 안에서 꼬끼오 — 소리가 레일을 따라 멀리 간다." + (" 어둠에서 무언가 일어난다." if n > 0 else ""), 3.0)


## 잠든 대피민을 실었는데 덜컹에 깼다
func _ghoul_wakes() -> void:
	_sv("CART_LOAD", 0)
	_sv("GHOUL", 0)
	var pos := Vector2(cart_x() * 32 + 16, (_row() - 1) * 32 + 16)
	var e: Enemy = host.combat.spawn("CR-204", pos, host.map, st, {"sheet": S_SHEETS[0], "dir": "S", "lv": 4, "arm": "claw"})
	e.brain.gauge = AIBrain.DETECT_AT
	e.brain.last_seen = host.player.loco.logical
	_place_cart()
	host.hint("덜컹 — 수레 위의 사람이 눈을 번쩍 뜬다. 번호표를 쥔 손이 이쪽으로 뻗는다.", 4.0)


# ---------------------------------------------------------------- 매 프레임: 밀기 · 타기 · 운반조 · 닭
func _process(dt: float) -> void:
	if host == null or host.map == null or not RAIL.has(_mid()):
		return
	if _tween_t > 0.0 and not _cart.is_empty() and is_instance_valid(_cart.get("node")):
		_tween_t = maxf(0.0, _tween_t - dt / _push_secs())
		_cart["node"].position = _tween_base + _tween_from * _tween_t   # 옛 자리에서 새 자리로 미끄러짐 없이 한 칸(바퀴가 구른다)
	_carry_tick()
	_carrier_tick(dt)
	if host.box.active or host.container != null:
		return
	if _riding:
		_ride_tick(dt)
		return
	_cd = maxf(0.0, _cd - dt)
	if _here():
		var p: Vector2i = host.map.tile_of(host.player.loco.logical)
		_last_near = absi(p.y - _row()) <= 1 and absi(p.x - cart_x()) <= 3
		var mv: Vector2 = host.last_move
		if _cd <= 0.0 and p.y == _row() and absf(mv.x) > 0.5 and absf(mv.y) < 0.5:
			var d := signi(int(signf(mv.x)))
			if (d > 0 and p.x == cart_x() - 1) or (d < 0 and p.x == cart_x() + 2):
				if _step(d):
					_cd = _push_secs()
					_say_once("push", "수레를 민다. 바퀴가 이음매를 칠 때마다 덜컹 — 소리는 레일을 타고 앞으로 간다.", 4.0)
		_near_flags()
	else:
		_last_near = false
	var p2: Vector2i = host.map.tile_of(host.player.loco.logical)
	var hen_cart := v("CART_LOAD") == 7 and _here()
	var hen_hand := int(st.items.get("M-407", 0)) > 0
	if hen_cart or hen_hand:
		_cluck_t += dt
		if _cluck_t > 25.0:
			_cluck_t = 0.0
			if randf() < 0.5:
				_cluck(cart_x() if hen_cart else p2.x)
	if p2 != _last_tile:                                             # 손짐 · 업은 사람: 걸음마다 판정(수레보다 손이 늘 낫지 않게)
		if _last_tile != Vector2i(-999, -999) and (p2 - _last_tile).length() < 3.0:
			_hand_step()
		_last_tile = p2


func _push_secs() -> float:
	var t := 0.26
	if v("CLOTH") == 1:
		t = 0.42
	if v("CART_LOAD") == 8:
		t *= 1.5
	return t


## 한 칸 걸었다: 진공관을 들고 뛰면 깨지고(열 칸마다) · 업은 사람은 스무 칸마다 뒤척인다(은신으로 버틴다)
func _hand_step() -> void:
	if int(st.items.get("M-406", 0)) > 0 and v("JOB") == 6 and host.player.mode == "run":
		_run_tiles += 1
		if _run_tiles >= 10:
			_run_tiles = 0
			_sv("JOB_DMG", v("JOB_DMG") + 1)
			_say_once("tube_run", "상자 안에서 유리 부딪는 소리 — 들고 뛰면 진공관이 깨진다.", 3.5)
	if v("GHOUL") == 2:
		_back_tiles += 1
		if _back_tiles >= 20:
			_back_tiles = 0
			if randf() < 0.15:
				if randf() * 100.0 > float(st.skill("SNEAK")):
					_back_wakes()
				else:
					host.hint("등의 사람이 뒤척인다. 숨을 죽이고 멈춰 서자 다시 잠든다.", 3.0)


## 업은 대피민이 깼다 — 등에서 내려 덤빈다(모시기 실패)
func _back_wakes() -> void:
	_sv("GHOUL", 0)
	var e: Enemy = host.combat.spawn("CR-204", host.player.loco.logical + Vector2(0, 32), host.map, st, {"sheet": S_SHEETS[0], "dir": "N", "lv": 4, "arm": "claw"})
	e.brain.gauge = AIBrain.DETECT_AT
	e.brain.last_seen = host.player.loco.logical
	host.hint("등의 사람이 눈을 번쩍 뜬다. 어깨를 할퀴며 내려선다.", 4.0)


## 진공관을 든 채 맞았다
func _on_pc_hit() -> void:
	if int(st.items.get("M-406", 0)) > 0 and v("JOB") == 6:
		_sv("JOB_DMG", v("JOB_DMG") + 1)


## 손에 든 짐 · 업은 사람: 걸음이 무겁다(이 던전 맵 안에서만 정한다)
func _carry_tick() -> void:
	var mul := 1.0
	if int(st.items.get("M-408", 0)) > 0:
		mul = 0.6
	elif int(st.items.get("M-406", 0)) + int(st.items.get("M-407", 0)) + int(st.items.get("M-409", 0)) > 0:
		mul = 0.85
	if v("GHOUL") == 2:
		mul = minf(mul, 0.7)
	host.carry_mul = mul


# ---------------------------------------------------------------- 타기(내리막)
func ride() -> void:
	if v("RIDE") == 0 or not _here():
		return
	_riding = true
	_ride_dir = 1
	_ride_v = 1.0
	_ride_acc = 0.0
	_braking = false
	_seat_player()
	host.hint("수레에 올라탄다. 레일이 아래로 기운다 — 조사 키 = 브레이크.", 3.5)


func _seat_player() -> void:
	host.player.loco.place(Vector2(cart_x() * 32 + 32, _row() * 32 + 10))
	host.player.set_pose("sit")


func _ride_tick(dt: float) -> void:
	var s: Array = SLOPE.get(_mid(), [])
	var on_slope := not s.is_empty() and cart_x() >= int(s[0]) and cart_x() <= int(s[1])
	if _braking:
		_ride_v -= (3.5 if v("CART_LOAD") == 8 else 6.0) * dt
	elif on_slope:
		_ride_v += 1.8 * dt
	else:
		_ride_v -= (STATION_FRIC if _mid() == YD or _mid() == NARU else FLAT_FRIC) * dt   # 평지 — 쇠바퀴는 멀리 구른다(역은 더 멀리)
	_ride_v = clampf(_ride_v, 0.0, 9.0)
	_ride_acc += _ride_v * dt
	while _ride_acc >= 1.0:
		_ride_acc -= 1.0
		var x := cart_x()
		if _ride_dir > 0 and x + 2 >= int(WID[_mid()]) and NEXT[_mid()].has("E"):
			_carry_to(NEXT[_mid()]["E"], true)                          # 맵 끝 — 탄 채로 다음 맵
			return
		if not _step(_ride_dir, true):
			_crash()
			return
		_seat_player()
	if _ride_v <= 0.05 and not on_slope:
		_stop_ride("수레가 멎는다. 내려선다.")
	elif _ride_v <= 0.05 and _braking:
		_stop_ride("브레이크가 끼익 — 수레가 선다. 내려선다.")


func _crash() -> void:
	if v("CART_LOAD") == 6:
		_sv("JOB_DMG", v("JOB_DMG") + 2)
	var lead := Vector2i(cart_x() + 2 if _ride_dir > 0 else cart_x() - 1, _row())
	if _mid() == YD and lead == SANDBAG and v("ENG") == 0 and v("RAM") < 3:
		_ram()
		return
	if _mid() == NARU:
		if v("CART_LOAD") == 10:
			_ghoul_wakes()                                           # 실린 사람이 깬다
		elif v("CART_LOAD") == 7:
			_cluck(cart_x())                                         # 닭이 놀라 운다
		_stop_ride("쿵! 차막이에 받혀 수레가 선다." + (" 전지 상자가 차막이를 넘을 뻔했다." if v("CART_LOAD") == 8 else ""))
		return
	for e in host.combat.enemies:                                    # 앞을 막은 적만 작게 다친다(§16.7 #5 — 사람 · 운반조 · 공병 인물은 레일 위에 서면 수레가 먼저 선다)
		if is_instance_valid(e) and not e.cmb.dead and host.map.tile_of(e.loco.logical) == lead:
			e.cmb.last_by = "player"
			e.cmb.take({"hp": 6.0 + _ride_v * 2.0}, Vector2(lead.x * 32 + 16, lead.y * 32 + 16))
	_stop_ride("쿵! 수레가 무언가에 받혀 선다. 몸이 앞으로 튕긴다.")


## 공병 모래주머니를 들이받았다: 공병이 화내고(BJ −2) · 우다현이 서두르고 · 셋째면 터져 수레 길이 난다(총 말고 수레 — 계엄 적대여도 되는 둘째 해법)
func _ram() -> void:
	_sv("RAM", v("RAM") + 1)
	if v("CART_LOAD") == 8 and _ride_v >= 7.0:
		_sv("RAM", 3)                                                # 전지를 싣고 빠르게 — 한 번에 터진다(대신 전지가 찌그러져 운임 −20)
		_sv("JOB_DMG", v("JOB_DMG") + 1)
	st.call_fn("aff", ["BJ", -2])
	_noise_near_yd()
	if v("RAM") >= 3:
		_lift_line()
		_stop_ride("쿵! 모래주머니가 터져 레일 위로 쏟아진다 — 수레 길이 났다. 초소에서 욕설.")
	else:
		_stop_ride("쿵! 모래주머니가 출렁인다. 초소에서: '누가 수레를 굴렸어!'")


func _stop_ride(msg: String) -> void:
	_riding = false
	_braking = false
	_ride_v = 0.0
	host.player.set_pose("stand")
	var back := Vector2i(cart_x() - 1, _row())
	if host.map.is_solid(back):
		back = Vector2i(cart_x(), _row() - 1)
	host.player.loco.place(Vector2(back.x * 32 + 16, back.y * 32 + 16))
	host.hint(msg, 3.0)


func _pre_interact() -> bool:
	if _riding:
		_braking = true
		host.hint("브레이크 손잡이를 당긴다. 쇠 긁히는 소리.", 2.0)
		return true
	return false


# ---------------------------------------------------------------- 맵을 넘을 때 수레를 데려간다
func _carry_to(to: String, riding: bool) -> void:
	var from := _mid()
	var side := "W" if NEXT.get(to, {}).get("W", "") == from else "E"
	var nx := 3 if side == "W" else int(WID[to]) - 6
	_sv("CART_MAP", MAPS.find(to))
	_sv("CART_X", nx)
	_ride_carry = riding
	_riding = false
	host.player.set_pose("stand")
	host.enter.call_deferred(to, "from_W" if side == "W" else "from_E")


## 수레 곁에서 맵 끝 출구로 걸어 나갔다 — 수레가 맵 끝에 붙어 있었으면 같이 넘어간다
func _maybe_follow(prev: String, now: String) -> void:
	if prev == "" or prev == now or not RAIL.has(prev) or not RAIL.has(now) or cart_map() != prev or not _last_near:
		return
	var x := cart_x()
	var w := int(WID[prev])
	var to_e: bool = NEXT[prev].get("E", "") == now
	var to_w: bool = NEXT[prev].get("W", "") == now
	if (to_e and x >= w - 5) or (to_w and x <= 3):
		_sv("CART_MAP", MAPS.find(now))
		_sv("CART_X", 3 if to_e else int(WID[now]) - 6)
		_log("수레가 따라 넘어감 %s → %s" % [prev, now])


# ---------------------------------------------------------------- 귀 대기 · 두드림
func _post_interact() -> bool:
	if not RAIL.has(_mid()) or _riding:
		return false
	var p: Vector2i = host.map.tile_of(host.player.loco.logical)
	if absi(p.y - _row()) > 1 and absi(p.y - int(ALT[_mid()])) > 1:
		return false
	if _here() and absi(p.y - _row()) <= 1 and p.x >= cart_x() - 1 and p.x <= cart_x() + 2:
		host.play_scene("U04_CART")                                  # 수레 바로 곁 — 앞 칸 판정이 칸 끝에서 빗나가도 수레를 잡는다
		return true
	var now := Time.get_ticks_msec() / 1000.0
	if now - _listen_at < 2.0:                                       # 2초 안에 한 번 더 — 막대를 든다(두드림 메뉴)
		_listen_at = -99.0
		host.play_scene("U04_RAIL")
		return true
	_listen_at = now                                                 # 레일 곁 빈 조사 = 바로 귀 대기(메뉴 없음 · 휴대폰에서 잘못 눌러도 가볍게)
	listen()
	return true


func _dist_word(n: int) -> String:
	if n < 8:
		return "바로 앞"
	if n < 20:
		return "가깝게"
	if n < 45:
		return "멀리"
	return "아주 멀리"


func listen() -> void:
	_sv("HEARD", 1)
	var p: Vector2i = host.map.tile_of(host.player.loco.logical)
	var near: Array = []                                             # [거리, 글] — 이 맵 소리
	var far: Array = []                                              # 맵 너머 소리(레일이 나른다)
	var asleep := {}
	var awake := {}
	for e in host.combat.enemies:
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		var t: Vector2i = host.map.tile_of(e.loco.logical)
		var key := "동쪽" if t.x > p.x else "서쪽"
		var dd := absi(t.x - p.x)
		var bag: Dictionary = asleep if e.asleep else awake
		if not bag.has(key) or int(bag[key]) > dd:
			bag[key] = dd
	for k in asleep:
		near.append([int(asleep[k]), "%s %s — 여럿이 잠든 숨" % [k, _dist_word(int(asleep[k]))]])
	for k in awake:
		near.append([int(awake[k]), "%s %s — 끄는 발소리" % [k, _dist_word(int(awake[k]))]])
	if not _carrier.is_empty():
		var cx := int(_carrier["x"])
		near.append([absi(cx - p.x), "%s %s — 천 감은 수레 바퀴 · 두드림 둘" % ["동쪽" if cx > p.x else "서쪽", _dist_word(absi(cx - p.x))]])
	if _mid() == YD and v("ENG") == 0 and v("RAM") < 3 and int(st.vars.get_v("AFF_BJ")) > -60:
		near.append([absi(40 - p.x), "동쪽 %s — 레일 위 모래주머니, 쇠 부딪는 소리(사람 셋)" % _dist_word(absi(40 - p.x))])
	match _mid():
		"U4-01":
			if v("SK") != 63:
				far.append("동쪽 아주 멀리 — 신길 쪽, 여럿이 숨 쉰다")
		"U4-03":
			if v("SK") != 63:
				far.append("서쪽 아주 멀리 — 신길 쪽, 여럿이 숨 쉰다")
			if v("LIST") < 3 and v("QK") != 1023:
				far.append("동쪽 아주 멀리 — 깊은 데서, 줄 선 사람들의 숨")
		"U4-04":
			if v("LIST") < 3 and v("QK") != 1023:
				far.append("동쪽 멀리 — 줄 선 사람들의 숨, 물소리")
	if _hour() >= 21 and _hour() <= 23 and v("CARR_DAY") != day() and (_mid() == "U4-02" or _mid() == "U4-04"):
		far.insert(0, "%s 아주 멀리 — 수레 바퀴, 쇠 두드림 둘(운반조가 온다)" % ("동쪽" if _carrier_dir() < 0 else "서쪽"))
	near.sort_custom(func(a, b): return int(a[0]) < int(b[0]))
	var lines: Array = []
	for i in mini(2, near.size()):                                   # 가까운 소리 둘 + 맵 너머 하나(한눈에)
		lines.append(str(near[i][1]))
	if not far.is_empty():
		lines.append(str(far[0]))
	if lines.is_empty():
		lines.append("레일이 조용하다. 아주 멀리 물 떨어지는 소리뿐")
	host.hint("레일에 귀를 댄다 — " + " · ".join(lines), 6.0)
	_say_once("tap_tip", "(조사 키를 한 번 더 — 막대로 레일을 두드린다)", 3.0)
	_log("귀 대기: " + " / ".join(lines))


func tap(code: String) -> void:
	_sv("TAP", {"2": 2, "3": 3, "L": 1, "L2": 12, "4": 4}.get(code, 0))
	var p: Vector2i = host.map.tile_of(host.player.loco.logical)
	match code:
		"4":
			var n := 0
			for e in host.combat.enemies:
				if is_instance_valid(e) and not e.cmb.dead and e.asleep and host.map.tile_of(e.loco.logical).distance_to(p) <= 15.0:
					e.wake()
					e.brain.gauge = AIBrain.DETECT_AT * 0.7
					e.brain.last_seen = host.player.loco.logical
					n += 1
			host.hint("막대가 레일을 마구 친다. 쇠 소리가 터널 끝까지 번진다." + (" 가까운 어둠에서 줄 선 사람들이 일어난다." if n > 0 else ""), 4.0)
			if _mid() == YD and v("WOO") == 1 and v("HATCH") == 0 and v("RUSH") == 0:
				_sv("RUSH", 1)
		"L2":
			if _mid() == YD and v("ENG") == 0 and p.x >= 24 and p.x <= 39 and p.y >= 17:
				if int(st.vars.get_v("AFF_BJ")) > -60:
					_sv("ENG", 1)
					_lift_line()
					host.hint("초소 공병: '…운반조? 지나가.' 모래주머니 둘을 걷어 낸다.", 4.0)
				else:
					host.hint("초소 쪽에서 노리쇠 소리. '신호 따위로 안 속는다.'", 3.5)
			else:
				host.hint("레일이 길게 한 번, 짧게 두 번 운다. 대답은 없다.", 3.0)
		"2", "3", "L":
			if not _carrier.is_empty() and not bool(_carrier.get("passed", false)):
				if code == "2":
					_sv("YIELD", 1)
					carriers_pass()                                   # 말없이 비켜 가되 한 줄은 던진다
					if v("TAPJH") == 0:
						_sv("TAPJH", 1)
						st.call_fn("aff", ["JH", 1])
					host.hint("저 앞에서 두드림 둘이 대답한다. 수레가 옆 선로로 바퀴를 옮긴다. 지나가며 '말 아는 사람이네.'", 4.0)
				elif code == "3":
					_carrier["stopped"] = true                       # 그 자리에 서서 기다린다 — 다가가면(4칸) 무슨 일인지 묻는다
					_carrier["wait3"] = true
					host.hint("저 앞 수레가 끼익 선다. 랜턴이 이쪽을 비춘다 — 기다린다.", 3.5)
				else:
					_carrier["slow"] = true
					host.hint("저 앞에서 길게 한 번 대답. 수레가 천천히 다가온다.", 3.0)
			else:
				host.hint("레일이 운다. 대답은 없다.", 2.5)


func _lift_line() -> void:
	if host.map == null or _mid() != YD:
		return
	for pr in host.map.props.duplicate():
		if pr["name"] == "sandbags" and int(pr["x"]) == 40 and int(pr["y"]) in [18, 19] and pr.has("node"):
			pr["node"].visible = false
			for i in range(int(pr["y"]), int(pr["y"]) + int(pr.get("h", 1))):
				host.map._put_solid(40, i, 0)
	for c in [Vector2i(39, 18), Vector2i(39, 19)]:
		host.map.texts.erase(c)
		host.map.text_meta.erase(c)


# ---------------------------------------------------------------- 밤 운반조(터널 A · B, 22~23시 하룻밤 한 번 — 짝숫날 동 → 서 둘 · 홀숫날 서 → 동 셋)
func _carrier_dir() -> int:
	return -1 if day() % 2 == 0 else 1


func _carrier_start() -> void:
	if not _carrier.is_empty() or v("CARR_DAY") == day() or not (_mid() == "U4-02" or _mid() == "U4-04"):
		return
	if _hour() < 22 or _hour() > 23:
		return
	_sv("CARR_DAY", day())                                           # 하룻밤 한 번만 판정(매 프레임 다시 굴리지 않는다)
	if st.is_dead("N-UG-009") and randf() < 0.5:
		return                                                       # 반장이 없으면 운반조가 드문드문
	_sv("YIELD", 0)
	_sv("TAP", 0)
	var dir := _carrier_dir()
	_sv("CDIR", dir)
	var n := 2 if dir < 0 else 3
	var x := int(WID[_mid()]) - 3 if dir < 0 else 2
	var acts: Array = []
	for i in n:
		var a := Actor.new()
		a.setup(CARRIER_SHEETS[i % CARRIER_SHEETS.size()], Vector2((x - dir * i * 2) * 32 + 16, _row() * 32 + 16), host.map)
		a.mode = "walk"
		a._show()
		host.map.add_actor(a)
		acts.append(a)
	var pr: Dictionary = host.map.add_runtime_prop("rail_cart_ug", Vector2i(x + dir * 3, _row()))
	if not pr.is_empty():
		host.map.set_prop_state(Vector2i(x + dir * 3, _row()), "load")
		for cc in pr.get("cells", []):
			host.map._put_solid(cc.x, cc.y, 0)
	_carrier = {"actors": acts, "prop": pr, "row": _row(), "x": float(x), "dir": dir, "stopped": false, "slow": false, "passed": false}
	_log("밤 운반조 출발 %s(%s · %d)" % [_mid(), "동 → 서" if dir < 0 else "서 → 동", n])


func _carrier_tick(dt: float) -> void:
	_carrier_start()
	if _carrier.is_empty():
		return
	var acts: Array = _carrier["actors"]
	if acts.is_empty() or not is_instance_valid(acts[0]):
		_carrier = {}
		return
	var dir := int(_carrier["dir"])
	var p: Vector2i = host.map.tile_of(host.player.loco.logical)
	var lead: Actor = acts[0]
	var lx: int = host.map.tile_of(lead.loco.logical).x
	var ahead := (p.x - lx) * dir                                    # 진행 방향 앞으로 몇 칸
	if _riding and not bool(_carrier["passed"]) and int(_carrier["row"]) == _row():
		var gap := (lx - cart_x() - 1) * _ride_dir                    # 탄 수레 앞머리에서 운반조까지
		if gap > 0 and gap <= 6:
			_head_on()
			return
	elif bool(_carrier.get("wait3", false)) and absi(p.y - _row()) <= 2 and absi(p.x - lx) <= 4:
		_carrier["wait3"] = false                                     # '세 번'에 서서 기다리던 수레 — 다가가니 묻는다
		host.play_scene.call_deferred("U04_CARRIERS")
	elif not bool(_carrier["stopped"]) and not bool(_carrier["passed"]) and int(_carrier["row"]) == _row() \
			and absi(p.y - _row()) <= 1 and ahead > 0 and ahead <= 4:
		_carrier["stopped"] = true                                    # 레일 위에 사람 — 서서 레일 말을 가르친다(길게 한 번을 쳤으면 고맙다고)
		host.play_scene.call_deferred("U04_CARRIERS")
	var spd := 0.0 if bool(_carrier["stopped"]) else (1.2 if bool(_carrier["slow"]) else 2.0)
	for i in acts.size():
		var a: Actor = acts[i]
		if not is_instance_valid(a):
			continue
		var target_y := float(int(_carrier["row"]) * 32 + 16)
		var dy := target_y - a.loco.logical.y
		var mv := Vector2(float(dir) if spd > 0.0 else 0.0, clampf(dy / 16.0, -1.0, 1.0) if absf(dy) > 2.0 else 0.0)
		a.mode = "walk"
		a.move(mv * (spd / 2.0), dt)
	_carrier["x"] = float(host.map.tile_of(lead.loco.logical).x)
	var pr: Dictionary = _carrier["prop"]
	if not pr.is_empty() and is_instance_valid(pr.get("node")):
		pr["node"].position = lead.loco.logical + Vector2(dir * 80, -24)
	if (dir < 0 and lx <= 1) or (dir > 0 and lx >= int(WID[_mid()]) - 2):
		_carrier_end()


## 탄 채 마주 오는(또는 앞서 가는) 운반조 수레 코앞 — 빠르면 맞부딪치고, 브레이크를 잡았으면 끼익
func _head_on() -> void:
	if _ride_v >= 4.0:
		if v("CART_LOAD") == 6:
			_sv("JOB_DMG", v("JOB_DMG") + 2)
		if v("CART_LOAD") == 10:
			_ghoul_wakes()
		_sv("TAP", 9)
		st.call_fn("aff", ["JH", -3])
		_stop_ride("쿵! 두 수레가 맞부딪친다. 레일 옆으로 튕겨 내린다.")
	else:
		_sv("TAP", 8)
		_stop_ride("끼익 — 운반조 수레 코앞에서 선다.")
	_carrier["stopped"] = true
	_carrier["wait3"] = false
	host.play_scene.call_deferred("U04_CARRIERS")


## 서쪽으로 가는(짝숫날) 밤 수레에 얹혀 간다 — 한 시간 뒤 영등포시장 차고 앞(펌프 부품은 그 자리에서 반장에게)
func hitch() -> void:
	if _carrier.is_empty() or int(_carrier["dir"]) > 0:
		return
	_carrier_end()
	host.advance_minutes(60)
	if int(st.items.get("M-409", 0)) > 0 and not st.is_dead("N-UG-009"):
		back()
		host.hint("차고 앞에 내린다. 반장이 펌프 부품을 받아 간다. 운임 %d캡." % BACK_PAY, 4.0)
	else:
		host.hint("한 시간 흔들린 끝에 영등포시장 차고 앞에 내린다.", 3.5)
	host.enter.call_deferred("U4-01", "garage")


func carriers_pass() -> void:
	if _carrier.is_empty():
		return
	_carrier["row"] = int(ALT[_mid()])
	_carrier["stopped"] = false
	_carrier["passed"] = true


## 밤 운반조에게 펌프 부품을 맡긴다 — 반장에게 갖다 준다(운임 반 · 귀환 걸음을 덜어 준다)
func parcel() -> void:
	if int(st.items.get("M-409", 0)) == 0:
		return
	st.call_fn("take", ["M-409", 1])
	st.call_fn("caps", [BACK_PAY / 2])
	st.call_fn("aff", ["JH", 1])
	_sv("JOB", 0)


func _carrier_end() -> void:
	for a in _carrier.get("actors", []):
		if is_instance_valid(a):
			host.map.remove_actor(a)
			a.queue_free()
	var pr: Dictionary = _carrier.get("prop", {})
	if not pr.is_empty():
		pr["cells"] = []
		host.map.remove_runtime_prop(pr)
	_carrier = {}


# ---------------------------------------------------------------- 운송(소민서 → 기건희)
func job(n: int) -> void:
	if v("JOB") != 0 or not CARGO.has(n):
		return
	_sv("JOB", n)
	_sv("JOB_DMG", 0)
	_sv("JOB_DAY", day())
	st.call_fn("give", [CARGO[n], 1])


func load_cart() -> void:
	if v("CART_LOAD") != 0:
		return
	for n in [6, 7, 8, 9]:
		if int(st.items.get(CARGO[n], 0)) > 0:
			st.call_fn("take", [CARGO[n], 1])
			_sv("CART_LOAD", n)
			_place_cart()
			return


func unload() -> void:
	var n := v("CART_LOAD")
	if not CARGO.has(n):
		return
	st.call_fn("give", [CARGO[n], 1])
	_sv("CART_LOAD", 0)
	_place_cart()


## 기건희에게 짐을 건넨다: 운임 · 운반조 인심 · 셋째에 쉼터 · 돌아오는 짐
func deliver() -> void:
	for n in [6, 7, 8]:
		if int(st.items.get(CARGO[n], 0)) > 0:
			st.call_fn("take", [CARGO[n], 1])
			var pay := int(PAY[n])
			if n == 6:
				pay = maxi(15, pay - 6 * maxi(0, v("JOB_DMG") - 2))
			if n == 8 and v("JOB_DMG") > 0:
				pay = maxi(10, pay - 20)                             # 들이받아 찌그러진 전지
			var late := day() - v("JOB_DAY") >= 3                    # 사흘 넘긴 '늦은 짐'(생포 압수 · 오래 둠) — 운임 절반
			if late:
				pay = pay / 2
			st.call_fn("caps", [pay])
			st.call_fn("xp", [15])
			st.call_fn("aff", ["JH", 1])
			_sv("RUN", v("RUN") + 1)
			_sv("RUN_DAY", day())
			_sv("JOB", 9)
			st.call_fn("give", ["M-409", 1])
			var msg := "기건희가 짐을 받는다. '%s' 운임 %d캡. 돌아가는 길에 펌프 부품 꾸러미를 들려 보낸다." % [
				"늦었네. 사흘이면 반값이야." if late else ("알이 몇 개 갔네." if n == 6 and v("JOB_DMG") > 2 else "멀쩡하네."), pay]
			if v("RUN") == 3:
				msg += " 대합실 구석에 운반조가 화로를 들여놓는다 — 쉼터다."
			host.hint(msg, 6.0)
			want_save.emit("u04_run")
			return


func back() -> void:
	if int(st.items.get("M-409", 0)) == 0:
		return
	st.call_fn("take", ["M-409", 1])
	st.call_fn("caps", [BACK_PAY])
	st.call_fn("xp", [10])
	_sv("JOB", 0)


## 받을 사람(기건희)이 죽었다 — 짐을 도로 돌려준다(운임 없음 · 수레 짐도). 반쯤 된 상태 없음(P10)
func cancel() -> void:
	for n in [6, 7, 8]:
		if int(st.items.get(CARGO[n], 0)) > 0:
			st.call_fn("take", [CARGO[n], 1])
	if CARGO.has(v("CART_LOAD")) and v("CART_LOAD") != 9:
		_sv("CART_LOAD", 0)
		if _here():
			_place_cart()
	_sv("JOB", 0)
	_sv("JOB_DMG", 0)


func where() -> void:
	var names := {"U4-01": "영등포시장역 승강장", "U4-02": "터널 A", "U4-03": "여의도역 승강장", "U4-04": "터널 B", "U4-05": "여의나루 선로 끝"}
	var m := cart_map()
	var extra := ""
	if m == "U4-02" and cart_x() >= 44 and cart_x() <= 66:
		extra = "(신길 승강장 앞)"
	host.hint("소민서: '수레? 마지막으로 본 게 %s%s. 레일 거니까 레일에 있겠지.'" % [names.get(m, "차고"), extra], 4.0)


func cart_info() -> void:
	var load := {0: "빈 수레", 6: "진공관 상자", 7: "닭 상자", 8: "전지 상자", 9: "펌프 부품 꾸러미", 10: "잠든 대피민 한 사람"}
	host.hint("운반조 레일 수레 — %s · 바퀴 천 %s. (걸어 들어가면 민다)" % [load.get(v("CART_LOAD"), "?"), "감음" if v("CLOTH") == 1 else "없음"], 4.0)
	_near_flags()


# ---------------------------------------------------------------- 신길 · 여의나루 무리 · 명단 · 모시기
func _spawn_groups() -> void:
	_stayers.clear()
	match _mid():
		SINGIL:
			for i in 6:
				if v("SK") & (1 << i):
					continue
				var e: Enemy = host.combat.spawn("CR-204", host.map.mark_pos("s%d" % (i + 1)), host.map, st,
					{"sheet": S_SHEETS[i % 3], "dir": "S", "lv": 4, "arm": "claw", "doze": "sit"})
				e.set_meta("u04_s", i)
				e.wake_cb = _group_wake
				_stayers.append(e)
		NARU:
			if v("LIST") < 3:
				for i in 10:
					if v("QK") & (1 << i):
						continue
					var e2: Enemy = host.combat.spawn("CR-204", host.map.mark_pos("q%d" % (i + 1)), host.map, st,
						{"sheet": S_SHEETS[(i + 1) % 3], "dir": "N", "lv": 4, "arm": "claw", "doze": "sit"})
					e2.set_meta("u04_q", i)
					e2.wake_cb = _group_wake
					_stayers.append(e2)
			if v("GHOUL") == 3:                                          # 0398번 — 대기 줄 빈자리에 앉아 잔다(덤비지 않는다)
				var e3: Enemy = host.combat.spawn("CR-204", host.map.mark_pos("seat"), host.map, st,
					{"sheet": S_SHEETS[0], "dir": "N", "lv": 4, "arm": "claw", "doze": "sit", "team": "calm_u4", "foes": []})
				e3.set_meta("u04_seat", 1)
		"U4-04":
			if v("LIST") == 3 and v("SCATTER") == 0:                     # 흩어진 대기 줄 몇이 터널에 남았다(명단의 값)
				for i in 2:
					var e4: Enemy = host.combat.spawn("CR-204", Vector2((30 + i * 22) * 32 + 16, 9 * 32 + 16), host.map, st,
						{"sheet": S_SHEETS[i % 3], "dir": "W", "lv": 4, "arm": "claw", "doze": "stand"})
					e4.set_meta("u04_w", i)


## 한 사람이 깨면 같은 줄이 함께 일어난다
func _group_wake(e: Enemy) -> void:
	for o in _stayers:
		if is_instance_valid(o) and o != e and o.asleep:
			o.wake()


func wake_group() -> void:
	for o in _stayers:
		if is_instance_valid(o) and o.asleep:
			o.wake()
			o.brain.gauge = AIBrain.DETECT_AT * 0.8
			o.brain.last_seen = host.player.loco.logical


func ghoul_lift() -> void:
	if v("CART_LOAD") != 0 or _mid() != SINGIL or v("GHOUL") != 0:
		return                                                       # 대기 줄 빈자리는 하나 — 모신 사람이 있으면 더 눕히지 않는다
	var best = null
	var bd := 1e9
	for o in _stayers:
		if is_instance_valid(o) and o.asleep and o.has_meta("u04_s"):
			var d: float = o.loco.logical.distance_to(Vector2(cart_x() * 32 + 32, _row() * 32))
			if int(o.get_meta("u04_s")) == 5:
				d -= 1e6                                             # 0398번(대기 줄 빈자리의 주인)이 아직 자면 그 사람부터
			if d < bd:
				bd = d
				best = o
	if best == null:
		return
	_sv("SK", v("SK") | (1 << int(best.get_meta("u04_s"))))
	_sv("GNO", int(best.get_meta("u04_s")))
	_stayers.erase(best)
	host.combat.drop_enemy(best)
	_sv("CART_LOAD", 10)
	_sv("GHOUL", 1)
	_place_cart()
	_check_clear()


func ghoul_carry() -> void:
	if v("CART_LOAD") != 10:
		return
	_sv("CART_LOAD", 0)
	_sv("GHOUL", 2)
	_place_cart()


func seat() -> void:
	if v("GHOUL") != 2:
		return
	_sv("GHOUL", 3)
	st.call_fn("karma", [10])
	st.call_fn("xp", [40])
	if _mid() == NARU:
		var e: Enemy = host.combat.spawn("CR-204", host.map.mark_pos("seat"), host.map, st,
			{"sheet": S_SHEETS[0], "dir": "N", "lv": 4, "arm": "claw", "doze": "sit", "team": "calm_u4", "foes": []})
		e.set_meta("u04_seat", 1)
	want_save.emit("u04_seat")


func list_take() -> void:
	if v("LIST") != 0:
		return
	_sv("LIST", 1)
	st.call_fn("give", [LIST_ITEM, 1])


func list_give() -> void:
	if int(st.items.get(LIST_ITEM, 0)) == 0 or v("LIST") >= 2:
		return
	st.call_fn("take", [LIST_ITEM, 1])
	_sv("LIST", 2)
	_sv("LIST_DAY", day())
	st.call_fn("karma", [10])
	st.call_fn("xp", [50])
	st.vars.set_v("NS_COOP", int(st.vars.get_v("NS_COOP")) + 1)        # 남산 방송 협력(SD-06 NS 협력) — 다음 날 06:00 낭독(radio.txt N-U04-L)


func _on_down(e: Enemy) -> void:
	if e.has_meta("u04_s"):
		_sv("SK", v("SK") | (1 << int(e.get_meta("u04_s"))))
	elif e.has_meta("u04_q"):
		_sv("QK", v("QK") | (1 << int(e.get_meta("u04_q"))))
	elif e.has_meta("u04_w"):
		_sv("SCATTER", 1)
	else:
		return
	_check_clear()


func _check_clear() -> void:
	if v("CLEAR") == 0 and v("SK") == 63 and (v("QK") == 1023 or v("LIST") == 3):
		_sv("CLEAR", 1)
		_log("정리 — 신길 · 여의나루 무리가 더는 없다")


# ---------------------------------------------------------------- 하루 판정 · 맵
func _on_day(d: int) -> void:
	if CARGO.has(v("CART_LOAD")) and v("CART_LOAD") != 9 and v("JOB") == v("CART_LOAD") and d - v("JOB_DAY") >= 3:
		_sv("CART_LOAD", 0)                                          # 수레에 실은 채 사흘 — 운반조가 짐과 수레를 차고로 거둬 간다(운임 없음 · §16.7 #3)
		_sv("JOB", 0)
		_sv("CART_MAP", 1)
		_sv("CART_X", 3)
		_sv("BACK", 1)
		if RAIL.has(_mid()):
			_place_cart()
		_log("버려둔 짐 — 운반조가 수레째 회수")
	if v("CART_LOAD") == 0 and v("RUN") >= 1 and (v("CART_MAP") == 4 or v("CART_MAP") == 5) and _mid() != cart_map():
		_sv("CART_MAP", 1)                                           # 짐을 넘긴 뒤 여의나루 쪽에 둔 빈 수레 — 밤 운반조 편에 매달려 차고로(귀환 걸음을 덜어 준다)
		_sv("CART_X", 3)
		_sv("BACK", 2)
		if RAIL.has(_mid()):
			_place_cart()
	if v("LIST") == 2 and d > v("LIST_DAY"):
		_sv("LIST", 3)                                               # 다음 06:00 남산이 명단을 읽는다 → 대기 줄이 흩어진다
		_check_clear()
		_log("남산 낭독 — 대기 줄 흩어짐")


func _on_map(id: String) -> void:
	_maybe_follow(_last_map, id)
	_last_map = id
	_last_tile = Vector2i(-999, -999)
	_drop_cart_ref()
	if not _carrier.is_empty():
		_carrier = {}
	if not RAIL.has(id):
		if v("GHOUL") == 2:                                          # 지하 밖으로 업고 나왔다 — 바깥 바람에 깨어 어둠 쪽으로 달아난다
			_sv("GHOUL", 0)
			host.hint("등의 사람이 바깥 바람에 몸을 비튼다. 내려서더니 비틀비틀 계단 아래 어둠으로 돌아간다.", 4.5)
		if host.carry_mul != 1.0 and _was_u04:
			host.carry_mul = 1.0
		_was_u04 = false
		return
	_was_u04 = true
	_spawn_groups()
	_place_cart()
	if id == YD:
		if v("ENG") == 1 or v("RAM") >= 3:
			_lift_line()
		if int(st.vars.get_v("UQ06_RESULT")) == 1:
			host.map.set_prop_state(Vector2i(21, 12), "close")       # 증권가 객장과 같은 회선 — 마감가(UQ-06 ①)
	if id == "U4-01" and int(st.vars.get_v("AFF_JH")) > -60:
		host.map.set_prop_state(Vector2i(36, 2), "up")
		for i in 2:
			host.map._put_solid(36 + i, 2, 0)
	elif id == "U4-01":
		host.map.set_prop_state(Vector2i(36, 2), "weld")
	if _ride_carry:
		_ride_carry = false
		_riding = true
		_ride_dir = 1
		_ride_v = maxf(_ride_v, 3.0)
		_seat_player()


var _was_u04 := false


func _drop_cart_ref() -> void:
	_cart = {}                                                       # 맵이 바뀌면 소품은 맵과 함께 사라졌다


# ---------------------------------------------------------------- 명령(@cmd u04 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"know":
			_sv("KNOW", 1)
		"cloth":
			_sv("CLOTH", int(a[1]))
			_sv("WEAR", 0)
		"job":
			job(int(a[1]))
		"back":
			back()
		"cancel":
			cancel()
		"parcel":
			parcel()
		"hitch":
			hitch()
		"lost_parcel":
			if v("JOB") == 9 and int(st.items.get("M-409", 0)) == 0:
				_sv("JOB", 0)
		"wrap":
			if int(st.items.get("M-411", 0)) > 0 and v("CLOTH") == 0:
				st.call_fn("take", ["M-411", 1])
				_sv("CLOTH", 1)
				_sv("WEAR", 0)
		"where":
			where()
		"cart_info":
			cart_info()
		"load":
			load_cart()
		"unload":
			unload()
		"ride":
			ride()
		"ghoul_lift":
			ghoul_lift()
		"ghoul_carry":
			ghoul_carry()
		"seat":
			seat()
		"wake_s", "wake_q":
			wake_group()
		"listen":
			listen()
		"tap":
			tap(str(a[1]))
		"carriers_pass":
			carriers_pass()
		"woo_meet":
			if v("WOO") == 0:
				_sv("WOO", 1)
		"board":
			if v("WOO") < 2:
				_sv("WOO", 2)
				st.call_fn("aff", ["BJ", 3])
				st.call_fn("xp", [20])
		"hatch":
			_sv("HATCH", 1)
		"hatch_go":
			host.enter.call_deferred("Y-03", "from_U4")
		"hatch_up":
			host.enter.call_deferred(YD, "from_hatch")
		"deliver":
			deliver()
		"list_take":
			list_take()
		"list_give":
			list_give()
	done.call()
