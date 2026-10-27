## 투사체 풀 v0 (SD-11 §14.3, SD-19 §6.8): 풀 128(모바일 96), 공간 격자(4×4타일 버킷),
## 이번 프레임 이동 선분 대 원 판정(터널링 방지), 노드 하나에서 일괄 그리기(드로 콜 절감).
## 그림은 전투 이펙트 시트(CombatFx, SD-16 §10.1): 탄환은 일반 혼합, 총구 화염·맞은 자리 불꽃은 가산 혼합 층.
## 높은 엄폐는 막고, 낮은 엄폐는 표적이 서 있으면 40% 확률로 막는다. 쏘는 쪽이 1t 안에 붙은 엄폐는 무시(§4.2).
class_name Projectiles
extends Node2D

const MAX := 128
const BUCKET := 128.0
var world
var perk_note := Callable()              ## (글, 자리): 퍽이 일한 순간 머리 위 꼬리표(전투가 준다 — 1-12p 구현 뒤 재미 검수 ②)
var ento_said := false                   ## 이 맵에서 엔토몰로지스트 꼬리표를 띄웠나(맵마다 한 번)
var pc_st                                ## 주인공 이야기 상태(1-12p 퍽 — 블러디 메스 · 엔토몰로지스트 · 피네스 · 베터 크리티컬스). 없으면 퍽 없음
var rng := RandomNumberGenerator.new()
var shots: Array = []                    ## {p, v, ang, life, team, weapon, skill, origin}
var flashes: Array = []                  ## 총구 효과 {at, ang, set, age, born}
var splats: Array = []                   ## 일반 혼합 튀김(1-D5b 개미산 · 산성 침이 맞은 자리) {at, ang, set, age, born}
var sparks: Array = []                   ## 벽·엄폐물에 맞은 자리 불꽃 {at, ang, set, age, born}
var marks: Array = []                    ## 탄흔 [pos, ttl]
var _add: Node2D                         ## 가산 혼합 층(총구 화염·불꽃)
var combatants: Array = []
var _buckets := {}
var _occupied := {}                      ## 산 전투 참가자가 선 칸: 그 칸의 엄폐(표적 받침·소품)는 그 사람을 겨눈 탄을 막지 않는다
var hits_total := 0
var spawned_total := 0
var ghosted_total := 0                   ## 무적 프레임에 몸을 지나간 탄 수
var focused_hits: Array = []             ## 집중 사격 명중 부위 기록(시험·HUD용)
var beams: Array = []                    ## 레이저 빔 {a, b, age, col} — 0.1초 유지 뒤 4컷에 사그라든다(SD-16 §10.1)
var booms: Array = []                    ## 폭발 {at, age, k}
var blasts_total := 0
signal exploded(at: Vector2, outer_px: float, team: String)
signal nuked(at: Vector2)                       ## 핵 투사기 착탄(1-9d): 전투 모듈이 폭심 4t 방사능 지대 20초(8라드/초)를 깐다
signal struck(at: Vector2, tile: Vector2i, weapon: Dictionary, team: String)   ## 탄이 엄폐·벽에 막힌 자리(1-9c: 차량·드럼·함정 소품이 맞는다)
const BEAM_HOLD := 0.1
const BEAM_FADE := 4.0 / 30.0


func _ready() -> void:
	rng.seed = 2277
	z_index = 5
	_add = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_add.material = m
	add_child(_add)
	_add.draw.connect(_draw_add)


## focused: 집중 사격(SD-11 §5.3) — 치명타 +15%p, 머리 가중치 + 2 × 인지력, 무기 부위 활성
## flash: 총구 효과 세트. "auto"면 무기로 고른다(CombatFx.flash_for). ""면 그리지 않는다 — 주인공은 인형이 총과 같은 층에 그린다.
func fire(origin: Vector2, angle_deg: float, speed: float, team: String, weapon: Dictionary, skill: float,
		focused: bool = false, per: int = 5, flash: String = "auto", fl: int = 0) -> bool:
	if shots.size() >= MAX:
		return false
	var dir := Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
	var pk := Arms.proj(weapon) if weapon.get("kind", "ranged") == "ranged" else "bullet"
	shots.append({"p": origin, "v": dir * speed, "ang": angle_deg, "life": weapon["range_max"] * 32.0 / speed, "team": team,
		"weapon": weapon, "skill": skill, "origin": origin, "focused": focused, "per": per, "fl": fl,
		"proj": pk, "r": Arms.radius(pk), "spr": Arms.sprite(pk)})
	var fs := CombatFx.flash_for(weapon) if flash == "auto" else flash
	if CombatFx.has_set(fs):
		flashes.append(_fx(fs, origin, angle_deg))
	spawned_total += 1
	return true


