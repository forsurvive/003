## 왕개미 군체(SD-14 §3.5 CR-080~082 · SD-11 §4.8 더듬이 · 1-D 계획 §11.10, 단계 1-D5b).
## 실내 전투 모듈(InteriorCombat)이 맵마다 하나 세운다 — 냄새 길(scent)이 있거나 왕개미가 있는 맵.
##   냄새 길: 맵 지시어 scent(영구 칸) + 페로몬 바른 발자국(20초 · 처음 그린 뒤 최대 60초 — 개미가 밟으면 다시 진해진다).
##     일개미는 순찰 대신 냄새 칸을 따라 걷는다(갈림길에선 새 냄새 · 곧은 길 먼저 · 막다른 곳에선 돌아선다).
##     닫힌 고리에 들어선 일개미는 고리를 돈다(냄새가 다하면 흩어진다) · 길이 지워지면(물 · 소화기 · 불) 그 자리에서 헤맨다.
##   위장: 여왕 페로몬을 바르면(PC_SMELL — 남은 게임 분, 3시간) 일개미가 같은 무리로 본다 — 냄새 줄 위에서만(줄 밖은 의심).
##     마주 오는 일개미와 더듬이를 맞대는 순간이 판정(뛰거나 막 쐈으면 들킨다 · 아니면 그 개미가 돌아선다).
##     병정 · 여왕은 냄새로 속지 않고 물고 있는 것을 본다 — 왕개미 알(M-394)을 지니고 줄 위에 있으면 지나친다(개미의 일 흉내).
##     물에 들어서면 위장이 씻긴다(물로 줄을 지우면 내 위장도 — 지우기와 위장이 부딪친다).
##   병정: 큰턱(물기) + 3칸 안 개미산 분사 12(방어구 내구도 −, 4초마다). 여왕: 산성 침 40(8칸 · 정확, 3.5초마다) ·
##     깨어 있으면 알 무더기에서 20초마다 일개미 하나(최대 4) — 알 무더기 곁 냄새 줄을 끊으면 멎는다.
##   더듬이(부위 가중치 10): 부위 손상 → 8초 광란(가까운 개미를 문다) — 광란 개미가 쓰러뜨린 적의 XP는 주인공 몫.
class_name AntColony
extends Node2D

const ANTS := ["CR-080", "CR-081", "CR-082"]
const WORKER := "CR-080"
const SOLDIER := "CR-081"
const QUEEN := "CR-082"
const EGG := "M-394"                              ## 왕개미 알(병정 · 여왕이 지나친다)
const SMELL_MIN := 180                            ## 여왕 페로몬 한 번 = 3시간(게임 분)
const DRAW_S := 20.0                              ## 발자국 냄새 수명(초)
const DRAW_MAX_S := 60.0                          ## 처음 그린 뒤 이만큼 지나면 개미가 밟아도 사라진다(고리 60초)
const DRAW_CAP := 160
const LOST_S := 8.0                               ## 길을 잃고 헤매는 시간 → 가장 가까운 냄새 줄로
const SEEK_R := 12                                ## 헤매다 찾아가는 냄새 칸 반경(칸)
const CHAIN := 10                                 ## 한 번에 미리 고르는 냄새 칸 수(꺾이는 곳만 순찰 점으로)
const TOUCH_R := 1.15                             ## 더듬이를 맞대는 거리(칸)
const SPRAY_R := 3.0
const SPRAY_DMG := 12.0
const SPRAY_CD := 4.0
const SPIT_R := 8.0
const SPIT_DMG := 40.0
const SPIT_CD := 3.5
const LAY_S := 20.0
const LAY_MAX := 4
const FRENZY_S := 8.0
const CAST_S := 0.5                               ## 분사 · 침 · 알 낳기 동작(서서 한다)
const N8 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]

var map: InteriorMap
var cmb: InteriorCombat
var st: StoryState
var cells := {}                                   ## Vector2i -> {"perm": bool, "exp": 끝 시각, "born": 그린 시각}
var clock := 0.0
var active := false
var _ants := {}                                   ## 인스턴스 id -> {"prev": [칸…], "goal": 칸, "lost": 초, "off": 초, "touch": 초, "cd": 초, "cast": 초, "mad": 초}
var _lay_t := 0.0
var _pc_cell := Vector2i(-9999, -9999)
var _smell_acc := 0.0
var _hint_t := 0.0
var _t := 0.0
var _draw_t := 0.0
var spit_w: Dictionary = {}
signal note(text: String)                         ## 호스트 알림(위장 씻김 · 더듬이 · 줄 끊김)
signal corrode                                    ## 개미산이 주인공 옷을 녹였다(방어구 내구도 −)


