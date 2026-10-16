## 관악(R01) 사이드 퀘스트 SQ-S05 「환승촌 막차」 진행기(단계 1-11e, SD-04a §4.5). 원고: script/act1/SQ-S05.txt · SADANG.txt(허순자 · 표하경 · 반로아 ·
##   방송 설비 · 칠판 · 철망 몫) · MQ-102.txt(주성호 몫). 맵: D-06 철망 문 · U-01 2호선 서쪽 터널 · U-02 낙성대역 승강장 · U-03 서울대입구역(봉천 사다리).
## 단계는 이 진행기 한 곳에서만, 오르기만 한다(SD-20). 퀘스트가 열리기 전에 한 일(방송 설비 · 터널 · 파수-3)은 사실로 남아 열리는 순간 따라 올린다(P2).
## 휴면 군집(SD-14 §12): 대피민 구울은 앉거나 누워(서서 조는 하나) '막차'를 기다린다 — 소리 · 맞음 · 2칸 안 서서 걸음(웅크리면 1칸)으로만 깨고,
##   하나가 깨면 승강장 무리가 한꺼번에 일어난다. 깬 무리는 여섯 시간 뒤 다시 앉는다(다음 방문).
## 해법: 1 막차 방송(행렬 — 24시간 안에 승강장에 내려가면 보인다, 그 뒤면 결과만) · 2 소탕 · 3 구울의 말(주성호 일시 동행 — 봉천행 표의 절반이 떠난다) ·
##   가면(A-106)은 길만 연다(손님은 그대로 — 통과지 해결이 아니다).
## 재미 검수(SD-23, 계획 때 8건): 서서 조는 손님 · 시계 태엽 시각 · 물 한 통 · 행렬 중 소란 · 매시 방송 · 무단 방송 꾸중 · 결과 판 · 주성호 동행 · 역무원의 정기권 막기.
class_name SideS05
extends Node

const GUESTS := 8                          ## 승강장 손님 수(SD-04a '대피민 구울 6~10' — 표지 g1~g8)
const SHEETS := ["en_cr204_loco", "en_cr204b_loco", "en_cr204c_loco"]   ## 무리마다 옷 색 셋
const LINE_MIN := 24 * 60                  ## 방송 뒤 이 안에 승강장에 내려가면 행렬을 본다(재미 검수 4 — 매시 정각 되풀이)
const RESLEEP_MIN := 6 * 60                ## 깬 무리가 다시 앉는 시간
const JU_DAYS := 2                         ## 주성호가 기다려 주는 날(그 뒤 봉천으로 돌아간다)
const PROC_GAP := 2.2                      ## 행렬: 손님 사이 간격(초)
const WARN_SECS := 2.5                     ## 역무원: '승차권을 확인합니다' 뒤 경광봉까지
const STAFF_BIT := 1 << 8
const IRON_U02 := Vector2i(2, 1)
const SIDING_U02 := Vector2i(11, 1)
const GATE_D06 := Vector2i(15, 10)
const ROBOT_U01 := Vector2i(29, 9)
const JU_ID := "N-R02-018"

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var guests: Array = []                     ## 지금 맵의 손님(Enemy) — 메타 s05g = 번호
var staff: Enemy
var sleeper: Enemy
var _warn_t := -1.0
var _asked := false                        ## 가면: '역무원이세요? 막차는요?'를 이번 방문에 들음
var _hour_said := -1
var proc: Dictionary = {}                  ## 행렬 진행: {"q": [번호…], "walk": {id: 번호}, "t", "n0", "in", "broke", "shots"}
var _shots0 := 0


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s05"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.enemy_down.connect(_on_down)
	host.combat.provoked.connect(_on_provoked)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v(k, n)


func _log(s: String) -> void:
	if log_on:
		print("[막차] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S05")


func _now() -> int:
	return Clock.abs_min(host.date_text)


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S05", n)
		_log("단계 %d" % n)


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _masked() -> bool:
	return str(st.vars.get_v("PC_EYES")) == "A-106"