## 1-9a 무기 계열 발사(SD-11 §3.2·§3.3): 무기 자료의 투사체 유형으로 고른다. 돌려주는 값 = 나간 투사체 수(0이면 못 쐈다).
## opts: focused, per, flash("auto"·""·세트), fl(층), target(곡사 착탄점), sneak_ok
func fire_weapon(origin: Vector2, angle_deg: float, team: String, w: Dictionary, skill: float, opts: Dictionary = {}) -> int:
	var pk := Arms.proj(w)
	var focused: bool = opts.get("focused", false)
	var per: int = int(opts.get("per", 5))
	var fl: int = int(opts.get("fl", 0))
	var fs: String = opts.get("flash", "auto")
	if fs == "auto":
		fs = CombatFx.flash_for(w)
	var n0 := shots.size()
	var lasers := 0
	match pk:
		"pellet":                                                     # 펠릿 n발을 원뿔 안에 고르게(탄당 피해 = 합계 ÷ n)
			var n := Arms.pellets(w)
			var cone := Arms.cone(w)
			var wp := w.duplicate()
			wp["dmg"] = float(w["dmg"]) / n
			wp["crit_dmg"] = float(w.get("crit_dmg", w["dmg"])) / n
			var gid := spawned_total
			for i in n:
				var a := angle_deg - cone + 2.0 * cone * (float(i) + 0.5) / n + rng.randf_range(-0.5, 0.5) * cone / n
				if not fire(origin, a, Arms.speed("pellet"), team, wp, skill, focused, per, "", fl):
					break
				shots[-1]["group"] = gid
		"laser":                                                      # 히트스캔: 이 프레임에 끝까지(벽·엄폐에서 멎는다)
			if fire(origin, angle_deg, Arms.speed("bullet"), team, w, skill, focused, per, "", fl):
				var ls: Dictionary = shots.pop_back()
				ls["sneak_ok"] = opts.get("sneak_ok", false)
				_trace(ls)
				lasers += 1
		"flame":                                                      # 화염 입자: 6t/초, 원뿔 25° 안, 대상마다 한 틱
			var cone := maxf(Arms.cone(w), 1.0)
			var a := angle_deg + (rng.randf() + rng.randf() - 1.0) * cone
			if fire(origin, a, Arms.speed("flame"), team, w, skill, false, per, "", fl):
				shots[-1]["life"] = float(w.get("range_eff", 4.0)) * 32.0 / Arms.speed("flame")
				shots[-1]["life0"] = shots[-1]["life"]
				shots[-1]["pierce"] = {}
				for k in 3:                                           # 그림만 있는 입자 셋(틱 사이를 메워 줄기로 보이게 — 맞지 않는다)
					if shots.size() >= MAX - 8:
						break
					var b := angle_deg + (rng.randf() + rng.randf() - 1.0) * cone
					var lead := Vector2.RIGHT.rotated(deg_to_rad(b)) * Arms.speed("flame") * (k + 1) / (float(w["rate"]) * 4.0)
					shots.append({"p": origin + lead, "v": Vector2.RIGHT.rotated(deg_to_rad(b)) * Arms.speed("flame") * rng.randf_range(0.9, 1.1),
						"ang": b, "life": shots[n0]["life"] - lead.length() / Arms.speed("flame"), "life0": shots[n0]["life0"], "team": team,
						"weapon": w, "skill": skill, "origin": origin, "fl": fl, "proj": "flame", "r": 0.0, "spr": "flame", "fx_only": true})
		"grenade", "nuke":                                            # 곡사: 착탄점으로 포물선(가짜 높이), 엄폐를 넘는다
			var to: Vector2 = opts.get("target", origin + Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * float(w["range_eff"]) * 32.0)
			var d: float = origin.distance_to(to)
			if pk == "nuke" and d < float(Arms.ARC_MIN_T["nuke"]) * 32.0:
				return 0                                              # 최소 사거리 6t 안은 쏘지 않는다(자폭 방지)
			d = minf(d, float(w["range_max"]) * 32.0)
			var land := origin + Vector2.RIGHT.rotated(deg_to_rad(angle_deg)) * d
			if fire(origin, angle_deg, 1.0, team, w, skill, false, per, "", fl):
				var s: Dictionary = shots[-1]
				s["arc"] = {"from": origin, "to": land, "t": 0.0, "dur": lerpf(0.6, 1.2, clampf(d / (16.0 * 32.0), 0.0, 1.0))}
				s["life"] = 99.0
		_:
			var sp := float(opts.get("speed", Arms.speed(pk))) if pk == "bullet" else Arms.speed(pk)
			if fire(origin, angle_deg, sp, team, w, skill, focused, per, "", fl) and pk == "missile":
				shots[-1]["accel"] = (Arms.speed("missile_max") - sp) / 0.8      # 0.8초에 18t/초까지
				shots[-1]["life"] = float(w["range_max"]) * 32.0 / Arms.speed("missile_max") + 0.4
	var made := shots.size() - n0 + lasers
	if made > 0:
		for k in range(n0, shots.size()):
			shots[k]["sneak_ok"] = opts.get("sneak_ok", false)
		if CombatFx.has_set(fs):
			flashes.append(_fx(fs, origin, angle_deg))
	return made


