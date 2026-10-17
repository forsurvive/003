## 영등포 · 여의도(R02) 사이드 퀘스트 SQ-S11 「토요일의 여의도」 진행기(단계 1-11j, SD-04a §5.4). 원고: script/act1/SQ-S11.txt ·
##   MQ-103_INJI · MQ-104_POST · SQS10_WOO · JM_SAGONG(넘겨받기 · 거절 한 줄) · R01_R02 K-02_LEAFLET(LR-11) · terms/r02_police.txt(LR-12 · 별첨) · world/radio.txt.
##   맵: K-29 경찰서(경비 파수 · 배관 통로 · 프린터) · KH-01 로비 · KH-02 본회의장 · KH-03 기록관 서고 · 월드 국회 앞마당(r02.spots) · J-03 인지영 벤치.
##   설계안 docs/seoul-fallout/_plans/SQ-S11_plan.md(§6 계획 단계 재미 검수 반영).
## 사실은 변수 한 곳(P1): 명단의 행방 SQH_LIST11(−1 · 4 · 14 · 1 · 0) — 처음 넘긴 곳 · 원본의 행방 SQH_RECESS(−1 · 14 · 1 · 0 · 97). 원본은 한 장(P3).
## 단계는 이 진행기 한 곳에서만, 오르기만 한다(SD-20). 원본을 든 지 5일째 반출 소문 · 7일째 '보관'으로 닫힌다.
class_name SideS11
extends Node

const INJI := "N-R02-014"                   ## 인지영(지하시장 원로 구울)
const LOG := "N-R02-027"                    ## 의사록(국회 기록광)
const WOO := "N-R02-026"                    ## 우도하(남산 방송 기술자)
const SUN := "C-034"                        ## 선우진(계엄군 중위 — 환승센터 터 초소)
const LIST_ID := "M-305"
const DOC_ID := "M-306"
const KEY_ID := "M-323"
const BAND_ID := "A-084"
const WARN_DAYS := 5
const KEEP_DAYS := 7
const XP := 350
const MAX_PRINT := 3
const ISLAND := Rect2i(745, 1045, 145, 85)  ## 여의도(국회 758,1057 ~ 금탑 883,1129) — 낮 순찰 06~20시
const READ_R := 3.0                         ## 낭독 자리(kh_read)에 이만큼 다가오면
const NEAR_R := 8.0                         ## 인지영이 '곁에 있다'
const MEET_R := 6.0                         ## 순찰 분대장이 말을 거는 거리
const WAKE_R := 3.0                         ## 경비 파수가 깨는 거리(웅크리면 1.5)
const GUARD_CELL := Vector2i(4, 10)
const KEY_BOX := Vector2i(19, 3)            ## K-29 무기 보관함(무기고 안)
const PRINTER := Vector2i(6, 3)
const STACK_DOOR := Vector2i(24, 9)         ## KH-03 제7 서고 문
const BOX := Vector2i(24, 5)                ## KH-03 원본 보존 상자
const GAP_SHELF := Vector2i(26, 3)

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var squad: Dictionary = {}                  ## 지금 선 순찰 분대: {"men": [Enemy], "lead": Enemy, "state", "t", "kind"}
var _guard_e: Enemy = null                  ## 부수기로 깨운 경비 파수


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s11"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.mates.hid.connect(_on_hid)
	host.combat.mates.regrouped.connect(_on_regrouped)
	host.combat.enemy_down.connect(_on_down)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func q(k: String) -> int:
	return int(st.vars.get_v("SQ_S11_" + k))


func _sq(k: String, n: int) -> void:
	st.vars.set_v("SQ_S11_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[토요일] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S11")


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S11", n)
		_log("단계 %d" % n)


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _has(id: String) -> bool:
	return int(st.items.get(id, 0)) > 0


func _hour() -> int:
	return Clock.hour(host.date_text)


## 지금 시각의 분(0~59)
func _mm() -> int:
	var t := Clock.parse(host.date_text)
	return int(t[4]) if not t.is_empty() else 0


func _busy() -> bool:
	return (host.box != null and host.box.active) or host.ev.busy() or host.busy