func _ticket() -> bool:
	return bool(st.call_fn("has", ["M-071"]))


func _gone(i: int) -> bool:
	return v("SQ_S05_LEFT") & (1 << i) != 0


func _set_gone(i: int) -> void:
	_sv("SQ_S05_LEFT", v("SQ_S05_LEFT") | (1 << i))


func _left_count() -> int:
	var n := 0
	for i in GUESTS:
		if not _gone(i):
			n += 1
	return n


## 손님마다 표 행선지: 봉천행이 절반(주인공마다 다른 절반 — 재미 검수 7 '매번 같은 절반이 아니다')
func _bongcheon(i: int) -> bool:
	var idx: Array = range(GUESTS)
	var r := RandomNumberGenerator.new()
	r.seed = hash("s05:" + str(st.vars.get_v("P_REGNO")))
	for k in range(idx.size() - 1, 0, -1):
		var j := r.randi_range(0, k)
		var tmp = idx[k]
		idx[k] = idx[j]
		idx[j] = tmp
	return idx.find(i) < GUESTS / 2


func _solved() -> bool:
	return v("SQ_S05_SOL") >= 1 and v("SQ_S05_SOL") <= 3


# ---------------------------------------------------------------- 단계
## 퀘스트가 열린다(단계 10) — 그 전에 한 일만큼 따라 올린다(P2)
func _start(why: String) -> void:
	if int(st.vars.get_v("V_ACT")) < 1:
		return
	if stage() == 0:
		_up(10)
		_log("발동(%s)" % why)
	_catch_up()


func _catch_up() -> void:
	if stage() < 10:
		return
	if v("SQ_S05_GATE") == 1 or v("SQ_S05_FENCE") >= 1 or v("SQ_S05_IN") == 1:
		_up(20)
	if v("SQ_S05_BSEEN") == 1:
		_up(30)
	if v("SQ_S05_IN") == 1:
		_up(40)
	if _solved():
		_up(50)
	if v("SQ_S05_REPORT") == 1:
		_up(100)


func _resolve(sol: int, why: String) -> void:
	if v("SQ_S05_SOL") == 0 or v("SQ_S05_SOL") == 4:
		_sv("SQ_S05_SOL", sol)
	_start(why)
	_up(50)
	_log("해법 %d(%s)" % [sol, why])
	var what := {1: "사당 서쪽 터널의 손님들이 막차 안내를 듣고 줄지어 측선으로 들어갔다", 2: "사당 서쪽 터널의 구울 손님들이 쓰러졌다",
		3: "봉천 구울 행상이 사당 서쪽 터널 손님들에게 막차가 끊겼다고 말했다"}
	_deed("SQS05_" + "ABC"[sol - 1], {"JC_SA": 0}, str(what.get(sol, "")))


# ---------------------------------------------------------------- 매 0.5초: 매시 방송 · 역무원 · 가면 · 행렬
func _process(dt: float) -> void:
	if not proc.is_empty():
		_proc_tick(dt)
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if host.map == null or host.player == null:
		return
	_broadcast_tick()
	match _zone():
		"U-02":
			_calm_tick()
			_staff_tick()
		"U-01":
			_calm_tick()
	if v("SQ_S05_BCAST") > 0 and v("SQ_S05_LINE") == 0 and _zone() != "U-02" and _now() >= v("SQ_S05_BCAST_AT") + LINE_MIN:
		_line_offscreen()


## 매시 정각 안내(재미 검수 4): 사당 · 터널 · 승강장에 있으면 들린다 — 행렬이 끝나면 멎는다
func _broadcast_tick() -> void:
	if v("SQ_S05_BCAST") == 0 or v("SQ_S05_LINE") != 0:
		return
	var z := _zone()
	if not (z.begins_with("D-0") or z.begins_with("U-0")):
		return
	var h := Clock.hour(host.date_text)
	if h == _hour_said:
		return
	_hour_said = h
	host.hint("확성기: \"오늘 운행을 모두 마쳤습니다. 승강장에 계신 손님께서는 서울대입구 방면 승강장 끝 출구로…\"", 6.0)


