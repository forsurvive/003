## 세력 퀘스트 FQ-JH-01 「B구역 셔터」 진행기(단계 1-12c, SD-04d §8.3). 원고: script/act1/FQ-JH-01.txt · MQ-103.txt(노복희 · 게시판) · SQ-S08.txt(수리공).
## 계획: docs/seoul-fallout/_plans/1-12c_FQ-JH-01-03_plan.md §4 확정안.
## 쥐굴 셋(A 앞쪽 콘크리트 벽 밑 · B 안쪽 흙 균열 · C 안쪽 왕쥐 둥지)마다 상태 한 곳(P1): 0 열림 · 1 철판 · 2 독 미끼(한 시간 뒤 판정) · 3 조용(독) · 4 비움(물결을 다 잡음).
## 열린 굴은 물결(A 2 · B 2 · C 3 — C 첫 물결에 왕쥐)을 하나씩 내보낸다. 물결을 다 잡으면 그 굴의 남은 수가 준다. 맵을 떠나면 열린 굴의 쥐는 굴로 돌아가고(물결은 그대로),
## 닫힌 굴에서 나온 쥐는 그 구역(앞 · 안)을 떠도는 수로 남는다(반쯤 된 상태 없음, P10).
## 구동부: 0 기어 빠짐 · 1 고침 · 2 내림(안쪽을 가둔다) · 3 휨(셔터 칸에 선 몹을 깔았다 — 틈이 남아 못 가둔다). 안쪽 굴이 열린 채 내리면 쥐가 굴로 J-11에 샌다.
## 다 됨(40): 굴 셋이 닫히고 · 앞쪽에 쥐가 없고 · 안쪽은 비었거나 셔터로 가뒀고 · J-11로 샌 쥐가 없을 때. 노복희에게 알리면 100.
## 실패(200): 노복희 사망(영구 적대 SD-06 §10.10) · 셔터 폭파(영구 적대) · 지하시장 적대(AFF_JH ≤ −60).
class_name FqJh
extends Node

signal want_save(why: String)

const Q1 := "FQ-JH-01"
const HOLES := {"a": Vector2i(17, 4), "b": Vector2i(32, 8), "c": Vector2i(43, 11)}   ## 쥐굴 소품 자리(J-08)
const HOLE_OUT := {"a": Vector2i(17, 5), "b": Vector2i(32, 9), "c": Vector2i(43, 12)}  ## 쥐가 나오는 칸
const WAVES := {"a": 2, "b": 2, "c": 3}
const INNER := ["b", "c"]
const GAP_X := 23                                                       ## 방화 셔터 칸(23, 9~11) — 이 x 동쪽이 안쪽
const SHUT_CELLS := [Vector2i(23, 9), Vector2i(23, 10), Vector2i(23, 11)]
const BIG := Vector2(36 * 32 + 16, 1 * 32 + 16)                        ## J-03 B구역 큰 셔터 가운데
const COOL := 7.0                                                       ## 물결 사이 쉼(초)
const NEAR_PLATE := 3.0                                                 ## 철판을 대려면 이 칸 안에 쥐가 없어야 한다

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _live := {"a": [], "b": [], "c": [], "x": []}                      ## 굴별 지금 살아 있는 쥐(x = 떠도는 쥐)
var _out := {"a": false, "b": false, "c": false}                      ## 그 굴의 물결이 나와 있나
var _cool := {"a": 6.0, "b": 6.0, "c": 6.0}
var _leak: Array = []                                                   ## J-11로 샌 쥐


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["jh01"] = _cmd1
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.shots.exploded.connect(_on_blast)


func v1(k: String) -> int:
	return int(st.vars.get_v("FQ_JH01_" + k))


func _s1(k: String, n: int) -> void:
	st.vars.set_v("FQ_JH01_" + k, n)