# ---------------------------------------------------------------- 발동 · 따라 올림(P2)
func _start(why: String) -> void:
	if v("V_ACT") < 1:
		return
	if q("START") == 0:
		_sq("START", day())
		host.hint("토요일의 여의도 — 열한 명의 이름과 국회가 멈춘 날의 종이 한 장.", 5.0)
		_log("발동(%s)" % why)
	_up(10)
	_catch_up()


func _catch_up() -> void:
	if q("START") == 0:
		if q("REPORT") == 1 or q("PRINT") > 0 or q("TOOK") == 1 or q("LEAF") == 1:
			_start("기록")
		return
	if q("TOLD") == 1 or q("REPORT") == 1:
		_up(20)
	if q("PRINT") > 0 or _has(LIST_ID):
		_up(30)
	if q("KNOWS") == 1 or q("STACK") == 1 or q("TOOK") == 1:
		_up(40)
	if q("TOOK") == 1:
		_up(50)
	if q("DONE") == 1:
		_up(100)


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	if host.map == null or host.player == null or v("V_ACT") < 1:
		return
	tick()


func tick() -> void:
	_flags()
	_catch_up()
	_escort_tick()
	if host.map is WorldMap:
		_read_tick()
		_squad_tick()
	if _zone() == "K-29":
		_guard_tick()


## 우도하 · 선우진에게 꺼낼 국회 기록이 있나(MQ-104_POST · SQS10_WOO가 넘겨준다)
func _flags() -> void:
	var doc := _has(DOC_ID) and v("SQH_RECESS") < 0
	_sq("WOOQ", 1 if not st.is_dead(WOO) and (doc or (_has(LIST_ID) and q("WOOL") == 0)) else 0)
	_sq("SUNQ", 1 if not st.is_dead(SUN) and (doc or (_has(LIST_ID) and q("SUNL") == 0)) else 0)
	if _zone() == "K-29" and host.player != null:
		var t := host.map.tile_of(host.player.loco.logical)
		_sq("ATOFFICE", 1 if t.x <= 7 and t.y <= 9 else 0)


# ---------------------------------------------------------------- 인지영 동행(일시 동행 v2 — 호위 대상, 싸우지 않는다)
func _mate() -> Dictionary:
	return host.combat.mates.get_mate(INJI)


func _inji_dist() -> float:
	var m := _mate()
	if m.is_empty() or not is_instance_valid(m["actor"]) or str(m["mode"]) == "hidden":
		return 1e9
	return (m["actor"] as Actor).loco.logical.distance_to(host.player.loco.logical) / 32.0


func _say(text: String, secs := 5.0) -> void:
	host.hint("인지영: \"%s\"" % text, secs)


func _join() -> void:
	_sq("ESCORT", 1)
	for n in host.npcs.duplicate():                                        # 벤치의 인지영을 동행으로 떼어 낸다(맵 인물 다시 세우기가 지우지 않게)
		if str(n["id"]) == INJI:
			host.npcs.erase(n)
			if is_instance_valid(n["actor"]):
				host.map.blockers.erase(n["actor"])
			host.sync_residents()
	if _mate().is_empty():
		if host.ev.actors.has(INJI):
			host.ev.handlers["buddy"].call([INJI], func() -> void: pass)
		else:
			host._bring_buddy(INJI)
	host.combat.mates.set_mode(INJI, "escort")
	_up(30)
	_log("호위 시작")


func _drop_mate() -> void:
	if not _mate().is_empty():
		var a = _mate()["actor"]
		host.combat.mates.remove(INJI)
		host._sync_mates()
		if is_instance_valid(a) and host.ev.actors.has(INJI):
			host.ev.run("hide", [INJI], func() -> void: pass)
	host.combat.mates.away.erase(INJI)