## 깬 손님 · 역무원의 편: 가면(또는 정기권 — 역무원만)이면 비적대, 아니면 적대. 주인공이 먼저 때린 무리(HOT)는 끝까지 적대
func _calm_tick() -> void:
	var mask := _masked()
	for e in guests + ([sleeper] if is_instance_valid(sleeper) else []):
		if not is_instance_valid(e) or e.cmb.dead or e.asleep:
			continue
		_side(e, mask and v("SQ_S05_HOT") == 0)
		if mask and not _asked and v("SQ_S05_HOT") == 0 and e.loco.logical.distance_to(host.player.loco.logical) < 4.0 * 32.0:
			_asked = true
			e.say_text = "역무원이세요? 막차는요?"                          # 재미 검수 8: 대답할 수 없다는 그 순간이 C 실마리
			e.say_t = 3.0


func _side(e: Enemy, calm: bool) -> void:
	var t := "calm_s05" if calm else "enemy_s05"
	if e.cmb.team == t:
		return
	e.cmb.team = t
	e.foes = [] if calm else ["player", "ally"]
	if calm:
		e.brain.state = AIBrain.S.IDLE
		e.brain.gauge = 0.0


## 역무원 구울: 정기권이나 가면이면 비켜선다. 없으면 3칸 안에서 '승차권을 확인합니다' — 2.5초 뒤 경광봉
func _staff_tick() -> void:
	if not is_instance_valid(staff) or staff.cmb.dead:
		return
	var pass_ok := (_ticket() or _masked()) and v("SQ_S05_HOT") == 0
	if pass_ok:
		_warn_t = -1.0
		_side(staff, true)
		return
	if staff.cmb.team == "enemy_s05":
		return
	var d := staff.loco.logical.distance_to(host.player.loco.logical) / 32.0
	if d > 3.0:
		_warn_t = -1.0
		return
	if _warn_t < 0.0:
		_warn_t = 0.0
		staff.say_text = "승차권을 확인합니다."
		staff.say_t = 2.5
		return
	_warn_t += 0.5
	if _warn_t >= WARN_SECS:
		_side(staff, false)
		staff.say_text = "무임승차입니다."
		staff.say_t = 2.0


# ---------------------------------------------------------------- 하루 판정 · 맵
func _on_day(_d: int) -> void:
	if v("SQ_S05_JU") == 2 and day() >= v("SQ_S05_JU_AT") + JU_DAYS:
		_ju_quit()
	elif v("SQ_S05_AWAY") == 1 and v("SQ_S05_JU") != 2:
		_sv("SQ_S05_AWAY", 0)                                             # 주성호가 봉천 노점에 돌아왔다(한 사람 한 곳, P3)


func _on_map(_id: String) -> void:
	guests.clear()
	staff = null
	sleeper = null
	_warn_t = -1.0
	_asked = false
	proc = {}
	if host.map == null:
		return
	var z := _zone()
	if z.begins_with("D-0") and stage() == 0 and (v("SA_MAKCHA_HEARD") >= 1 or v("SD_BOARD_SEEN") >= 1):
		_start("이미 앎")
	match z:
		"D-06":
			if _solved():
				host.map.set_prop_state(GATE_D06, "open")
		"D-03":
			if _solved() and v("SQ_S05_REPORT") == 0 and st.is_dead("N-R01-041"):
				host.hint("서랍 위에 위원회 쪽지. '서쪽 터널 — 고맙다. 몫은 서랍에. 역무 위원회.'", 6.0)
				_report()                                                   # 허순자가 없으면 위원회가 대신(SD-20 P3)
		"U-01":
			_enter_u01()
		"U-02":
			_enter_u02()
		"U-03":
			_rats("U-03", 2, ["r1", "r2"], [])


