## 관악(R01) 사이드 퀘스트 SQ-S02 「물 반 컵의 값」 진행기(단계 1-11b, SD-04a §4.2). 원고: script/act1/SQ-S02.txt · MQ-101.txt X-BC_BOARD · SAGOGAE.txt SG_HWANG.
## 발동: MQ-101 끝난 다음 날 06시 조수안이 반상회 게시판에 '급수 제한' 쪽지(POSTED) — 쪽지를 읽거나 조수안과 말하면 단계 10. 척후 지도(M-301)를 먼저 쥐면 단계 40부터.
## 사실은 변수 한 곳(SD-20 P1): SQ_S02_SOL 밸브 해법(1 탈환 · 2 우회 관로 · 4 계엄군 · 3 두목은 신림 고시촌과 함께) · OPEN 밸브가 열림 · PAID 물값을 낸 끝 날 ·
##   LEVEL 수위계(5칸, 하루 한 칸) · CAMP 밸브 캠프가 빔 · B 우회 관로를 이음 · BJ 밸브가 계엄사령부 관리 · MAP 척후 지도 · HAND 글씨 대조 · KNOW 남건희를 앎 · IN 내부자 처리.
## 장소: 봉천 배수지(X-BS · K-32 밸브실) · 삼성산 능선 캠프(X-SS — 상류 밸브, 약탈자 ×4 + 경비견) · 낙성대 고개 캠프(X-NS — 사이렌 + 척후 ×4) · 관악 계곡 배수로(K-08 이음 지점 둘).
## 큰 사건(계엄군 분대 · 03시 습격)은 정한 시각이 지나도 대화 · 교전 중이면 안전한 순간까지 미룬다(SD-20 P5). 주인공이 그 자리에 없으면 결과만 남긴다(P10 — 반쯤 된 상태 없음).
class_name SideS02
extends Node

const CAMP_R := 40.0                     ## 캠프를 세우는 거리(칸)
const DESPAWN_R := 60.0
const NEAR_R := 30.0                     ## 단계 30 '밸브실 반경 30타일'
const TOLL_R := 9.0                      ## 수금원이 외치는 거리
const HOT_R := 2.5                       ## 물값을 안 내고 밸브에 붙으면 싸움
const SIREN_TALK := 6.0
const NIGHT_SEE := 8.0                   ## 남건희 미행: 이만큼 안에서 지켜보면 본다
const NIGHT_SPOT := 3.0                  ## 쪼그리지 않고 이만큼 다가가면 들킨다
const BC_CENTER := Vector2i(892, 1362)   ## 봉천(X-BC) 중심 — 밤 습격 RE 배수(Encounters.cat_mult)
const BC_R := 45
const RIDGE := Vector2i(868, 1581)      ## 삼성산 능선 캠프(L-R01-31) — 외눈 무리가 옮긴 뒤 약탈자 매복 −25%(SQ-S01 후일담, Encounters.cat_mult)
const RIDGE_R := 40
const TRAP_GUARDS := [["N-R01-035", "land1"], ["N-R01-028", "land2"], ["N-R01-036", "land3"]]   ## 03시 함정: 감시조 셋(계단참 ①②③)
const TRAP_FROM := ["sbf1", "sbf2", "sbf3", "doksaf", "sb1", "sb2"]
const WATER := ["I-054", "I-055", "I-056", "I-057"]

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var camp: Array = []                     ## 밸브 캠프(수금원 포함)
var toller: Enemy = null                 ## 수금원(N-YT-1)
var camp_on := false
var _toll_said := false
var scouts: Array = []                   ## 낙성대 캠프(사이렌 포함)
var siren: Enemy = null
var scouts_on := false
var _siren_said := false
var valve_props: Array = []
var _valve_look := ""
var night_on := false                    ## 남건희 · 척후가 윗문에 서 있다
var _night_said := false
var trap_on := false
var trap_foes: Array = []
var _trap_near := 0
var _trap_n := 0
var squad: Array = []                    ## 계엄군 분대(D, 주인공이 그 자리에 있을 때)
var _squad_t := -1.0
var _with_bj := false
var _hr_band := -1
var _map_ref: InteriorMap = null


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s02"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.enemy_killed.connect(_on_killed)
	host.combat.resident_down.connect(_on_resident_down)
	host.combat.provoked.connect(_on_provoked)


## 조용히 지켜보던 패거리를 주인공이 쳤다: 그 캠프는 이제 적대(캠프가 비거나 새 분대가 들 때까지)
func _on_provoked(team: String) -> void:
	if team == "calmss":
		st.vars.set_v("SQ_S02_HOT", 1)
	elif team == "calmns":
		st.vars.set_v("SQ_S02_NS_HOT", 1)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[물 반 컵] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S02")


func hour() -> int:
	return Clock.hour(host.date_text)


func _now() -> int:
	return Clock.abs_min(host.date_text)


func _safe() -> bool:
	return not host.box.active and not host.ev.busy() and not host.busy and not host.combat.in_combat()


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S02", n)
		_log("단계 %d" % n)


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _near(mark: String, r: float) -> bool:
	return host.map is WorldMap and host.player.loco.logical.distance_to(host.map.mark_pos(mark)) <= r * 32.0