func gv(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[B구역 셔터] " + s)


func day() -> int:
	return maxi(1, gv("GAME_DAY"))


func now() -> int:
	return Clock.abs_min(host.date_text)


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _up(n: int) -> void:
	var s := st.quests.stage(Q1)
	if s < n and s < 100:
		st.quests.set_stage(Q1, n)
		_log("단계 %d" % n)


func hole(k: String) -> int:
	return v1("H" + k.to_upper())


func closed(k: String) -> bool:
	return hole(k) in [1, 3, 4]


func left(k: String) -> int:
	return WAVES[k] - v1("W" + k.to_upper())


# ---------------------------------------------------------------- 시간
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	tick(_t)
	_t = 0.0


func tick(dt := 0.5) -> void:
	var s := st.quests.stage(Q1)
	if s > 0 and s < 100 and (st.known_dead("C-050") or gv("AFF_JH") <= -60):
		st.quests.set_stage(Q1, 200)                                      # 노복희 사망 · 적대: 상인회가 셔터를 다시 감는다
		_log("실패(적대 · 노복희)")
	for k in HOLES:
		if hole(k) == 2 and now() >= v1("T" + k.to_upper()) + 60:
			_poisoned(k)
	if _zone() == "J-08":
		_tick_b(dt)
	elif _zone() == "J-11" and not _leak.is_empty():
		_leak = _leak.filter(func(e) -> bool: return is_instance_valid(e) and not e.cmb.dead)
		if _leak.is_empty() and v1("LEAK") == 1:
			_s1("LEAK", 2)
			host.hint("버섯 선반 사이가 조용해졌다. 갉힌 선반에서 포자가 눈처럼 날린다.", 5.0)
			_check_clear()


func _tick_b(dt: float) -> void:
	for k in _live:
		_live[k] = (_live[k] as Array).filter(func(e) -> bool: return is_instance_valid(e) and not e.cmb.dead)
	for k in HOLES:
		if _out[k] and (_live[k] as Array).is_empty():
			_out[k] = false                                               # 물결 하나를 다 잡았다
			_s1("W" + k.to_upper(), v1("W" + k.to_upper()) + 1)
			_cool[k] = COOL
			if left(k) <= 0 and not closed(k):
				_s1("H" + k.to_upper(), 4)
				_hole_props()
				host.hint("굴 안이 조용하다. 더 나올 것이 없다.", 4.0)
				_closed_one()
		if not _out[k] and not closed(k) and left(k) > 0 and not _paused():
			_cool[k] -= dt                                                # 대화 · 창이 떠 있는 동안은 세지 않는다(시간이 멈춘 사이 쥐가 나오지 않게)
			if _cool[k] <= 0.0:
				_wave(k)
	var kf := 0
	var ki := 0
	for e in _live["x"] + _live["a"] + _live["b"] + _live["c"]:
		if not _origin_open(e):
			if _inner(e.loco.logical):
				ki += 1
			else:
				kf += 1
	_s1("SF", kf)                                                         # 떠도는 쥐(닫힌 굴에서 나와 남은 것) — 다시 들어오면 그만큼 다시 선다
	_s1("SI", ki)
	_check_clear()


func _paused() -> bool:
	return host.busy or host.ev.busy() or (host.box != null and host.box.active)


func _origin_open(e) -> bool:
	var k := str(e.get_meta("jh_hole", "x"))
	return k != "x" and not closed(k)


func _inner(p: Vector2) -> bool:
	return p.x >= GAP_X * 32 + 16


func _on_day(_d: int) -> void:
	if v1("DONE") > 0 and day() > v1("DONE") and v1("REOPEN") == 0:
		_reopen()


# ---------------------------------------------------------------- 맵
func _on_map(id: String) -> void:
	for k in _live:
		_live[k] = []
	for k in _out:
		_out[k] = false                                                   # 맵을 떠나면 열린 굴의 쥐는 굴로 돌아갔다(물결 그대로)
		_cool[k] = 6.0                                                    # 들어선 사람을 알아채기까지(첫 물결 전 틈 — 굴 앞에 먼저 닿을 수 있다)
	_leak = []
	if id == "J-08":
		_enter_b()
	elif id == "J-11" and v1("LEAK") == 1:
		_spawn_leak()
	elif id == "J-03":
		if v1("OPEN") >= 1:
			host.map.set_prop_state(Vector2i(35, 1), "open")                # 사슬을 풀고 들어 올린 셔터(폭파면 찢긴 채 — 그림은 'open'과 같은 틈)


func _enter_b() -> void:
	if v1("OPEN") == 0:
		_s1("OPEN", 2)                                                    # 들어왔다면 사슬은 이미 풀렸다
	if v1("DONE") == 0 and st.quests.stage(Q1) < 100:
		_up(10)
		_up(20)
		if closed("a") or closed("b") or closed("c"):
			_up(30)
	_hole_props()
	_motor_props()
	var cells_f := [Vector2i(6, 9), Vector2i(12, 11), Vector2i(16, 7), Vector2i(9, 6)]
	var cells_i := [Vector2i(28, 6), Vector2i(36, 10), Vector2i(40, 5), Vector2i(45, 8), Vector2i(30, 12)]
	for i in v1("SF"):
		_rat("CR-095", cells_f[i % cells_f.size()], "x")
	for i in v1("SI"):
		_rat("CR-095", cells_i[i % cells_i.size()], "x")
	if v1("KOUT") == 1 and v1("KING") == 0:
		_rat("CR-097", Vector2i(38, 8), "x")                             # 둥지를 막힌 왕쥐가 안쪽을 떠돈다


func _hole_props() -> void:
	if _zone() != "J-08":
		return
	for k in HOLES:
		host.map.set_prop_state(HOLES[k], ["", "plated", "bait", "dead", "dead"][clampi(hole(k), 0, 4)])


func _motor_props() -> void:
	if _zone() != "J-08":
		return
	host.map.set_prop_state(Vector2i(20, 8), ["", "fixed", "down", ""][clampi(v1("MOTOR"), 0, 3)])
	var down := _shutter_prop()
	if v1("MOTOR") == 2 and down.is_empty():
		host.map.add_runtime_prop("jh_fire_down", SHUT_CELLS[0])
	elif v1("MOTOR") != 2 and not down.is_empty():
		if not down.has("cells"):
			down["cells"] = SHUT_CELLS.duplicate()
		host.map.remove_runtime_prop(down)


func _shutter_prop() -> Dictionary:
	for p in host.map.props:
		if str(p["name"]) == "jh_fire_down":
			return p
	return {}


# ---------------------------------------------------------------- 쥐
func _wave(k: String) -> void:
	var ids: Array = ["CR-095", "CR-095"]
	if k == "b":
		ids = ["CR-096", "CR-095"]
	elif k == "c" and v1("KING") == 0 and v1("KOUT") == 0 and not _king_alive():
		ids = ["CR-097", "CR-095", "CR-095"]                              # 왕쥐는 둥지가 내보내는 다음 물결에(떠났다 돌아와도 다시 — 굴로 돌아갔으니)
	var c: Vector2i = HOLE_OUT[k]
	for i in ids.size():
		_rat(str(ids[i]), c + Vector2i(i - ids.size() / 2, 0), k)
	_out[k] = true
	_log("굴 %s 물결(%s)" % [k, ",".join(ids)])


func _rat(id: String, c: Vector2i, k: String) -> void:
	var pos := Vector2(c.x * 32 + 16, c.y * 32 + 16)
	var e := host.combat.spawn(id, pos, host.map, st, {"lv": 3 if id == "CR-097" else 1, "dir": "S"})
	if e == null:
		return
	e.set_meta("jh_hole", k)
	e.foes = ["player", "ally"]
	e.wake()
	e.brain.gauge = 100.0
	_live[k].append(e)
	if id == "CR-097":
		e.cmb.died.connect(_king_down, CONNECT_ONE_SHOT)


func _king_down() -> void:
	_s1("KING", 1)
	_s1("KOUT", 0)
	host.hint("왕쥐가 쓰러졌다. 둥지 쪽 찍찍 소리가 한꺼번에 낮아진다.", 5.0)
	_log("왕쥐 죽음")


func _rats_near(c: Vector2i, r: float) -> bool:
	var p := Vector2(c.x * 32 + 16, c.y * 32 + 16)
	for k in _live:
		for e in _live[k]:
			if is_instance_valid(e) and not e.cmb.dead and e.loco.logical.distance_to(p) <= r * 32.0:
				return true
	return false


func _king_alive() -> bool:
	for k in _live:
		for e in _live[k]:
			if is_instance_valid(e) and not e.cmb.dead and str(e.get_meta("enemy_id", "")) == "CR-097":
				return true
	return false


func _king_home() -> bool:
	for e in _live["c"] + _live["x"]:
		if is_instance_valid(e) and not e.cmb.dead and str(e.get_meta("enemy_id", "")) == "CR-097":
			return e.loco.logical.distance_to(Vector2(43 * 32 + 32, 12 * 32)) <= NEAR_PLATE * 32.0
	return v1("KING") == 0 and v1("KOUT") == 0                            # 아직 안 나왔으면 둥지 안이다


# ---------------------------------------------------------------- 굴 막기
func _closed_one() -> void:
	_up(30)
	want_save.emit("hole")


func _plate(k: String) -> void:
	if closed(k):
		return
	if int(st.items.get("M-010", 0)) <= 0:
		host.hint("철판으로 쓸 고철이 없다.", 4.0)
		return
	if k == "c" and v1("KING") == 0 and _king_home():
		host.hint("둥지 안에서 큰 것이 버틴다. 왕쥐가 둥지에 있는 한 철판은 밀려난다.", 5.0)
		return
	if _rats_near(HOLE_OUT[k], NEAR_PLATE):
		host.hint("쥐가 굴 앞을 지킨다. 먼저 치우거나 떼어 놓아야 철판을 댈 수 있다.", 4.0)
		return
	st.call_fn("take", ["M-010", 1])
	_s1("H" + k.to_upper(), 1)
	if k == "c" and v1("KING") == 0:
		_s1("KOUT", 1)                                                    # 둥지를 비운 사이 막았다 — 왕쥐는 밖에 남는다
	if _out[k]:
		for e in _live[k]:
			e.set_meta("jh_hole", "x")
		_live["x"].append_array(_live[k])
		_live[k] = []
		_out[k] = false
	advance(10)
	_hole_props()
	host.hint("철판을 굴 테두리에 대고 철사로 감는다. 안에서 긁는 소리가 철판을 두드린다.", 5.0)
	_log("굴 %s 철판" % k)
	_closed_one()


func _bait(k: String) -> void:
	if closed(k) or hole(k) == 2:
		return
	if int(st.items.get("M-026", 0)) <= 0:
		host.hint("미끼에 쓸 독이 없다.", 4.0)
		return
	st.call_fn("take", ["M-026", 1])
	_s1("H" + k.to_upper(), 2)
	_s1("T" + k.to_upper(), now())
	advance(5)
	_hole_props()
	host.hint("독낭을 짓이겨 깡통 뚜껑에 바른다. 한 시간쯤 지나면 안다.", 5.0)
	_log("굴 %s 독 미끼" % k)


func _poisoned(k: String) -> void:
	if k == "c" and v1("KING") == 0:
		_s1("HC", 0)                                                      # 왕쥐는 먹지 않는다 — 시궁쥐 한 물결만 줄고 미끼는 밀려났다
		_s1("WC", mini(v1("WC") + 1, WAVES["c"] - 1))
		if _zone() == "J-08":
			_hole_props()
			host.hint("둥지 앞 미끼 접시가 뒤집혀 있다. 작은 놈 몇이 쓰러졌지만 큰 놈은 먹지 않았다.", 6.0)
		_log("굴 c 독 — 왕쥐가 밀어냄")
		return
	_s1("H" + k.to_upper(), 3)
	for e in _live[k]:
		if is_instance_valid(e) and not e.cmb.dead:
			e.cmb.take({"hp": 999.0}, e.loco.logical)
	_out[k] = false
	if _zone() == "J-08":
		_hole_props()
		host.hint("굴 앞 미끼 접시가 비었다. 안에서 아무 소리도 나지 않는다.", 5.0)
	_log("굴 %s 독 — 조용" % k)
	_closed_one()


func advance(m: int) -> void:
	host.advance_minutes(m)


# ---------------------------------------------------------------- 구동부 · 방화 셔터
func _fix(by_minsu: bool) -> void:
	_s1("MOTOR", 1)
	if by_minsu:
		_s1("MINSU", 1)
	advance(20 if not by_minsu else 0)
	_motor_props()
	_log("구동부 고침%s" % (" (수리공)" if by_minsu else ""))


func _down() -> void:
	if v1("MOTOR") != 1:
		return
	var crushed := false
	for k in _live:
		for e in _live[k]:
			if not is_instance_valid(e) or e.cmb.dead:
				continue
			var t: Vector2i = host.map.tile_of(e.loco.logical)
			if t in SHUT_CELLS:
				crushed = true
				e.cmb.take({"hp": 80.0}, e.loco.logical)                 # 셔터 날에 깔렸다(재미 검수 '해 보고 싶은 짓')
	if crushed:
		_s1("MOTOR", 3)
		_s1("CRUSH", 1)
		_motor_props()
		host.hint("셔터가 무언가 위로 떨어진다. 비명 — 그리고 날이 휘어 반쯤에서 멈춘다. 기어가 다시 튀어나왔다.", 6.0)
		_log("셔터로 깔기 — 휨")
		return
	_s1("MOTOR", 2)
	_motor_props()
	var leaked := false
	for k in INNER:
		if not closed(k) and v1("LEAK") == 0:
			leaked = true
	if leaked:
		_s1("LEAK", 1)                                                    # 굴 막기 전에 내렸다 — 갇힌 쥐가 굴로 샌다(원문)
		host.hint("셔터가 내려앉는다. 안쪽에서 찍찍 소리가 한꺼번에 굴 쪽으로 몰려가더니 — 벽 속을 타고 멀어진다.", 6.0)
		_log("셔터 내림 — 쥐가 J-11로 샘")
	else:
		host.hint("셔터가 바닥까지 내려앉는다. 안쪽 긁는 소리가 셔터 너머에 갇힌다.", 5.0)
		_log("셔터 내림 — 가둠")
	_check_clear()


func _raise() -> void:
	if v1("MOTOR") == 2:
		_s1("MOTOR", 1)
		_motor_props()


func _spawn_leak() -> void:
	var cells := [Vector2i(4, 8), Vector2i(8, 9), Vector2i(4, 12), Vector2i(8, 12)]
	for c in cells:
		var e := host.combat.spawn("CR-095", Vector2(c.x * 32 + 16, c.y * 32 + 16), host.map, st, {"lv": 1, "dir": "E"})
		if e != null:
			e.foes = ["player", "ally"]
			e.wake()
			e.brain.gauge = 100.0
			_leak.append(e)
	host.hint("버섯 선반 사이로 쥐 떼가 쏟아져 있다. 설태호가 선반 위에 올라섰다.", 5.0)


# ---------------------------------------------------------------- 셔터 열기 · 폭파
func _on_blast(at: Vector2, outer_px: float, _team: String) -> void:
	if _zone() != "J-03" or v1("OPEN") == 3:
		return
	if at.distance_to(BIG) > outer_px + 48.0:
		return
	_s1("OPEN", 3)                                                        # 셔터는 우리가 내리는 것 — 폭파는 상가 전체가 듣는다(원문 영구 적대)
	host.map.set_prop_state(Vector2i(35, 1), "open")
	st.deeds.record(st, "범죄", "R02", 2, {"JH": 0}, now(), {"tag": "CRIME_PERM", "what": "B구역 셔터 폭파", "seen_by": ["JH"]})
	if st.quests.stage(Q1) < 100:
		st.quests.set_stage(Q1, 200)
	host.hint("셔터가 찢겨 나간다. 광장의 모든 얼굴이 이쪽을 본다. 아무도 말하지 않는다.", 6.0)
	_log("셔터 폭파 — 영구 적대")


func _pick() -> void:
	host.open_lock(25, "pad", _picked)


func _picked() -> void:
	_s1("OPEN", 2)
	for n in host.npcs:                                                   # 경호 구울이 보면 '상인회 사슬'(JH −3)
		if str(n["id"]) == "CR-457" and is_instance_valid(n["actor"]) \
				and n["actor"].loco.logical.distance_to(host.player.loco.logical) <= 8.0 * 32.0:
			st.call_fn("aff", ["JH", -3])
			host.hint("경호 구울이 고개를 돌린다. \"그건 상인회 사슬이야.\" 막지는 않는다.", 5.0)
			break
	_go_in()


func _go_in() -> void:
	host.enter("J-08", "from_J-03")


# ---------------------------------------------------------------- 끝
func _check_clear() -> void:
	if v1("CLEAR") == 1 or v1("DONE") > 0 or st.quests.stage(Q1) >= 100:
		return
	for k in HOLES:
		if not closed(k):
			return
	if v1("LEAK") == 1:
		return
	if _zone() == "J-08":
		var front := 0
		var inner := 0
		for k in _live:
			for e in _live[k]:
				if _inner(e.loco.logical):
					inner += 1
				else:
					front += 1
		if front > 0 or (inner > 0 and v1("MOTOR") != 2):
			return
	elif v1("SF") > 0 or (v1("SI") > 0 and v1("MOTOR") != 2) or (v1("KOUT") == 1 and v1("KING") == 0 and v1("MOTOR") != 2):
		return
	_s1("CLEAR", 1)
	_up(40)
	host.hint("B구역이 조용하다. 노복희에게 알린다.", 5.0)
	_log("B구역 조용(굴 %d%d%d · 셔터 %d · 샘 %d)" % [hole("a"), hole("b"), hole("c"), v1("MOTOR"), v1("LEAK")])
	want_save.emit("clear")


func _done() -> void:
	if st.quests.stage(Q1) >= 100:
		return
	var jh := 8 - (3 if v1("LEAK") >= 1 else 0)
	st.call_fn("aff", ["JH", jh])                                         # 원문 JH +8 · 연동 BJ −2 · SB −2 · SV −2(샌 쥐 −3, 계획 §4)
	st.call_fn("aff", ["BJ", -2])
	st.call_fn("aff", ["SB", -2])
	st.call_fn("aff", ["SV", -2])
	st.call_fn("xp", [250])
	st.call_fn("caps", [100])
	_s1("DONE", day())
	st.quests.set_stage(Q1, 100)
	_log("JH-01 끝(JH +%d)" % jh)
	want_save.emit("done")


## 다음 날 아침 B구역 가게가 다시 연다(P6): 수리공(B-06) · 사공 수선(J-03 B-04 앞면) — 살아 있는 사람만
func _reopen() -> void:
	_s1("REOPEN", 1)
	if not st.is_dead("N-R02-016"):
		_s1("SHOP_M", 1)
	if not st.is_dead("N-R02-012"):
		_s1("SHOP_S", 1)
	if _zone() in ["J-03", "J-08"]:
		host.refresh_npcs()
	_log("B구역 재개장(수리 %d · 사공 %d)" % [v1("SHOP_M"), v1("SHOP_S")])


func _nest() -> void:
	if v1("NEST") == 1:
		return
	_s1("NEST", 1)
	st.call_fn("caps", [12])
	st.vars.set_v("FQ_JH02_SEEN", maxi(gv("FQ_JH02_SEEN"), 1))           # 2077 영수증 '복희 의류 · 코트 1 · 180,000 · 외상 — 탁'(JH-02 훅, P2)


func _cmd1(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"board":
			if st.quests.stage(Q1) == 0:
				_up(10)
		"key":
			_s1("OPEN", maxi(v1("OPEN"), 1))
			_up(10)
			if _zone() == "J-03":
				host.map.set_prop_state(Vector2i(35, 1), "open")
		"enter":
			_go_in()
		"pick":
			_pick()
		"plate":
			_plate(str(a[1]))
		"bait":
			_bait(str(a[1]))
		"fix":
			_fix(false)
		"minsu":
			_fix(true)
		"warn":
			_s1("WARN", 1)
		"down":
			_down()
		"up":
			_raise()
		"nest":
			_nest()
		"done":
			_done()
	done.call()
