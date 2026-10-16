## 관악(R01) 사이드 퀘스트 SQ-S04 「도성이 뒤척인다」 진행기(단계 1-11c, SD-04a §4.4). 원고: script/act1/SQ-S04.txt · JUNGGYE.txt GS_HAN ·
##   MQ-103.txt MQ-103_MA · R01_R02.txt BC_NAM · MQ-101.txt X-BC_BOARD · MQ-102.txt 잠든 파수 · terms/r01_radar.txt(TM-K34 · TM-K35).
## 발동: MQ-102가 열린 뒤 48시간 넘게 지난 첫 21시, 관악 레이더 중계소 전지가 깨어난다(WAKE) — 파수-3 셋이 일어나고 주민센터 앞 파수가 남솔을 '미등록 아동'으로 안아 간다.
##   주인공이 봉천 반경 3청크 안이면 종소리(가까우면 실시간 경보 장면 — 파수가 아이를 안고 걷는다), 멀면 다음 봉천 방문 때 게시판 쪽지로 단계 10.
## 사실은 변수 한 곳(SD-20 P1): HELD 남솔이 철망 안 · OUT 나온 길 · SLEEP 파수가 잠든 까닭 · KILLED 부순 파수 · BATT 전지 · F 단말 '대기' · D 각성회 정비.
## 파수(관제망 G0 국지 전원): 봉천 주민 모두 판독 불능 — 어른에게는 '정지 → 3초 → 경고 사격 → 제압', K_CODE면 1.5초 더 멈칫(PK-103). 쪼그리면 바로 앞에서야 본다.
## 큰 사건(경보 · 보호 기간 만료 · 정비 의식)은 정한 시각이 지나도 대화 · 교전 중이면 안전한 순간까지 미룬다(P5). 주인공이 그 자리에 없으면 결과만 남긴다(P10).
class_name SideS04
extends Node

const BC_CENTER := Vector2i(892, 1362)   ## 봉천(X-BC) 중심
const HEAR_R := 120.0                    ## 봉천 반경 3청크(40×3): 종소리가 닿는다
const SEE_R := 45.0                      ## 그 안이면 경보를 실시간으로
const RADAR := Vector2i(990, 1561)       ## 관악 레이더 중계소(X-RD 중심, L-R01-04)
const SIGNAL_R := 80.0                   ## 핍-보이 등록 카드 칸 '반송파 강함'
const POST_R := 60.0                     ## 파수를 세우는 거리 · 치우는 거리 +10
const NEAR_R := 10.0                     ## 단계 20 '주민센터 반경 10타일'
const CAST_R := 12.0                     ## 방송이 들리는 거리
const HALT_R := 5.0
const HALT_CROUCH := 1.5
const HALT_SECS := 3.0
const KCODE_SECS := 1.5
const PAUSE_SECS := 60.0
const CHASE_SECS := 30.0
const WAKE_GAP := 48 * 60
const HOLD_MIN := 72 * 60
const D_TRAVEL := 6 * 60
const RITUAL_MIN := 120
const VILLAGE_MIN := 6 * 60              ## 파수가 잠든 뒤 마을이 철망을 여는 데 걸리는 시간
const CARRY_MIN := 4 * 60                ## 노량진까지 안고 갔다 돌아오는 시간(약 420타일 왕복)
const POSTS := ["guard", "gate", "road"] ## 비트 1 · 2 · 4
const BJ_REG := 4                        ## V_REGCARD 4 = K_CODE(관리자 후보)

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var bots: Array = [null, null, null]     ## 파수-3(Enemy) — 자리 순서 POSTS
var halt: Array = [-1.0, -1.0, -1.0]     ## 정지 명령 뒤 흐른 초(-1 = 명령 없음)
var warned: Array = [false, false, false]
var _halt_scene := false                 ## 주민센터 파수가 관리자 후보에게 말을 걸었다(이번 접근)
var pause_t := 0.0                       ## 관리자 명령: 순찰 정지 남은 초
var chase_t := 0.0                       ## '보호 대상 이탈' 추격 남은 초
var posts_on := false
var looks: Dictionary = {}               ## 자리 → 런타임 소품(잠든 파수 · 잔해 · 흰 천)
var carry_on := false                    ## 경보 장면: 파수가 아이를 안고 걷는다
var _carry_t := 0.0
var radar_on := false
var turrets: Array = [null, null]
var radar_props: Array = []
var _radar_look := ""
var helpers := false                     ## 남태하 감시조 둘(해법 B 지원)
var _cast_said := false
var _map_ref: InteriorMap = null


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s04"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.enemy_killed.connect(_on_killed)
	host.combat.provoked.connect(_on_provoked)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[도성] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S04")


func hour() -> int:
	return Clock.hour(host.date_text)


func _now() -> int:
	return Clock.abs_min(host.date_text)


func _safe() -> bool:
	return not host.box.active and not host.ev.busy() and not host.busy and not host.combat.in_combat()


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S04", n)
		_log("단계 %d" % n)


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _world() -> bool:
	return host.map is WorldMap


func _ptile() -> Vector2i:
	return host.map.tile_of(host.player.loco.logical)


func _tiles(a: Vector2i, b: Vector2i) -> float:
	return Vector2(a - b).length()


func _dist_mark(mark: String) -> float:
	return host.player.loco.logical.distance_to(host.map.mark_pos(mark)) / 32.0


func _awake() -> bool:
	return v("SQ_S04_WAKE") > 0 and v("SQ_S04_SLEEP") == 0


## 레이더 중계소 전지가 깨어 있다(감시포 · 경광): 깨어났고, 뽑지도 '대기'로 내리지도 않았다
func radar_awake() -> bool:
	return v("SQ_S04_WAKE") > 0 and v("SQ_S04_BATT") == 0 and v("SQ_S04_F") == 0