func _dist(mark: String) -> float:
	return host.player.loco.logical.distance_to(host.map.mark_pos(mark)) / 32.0


## 다음 h시 정각(절대 분) — 지금부터 적어도 gap분 뒤
func _next_at(h: int, gap: int) -> int:
	var a := _now()
	var t := a - posmod(a, 1440) + h * 60
	while t < a + gap:
		t += 1440
	return t


## 봉천이 알게 되는 일(공개도 2, 봉천 안 소문 — SD-06 §6). 봉천에 돌아오면 그 자리에서 닿는다(물이 다시 흐르는 걸 마을이 본다)
func _deed(tag: String, fx: Dictionary, what: String, seen: Array = [], about: Array = []) -> void:
	st.deeds.record(st, "side", "R01", 2, fx, _now(), {"tag": tag, "place": "BC", "what": what, "seen_by": seen, "about": about})
	if _zone() == "X-BC":
		st.deeds.tell(st, tag, "JC_BC", _now())


# ---------------------------------------------------------------- 매 0.25초
func _process(dt: float) -> void:
	if host.map == null:
		return
	if _squad_t > 0.0:
		_squad_t = maxf(0.0, _squad_t - dt)
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	tick()


func tick() -> void:
	_facts()
	if v("V_ACT") < 1:
		return
	if host.map is WorldMap:
		_camp_tick()
		_siren_tick()
		_bc_tick()
		_bj_tick()
		_valve_look_tick()
	elif _zone() == "K-32":
		_gauge()
	elif _zone() == "K-08":
		_joint_at()
	if not (host.map is WorldMap and _zone() == "X-BC") and v("SQ_S02_TRAP_AT") > 0 and v("SQ_S02_TRAP_DONE") == 0 and _now() >= v("SQ_S02_TRAP_AT"):
		_trap_away()                                                       # 03시에 봉천에 없었다: 감시조가 막는다(결과만)


## 사실 맞추기: 쪽지 · 수위 · 물값 기한 · 척후 지도 · 7일 묵인
func _facts() -> void:
	if st.quests.stage("MQ-101") >= 100 and v("SQ_S02_ARM") == 0:
		st.vars.set_v("SQ_S02_ARM", day())                                  # MQ-101이 끝난 날(다음 날 06시 발동)
	if v("SQ_S02_PAID") > 0 and day() >= v("SQ_S02_PAID"):
		st.vars.set_v("SQ_S02_PAID", 0)                                     # 사흘이 지났다 — 패거리가 다시 잠갔다(해법 E는 미룰 뿐)
		st.vars.set_v("SQ_S02_DAY0", day())
		if v("SQ_S02_OPEN") == 2:
			st.vars.set_v("SQ_S02_OPEN", 0)
		host.hint("관 속 물소리가 끊겼다. 패거리가 밸브를 다시 잠갔다.", 5.0)
		_log("물값 기한 끝 — 다시 잠김")
	st.vars.set_v("SQ_S02_LEVEL", level())
	if st.count_of("M-301") > 0 and v("SQ_S02_MAP") == 0:
		st.vars.set_v("SQ_S02_MAP", 1)
		if stage() < 70:
			_up(40)                                                         # 순서 파괴: 지도를 먼저 쥐면 단계 40부터(SD-04a §4.2 발동)
		host.hint("패거리 척후 지도 — 핍-보이 잡화에서 살펴볼 수 있다", 5.0)
	var s := stage()
	if s >= 70 and s < 100:
		var inn := v("SQ_S02_IN")
		if inn in [1, 2] or (inn == 3 and v("SQ_S02_TRAP_DONE") == 1):
			_finish("내부자 %d" % inn)
		elif day() >= v("SQ_S02_DONE_DAY") + 7 and not trap_on:
			if inn == 0:
				st.vars.set_v("SQ_S02_IN", 4)                               # d 묵인: 7일 뒤 자동 종료 — 봉천 밤 습격 RE +20%(척후가 정확해진다)
			_finish("7일")


## 수위계 칸(0~5): 쪽지 전 · 밸브가 열림 · 물값 기간은 5. 닫힌 날부터 하루 한 칸 — 첫날 4, 닷새째 0(물값 2배)
func level() -> int:
	if v("SQ_S02_POSTED") == 0 or v("SQ_S02_OPEN") != 0:
		return 5
	return clampi(4 - (day() - v("SQ_S02_DAY0")), 0, 5)


func _finish(why: String) -> void:
	if stage() >= 100:
		return
	st.vars.set_v("SQS02_RESULT", v("SQ_S02_SOL"))
	st.quests.set_stage("SQ-S02", 100)
	st.call_fn("xp", [350])
	_log("SQ-S02 끝(%s · 해법 %d · 내부자 %d)" % [why, v("SQ_S02_SOL"), v("SQ_S02_IN")])


## 밸브 해법 하나가 섰다(겹쳐도 된다 — SOL은 처음 것). 단계 70 · 봉천 거처 '문제 해결'(SD-04a §2.5)
func _solved(sol: int) -> void:
	if v("SQ_S02_SOL") == 0:
		st.vars.set_v("SQ_S02_SOL", sol)
	st.vars.set_v("SQ_S02_OPEN", 1)
	st.vars.set_v("SQ_S02_PAID", 0)
	if st.vars.has("JC_PROB_BC"):
		st.vars.set_v("JC_PROB_BC", 1)
	if stage() < 70:
		_up(70)
		st.vars.set_v("SQ_S02_DONE_DAY", day())
	st.vars.set_v("SQ_S02_LEVEL", 5)