func _rats(_m: String, bit: int, rats: Array, roaches: Array) -> void:
	if v("SQ_S05_RAT") & bit != 0:
		return
	_sv("SQ_S05_RAT", v("SQ_S05_RAT") | bit)
	for k in rats:
		host.combat.spawn("CR-095", host.map.mark_pos(k), host.map, st, {"lv": 2, "dir": host.map.mark_dir(k)})
	for k in roaches:
		host.combat.spawn("CR-002", host.map.mark_pos(k), host.map, st, {"lv": 1, "dir": host.map.mark_dir(k)})


func _enter_u01() -> void:
	_sv("SQ_S05_IN", 1)
	_start("서쪽 터널")
	_catch_up()
	_rats("U-01", 1, ["r1", "r2"], ["x1", "x2"])
	if v("SQ_S05_ROBOT") != 0:
		_drop_prop(ROBOT_U01)
	if v("SQ_S05_SLEEPER") == 0 and not _solved():                       # 재미 검수 1: 철망 발소리의 주인 — 두 걸음 걷고 멈춘다
		var p := host.map.mark_pos("sleeper")
		var c := host.map.tile_of(p)
		sleeper = host.combat.spawn("CR-204", p, host.map, st, {"doze": "stand", "sheet": SHEETS[1], "dir": "W", "lv": 3, "arm": "claw",
			"team": "enemy_s05", "route": [[c.x, c.y, 5.0], [c.x - 2, c.y, 6.0]]})
		sleeper.set_meta("s05s", 1)


func _enter_u02() -> void:
	if stage() == 0:                                                       # 순서 파괴: 서울대입구 쪽에서 먼저 왔다 — 10 → 40
		_sv("SQ_S05_IN", 1)
		_start("낙성대 승강장")
	if _masked():
		_sv("SQ_S05_MASK", 1)
	if v("SQ_S05_DOOR") == 1:
		host.map.set_prop_state(IRON_U02, "open")
	if v("SQ_S05_SOL") == 1:
		host.map.set_prop_state(SIDING_U02, "open")
	if v("SQ_S05_BCAST") > 0 and v("SQ_S05_LINE") == 0 and _now() >= v("SQ_S05_BCAST_AT") + LINE_MIN:
		_line_offscreen()
	var awake := v("SQ_S05_WOKE") > 0 and _now() < v("SQ_S05_WOKE") + RESLEEP_MIN
	if not awake:
		_sv("SQ_S05_WOKE", 0)
	var r := RandomNumberGenerator.new()
	r.seed = hash("s05pose:%d" % day())
	for i in GUESTS:
		if _gone(i):
			continue
		var m := "g%d" % (i + 1)
		var o := {"sheet": SHEETS[i % 3], "dir": host.map.mark_dir(m), "lv": 3, "arm": "claw", "team": "enemy_s05"}
		if not awake:
			o["doze"] = "lie" if r.randf() < 0.3 else "sit"                 # 휴면 자세: 앉음이 많고 누운 이가 섞인다(매일 다르게)
		var e := host.combat.spawn("CR-204", host.map.mark_pos(m), host.map, st, o)
		e.set_meta("s05g", i)
		e.wake_cb = _cluster_wake
		guests.append(e)
	if v("SQ_S05_LEFT") & STAFF_BIT == 0:
		var a := host.map.tile_of(host.map.mark_pos("st1"))
		var b := host.map.tile_of(host.map.mark_pos("st2"))
		staff = host.combat.spawn("CR-205", host.map.mark_pos("st1"), host.map, st, {"sheet": "en_cr205_loco", "dir": "S", "lv": 4, "arm": "baton",
			"team": "calm_s05", "foes": [], "route": [[a.x, a.y, 4.0], [b.x, b.y, 4.0], [30, 8, 3.0], [b.x, b.y, 3.0]]})
		staff.set_meta("s05st", 1)
	if v("SQ_S05_JU") == 2 and not host.combat.mates.get_mate(JU_ID).is_empty():
		_ju_speak()
	elif v("SQ_S05_BCAST") > 0 and v("SQ_S05_LINE") == 0:
		_line_start()