func setup(m: InteriorMap, c: InteriorCombat, s: StoryState) -> void:
	map = m
	cmb = c
	st = s
	cells = {}
	_ants = {}
	clock = 0.0
	_lay_t = 0.0
	_pc_cell = Vector2i(-9999, -9999)
	for c2 in m.scent_cells():
		cells[c2] = {"perm": true, "exp": INF, "born": 0.0}
	active = not cells.is_empty() or c.enemies.any(func(e): return is_instance_valid(e) and str(e.row.get("id", "")) in ANTS)
	spit_w = (c.weapons.get("W-002", {}) as Dictionary).duplicate()
	spit_w.merge({"id": "ACID", "name": "산성 침", "dmg": SPIT_DMG, "crit_dmg": SPIT_DMG, "range_eff": SPIT_R, "range_max": SPIT_R + 1.0,
		"proj": "acid", "kind": "ranged", "sound": "", "rate": 0.3}, true)
	z_index = -9                                                       # 바닥 · 벽 위, 인물 아래
	queue_redraw()


static func is_ant(e: Enemy) -> bool:
	return str(e.row.get("id", "")) in ANTS


func scent_at(t: Vector2i) -> bool:
	return cells.has(t)


func perm_at(t: Vector2i) -> bool:
	return cells.has(t) and bool(cells[t]["perm"])


## 위장(여왕 페로몬) 남은 게임 분
func smell() -> int:
	return int(st.vars.get_v("PC_SMELL")) if st != null else 0


func smear() -> void:
	if st != null:
		st.vars.set_v("PC_SMELL", SMELL_MIN)


func wash(why: String = "물에 여왕 페로몬이 씻겨 나갔다.") -> void:
	if smell() > 0:
		st.vars.set_v("PC_SMELL", 0)
		note.emit(why)


## 냄새 길 지우기(물 · 소화기 분말 · 불): 반경 r칸 — 그 위의 일개미는 헤맨다. water면 그 안에 선 주인공 위장도 씻긴다
func erase_at(at: Vector2, r: float, water := false) -> int:
	var c0 := map.tile_of(at)
	var n := 0
	var ri := int(ceil(r))
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var t := c0 + Vector2i(dx, dy)
			if cells.has(t) and Vector2(dx, dy).length() <= r + 0.01:
				cells.erase(t)
				n += 1
	if n > 0:
		for e in cmb.enemies:
			if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == WORKER and e.loco.logical.distance_to(at) <= (r + 1.5) * 32.0:
				lose(e, LOST_S)
		queue_redraw()
	if water and cmb.pc.pos().distance_to(at) <= (r + 0.5) * 32.0:
		wash()
	return n


## 냄새 길을 잃었다(회전문에 갇힌 동료 · 지워진 줄): secs초 헤맨 뒤 가까운 줄을 찾는다
func lose(e: Enemy, secs: float) -> void:
	var a := _a(e)
	a["lost"] = secs
	a["off"] = 0.0
	e.route = []
	e.set("_route_i", 0)
	e.brain.home = e.loco.logical


## 다른 동사가 이 개미를 잠시 데려간다(회전문 삐걱 소리 쪽으로): 그동안 냄새 길을 따르지 않는다
func lure(e: Enemy, at: Vector2, secs: float) -> void:
	var a := _a(e)
	a["off"] = secs
	e.route = [[at, 6.0]]
	e.set("_route_i", 0)


func _a(e: Enemy) -> Dictionary:
	var k := e.get_instance_id()
	if not _ants.has(k):
		_ants[k] = {"prev": [], "goal": Vector2i(-9999, -9999), "lost": 0.0, "off": 0.0, "touch": 0.0, "cd": 1.0 + randf() * 2.0, "cast": 0.0, "mad": 0.0}
	return _ants[k]