## 레이저 히트스캔: 처음 맞는 대상 또는 엄폐·벽까지 한 번에. 빔은 0.1초 보인다
func _trace(s: Dictionary) -> void:
	_rebucket()
	var a: Vector2 = s["p"]
	var b: Vector2 = a + (s["v"] as Vector2).normalized() * float(s["weapon"]["range_max"]) * 32.0
	var hit = _segment_hit(a, b, s)
	var end := b
	if hit != null:
		end = a.lerp(b, float(s.get("_t", 1.0)))
	var blk := _blocked(a, end, s)
	if blk.x >= 0.0:
		end = blk
		hit = null
		sparks.append(_fx("spark_red", blk, float(s["ang"])))
		marks.append([blk, 20])
		struck.emit(blk, Vector2i(floori(blk.x / 32), floori(blk.y / 32)), s["weapon"], str(s["team"]))
	if hit != null:
		_apply(hit, s, end)
	beams.append({"a": a, "b": end, "age": 0.0, "red": str(s["weapon"].get("family", "")) != "heavy"})


## 미사일 약한 유도(SD-11 §3.3 · 1-9e2): 앞쪽 ±60° · 12t 안 로봇 · 파워 아머(대형)를 초당 30°까지 쫓는다
const HOME_TURN := 30.0
func _home(s: Dictionary, dt: float) -> void:
	var v: Vector2 = s["v"]
	var team := str(s["team"])
	var best: Combatant = null
	var bd := 12.0 * 32.0
	for c in combatants:
		if c.dead or c.team == team or (team == "player" and is_ally(c.team)) or not (c.robot or c.big):
			continue
		var to: Vector2 = c.pos() - (s["p"] as Vector2)
		if to.length() > bd or absf(v.angle_to(to)) > deg_to_rad(60.0):
			continue
		bd = to.length()
		best = c
	if best == null:
		return
	var ang := v.angle_to(best.pos() - (s["p"] as Vector2))
	var lim := deg_to_rad(HOME_TURN) * dt
	s["v"] = v.rotated(clampf(ang, -lim, lim))
	s["homing"] = true


## 폭발(SD-11 §9.2): 피해 = 폭발 기본 × (100 + 스킬)/200 × 거리 비율(내부 1.0 → 외부 0.25) · DR 절반 · 낮은 엄폐 뒤 ×0.5 · 높은 엄폐 뒤 0.
## 내부 반경 안 인간형은 넘어진다. 광역이라 기습 배수가 없다. 주인공의 폭발은 아군을 비켜 가고(오사 없음 §8.4), 적의 폭발은 주민을 비켜 간다.
func explode(at: Vector2, w: Dictionary, skill: float, team: String, fl: int = 0) -> void:
	var pk := str(w.get("proj", Arms.proj(w)))
	var bk := str(w.get("blast_kind", ""))
	var rr: Array = Arms.blast_r("emp" if bk == "emp" else pk)
	var inner := float(rr[0]) * 32.0
	var outer := float(rr[1]) * 32.0
	var base := float(w.get("blast", 0.0))
	blasts_total += 1
	booms.append({"at": at, "age": 0.0, "k": 2 if pk in ["nuke", "car"] else 1, "born": Engine.get_process_frames(),
		"set": "boom_pulse" if bk == "emp" else ("boom_plasma" if bk == "plasma" else "boom")})
	exploded.emit(at, outer, team)
	if pk == "nuke":
		nuked.emit(at)
	if base <= 0.0:
		return
	_rebucket()
	var bw := {"dmg": base, "kind": "ranged", "crit_dmg": 0.0, "range_eff": 0.0, "condition": str(w.get("condition", "new"))}
	for c in combatants:
		if c.dead or c.team == "gone" or (team != "player" and c.team == "resident"):
			continue
		if c.fl() != fl:
			continue
		var ctr: Vector2 = c.pos() + Vector2(0, -12)
		var d: float = at.distance_to(ctr) - float(c.radius)
		if d > outer:
			continue
		var ratio := 1.0 if d <= inner else lerpf(1.0, 0.25, (d - inner) / maxf(1.0, outer - inner))
		if team == "player" and is_ally(c.team):
			ratio *= 0.5                                                # 오사(SD-11 §8.4): 주인공 폭발·화염·지뢰는 아군에게 ×0.5
		var cover := _blast_cover(at, ctr)
		if cover >= 2:
			continue
		if cover == 1:
			ratio *= 0.5
		var r := CombatRules.resolve({"weapon": bw, "skill": skill, "part": "torso", "dr": c.dr, "explosive": true,
			"perk_mult": Perks.dmg_mult(pc_st, target_id(c)) if team == "player" and pc_st != null else 1.0})
		r["hp"] = float(r["hp"]) * ratio * (float(w.get("robot_mult", 1.0)) if c.robot else 1.0)
		if bk == "emp":                                               # 펄스(§9.2): 로봇 +200 · 정지, 사람은 거의 안 다친다
			if c.robot:
				r["hp"] = float(r["hp"]) + 200.0 * ratio
				c.hold("stun", float(w.get("robot_stop", 2.0)))
			else:
				r["hp"] = float(r["hp"]) * 0.1
		c.last_by = team
		c.take(r, at)
		if float(w.get("blast_burn", 0.0)) > 0.0:                      # 연료 드럼 · 가스: 화상(SD-11 §9.3)
			c.add_dot("burn", float(w["blast_burn"]), 4.0)
		if d <= inner:
			c.hold("down", 1.5)
		if not c.big:
			c.push += (ctr - at).normalized() * (16.0 if d <= inner else 6.0)