## 하나가 깨면 승강장 무리가 한꺼번에(SD-14 '일제 기상') · 깬 시각(여섯 시간 뒤 다시 앉는다)
func _cluster_wake(e: Enemy) -> void:
	if v("SQ_S05_WOKE") == 0:
		_sv("SQ_S05_WOKE", _now())
		_log("군집 깸")
		if not _masked():
			host.hint("벤치의 손님들이 한꺼번에 고개를 든다.", 3.0)
	for o in guests:
		if is_instance_valid(o) and o != e and o.asleep and o.loco.logical.distance_to(e.loco.logical) <= 10.0 * 32.0:
			o.wake()


func _on_provoked(team: String) -> void:
	if team == "calm_s05":
		_sv("SQ_S05_HOT", 1)


func _on_down(e: Enemy) -> void:
	if not e.cmb.dead:
		return
	if e.has_meta("s05g"):
		_set_gone(int(e.get_meta("s05g")))
		guests.erase(e)
	elif e.has_meta("s05st"):
		_sv("SQ_S05_LEFT", v("SQ_S05_LEFT") | STAFF_BIT)
	elif e.has_meta("s05s"):
		_sv("SQ_S05_SLEEPER", 1)
	else:
		return
	if _left_count() == 0 and v("SQ_S05_LEFT") & STAFF_BIT != 0 and not _solved():
		_resolve(2, "소탕")                                                # B: 카르마 0 · 보고 때 SA +8


func _drop_prop(c: Vector2i) -> void:
	for p in host.map.props.duplicate():
		if int(p["x"]) == c.x and int(p["y"]) == c.y and p.has("node"):
			host.map.remove_runtime_prop(p)


# ---------------------------------------------------------------- A 막차 방송 → 행렬
## 24시간 안에 승강장에 처음 내려왔다: 손님들이 일어나 한 줄로 측선에 들어간다(30초 남짓, 아무도 공격하지 않는다)
func _line_start() -> void:
	if not proc.is_empty() or v("SQ_S05_LINE") != 0:
		return
	var q: Array = []
	for e in guests.duplicate():
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		var i := int(e.get_meta("s05g"))
		var id := "S5G%d" % i
		var at: Vector2 = e.loco.logical
		var dir := "W"
		host.combat.drop_enemy(e)
		guests.erase(e)
		host.ev._show_actor(id, at, dir, SHEETS[i % 3])
		q.append([at.x, i])
	q.sort_custom(func(a, b): return a[0] < b[0])                     # 측선(서쪽)에 가까운 손님부터
	proc = {"q": q.map(func(x): return x[1]), "walk": {}, "t": PROC_GAP, "n0": q.size(), "in": 0, "broke": 0, "staff": false,
		"shots": int(host.combat.stats.get("shots", 0))}
	host.map.set_prop_state(SIDING_U02, "open")
	host.hint("확성기 안내가 승강장 끝까지 번진다. 벤치의 손님들이 하나씩 일어선다.", 5.0)
	_log("행렬 시작 %d" % q.size())


