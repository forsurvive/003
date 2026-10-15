## 인카운터 진행(단계 1-3, SD-05 §6.9 실시간 등장 연출): Encounters(판정 규칙)가 고른 RE를 월드에 세우고 끝까지 돌본다.
## 스폰: 주인공에게서 12~20타일, 화면 밖(가로 11 · 세로 7타일 넘게), 같은 높이 단의 걷는 칸, 시야가 끊긴 칸 먼저(허공에서 생기지 않는다),
##   길이 닿는 칸. 활성 상한(SD-14 §11.7): 위협 1~3 적 12 · 4~5 16, 추적대 5 — 넘으면 다음 판정으로 미룬다.
## 적대(RE-004 등): 곧바로 전투 개체로 선다(인지는 적 AI가 한다).
## 추적대(RE-087): 첫 분대는 비적대로 걸어와 4타일 안에서 말을 건다(원고 RE-087_TALK) → re fight·run = 전투 개체로 바꿔 세움,
##   re leave = 돌아서 떠난다. 다가오는 동안 인지력 판정(인지력 × 10%)에 성공하면 방위 링이 붉게 점멸하고 `추격자가 다가옵니다`.
## 끝: 적 전멸 · 놓침(살아 있는 적이 모두 25타일 넘게 떨어지고 시야가 끊김) · 떠남 · 생포 → Encounters.finished()(안전 간격 2회).
## 추적대가 다가오거나 싸우는 동안은 '추격 중'(빠른 이동 F8 · 대기 불가).
class_name EncounterLive
extends Node

signal started(re: String)
signal ended(re: String, how: String)

const SPAWN_MIN := 12
const SPAWN_MAX := 20
const LOST_T := 25.0
const TALK_T := 4.0
const LEAVE_T := 22.0
const CAP := {1: 12, 2: 12, 3: 12, 4: 16, 5: 16}
const CAP_TRACKER := 5
const SHEETS := {"CR-436": "en_cr436_loco", "CR-437": "en_cr437_loco", "CR-002": "cr_cr002_base_loco"}

var host                                          ## InteriorHost
var rules: Encounters
var cur := {}                                     ## 지금 RE: {"re", "kind", "state": approach|talk|fight|leave, "actors": [Actor], "foes": [Enemy], "t"}
var flash_t := 0.0                                ## 방위 링 붉은 점멸 남은 초
var _path_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup(h, seed_v := 0) -> EncounterLive:
	host = h
	rules = Encounters.new(h.st, seed_v)
	_rng.seed = seed_v if seed_v != 0 else Time.get_ticks_usec() + 77
	return self


## 추격 중(SD-12 §5.6 F8 · §7.6 대기 불가)
func chasing() -> bool:
	return not cur.is_empty() and cur["kind"] == "tracker" and cur["state"] in ["approach", "talk", "fight"]


func _now() -> int:
	return Clock.abs_min(host.date_text)


func _here() -> Vector2i:
	return host.map.tile_of(host.player.loco.logical)


func _ok() -> bool:
	return host.map is WorldMap and host.clock_running() and cur.is_empty()


# ---------------------------------------------------------------- 판정 기회(진행기·호스트가 부른다)
func tick(dt: float) -> void:
	flash_t = maxf(0.0, flash_t - dt)
	if not cur.is_empty():
		_tick_cur(dt)
		return
	if not _ok():
		return
	var t := _here()
	var req := rules.on_move(t, _now(), Clock.is_night(host.date_text), host.map.region_at(t))
	if not req.is_empty():
		start(req)


func on_exit_interior() -> void:
	if not _ok():
		return
	var t := _here()
	var req := rules.on_exit_interior(t, Clock.is_night(host.date_text), host.map.region_at(t))
	if not req.is_empty():
		start(req)


func on_arrive() -> void:
	if not _ok():
		return
	var t := _here()
	var req := rules.on_arrive(t, Clock.is_night(host.date_text), host.map.region_at(t))
	if not req.is_empty():
		start(req)


## 맵이 바뀌었다(문 전환): 전투 개체는 전투가 치웠다. 다가오던 추적대는 사라진다(실내로 들어가면 놓침)
func on_map_changed() -> void:
	if cur.is_empty():
		return
	for a in cur.get("actors", []):
		if is_instance_valid(a):
			a.queue_free()
	_end("lost")