func _killed(i: int) -> bool:
	return (v("SQ_S04_KILLED") >> i) & 1 == 1


## 봉천이 알게 되는 일(공개도 2). 봉천 · 주민센터 앞이면 그 자리에서 닿는다
func _deed(tag: String, fx: Dictionary, what: String, seen: Array = [], about: Array = []) -> void:
	st.deeds.record(st, "side", "R01", 2, fx, _now(), {"tag": tag, "place": "BC", "what": what, "seen_by": seen, "about": about})


# ---------------------------------------------------------------- 매 0.25초
func _process(dt: float) -> void:
	if host.map == null:
		return
	if pause_t > 0.0:
		pause_t = maxf(0.0, pause_t - dt)
		if pause_t == 0.0:
			_resume()
	if chase_t > 0.0:
		chase_t = maxf(0.0, chase_t - dt)
		if chase_t == 0.0:
			_chase_end()
	_halt_step(dt)
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	tick()


func tick() -> void:
	_facts()
	if v("V_ACT") < 1:
		return
	if _world():
		_looks_tick()                                                       # 잠든 파수 그림을 먼저 걷는다(경보 걸음이 그 칸으로 간다)
		_wake_scene()
		_posts_tick()
		_radar_tick()
		_signal_tick()
		_ritual_tick()
	elif _zone() == "K-33":
		host.map.set_prop_state(Vector2i(10, 4), "413" if v("SQ_S04_WAKE") > 0 else "")
	if not _world() or _dist_mark("sentry") > POST_R:
		_ritual_away()


## 사실 맞추기: 발동 시각 · 깨어남 · 보호 기간 · 잠든 뒤 마을 · 단계 · 끝
func _facts() -> void:
	if v("SQ_S04_ARM") == 0 and st.quests.stage("MQ-102") >= 10 and _now() > 0:
		st.vars.set_v("SQ_S04_ARM", _now())                                 # MQ-102가 열린 때(분)
		st.vars.set_v("SQ_S04_WAKE_AT", _next_at(21, WAKE_GAP))            # 48시간 넘게 지난 첫 21시
	if v("SQ_S04_WAKE") == 0 and v("SQ_S04_WAKE_AT") > 0 and _now() >= v("SQ_S04_WAKE_AT"):
		_wake()
	if v("SQ_S04_F") == 1 and v("SQ_S04_WAKE") > 0 and v("SQ_S04_SLEEP") == 0:
		st.vars.set_v("SQ_S04_SLEEP", 2)                                     # F 당직실 단말: 전지 출력 '대기' — 파수가 다시 엎드린다(전지는 남는다)
		_deed("SQS04_F", {"JC_BC": 3}, "관악 레이더 중계소 전지가 '대기'로 내려갔다 — 봉천의 파수들이 다시 엎드렸다")
		_log("전지 대기(F)")
	var now := _now()
	if v("SQ_S04_HELD") == 1:
		if v("SQ_S04_SLEEP") >= 1 and v("SQ_S04_VILLAGE_AT") == 0:
			st.vars.set_v("SQ_S04_VILLAGE_AT", now + VILLAGE_MIN)           # 파수가 잠든 걸 마을이 알아채는 데 여섯 시간
		if v("SQ_S04_SLEEP") >= 1 and v("SQ_S04_VILLAGE_AT") > 0 and now >= v("SQ_S04_VILLAGE_AT"):
			_out(6)                                                          # 파수가 잠들었다: 남태하가 철망을 비틀어 연다
			if _zone() == "X-BC" or (_world() and _dist_mark("sentry") <= POST_R):
				host.hint("남태하와 감시조가 주민센터로 달려간다. 잠든 파수 곁을 지나 철망을 비틀어 연다.", 6.0)
		elif v("SQ_S04_SLEEP") == 0 and now >= v("SQ_S04_DEADLINE") and v("SQ_S04_DEADLINE") > 0 and _safe_or_away():
			_expire()
	var up := 1 if _awake() and not _killed(0) and now >= v("SQ_S04_GUARD_BACK") else 0
	if v("SQ_S04_UP") != up:
		st.vars.set_v("SQ_S04_UP", up)
	if v("SQ_S04_LOITER") > 0 and (now >= v("SQ_S04_LOITER") or not _awake()):
		st.vars.set_v("SQ_S04_LOITER", 0)                                    # 아랫문 서성임 끝(72시간 · 잠듦)
		if posts_on:
			_clear_posts()
	if stage() >= 10 and stage() < 100 and v("SQ_S04_OUT") > 0:
		_up(50)                                                              # 50 · 60은 따로 선다 — 60(잠듦)만 먼저면 마을이 꺼낼 때(OUT 6)까지 기다린다
		if v("SQ_S04_SLEEP") > 0:
			_up(60)
			_finish()


func _safe_or_away() -> bool:
	return _safe() or not _world() or _dist_mark("sentry") > POST_R


## 다음 h시 정각(절대 분) — 지금부터 적어도 gap분 뒤
func _next_at(h: int, gap: int) -> int:
	var a := _now()
	var t := a - posmod(a, 1440) + h * 60
	while t < a + gap:
		t += 1440
	return t


func _finish() -> void:
	if stage() >= 100:
		return
	st.vars.set_v("SQS04_RESULT", v("SQ_S04_OUT"))
	st.quests.set_stage("SQ-S04", 100)
	st.call_fn("xp", [350])
	_log("SQ-S04 끝(나옴 %d · 잠듦 %d)" % [v("SQ_S04_OUT"), v("SQ_S04_SLEEP")])