# ---------------------------------------------------------------- 흐름(전투 모듈이 부른다 — 움직임이 멈춘 동안(대화 · 연출)은 dt 0)
func tick(dt: float) -> void:
	if not active or map == null:
		return
	clock += dt
	_hint_t = maxf(0.0, _hint_t - dt)
	_smell_tick(dt)
	if dt <= 0.0:
		return
	_draw_trail()
	_t += dt
	var slow := _t >= 0.2
	var sstep := _t
	if slow:
		_t = 0.0
		_expire()
	for e in cmb.enemies.duplicate():
		if not is_instance_valid(e) or e.cmb.dead or not is_ant(e):
			continue
		var a := _a(e)
		_frenzy_step(e, a, dt)
		_cast_step(e, a, dt)
		if slow:
			_disguise(e, a, sstep)
			if str(e.row.get("id", "")) == WORKER:
				_follow(e, a, sstep)
	_queen_step(dt)
	_draw_t += dt
	if _draw_t >= 0.25:
		_draw_t = 0.0
		queue_redraw()


## 위장 시간: 실시간 1초 = 게임 30초(1-3a). 물 칸에 들어서면 씻긴다
func _smell_tick(dt: float) -> void:
	if smell() <= 0:
		return
	_smell_acc += dt * 0.5
	if _smell_acc >= 1.0:
		var m := int(_smell_acc)
		_smell_acc -= m
		st.vars.set_v("PC_SMELL", maxi(0, smell() - m))
		if smell() == 0:
			note.emit("몸에 바른 여왕 페로몬 냄새가 다 날아갔다.")
	if map.wet_at(map.tile_of(cmb.pc.pos())) > 0:
		wash()


## 페로몬 바른 발: 냄새 줄 밖 걸음마다 20초 남는 냄새 칸
func _draw_trail() -> void:
	if smell() <= 0 or cmb.pc.dead:
		return
	var t := map.tile_of(cmb.pc.pos())
	if t == _pc_cell:
		return
	_pc_cell = t
	if map.is_solid(t) or perm_at(t):
		return
	if cells.has(t):
		cells[t]["exp"] = minf(float(cells[t]["born"]) + DRAW_MAX_S, clock + DRAW_S)
		return
	cells[t] = {"perm": false, "exp": clock + DRAW_S, "born": clock}
	if cells.size() > DRAW_CAP:
		var old := Vector2i(-9999, -9999)
		var ob := INF
		for k in cells:
			if not bool(cells[k]["perm"]) and float(cells[k]["born"]) < ob:
				ob = float(cells[k]["born"])
				old = k
		cells.erase(old)


func _expire() -> void:
	var gone: Array = []
	for k in cells:
		if not bool(cells[k]["perm"]) and float(cells[k]["exp"]) <= clock:
			gone.append(k)
	for k in gone:
		cells.erase(k)
	if not gone.is_empty():
		queue_redraw()


# ---------------------------------------------------------------- 일개미: 냄새 칸 따라 걷기
func _follow(e: Enemy, a: Dictionary, step: float) -> void:
	if e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY, AIBrain.S.SEARCH, AIBrain.S.SUSPICIOUS, AIBrain.S.LOST, AIBrain.S.FLEE] or e.asleep:
		a["goal"] = Vector2i(-9999, -9999)
		return
	if float(a["off"]) > 0.0:
		a["off"] = float(a["off"]) - step
		return
	var here := map.tile_of(e.loco.logical)
	if cells.has(here) and not bool(cells[here]["perm"]):                  # 개미가 밟으면 발자국 냄새가 다시 진해진다(처음 그린 뒤 60초까지)
		cells[here]["exp"] = minf(float(cells[here]["born"]) + DRAW_MAX_S, clock + DRAW_S)
	if float(a["lost"]) > 0.0:
		a["lost"] = float(a["lost"]) - step
		if float(a["lost"]) > 0.0:
			return
		var near := _nearest(here, SEEK_R)
		if near.x > -9999:
			a["goal"] = near
			a["prev"] = []
			e.route = [[_c(near), 0.0]]
			e.set("_route_i", 0)
		else:
			a["lost"] = LOST_S
		return
	var g: Vector2i = a["goal"]
	var on := cells.has(here) or _adjacent(here)
	if not on and g.x <= -9999:                                            # 줄 밖(귀환 · 처음): 가장 가까운 줄로
		a["lost"] = 0.01
		return
	if g.x > -9999 and e.loco.logical.distance_to(_c(g)) > 12.0 and not e.route.is_empty() and (cells.has(g) or not cells.has(here)):
		return                                                             # 아직 가는 중
	if not cells.has(here) and not _adjacent(here):
		lose(e, LOST_S * 0.5)
		return
	var chain := _chain(here if cells.has(here) else _adjacent_cell(here), a)
	if chain.is_empty():
		lose(e, LOST_S * 0.5)
		return
	var seq: Array = [here] + chain
	var pts: Array = []
	for j in range(1, seq.size()):                                         # 꺾이는 곳만 순찰 점으로(한 칸마다 멈칫하지 않게)
		if j == seq.size() - 1 or (seq[j] - seq[j - 1]) != (seq[j + 1] - seq[j]):
			pts.append([_c(seq[j]), 0.0])
	a["goal"] = chain[-1]
	e.route = pts
	e.set("_route_i", 0)
	e.set("_route_wait", 0.0)
	e.set("_path", PackedVector2Array())
	if e.brain.state == AIBrain.S.RETURN or e.brain.state == AIBrain.S.IDLE:
		e.brain.home = _c(chain[-1])                                       # 귀환 판정이 줄 위에서 끝나게