func _proc_tick(dt: float) -> void:
	if host.map == null or _zone() != "U-02":
		proc = {}
		return
	var loud: bool = host.combat.pc.movement == "sprint" or int(host.combat.stats.get("shots", 0)) > int(proc["shots"])
	if loud:                                                               # 재미 검수 3: 아직 측선에 들지 않은 손님은 깨어 적대한다
		_proc_break()
		return
	proc["t"] = float(proc["t"]) + dt
	var q: Array = proc["q"]
	if not q.is_empty() and float(proc["t"]) >= PROC_GAP:
		proc["t"] = 0.0
		var i: int = q.pop_front()
		var id := "S5G%d" % i
		host.ev.run("go", [id, "siding"], func() -> void: pass)
		(proc["walk"] as Dictionary)[id] = i
	var walk: Dictionary = proc["walk"]
	for id in walk.keys():
		var a: Actor = host.ev.actors.get(id)
		if a == null or a.loco.logical.distance_to(host.map.mark_pos("siding")) < 20.0:
			host.ev.run("hide", [id], func() -> void: pass)
			_set_gone(int(walk[id]))
			walk.erase(id)
			proc["in"] = int(proc["in"]) + 1
	if q.is_empty() and walk.is_empty():
		if is_instance_valid(staff) and not staff.cmb.dead and not bool(proc["staff"]):
			proc["staff"] = true                                           # 행렬 끝 역무원: 한 줄을 남기고 맨 마지막에
			var at := staff.loco.logical
			host.combat.drop_enemy(staff)
			staff = null
			host.ev._show_actor("S5ST", at, "W", "en_cr205_loco")
			host.hint("역무원: \"승차권을 확인합니다.\" — 그리고 맨 마지막에 측선으로 들어간다.", 5.0)
			host.ev.run("go", ["S5ST", "siding"], func() -> void: pass)
			walk["S5ST"] = -1
			return
		_proc_end()


func _proc_break() -> void:
	var walk: Dictionary = proc["walk"]
	var rest: Array = (proc["q"] as Array).duplicate()
	for id in walk.keys():
		if int(walk[id]) >= 0:
			rest.append(int(walk[id]))
	for i in rest:
		var id := "S5G%d" % int(i)
		var a: Actor = host.ev.actors.get(id)
		var at: Vector2 = a.loco.logical if a != null else host.map.mark_pos("g%d" % (int(i) + 1))
		host.ev.run("hide", [id], func() -> void: pass)
		var e := host.combat.spawn("CR-204", at, host.map, st, {"sheet": SHEETS[int(i) % 3], "dir": "E", "lv": 3, "arm": "claw", "team": "enemy_s05"})
		e.set_meta("s05g", int(i))
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
		guests.append(e)
	proc["broke"] = rest.size()
	proc["q"] = []
	proc["walk"] = {}
	_sv("SQ_S05_WOKE", _now())
	host.hint("총성 — 줄이 흩어진다. 아직 측선에 들지 못한 손님들이 이쪽을 돌아본다.", 4.0)
	_log("행렬 깨짐 %d" % rest.size())
	_proc_end()


func _proc_end() -> void:
	var n0 := maxi(1, int(proc["n0"]))
	var gone_in := int(proc["in"])
	if bool(proc.get("staff", false)):
		_sv("SQ_S05_LEFT", v("SQ_S05_LEFT") | STAFF_BIT)
		gone_in = maxi(0, gone_in - 1)
	_sv("SQ_S05_LINE", 1)
	st.call_fn("karma", [roundi(100.0 * float(gone_in) / float(n0))])     # 카르마 +100 × 들어간 비율(재미 검수 3)
	proc = {}
	if gone_in > 0:
		_resolve(1, "막차 방송")
	host.hint("측선 셔터 아래, 바닥에 2077년 승차권이 몇 장 떨어져 있다.", 5.0)


## 24시간이 지나도록 내려가지 않았다: 결과만(P6 — 날마다 하나씩, 그 사이 일은 없다)
func _line_offscreen() -> void:
	if v("SQ_S05_LINE") != 0:
		return
	var n := _left_count()
	for i in GUESTS:
		_set_gone(i)
	_sv("SQ_S05_LEFT", v("SQ_S05_LEFT") | STAFF_BIT)
	_sv("SQ_S05_LINE", 2)
	if n > 0:
		st.call_fn("karma", [100])
		_resolve(1, "막차 방송(결과만)")