# ---------------------------------------------------------------- 깨어남(21시)
func _wake() -> void:
	if v("SQ_S04_BATT") == 1 or v("SQ_S04_F") == 1 or v("V_ACT") > 2:
		st.vars.set_v("SQ_S04_WAKE_AT", 0)                                  # 전지가 이미 없다(먼저 뽑음 · 대기) · 3막 이후: 이번엔 뒤척이지 않는다
		_log("깨어나지 않음")
		return
	st.vars.set_v("SQ_S04_WAKE", _now())
	if st.dead.has("N-R01-034"):
		st.vars.set_v("SQ_S04_WAKE", 0)                                     # 데려갈 아이가 없다(SD-20 N2) — 이번 깨어남은 소리 없이 지나간다
		st.vars.set_v("SQ_S04_WAKE_AT", 0)
		return
	st.vars.set_v("SQ_S04_HELD", 1)
	st.vars.set_v("SQ_S04_DEADLINE", _now() + HOLD_MIN)
	st.vars.set_v("SQ_S04_BELL", 0)
	_log("파수 깨어남(%s)" % host.date_text)
	if host.map != null:
		host.refresh_npcs()                                                 # 남솔이 마당에서 사라진다(파수 품에)


## 경보 장면: 깨어난 뒤 첫 안전한 순간. 봉천 반경 3청크 안이면 종소리(가까우면 아이를 안은 파수가 걷는다), 멀면 게시판 쪽지
func _wake_scene() -> void:
	if v("SQ_S04_WAKE") == 0 or v("SQ_S04_BELL") != 0 or stage() >= 10:
		return
	if _now() > v("SQ_S04_WAKE") + 90:
		st.vars.set_v("SQ_S04_BELL", 3)                                     # 종소리를 들을 때가 지났다 — 쪽지로
		return
	var d := _tiles(_ptile(), BC_CENTER)
	if d > HEAR_R or not _safe() or host.story_hold:
		return
	if d <= SEE_R:
		st.vars.set_v("SQ_S04_BELL", 1)
		host.hint("21시. 망루에서 종이 울린다 — 땡, 땡, 땡. 남태하가 아랫문 쪽을 가리키며 소리친다. '쇳덩이가 솔이를 안고 간다!'", 7.0)
		_carry_start()
	else:
		st.vars.set_v("SQ_S04_BELL", 2)
		host.hint("21시. 멀리 봉천 쪽에서 종소리 — 땡, 땡, 땡. 관악산 꼭대기에서 앰버 불빛 하나가 깜박인다.", 7.0)
	_up(10)


func _carry_start() -> void:
	var from := host.map.mark_pos("X-BC:land1")
	host.ev._show_actor("S04_CARRY", from, "S", "rb_cr305_carry_loco")
	var a: Actor = host.ev.actors.get("S04_CARRY")
	if a == null:
		return
	a.loco.custom = {"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 1.75},
		"run": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 1.75, "anim": "walk"}}
	host.map.blockers.erase(a)
	carry_on = true
	_carry_t = 0.0
	_walk(a, host.map.mark_pos("sentry") + Vector2(0, -32))                # 정문 앞까지(민원실로 들어간다)
	_log("경보: 파수가 남솔을 안고 걷는다")


## 기다리지 않는 걸음(연출 'go'와 같은 배경 이동 — 표지 대신 월드 좌표로: 발견 자리 표지는 연출 표지 목록에 없다)
func _walk(a: Actor, to: Vector2) -> void:
	a.mode = "walk"
	host.ev._bg = host.ev._bg.filter(func(b): return is_instance_valid(b["actor"]) and b["actor"] != a)
	host.ev._bg.append({"actor": a, "to": to, "path": host.ev._route(a, to), "t": 0.0, "still": 0.0, "last": a.loco.render})


func _carry_tick(dt: float) -> void:
	if not carry_on:
		return
	_carry_t += dt
	var a: Actor = host.ev.actors.get("S04_CARRY")
	if a == null or not is_instance_valid(a) or (not host.ev.drives(a) and _carry_t > 1.0) or _carry_t > 40.0:
		_carry_end()


func _carry_end() -> void:
	carry_on = false
	if host.ev.actors.has("S04_CARRY"):
		var a: Actor = host.ev.actors["S04_CARRY"]
		host.ev.actors.erase("S04_CARRY")
		if is_instance_valid(a):
			host.map.remove_actor(a)
			a.queue_free()
	if _world():
		host.hint("파수가 주민센터 안으로 들어갔다가 혼자 나온다. 정문 앞에 다시 선다.", 5.0)


# ---------------------------------------------------------------- 파수 셋(봉천)
func _post_pos(i: int, r: RandomNumberGenerator) -> Vector2:
	var c := _post_cell(i)
	for _k in 16:
		var cc := c + Vector2i(r.randi_range(-1, 1), r.randi_range(-1, 1))
		if not host.map.is_solid(cc):
			return Vector2(cc.x * 32 + 16, cc.y * 32 + 16)
	return Vector2(c.x * 32 + 16, c.y * 32 + 16)


## 자리 칸: 주민센터 정문 앞(MQ-102 잠든 파수 자리) · 봉천 아랫문 앞 · 남부순환로(아랫문 동쪽). 서성임(C)이면 셋 다 아랫문 앞
func _post_cell(i: int) -> Vector2i:
	var gate: Vector2i = host.map.tile_of(host.map.mark_pos("X-BC:doksaf"))
	if v("SQ_S04_LOITER") > 0:
		return gate + Vector2i([-3, 0, 3][i], 0)
	match i:
		0:
			return host.map.tile_of(host.map.mark_pos("sentry"))
		1:
			return gate
		_:
			return host.map.tile_of(host.map.mark_pos("X-BC:from_X-S07")) + Vector2i(-8, 0)