## 지금 칸에서 냄새 칸 CHAIN개를 고른다: 지난 칸은 피하고 · 새 발자국 냄새 → 곧은 길 → 아무 길 · 막다른 곳이면 돌아선다
func _chain(from: Vector2i, a: Dictionary, again := true) -> Array:
	var out: Array = []
	var prev: Array = (a["prev"] as Array).duplicate()
	var cur := from
	var dir := Vector2i.ZERO
	if prev.size() > 0:
		dir = cur - (prev[-1] as Vector2i)
	for i in CHAIN:
		var best := Vector2i(-9999, -9999)
		var bs := -INF
		for d in N8:
			var n: Vector2i = cur + d
			if not cells.has(n) or map.is_solid(n):
				continue
			if d.x != 0 and d.y != 0 and (map.is_solid(cur + Vector2i(d.x, 0)) or map.is_solid(cur + Vector2i(0, d.y))):
				continue                                                    # 모서리를 깎아 지나가지 않는다(벽 비비기 금지)
			if n in prev or n in out:
				continue
			var s := 0.0
			if not bool(cells[n]["perm"]):
				s += 4.0 + float(cells[n]["exp"]) - clock                   # 새 냄새일수록(행렬을 끌고 가는 발자국)
			if d == dir:
				s += 2.0
			elif dir != Vector2i.ZERO and (d.x == dir.x or d.y == dir.y):
				s += 0.8
			s += randf() * 0.6
			if d.x != 0 and d.y != 0:
				s -= 0.3
			if s > bs:
				bs = s
				best = n
		if best.x <= -9999:
			if out.is_empty() and prev.size() > 0 and again:                # 막다른 곳: 돌아선다(지난 칸을 잊고 한 번 더)
				a["prev"] = []
				return _chain(from, a, false)
			break
		out.append(best)
		dir = best - cur
		cur = best
	var p2: Array = (a["prev"] as Array) + [from] + out
	a["prev"] = p2.slice(maxi(0, p2.size() - 4))
	return out


func _adjacent(t: Vector2i) -> bool:
	return _adjacent_cell(t).x > -9999


func _adjacent_cell(t: Vector2i) -> Vector2i:
	for d in N8:
		if cells.has(t + d):
			return t + d
	return Vector2i(-9999, -9999)


func _nearest(t: Vector2i, r: int) -> Vector2i:
	var best := Vector2i(-9999, -9999)
	var bd := INF
	for k in cells:
		var d := Vector2(k - t).length()
		if d <= r and d < bd:
			bd = d
			best = k
	return best


func _c(t: Vector2i) -> Vector2:
	return Vector2(t) * 32.0 + Vector2(16, 16)


