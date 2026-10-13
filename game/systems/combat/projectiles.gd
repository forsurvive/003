## 투사체 풀 v0 (SD-11 §14.3, SD-19 §6.8): 풀 128(모바일 96), 공간 격자(4×4타일 버킷),
## 이번 프레임 이동 선분 대 원 판정(터널링 방지), 노드 하나에서 일괄 그리기(드로 콜 절감).
## 그림은 전투 이펙트 시트(CombatFx, SD-16 §10.1): 탄환은 일반 혼합, 총구 화염·맞은 자리 불꽃은 가산 혼합 층.
## 높은 엄폐는 막고, 낮은 엄폐는 표적이 서 있으면 40% 확률로 막는다. 쏘는 쪽이 1t 안에 붙은 엄폐는 무시(§4.2).
class_name Projectiles
extends Node2D

const MAX := 128
const BUCKET := 128.0
var world
var rng := RandomNumberGenerator.new()
var shots: Array = []                    ## {p, v, ang, life, team, weapon, skill, origin}
var flashes: Array = []                  ## 총구 효과 {at, ang, set, age, born}
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
		focused: bool = false, per: int = 5, flash: String = "auto") -> bool:
	if shots.size() >= MAX:
		return false
	var dir := Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
	shots.append({"p": origin, "v": dir * speed, "ang": angle_deg, "life": weapon["range_max"] * 32.0 / speed, "team": team,
		"weapon": weapon, "skill": skill, "origin": origin, "focused": focused, "per": per})
	var fs := CombatFx.flash_for(weapon) if flash == "auto" else flash
	if CombatFx.has_set(fs):
		flashes.append(_fx(fs, origin, angle_deg))
	spawned_total += 1
	return true


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
		if c.dead:
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
		var a: Vector2 = s["p"]
		var b: Vector2 = a + s["v"] * dt
		var hit = _segment_hit(a, b, s)
		if hit == null:
			var blk := _blocked(a, b, s)
			if blk.x >= 0.0:
				marks.append([blk, 20])
				sparks.append(_fx("spark", blk, float(s["ang"])))
				continue
		if hit != null:
			_apply(hit, s, b)
			continue
		s["p"] = b
		s["life"] -= dt
		if s["life"] > 0.0:
			keep.append(s)
	shots = keep
	flashes = _aged(flashes, dt)
	sparks = _aged(sparks, dt)
	for m in marks:
		m[1] -= 1
	marks = marks.filter(func(m): return m[1] > 0)
	queue_redraw()
	if _add != null:
		_add.queue_redraw()


func _segment_hit(a: Vector2, b: Vector2, s: Dictionary):
	var best = null
	var best_t := 2.0
	var kmin := Vector2i(floori(minf(a.x, b.x) / BUCKET) - 1, floori(minf(a.y, b.y) / BUCKET) - 1)
	var kmax := Vector2i(floori(maxf(a.x, b.x) / BUCKET) + 1, floori(maxf(a.y, b.y) / BUCKET) + 1)
	for ky in range(kmin.y, kmax.y + 1):
		for kx in range(kmin.x, kmax.x + 1):
			for c in _buckets.get(Vector2i(kx, ky), []):
				if c.team == s["team"]:
					continue
				var ctr: Vector2 = c.pos() + Vector2(0, -12)          # torso centre above the feet
				var tt := _seg_circle(a, b, ctr, c.radius)
				if c.invuln:                                          # 구르기 무적: 탄이 지나간다
					if tt >= 0.0 and not s.has("ghost"):
						s["ghost"] = true
						ghosted_total += 1
					continue
				if tt >= 0.0 and tt < best_t:
					best_t = tt
					best = c
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
	var ot := Vector2i(floori(o.x / 32), floori(o.y / 32))
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var t := Vector2i(floori(p.x / 32), floori(p.y / 32))
		var cov: int = world.cover_at(t)
		if cov == 0:
			continue
		if p.distance_to(o) <= 32.0 or (cov == 1 and maxi(absi(t.x - ot.x), absi(t.y - ot.y)) <= 1):
			continue
		if cov == 1 and _occupied.get(t, s["team"]) != s["team"]:      # 표적이 선 칸(받침대·낮은 소품)
			continue
		if cov >= 2:
			return p
		if rng.randf() < 0.4:                                            # low cover vs a standing target
			return p
	return Vector2(-1, -1)


func _apply(c: Combatant, s: Dictionary, at: Vector2) -> void:
	var w: Dictionary = s["weapon"]
	var focused: bool = s.get("focused", false)
	var crit := rng.randf() * 100.0 < CombatRules.crit_chance(5, float(w.get("crit_mult", 1.0)), "new", 0.0, focused)
	var part := CombatRules.pick_part(CombatRules.part_weights(c.weights, {"focused": focused, "per": s.get("per", 5)}) if focused
		else c.weights, rng)
	var sneak: bool = s.get("sneak_ok", false) and c.unaware.is_valid() and c.unaware.call()
	c.last_sneak = sneak
	var r := CombatRules.resolve({"weapon": w, "skill": s["skill"], "dist": s["origin"].distance_to(at) / 32.0,
		"crit": crit or sneak, "part": part, "dr": c.dr, "sneak": sneak})
	r["nonlethal"] = w.get("sound", "") == "suppressed" or w.get("kind", "ranged") != "ranged"   # 공기총·근접 = 비살상(기절, 0-9)
	c.take(r, s["origin"])
	hits_total += 1
	if focused:
		focused_hits.append(part)
	marks.append([at, 6])


func _draw() -> void:
	var tex := CombatFx.sheet()
	for m in marks:
		draw_rect(Rect2((m[0] as Vector2).round() - Vector2(1, 1), Vector2(2, 2)), Color("cbc5b9" if m[1] > 10 else "6e6966"))
	for s in shots:                                                   # 탄환 16방향(2×1 심 + 잔상 4px + 어두운 심) — 머리가 탄 위치
		var r := CombatFx.region("bullet", float(s["ang"]), 0)
		draw_texture_rect_region(tex, Rect2(CombatFx.top_left("bullet", s["p"]), r.size), r)


func _draw_add() -> void:
	var tex := CombatFx.sheet()
	for list in [flashes, sparks]:
		for f in list:
			var k := CombatFx.frame_at(f["set"], f["age"])
			if k < 0:
				continue
			var r := CombatFx.region(f["set"], f["ang"], k)
			_add.draw_texture_rect_region(tex, Rect2(CombatFx.top_left(f["set"], f["at"]), r.size), r)