func _posts_tick() -> void:
	_carry_tick(0.25)
	var d := _dist_mark("sentry")
	var want := _awake() and d <= POST_R
	if want and (not posts_on or _missing()):
		_spawn_posts()
	elif posts_on and (not _awake() or (d > POST_R + 10.0 and not host.combat.in_combat())):
		_clear_posts()
	if not posts_on:
		return
	if v("SQ_S04_HELD") == 1:
		if stage() >= 10 and stage() < 20 and d <= NEAR_R:
			_up(20)
		elif stage() < 10 and d <= NEAR_R:
			_up(20)                                                         # 순서 파괴: 종도 쪽지도 못 본 채 주민센터 앞에 왔다
		if stage() >= 20 and stage() < 30 and not _cast_said and d <= CAST_R and _safe():
			_cast_said = true
			host.play_scene("SQS04_BROADCAST")
	if v("SQ_S04_GUARD_BACK") > _now() and is_instance_valid(bots[0]):
		_drop(0)                                                            # 주민센터 파수가 아이를 노량진으로 안고 갔다(돌아올 때까지 빈 자리)
	if helpers == false and v("SQ_S04_HELP") == 1 and v("SQ_S04_HOT") == 1 and host.combat.in_combat():
		_helpers_in()


## 서 있어야 할 파수가 빠졌다(경보 걸음이 끝남 · 노량진에서 돌아옴)
func _missing() -> bool:
	for i in 3:
		if not _killed(i) and not is_instance_valid(bots[i]) and not (i == 0 and (carry_on or v("SQ_S04_GUARD_BACK") > _now())):
			return true
	return false


func _spawn_posts() -> void:
	if not posts_on:
		_cast_said = false
	posts_on = true
	var r := RandomNumberGenerator.new()
	r.seed = hash("S04:%d" % (_now() / 120))                                # 때가 바뀌면 다른 걸음 · 다른 자리(SD-22)
	for i in 3:
		if _killed(i) or is_instance_valid(bots[i]):
			continue
		if i == 0 and v("SQ_S04_GUARD_BACK") > _now():
			continue
		if i == 0 and carry_on:
			continue
		var c := _post_cell(i)
		var opts := {"lv": r.randi_range(3, 5), "dir": "S" if i == 0 else ["E", "W", "S"][r.randi() % 3]}
		if i != 1:
			var span := r.randi_range(3, 5)                                 # 정문 앞 · 길 위를 오간다 — 한쪽 끝에서 쉬는 시간도 매번 다르게
			opts["route"] = [[c.x - span, c.y, r.randf_range(1.5, 4.0)], [c.x + span, c.y, r.randf_range(1.5, 4.0)]]
		else:
			opts["stance"] = "hold"
		var e := host.combat.spawn("CR-305", _post_pos(i, r), host.map, st, opts)
		e.set_meta("s04_post", i)
		bots[i] = e
		if v("SQ_S04_HOT") == 1:
			_hostile_one(e)
		else:
			_calm(e)
	_log("파수 %d기" % bots.filter(func(b): return is_instance_valid(b)).size())


func _clear_posts() -> void:
	for i in 3:
		_drop(i)
	posts_on = false
	if not host.combat.in_combat():
		st.vars.set_v("SQ_S04_HOT", 0)                                      # 놓쳤다 — 다음에 오면 다시 정지 명령부터
	_reset_halt()
	if helpers:
		_helpers_out()


func _drop(i: int) -> void:
	var e: Enemy = bots[i]
	if is_instance_valid(e) and not e.cmb.dead:
		host.combat.drop_enemy(e)
	bots[i] = null


func _calm(e: Enemy) -> void:
	e.cmb.team = "calmsentry"
	e.foes.clear()


func _hostile_one(e: Enemy) -> void:
	e.cmb.team = "enemysentry"
	e.foes = ["player", "ally"]
	e.wake()
	e.brain.gauge = 100.0


## 제압: 파수 셋이 함께 움직인다(관제망 한 판정)
func _hostile_all(why: String) -> void:
	st.vars.set_v("SQ_S04_HOT", 1)
	for e in bots:
		if is_instance_valid(e) and not e.cmb.dead:
			_hostile_one(e)
	_reset_halt()
	_log("파수 적대(%s)" % why)


func _on_provoked(team: String) -> void:
	if team == "calmsentry":
		_hostile_all("먼저 쏨")


func _reset_halt() -> void:
	for i in 3:
		halt[i] = -1.0
		warned[i] = false


## 정지 명령: 어른이 5칸 안(쪼그리면 1.5칸) → 3초(관리자 후보는 4.5초) → 경고 사격 → 3초 → 제압. 물러나면 풀린다
func _halt_step(dt: float) -> void:
	if not posts_on or pause_t > 0.0 or chase_t > 0.0 or v("SQ_S04_HOT") == 1 or not _world():
		return
	var crouch: bool = host.combat.crouch
	for i in 3:
		var e: Enemy = bots[i]
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		var d := host.player.loco.logical.distance_to(e.loco.logical) / 32.0
		var seen := d <= (HALT_CROUCH if crouch else HALT_R)
		if halt[i] < 0.0:
			if seen and _safe():
				halt[i] = 0.0
				warned[i] = false
				_halt_said(i)
			continue
		if d > HALT_R + 2.0:
			halt[i] = -1.0                                                  # 물러났다
			warned[i] = false
			if i == 0:
				_halt_scene = false
			host.hint("파수-3: '이동을 확인했습니다.'", 2.5)
			continue
		if host.box.active or host.ev.busy():
			continue                                                        # 관리자 후보와 말하는 동안은 센다지 않는다
		halt[i] += dt
		var limit := HALT_SECS + (KCODE_SECS if v("V_REGCARD") >= BJ_REG else 0.0)
		if not warned[i] and halt[i] >= limit:
			warned[i] = true
			halt[i] = 0.0
			e.loco.facing = _face_to(e)
			host.hint("파수-3이 하늘로 경고 사격! '마지막 경고. 판독 불능자는 물러나십시오.'", 3.0)
			_log("경고 사격")
		elif warned[i] and halt[i] >= HALT_SECS:
			_hostile_all("정지 불응")
			return


