## 여의도 대학병원 DG-HP — UQ-126 「병동 7층」(H-R02-13) · RQ-47 「병동 7층 보급」(단계 1-D8, 1-D 계획 §14.7 · SD-05 §3.22 · SD-09a L-R02-09)
## · 병원 시계: 06:30 기상 · 09:00 회진 · 12:00 배식 · 14:00 면회 · 16:00 휴식 · 22:00 소등. 지하 야생 구울(옛 직원 N-HP-F1~F5 · 잃은 환자 N-HP-L1~L3)은
##   차임마다 다른 대형 — 기상 칸 앞에 누움 · 회진 복도 행진 · 배식 배식차 앞에 섬 · 면회 조문 의자에 앉음 · 휴식 서서 졸기 · 소등 배회(F4 · F5는 1층으로).
## · 방재실 단말로 아무 차임이나 지금(2시간 덮어쓰기) — 7층 회로가 이어져 있으면 제때 아닌 차임이 병동을 흐린다(하루 한 번).
## · 병동 시계(반수빈 첫 대화부터): 약 없이 14일(반수빈이 없으면 7일) → 차트 맨 위가 '흐림' → 7일 → '잃음'(지하로 · 이름표 구울) — 1막 최대 셋.
##   면회 시간에 흐린 환자 곁에 앉으면 돌아온다. 약길(① 교역 · ② 들것 · ③ 이주)을 고르면 시계가 멈춘다(그 길이 끊기면 다시 돈다).
## 사실은 변수 한 곳(P1) — 뜻은 script/act1/HP.txt 머리 주석.
class_name Hp
extends Node

const QID := "UQ-126"
const LOBBY := "HP-01"
const WARD := "HP-02"
const BASE := "HP-03"
const MARKET := "J-05"
const BAN := "N-R02-031"
const GEUM := "C-051"
const SO := "C-067"
const RAD := "I-002"
const BLOOD := "I-004"
const TAG := "M-397"
const NOTE := "M-398"
const XP := 120
const RQ_CAPS := 50
const RQ_XP := 15
const RQ_XP_CAP := 500
const CLOCK_D := 14                                ## 약 없이 버티는 날(반수빈이 없으면 절반)
const BLUR_D := 7                                  ## 흐림을 이만큼 넘기면 잃음
const LOST_MAX := 3                                ## 1막 안 최대 — 넷째부터는 흐림에서 멈춘다
const OVR_MIN := 120                               ## 덮어쓴 차임이 이 건물의 '지금'인 분
const PHASE_NAME := ["", "기상", "회진", "배식", "면회", "소등", "휴식"]
const POSE := {1: "lie", 3: "stand", 4: "sit", 6: "stand"}
const SPOT := {1: "lie", 2: "walk", 3: "eat", 4: "sit", 6: "rest"}
const FERALS := ["N-HP-F1", "N-HP-F2", "N-HP-F3", "N-HP-F4", "N-HP-F5", "N-HP-L1", "N-HP-L2", "N-HP-L3"]
const NIGHT_UP := ["N-HP-F4", "N-HP-F5"]           ## 소등 뒤 1층으로 올라오는 둘
const STAIR_B := Vector2i(3, 12)                    ## 지하 계단참
const STAIR_1 := Vector2i(17, 3)                    ## 1층 지하 계단참
const NIGHT_1 := {"N-HP-F4": [[19, 4, 3], [5, 6, 2], [8, 19, 3], [19, 15, 2]], "N-HP-F5": [[30, 8, 3], [24, 12, 2], [36, 10, 2], [21, 6, 3]]}
const ROAM_B := [[4, 12, 1], [17, 12, 2], [30, 12, 1], [40, 12, 2], [30, 5, 2], [17, 5, 1], [6, 5, 2], [9, 19, 2], [30, 19, 2]]
## 침상(차트 번호 → 칸) — 1~8 말 없는 환자(차트 순서 = 흐린 순서) · 9~12 말하는 넷
const BEDS := {1: Vector2i(2, 3), 2: Vector2i(13, 3), 3: Vector2i(8, 3), 4: Vector2i(19, 3), 5: Vector2i(4, 17), 6: Vector2i(30, 3), 7: Vector2i(26, 3),
	8: Vector2i(28, 3), 9: Vector2i(5, 3), 10: Vector2i(16, 3), 11: Vector2i(2, 17), 12: Vector2i(24, 3)}