## 폭심 → 대상 사이 엄폐(가장 높은 것): 0 없음 · 1 낮음 · 2 높음/벽
func _blast_cover(a: Vector2, b: Vector2) -> int:
	var n := int(ceil(a.distance_to(b) / 8.0)) + 1
	var best := 0
	var ta := Vector2i(floori(a.x / 32), floori(a.y / 32))
	var tb := Vector2i(floori(b.x / 32), floori(b.y / 32))
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		var t := Vector2i(floori(p.x / 32), floori(p.y / 32))
		if t == ta or t == tb:
			continue
		best = maxi(best, int(world.cover_at(t)) if world != null else 0)
	return best


static func _fx(set_name: String, at: Vector2, ang: float) -> Dictionary:
	return {"set": set_name, "at": at, "ang": ang, "age": 0.0, "born": Engine.get_process_frames()}


## 이펙트 나이: 나온 프레임에는 첫 컷을 그대로 그리고 다음 프레임부터 먹인다(사격·탄 이동 순서와 녹화 30fps에서도 첫 컷이 남는다)
static func _aged(list: Array, dt: float) -> Array:
	var now := Engine.get_process_frames()
	var keep: Array = []
	for f in list:
		if int(f["born"]) != now:
			f["age"] = float(f["age"]) + dt
		if CombatFx.frame_at(f["set"], f["age"]) >= 0:
			keep.append(f)
	return keep


func _rebucket() -> void:
	_buckets.clear()
	_occupied.clear()
	for c in combatants:
		if c.dead or not is_instance_valid(c.actor):
			continue
		_occupied[Vector2i(floori(c.pos().x / 32), floori(c.pos().y / 32))] = c.team
		var k := Vector2i(floori(c.pos().x / BUCKET), floori(c.pos().y / BUCKET))
		if not _buckets.has(k):
			_buckets[k] = []
		_buckets[k].append(c)