func _escort_tick() -> void:
	if q("ESCORT") != 1:
		return
	if st.is_dead(INJI):
		_sq("ESCORT", 3)
		_drop_mate()
		host.hint("인지영이 쓰러졌다. 명단은 아직 주머니에 있다. 계단까지 갈 사람은 이제 하나다.", 6.0)
		_log("인지영 사망 — 낭독 닫힘")
		return
	if v("SQH_LIST11") >= 0:                                               # 명단이 다른 데로 갔다(P1): 그녀는 혼자 돌아간다
		_sq("ESCORT", 3)
		_drop_mate()
		host.refresh_npcs()
		host.hint("인지영이 걸음을 멈춘다. \"그 종이는 먼저 간 데로 갔네. 나는 벤치로 돌아갈게.\"", 6.0)
		return
	if _mate().is_empty() and not host.combat.mates.away.has(INJI) and not _busy():
		host._bring_buddy(INJI)                                            # 불러오기 뒤 · 맵을 건넌 뒤 다시 곁에
		host.combat.mates.set_mode(INJI, "escort")


## 호위 대상은 주인공이 멀어지면 그 자리에 숨는다(Companions hide_far) — 한 줄씩 알린다
func _on_hid(id: String) -> void:
	if id == INJI:
		host.hint("인지영이 근처 그늘에 앉았다 — 돌아와 곁에 서면 다시 따라온다.", 5.0)


func _on_regrouped(id: String) -> void:
	if id != INJI:
		return
	var lines := ["왔네. 늙은 다리는 쉬어 가야 해.", "그날도 이렇게 쉬어 가며 걸었어. 행진은 원래 느린 거야.", "여기 앉아서 간판 글씨를 셌어. 반은 영어더라."]
	_say(lines[(day() + q("PDAY")) % lines.size()], 4.0)


## 국회 정면 계단(월드 발견 자리 표지 kh_read)에 인지영과 함께 닿으면 낭독
func _read_tick() -> void:
	if q("ESCORT") != 1 or q("READ") != 0 or _busy() or not squad.is_empty():
		return
	var marks: Dictionary = host.map.data.get("marks", {})
	if not marks.has("kh_read"):
		return
	if host.player.loco.logical.distance_to(host.map.mark_pos("kh_read")) / 32.0 > READ_R or _inji_dist() > NEAR_R:
		return
	host.play_scene("SQS11_READ")


func _step_cell(i: int) -> Vector2i:
	var m: Array = host.map.data.get("marks", {}).get("kh_steps", [])
	if m.is_empty():
		return Vector2i(-1, -1)
	return Vector2i(int(m[0]) + i - 1, int(m[1]))


func _steps_state() -> void:
	if not (host.map is WorldMap) or not host.map.data.get("marks", {}).has("kh_steps"):
		return
	for i in range(1, 12):
		var on := q("READ") == 1 or (q("READ") == 2 and i == 11)
		host.map.set_prop_state(_step_cell(i), "leaf" if on else "")
	var fm: Array = host.map.data.get("marks", {}).get("kh_flag", [])
	if not fm.is_empty():
		host.map.set_prop_state(Vector2i(int(fm[0]), int(fm[1])), "bj" if v("PD_R02_KH") == 1 else "")


# ---------------------------------------------------------------- 여의도 낮 순찰(06~20시): 1 구울과 함께 · 2 원본 반출 소문 뒤(재미 검수 4 · 6)
func _patrol_kind() -> int:
	if q("ESCORT") == 1 and _inji_dist() <= NEAR_R + 4.0:
		return 1
	if q("TOOK") == 1 and v("SQH_RECESS") < 0 and _has(DOC_ID) and q("WARN") == 1:
		return 2
	return 0


func _squad_tick() -> void:
	if not squad.is_empty():
		_squad_live()
		return
	var h := _hour()
	if h < 6 or h >= 20 or q("PDAY") == day() or _busy():
		return
	if host.enc_live != null and host.enc_live.chasing():
		return                                                             # 생포 추적대가 떠 있으면 미룬다(P4)
	var t := host.map.tile_of(host.player.loco.logical)
	if not ISLAND.has_point(t):
		return
	var kind := _patrol_kind()
	if kind == 0 or host.player.loco.motion == "idle":
		return                                                             # 걷는 중에만(바라보는 쪽 = 가는 쪽)
	_squad_spawn(kind)


