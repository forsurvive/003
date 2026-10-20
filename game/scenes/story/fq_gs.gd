## 세력 퀘스트 FQ-GS-01 「정비 당번」 · FQ-GS-02 「천공기」 진행기(단계 1-12b, SD-04d §9.3 · §9.4). 원고: script/act1/FQ-GS-01.txt · FQ-GS-02.txt · JUNGGYE.txt.
## 계획: docs/seoul-fallout/_plans/1-12b_FQ-GS-01-02_plan.md §4 확정안 · §5 구현.
## GS-01: 잠든 로봇 여섯(마당 1 · 2 · 4번 · 정비고 3번 · 살림-2 둘)마다 하는 일이 다르다. 3번만 전지가 살아 있어 전원을 안 내리고 기름부터 치면 깨어난다(확률 아님 — 순서).
##   퓨즈는 정비고에 사람이 있나로 갈린다(오상구가 차양에 있는 낮 — 대기음 11 · 16시 빼고 — 이면 들킨다). 뺀 퓨즈 = GS_ROBOT −1(MQ-505 개통파가 깨울 로봇).
## GS-02: 학원 K-24 채점기 한 대의 상태 GS02_GRADER(P1, UQ-62가 읽는다) — 바늘 분리 · 진공관을 갈아 먼저 돌림 · 머리째 뜯음 · 원장 금고 예비 부품. 원장실 옆문 · 원장 대행.
## 실패(200): GS-01 = 각성회 적대(AFF_GS ≤ −60) · GS-02 = 류정 사망(SD-06 §10.11 영구 적대) 또는 적대. 끝난 퀘스트는 되돌리지 않는다(P10).
class_name FqGs
extends Node

signal want_save(why: String)

const Q1 := "FQ-GS-01"
const Q2 := "FQ-GS-02"
const BELL_HOURS := [11, 16]              ## 오상구가 마당 대기음에 나가 정비고가 비는 시(낮 당번 7~19시 가운데)
const DOOR := Vector2i(21, 12)            ## K-24 원장실 옆문
const SAFE := Vector2i(30, 11)            ## K-24 원장 금고
const GRADER := Vector2i(29, 3)
const WATCH_PX := 128.0                   ## 원장 대행이 옆문을 보는 거리(4칸)
const ROBOT_CELLS := {1: Vector2i(5, 16), 2: Vector2i(9, 17), 3: Vector2i(22, 5), 4: Vector2i(19, 17), 5: Vector2i(24, 5), 6: Vector2i(25, 5)}

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _bot: Enemy = null                    ## 깨어나 맞선 3번(교전 중)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["gs01"] = _cmd1
	host.ev.handlers["gs02"] = _cmd2
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.interact_pre.append(_pre_interact)


func v1(k: String) -> int:
	return int(st.vars.get_v("FQ_GS01_" + k))


func v2(k: String) -> int:
	return int(st.vars.get_v("FQ_GS02_" + k))


func _s1(k: String, n: int) -> void:
	st.vars.set_v("FQ_GS01_" + k, n)


func _s2(k: String, n: int) -> void:
	st.vars.set_v("FQ_GS02_" + k, n)