# ---------------------------------------------------------------- 하루 판정(06:00)
func _on_day(d: int) -> void:
	if v("SQ_S02_ARM") > 0 and d > v("SQ_S02_ARM") and v("SQ_S02_POSTED") == 0 and v("V_ACT") >= 1:
		st.vars.set_v("SQ_S02_POSTED", 1)                                  # 조수안의 '급수 제한' 쪽지 · 상류 밸브가 잠긴 첫날
		st.vars.set_v("SQ_S02_DAY0", d)
		for k in ["SQ_S02_CAMP", "SQ_S02_CKILLS", "SQ_S02_TDEAD", "SQ_S02_DDEAD", "SQ_S02_HOT"]:
			st.vars.set_v(k, 0)                                           # '또 잠겼어': 비워 둔 캠프에도 새 분대가 든다(SD-20 — 먼저 턴 캠프와 모순 없음)
		_log("급수 제한 쪽지(%d일)" % d)
	if level() == 0 and v("SQ_S02_DRY_HINT") == 0 and v("SQ_S02_POSTED") == 1:
		st.vars.set_v("SQ_S02_DRY_HINT", 1)
		if _zone() in ["X-BC", "X-BS", "K-32"]:
			host.hint("봉천 배수지 수위계가 붉은 띠 아래로 내려갔다. 오늘부터 물값이 두 배다.", 6.0)