func step(dt: float) -> void:
	_rebucket()
	var keep: Array = []
	for s in shots:
		if s.has("arc"):                                               # 곡사: 날아가는 동안 맞지 않고, 내려앉으면 터진다
			var arc: Dictionary = s["arc"]
			arc["t"] = float(arc["t"]) + dt
			var k := clampf(float(arc["t"]) / float(arc["dur"]), 0.0, 1.0)
			s["p"] = (arc["from"] as Vector2).lerp(arc["to"], k)
			s["h"] = 4.0 * 28.0 * k * (1.0 - k)
			if k >= 1.0:
				explode(s["p"], s["weapon"], float(s["skill"]), str(s["team"]), int(s.get("fl", 0)))
				continue
			keep.append(s)
			continue
		if s.has("accel"):
			var v: Vector2 = s["v"]
			s["v"] = v.normalized() * minf(Arms.speed("missile_max"), v.length() + float(s["accel"]) * dt)
			_home(s, dt)
		var a: Vector2 = s["p"]
		var b: Vector2 = a + s["v"] * dt
		var hit = null if s.has("fx_only") else _segment_hit(a, b, s)
		if hit == null or s.has("pierce"):
			var blk := _blocked(a, b, s)
			if blk.x >= 0.0:
				if float(s["weapon"].get("blast", 0.0)) > 0.0:
					explode(blk - (s["v"] as Vector2).normalized() * 4.0, s["weapon"], float(s["skill"]), str(s["team"]), int(s.get("fl", 0)))
				elif s["proj"] == "acid":                                  # 산성 침: 벽에 튀어 흐른다(불꽃 대신)
					splats.append(_fx("acid_splat", blk, 0.0))
				elif s["proj"] != "flame":
					marks.append([blk, 20])
					sparks.append(_fx("spark", blk, float(s["ang"])))
				if not s.has("fx_only"):
					struck.emit(blk, Vector2i(floori(blk.x / 32), floori(blk.y / 32)), s["weapon"], str(s["team"]))
				continue
		if hit != null and s.has("pierce"):                            # 화염: 대상마다 한 번(입자는 계속 간다)
			if not (s["pierce"] as Dictionary).has(hit.get_instance_id()):
				s["pierce"][hit.get_instance_id()] = true
				_apply(hit, s, b)
		elif hit != null:
			_apply(hit, s, b)
			if s["proj"] == "acid":
				splats.append(_fx("acid_splat", b + Vector2(0, -4), 0.0))
			if float(s["weapon"].get("blast", 0.0)) > 0.0:
				explode(b, s["weapon"], float(s["skill"]), str(s["team"]), int(s.get("fl", 0)))
			continue
		s["p"] = b
		s["life"] -= dt
		if s["life"] > 0.0:
			keep.append(s)
		elif float(s["weapon"].get("blast", 0.0)) > 0.0 and s["proj"] == "missile":
			explode(b, s["weapon"], float(s["skill"]), str(s["team"]), int(s.get("fl", 0)))   # 미사일은 사거리 끝에서도 터진다
	shots = keep
	for bm in beams:
		bm["age"] = float(bm["age"]) + dt
	beams = beams.filter(func(bm): return float(bm["age"]) < BEAM_HOLD + BEAM_FADE)
	for bo in booms:
		if int(bo["born"]) != Engine.get_process_frames():
			bo["age"] = float(bo["age"]) + dt
	booms = booms.filter(func(bo): return CombatFx.frame_at("boom_smoke", float(bo["age"])) >= 0)
	flashes = _aged(flashes, dt)
	sparks = _aged(sparks, dt)
	splats = _aged(splats, dt)
	for m in marks:
		m[1] -= 1
	marks = marks.filter(func(m): return m[1] > 0)
	queue_redraw()
	if _add != null:
		_add.queue_redraw()


func _segment_hit(a: Vector2, b: Vector2, s: Dictionary):
	var best = null
	var best_t := 2.0
	var deck_world: bool = world is InteriorMap and world.has_deck
	var kmin := Vector2i(floori(minf(a.x, b.x) / BUCKET) - 1, floori(minf(a.y, b.y) / BUCKET) - 1)
	var kmax := Vector2i(floori(maxf(a.x, b.x) / BUCKET) + 1, floori(maxf(a.y, b.y) / BUCKET) + 1)
	for ky in range(kmin.y, kmax.y + 1):
		for kx in range(kmin.x, kmax.x + 1):
			for c in _buckets.get(Vector2i(kx, ky), []):
				if c.team == s["team"] or (c.team == "resident" and s["team"] != "player") \
						or (is_ally(c.team) and s["team"] == "player") or (is_ally(str(s["team"])) and c.team in ["player", "resident"]) \
						or c.team == "gone" \
						or (str(s["team"]).begins_with("calm") and c.team in ["player", "resident", "ally"]):   # 적의 탄은 주민을 비켜 간다 · 주인공 탄은 아군을 지나간다(SD-11 §8.4 오사 없음) · 달아난 적 · 비적대 무리(1-E)의 탄은 주인공 편을 비켜 간다
					continue
				if deck_world and not world.floors_meet(c.pos(), c.fl(), a, int(s.get("fl", 0))):
					continue                                              # 다른 층(고가 위·아래)은 맞지 않는다(SD-21 §6.2, 내려 쏘기는 1-9)
				var ctr: Vector2 = c.pos() + Vector2(0, -12)          # torso centre above the feet
				var tt := _seg_circle(a, b, ctr, c.radius + float(s.get("r", 0.0)))
				if c.invuln:                                          # 구르기 무적: 탄이 지나간다
					if tt >= 0.0 and not s.has("ghost"):
						s["ghost"] = true
						ghosted_total += 1
					continue
				if tt >= 0.0 and tt < best_t:
					best_t = tt
					best = c
	s["_t"] = best_t
	return best