# ---------------------------------------------------------------- C 구울의 말(주성호 일시 동행)
func _ju_speak() -> void:
	if v("SQ_S05_JU") != 2:
		return
	var q: Array = []
	for e in guests.duplicate():
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		var i := int(e.get_meta("s05g"))
		if not _bongcheon(i):
			continue
		var at: Vector2 = e.loco.logical
		host.combat.drop_enemy(e)
		guests.erase(e)
		var id := "S5G%d" % i
		host.ev._show_actor(id, at, "E", SHEETS[i % 3])
		q.append(id)
		_set_gone(i)
	host.hint("주성호: \"막차 끊겼어요. 다들 집에 가요.\"", 5.0)
	var k := 0
	for id in q:
		host.ev.run("go", [id, "42,6"], func() -> void: pass)
		k += 1
	_sv("SQ_S05_JU", 3)
	_sv("SQ_S05_JU_AT", day())
	st.call_fn("karma", [50])
	st.call_fn("aff", ["JH", 3])
	_resolve(3, "구울의 말")
	host.combat.mates.remove(JU_ID)
	host._sync_mates()
	if host.ev.actors.has(JU_ID):
		host.ev.run("go", [JU_ID, "42,6"], func() -> void: pass)
	host.hint("봉천행 표를 쥔 손님 %d명이 계단 쪽으로 걸어간다. 주성호도 그 뒤를 따라 봉천으로 돌아간다." % k, 6.0)
	_hide_later(q + [JU_ID])


func _hide_later(ids: Array) -> void:
	if is_inside_tree():
		await get_tree().create_timer(9.0).timeout
	for id in ids:
		if host.ev.actors.has(id):
			host.ev.run("hide", [id], func() -> void: pass)


## 주성호가 기다리다 돌아간다(이틀) — 반쯤 된 상태 없이 처음으로(P10). 다시 부탁할 수 있다
func _ju_quit() -> void:
	_sv("SQ_S05_JU", 0)
	_sv("SQ_S05_AWAY", 1)
	host.combat.mates.remove(JU_ID)
	host.combat.mates.away.erase(JU_ID)
	host._sync_mates()
	if host.ev.actors.has(JU_ID):
		host.ev.run("hide", [JU_ID], func() -> void: pass)
	host.hint("주성호가 남긴 말: '장사 이틀 망쳤네. 난 봉천 간다. 다시 부르려면 노점으로.'", 6.0)