# ---------------------------------------------------------------- 밸브 캠프(삼성산 능선 X-SS)
func _rng(tag: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s:%d:%d" % [tag, _now() / 60, v("SQ_S02_CKILLS")])   # 같은 때 다시 오면 같은 자리 — 때가 바뀌면 다른 수 · 방향 · 자리(SD-22)
	return r


func _spot(mark: String, r: RandomNumberGenerator, rx := 2, ry := 1) -> Vector2:
	var c0: Vector2i = host.map.tile_of(host.map.mark_pos(mark))
	for _i in 20:
		var c := c0 + Vector2i(r.randi_range(-rx, rx), r.randi_range(-ry, ry))
		if not host.map.is_solid(c):
			return Vector2(c.x * 32 + 16, c.y * 32 + 16)
	return host.map.mark_pos(mark)


func _calm(e: Enemy, team: String) -> void:
	e.cmb.team = team
	e.foes.clear()


func _hostile(list: Array, team: String, extra: Array = []) -> void:
	for e in list:
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		e.cmb.team = team
		e.foes = ["player", "ally"] + extra
		e.wake()
		e.brain.gauge = 100.0


func _camp_tick() -> void:
	var d := _dist("X-SS:valve")
	if d <= CAMP_R and not camp_on:
		_spawn_camp()
	elif d > DESPAWN_R and camp_on and not host.combat.in_combat():
		_clear(camp)
		toller = null
		camp_on = false
	if stage() >= 10 and stage() < 30 and d <= NEAR_R:
		_up(30)                                                             # 밸브실 앞에 패거리가 있다
	if not camp_on or v("SQ_S02_CAMP") == 1:
		return
	if not _toll_said and v("SQ_S02_POSTED") == 1 and v("SQ_S02_OPEN") != 1 and is_instance_valid(toller) and not toller.cmb.dead and toller.cmb.team.begins_with("calm") and _safe() \
			and host.player.loco.logical.distance_to(toller.loco.logical) <= TOLL_R * 32.0:
		_toll_said = true
		host.play_scene("SQS02_TOLL")
	if _toll_said and v("SQ_S02_OPEN") == 0 and d <= HOT_R and _safe() and _calm_camp():
		_hostile(camp, "enemyss")                                           # 말했지 — 물값 없이 밸브에 손을 댄다
		st.vars.set_v("SQ_S02_HOT", 1)
		host.hint("수금원: '말했지!' 패거리가 총을 든다.", 4.0)
		_log("밸브 캠프 적대")


func _calm_camp() -> bool:
	for e in camp:
		if is_instance_valid(e) and not e.cmb.dead and e.cmb.team.begins_with("calm"):
			return true
	return false


func _spawn_camp() -> void:
	camp_on = true
	_toll_said = false
	camp.clear()
	toller = null
	_box_map()
	if v("SQ_S02_CAMP") == 1:
		return
	var r := _rng("SS")
	var night := hour() >= 22 or hour() < 5
	if v("SQ_S02_TDEAD") == 0:
		toller = host.combat.spawn("CR-421", _spot("X-SS:valve_front", r, 1, 0), host.map, st, {"lv": r.randi_range(5, 7), "who": "N-YT-1", "sheet": "en_cr421_loco", "dir": "S", "stance": "hold"})
		camp.append(toller)
	var kinds := ["CR-420", "CR-421", "CR-423"]
	var spots := ["X-SS:camp1", "X-SS:camp2", "X-SS:camp3", "X-SS:camp4"]
	for i in maxi(0, 3 - v("SQ_S02_CKILLS")):
		var opts := {"lv": r.randi_range(4, 8), "dir": ["N", "S", "E", "W"][r.randi() % 4]}
		if night and r.randf() < 0.5:
			opts["sleep"] = true                                         # 밤: 불 드럼 곁에서 존다(수금원은 깨어 있다)
		camp.append(host.combat.spawn(str(kinds[r.randi() % 3]), _spot(str(spots[r.randi() % 4]), r), host.map, st, opts))
	if v("SQ_S02_DDEAD") == 0:
		camp.append(host.combat.spawn("CR-107", _spot("X-SS:dog", r), host.map, st, {"lv": 4, "dir": "N"}))
	var calm := v("SQ_S02_POSTED") == 1 and v("SQ_S02_HOT") == 0 and v("SQ_S02_B") == 0   # 밸브를 잠근 뒤: 먼저 쏘지 않으면 수금원이 말을 건다(그 전 · 우회 관로 뒤엔 그냥 패거리 캠프)
	for e in camp:
		e.set_meta("s02_role", "toller" if e == toller else ("dog" if str(e.get_meta("enemy_id", "")) == "CR-107" else "raider"))
		if calm:
			_calm(e, "calmss")
	_log("밸브 캠프 %d(%d시)" % [camp.size(), hour()])


## 캠프 상자(scout_cache): 척후 지도가 아직 아무 손에도 없으면 상자에 넣고, 다른 데서 쥐었으면 뺀다(지도는 한 장 — SD-20 P3)
func _box_map() -> void:
	var c0: Vector2i = host.map.tile_of(host.map.mark_pos("X-SS:camp"))
	for c in host.map.boxes.keys():
		var b: Dictionary = host.map.boxes[c]
		if str(b.get("kind", "")) != "scout_cache" or absi(c.x - c0.x) > 12 or absi(c.y - c0.y) > 12:
			continue
		var bx := host.box_contents(b)
		var items: Dictionary = bx.get("items", {})
		if v("SQ_S02_MAP") == 0 and int(bx.get("s02", 0)) == 0:
			items["M-301"] = 1
			bx["s02"] = 1
		elif v("SQ_S02_MAP") == 1 and int(bx.get("s02", 0)) == 1 and items.has("M-301"):
			items.erase("M-301")
		bx["items"] = items


func _clear(list: Array) -> void:
	for e in list:
		if is_instance_valid(e) and not e.cmb.dead:
			host.combat.drop_enemy(e)
	list.clear()


func _on_killed(_eid: String, _alive: int) -> void:
	for e in camp.duplicate():
		if is_instance_valid(e) and e.cmb.dead and not e.has_meta("s02_dead"):
			e.set_meta("s02_dead", true)
			match str(e.get_meta("s02_role", "")):
				"toller":
					st.vars.set_v("SQ_S02_TDEAD", 1)
				"dog":
					st.vars.set_v("SQ_S02_DDEAD", 1)
				_:
					st.vars.set_v("SQ_S02_CKILLS", v("SQ_S02_CKILLS") + 1)
			if not squad.is_empty() and e.cmb.last_by == "player":
				_with_bj = true                                             # 계엄군 분대와 함께 싸웠다(BJ '함께 싸움' +2)
	if camp_on and v("SQ_S02_CAMP") == 0 and v("SQ_S02_TDEAD") == 1 and v("SQ_S02_DDEAD") == 1 and v("SQ_S02_CKILLS") >= 3:
		st.vars.set_v("SQ_S02_CAMP", 1)
		host.hint("밸브 캠프가 조용해졌다. 사슬 감긴 밸브만 남았다.", 5.0)
		_log("밸브 캠프 빔")
		if not squad.is_empty():
			_bj_done(true)
	for e in scouts.duplicate():
		if is_instance_valid(e) and e.cmb.dead and not e.has_meta("s02_dead"):
			e.set_meta("s02_dead", true)
			if e == siren:
				st.vars.set_v("SQ_S02_SIREN", 2)
				st.kill("N-R01-062")
				_siren_drop(e)
			else:
				st.vars.set_v("SQ_S02_NKILLS", v("SQ_S02_NKILLS") + 1)


# ---------------------------------------------------------------- 밸브 그림(월드 청크에 굽지 않고 진행기가 세운다: 잠김 · 열림 · 계엄사령부 표지)
func _valve_look_tick() -> void:
	if _dist("X-SS:valve") > DESPAWN_R:
		if not valve_props.is_empty():
			for p in valve_props:
				host.map.remove_runtime_prop(p)
			valve_props.clear()
			_valve_look = ""
		return
	var want := "bj" if v("SQ_S02_BJ") == 1 else ("open" if v("SQ_S02_OPEN") != 0 else "shut")
	if want == _valve_look:
		return
	for p in valve_props:
		host.map.remove_runtime_prop(p)
	valve_props.clear()
	var c: Vector2i = host.map.tile_of(host.map.mark_pos("X-SS:valve"))
	valve_props.append(host.map.add_runtime_prop("valve_up" if want == "shut" else "valve_open", c))
	if want == "bj":
		valve_props.append(host.map.add_runtime_prop("bj_plate", c + Vector2i(1, 0)))
		valve_props.append(host.map.add_runtime_prop("bj_speaker", c + Vector2i(-1, 0)))
	_valve_look = want


# ---------------------------------------------------------------- 낙성대 고개 캠프(X-NS): 척후장 사이렌
func _siren_tick() -> void:
	var d := _dist("X-NS:siren")
	if d <= CAMP_R and not scouts_on:
		_spawn_scouts()
	elif d > DESPAWN_R and scouts_on and not host.combat.in_combat():
		_clear(scouts)
		siren = null
		scouts_on = false
	if not scouts_on or not is_instance_valid(siren) or siren.cmb.dead or _siren_said:
		return
	if siren.cmb.team.begins_with("calm") and _safe() and host.player.loco.logical.distance_to(siren.loco.logical) <= SIREN_TALK * 32.0:
		_siren_said = true
		host.play_scene("SQS02_SIREN")


func _spawn_scouts() -> void:
	scouts_on = true
	_siren_said = false
	scouts.clear()
	siren = null
	var r := _rng("NS")
	if v("SQ_S02_SIREN") != 2:
		siren = host.combat.spawn("CR-420", _spot("X-NS:siren", r, 1, 0), host.map, st, {"lv": 7, "who": "N-R01-062", "sheet": "en_n062_loco", "dir": "N", "stance": "hold"})
		scouts.append(siren)
	var kinds := ["CR-420", "CR-420", "CR-423", "CR-423"]
	for i in maxi(0, kinds.size() - v("SQ_S02_NKILLS")):
		scouts.append(host.combat.spawn(str(kinds[i]), _spot("X-NS:scout%d" % (i + 1), r), host.map, st,
			{"lv": r.randi_range(3, 6), "dir": ["N", "E", "W", "S"][r.randi() % 4]}))
	if v("SQ_S02_NS_HOT") == 0:
		for e in scouts:
			_calm(e, "calmns")                                         # 먼저 쏘지 않으면 사이렌이 말을 건다(지도 50캡)
	_log("낙성대 캠프 %d" % scouts.size())


## 사이렌이 쓰러졌다: 지도가 아직 그녀 품에 있으면 유해 소지품에 넣는다
func _siren_drop(e: Enemy) -> void:
	if v("SQ_S02_MAP") == 1 or v("SQ_S02_SIREN") == 3:
		return
	var c: Vector2i = host.map.tile_of(e.loco.logical)
	if not host.map.boxes.has(c):
		host._on_enemy_down(e)
	if host.map.boxes.has(c):
		var bx := host.box_contents(host.map.boxes[c])
		var items: Dictionary = bx.get("items", {})
		items["M-301"] = 1
		bx["items"] = items
	else:
		st.call_fn("give", ["M-301", 1])


# ---------------------------------------------------------------- 봉천(X-BC): 남건희의 밤 · 03시 함정 · 시각에 따른 인물
func _bc_tick() -> void:
	if _zone() != "X-BC":
		if night_on:
			_night_off()
		return
	var hb := 0 if (hour() >= 6 and hour() < 22) else 1
	if hb != _hr_band:
		_hr_band = hb
		host.refresh_npcs()                                                 # 남건희: 낮엔 텃밭, 밤엔 없다(윗문 밖)
	_night_tick()
	if v("SQ_S02_TRAP_AT") > 0 and v("SQ_S02_TRAP_DONE") == 0:
		if trap_on:
			_trap_tick()
		elif _now() >= v("SQ_S02_TRAP_AT") and _safe():
			_trap_start()


func _gate_spot(dy: int) -> Vector2:
	var p := host.map.mark_pos("X-BC:upgate")
	var c: Vector2i = host.map.tile_of(p) + Vector2i(0, dy)
	return Vector2(c.x * 32 + 16, c.y * 32 + 16) if not host.map.is_solid(c) else p


## 22시 이후 윗문 쪽문: 남건희가 척후에게 물통을 받는다(단계 40 이후, 아직 모를 때만). 지켜보면 단계 60, 쪼그리지 않고 너무 다가가면 오늘 밤은 흩어진다
func _night_tick() -> void:
	var want := (hour() >= 22 or hour() < 1) and v("SQ_S02_MAP") == 1 and v("SQ_S02_KNOW") == 0 and v("SQ_S02_IN") == 0 \
		and not st.is_dead("N-R01-039") and v("SQ_S02_NIGHT_DAY") != _night_key()
	if want and not night_on:
		host.ev._show_actor("N-R01-039", _gate_spot(1), "N")
		host.ev._show_actor("N-YT-2", _gate_spot(-1), "S", "en_cr420b_loco")
		for id in ["N-R01-039", "N-YT-2"]:
			if host.ev.actors.has(id):
				host.map.blockers.erase(host.ev.actors[id])
		night_on = true
		_night_said = false
		_log("윗문 밤 거래")
	elif not want and night_on:
		_night_off()
	if not night_on or _night_said or not host.ev.actors.has("N-R01-039"):
		return
	var dn := host.player.loco.logical.distance_to(host.ev.actors["N-R01-039"].loco.logical) / 32.0
	if dn <= NIGHT_SPOT and not host.combat.crouch:
		_night_said = true
		st.vars.set_v("SQ_S02_NIGHT_DAY", _night_key())                  # 들켰다 — 오늘 밤은 끝(내일 밤 다시)
		host.hint("남건희가 화들짝 돌아본다. 낯선 사람은 능선 쪽으로 사라졌다.", 5.0)
		_night_off()
	elif dn <= NIGHT_SEE and _safe():
		_night_said = true
		host.play_scene("SQS02_NIGHT")


func _night_key() -> int:
	return (_now() - 360) / 1440                                           # 밤 하나 = 06시~다음 06시


func _night_off() -> void:
	for id in ["N-R01-039", "N-YT-2"]:
		if host.ev.actors.has(id):
			var a: Actor = host.ev.actors[id]
			host.ev.actors.erase(id)
			if is_instance_valid(a):
				host.map.remove_actor(a)
				a.queue_free()
	night_on = false
	if _zone() == "X-BC":
		host.refresh_npcs()


## 03시 함정: 감시조 셋을 계단참에 세우고, 아랫문으로 패거리 여섯이 올라온다(SD-04a §4.2 해법 c)
func _trap_start() -> void:
	trap_on = true
	_trap_near = 0
	_trap_n = 0
	st.vars.set_v("SQ_S02_FIGHT", 1)
	host.refresh_npcs()                                                    # 계단참 감시조는 전투 개체로 다시 세운다(맵 조건 SQ_S02_FIGHT == 0)
	for g in TRAP_GUARDS:
		if st.is_dead(str(g[0])):
			continue
		host.ev._show_actor(str(g[0]), host.map.mark_pos("X-BC:" + str(g[1])), "S")
		var a: Actor = host.ev.actors.get(str(g[0]))
		if a != null:
			var c := host.combat.add_ally(str(g[0]), a, 60.0, "W-002")
			c.hp_floor = 1.0                                                # 감시조는 쓰러져도 죽지 않는다(이 퀘스트의 판정은 남건희 하나)
	if not st.is_dead("N-R01-039"):
		host.ev._show_actor("N-R01-039", host.map.mark_pos("X-BC:land1") + Vector2(64, 0), "S")
	var r := _rng("TRAP")
	trap_foes.clear()
	for i in 6:
		var e := host.combat.spawn(["CR-420", "CR-421", "CR-423"][r.randi() % 3], host.map.mark_pos("X-BC:" + TRAP_FROM[i]), host.map, st, {"lv": r.randi_range(4, 7)})
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
		trap_foes.append(e)
	host.hint("03시. 아랫문 쪽에서 발소리 — 패거리 습격조가 계단을 오른다. 계단참①을 지켜라.", 6.0)
	_log("03시 함정 시작")


func _trap_tick() -> void:
	_trap_n += 1
	if host.player.loco.logical.distance_to(host.map.mark_pos("X-BC:land1")) <= 7.0 * 32.0:
		_trap_near += 1
	var left := trap_foes.filter(func(e): return is_instance_valid(e) and not e.cmb.dead).size()
	if left == 0:
		_trap_end(_trap_n > 0 and float(_trap_near) / _trap_n >= 0.5)


## 함정이 끝났다: 주인공이 계단참①을 지켰으면 남건희는 산다. 아니면 50%(씨앗 — 다시 불러와도 같은 결과)
func _trap_end(guarded: bool) -> void:
	trap_on = false
	host.combat.clear_allies()
	for g in TRAP_GUARDS + [["N-R01-039", ""]]:
		var id := str(g[0])
		if host.ev.actors.has(id):
			var a: Actor = host.ev.actors[id]
			host.ev.actors.erase(id)
			if is_instance_valid(a):
				host.map.remove_actor(a)
				a.queue_free()
	_clear(trap_foes)
	st.vars.set_v("SQ_S02_FIGHT", 0)
	_trap_result(guarded)
	host.refresh_npcs()


func _trap_result(guarded: bool) -> void:
	if v("SQ_S02_TRAP_DONE") == 1:
		return
	st.vars.set_v("SQ_S02_TRAP_DONE", 1)
	var r := RandomNumberGenerator.new()
	r.seed = hash("S02TRAP:%d" % v("SQ_S02_TRAP_AT"))
	var dead := not guarded and r.randf() < 0.5 and not st.is_dead("N-R01-039")
	if dead:
		st.kill("N-R01-039")
		st.vars.set_v("SQ_S02_NH_DEAD", 1)
		st.call_fn("karma", [-50])
	st.vars.set_v("PD_BC", v("PD_BC") + 5)                                 # 판도 PD-R01-2 약탈 −5(습격조가 매복에 걸렸다)
	_deed("SQS02_TRAP", {"JC_BC": 5}, "봉천 계단참 매복에 남부순환 습격조가 걸렸다", ["JC_BC"])
	if _zone() == "X-BC":
		host.hint("습격조가 무너졌다." + (" 계단참① 아래 — 남건희가 쓰러져 있다." if dead else " 남건희가 떨며 계단참에 주저앉는다."), 6.0)
	_log("03시 함정 끝(남건희 %s)" % ("죽음" if dead else "생존"))


func _trap_away() -> void:
	if trap_on:
		_trap_end(false)
	else:
		_trap_result(false)


# ---------------------------------------------------------------- 해법 D 계엄군 분대(다음 06시)
func _bj_tick() -> void:
	if v("SQ_S02_BJ_AT") <= 0 or v("SQ_S02_BJ") == 1 or _now() < v("SQ_S02_BJ_AT"):
		return
	if squad.is_empty():
		if camp_on and v("SQ_S02_CAMP") == 0:
			if _safe() or host.combat.in_combat():
				_squad_in()
		else:
			_bj_done(false)                                                 # 주인공이 그 자리에 없다(또는 캠프가 이미 비었다): 결과만
	elif _squad_t == 0.0 and v("SQ_S02_CAMP") == 0:
		_bj_done(false)                                                     # 분대가 정리했다(주인공이 오래 비켜 있었다)


func _squad_in() -> void:
	var at := host.map.mark_pos("X-SS:arrive")
	for i in 4:
		var e := host.combat.spawn("CR-401", at + Vector2((i - 1.5) * 40.0, 0), host.map, st, {"lv": 8, "dir": "S"})
		e.cmb.team = "bj"
		e.foes = ["enemyss", "calmss"]
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
		squad.append(e)
	_hostile(camp, "enemyss", ["bj"])
	_squad_t = 90.0
	host.hint("06시. 능선 위에서 확성기 — '민간 기반 시설 점거자는 즉시 투항하라.' 계엄군 분대가 밸브 캠프를 친다.", 6.0)
	_log("계엄군 분대 도착")


## 계엄군이 밸브를 쳤다: 물 복구 · 표지 · 공보 공고. BJ +6(+2 함께 싸움) · 봉천 +3 · 연동(JC −2 · YH −3 · JG −3) · 판도 PD-R01-1 비상 +5
func _bj_done(fought: bool) -> void:
	if v("SQ_S02_BJ") == 1:
		return
	st.vars.set_v("SQ_S02_BJ", 1)
	st.vars.set_v("SQ_S02_CAMP", 1)
	st.call_fn("aff", ["BJ", 6 + (2 if (fought and _with_bj) else 0)])
	for kv in [["JC", -2], ["YH", -3], ["JG", -3]]:
		if st._aff_key(str(kv[0])) != "":
			st.call_fn("aff", kv)
	st.vars.set_v("PD_R01_BJ", v("PD_R01_BJ") + 5)
	if v("SQ_S02_SOL") == 0:
		_solved(4)
		_deed("SQS02_D", {"JC_BC": 3}, "계엄군 분대가 삼성산 밸브 캠프를 쳤다 — '배급 수도, 관리 계엄사령부'", [], ["BJ"])
	if not squad.is_empty():
		var out := host.map.mark_pos("X-SS:arrive")
		for e in squad:
			if is_instance_valid(e) and not e.cmb.dead:
				e.released = true
				e.set_meta("leave_from", e.loco.logical)
				e.set_meta("leave_to", out)
				e.foes.clear()
				e.cmb.team = "gone"
				e.brain.state = AIBrain.S.RETURN
		host.combat._rebuild_list()
		squad.clear()
	_squad_t = -1.0
	if host.map is WorldMap and _dist("X-SS:valve") <= DESPAWN_R:
		_clear(camp)
		toller = null
	_log("계엄군 밸브 관리(%s)" % ("함께" if fought else "결과만"))


# ---------------------------------------------------------------- 밸브실(K-32) 수위계 · 계곡 이음 지점(K-08)
func _gauge() -> void:
	var lv := level()
	host.map.set_prop_state(Vector2i(9, 1), "" if lv >= 5 else "lv%d" % lv)


## 이음 지점 둘(K-08 30,3 · 37,3): 주인공이 가까운 쪽을 원고가 SQ_S02_AT으로 본다(1 = 그 지점은 이미 이었다)
func _joint_at() -> void:
	var x := host.map.tile_of(host.player.loco.logical).x
	st.vars.set_v("SQ_S02_AT", v("SQ_S02_J1") if x < 34 else v("SQ_S02_J2"))


func _on_map(id: String) -> void:
	var fresh := host.map != _map_ref
	_map_ref = host.map
	if fresh:
		camp.clear()
		scouts.clear()
		toller = null
		siren = null
		camp_on = false
		scouts_on = false
		valve_props.clear()
		_valve_look = ""
		night_on = false
		squad.clear()
		_squad_t = -1.0
		if trap_on:
			trap_on = false
			trap_foes.clear()
			host.combat.clear_allies()
			st.vars.set_v("SQ_S02_FIGHT", 0)
			_trap_result(false)                                             # 싸움 중에 봉천을 떠났다: 계단참①은 비었다
		_hr_band = -1
	if id == "X-BC":
		for tag in ["SQS02_A", "SQS02_B", "SQS02_D", "SQS02_E"]:
			st.deeds.tell(st, tag, "JC_BC", _now())                         # 봉천에 돌아왔다: 물이 다시 흐르는 걸 마을이 안다
	if id == "K-32":
		_gauge()


func _on_resident_down(id: String, killed: bool) -> void:
	if id == "N-R01-039" and killed and v("SQ_S02_NH_KILLED") == 0:
		st.vars.set_v("SQ_S02_NH_KILLED", 1)
		st.vars.set_v("SQ_S02_NH_DEAD", 1)
		_deed("SQS02_KILL", {"JC_BC": -8}, "봉천 청년 남건희가 살해됐다", ["JC_BC"])   # 마을 청년 살해(공개도 2 — 카르마 −100은 살인 판정이)


# ---------------------------------------------------------------- 원고 명령(@cmd s02 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"open":                                                         # A 탈환: 빈 캠프의 밸브를 연다
			if v("SQ_S02_SOL") == 0:
				_solved(1)
				st.vars.set_v("PD_BC", v("PD_BC") + 5)                         # 판도 PD-R01-2 정착 +5
				_deed("SQS02_A", {"JC_BC": 8}, "삼성산 상류 밸브를 되찾아 봉천 배수지에 물이 돌아왔다")
			else:
				st.vars.set_v("SQ_S02_OPEN", 1)
			_valve_look = ""
		"pay":                                                          # E 물값: 사흘 흘려 준다(봉천 +2는 한 번)
			st.vars.set_v("SQ_S02_OPEN", 2)
			st.vars.set_v("SQ_S02_PAID", day() + 3)
			if v("SQ_S02_SOL_E") == 0:
				st.vars.set_v("SQ_S02_SOL_E", 1)
				_deed("SQS02_E", {"JC_BC": 2}, "누군가 패거리에게 물값을 대신 냈다 — 사흘 물이 흐른다")
			for e in camp:
				if is_instance_valid(e) and not e.cmb.dead:
					_calm(e, "calmss")
			_valve_look = ""
		"back":
			pass
		"sold":                                                         # 사이렌에게 지도를 샀다(50캡은 원고가)
			st.vars.set_v("SQ_S02_SIREN", 3)
			st.call_fn("give", ["M-301", 1])
		"hand":                                                         # 반상회 게시판 '빗물 당번표' 글씨 대조
			st.vars.set_v("SQ_S02_HAND", 1)
			if stage() < 70:
				_up(50)
		"seen":                                                         # 남건희 미행 · 남태하에게 들음
			st.vars.set_v("SQ_S02_KNOW", 1)
			if stage() < 70:
				_up(60)
			if night_on:
				_night_off()
		"insider":                                                      # 내부자 처리: 1 고발 · 2 타이름 · 3 함정
			var n := int(a[1]) if a.size() > 1 else 0
			if v("SQ_S02_IN") == 0 and n in [1, 2, 3]:
				st.vars.set_v("SQ_S02_IN", n)
				match n:
					1:
						st.vars.set_v("SQ_S02_EXILE_DAY", day() + 1)              # 반상회 — 내일 아침엔 그 애가 없다(7일 뒤 고시촌 졸개는 L-R01-14와 함께)
						_deed("SQS02_IN1", {"JC_BC": 5}, "반상회가 척후에게 마을을 판 청년을 내쫓았다", ["JC_BC"])
					2:
						st.call_fn("karma", [50])
						st.vars.set_v("SQ_S02_STOP_DAY", day())                  # 대장간 일(14일 뒤 옥탑 감시조 — MQ-507 방어 인원 +1)
						_deed("SQS02_IN2", {"JC_BC": 5}, "남건희가 패거리와 손을 끊고 대장간 일을 배운다", ["JC_BC"])
					3:
						st.vars.set_v("SQ_S02_TRAP_AT", _next_at(3, 180))          # 다음 03시(적어도 세 시간 뒤 — 오늘 밤 전한다)
				host.refresh_npcs()
		"guard":                                                        # A 뒤 남태하에게 알림: 감시조 둘이 밸브에 상주
			st.vars.set_v("SQ_S02_GUARD", 1)
		"joint":                                                        # B: 옛 관로 이음 지점(고철 · 테이프는 원고가)
			var x := host.map.tile_of(host.player.loco.logical).x if host.map != null else 0
			st.vars.set_v("SQ_S02_J1" if x < 34 else "SQ_S02_J2", 1)
			st.vars.set_v("SQ_S02_AT", 1)
			if v("SQ_S02_J1") == 1 and v("SQ_S02_J2") == 1 and v("SQ_S02_B") == 0:
				st.vars.set_v("SQ_S02_B", 1)
				_solved(2)
				st.call_fn("karma", [50])
				st.vars.set_v("SQ_S02_RAID_UNTIL", day() + 3)                   # 패거리가 사흘 동안 봉천 밤 습격을 늘린다(+30%)
				_deed("SQS02_B", {"JC_BC": 10}, "관악 계곡 옛 관로가 이어져 봉천 배수지에 물이 돌아왔다")
				st.vars.set_v("SQ_S03_PIPE", 1)                                   # 우회 관로가 계곡 배수로를 지난다 — 곰팡이(SQ-S03 발동은 SideS03이 받는다)
				host.hint("두 번째 이음 지점이 닫혔다. 관 속으로 물이 밀려 내려가는 소리.", 5.0)
		"bj":                                                           # D: 황보서현에게 밸브 위치(다음 06시 분대)
			if v("SQ_S02_BJ_AT") == 0:
				st.vars.set_v("SQ_S02_BJ_AT", _next_at(6, 360))
	done.call()