func _squad_spawn(kind: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = absi(hash("s11:%d:%d:%s" % [kind, day(), str(st.vars.get_v("P_REGNO"))]))
	var me := host.player.loco.logical
	var f: Vector2 = Locomotion.VEC[host.player.loco.facing].normalized()
	if kind == 1 and host.map.data.get("marks", {}).has("kh_read"):
		var goal := host.map.mark_pos("kh_read")
		if goal.distance_to(me) > 16.0 * 32.0:
			f = (goal - me).normalized()                                     # 국회 계단 쪽 길목에 선다
	var side := f.rotated(PI / 2.0 if r.randf() < 0.5 else -PI / 2.0)
	var at := me + (f * r.randf_range(10.0, 13.0) + side * r.randf_range(-3.0, 3.0)) * 32.0
	var c := _free_tile(host.map.tile_of(at))
	if c.x < 0:
		return
	_sq("PDAY", day())
	_sq("PKIND", kind)
	_sq("PSAID", 0)
	var men: Array = []
	var lead: Enemy = null
	for k in r.randi_range(3, 4):                                         # 원문 '계엄군 분대 4'(분대장 1 + 계엄병 2~3)
		var off := Vector2(((k % 2) * 2 - 1) * (k + 1) / 2, (k / 2)) if k > 0 else Vector2.ZERO
		var cc := _free_tile(c + Vector2i(off))
		if cc.x < 0:
			cc = c
		var pos := Vector2(cc.x * 32 + 16, cc.y * 32 + 16)
		var id := "CR-403" if k == 0 else "CR-401"
		var e := host.combat.spawn(id, pos, host.map, st, {"lv": r.randi_range(6, 9), "team": "calm_s11", "foes": [], "dir": _dir_to(pos, me),
			"sheet": "en_cr403_loco" if k == 0 else "en_cr401_loco"})
		e.set_meta("s11", 1)
		men.append(e)
		if k == 0:
			lead = e
	squad = {"men": men, "lead": lead, "state": "near", "t": 0.0, "kind": kind}
	host.hint("계엄군 순찰 분대 %d명이 앞길을 훑는다." % men.size(), 4.0)
	if kind == 1:
		_say("…저 사람들이야. 여의도는 구울 통행 금지래.", 4.0)
	_log("순찰(%d) %d명" % [kind, men.size()])


func _dir_to(from: Vector2, to: Vector2) -> String:
	var d := to - from
	if absf(d.x) > absf(d.y):
		return "E" if d.x > 0 else "W"
	return "S" if d.y > 0 else "N"


func _free_tile(c: Vector2i) -> Vector2i:
	for r in range(0, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := c + Vector2i(dx, dy)
				if not host.map.is_solid(t):
					return t
	return Vector2i(-1, -1)


func _alive(list: Array) -> Array:
	return list.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)


func _squad_live() -> void:
	var men := _alive(squad["men"])
	if men.is_empty():
		_squad_done("전멸")
		return
	var lead: Enemy = squad["lead"]
	if not is_instance_valid(lead) or lead.cmb.dead:
		lead = men[0]
		squad["lead"] = lead
	var d := lead.loco.logical.distance_to(host.player.loco.logical) / 32.0
	squad["t"] = float(squad["t"]) + 0.25
	match str(squad["state"]):
		"near":
			if fmod(float(squad["t"]), 2.0) < 0.26:                         # 길을 막으러 온다: 2초마다 주인공 쪽으로 걸음을 고친다(재미 검수 4 — 지나칠 수 없는 검문)
				for e in men:
					e.route = [[host.player.loco.logical, 30.0]]
					e._route_i = 0
					e._route_wait = 0.0
			if d <= MEET_R and not _busy():
				squad["state"] = "talk"
				for e in men:
					e.brain.state = AIBrain.S.IDLE
				host.play_scene("SQS11_PATROL")
			elif d > 30.0 or float(squad["t"]) > 60.0:
				_squad_done("지나침")
		"hostile":
			if d >= 35.0:
				Wanted.add(st, 10)                                         # 살아서 본 자가 있다(SQ-S06과 같은 값)
				host.hint("순찰 분대를 따돌렸다. …얼굴은 봤을 것이다.", 5.0)
				_squad_done("따돌림")
		"leave":
			if float(squad["t"]) > 10.0:
				_squad_done("떠남")


func _squad_hostile() -> void:
	if squad.is_empty():
		return
	squad["state"] = "hostile"
	squad["t"] = 0.0
	for e in _alive(squad["men"]):
		e.cmb.team = "enemy_s11"
		e.foes = ["player", "ally"]
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
	host.combat._rebuild_list()
	st.call_fn("aff", ["BJ", -5])


func _squad_done(why: String) -> void:
	if squad.is_empty():
		return
	for e in _alive(squad["men"]):
		e.cmb.team = "gone"
		e.foes.clear()
		e.brain.state = AIBrain.S.RETURN
		var tw: Tween = e.create_tween()
		tw.tween_interval(4.0)
		tw.tween_property(e, "modulate:a", 0.0, 2.0)
		var gone_e: Enemy = e
		tw.tween_callback(func() -> void:
			if is_instance_valid(gone_e):
				gone_e.visible = false
				host.combat.drop_enemy(gone_e))
	_log("순찰 끝(%s)" % why)
	squad = {}


func _patrol(what: String) -> void:
	match what:
		"talk", "pass":
			squad["state"] = "leave"
			squad["t"] = 0.0
			_squad_done("통과")
		"hide":
			_fade(30, "환승센터 계단 아래에서 숨을 죽인다. 군화 소리가 멀어진다.")
			_squad_done("숨음")
		"night":
			var h := _hour()
			_fade(maxi(30, (20 - h) * 60 - _mm()) if h < 20 else 30, "해가 진다. 여의도의 낮 순찰이 초소로 돌아간다.")
			_squad_done("밤까지")
		"fight":
			_squad_hostile()
		"give":                                                            # 반출 검문에 원본을 내줬다 — 비상정부가 가졌다(행방 1)
			_squad_done("회수")
			_doc_to(1, "검문에서 회수")


func _fade(minutes: int, msg: String) -> void:
	host.busy = true
	host.ev.run("fade_out", ["black", "2"], func() -> void:
		host.advance_minutes(minutes)
		host.hint(msg, 5.0)
		host.ev.run("fade_in", ["black", "2"], func() -> void: host.busy = false))


# ---------------------------------------------------------------- 영등포 경찰서: 경비 파수-3(N-PS-2)
func _guard_actor() -> Actor:
	for n in host.npcs:
		if str(n["id"]) == "N-PS-2" and is_instance_valid(n["actor"]):
			return n["actor"]
	return null


func _guard_tick() -> void:
	if q("GUARD") != 0 or _busy():
		return
	var a := _guard_actor()
	if a == null:
		return
	var r := 1.5 if host.combat.crouch else WAKE_R
	if a.loco.logical.distance_to(host.player.loco.logical) / 32.0 <= r:
		_sq("GUARD", 1)
		host.play_scene("SQS11_GUARD")
		_log("경비 파수 깨어남")


func _guard_fight() -> void:
	_sq("GUARD", 9)
	var a := _guard_actor()
	var at: Vector2 = a.loco.logical if a != null else Vector2(GUARD_CELL * 32) + Vector2(16, 16)
	host.refresh_npcs()
	_guard_spawn(at)
	host.hint("진공관이 붉게 켜진다. \"저항 감지. 자위 모드 전환.\"", 4.0)


## 부수기로 깨운 파수: 쓰러질 때까지는 들어설 때마다 다시 선다(불러오기 · 맵 이탈 — P10)
func _guard_spawn(at: Vector2) -> void:
	_guard_e = host.combat.spawn("CR-306", at, host.map, st, {"lv": clampi(int(host.level()), 3, 12), "sheet": "rb_cr306_loco"})
	_guard_e.brain.gauge = 100.0
	_guard_e.set_meta("s11g", 1)


func _on_down(e: Enemy) -> void:
	if e.cmb.dead and e.has_meta("s11g"):
		st.boxes["s11guard"] = {"open": true}
		_log("경비 파수 파괴")


# ---------------------------------------------------------------- 인도 · 행방(P1)
func _deed(tag: String, pub: int, fx: Dictionary, what: String) -> void:
	st.deeds.record(st, "side", "R02", pub, fx, Clock.abs_min(host.date_text), {"tag": tag, "place": "R02", "what": what, "seen_by": [], "about": []})


func _list_to(code: int, why: String) -> void:
	if v("SQH_LIST11") >= 0:
		return
	st.vars.set_v("SQH_LIST11", code)
	match code:
		4:                                                                 # a 인지영과 국회 앞(또는 주인공이 혼자 — SOL_L 2)
			st.vars.set_v("SQE_LIST11", 1)
		14:
			st.vars.set_v("SQE_LIST11", 1)
			st.call_fn("take", [LIST_ID, 1])
			st.call_fn("karma", [50])
			st.vars.set_v("NS_COOP", v("NS_COOP") + 1)
			st.call_fn("aff", ["JC", 3])
			st.call_fn("aff", ["BJ", -3])                                    # 공보방송 반박 방송
			_sq("SOL_L", 3)
			_sq("CASTL", 1)
			_sq("CASTL_DAY", day() + 1)
			_deed("SQS11_L14", 3, {"BJ": 0}, "남산 방송이 여의도 해산 사건 사망자 열한 명의 이름을 읽었다")
			host.hint("내일 아침 송미래가 열한 이름을 읽는다.", 4.0)
		1:
			st.call_fn("take", [LIST_ID, 1])
			st.call_fn("karma", [-50])
			st.call_fn("aff", ["BJ", 5])
			_sq("SOL_L", 4)
			_sq("PASS", 1)
			_deed("SQS11_L1", 1, {"BJ": 0}, "여의도 초소가 해산 사건 사망자 명단을 '정부 재산'으로 회수했다")
		0:
			st.vars.set_v("SQE_LIST11", 1)
			_sq("SOL_L", 5)
	_log("명단 → %d (%s)" % [code, why])
	_close()


func _doc_to(code: int, why: String) -> void:
	if v("SQH_RECESS") >= 0:
		return
	st.vars.set_v("SQH_RECESS", code)
	match code:
		14:
			st.call_fn("take", [DOC_ID, 1])
			st.vars.set_v("NS_COOP", v("NS_COOP") + 1)
			st.call_fn("aff", ["BJ", -3])
			_sq("SOL_D", 1)
			_deed("SQS11_D14", 3, {"BJ": 0}, "남산 방송: '국회는 스스로 멈췄다. 누구에게도 넘기지 않았다.'")
		1:
			st.call_fn("take", [DOC_ID, 1])
			st.call_fn("aff", ["BJ", 8])
			st.call_fn("aff", ["YH", -4])                                   # 연동(BJ +8 → YH −4 · JG −4 · JC −3)
			st.call_fn("aff", ["JG", -4])
			st.call_fn("aff", ["JC", -3])
			st.vars.set_v("PD_R02_KH", 1)                                    # 거점 '국회 폐허' → BJ(돔 잔해에 휘장 깃발)
			_sq("SOL_D", 2)
			_deed("SQS11_D1", 3, {"BJ": 0}, "공보방송: '국회 수복 — 권한 인계 문서 확보.' 국회 돔 잔해에 휘장 깃발이 올랐다")
			_steps_state()
		0:
			st.vars.set_v("SQE_RECESS", 1)
			_sq("SOL_D", 3)
		97:
			st.call_fn("take", [DOC_ID, 1])
			st.call_fn("karma", [25])
			_sq("SOL_D", 4)
			if _zone() == "KH-03":
				host.map.set_prop_state(BOX, "")
				host.map.set_prop_state(GAP_SHELF, "")
	_log("원본 → %d (%s)" % [code, why])
	_close()


func _close() -> void:
	if q("DONE") == 1 or v("SQH_LIST11") < 0 or v("SQH_RECESS") < 0:
		return
	_sq("DONE", 1)
	if q("START") == 0:
		_sq("START", day())
	st.vars.set_v("SQR_S11", 1)
	_up(100)
	st.call_fn("xp", [XP])
	_deed("SQS11_DONE", 1, {"JH": 0}, "여의도의 두 기록이 자리를 찾았다")
	_log("닫힘")


# ---------------------------------------------------------------- 맵 · 하루 판정
func _on_map(_id: String) -> void:
	if host.map == null:
		return
	squad = {}
	_guard_e = null
	if q("ESCORT") == 1 and _zone() in ["H-03", "CG-05"]:             # 호위 중 생포: 인지영은 우리까지 따라오지 않는다 — 벤치로 돌아가 다시 부탁할 수 있다(P3)
		_sq("ESCORT", 0)
		_drop_mate()
		host.hint("끌려가는 길에 인지영을 놓쳤다. 지하시장 쪽으로 혼자 걸어가는 뒷모습을 본 것 같다.", 6.0)
	match _zone():
		"K-29":
			if not st.boxes.has("s11key"):                                 # 서장 열쇠는 무기고 보관함에(원문 '무기고 사물함의 서장 열쇠')
				var wb: Variant = host.map.boxes.get(KEY_BOX)
				if wb != null:
					st.boxes["s11key"] = {"open": true}
					(host.box_contents(wb)["items"] as Dictionary)[KEY_ID] = 1
			host.map.set_prop_state(PRINTER, "print" if q("PRINT") > 0 else "")
			if q("GUARD") == 9 and not st.boxes.has("s11guard"):
				_guard_spawn(Vector2(GUARD_CELL * 32) + Vector2(16, 16))
		"KH-01":
			host.map.set_prop_state(Vector2i(17, 5), "broken")
		"KH-02":
			host.map.set_prop_state(Vector2i(2, 4), "broken")
		"KH-03":
			if q("STACK") == 1:
				host.ev.handlers["unlock"].call([STACK_DOOR.x, STACK_DOOR.y], func() -> void: pass)
			var gone := q("TOOK") == 1 and v("SQH_RECESS") != 97
			host.map.set_prop_state(BOX, "open" if gone else "")
			host.map.set_prop_state(GAP_SHELF, "gap" if gone else "")
	_steps_state()


func _on_day(d: int) -> void:
	if q("CASTL") == 1 and d >= q("CASTL_DAY"):
		_sq("CASTL", 2)                                                    # 다음 06시 송미래가 읽는다(뉴스 대기열 N-S11-L)
	if q("TOOK") == 1 and v("SQH_RECESS") < 0:
		var held := d - q("HELD_DAY")
		if held >= WARN_DAYS and q("WARN") == 0:
			_sq("WARN", 1)
			host.hint("여의도에서 '국회 문서 반출자를 찾는다'는 말이 돈다.", 6.0)
		if held >= KEEP_DAYS:                                              # 7일 소지 → '보관'(원문 단계 100)
			host.hint("원본을 든 지 이레. 이 종이는 이제 당신이 보관한다.", 6.0)
			if v("SQH_LIST11") < 0 and _has(LIST_ID):
				_list_to(0, "7일 보관")
			_doc_to(0, "7일 보관")


# ---------------------------------------------------------------- 원고 명령(@cmd s11 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"talk":                                                            # 다른 장면에서 넘겨받기: 이 창이 닫힌 뒤 S11 장면
			var sid := str(a[1])
			host.box.finished.connect(func() -> void: host.play_scene.call_deferred(sid), CONNECT_ONE_SHOT)
		"start":
			_start(str(a[1]) if a.size() > 1 else "")
		"leaflet":
			_sq("LEAF", 1)
			_start("유인물")
		"told":
			_sq("TOLD", 1)
			_catch_up()
		"knows":
			_sq("KNOWS", 1)
			_catch_up()
		"stack":
			_sq("STACK", 1)
			if _zone() == "KH-03":
				host.ev.handlers["unlock"].call([STACK_DOOR.x, STACK_DOOR.y], func() -> void: pass)
			host.hint("제7 서고 — 번호 1021.", 4.0)
			_catch_up()
		"take":
			_sq("TOOK", 1)
			_sq("HELD_DAY", day())
			st.call_fn("give", [DOC_ID, 1])
			if _zone() == "KH-03":
				host.map.set_prop_state(BOX, "open")
				host.map.set_prop_state(GAP_SHELF, "gap")
			_start("원본")
		"return":
			_doc_to(97, "기록관")
		"keep":
			_doc_to(0, "의사록에게 말함")
		"print":
			_sq("PRINT", q("PRINT") + 1)
			st.call_fn("give", [LIST_ID, 1])
			if _zone() == "K-29":
				host.map.set_prop_state(PRINTER, "print")
			_catch_up()
		"auth":
			st.call_fn("wanted", [3, "auth"])                                 # 관리자 인증 1회 수배도 +3(SD-04a §2.4)
			_sq("GUARD", 2)
			host.refresh_npcs()
		"query":
			_sq("GUARD", 2)
			host.refresh_npcs()
		"march":
			st.vars.set_v("SQK_MARCH", 1)
		"fight":
			_guard_fight()
		"pipe":
			var into := str(a[1]) == "in"
			if into and q("GUARD") <= 1:
				_sq("GUARD", 3)
			host.busy = true
			host.ev.run("fade_out", ["black", "2"], func() -> void:
				host.ev.handlers["pc"].call(["pipe_office" if into else "pipe_cell"], func() -> void: pass)
				host.hint("배관 속을 기었다. 녹물 냄새." if into else "유치장으로 기어 나왔다.", 3.0)
				host.ev.run("fade_in", ["black", "2"], func() -> void: host.busy = false))
		"escort":
			if not st.is_dead(INJI) and v("SQH_LIST11") < 0:
				_join()
		"stay":
			host.combat.mates.set_mode(INJI, "wait")
		"wait20":
			var h := _hour()
			if h >= 6 and h < 20:
				host.advance_minutes((20 - h) * 60 - _mm())
				host.hint("밤 여덟 시까지 벤치에서 기다렸다.", 4.0)
		"leaf":
			if host.map is WorldMap:
				host.map.set_prop_state(_step_cell(int(a[1])), "leaf")
		"read":
			_sq("READ", 1)
			_sq("ESCORT", 3)
			_sq("SOL_L", 1)
			st.call_fn("karma", [100])
			st.call_fn("aff", ["JH", 6])
			if q("REWARD") == 0:
				_sq("REWARD", 1)
				st.call_fn("give", [BAND_ID, 1])                                # 종전 행진 머리띠(지하시장 구울 화술 +5)
			_deed("SQS11_L4", 2, {"JH": 0}, "인지영이 국회 계단에서 열한 이름을 읽었다 — '이제 토요일이 끝났네'")
			_list_to(4, "인지영 낭독")
			_drop_mate()
			host.refresh_npcs()
		"selfread":                                                        # 인지영이 죽은 뒤 주인공이 혼자(재미 검수 7): +50 · 머리띠 없음
			_sq("READ", 2)
			_sq("SOL_L", 2)
			st.call_fn("take", [LIST_ID, 1])
			st.call_fn("karma", [50])
			_deed("SQS11_L4S", 2, {"JH": 0}, "누군가 국회 계단에 해산 사건 명단을 놓고 이름을 읽었다")
			_list_to(4, "혼자 낭독")
			_steps_state()
		"woo":
			match str(a[1]):
				"list":
					_sq("WOOL", 1)
					_list_to(14, "우도하")
				"copy":
					_sq("WOOL", 1)
					st.call_fn("take", [LIST_ID, 1])
				"doc":
					_doc_to(14, "우도하")
		"sun":
			match str(a[1]):
				"list":
					_sq("SUNL", 1)
					_list_to(1, "선우진")
				"copy":
					_sq("SUNL", 1)
					st.call_fn("take", [LIST_ID, 1])
				"doc":
					_doc_to(1, "선우진")
		"patrol":
			_patrol(str(a[1]))
	done.call()