# ---------------------------------------------------------------- 세우기
func start(req: Dictionary) -> bool:
	var re := str(req["re"])
	var d: Dictionary = Encounters.RES[re]
	var ids := rules.units(re, host.level())
	var alive: int = host.combat.alive_enemies()
	if d["kind"] == "tracker" and ids.size() > CAP_TRACKER:
		ids = ids.slice(0, CAP_TRACKER)
	if alive + ids.size() > int(CAP.get(Encounters.threat_at(_here()), 12)):
		return false                                                 # 활성 상한: 다음 판정으로 미룬다
	var spots := spawn_spots(ids.size())
	if spots.is_empty():
		return false
	cur = {"re": re, "kind": d["kind"], "state": "", "actors": [], "foes": [], "t": 0.0, "src": str(req.get("src", ""))}
	if d["kind"] == "tracker":
		cur["state"] = "approach"
		for i in ids.size():
			var a := Actor.new()
			a.setup(SHEETS.get(ids[i], "en_cr437_loco"), spots[i], host.map)
			a.mode = "walk"
			a.set_meta("cr", ids[i])
			host.map.add_actor(a)
			a._show()
			cur["actors"].append(a)
		if _rng.randf() < host.st.stat("PE") / 10.0:                   # 인지력 판정(정합: 인지력 × 10%)
			flash_t = 2.4
			host.hint("추격자가 다가옵니다", 3.0)
	else:
		cur["state"] = "fight"
		for i in ids.size():
			cur["foes"].append(host.combat.spawn(ids[i], spots[i], host.map, host.st, {"lv": host.level()}))
	started.emit(re)
	return true


## 스폰 자리: 주인공 둘레 12~20타일, 화면 밖, 같은 높이 단, 걷는 칸, 시야가 끊긴 칸 먼저. 무리는 첫 자리 옆 칸들
func spawn_spots(n: int) -> Array:
	var me := _here()
	var lv: int = host.map.level_at(me)
	var me_px: Vector2 = host.player.loco.logical
	var best := Vector2i(-1, -1)
	var best_score := -1
	var dirs := 24
	var off := _rng.randi() % dirs
	for i in dirs:
		var ang := TAU * float((i + off) % dirs) / dirs
		for r in [SPAWN_MIN + 2, SPAWN_MIN, SPAWN_MAX - 4, SPAWN_MAX]:
			var t := me + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r))
			if absi(t.x - me.x) <= 11 and absi(t.y - me.y) <= 7:
				continue
			if host.map.is_solid(t) or host.map.level_at(t) != lv:
				continue
			var hidden: bool = not host.map.line_of_sight(me_px, Vector2(t) * 32.0 + Vector2(16, 16))
			var score := (2 if hidden else 1)
			if score > best_score and _reachable(me_px, t):
				best_score = score
				best = t
				if hidden:
					break
		if best_score == 2:
			break
	if best_score < 0:
		return []
	var out: Array = [Vector2(best) * 32.0 + Vector2(16, 16)]
	var ring := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1),
		Vector2i(-1, -1), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	for o in ring:
		if out.size() >= n:
			break
		var t: Vector2i = best + o
		if not host.map.is_solid(t) and host.map.level_at(t) == lv:
			out.append(Vector2(t) * 32.0 + Vector2(16, 16))
	return out if out.size() >= n else []


## 길이 닿나(칸 A*, 노드 700 — 20타일 안팎이면 충분하다)
func _reachable(from_px: Vector2, t: Vector2i) -> bool:
	return not host.map.path(Vector2(t) * 32.0 + Vector2(16, 16), from_px, 700).is_empty()


# ---------------------------------------------------------------- 돌보기
func _tick_cur(dt: float) -> void:
	cur["t"] = float(cur["t"]) + dt
	match str(cur["state"]):
		"approach":
			_approach(dt)
		"leave":
			_leave(dt)
		"fight":
			_fight_check()