func _face_to(e: Enemy) -> int:
	return Locomotion.dir_of(host.player.loco.logical - e.loco.logical)


func _halt_said(i: int) -> void:
	if i == 0 and v("V_REGCARD") >= BJ_REG and not _halt_scene and v("SQ_S04_SLEEP") == 0:
		_halt_scene = true
		host.play_scene("SQS04_HALT")                                       # 관리자 후보: 파수가 멈칫하고 명령을 기다린다(PK-103)
		return
	host.hint("파수-3: '정지. 판독 불능. 등록 창구로 가십시오. 3초 안에 물러나십시오.'", 3.0)


## 관리자 명령: 파수 셋 순찰 정지(60초)
func _pause_all() -> void:
	pause_t = PAUSE_SECS
	for e in bots:
		if is_instance_valid(e) and not e.cmb.dead:
			e.set_meta("s04_route", e.route.duplicate())
			e.route.clear()
	_reset_halt()


func _resume() -> void:
	for e in bots:
		if is_instance_valid(e) and not e.cmb.dead and e.has_meta("s04_route"):
			e.route = e.get_meta("s04_route")
			e.remove_meta("s04_route")
	_halt_scene = false
	if _world() and posts_on:
		host.hint("파수의 얼굴판이 다시 켜진다. 순찰 재개.", 3.0)


func _on_killed(_eid: String, _alive: int) -> void:
	for i in 3:
		var e: Enemy = bots[i]
		if is_instance_valid(e) and e.cmb.dead and not e.has_meta("s04_dead"):
			e.set_meta("s04_dead", true)
			st.vars.set_v("SQ_S04_KILLED", v("SQ_S04_KILLED") | (1 << i))
			bots[i] = null
			_log("파수 %s 부서짐(%d)" % [POSTS[i], v("SQ_S04_KILLED")])
	for i in 2:
		var t: Enemy = turrets[i]
		if is_instance_valid(t) and t.cmb.dead and not t.has_meta("s04_dead"):
			t.set_meta("s04_dead", true)
			st.vars.set_v("SQ_S04_TKILLED", v("SQ_S04_TKILLED") | (1 << i))
	if v("SQ_S04_KILLED") == 7 and v("SQ_S04_B") == 0:
		st.vars.set_v("SQ_S04_B", 1)
		_deed("SQS04_B_GS", {"GS": -6}, "봉천 주민센터 앞 수호자 셋이 부서졌다", [], ["GS"])   # 한가람이 잔해를 보고 안다(소문 12시간 — 기획 24시간은 정합)
		if v("SQ_S04_HELD") == 1:
			_out(2)
			st.call_fn("karma", [50])
			_deed("SQS04_B", {"JC_BC": 6}, "봉천 주민센터 앞 파수 셋을 부수고 남솔을 꺼냈다", ["JC_BC"])
			host.hint("파수 셋이 모두 멈췄다. 남태하와 감시조가 주민센터로 달려가 철망을 비틀어 연다.", 6.0)
		else:
			host.hint("봉천의 파수 셋이 모두 멈췄다.", 4.0)
		st.vars.set_v("SQ_S04_HOT", 0)
		if helpers:
			_helpers_out()


# ---------------------------------------------------------------- 남태하 감시조 둘(해법 B 지원 — 계단참①에서 내려온다)
func _helpers_in() -> void:
	helpers = true
	st.vars.set_v("SQ_S04_FIGHT", 1)
	host.refresh_npcs()
	var from := host.map.mark_pos("X-BC:land1")
	for k in 2:
		var id: String = ["N-R01-035", "N-R01-036"][k]
		if st.dead.has(id):
			continue
		host.ev._show_actor(id, from + Vector2((k * 2 - 1) * 40.0, 0), "S", _sheet(id))
		var a: Actor = host.ev.actors.get(id)
		if a != null:
			var c := host.combat.add_ally(id, a, 60.0, "W-002")
			c.hp_floor = 1.0                                                    # 감시조는 쓰러져도 죽지 않는다
	host.hint("계단참①에서 감시조 둘이 뛰어 내려온다.", 4.0)


func _helpers_out() -> void:
	helpers = false
	host.combat.clear_allies()
	for id in ["N-R01-035", "N-R01-036"]:
		if host.ev.actors.has(id):
			var a: Actor = host.ev.actors[id]
			host.ev.actors.erase(id)
			if is_instance_valid(a):
				host.map.remove_actor(a)
				a.queue_free()
	st.vars.set_v("SQ_S04_FIGHT", 0)
	if host.map != null:
		host.refresh_npcs()


# ---------------------------------------------------------------- 남솔이 나온다 · 보호 기간 만료
func _out(n: int) -> void:
	if v("SQ_S04_HELD") == 0:
		return
	st.vars.set_v("SQ_S04_HELD", 0)
	if v("SQ_S04_OUT") == 0:
		st.vars.set_v("SQ_S04_OUT", n)
	if stage() < 10:
		_up(10)
	_up(50)
	if host.map != null:
		host.refresh_npcs()
	_log("남솔 나옴(%d)" % n)