func gv(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[각성회 정비 · 천공기] " + s)


func day() -> int:
	return maxi(1, gv("GAME_DAY"))


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _up(q: String, n: int) -> void:
	var s := st.quests.stage(q)
	if s < n and s < 100:
		st.quests.set_stage(q, n)
		_log("%s 단계 %d" % [q, n])


## 손 맵 칸 → 지금 맵 칸(X-GS는 월드에 찍힌 손 맵)
func _cell(map_id: String, c: Vector2i) -> Vector2i:
	if host.map is WorldMap:
		return (host.map as WorldMap).to_world(map_id, c.x, c.y)
	return c


func _has(id: String) -> bool:
	return int(st.items.get(id, 0)) > 0


# ---------------------------------------------------------------- 단계 따라 올리기(SD-20 P2 '이미 함')
func start1() -> void:
	if v1("ROSTER") == 0:
		return
	_up(Q1, 10)
	for i in range(1, 7):
		if v1("R%d" % i) > 0:
			_up(Q1, 20)
	if v1("SEEN") == 1:
		_up(Q1, 30)


func start2() -> void:
	if v2("OFFER") == 0:
		return
	_up(Q2, 10)
	_up(Q2, 20)                                                          # 류정이 학원가 채점실을 같이 말한다
	if v2("SEEN") == 1 or gv("GS02_GRADER") > 0:
		_up(Q2, 30)
	if _has("M-420") or _has("M-421"):
		_up(Q2, 40)


# ---------------------------------------------------------------- 시간
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	tick()


func tick() -> void:
	var s1 := st.quests.stage(Q1)
	var s2 := st.quests.stage(Q2)
	if s1 > 0 and s1 < 100 and gv("AFF_GS") <= -60:
		st.quests.set_stage(Q1, 200)                                     # 각성회 적대: 오상구가 정비고 문을 닫는다
		_log("GS-01 실패(적대)")
	if s2 > 0 and s2 < 100 and (st.known_dead("C-014") or gv("AFF_GS") <= -60):
		st.quests.set_stage(Q2, 200)                                     # 류정 사망 = 영구 적대(SD-06 §10.11)
		_log("GS-02 실패")
	if _bot != null:
		if not is_instance_valid(_bot) or _bot.cmb.dead:
			_bot = null
			_wrecked()
		elif _zone() != "X-GS":
			_bot = null
			_calmed()


func _on_day(d: int) -> void:
	if v1("FUSE") == 1 and d > v1("FUSE_DAY") and v1("DIM") == 0:
		_s1("DIM", 1)                                                    # 다음 날 은솔이 '3번 대기등이 어제보다 어둡다'(범인 단정 없음, P7)


func _on_map(id: String) -> void:
	_bot = null if _bot != null and not is_instance_valid(_bot) else _bot
	if id == "X-GS":
		if v1("WAKE") == 1 and _bot == null:
			_s1("WAKE", 0)                                               # 떠난 사이 오상구가 정비 모드로 눕혀 두었다
		_props_xgs()
	elif id == "K-24":
		_props_k24()


func _props_xgs() -> void:
	var m := host.map
	for i in [1, 2]:
		m.set_prop_state(_cell("X-GS", ROBOT_CELLS[i]), "card" if v1("R%d" % i) >= 1 else "tag")
	var tagged := v1("TAG") >= 2
	var r4 := v1("R4") >= 1
	m.set_prop_state(_cell("X-GS", ROBOT_CELLS[4]), ("card" if r4 else "tag") if tagged else ("bare_card" if r4 else ""))
	var r3 := v1("R3")
	var dim := v1("FUSE") == 1 or r3 == 3
	var st3 := "three_dim" if dim else "three"
	if r3 in [1, 2]:
		st3 = "three_dimcard" if dim else "three_card"
	m.set_prop_state(_cell("X-GS", ROBOT_CELLS[3]), st3)
	m.set_prop_state(_cell("X-GS", ROBOT_CELLS[5]), ["", "bare", "done"][clampi(v1("R5"), 0, 2)])
	m.set_prop_state(_cell("X-GS", ROBOT_CELLS[6]), ["", "nest", "nest", "done"][clampi(v1("R6"), 0, 3)])


func _props_k24() -> void:
	host.map.set_prop_state(GRADER, ["", "run", "noneedle", "wreck"][clampi(gv("GS02_GRADER"), 0, 3)])


# ---------------------------------------------------------------- GS-01: 3번
## 정비고에 지금 누가 보나 — 오상구가 차양에 서 있는 낮(대기음 시 빼고). 밤 · 대기음 · 오상구 죽음 = 빈 정비고
func watched() -> bool:
	if st.is_dead("N-R01-503"):
		return false
	var h := gv("GAME_HOUR")
	return h >= 7 and h < 20 and not (h in BELL_HOURS)


func _oil(clumsy: bool) -> void:
	if v1("POWER") == 0 and v1("FUSE") != 1:
		_s1("WAKE", 1)                                                   # 순서: 전원을 안 내리고 기름부터 — 반쯤 깬 3번이 일어난다(확률 아님)
		_s1("WAKE_DAY", day())
		_log("3번이 깨어남")
		host.box.finished.connect(func() -> void: host.play_scene("FQGS01_WAKE"), CONNECT_ONE_SHOT)
		return
	_robot(3, clumsy)
	_s1("POWER", 0)
	host.hint("닦고 기름을 친 뒤 전원을 다시 올린다. 3번은 그대로 잔다.", 4.0)


func _auth() -> void:
	_s1("WAKE", 0)
	_s1("R3", 2)
	st.call_fn("aff", ["GS", 3])                                         # [관리자 인증]으로 멈춤: GS +3(원문) · 수배도 +3
	st.call_fn("wanted", [3, "auth"])
	start1()
	_up(Q1, 20)
	_props_xgs()
	_log("3번 관리자 인증")


## 맞선다: 3번 자리 앞 칸에 깨어난 파수-3이 선다(소품은 숨긴다). 신도들은 '시험 가동'이라 부르며 지켜본다 — 각성회 적대 아님
func _fight() -> void:
	var c := _cell("X-GS", ROBOT_CELLS[3])
	var p := _prop_at(c)
	if not p.is_empty() and is_instance_valid(p.get("node")):
		p["node"].visible = false
	var pos := Vector2((c.x + 1) * 32 + 16, (c.y + 1) * 32 + 16)
	_bot = host.combat.spawn("CR-305", pos, host.map, st, {"lv": 3, "dir": "S"})
	_bot.cmb.team = "enemysentry"
	_bot.foes = ["player", "ally"]
	_bot.wake()
	_bot.brain.gauge = 100.0
	_log("3번과 교전")


func _wrecked() -> void:
	_s1("WAKE", 0)
	_s1("R3", 3)
	st.call_fn("aff", ["GS", -6])                                        # 수호자 몸을 상하게 함(계획 §2-3)
	if v1("FUSE") != 1:
		st.vars.set_v("GS_ROBOT", gv("GS_ROBOT") - 1)                    # 깨울 로봇이 준다 — 퓨즈를 이미 뺐으면 같은 로봇이라 두 번 빼지 않는다
	start1()
	_up(Q1, 20)
	_show_three()
	host.hint("3번이 쓰러졌다. 엎드렸던 신도들이 천천히 일어난다. 아무도 말이 없다.", 5.0)
	_log("3번 부숨")


func _calmed() -> void:
	_s1("WAKE", 0)                                                       # 맞서다 떠났다 — 오상구가 정비 모드로 눕힌다(정비는 다시)
	_log("3번이 다시 누움")


func _show_three() -> void:
	var p := _prop_at(_cell("X-GS", ROBOT_CELLS[3]))
	if not p.is_empty() and is_instance_valid(p.get("node")):
		p["node"].visible = true
	if _zone() == "X-GS":
		_props_xgs()


func _prop_at(c: Vector2i) -> Dictionary:
	for p in host.map.props:
		if c.x >= p["x"] and c.x < p["x"] + p["w"] and c.y >= p["y"] and c.y < p["y"] + p["h"] and str(p["name"]) in ["gs_sentry_maint", "k24_side_door"]:
			return p
	return {}


func _fuse() -> void:
	if watched():
		_s1("FUSE", 2)                                                   # 보는 앞: 압수(GS −5) — 퓨즈는 오상구 주머니로, 3번은 그대로
		st.call_fn("aff", ["GS", -5])
		host.hint("오상구가 손목을 잡는다. \"…지금 뭐 하시는 거예요. 퓨즈는 제가 맡아 둘게요.\"", 6.0)
		_log("퓨즈 발각")
		return
	_s1("FUSE", 1)
	_s1("FUSE_DAY", day())
	st.call_fn("give", ["M-419", 1])
	if v1("R3") != 3:
		st.vars.set_v("GS_ROBOT", gv("GS_ROBOT") - 1)
	_props_xgs()
	host.hint("퓨즈가 손바닥에 미끄러져 나온다. 3번의 대기등이 아주 천천히 흐려진다.", 5.0)
	_log("퓨즈 뺌")


## 퓨즈 · 태그 · 바늘처럼 [물건:] 선택지로 건넨 물건은 대화기가 이미 거둬 갔다 — 여기서 다시 빼지 않는다
func _fuse_back() -> void:
	if v1("FUSE") == 1 and v1("R3") != 3:
		st.vars.set_v("GS_ROBOT", gv("GS_ROBOT") + 1)                    # 한가람이 그날 밤 다시 끼운다 — 벌 없이 대사로(계획 §4)
	_s1("FUSE", 3)
	_s1("DIM", maxi(v1("DIM"), 2))


# ---------------------------------------------------------------- GS-01: 로봇 손질
func _robot(i: int, clumsy: bool) -> void:
	var done_v: int = {5: 2, 6: 3}.get(i, 1)
	if i == 3 and v1("R3") == 2:
		return
	_s1("R%d" % i, done_v)
	if clumsy:
		_s1("CLUMSY", v1("CLUMSY") + 1)                                  # 서툴러도 3번 말고는 벌 없음(오상구 '위에서 아래로요')
	start1()
	_up(Q1, 20)
	_props_xgs()
	_log("로봇 %d 정비%s" % [i, " (서툼)" if clumsy else ""])


func _nest() -> void:
	_s1("R6", 1)
	_props_xgs()
	var c := _cell("X-GS", ROBOT_CELLS[6])
	for k in 2:
		var pos := Vector2((c.x + 2) * 32 + 16, (c.y + 1 + k) * 32 + 16)       # 집진통 옆으로 튀어나와 마당 쪽으로 — 선 자리와 겹치지 않게
		var e := host.combat.spawn("CR-095", pos, host.map, st, {"lv": 1, "dir": "S"})
		if e != null:
			e.foes = ["player", "ally"]
			e.wake()
			e.brain.gauge = 100.0
	_log("집진통 쥐 둘")


func _empty() -> void:
	_s1("R6", 2)
	_s1("PAPER", 1)                                                      # 2077 청소 확인서 — 학원 원장 금고 번호판(GS-02 (다)로 이어진다)
	if v1("TAG") == 0:
		_s1("TAG", 1)
		st.call_fn("give", ["M-418", 1])
	_props_xgs()


func _tag(sell: bool) -> void:
	_s1("TAG", 3 if sell else 2)
	if sell:
		st.call_fn("caps", [20])
	if _zone() == "X-GS":
		_props_xgs()


func _done1() -> void:
	if st.quests.stage(Q1) >= 100:
		return
	st.call_fn("aff", ["GS", 6])                                         # 원문 GS +6 · 연동 JG −2 · YH −1 · WP −1
	st.call_fn("aff", ["JG", -2])
	st.call_fn("aff", ["YH", -1])
	st.call_fn("aff", ["WP", -1])
	st.call_fn("xp", [250])
	st.call_fn("give", ["M-014", 2])                                     # 진공관 둘(정비고 예비품). 원문 '정비용 기름'은 소모품이 없어 뺀다(구현 정합)
	_s1("DONE", day())
	st.quests.set_stage(Q1, 100)
	_log("GS-01 끝(서툼 %d · 3번 %d · 퓨즈 %d · GS_ROBOT %d)" % [v1("CLUMSY"), v1("R3"), v1("FUSE"), gv("GS_ROBOT")])
	want_save.emit("done")


func _cmd1(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"roster":
			_s1("ROSTER", 1)
			start1()
		"cards":
			_s1("CARDS", 6)
		"robot":
			_robot(int(a[1]), a.size() > 2 and str(a[2]) == "clumsy")
		"seen":
			_s1("SEEN", 1)
			start1()
		"power":
			_s1("POWER", 1)
		"oil":
			_oil(a.size() > 1 and str(a[1]) == "clumsy")
		"auth":
			_auth()
		"fight":
			_fight()
		"flee":
			_s1("WAKE", 0)
		"fuse":
			_fuse()
		"fuseback":
			_fuse_back()
		"unwrap":
			_s1("R5", 1)
			_props_xgs()
		"nest":
			_nest()
		"empty":
			_empty()
		"tag":
			_tag(false)
		"tagsell":
			_tag(true)
		"done":
			_done1()
	done.call()


# ---------------------------------------------------------------- GS-02
func _door_open(why: String) -> void:
	if v2("DOOR") == 1:
		return
	_s2("DOOR", 1)
	if _zone() == "K-24":
		var p := _prop_at(DOOR)
		if not p.is_empty():
			if not p.has("cells"):
				p["cells"] = [DOOR]                                      # 맵이 세운 소품엔 발 칸 목록이 없다 — 문 한 칸
			host.map.remove_runtime_prop(p)                              # 그림 · 발 칸을 함께 걷는다(다시 들어오면 cond가 열린 문을 세운다)
		host.map.add_runtime_prop("k24_side_door_open", DOOR)
	_log("원장실 옆문 열림(%s)" % why)


func _proxy_pos() -> Variant:
	for n in host.npcs:
		if str(n["id"]) == "N-K24-P1" and not n.get("dead", false) and is_instance_valid(n["actor"]):
			return n["actor"].loco.logical
	return null


func proxy_watching() -> bool:
	if st.is_dead("N-K24-P1"):
		return false
	var p = _proxy_pos()
	if p == null:
		return false
	return (p as Vector2).distance_to(Vector2(DOOR * 32) + Vector2(16, 16)) <= WATCH_PX


## 조사 키 고리(K-24): 원장실 옆문 · 원장 금고
func _pre_interact() -> bool:
	if _zone() != "K-24" or host.box.active:
		return false
	var cells: Array = host._front_cells()
	if v2("DOOR") == 0 and cells.has(DOOR):
		var pt: Vector2i = host.map.tile_of(host.player.loco.logical)
		if pt.x > DOOR.x:
			host.say_text("안쪽 고리를 풀자 옆문이 열린다.")
			_door_open("안에서")
		elif proxy_watching():
			host.play_scene("K24_DOOR_STOP")
		elif not Lockpick.can_try(25, st.skill("LOCKPICK")):
			host.hint("원장실 옆문이 잠겼다. [자물쇠 따기 25 필요]", 3.0)
		else:
			host.open_lock(25, "door", func() -> void: _door_open("자물쇠"))
		return true
	var b: Dictionary = host._front_box(cells)
	if not b.is_empty() and Vector2i(int(b["x"]), int(b["y"])) == SAFE and host.box_locked(b) and not bool(host.box_contents(b).get("jammed", false)):
		host.play_scene("K24_SAFE")
		return true
	return false


func _safe_box() -> Dictionary:
	return host.map.boxes.get(SAFE, {})


func _done2() -> void:
	if st.quests.stage(Q2) >= 100:
		return
	st.call_fn("aff", ["GS", 8])                                         # 원문 GS +8 · 연동 JG −3 · YH −2 · WP −2 · 판도 PD-R01-5 GS +3(신도 증가)
	st.call_fn("aff", ["JG", -3])
	st.call_fn("aff", ["YH", -2])
	st.call_fn("aff", ["WP", -2])
	st.vars.set_v("PD_R01_GS", gv("PD_R01_GS") + 3)
	st.call_fn("xp", [250])
	st.call_fn("caps", [50])                                             # 헌금 50캡
	_s2("DONE", day())
	st.quests.set_stage(Q2, 100)
	if _zone() == "GS-01":
		host.refresh_npcs()
	_log("GS-02 끝(채점기 %d · 채점 %d)" % [gv("GS02_GRADER"), v2("SCORED")])
	want_save.emit("done")


func _cmd2(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"offer":
			_s2("OFFER", 1)
			start2()
		"early":
			_s2("EARLY", 1)
			_s2("OFFER", 1)
			start2()
		"seen":
			_s2("SEEN", 1)
			start2()
		"tube":
			st.vars.set_v("GS02_GRADER", 1)
			_s2("SCORED", 1)
			st.call_fn("give", ["M-423", 1])
			_props_k24()
		"needle":
			st.vars.set_v("GS02_GRADER", 2)
			st.call_fn("give", ["M-420", 1])
			start2()
			_props_k24()
		"rip":
			st.vars.set_v("GS02_GRADER", 3)
			st.call_fn("give", ["M-421", 1])
			start2()
			_props_k24()
		"head":
			st.call_fn("give", ["M-420", 1])
			_s2("HEAD", 1)
			start2()
		"m135":
			_s2("M135", 1)
			st.call_fn("give", ["M-135", 1])                             # 카드는 상하지 않고 돌아 나온다
		"bundle":
			_s2("BUNDLE", 1)
			st.call_fn("give", ["M-422", 1])
		"truth":
			var n := int(a[1])
			_s2("NAME", n)
			if _has("M-422"):
				st.call_fn("take", ["M-422", 1])                         # 류정이 벽 맨 윗줄에 건다
			if a.size() > 2 and str(a[2]) == "owner":
				st.call_fn("give", ["M-423", 1])                         # 류정: '살아 있는 분의 카드는 돌려 드릴게요'
			if n == 2 and v2("TRUTH") == 0:
				_s2("TRUTH", 1)
				st.vars.set_v("GS_TRUTH", mini(3, gv("GS_TRUTH") + 1))     # '학생 답안지' — GS 변화 없음(원문)
		"call":
			_door_open("화술")
		"sit":
			host.advance_minutes(60)
			_s2("SAT", 1)
			_door_open("자습 우수")
		"code":
			var b := _safe_box()
			if not b.is_empty():
				var c := host.box_contents(b)
				c["unlocked"] = true
				_s2("SAFE", 1)
				host.box.finished.connect(func() -> void: host.open_box(b), CONNECT_ONE_SHOT)
		"safepick":
			var b2 := _safe_box()
			if not b2.is_empty():
				host.box.finished.connect(func() -> void: host.open_box(b2), CONNECT_ONE_SHOT)
		"done":
			_done2()
	done.call()
