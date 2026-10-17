## 구로 차량기지 던전 DG-GR 진행기(단계 1-D4, SD-09a L-R02-25 · SD-14 CR-205 · 1-D 계획 §10 · §10.7).
##   원고: script/act1/GR.txt. 맵: X-GR 구내(월드에 찍는 손 맵) · GR-01 수송 열차 · GR-02 정비고 · GR-03 떠돌이 전동차 · GR-04 정비 대기 객차 · GR-05 검측차 · GR-06 신호 초소.
## 동사: 입환 — 레버 셋(A · B · C)을 맞추고 정비고 기관차 7703으로 민다(대기 출력은 두 번 · 버스 노심이면 세 번). 앞에서 꺾인 레버가 길을 정한다.
## 정리: C(수송 열차에 연결) = '출발 진행' — 역무원 둘이 휴게실로 간다(GR_STAFF 2) · 둘 다 쓰러뜨려도 정리(1).
## 역무원(SD-14 '정기권 소지자 비공격'): 정기권이면 치지 않고 따라붙어 개찰구 밖으로 데려간다 · 기관사 열쇠꾸러미면 경례 · 없으면 경고 2.5초 뒤 적대(S05 규칙).
##   둘은 김(첫째 자리)과 박(둘째 자리) — 쓰러뜨린 사람은 다시 서지 않는다 · 박에게 분실물 정기권을 돌려주면 퇴근(GR_PARK = 그날).
## 재미 검수(구현 뒤) 반영: 구내 '출발 진행' 연출(살아 있는 역무원만) · 집결한 '안 간 사람들'의 승차 · 경보 스위치는 신호 초소 안(꾀어 놓고 반대편으로) ·
##   손으로 민 무개차는 소리(역무원이 서쪽 끝으로) · 억지로 연 냉장 화차는 절반 · 민 쪽을 제 눈으로(A 정비고 앞 · B 서쪽 끝 · C 수송 열차).
## 시간선(P4 · P6): 측량조 · 떠돌이 떠남은 06:00 하루 판정에서만. 사실은 GR_* 한 곳(P1) — 구내 그림은 들어설 때 그 사실로 다시 세운다.
class_name Gr
extends Node

const XGR := "X-GR"
const SHED := "GR-02"
const TRAIN := "GR-01"
const NEST := "GR-04"
const PUSHES := 2                          ## 대기 출력으로 밀 수 있는 횟수(정비 수칙 '노심 보호')
const BUS_PUSHES := 3                      ## 대방 버스 노심을 꽂으면
const WARN_S := 2.5                        ## 표 없는 사람: 경고 뒤 적대까지(S05 WARN_SECS와 같게)
const ESCORT_S := 3.0                      ## 정기권 손님: 곁에 이만큼 붙으면 개찰구 밖으로 데려간다
const SEE_T := 6.0                         ## 역무원이 손님을 알아보는 거리(칸) — 웅크리면 반
const BELL_S := 8.0                        ## 건널목 경보: 역무원이 건널목 앞에 서 있는 초
const NOISE_S := 20.0                      ## 손으로 민 무개차 소리: 역무원이 서쪽 끝을 살피는 초(구내 반대편에서 걸어오는 길 포함)
const STAY := 5                            ## 수송 열차 '안 간 사람들'
const ORIGIN_MARK := "X-GR:gr_gate_in"
const GATE_IN := Vector2i(61, 24)          ## 위 표지의 구내 안 좌표(원점 셈)
const YARD := Vector2i(64, 40)
const CROSS := Vector2i(39, 15)            ## 건널목(경보 단추를 누르면 역무원이 여기 와서 선다)
const SHED_DOOR := Vector2i(13, 12)        ## 정비고 큰 셔터 앞(퇴근길)
const LEVERS := {"A": Vector2i(12, 22), "B": Vector2i(2, 21), "C": Vector2i(37, 18)}
const LOST := Vector2i(60, 22)
const LOCO_AT := Vector2i(6, 8)            ## 정비고 안 기관차 자리
const FLAT_AT := Vector2i(3, 23)           ## 선로 끝 무개차 자리(소리가 난 곳)
const BELL_AT := Vector2i(40, 14)          ## 건널목 경보기 소품
const TRAIN_DOOR := Vector2i(17, 21)       ## 수송 열차 첫째 문 앞(집결한 사람들이 오른다)
const PARK_OUT := Vector2i(60, 24)         ## 박이 퇴근해 나가는 개찰구 안쪽
const CHEER_AT := [Vector2i(35, 21), Vector2i(36, 23)]   ## '출발 진행' — 김 · 박이 열차 곁에서 경광봉을 드는 자리
const VIEW := {"A": "gr_va", "B": "gr_west", "C": "gr_view"}   ## 민 뒤 구내에서 보는 자리
const SHEETS := ["en_cr204_loco", "en_cr204b_loco", "en_cr204c_loco"]
const BOSSES := ["C-013", "C-049"]         ## 새벽인력 소장 · 실장 — 둘 다 죽었으면 장부쟁이가 오지 않는다

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _now_s := 0.0
var _warn := {}                            ## 역무원 → 경고 초
var _near := {}                            ## 역무원 → 곁에 붙은 초
var _alarm_until := 0.0
var _alarm_at := Vector2i.ZERO
var _escorting := false
var _ringing := false
var stayers: Array = []


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["gr"] = _cmd
	host.day_tick.connect(_on_day)
	host.combat.enemy_killed.connect(_on_kill)
	host.map_entered.connect(_on_map)