# ---------------------------------------------------------------- 위장 판정
func _disguise(e: Enemy, a: Dictionary, step: float) -> void:
	if not e.has_meta("ant_det"):
		e.set_meta("ant_det", e.det_mul)
	var base := float(e.get_meta("ant_det"))
	var id := str(e.row.get("id", ""))
	var pt := map.tile_of(cmb.pc.pos())
	var smelly := smell() > 0
	var carry := st != null and st.items.has(EGG)
	var m := 1.0
	if id == WORKER and smelly:
		m = 0.0 if perm_at(pt) else (0.15 if cells.has(pt) else 0.6)       # 줄 위 = 같은 무리 · 내 발자국 위 = 정찰 개미 · 줄 밖 = 의심
	elif id != WORKER and carry and cells.has(pt):
		m = 0.0 if perm_at(pt) or smelly else 0.3                          # 병정 · 여왕: 알을 물고 줄 위를 걷는 개미는 일하는 개미
	e.det_mul = base * m
	a["touch"] = maxf(0.0, float(a["touch"]) - step)
	if m < 1.0 and float(a["touch"]) <= 0.0 and not e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY] \
			and e.loco.logical.distance_to(cmb.pc.pos()) <= TOUCH_R * 32.0 + e.radius_px:
		a["touch"] = 6.0
		if cmb.sprinting or cmb.since_shot < 1.0:                           # 뛰거나 막 쐈다 — 더듬이가 낯선 것을 안다
			e.brain.gauge = 100.0
			e.hear("impact", cmb.pc.pos())
			_say("더듬이가 닿자마자 큰턱을 벌린다!")
		else:
			_say("더듬이가 내 어깨를 두 번 두드린다. …지나간다." if id == WORKER else "병정이 알을 더듬어 보고 비켜선다.")
			if id == WORKER:                                                # 마주 오던 일개미가 돌아선다(좁은 줄에서 길을 내준다)
				a["prev"] = [map.tile_of(e.loco.logical + (cmb.pc.pos() - e.loco.logical).normalized() * 32.0)]
				a["goal"] = Vector2i(-9999, -9999)
				e.route = []


func _say(s: String) -> void:
	if _hint_t <= 0.0:
		_hint_t = 4.0
		note.emit(s)


# ---------------------------------------------------------------- 분사 · 침 · 알 낳기 · 광란
func _cast_step(e: Enemy, a: Dictionary, dt: float) -> void:
	if float(a["cast"]) > 0.0:
		a["cast"] = float(a["cast"]) - dt
		if float(a["cast"]) <= 0.0 and e.pose in ["spray", "spit", "lay"]:
			e.set_pose("stand")
		return
	a["cd"] = maxf(0.0, float(a["cd"]) - dt)
	var id := str(e.row.get("id", ""))
	if float(a["cd"]) > 0.0 or e.cmb.held() or not e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY]:
		return
	var tg: Combatant = e.focus
	if tg == null or tg.dead:
		return
	var to := tg.pos() - e.loco.logical
	var d := to.length() / 32.0
	var reach := (e.radius_px + tg.radius + 6.0) / 32.0
	if id == SOLDIER and d <= SPRAY_R and d > reach + 0.2 and map.line_of_sight(e.loco.logical, tg.pos()):
		a["cd"] = SPRAY_CD
		_cast(e, a, "spray", to)
		for k in 3:                                                        # 줄기: 1 · 2 · 3칸에 튀김
			var p := e.loco.logical + to.normalized() * 32.0 * (k + 1) * minf(1.0, d / 3.0)
			cmb.shots.splats.append(Projectiles._fx("acid_splat", p + Vector2(0, -6), 0.0))
		tg.last_by = e.cmb.team
		tg.take({"hp": SPRAY_DMG}, e.loco.logical)
		if tg == cmb.pc:
			corrode.emit()
	elif id == QUEEN and d <= SPIT_R and d > reach + 0.5 and map.line_of_sight(e.loco.logical, tg.pos()):
		a["cd"] = SPIT_CD
		_cast(e, a, "spit", to)
		var o := e.loco.logical + Vector2(0, -14) + to.normalized() * 22.0
		var aim := (tg.pos() + Vector2(0, -10) - o).angle()
		cmb.shots.fire(o, rad_to_deg(aim), Arms.speed("acid"), e.cmb.team, spit_w, 95.0, false, 5, "", 0)


func _cast(e: Enemy, a: Dictionary, pose: String, to: Vector2) -> void:
	a["cast"] = CAST_S
	e.cmb.hold("cast", CAST_S)
	e.loco.facing = Locomotion.snap8(to, 0.0)
	e.set_pose(pose)


func _frenzy_step(e: Enemy, a: Dictionary, dt: float) -> void:
	if e.cmb.crippled.has("antenna") and not e.has_meta("ant_mad_done"):
		e.set_meta("ant_mad_done", true)                                    # 한 번만(부위 손상은 회복 전까지 그대로 — 광란은 8초)
		a["mad"] = FRENZY_S
		e.set_meta("ant_mad", true)
		e.cmb.team = "frenzy"
		e.foes = ["enemy"]
		e.brain.frenzy()
		e.focus = null
		note.emit("더듬이가 꺾였다 — %s가 미쳐서 제 무리를 문다!" % str(e.row.get("name", "개미")))
	if float(a["mad"]) > 0.0:
		a["mad"] = float(a["mad"]) - dt
		if float(a["mad"]) <= 0.0:
			e.remove_meta("ant_mad")
			e.cmb.team = "enemy"
			e.foes = ["player", "ally"]
			e.focus = null
			e.brain.gauge = 100.0
			e.brain.state = AIBrain.S.COMBAT