## 추적대가 걸어온다(칸 길찾기, 1초마다 다시). 4타일 안이면 멈춰 서서 말을 건다
func _approach(dt: float) -> void:
	var me: Vector2 = host.player.loco.logical
	var lead: Actor = cur["actors"][0] if not cur["actors"].is_empty() else null
	if lead == null or not is_instance_valid(lead):
		_end("lost")
		return
	if host.box.active or host.busy or host.ev.busy() or host.pipboy != null:
		for a in cur["actors"]:
			a.move(Vector2.ZERO, dt)
		return
	if lead.loco.logical.distance_to(me) <= TALK_T * 32.0:
		for a in cur["actors"]:
			a.move(Vector2.ZERO, dt)
			a.loco.facing = Locomotion.snap8(me - a.loco.logical)
			a._show()
		cur["state"] = "talk"
		host.play_scene(str(Encounters.RES[cur["re"]]["talk"]))
		return
	if lead.loco.logical.distance_to(me) > (SPAWN_MAX + 14) * 32.0:   # 주인공이 멀리 달아났다(다가오는 중의 놓침)
		_despawn_actors()
		_end("lost")
		return
	_path_t -= dt
	for i in cur["actors"].size():
		var a: Actor = cur["actors"][i]
		var goal := me + Vector2(((i % 3) - 1) * 28.0, (i / 3) * 28.0)
		if (_path_t <= 0.0 and i == int(cur["t"] * 2.0) % cur["actors"].size()) or not a.has_meta("path"):   # 한 번에 한 명씩 다시 찾는다
			var np: PackedVector2Array = host.map.path(a.loco.logical, goal, 700)
			np.insert(0, a.loco.logical)
			a.set_meta("path", np)
			a.set_meta("pi", 0)
		_follow(a, dt)
	if _path_t <= 0.0:
		_path_t = 0.5


func _follow(a: Actor, dt: float) -> void:
	var p: PackedVector2Array = a.get_meta("path", PackedVector2Array())
	var i := int(a.get_meta("pi", 0))
	while i < p.size() and a.loco.logical.distance_to(p[i]) < 10.0:
		i += 1
	a.set_meta("pi", i)
	if i >= p.size():
		a.move(Vector2.ZERO, dt)
		return
	a.move(a.steer((p[i] - a.loco.logical).normalized()), dt)         # 막히면 돌아서 걷는다(벽 비비기 없음, Sweep.steer)


## 원고 명령 re fight · run · leave
func cmd(what: String) -> void:
	if cur.is_empty():
		return
	match what:
		"fight", "run":
			var cap := str(Encounters.RES[cur["re"]].get("capture", ""))
			for a in cur["actors"]:
				if not is_instance_valid(a):
					continue
				var e: Enemy = host.combat.spawn(str(a.get_meta("cr")), a.loco.logical, host.map, host.st, {"lv": host.level()})
				e.brain.state = AIBrain.S.COMBAT
				e.brain.gauge = 100.0
				if cap != "":
					e.set_meta("capture", cap)                         # 생포 분대: 주인공을 쓰러뜨리면 생포(SD-03a §6.7)
				cur["foes"].append(e)
				a.queue_free()
			cur["actors"] = []
			cur["state"] = "fight"
			Wanted.seen_wearing(host.st, host.worn())                    # 추적대가 본 옷으로 공고 인상착의를 고친다(SD-12 §9.7)
		"leave":
			cur["state"] = "leave"
			cur["t"] = 0.0
		"surrender":                                                     # 손을 내민다(MQ-105 '일부러 잡힌다', SD-03a §8.5): 싸움 없이 생포
			for a in cur["actors"]:
				if is_instance_valid(a):
					a.queue_free()
			cur["actors"] = []
			cur["state"] = "leave"
			cur["t"] = 99.0
			host.capture.call_deferred("SB")


func _leave(dt: float) -> void:
	var me: Vector2 = host.player.loco.logical
	var gone := true
	for a in cur["actors"]:
		if not is_instance_valid(a):
			continue
		var away: Vector2 = (a.loco.logical - me)
		if away.length() < LEAVE_T * 32.0 and float(cur["t"]) < 20.0:
			gone = false
			a.move(a.steer(away.normalized()), dt)
	if gone:
		_despawn_actors()
		_end("left")


func _fight_check() -> void:
	var foes: Array = cur["foes"].filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
	if foes.is_empty():
		_end("cleared")
		return
	var me: Vector2 = host.player.loco.logical
	for e in foes:
		if e.loco.logical.distance_to(me) <= LOST_T * 32.0 or host.map.line_of_sight(e.loco.logical, me):
			return
	for e in foes:                                                   # 놓침: 모두 25타일 밖 + 시야 끊김(SD-11 §2.5)
		e.cmb.team = "gone"
		e.queue_free()
	host.combat.enemies = host.combat.enemies.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion())
	_end("lost")


## 생포로 끝났다(호스트가 부른다)
func captured() -> void:
	if cur.is_empty():
		return
	for e in cur["foes"]:
		if is_instance_valid(e):
			e.queue_free()
	_end("captured")


func _despawn_actors() -> void:
	for a in cur.get("actors", []):
		if is_instance_valid(a):
			a.queue_free()
	cur["actors"] = []


func _end(how: String) -> void:
	var re := str(cur.get("re", ""))
	cur = {}
	rules.finished()
	ended.emit(re, how)