func v(k: String) -> int:
	return int(st.vars.get_v("GR_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("GR_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[구로 차량기지] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


## 구내(월드 손 맵)의 원점 칸 — 월드가 아니거나 구내가 실려 있지 않으면 없음
func origin() -> Vector2i:
	if host.map == null or not (host.map is WorldMap) or not host.map.marks.has(ORIGIN_MARK):
		return Vector2i(-99999, -99999)
	var m: Array = host.map.marks[ORIGIN_MARK]
	return Vector2i(int(m[0]), int(m[1])) - GATE_IN


func in_yard(p: Vector2) -> bool:
	var o := origin()
	if o.x < -9999:
		return false
	var t := host.map.tile_of(p) - o
	return t.x >= 0 and t.y >= 0 and t.x < YARD.x and t.y < YARD.y


func _ypos(c: Vector2i) -> Vector2:
	return Vector2(origin() + c) * 32.0 + Vector2(16, 16)


# ---------------------------------------------------------------- 매 0.25초: 구내 역무원 · 수송 열차
func _process(dt: float) -> void:
	_now_s += dt
	if host == null or host.map == null or host.player == null:
		return
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	if host.map is WorldMap and in_yard(host.player.loco.logical):
		_staff_tick(0.25)


func staff() -> Array:
	var out: Array = []
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-205" and in_yard(e.loco.logical):
			_who(e)
			out.append(e)
	return out


## 역무원 누구인가(1 김 · 2 박): 맵 자리(처음 길의 첫 점)로 가린다 — 휴게실 자리는 진행기가 직접 적는다
func _who(e: Enemy) -> int:
	if not e.has_meta("gr_who"):
		var r: Array = e.get_meta("gr_route") if e.has_meta("gr_route") else e.route
		var p: Vector2 = r[0][0] if not r.is_empty() else e.loco.logical
		var t := host.map.tile_of(p) - origin()
		e.set_meta("gr_who", 2 if t.x >= 50 else 1)
	return int(e.get_meta("gr_who"))


## 구내에서 빠진 역무원(쓰러짐 비트 + 퇴근한 박) — 셋이면 구내가 빈다
func gone() -> int:
	return v("STAFF_K") | (2 if v("PARK") >= 1 else 0)


func _calm(e: Enemy, calm: bool) -> void:
	var t := "calm_gr" if calm else "enemy_gr"
	if e.cmb.team == t:
		return
	e.cmb.team = t
	e.foes = [] if calm else ["player", "ally"]
	if calm:
		e.brain.state = AIBrain.S.IDLE
		e.brain.gauge = 0.0


func _route_home(e: Enemy) -> void:
	if e.has_meta("gr_route"):
		e.route = (e.get_meta("gr_route") as Array).duplicate(true)
		e.set("_route_i", 0)


func _route_to(e: Enemy, p: Vector2, wait: float) -> void:
	if not e.has_meta("gr_route"):
		e.set_meta("gr_route", e.route.duplicate(true))
	e.route = [[p, wait]]
	e.set("_route_i", 0)


func _say(e: Enemy, s: String, secs := 2.5) -> void:
	e.say_text = s
	e.say_t = secs


## 역무원 둘: 출발 진행 · 퇴근 · 경례 · 안내(따라붙어 개찰구 밖) · 경고 → 적대 · 경보 · 소리
func _staff_tick(dt: float) -> void:
	var pc: Vector2 = host.player.loco.logical
	var pass_ok := bool(st.call_fn("has", ["M-071"]))
	var crouch: bool = host.combat.pc.posture == "crouch"
	var alarm := _now_s < _alarm_until
	var ring := alarm and _alarm_at == CROSS
	for e in staff():
		var at_cross: bool = e.loco.logical.distance_to(_ypos(CROSS)) < 2.5 * 32.0
		ring = ring or at_cross                                             # 건널목을 지나면 저절로 땡땡(어디쯤 있는지 알리는 소리)
		if e.has_meta("gr_leave"):                                          # 퇴근길(박) · 휴게실 가는 길: 닿으면 사라진다
			if e.loco.logical.distance_to(e.get_meta("gr_leave")) < 24.0:
				_drop(e)
			continue
		if v("STAFF") == 2:                                                 # '출발 진행' 뒤: 열차 곁에서 경광봉을 들고 외친 뒤 정비고 휴게실로(덤비던 중이어도)
			_cheer(e)
			continue
		if e.has_meta("gr_hot"):
			continue                                                        # 이미 무임승차로 덤볐다
		_calm(e, true)
		var d: float = e.loco.logical.distance_to(pc) / 32.0
		if alarm:                                                           # 경보 · 소리: 하던 일을 놓고 그쪽으로 — 곁을 지나가면 경고는 한다
			if not e.has_meta("gr_alarm"):
				e.set_meta("gr_alarm", 1)
				_route_to(e, _ypos(_alarm_at), BELL_S)
		elif e.has_meta("gr_alarm"):
			e.remove_meta("gr_alarm")
			_route_home(e)
		if v("KEY") == 1:                                                   # 직원 대접(기관사 열쇠꾸러미)
			if not alarm:
				_route_home(e)
			if d <= 3.0 and not e.has_meta("gr_salute"):
				e.set_meta("gr_salute", 1)
				_say(e, "수고하십니다, 기관사님.")
			continue
		if pass_ok:                                                         # 정기권 손님: 치지 않는다 — 대신 밖으로 모신다
			var see := SEE_T * (0.5 if crouch else 1.0)
			if d <= see:
				if not e.has_meta("gr_guide"):
					e.set_meta("gr_guide", 1)
					_say(e, "손님, 관계자 외 출입 금지입니다.", 3.0)
				_route_to(e, pc, 0.5)
				_near[e] = float(_near.get(e, 0.0)) + dt if d <= 1.6 else 0.0
				if float(_near[e]) >= ESCORT_S:
					_guide(e)
					return
			else:
				_near[e] = 0.0
				if e.has_meta("gr_guide"):
					e.remove_meta("gr_guide")
					if not alarm:
						_route_home(e)
			continue
		if d > 3.0:                                                         # 표 없음: 3칸 안 경고 → 2.5초 뒤 경광봉(S05 규칙)
			_warn[e] = -1.0
			continue
		if float(_warn.get(e, -1.0)) < 0.0:
			_warn[e] = 0.0
			_say(e, "승차권을 확인합니다.")
			continue
		_warn[e] = float(_warn[e]) + dt
		if float(_warn[e]) >= WARN_S:
			e.set_meta("gr_hot", 1)
			_calm(e, false)
			_say(e, "무임승차입니다.", 2.0)
	if ring != _ringing:
		_ringing = ring
		host.map.set_prop_state(origin() + BELL_AT, "ring" if ring else "")
	_board_tick()


func _drop(e: Enemy) -> void:
	host.combat.enemies.erase(e)
	e.queue_free()
	host.combat._rebuild_list()


## '출발 진행!' — 구내에 처음 들어섰을 때 한 번(GR_CHEER). 살아 있는 역무원만 서 있다(맵 조건 · 처치 기록)
func _cheer(e: Enemy) -> void:
	if e.has_meta("gr_cheer"):
		if e.loco.logical.distance_to(_ypos(CHEER_AT[_who(e) - 1])) < 24.0 and not e.has_meta("gr_cheered"):
			e.set_meta("gr_cheered", 1)
			_say(e, "출발 진행!", 3.0)
		return
	e.set_meta("gr_cheer", 1)
	e.remove_meta("gr_hot")
	_calm(e, true)
	e.route = [[_ypos(CHEER_AT[_who(e) - 1]), 3.0], [_ypos(SHED_DOOR), 30.0]]
	e.set("_route_i", 0)
	e.set_meta("gr_leave", _ypos(SHED_DOOR))
	if v("CHEER") == 0:
		_sv("CHEER", 1)
		_say(e, "…출발 진행.", 2.0)
		host.hint("경광봉 불빛이 열차 쪽으로 모인다. 2백 년 만의 출발 신호다.", 4.0)
		_log("구내 '출발 진행' 연출")


## 집결지의 '안 간 사람들': 열차가 움직였으면 줄지어 첫째 문으로 오른다(GR_MUSTER 3)
func _board_tick() -> void:
	if v("C") != 1:
		return
	for e in host.combat.enemies:
		if not is_instance_valid(e) or e.cmb.dead or not e.has_meta("gr_mu"):
			continue
		if not e.has_meta("gr_board"):
			e.set_meta("gr_board", 1)
			e.stance = ""
			e.route = [[_ypos(TRAIN_DOOR), 30.0]]
			e.set("_route_i", 0)
			_say(e, "…승차.", 2.0)
		elif e.loco.logical.distance_to(_ypos(TRAIN_DOOR)) < 24.0:
			_drop(e)
	if v("MUSTER") == 1:
		_sv("MUSTER", 3)
		_sv("MUSTER_DAY", day())
		host.hint("군화 소리가 줄을 맞춘다. 집결한 사람들이 하나씩 수송 열차에 오른다 — 200년 늦은 승차.", 5.0)
		_log("집결한 사람들이 수송 열차에 오름")


## 정기권 손님 곁에 붙었다: 안내 장면(박이면 정기권을 돌려줄 수 있다)
func _guide(e: Enemy) -> void:
	if _escorting:
		return
	_escorting = true
	_sv("GUIDE", _who(e))
	set_meta("guide_e", e)
	if host.is_inside_tree():
		host.play_scene("GR_ESCORT")
	else:
		_escort()


## 친절한 방해: 팔을 붙들려 직원 개찰구 밖으로
func _escort() -> void:
	for e in staff():
		_near[e] = 0.0
		if e.has_meta("gr_guide"):
			e.remove_meta("gr_guide")
		_route_home(e)
	_sv("ESC", v("ESC") + 1)
	host.hint("개찰구 밖까지 정중하게 모셔진다.", 3.0)
	_log("역무원이 개찰구 밖으로 안내")
	if host.is_inside_tree():
		host.go.call_deferred(XGR, "gr_gate_out")
	_escorting = false


## 박이 제 정기권을 돌려받았다: 퇴근(다시 서지 않는다 · 김은 이제 표 없는 손님으로 본다)
func _park() -> void:
	_escorting = false
	if v("PARK") >= 1 or not bool(st.call_fn("has", ["M-071"])):
		return
	st.call_fn("take", ["M-071", 1])
	_sv("PARK", day())
	var e: Variant = get_meta("guide_e") if has_meta("guide_e") else null
	if e != null and is_instance_valid(e):
		var en: Enemy = e
		en.remove_meta("gr_guide")
		_near[en] = 0.0
		en.route = [[_ypos(PARK_OUT), 30.0]]
		en.set("_route_i", 0)
		en.set_meta("gr_leave", _ypos(PARK_OUT))
		_say(en, "좋은 하루 되십시오.", 3.0)
	if v("STAFF") == 0 and gone() == 3:
		_sv("STAFF", 1)
		_sv("STAFF_DAY", day())
		_clear_check()
	_log("박이 정기권을 돌려받고 퇴근")


# ---------------------------------------------------------------- 맵에 들어섰다: 수송 열차 '안 간 사람들' · 휴게실 · 집결지
func _on_map(id: String) -> void:
	stayers.clear()
	_warn.clear()
	_near.clear()
	_escorting = false
	_ringing = false
	match id:
		TRAIN:
			if v("MUSTER") in [0, 3]:                                       # 0 고개 숙인 채 · 3 열차가 움직인 뒤 다시 앉음(고개를 들고 — 덤비지 않는다)
				var calm := v("MUSTER") == 3
				for i in STAY:
					if v("MUSTER_K") & (1 << i):
						continue
					var m := "s%d" % (i + 1)
					var o := {"sheet": SHEETS[i % 3], "dir": "S", "lv": 4, "arm": "claw", "team": "calm_gr" if calm else "enemy_gr", "doze": "sit"}
					if calm:
						o["foes"] = []
					var e := host.combat.spawn("CR-204", host.map.mark_pos(m), host.map, st, o)
					e.set_meta("gr_stay", i)
					if not calm:
						e.wake_cb = _stay_wake
					stayers.append(e)
		SHED:
			if v("STAFF") == 2:                                             # '출발 진행' 뒤 휴게실 의자에 앉아 존다 — 살아 있는 사람 자리만(김 rest1 · 박 rest2)
				for w in [1, 2]:
					if gone() & w:
						continue
					var e2 := host.combat.spawn("CR-205", host.map.mark_pos("rest%d" % w), host.map, st, {"sheet": "en_cr205_loco", "dir": "S", "lv": 4,
						"arm": "baton", "team": "calm_gr", "foes": [], "doze": "sit"})
					e2.set_meta("gr_rest", 1)
					e2.set_meta("gr_who", w)
	if host.map is WorldMap and v("MUSTER") == 1 and origin().x > -9999:      # 집결지: 기립한 '안 간 사람들'이 줄 맞춰 선다
		var n := 0
		for i in STAY:
			if v("MUSTER_K") & (1 << i):
				continue
			n += 1
			var mk := "%s:gr_mu%d" % [XGR, n]
			if not host.map.marks.has(mk):
				continue
			var e3 := host.combat.spawn("CR-204", host.map.mark_pos(mk), host.map, st, {"sheet": SHEETS[i % 3], "dir": "N", "lv": 4,
				"arm": "claw", "team": "calm_gr", "foes": [], "stance": "hold"})
			e3.set_meta("gr_mu", i)


## 수송 열차: 하나가 깨면 객차가 함께 일어난다(호루라기가 아니면 덤빈다)
func _stay_wake(e: Enemy) -> void:
	for o in stayers:
		if is_instance_valid(o) and o != e and o.asleep:
			o.wake()


# ---------------------------------------------------------------- 06:00 하루 판정
func _on_day(d: int) -> void:
	if v("CORE") >= 1 and v("SB") == 0 and d > v("CORE_DAY") and not (st.is_dead(BOSSES[0]) and st.is_dead(BOSSES[1])):
		_sv("SB", 1)                                                        # 기관 소리를 듣고 새벽인력 측량조가 와서 장부 번호를 칠한다(그날 하루 구내에)
		_sv("SB_DAY", d)
		_log("새벽인력 측량조 — 7703 장부 번호")
	elif v("SB") == 1 and d > v("SB_DAY") and v("DRIFT") != 2 and not st.is_dead("N-GR-D1"):
		_sv("DRIFT", 2)                                                     # 떠돌이가 개봉 쪽으로 떠난다(한 사람 한 곳 — 객차는 빈다)
		_log("떠돌이가 떠남")


# ---------------------------------------------------------------- 쓰러뜨림
func _on_kill(id: String, _left: int) -> void:
	var mid := _mid()
	if id == "CR-205" and (host.map is WorldMap or mid == SHED) and v("STAFF") != 1:
		var bits := 0
		for e in host.combat.enemies:                                       # 누가 쓰러졌나 — 처치 기록은 우두머리처럼(다시 서지 않는다 · 한 사람)
			if is_instance_valid(e) and e.cmb.dead and str(e.row.get("id", "")) == "CR-205" and e.has_meta("gr_who") and not e.has_meta("gr_down"):
				e.set_meta("gr_down", 1)
				bits |= int(e.get_meta("gr_who"))
				if e.has_meta("spawn_key"):
					st.boxes[str(e.get_meta("spawn_key"))] = {"day": day(), "boss": true}
		if bits == 0:                                                       # 누군지 못 가렸으면 아직 서 있는 쪽부터
			bits = 1 if not (gone() & 1) else 2
		_sv("STAFF_K", v("STAFF_K") | bits)
		if v("STAFF") == 0 and gone() == 3:
			_sv("STAFF", 1)
			_sv("STAFF_DAY", day())
			_clear_check()
			_log("역무원이 다 쓰러짐 — 정리")
	elif id == "CR-204" and mid == TRAIN:
		for e in stayers:
			if is_instance_valid(e) and e.cmb.dead and e.has_meta("gr_stay"):
				_sv("MUSTER_K", v("MUSTER_K") | (1 << int(e.get_meta("gr_stay"))))
		if v("MUSTER") == 0 and v("MUSTER_K") == (1 << STAY) - 1:
			_sv("MUSTER", 2)
	elif id == "CR-095" and mid == NEST and v("RATS") == 0:
		var left := 0
		for e in host.combat.enemies:
			if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-095":
				left += 1
		if left == 0:
			_sv("RATS", 1)
			host.hint("찍찍 소리가 그쳤다. 객차가 조용하다.", 3.0)
			_log("4번 칸 쥐 둥지 비움")


func _clear_check() -> void:
	var msg := Dungeon.check_clear(st, SHED)
	if msg != "" and host.is_inside_tree():
		host.hint(msg, 4.0)


# ---------------------------------------------------------------- 원고 명령(@cmd gr …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"enter":
			if host.is_inside_tree():
				host.go.call_deferred(str(a[1]), str(a[2]))
		"lever":
			var k := str(a[1])
			_sv("LV_" + k, 1 - v("LV_" + k))
			if host.map is WorldMap and origin().x > -9999:
				host.map.set_prop_state(origin() + LEVERS[k], "thrown" if v("LV_" + k) == 1 else "")
		"flat":
			_sv("B", 2)                                                     # 몸으로 밀어 굴렸다(노심 없이 관통 출구) — 쿵 소리에 역무원이 서쪽 끝으로
			if v("STAFF") == 0:
				_alarm(FLAT_AT, NOISE_S)
			if host.is_inside_tree():
				host.go.call_deferred(XGR, "gr_west")
		"reefer":
			if v("REEFER") == 0:
				_sv("REEFER", 1)                                            # 크레인으로 들면 밀봉째 다 · 억지로 열면 밀봉이 터져 절반(재미 검수: 우회에 대가)
				var full := a.size() > 1 and str(a[1]) == "full"
				for kv in ([["I-004", 3], ["I-001", 2], ["I-003", 1], ["I-092", 1]] if full else [["I-004", 1], ["I-001", 1]]):
					st.call_fn("give", kv)
		"bell":
			_alarm(CROSS, BELL_S)
		"escort":
			_escort()
		"park":
			_park()
		"tag":
			if v("TAG") == 0:
				_sv("TAG", 1)
		"side":
			if host.is_inside_tree():
				host.go.call_deferred(SHED, "side")
		"gate":
			if host.is_inside_tree():
				var out := host.map.tile_of(host.player.loco.logical).x <= (origin() + GATE_IN).x
				host.go.call_deferred(XGR, "gr_gate_out" if out else "gr_gate_in")
		"lost":
			if v("LOST") == 0:
				_sv("LOST", 1)
				st.call_fn("give", ["M-071", 1])
				if host.map is WorldMap and origin().x > -9999:
					host.map.set_prop_state(origin() + LOST, "open")
		"key":
			_sv("KEY", 1)
		"sigkey":
			_sv("SIGKEY", 1)
		"whistle":
			_sv("WHISTLE", 1)
		"muster":
			_muster()
		"wake":
			_wake(PUSHES)
		"bus":
			if bool(st.call_fn("has", ["M-392"])):
				st.call_fn("take", ["M-392", 1])
				st.vars.set_v("UQ71_CORE", 6)                               # 대방 버스 노심은 구로 7703에 들어가 다 탄다(UQ-71 노심의 행방 6)
				_sv("BUS", 1)
				_wake(BUS_PUSHES)
		"push":
			_push()
		"drift":
			if str(a[1]) == "ask" and v("DRIFT") == 0:
				_sv("DRIFT", 1)
			elif str(a[1]) == "done" and v("DRIFT") == 1 and v("TAG") == 1:
				_sv("DRIFT", 3)
				_sv("TAG", 2)
				st.call_fn("give", ["I-035", 2])
				st.call_fn("give", ["I-006", 1])
				st.call_fn("caps", [20])
	done.call()


## 경보 · 소리: 역무원이 그 자리로 가서 살핀다(곁을 지나는 사람에겐 여전히 경고)
func _alarm(at: Vector2i, secs: float) -> void:
	_alarm_at = at
	_alarm_until = _now_s + secs


func _wake(n: int) -> void:
	if v("CORE") != 0:
		return
	_sv("CORE", 1)
	_sv("PUSH", n)
	_sv("CORE_DAY", day())
	if _mid() == SHED:
		host.map.set_prop_state(LOCO_AT, "idle")                            # 유리 돔에 초록빛(맵 조건은 들어설 때만 본다)
	_log("7703 대기 출력(밀기 %d)" % n)


## 입환: 정비고에서 나가면 A부터 만난다 — 앞에서 꺾인 레버가 길을 정한다(전철기 표)
func route() -> String:
	for k in ["A", "B", "C"]:
		if v("LV_" + k) == 1:
			return k
	return ""


func _push() -> void:
	if v("CORE") != 1 or v("PUSH") <= 0 or v("C") == 1:
		return
	var r := route()
	if r == "":
		host.hint("레버가 다 곧은 길이다. 기관차가 정비고 앞까지 나갔다가 숨을 고르고 돌아온다.", 4.0)
		return
	if (r == "A" and v("A") == 1) or (r == "B" and v("B") >= 1):
		host.hint("그쪽은 이미 비었다. 기관차가 이음매 앞에서 멈춘다.", 3.0)
		return
	_sv("PUSH", v("PUSH") - 1)
	var msg := ""
	match r:
		"A":
			_sv("A", 1)
			msg = "쿵 — 연결기가 냉장 화차를 문다. 기관차가 끌고 와 정비고 앞에 내려놓는다."
		"B":
			_sv("B", 1)
			msg = "기관차가 서쪽 끝 무개차를 민다. 쐐기가 튕기고, 무개차가 담 틈 밖 내리막으로 굴러간다."
		"C":
			_sv("C", 1)
			msg = "쿵 — 2번 선로. 기관차가 수송 열차에 붙는다. 열차가 50미터 굴러가다 선다. 200년 늦은 출발."
			if v("STAFF") == 0:
				_sv("STAFF", 2)                                             # '출발 진행' = 던전 정리(역무원 둘이 휴게실로)
				_sv("STAFF_DAY", day())
				_clear_check()
	if v("PUSH") == 0 and r != "C":
		_sv("CORE", 2)                                                      # 두 번 밀면 다시 잠든다(노심 보호)
		msg += " 유리 돔의 초록빛이 사그라진다 — 노심이 다시 잠들었다."
	_log("입환 %s · 남은 밀기 %d" % [r, v("PUSH")])
	if host.is_inside_tree() and _mid() == SHED:
		_roll(msg, str(VIEW[r]))
	else:
		host.hint(msg, 5.0)


## 기관차가 실제로 구른다: 정비고 안 그림이 동쪽 선로 구멍으로 미끄러져 나가고(흔들림) → 구내로
func _roll(msg: String, view: String) -> void:
	var node: Node2D = null
	for p in host.map.props:
		if str(p["name"]) == "loco_atomic" and p.has("node") and int(p["x"]) == LOCO_AT.x and int(p["y"]) == LOCO_AT.y:
			node = p["node"]
	host.busy = true
	host.ev.run("shake", ["12"], func() -> void: pass)
	if node != null:
		var tw := host.create_tween()
		tw.tween_property(node, "position:x", node.position.x + 40.0 * 32.0, 3.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void:
			host.busy = false
			host.hint(msg, 6.0)
			host.go(XGR, view))
	else:
		host.busy = false
		host.hint(msg, 6.0)
		host.go.call_deferred(XGR, view)


## 호루라기 '기립!': 수송 열차 '안 간 사람들'이 일어나 줄지어 문으로 걸어 나간다(비적대) — 구내 집결지에 선다
func _muster() -> void:
	if v("MUSTER") != 0:
		return
	if v("C") == 1:                                                         # 열차가 이미 움직였다: 일어섰다가 고개를 들고 다시 앉는다(내리지 않는다)
		_sv("MUSTER", 3)
		_sv("MUSTER_DAY", day())
		for e in stayers:
			if is_instance_valid(e) and not e.cmb.dead:
				if e.asleep:
					e.wake()
				_calm(e, true)
				_say(e, "…출발 진행.", 2.0)
		_log("호루라기 — 이미 출발한 열차(다시 앉음)")
		return
	_sv("MUSTER", 1)
	_sv("MUSTER_DAY", day())
	var door := host.map.mark_pos("from_a") if host.map.marks.has("from_a") else Vector2.ZERO
	for e in stayers:
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		if e.asleep:
			e.wake()
		_calm(e, true)
		e.route = [[door, 60.0]]
		e.set("_route_i", 0)
		_say(e, "…기립.", 2.0)
	_log("호루라기 — 기립 · 집결")