func _queen_step(dt: float) -> void:
	var q: Enemy = null
	for e in cmb.enemies:
		if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == QUEEN:
			q = e
			break
	if q == null or not q.brain.state in [AIBrain.S.COMBAT, AIBrain.S.SEARCH, AIBrain.S.SUSPICIOUS]:
		_lay_t = 0.0
		return
	_lay_t += dt
	if _lay_t < LAY_S:
		return
	_lay_t = 0.0
	var kids := cmb.enemies.filter(func(o): return is_instance_valid(o) and not o.cmb.dead and int(o.get_meta("mother", 0)) == q.get_instance_id())
	if kids.size() >= LAY_MAX:
		return
	var mound := egg_mound()
	if mound.x <= -9999:
		return
	if not ring_ok(mound):
		_say("여왕이 배를 떤다 — 알 무더기 쪽 냄새 줄이 끊겨 일개미가 나오지 않는다.")
		return
	var a := _a(q)
	_cast(q, a, "lay", _c(mound) - q.loco.logical)
	var spot := _c(mound) + Vector2(randf_range(-10, 10), 20)
	if map.is_solid(map.tile_of(spot)):
		spot = _c(mound + Vector2i(0, 1))
	var k := cmb.spawn(WORKER, spot, map, st, {"dir": "S", "morale": false})
	k.set_meta("mother", q.get_instance_id())
	k.hear("impact", cmb.pc.pos())
	k.brain.gauge = 100.0
	note.emit("알 무더기가 들썩인다 — 일개미가 또 하나 기어 나온다.")


## 알 무더기 자리(소품 egg_mound_kt 가운데 아래 칸)
func egg_mound() -> Vector2i:
	for p in map.props:
		if str(p["name"]) == "egg_mound_kt" and str(p.get("state", "")) != "gone":
			return Vector2i(int(p["x"]) + int(p.get("w", 1)) / 2, int(p["y"]) + int(p.get("h", 1)))
	return Vector2i(-9999, -9999)


## 알 무더기 둘레(2칸 안)에 냄새 칸이 남아 있나 — 끊으면 생성이 멎는다
func ring_ok(mound: Vector2i) -> bool:
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if cells.has(mound + Vector2i(dx, dy)):
				return true
	return false


# ---------------------------------------------------------------- 그림: 냄새 줄(바닥에 희미한 반짝임 — 영구 줄은 호박빛 점선 · 발자국은 진한 점이 바래 간다)
func _draw() -> void:
	if not active:
		return
	for k in cells:
		var c: Dictionary = cells[k]
		var o := Vector2(k) * 32.0
		var h := int(k.x * 73 + k.y * 151)
		if bool(c["perm"]):
			var tw := 0.5 + 0.5 * sin(clock * 2.2 + float(h % 17))
			for i in 4:
				var p := o + Vector2(4 + (h >> (i * 3)) % 24, 6 + (h >> (i * 2 + 1)) % 20)
				var col := Color("C4A56E") if (i + int(tw * 2.0)) % 3 == 0 else Color("7E8448")
				col.a = 0.55 if i % 2 == 0 else 0.35
				draw_rect(Rect2(p.floor(), Vector2(1, 1)), col)
			if tw > 0.85:
				draw_rect(Rect2((o + Vector2(10 + h % 12, 12 + h % 9)).floor(), Vector2(1, 1)), Color("E0C996"))
		else:
			var left := clampf((float(c["exp"]) - clock) / DRAW_S, 0.0, 1.0)
			var n := 2 + int(left * 3.0)
			for i in n:
				var p := o + Vector2(6 + (h >> (i * 2)) % 20, 8 + (h >> (i * 3 + 2)) % 16)
				var col := Color("D4FF6A") if left > 0.6 and i == 0 else Color("A5A86A")
				col.a = 0.35 + 0.4 * left
				draw_rect(Rect2(p.floor(), Vector2(1 if i % 2 else 2, 1)), col)