# ---------------------------------------------------------------- 원고 명령(@cmd s05 …)
func _cmd(a: Array, done: Callable) -> void:
	var what := str(a[0]) if a.size() > 0 else ""
	match what:
		"heard":                                                           # 철망 발소리 · 철망 문 경고(문 경고 표지 GATE는 원고가 세운다) — 단계 20
			_start("철망")
		"fence":
			_sv("SQ_S05_FENCE", v("SQ_S05_FENCE") + 1)
		"bseen":
			_sv("SQ_S05_BSEEN", 1)
			_catch_up()
		"go":
			var to := str(a[1]) if a.size() > 1 else ""
			var mk := str(a[2]) if a.size() > 2 else ""
			done.call()
			host.go.call_deferred(to, mk)
			return
		"drag":                                                            # [힘 5] 끌기: 삼십 분이 흐른다
			_sv("SQ_S05_ROBOT", 2)
			if _zone() == "U-01":
				_drop_prop(ROBOT_U01)
			host.advance_minutes(30)
		"wake":                                                            # [수리 25] + 진공관: 스스로 사당으로 걸어간다
			_sv("SQ_S05_ROBOT", 2)
			if _zone() == "U-01":
				_drop_prop(ROBOT_U01)
				host.ev._show_actor("S5RB", Vector2(ROBOT_U01.x * 32 + 16, ROBOT_U01.y * 32 + 16), "E", "rb_cr306_loco")
				host.ev.run("go", ["S5RB", "from_E"], func() -> void: pass)
				_hide_later(["S5RB"])
		"broadcast":                                                       # 1 혼자(무단 — 허순자가 따로 꾸중) · 2 허순자가 스위치를
			if v("SQ_S05_BCAST") == 0:
				_sv("SQ_S05_BCAST", int(a[1]) if a.size() > 1 else 1)
				_sv("SQ_S05_BCAST_AT", _now())
				_hour_said = Clock.hour(host.date_text)
				_sv("SQ_S05_BSEEN", 1)
				_start("방송")
				_log("방송 %d" % v("SQ_S05_BCAST"))
		"door":
			_sv("SQ_S05_DOOR", 1)
			if _zone() == "U-02":
				host.map.set_prop_state(IRON_U02, "open")
			for e in guests:                                               # 빗장 쇳소리: 승강장 끝까지 울린다(문소리)
				if is_instance_valid(e):
					e.hear("door", e.loco.logical)
		"water":                                                           # 위원회 물통에 물 한 통(재미 검수 2)
			for id in ["I-054", "I-055", "I-056", "I-057"]:
				if bool(st.call_fn("has", [id])):
					st.call_fn("take", [id, 1])
					break
		"lend":
			_sv("SQ_S05_PASS", 1)
			_from_drawer()
			st.call_fn("give", ["M-071", 1])
		"ju":
			_sv("SQ_S05_JU", 2)
			_sv("SQ_S05_JU_AT", day())
			_sv("SQ_S05_AWAY", 1)
			_ju_join()
		"report":
			_report()
		"pyo":
			_sv("SQ_S05_PYO", 1)
			st.call_fn("give", ["I-044", 5])
	done.call()


func _ju_join() -> void:
	host._bring_buddy(JU_ID)
	host.refresh_npcs()


## 정기권은 한 장뿐(P1): 서랍에서 꺼내 준다 — 서랍 상자의 그 한 장을 지운다
func _from_drawer() -> void:
	var b := {"x": 5, "y": 6, "w": 1, "h": 1, "kind": "sd_drawer", "owner": "N-R01-041", "name": "역무실 서랍"}
	var c: Dictionary = Loot.contents(st, "D-03", b, "r01")
	(c["items"] as Dictionary).erase("M-071")


## 보고(허순자 — 없으면 위원회 쪽지): 100 · XP 300 · 100캡 · 정기권(없으면, 있으면 30캡) · 노선도 서쪽 칸 · SA(A +12 · B +8 · C +10)
func _report() -> void:
	if v("SQ_S05_REPORT") == 1:
		return
	_sv("SQ_S05_REPORT", 1)
	_start("보고")
	_up(100)
	st.call_fn("xp", [300])
	st.call_fn("caps", [100])
	if _ticket():
		st.call_fn("caps", [30])
	else:
		var b := {"x": 5, "y": 6, "w": 1, "h": 1, "kind": "sd_drawer", "owner": "N-R01-041", "name": "역무실 서랍"}
		var c: Dictionary = Loot.contents(st, "D-03", b, "r01")
		if (c["items"] as Dictionary).has("M-071"):
			(c["items"] as Dictionary).erase("M-071")
			st.call_fn("give", ["M-071", 1])
		else:
			st.call_fn("caps", [30])                                       # 정기권이 이미 세상 어딘가에 있다(팔았거나 떨어뜨림) — 둘이 되지 않게
	_sv("SD_MAP_UG", 2)
	st.call_fn("aff", ["SA", {1: 12, 2: 8, 3: 10}.get(v("SQ_S05_SOL"), 8)])
	_sv("SQ_S05_REWARD", 1)
	_log("보고(해법 %d)" % v("SQ_S05_SOL"))


func _deed(tag: String, fx: Dictionary, what: String) -> void:
	st.deeds.record(st, "side", "R01", 1, fx, Clock.abs_min(host.date_text), {"tag": tag, "place": "SA", "what": what, "seen_by": ["JC_SA"], "about": []})
