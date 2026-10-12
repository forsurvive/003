## 투사체 풀 v0 (SD-11 §14.3, SD-19 §6.8): 풀 128(모바일 96), 공간 격자(4×4타일 버킷),
## 이번 프레임 이동 선분 대 원 판정(터널링 방지), 노드 하나에서 일괄 그리기(드로 콜 절감).
## 높은 엄폐는 막고, 낮은 엄폐는 표적이 서 있으면 40% 확률로 막는다. 쏘는 쪽이 1t 안에 붙은 엄폐는 무시(§4.2).
class_name Projectiles
extends Node2D

const MAX := 128
const BUCKET := 128.0
var world
var rng := RandomNumberGenerator.new()
var shots: Array = []                    ## {p, v, life, team, weapon, skill, from, origin}
var flashes: Array = []                  ## [pos, ttl]
var marks: Array = []                    ## 탄흔 [pos, ttl]
var combatants: Array = []
var _buckets := {}
var hits_total := 0
var spawned_total := 0
var ghosted_total := 0                   ## 무적 프레임에 몸을 지나간 탄 수
var focused_hits: Array = []             ## 집중 사격 명중 부위 기록(시험·HUD용)


func _ready() -> void:
	rng.seed = 2277
	z_index = 5


## focused: 집중 사격(SD-11 §5.3) — 치명타 +15%p, 머리 가중치 + 2 × 인지력, 무기 부위 활성
func fire(origin: Vector2, angle_deg: float, speed: float, team: String, weapon: Dictionary, skill: float,
		focused: bool = false, per: int = 5) -> bool:
	if shots.size() >= MAX:
		return false
	var dir := Vector2.RIGHT.rotated(deg_to_rad(angle_deg))
	shots.append({"p": origin, "v": dir * speed, "life": weapon["range_max"] * 32.0 / speed, "team": team,
		"weapon": weapon, "skill": skill, "origin": origin, "focused": focused, "per": per})
	flashes.append([origin, 2])
	spawned_total += 1
	return true


func _rebucket() -> void:
	_buckets.clear()
	for c in combatants:
		if c.dead:
			continue
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
				continue
		if hit != null:
			_apply(hit, s, b)
			continue
		s["p"] = b
		s["life"] -= dt
		if s["life"] > 0.0:
			keep.append(s)
	shots = keep
	for f in flashes:
		f[1] -= 1
	flashes = flashes.filter(func(f): return f[1] > 0)
	for m in marks:
		m[1] -= 1
	marks = marks.filter(func(m): return m[1] > 0)
	queue_redraw()


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
func _blocked(a: Vector2, b: Vector2, s: Dictionary) -> Vector2:
	var n := int(ceil(a.distance_to(b) / 8.0)) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		var t := Vector2i(floori(p.x / 32), floori(p.y / 32))
		var cov: int = world.cover_at(t)
		if cov == 0:
			continue
		if p.distance_to(s["origin"]) <= 32.0:                          # own cover never blocks own shots
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
	var r := CombatRules.resolve({"weapon": w, "skill": s["skill"], "dist": s["origin"].distance_to(at) / 32.0,
		"crit": crit, "part": part, "dr": c.dr})
	c.take(r, s["origin"])
	hits_total += 1
	if focused:
		focused_hits.append(part)
	marks.append([at, 6])


func _draw() -> void:
	for s in shots:
		var p: Vector2 = (s["p"] as Vector2).round()
		var tail: Vector2 = p - (s["v"] as Vector2).normalized() * 6.0
		draw_line(tail.round(), p, Color("e8c23a"), 1.0)
		draw_rect(Rect2(p - Vector2(0.5, 0.5), Vector2(1, 1)), Color("ffec9a"))
	for f in flashes:
		var q: Vector2 = (f[0] as Vector2).round()
		draw_rect(Rect2(q - Vector2(2, 2), Vector2(4, 4)), Color("ffec9a"))
		draw_rect(Rect2(q - Vector2(1, 1), Vector2(2, 2)), Color("e9e4d8"))
	for m in marks:
		draw_rect(Rect2((m[0] as Vector2).round() - Vector2(1, 1), Vector2(2, 2)), Color("cbc5b9" if m[1] > 10 else "6e6966"))