static func _seg_circle(a: Vector2, b: Vector2, c: Vector2, r: float) -> float:
	var d := b - a
	var f := a - c
	var A := d.dot(d)
	if A < 0.0001:
		return 0.0 if f.length() <= r else -1.0
	var B := 2.0 * f.dot(d)
	var Cc := f.dot(f) - r * r
	var disc := B * B - 4.0 * A * Cc
	if disc < 0.0:
		return -1.0
	var sq := sqrt(disc)
	var t1 := (-B - sq) / (2.0 * A)
	var t2 := (-B + sq) / (2.0 * A)
	if t1 >= 0.0 and t1 <= 1.0:
		return t1
	if t2 >= 0.0 and t2 <= 1.0 and Cc <= 0.0:
		return 0.0
	return -1.0


## 엄폐 타일 통과 판정. 막히면 막힌 지점, 아니면 (-1, -1).
## 쏜 사람 칸에서 한 칸 안의 낮은 엄폐는 자기 탄을 막지 않는다(SD-11 §4.2 '내 엄폐는 나를 막지 않는다').
func _blocked(a: Vector2, b: Vector2, s: Dictionary) -> Vector2:
	var n := int(ceil(a.distance_to(b) / 8.0)) + 1
	var o: Vector2 = s["origin"]
	var deck_world: bool = world is InteriorMap and world.has_deck
	var ot := Vector2i(floori(o.x / 32), floori(o.y / 32))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var t := Vector2i(floori(p.x / 32), floori(p.y / 32))
		if deck_world:                                                   # 고가(1-Rd): 층 1 탄은 상판 밖·난간에서 멎고 땅 엄폐를 넘는다 · 층 0 탄은 기둥·옹벽에 막힌다
			var d: int = world.deck_at(t)
			if int(s.get("fl", 0)) >= 1 and not InteriorMap.is_link(d):
				if (d == InteriorMap.DK_RAIL or d == InteriorMap.DK_WALL or d == InteriorMap.DK_JUNK or not InteriorMap.is_top(d)) and p.distance_to(o) > 12.0:
					return p
				continue
			if d == InteriorMap.DK_PILLAR or d == InteriorMap.DK_WALL:
				return p
		var cov: int = world.cover_at(t)
		if cov == 0:
			continue
		if p.distance_to(o) <= 32.0 or (cov == 1 and maxi(absi(t.x - ot.x), absi(t.y - ot.y)) <= 1):
			continue
		if cov == 1 and _occupied.get(t, s["team"]) != s["team"]:      # 표적이 선 칸(받침대·낮은 소품)
			continue
		if cov >= 2 or s.get("proj", "") == "flame":                    # 화염은 낮은 엄폐도 넘지 못한다(SD-11 §3.4)
			return p
		if rng.randf() < 0.4:                                            # low cover vs a standing target
			return p
	return Vector2(-1, -1)


## 맞은 쪽 적 ID(엔토몰로지스트 대상 — 적 노드의 enemy_id 메타). 표적 · 주민은 ""
static func target_id(c: Combatant) -> String:
	var a = c.actor
	return str(a.get_meta("enemy_id", "")) if a is Node and a.has_meta("enemy_id") else ""