const NAMES := {1: "탁정오", 2: "길순례", 3: "오재민", 4: "하예림", 5: "문덕배", 6: "정소라", 7: "윤상철", 8: "표경애"}

var host: InteriorHost
var st: StoryState
var log_on := false
var _tick := 0.0
var _phase := 0                                     ## 지금 맵에서 짠 대형(0 = 아직)
var _night := -1
var _leaving: Array = []                            ## 계단으로 사라질 개체(소등 · 기상 때 층을 옮김)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["hp"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.enemy_down.connect(_on_down)


func v(k: String) -> int:
	return int(st.vars.get_v("HP_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("HP_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[대학병원] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func _tc(c: Vector2i) -> Vector2:
	return Vector2(c) * 32.0 + Vector2(16, 16)


func _now() -> int:
	return Clock.abs_min(host.date_text)


func _minute() -> int:
	return TimeOfDay.minute(host.date_text)


# ---------------------------------------------------------------- 병원 시각표
## 그 분(하루 안 0~1439)의 차임 칸: 1 기상 · 2 회진 · 3 배식 · 4 면회 · 6 휴식 · 5 소등
static func phase_of(m: int) -> int:
	if m >= 1320 or m < 390:
		return 5
	if m < 540:
		return 1
	if m < 720:
		return 2
	if m < 840:
		return 3
	if m < 960:
		return 4
	return 6


## 지금 이 건물의 '지금'(덮어쓴 차임이 살아 있으면 그것)
func phase() -> int:
	if v("OVR") > 0 and _now() < v("OVR_END"):
		return v("OVR")
	return phase_of(_minute())


func way_ok() -> bool:
	match v("WAY"):
		1:
			return not st.is_dead(GEUM)
		2:
			return not st.is_dead(SO)
		3:
			return true
	return false


## 병동 시계가 도나: 첫 대화 뒤 · 약길이 없거나 끊김
func clock_on() -> bool:
	return v("MET") == 1 and not way_ok()


## 다음에 흐려질 차트(잃은 수 다음 — 이주 때 떠난 1~5는 건너뛰지 않는다: 이주면 시계가 멈춘다)
func next_chart() -> int:
	return v("LOST") + 1


func days_left() -> int:
	if not clock_on():
		return -1
	if v("BLUR") > 0:
		return maxi(0, BLUR_D - (day() - v("BLUR_DAY")))
	var span := CLOCK_D if not st.is_dead(BAN) else CLOCK_D / 2
	return maxi(0, span - (day() - v("DAY0")))


# ---------------------------------------------------------------- 하루 판정(06:00 — P6)
func _on_day(d: int) -> void:
	if v("MOVE_DAY") > 0 and d > v("MOVE_DAY") and v("WAY") == 0 and not st.is_dead(BAN):
		_sv("WAY", 3)                                                 # 이주: 기상 차임에 맞춰 내려갔다(인솔은 다음 06:00)
		_sv("BLUR", 0)
		st.call_fn("aff", ["JH", 4])
		_log("이주 — 지하시장 진료소 곁")
	if v("WAY") == 2 and way_ok() and posmod(d, 7) == 4:
		_sv("DAY0", d)                                                # 들것이 들렀다(이레에 하루 — 접수대 약 상자)
	_skip_week(d)
	_ward_clock(d)
	_quest()


## 보급을 한 주 걸렀다(첫 납품 뒤 · 직접 나르는 길일 때) — 반수빈이 다음 대화 첫머리에 한 번 말한다(HP_SKIP 1 → 원고가 2)
func _skip_week(d: int) -> void:
	var n := int(st.vars.get_v("RQ47_N"))
	if n == 0 or v("SKIP") != 0 or v("WAY") >= 2 or st.is_dead(BAN):
		return
	if int(d / 7.0) + 1 >= int(st.vars.get_v("RQ47_WK")) + 2:
		_sv("SKIP", 1)


func _ward_clock(d: int) -> void:
	if not clock_on():
		return
	if v("BLUR") > 0:
		if v("BLUR") <= LOST_MAX and v("LOST") < LOST_MAX and d - v("BLUR_DAY") >= BLUR_D:
			_sv("LOST", v("LOST") + 1)                                # 잃음 — 지하로 내려가 이름표를 단다
			_sv("BLUR", 0)
			_sv("DAY0", d)
			_log("잃음 %d — %s" % [v("LOST"), NAMES.get(v("LOST"), "")])
		return
	var span := CLOCK_D if not st.is_dead(BAN) else CLOCK_D / 2
	if d - v("DAY0") >= span:
		_blur_start(d)


func _blur_start(d: int) -> void:
	var n := next_chart()
	if n > 8:
		return
	_sv("BLUR", n)
	_sv("BLUR_DAY", d)
	_log("흐림 — 차트 %d %s" % [n, NAMES.get(n, "")])


## 제때 아닌 차임 · 몰래 끊은 회로가 병동 일과를 흐트러뜨렸다(하루 한 번)
func _push() -> void:
	if v("PUSH_DAY") == day() or v("MET") == 0 or v("WAY") == 3:
		return
	_sv("PUSH_DAY", day())
	if v("BLUR") == 0:
		_blur_start(day())
	else:
		_sv("BLUR_DAY", v("BLUR_DAY") - 1)                           # 이미 흐린 사람은 하루 더 멀어진다
	if _mid() == WARD:
		host.hint("7층 복도에서 누가 묻는다. '지금 몇 시예요? 방금 차임 뭐였어요?' 반수빈이 차트를 넘긴다.", 4.0)


# ---------------------------------------------------------------- 맵 · 대형
func _on_map(id: String) -> void:
	_phase = 0
	_night = -1
	_leaving.clear()
	if not id.begins_with("HP-"):
		return
	_sv("NIGHT", 1 if phase() == 5 and v("GEN") == 0 else 0)
	if id == BASE or id == LOBBY:
		_place_floor(id)
		_formation(true)


func _process(dt: float) -> void:
	if host == null or host.map == null or host.player == null:
		return
	var mid := _mid()
	if not mid.begins_with("HP-"):
		return
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 0.25
	if v("OVR") > 0 and _now() >= v("OVR_END"):
		_sv("OVR", 0)                                                 # 덮어쓴 차임이 끝났다 — 시계로 돌아간다
	var ph := phase()
	if ph != _phase and _phase != 0:
		_chime(ph)
	if mid == BASE or mid == LOBBY:
		_formation(false)
	_settle()
	if v("MORGUE") == 0 and FERALS.slice(0, 5).all(func(w): return st.is_dead(w)):
		_sv("MORGUE", 1)                                              # 옛 직원 다섯 — 지하 정리(던전 표 clear)
		_log("영안실 정리")


## 차임이 울렸다(제때든 덮어쓰기든)
func _chime(ph: int) -> void:
	host.hint("천장 스피커 차임 — '%s 시간입니다.'" % PHASE_NAME[ph], 3.0)
	if v("CUT") == 2 and v("OVR") == 0 and v("SEEN") == 0:
		_sv("TRUST", 0)                                               # 몰래 끊은 회로 — 제때 차임이 7층에 안 울렸다: 반수빈이 안다(다음 대화 첫마디)
		_sv("SEEN", 1)
		_push()


func _is_feral(e) -> bool:
	return is_instance_valid(e) and not e.cmb.dead and str(e.who).begins_with("N-HP-")


func ferals() -> Array:
	return host.combat.enemies.filter(func(e): return _is_feral(e))


## 지금 칸에 맞게 대형을 짠다(placed: 맵에 막 들어섬 — 자리에 바로 세운다)
func _formation(placed: bool) -> void:
	var ph := phase()
	var night := 1 if ph == 5 and v("GEN") == 0 else 0
	if v("GEN") == 1:
		ph = 1                                                        # 냉동 칸을 다시 돌렸다 — 소등 반사가 꺼지고 다섯은 칸 앞에서 잔다
	if ph == _phase and night == _night:
		return
	var floor_moved := _night != -1 and night != _night
	_phase = ph
	_night = night
	_sv("NIGHT", night)
	_sv("PHASE", ph)
	var mid := _mid()
	if floor_moved:
		_swap_floor(night == 1)
	var k := 0
	for e in ferals():
		if e in _leaving or e.brain.state == AIBrain.S.COMBAT:
			continue
		var i := FERALS.find(str(e.who))
		if mid == LOBBY:
			_night_walk(e)
			continue
		if ph == 5:
			_roam(e, i)
		elif ph == 2:
			_march(e, k)
		else:
			_to_spot(e, "f_%s_%d" % [SPOT[ph], i + 1], ph, placed)
		k += 1
	_log("대형 %s%s" % [PHASE_NAME[ph], " (밤 1층)" if night == 1 else ""])


func _wake_quiet(e) -> void:
	e.doze = ""
	e.asleep = false
	e.det_mul = 1.0
	e.set_pose("stand")


func _to_spot(e, mark: String, ph: int, placed: bool) -> void:
	if not host.map.marks.has(mark):
		return
	var p: Vector2 = host.map.mark_pos(mark)
	if placed:
		e.loco.place(p)
		_doze(e, ph)
		return
	_wake_quiet(e)
	e.det_mul = 0.6                                                   # 일과 걸음(멍하다)
	e.route = [[p, 9999.0]]
	e._route_i = 0
	e.set_meta("hp_go", ph)


func _doze(e, ph: int) -> void:
	e.route = []
	e.doze = POSE.get(ph, "stand")
	e.asleep = true
	e.det_mul = 0.3
	e.set_pose(e.doze)
	e.wake_cb = _group_wake
	if e.has_meta("hp_go"):
		e.remove_meta("hp_go")


## 자리에 닿은 개체를 그 칸 자세로 재운다
func _settle() -> void:
	for e in ferals():
		if not e.has_meta("hp_go") or e.route.is_empty():
			continue
		if e.loco.logical.distance_to(e.route[0][0]) < 10.0:
			_doze(e, int(e.get_meta("hp_go")))
	for e in _leaving.duplicate():
		if not is_instance_valid(e) or e.cmb.dead:
			_leaving.erase(e)
			continue
		if not e.route.is_empty() and e.loco.logical.distance_to(e.route[0][0]) < 12.0:
			_leaving.erase(e)
			host.combat.enemies.erase(e)
			e.queue_free()


func _march(e, k: int) -> void:
	_wake_quiet(e)
	e.det_mul = 0.6
	var pts: Array = []
	for j in 8:
		var m := "f_walk_%d" % (((j + k) % 8) + 1)
		if host.map.marks.has(m):
			pts.append([host.map.mark_pos(m), 1.0])
	e.route = pts
	e._route_i = 0


func _roam(e, i: int) -> void:
	_wake_quiet(e)
	var pts: Array = []
	for j in ROAM_B.size():
		var r: Array = ROAM_B[(j + i * 2) % ROAM_B.size()]
		pts.append([_tc(Vector2i(int(r[0]), int(r[1]))), float(r[2])])
	e.route = pts
	e._route_i = 0


func _night_walk(e) -> void:
	_wake_quiet(e)
	var pts: Array = []
	for r in NIGHT_1.get(str(e.who), []):
		pts.append([_tc(Vector2i(int(r[0]), int(r[1]))), float(r[2])])
	e.route = pts
	e._route_i = 0


## 맵에 막 들어섰다: 맵 원고의 적은 진행기보다 먼저 서므로, 지금 밤낮에 맞게 F4 · F5를 이 층에 두거나 치운다(자리에서 바로)
func _place_floor(id: String) -> void:
	var night := v("NIGHT") == 1
	for w in NIGHT_UP:
		if st.is_dead(w):
			continue
		var here := ferals().filter(func(e): return str(e.who) == w)
		var belongs := (id == LOBBY and night) or (id == BASE and not night)
		if not belongs:
			for e in here:
				host.combat.enemies.erase(e)
				e.queue_free()
		elif here.is_empty():
			var at: Vector2i = STAIR_1 if id == LOBBY else STAIR_B
			var e2: Enemy = host.combat.spawn("CR-200", _tc(at), host.map, st, {"who": w})
			e2.who = w
			e2.wake_cb = _group_wake


## 소등이 시작 · 끝났다 — F4 · F5가 계단으로 층을 옮긴다(보이는 자리에서)
func _swap_floor(night_now: bool) -> void:
	var mid := _mid()
	for w in NIGHT_UP:
		if st.is_dead(w):
			continue
		var here := ferals().filter(func(e): return str(e.who) == w)
		var goes_away := (mid == BASE and night_now) or (mid == LOBBY and not night_now)
		if goes_away:
			for e in here:
				if e.brain.state == AIBrain.S.COMBAT:
					continue
				_wake_quiet(e)
				e.route = [[_tc(STAIR_B if mid == BASE else STAIR_1), 9999.0]]
				e._route_i = 0
				_leaving.append(e)
		elif here.is_empty():
			var at := STAIR_B if mid == BASE else STAIR_1
			var e2: Enemy = host.combat.spawn("CR-200", _tc(at), host.map, st, {"who": w})
			e2.who = w
			e2.wake_cb = _group_wake


## 하나가 깨면 12칸 안 같은 무리가 한꺼번에(SD-14 '비명 뒤 한꺼번에 돌진')
func _group_wake(src) -> void:
	for e in ferals():
		if e != src and e.asleep and e.loco.logical.distance_to(src.loco.logical) < 12.0 * 32.0:
			e.wake()


func _on_down(e: Enemy) -> void:
	if str(e.who).begins_with("N-HP-"):
		st.kill(str(e.who))
		_log("쓰러짐 %s" % str(e.who))


# ---------------------------------------------------------------- 명령(@cmd hp …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"met":
			if v("MET") == 0:
				_sv("MET", 1)
				_sv("DAY0", day())
		"told":
			_sv("TOLD", 1)
		"letter":
			if v("LETTER") == 0:
				_sv("LETTER", 1)
		"way":
			set_way(int(a[1]))
		"move":
			_sv("MOVE_DAY", day())
		"supply":
			supply()
		"visit":
			visit(int(a[1]) if a.size() > 1 else 0)
		"bed":
			_sv("BED", bed_here())
			_sv("VON", visit_on())
		"von":
			_sv("VON", visit_on())
		"cut":
			cut(int(a[1]))
		"call":
			call_chime(int(a[1]))
		"gen":
			_sv("GEN", 1)
			_phase = 0
		"mask":
			_sv("MASK", 1)
		"board":
			board()
		"pa1":
			pa1()
		"take":
			st.call_fn("give", [str(a[1]), 1])
		"ask":
			ask(int(a[1]))
	_quest()
	done.call()


func set_way(n: int) -> void:
	if v("WAY") != 0 or st.is_dead(BAN):
		return
	match n:
		1:
			if st.is_dead(GEUM):
				return
			_sv("LETTER", 2)
			st.call_fn("aff", ["JH", 2])
		2:
			if st.is_dead(SO) or int(st.vars.get_v("DG_STOP")) != 0:
				return
			st.vars.set_v("DG_STOP", 1)                                   # 들것 추가 정류지는 하나 — 여의도(흑석은 닫힘, UQ-66이 읽는다)
	_sv("WAY", n)
	_sv("BLUR", 0)
	_sv("DAY0", day())
	_log("약길 %d" % n)


## RQ-47 납품: 라드어웨이 셋 + 수혈 팩 둘 — 주 한 번 · 회차 곡선(1~3 100% · 4~5 75% · 6~ 50%) · XP 누적 500
func supply() -> void:
	var wk := int(day() / 7.0) + 1
	if int(st.vars.get_v("RQ47_WK")) == wk:
		host.hint("반수빈 '이번 주 몫은 받았어요. 다음 주에 와요.'", 3.0)
		return
	if int(st.call_fn("has", [RAD, 3])) == 0 or int(st.call_fn("has", [BLOOD, 2])) == 0:
		return
	st.call_fn("take", [RAD, 3])
	st.call_fn("take", [BLOOD, 2])
	var n := int(st.vars.get_v("RQ47_N")) + 1
	st.vars.set_v("RQ47_N", n)
	st.vars.set_v("RQ47_WK", wk)
	st.vars.set_v("RQ47_LAST", day())
	var mul := 1.0 if n <= 3 else (0.75 if n <= 5 else 0.5)
	st.call_fn("caps", [roundi(RQ_CAPS * mul)])
	if n * RQ_XP <= RQ_XP_CAP:
		st.call_fn("xp", [roundi(RQ_XP * mul)])
	if n <= 3:
		st.call_fn("karma", [10])
	if v("WAY") == 1:
		st.call_fn("aff", ["JH", 2])
	if n == 1 and v("TRUST") == 0 and v("CUT") != 2:
		_sv("TRUST", 1)                                               # 첫 보급 — 약을 들고 온 사람이면 7층 회로를 맡긴다
	_sv("SKIP", 0)
	_sv("DAY0", day())                                                # 약이 들어왔다 — 시계를 다시 잰다
	_log("RQ-47 %d회" % n)


## 7층이 듣는 '지금'이 면회인가: 0 아님 · 1 제때(14~16시) · 2 지하에서 튼 가짜(회로가 이어져 있을 때만 들린다)
func visit_on() -> int:
	var natural := phase_of(_minute()) == 4
	var ward := phase() if v("CUT") == 0 else phase_of(_minute())
	if ward != 4:
		return 0
	return 1 if natural else 2


## 면회(제때만): 흐린 환자 곁에 앉으면 돌아온다 · 서로 다른 날 셋째 면회 또는 한 면회 시간에 다른 침상 셋 → 반수빈이 믿는다(7층 회로)
func visit(bed: int) -> void:
	if visit_on() != 1:
		return
	var b := bed if bed > 0 else v("BED")
	if b > 0 and b == v("BLUR"):
		_sv("BLUR", 0)
		_sv("DAY0", day())
		host.hint("%s 씨가 내 얼굴을 보고 이름을 부른다. 반수빈이 칠판 숫자를 지운다." % NAMES.get(b, "환자"), 3.5)
	if v("VISIT_DAY") != day():
		_sv("VISIT_DAY", day())
		_sv("VISIT", v("VISIT") + 1)
		_sv("VMASK", 0)
	if b > 0:
		_sv("VMASK", v("VMASK") | (1 << b))
	var beds := 0
	for i in 13:
		if v("VMASK") & (1 << i):
			beds += 1
	if (v("VISIT") >= 3 or beds >= 3) and v("TRUST") == 0 and v("CUT") != 2:
		_sv("TRUST", 1)


## 주인공이 서서 바라보는 침상(차트 번호 — 없으면 0)
func bed_here() -> int:
	if _mid() != WARD:
		return 0
	var c := Vector2i(host.player.loco.logical / 32.0)
	var best := 0
	var bd := 99.0
	for n in BEDS:
		var b: Vector2i = BEDS[n]
		var d := Vector2(c).distance_to(Vector2(b) + Vector2(0, 1.5))
		if d < bd:
			bd = d
			best = int(n)
	return best if bd <= 3.0 else 0


func cut(n: int) -> void:
	if n == 1 and v("TRUST") == 0:
		return
	if n == 2 and ban_sees():
		_sv("TRUST", 0)                                               # 보는 앞에서 — 그 자리에서 잡힌다(믿음은 처음부터)
		_sv("VISIT", 0)
		_sv("VMASK", 0)
		return
	if n != 2:
		_sv("SEEN", 0)
	_sv("CUT", n)


## 반수빈이 차단기를 보고 있나: 살아 있고 · 간호사실에 있다(면회 시간엔 복도 의자 앞 — 그때만 몰래 내릴 수 있다)
func ban_sees() -> bool:
	if st.is_dead(BAN) or v("WAY") == 3:
		return false
	return phase_of(_minute()) != 4


## 방재실 단말: 그 차임 칸이 두 시간 동안 이 건물의 '지금' — 7층이 들으면(회로 연결) 제때 아닌 차임은 병동을 흐린다
func call_chime(n: int) -> void:
	if n < 1 or n > 5:
		return
	var natural := phase_of(_minute())
	_sv("OVR", n)
	_sv("OVR_END", _now() + OVR_MIN)
	if v("CUT") == 0 and n != natural:
		_push()
	_log("차임 덮어쓰기 %s" % PHASE_NAME[n])


func board() -> void:
	var lines: Array = ["칠판. 오늘 일과 — 기상 · 회진 · 배식 · 면회 · 소등. 지금은 '%s'." % PHASE_NAME[phase_of(_minute())]]
	if v("WAY") > 0 and way_ok():
		lines.append(["", "'지하 진료소 — 주마다 피 둘'", "'들것 — 이레에 하루'", "'이송 — 지하시장'"][v("WAY")])
	elif v("MET") == 1:
		var left := days_left()
		if v("BLUR") > 0:
			lines.append("'%d번 %s — 흐림. 면회 꼭.' 그 옆에 '%d일'." % [v("BLUR"), NAMES.get(v("BLUR"), ""), left])
		else:
			lines.append("'약 없이 버틴 날 — 다음 차트 정리까지 %d일'." % left)
	if v("LOST") > 0:
		lines.append("맨 아래 줄에 지운 이름 %d개. 지운 자국 위에 '지하'." % v("LOST"))
	host.hint("  ".join(lines), 5.0)


func pa1() -> void:
	var ph := phase()
	host.hint("접수대 스피커. 지금은 '%s' 시간.%s" % [PHASE_NAME[ph], "  (누가 지하에서 시각표를 바꿔 틀었다)" if v("OVR") > 0 else ""], 3.5)


## 작은 부탁(말하는 환자): 1 변수아 사원증 · 2 오재석 이야기 · 3 기도윤 아빠 쪽지
func ask(n: int) -> void:
	if v("ASK%d" % n) == 2:
		return
	if n == 1:
		st.call_fn("take", [TAG, 1])
	elif n == 3:
		st.call_fn("take", [NOTE, 1])
	_sv("ASK%d" % n, 2)
	st.call_fn("xp", [25])
	st.call_fn("karma", [5])


# ---------------------------------------------------------------- UQ-126 단계는 사실로 센다(P2)
func _quest() -> void:
	var cur := st.quests.stage(QID)
	if cur >= 100:
		return
	if v("MET") == 0:
		return
	var s := 10
	if v("TOLD") == 1:
		s = 20
	if v("WAY") > 0:
		s = 100
	if s > cur:
		st.quests.set_stage(QID, s)
		if s == 100:
			st.call_fn("xp", [XP])
			st.call_fn("karma", [10])
			st.call_fn("result", [QID, v("WAY")])
			_log("UQ-126 끝 — 약길 %d" % v("WAY"))