## 72시간: 파수가 '보호 기간 만료'를 방송하고 남솔을 노량진 관제 중계소로 안고 간다 — 다음 날 류정이 돌려보낸다(BC −5 · GS +3)
func _expire() -> void:
	var carrier := -1
	for i in 3:
		if not _killed(i):
			carrier = i
			break
	if carrier < 0:
		return
	_out(5)
	st.vars.set_v("SQ_S04_AWAY", day() + 1)
	st.vars.set_v("SQ_S04_GUARD_BACK", _now() + CARRY_MIN)
	if carrier != 0:
		st.vars.set_v("SQ_S04_GUARD_BACK", 0)
	if _world() and _dist_mark("sentry") <= POST_R:
		host.hint("파수-3: '보호 기간 만료. 대상을 가장 가까운 관제 시설로 이송합니다.' 파수가 남솔을 안고 순례로 쪽으로 걷는다.", 7.0)
		if carrier == 0 and is_instance_valid(bots[0]):
			var p: Vector2 = bots[0].loco.logical
			_drop(0)
			host.ev._show_actor("S04_CARRY", p, "W", "rb_cr305_carry_loco")
			var a: Actor = host.ev.actors.get("S04_CARRY")
			if a != null:
				a.loco.custom = {"walk": {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3], "speed_t": 1.75}}
				host.map.blockers.erase(a)
				carry_on = true
				_carry_t = 0.0
				_walk(a, host.map.mark_pos("X-BC:sbf1"))
	_log("보호 기간 만료 — 노량진으로")


# ---------------------------------------------------------------- 하루 판정(06:00): 노량진에서 돌아옴
func _on_day(d: int) -> void:
	if v("SQ_S04_AWAY") > 0 and d >= v("SQ_S04_AWAY"):
		st.vars.set_v("SQ_S04_AWAY", 0)
		_deed("SQS04_FAR", {"JC_BC": -5, "GS": 3}, "각성회가 '등록 아동'으로 맞은 봉천 아이를 류정이 돌려보냈다", ["JC_BC"])
		if host.map != null:
			host.refresh_npcs()
		_log("남솔 돌아옴")


# ---------------------------------------------------------------- 그림: 잠든 파수 · 잔해 · 흰 천과 대기등(월드 청크에 굽지 않고 진행기가 세운다)
func _looks_tick() -> void:
	if _dist_mark("sentry") > POST_R + 10.0:
		if not looks.is_empty():
			for k in looks:
				host.map.remove_runtime_prop(looks[k])
			looks.clear()
		return
	var want := {}
	if v("SQ_S04_WAKE") == 0 or v("SQ_S04_SLEEP") > 0 or _killed(0):
		want["guard"] = [_home_cell(0), "sentry_down"]                     # 잠든 파수(깨어나기 전 · 다시 잠듦) · 잔해
	for i in [1, 2]:
		if _killed(i) or (v("SQ_S04_WAKE") > 0 and v("SQ_S04_SLEEP") > 0):
			want[POSTS[i]] = [_home_cell(i), "sentry_down"]
	if v("SQ_S04_OUT") == 4:
		want["cloth"] = [_home_cell(0) + Vector2i(0, 1), "care_cloth"]     # 해법 D 후일담: 흰 천 · 대기등 램프
		want["lamp"] = [_home_cell(0) + Vector2i(2, 0), "radar_beacon"]
	for k in looks.keys():
		if not want.has(k) or looks[k].get("cell") != want[k][0] or looks[k].get("name") != want[k][1]:
			host.map.remove_runtime_prop(looks[k])
			looks.erase(k)
	for k in want:
		if looks.has(k):
			continue
		var p := host.map.add_runtime_prop(str(want[k][1]), want[k][0])
		if not p.is_empty():
			p["cell"] = want[k][0]
			looks[k] = p
			if k == "lamp":
				host.map.set_prop_state(want[k][0], "dim")


## 잠들거나 부서진 자리(서성임과 상관없이 원래 자리)
func _home_cell(i: int) -> Vector2i:
	var lo := v("SQ_S04_LOITER")
	st.vars.set_v("SQ_S04_LOITER", 0)
	var c := _post_cell(i)
	st.vars.set_v("SQ_S04_LOITER", lo)
	return c


# ---------------------------------------------------------------- 관악 레이더 중계소(X-RD): 감시포 둘 · 경광 · 약한 철조망 · 핍-보이 신호
func _radar_tick() -> void:
	var d := _dist_mark("X-RD:dome_yard")
	if d <= POST_R and not radar_on:
		radar_on = true
		_radar_look = ""
	if radar_on and radar_awake():
		_spawn_turrets()                                                    # 깨어 있는 동안: 빠진 감시포를 세운다(부순 것은 그대로)
	elif d > POST_R + 10.0 and radar_on and not host.combat.in_combat():
		radar_on = false
		for i in 2:
			if is_instance_valid(turrets[i]) and not turrets[i].cmb.dead:
				host.combat.drop_enemy(turrets[i])
			turrets[i] = null
		for p in radar_props:
			host.map.remove_runtime_prop(p)
		radar_props.clear()
		_radar_look = ""
		return
	if not radar_on:
		return
	if not radar_awake():
		for i in 2:
			if is_instance_valid(turrets[i]) and not turrets[i].cmb.dead:
				host.combat.drop_enemy(turrets[i])                         # 전지가 꺼졌다: 감시포가 고개를 떨군다
				turrets[i] = null
	var want := "%d%d%d" % [v("SQ_S04_BATT"), 1 if radar_awake() else 0, v("SQ_S04_FENCE")]
	if want == _radar_look:
		return
	for p in radar_props:
		host.map.remove_runtime_prop(p)
	radar_props.clear()
	var fc: Vector2i = host.map.tile_of(host.map.mark_pos("X-RD:fence_weak"))
	radar_props.append(host.map.add_runtime_prop("chain_fence_cut" if v("SQ_S04_FENCE") == 1 else "chain_fence", fc))
	if v("SQ_S04_BATT") == 0:
		var bc: Vector2i = host.map.tile_of(host.map.mark_pos("X-RD:dome_yard")) + Vector2i(0, -4)
		var b := host.map.add_runtime_prop("radar_beacon", bc)                # 돔 꼭대기 경광: 깨어 있으면 앰버, 잠들면 흐림(뽑으면 영영 꺼진다)
		radar_props.append(b)
		if not radar_awake():
			host.map.set_prop_state(bc, "dim")
	_radar_look = want