func _apply(c: Combatant, s: Dictionary, at: Vector2) -> void:
	var w: Dictionary = s["weapon"]
	var focused: bool = s.get("focused", false)
	var pk: bool = str(s["team"]) == "player" and pc_st != null
	var crit: bool = rng.randf() * 100.0 < CombatRules.crit_chance(5, float(w.get("crit_mult", 1.0)), "new", Perks.crit_add(pc_st) if pk else 0.0, focused) and not bool(w.get("no_crit", false))
	var wts: Dictionary = c.weights
	if not c.back_part.is_empty() and c.actor != null and "loco" in c.actor and CombatRules.from_behind(c.actor.loco.logical, c.actor.loco.facing, s["origin"]):
		wts = CombatRules.back_weights(wts, c.back_part)                 # 뒤쪽 90° — 갑각 배
	var part := CombatRules.pick_part(CombatRules.part_weights(wts, {"focused": focused, "per": s.get("per", 5)}) if focused
		else wts, rng)
	var sneak: bool = s.get("sneak_ok", false) and c.unaware.is_valid() and c.unaware.call()
	c.last_sneak = sneak
	var r := CombatRules.resolve({"weapon": w, "skill": s["skill"], "dist": s["origin"].distance_to(at) / 32.0,
		"crit": crit or sneak, "part": part, "dr": c.dr, "sneak": sneak, "part_mult": c.part_mult.get(part, CombatRules.PART_MULT.get(part, 1.0)),
		"perk_mult": Perks.dmg_mult(pc_st, target_id(c)) if pk else 1.0, "better_crits": pk and Perks.better_crits(pc_st)})
	r["nonlethal"] = w.get("sound", "") == "suppressed" or w.get("kind", "ranged") != "ranged" or s.get("proj", "") == "net"   # 공기총·근접·그물 = 비살상(기절, 0-9)
	if c.robot:
		r["hp"] = float(r["hp"]) * float(w.get("robot_mult", 1.0))
	if pk and not ento_said and Perks.rank(pc_st, "PK-013") > 0 and Perks.insect(target_id(c)) and perk_note.is_valid():
		ento_said = true
		perk_note.call("엔토몰로지스트", c.pos() + Vector2(0, -40))
	c.last_by = str(s["team"])
	c.take(r, s["origin"])
	Projectiles.after_hit(c, w, s.get("proj", "bullet"), s["origin"].distance_to(at) / 32.0, rng, (at - s["origin"]).normalized())
	if s.has("group"):                                              # 산탄 넉백: 3t 안에서 같은 대상에 6발 이상(대형 제외)
		var pg: Array = c.get_meta("pellet_group", [-1, 0])
		var cnt: int = (int(pg[1]) + 1) if int(pg[0]) == int(s["group"]) else 1
		c.set_meta("pellet_group", [int(s["group"]), cnt])
		if cnt == 6 and s["origin"].distance_to(at) <= 96.0 and not c.big:
			c.push += (at - s["origin"]).normalized() * 16.0
	hits_total += 1
	if focused:
		focused_hits.append(part)
	marks.append([at, 6])


## 투사체 그림 컷: 화염 입자는 나온 뒤 수명에 따라 0~4컷(작은 심 → 불덩이 → 성기게 꺼짐), 그 밖은 0
static func _proj_frame(s: Dictionary) -> int:
	if s.get("spr", "") != "flame":
		return 0
	return clampi(int((1.0 - float(s["life"]) / maxf(0.01, float(s.get("life0", 1.0)))) * 5.0), 0, 4)


## 맞은 뒤 상태 이상(1-9a, SD-13 무기 특성): 지속 피해(화상·전기) · 넘어뜨림 · 마비 · 그물 · 다리 손상(못·다트)
static func after_hit(c: Combatant, w: Dictionary, pk: String, dist_t: float, r: RandomNumberGenerator, dir: Vector2) -> void:
	if c.dead:
		return
	var dot := float(w.get("dot", 0.0))
	if dot > 0.0:
		c.add_dot(str(w.get("dot_kind", "burn")), dot, float(w.get("dot_s", 3.0)))
	var kp := float(w.get("knock_pct", 0.0))
	if kp > 0.0 and (Arms.fam(w) != "shotgun" or dist_t <= 3.0) and r.randf() * 100.0 < kp:
		c.hold("down", 1.5)
	var sp := float(w.get("stun_pct", 0.0))
	if sp > 0.0 and not c.robot and r.randf() * 100.0 < sp:
		c.hold("stun", 1.0)
	if pk == "net":
		c.hold("root", 3.0)
	var lp := float(w.get("leg_pct", 0.0))
	if lp > 0.0 and r.randf() * 100.0 < lp:
		c.set_meta("leg_hurt", true)
		if c.track_limbs:                                               # 다트 건 '다리 고정'(SD-11 §4.8): 다리 부위 피해 1,000 → 즉시 다리 손상(1-9e3)
			c._limb_hit("leg", 1000.0)