func _spawn_turrets() -> void:
	for i in 2:
		if (v("SQ_S04_TKILLED") >> i) & 1 == 1 or is_instance_valid(turrets[i]):
			continue
		var p := host.map.mark_pos("X-RD:t%d" % (i + 1))
		var e := host.combat.spawn("CR-320", p, host.map, st, {"lv": 6, "dir": "S", "stance": "hold"})
		turrets[i] = e


## 단계 40: 레이더 반경 80타일 — 핍-보이 등록 카드 칸 '반송파 강함'
func _signal_tick() -> void:
	if stage() < 10 or stage() >= 40 or not radar_awake():
		return
	if _tiles(_ptile(), RADAR) <= SIGNAL_R and _safe():
		host.hint("핍-보이 등록 카드 칸이 혼자 깜박인다 — '반송파 강함'. 관악산 정상 쪽이다.", 6.0)
		_up(40)


# ---------------------------------------------------------------- 해법 D 각성회 정비 의식(도착 시각 D_AT, 두 시간)
## 시트 이름: 맵 인물 시트가 없으면 이야기 인물 시트(st_n_r01_055 꼴)
func _sheet(id: String) -> String:
	var s: String = str(host.ev.cast_sheets.get(id, ""))
	return s if s != "" else "st_" + id.to_lower().replace("-", "_")


func _ritual_tick() -> void:
	if v("SQ_S04_D") != 1 or _now() < v("SQ_S04_D_AT"):
		return
	if _dist_mark("sentry") > POST_R:
		return
	if not _safe():
		return
	var p := host.map.mark_pos("sentry")
	host.ev._show_actor("N-R01-055", p + Vector2(-40, 32), "N", _sheet("N-R01-055"))
	if v("AFF_GS") >= 20 and not st.dead.has("C-053"):
		host.ev._show_actor("C-053", p + Vector2(48, 32), "N", _sheet("C-053"))
	for id in ["N-R01-055", "C-053"]:
		if host.ev.actors.has(id):
			host.map.blockers.erase(host.ev.actors[id])
	host.play_scene("SQS04_RITUAL")


## 주인공이 그 자리에 없다: 의식은 결과만(은솔은 아무도 막지 않는다 — 우호 이상이면 시험 가동)
func _ritual_away() -> void:
	if v("SQ_S04_D") != 1 or _now() < v("SQ_S04_D_AT") + RITUAL_MIN:
		return
	if v("AFF_GS") >= 20 and v("SQ_S04_TEST") == 0:
		st.vars.set_v("SQ_S04_TEST", 1)
	_ritual_done()


func _ritual_done() -> void:
	if v("SQ_S04_D") != 1:
		return
	st.vars.set_v("SQ_S04_D", 2)
	for id in ["N-R01-055", "C-053"]:
		if host.ev.actors.has(id):
			var a: Actor = host.ev.actors[id]
			host.ev.actors.erase(id)
			if is_instance_valid(a):
				host.map.remove_actor(a)
				a.queue_free()
	if v("SQ_S04_SLEEP") == 0:
		st.vars.set_v("SQ_S04_SLEEP", 3)
	if v("SQ_S04_HELD") == 1:
		_out(4)
	st.call_fn("karma", [25])
	st.vars.set_v("PD_R01_GS", v("PD_R01_GS") + 5)                         # 판도 PD-R01-2 각성회 +5
	_deed("SQS04_D", {"GS": 6, "JC_BC": 3}, "각성회 정비 당번이 봉천 주민센터 앞 수호자 셋을 정비 모드로 눕혔다", ["GS", "JC_BC"])
	if _world() and posts_on:
		_clear_posts()
	_facts()
	_log("정비 의식 끝(시험 가동 %d)" % v("SQ_S04_TEST"))


# ---------------------------------------------------------------- 맵 바뀜
func _on_map(id: String) -> void:
	var fresh := host.map != _map_ref
	_map_ref = host.map
	if fresh:
		bots = [null, null, null]
		turrets = [null, null]
		posts_on = false
		radar_on = false
		looks.clear()
		radar_props.clear()
		_radar_look = ""
		carry_on = false
		helpers = false
		_reset_halt()
		_halt_scene = false
		if v("SQ_S04_FIGHT") == 1:
			st.vars.set_v("SQ_S04_FIGHT", 0)
	if id == "K-33":
		host.map.set_prop_state(Vector2i(10, 4), "413" if v("SQ_S04_WAKE") > 0 else "")
		if v("SQ_S04_HELD") == 1:
			if stage() < 20:
				_up(20)
			if stage() < 30 and _safe():
				host.play_scene("SQS04_BROADCAST")                             # 민원실 천장 확성기도 같은 방송을 한다
		elif v("SQ_S04_OUT") > 0:
			host.map.set_prop_state(Vector2i(20, 10), "open")
			host.map._put_solid(20, 10, 0)
	if id == "K-36":
		if v("SQ_S04_BATT") == 1:
			host.map.set_prop_state(Vector2i(4, 5), "empty")
			host.map.set_prop_state(Vector2i(13, 4), "off")
	if _world() and v("SQ_S04_CHASE") == 1:
		st.vars.set_v("SQ_S04_CHASE", 0)
		if _awake():
			chase_t = CHASE_SECS                                               # '보호 대상 이탈' — 30초 추격
			st.vars.set_v("SQ_S04_HOT", 1)
			host.hint("파수-3: '보호 대상 이탈. 보호 대상 이탈.' 파수들이 정문으로 몰려든다!", 5.0)