func _draw() -> void:
	var tex := CombatFx.sheet()
	for bo in booms:                                                 # 폭발 연기(일반 혼합) — 불덩이 아래
		var k := CombatFx.frame_at("boom_smoke", float(bo["age"]))
		if k >= 0:
			var rs := CombatFx.region("boom_smoke", 0.0, k)
			var sc := float(bo["k"])
			draw_texture_rect_region(tex, Rect2((bo["at"] as Vector2) - rs.size * 0.5 * sc, rs.size * sc), rs)
	for m in marks:
		draw_rect(Rect2((m[0] as Vector2).round() - Vector2(1, 1), Vector2(2, 2)), Color("cbc5b9" if m[1] > 10 else "6e6966"))
	var dw: bool = world is WorldMap and world.has_deck
	for bm in beams:                                                  # 레이저 빔(SD-16 §10.1 '빔 1~2px P54·P63, 0.1초 유지 후 4컷'): 일반 혼합 — 밝은 바닥에서도 보인다.
		var f := clampf((float(bm["age"]) - BEAM_HOLD) / BEAM_FADE, 0.0, 1.0)   # 사그라듦은 반투명 대신 굵기·색 단계(§3.8)
		var k := int(f * 4.0)
		var red: bool = bm["red"]
		if k == 0:
			draw_line(bm["a"], bm["b"], Color("A82A26") if red else Color("1F9AA6"), 2.0)
			draw_line(bm["a"], bm["b"], Color("FFEC9A") if red else Color("7FF0E8"), 1.0)
		elif k == 1:
			draw_line(bm["a"], bm["b"], Color("E04A35") if red else Color("7FF0E8"), 1.0)
		elif k == 2:
			draw_line(bm["a"], bm["b"], Color("A82A26") if red else Color("1F9AA6"), 1.0)
		elif k == 3:
			draw_dashed_line(bm["a"], bm["b"], Color("6E1A1E") if red else Color("0E4A52"), 1.0, 2.0)
	for s in shots:                                                   # 탄환 16방향(2×1 심 + 잔상 4px + 어두운 심) — 머리가 탄 위치
		if dw and int(s.get("fl", 0)) == 0 and InteriorMap.is_top(world.deck_at(world.tile_of(s["p"]))) \
				and (s["p"] as Vector2).distance_to(world.hole) > world.hole_r:
			continue                                                  # 상판 아래(층 0) 탄은 상판에 가린다(디더 구멍 안만 보인다)
		var spr: String = s.get("spr", "bullet")
		if CombatFx.meta()["sets"][spr]["blend"] == "add":         # 가산 투사체(플라스마·방전 구)는 가산 층에서
			continue
		var at: Vector2 = s["p"]
		if s.has("h"):                                             # 곡사: 그림자 + 띄운 탄
			draw_circle(at, 3.0, Color(0, 0, 0, 0.35))
			at -= Vector2(0, float(s["h"]))
		var r := CombatFx.region(spr, float(s["ang"]), _proj_frame(s))
		draw_texture_rect_region(tex, Rect2(CombatFx.top_left(spr, at), r.size), r)
	for f in splats:                                                 # 산 튀김(일반 혼합)
		var k := CombatFx.frame_at(f["set"], f["age"])
		if k >= 0:
			var r := CombatFx.region(f["set"], f["ang"], k)
			draw_texture_rect_region(tex, Rect2(CombatFx.top_left(f["set"], f["at"]), r.size), r)
	for bo in booms:                                                 # 폭발 불덩이(연기 위) — 일반 혼합
		var bs: String = bo.get("set", "boom")
		var k := CombatFx.frame_at(bs, float(bo["age"]))
		if k >= 0:
			var rs := CombatFx.region(bs, 0.0, k)
			var sc := float(bo["k"])
			draw_texture_rect_region(tex, Rect2((bo["at"] as Vector2) - rs.size * 0.5 * sc, rs.size * sc), rs)


func _draw_add() -> void:
	var tex := CombatFx.sheet()
	for s in shots:                                                # 가산 투사체: 플라스마·방전 구·화염 입자
		var spr: String = s.get("spr", "bullet")
		if CombatFx.meta()["sets"][spr]["blend"] != "add":
			continue
		var r := CombatFx.region(spr, float(s["ang"]), _proj_frame(s))
		_add.draw_texture_rect_region(tex, Rect2(CombatFx.top_left(spr, s["p"]), r.size), r)
	for bm in beams:                                               # 빔 둘레 빛(가산, 밝은 바닥에서는 묻히고 어두운 곳에서 번진다)
		if float(bm["age"]) < BEAM_HOLD:
			_add.draw_line(bm["a"], bm["b"], Color("6E1A1E") if bm["red"] else Color("0E4A52"), 4.0)
	for list in [flashes, sparks]:
		for f in list:
			var k := CombatFx.frame_at(f["set"], f["age"])
			if k < 0:
				continue
			var r := CombatFx.region(f["set"], f["ang"], k)
			_add.draw_texture_rect_region(tex, Rect2(CombatFx.top_left(f["set"], f["at"]), r.size), r)


## 주인공 편(동행 'ally' · 진행기가 따로 이름 붙인 'ally_…' — FQ-SB-02 운송조 ally_sb02): 주인공 탄은 지나가고 폭발은 ×0.5(SD-11 §8.4 오사 없음 — D-410)
static func is_ally(team: String) -> bool:
	return team == "ally" or team.begins_with("ally_")