func _chase_end() -> void:
	st.vars.set_v("SQ_S04_HOT", 0)
	if _awake() and v("SQ_S04_LOITER") == 0 and v("SQ_S04_OUT") == 3:
		st.vars.set_v("SQ_S04_LOITER", _now() + HOLD_MIN)                    # 이후 72시간 아랫문 앞을 서성인다(상인 휴업 · 밤 출입 경보)
	if posts_on:
		_clear_posts()
	if _world():
		host.hint("파수들이 추격을 멈춘다. 셋 다 봉천 아랫문 앞으로 걸어가 선다.", 5.0)
	_log("추격 끝 — 아랫문 서성임")


## 상인 휴업(해법 C 뒤 72시간): 봉천 상인은 아랫문 앞 파수 때문에 문을 닫는다
func closed(settle: String) -> bool:
	return settle == "BC" and v("SQ_S04_LOITER") > _now()


# ---------------------------------------------------------------- 원고 명령(@cmd s04 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"auth":                                                         # A 관리자 인증: 보호 해제 · 파수 1기당 수배도 +3(하루 +9)
			var n := bots.filter(func(b): return is_instance_valid(b) and not b.cmb.dead).size()
			st.call_fn("wanted", [3 * maxi(1, n), "auth"])
			_out(1)
			st.call_fn("karma", [50])
			_deed("SQS04_A", {"JC_BC": 3, "GS": 5, "BJ": 0}, "봉천 주민센터 앞 파수가 볼트에서 나온 사람의 명령을 들었다 — '관리자님 명령'", ["JC_BC"])
			_pause_all()
		"pause":                                                        # 아이가 없을 때의 관리자 명령: 순찰 정지만(수배도는 같다)
			var n := bots.filter(func(b): return is_instance_valid(b) and not b.cmb.dead).size()
			st.call_fn("wanted", [3 * maxi(1, n), "auth"])
			_pause_all()
		"back":
			pass
		"cage":                                                         # C 은신 구출: 철망을 땄다 — 바깥에 나가면 '보호 대상 이탈'
			if host.map != null and _zone() == "K-33":
				host.map.set_prop_state(Vector2i(20, 10), "open")
				host.map._put_solid(20, 10, 0)
			if v("SQ_S04_HELD") == 1:
				var asleep := v("SQ_S04_SLEEP") >= 1
				_out(3)
				st.call_fn("karma", [50])
				_deed("SQS04_C", {"JC_BC": 3}, "누군가 주민센터 철망을 따고 남솔을 빼냈다", ["JC_BC"])
				if not asleep:
					st.vars.set_v("SQ_S04_CHASE", 1)
		"red":                                                          # 남태하: 산꼭대기 돔이 깜박였다
			st.vars.set_v("SQ_S04_RED", 1)
			_up(40)
		"help":
			st.vars.set_v("SQ_S04_HELP", 1)
		"gs":                                                           # D: 한가람 — 여섯 시간 뒤 정비 당번이 온다
			if v("SQ_S04_D") == 0:
				st.vars.set_v("SQ_S04_D", 1)
				st.vars.set_v("SQ_S04_D_AT", _now() + D_TRAVEL)
				host.refresh_npcs()
		"eun":
			st.vars.set_v("SQ_S04_TEST", int(a[1]) if a.size() > 1 else 0)
		"ritual":
			host.advance_minutes(RITUAL_MIN)
			_ritual_done()
		"fence":
			st.vars.set_v("SQ_S04_FENCE", 1)
			_radar_look = ""
		"batt":                                                         # E 전지 회수: R01 관제 장치 전부 잠듦 · 거점 '관악산 송신소' 공백 고정
			if v("SQ_S04_BATT") == 0:
				st.vars.set_v("SQ_S04_BATT", 1)
				st.call_fn("give", ["M-162", 1])
				if v("SQ_S04_WAKE") > 0 and v("SQ_S04_SLEEP") == 0:
					st.vars.set_v("SQ_S04_SLEEP", 1)
				st.vars.set_v("SQ_S04_PD_LOCK", 1)
				if v("SQ_S04_WAKE") > 0:
					_deed("SQS04_E", {"GS": -10, "JC_BC": 6}, "관악산 정상 돔의 경광이 꺼졌다 — 누군가 레이더 전지를 뽑았다")
				if host.map != null and _zone() == "K-36":
					host.map.set_prop_state(Vector2i(4, 5), "empty")
					host.map.set_prop_state(Vector2i(13, 4), "off")
				_radar_look = ""
		"batt_bc":                                                      # 인도처: 대장간 남무진(옥탑 조명 · 화로 — BC +3 · 봉천 밤 RE −10%)
			_hand("BC")
		"batt_gs":                                                      # 각성회 한가람(대기등 예비 전원 — GS +8)
			_hand("GS")
		"batt_jh":                                                      # 지하시장 마영식(150캡 · JH +2)
			_hand("JH")
		"letter":                                                       # 아이의 감사 편지: 화술 +10 영구(첫 1회 — SQ-N19와 같은 ID)
			if v("M303_BONUS") == 0:
				st.vars.set_v("M303_BONUS", 1)
				st.vars.set_v("PC_SKP_SPEECH", v("PC_SKP_SPEECH") + 10)
				host.hint("남솔의 편지 — 말이 조금 부드럽게 나온다(화술 +10)", 5.0)
	done.call()


## 전지 인도(전지는 원고가 건넨다 — [물건:M-162] 선택지 · take): 인도처는 한 번(전지는 하나 — P3)
func _hand(to: String) -> void:
	if v("SQH_BATT") != -1:
		return
	match to:
		"BC":
			st.vars.set_v("SQH_BATT", 81)
			st.call_fn("aff", ["JC_BC", 3])
		"GS":
			st.vars.set_v("SQH_BATT", 7)
			st.call_fn("aff", ["GS", 8])
		"JH":
			st.vars.set_v("SQH_BATT", 6)
			st.call_fn("caps", [150])
			st.call_fn("aff", ["JH", 2])
	_log("전지 인도 %s" % to)
