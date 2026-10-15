## 고가 2층 엔진(단계 1-Rd, SD-21 §6.1~6.2 · SD-16 §6.5): 상판 부호 · 층별 막힘 · 램프로만 층 이동 · 끊긴 상판에서 멈춤 ·
## 층 0·1 탄 막힘 · 다른 층 시야 ×0.5 · 층별 길찾기 · 저장 왕복.
extends RefCounted

## 시험 맵(24×12). 가로 고가: 땅 x 0~1 → 램프 x 2~5(4·5행, 옆벽 3·6행) → 상판 x 6~17(난간 3·6행, 노면 4·5행),
## 경간 x 13~14 무너짐, 기둥 (9,5), 상판 아래는 땅(층 0이 지나간다).
func _map() -> InteriorMap:
	var m := InteriorMap.new()
	m.size = Vector2i(24, 12)
	m.solid.resize(24 * 12)
	m.cover.resize(24 * 12)
	m.deck.resize(24 * 12)
	m.has_deck = true
	for x in range(2, 6):
		m.deck[3 * 24 + x] = InteriorMap.DK_WALL
		m.deck[6 * 24 + x] = InteriorMap.DK_WALL
		m.solid[3 * 24 + x] = 1
		m.solid[6 * 24 + x] = 1
		for y in [4, 5]:
			m.deck[y * 24 + x] = InteriorMap.DK_RAMP
	for x in range(6, 18):
		if x == 13 or x == 14:
			continue
		m.deck[3 * 24 + x] = InteriorMap.DK_RAIL
		m.deck[6 * 24 + x] = InteriorMap.DK_RAIL
		for y in [4, 5]:
			m.deck[y * 24 + x] = InteriorMap.DK_BROKEN if x == 12 or x == 15 else InteriorMap.DK_DECK
	m.deck[5 * 24 + 9] = InteriorMap.DK_PILLAR
	m.solid[5 * 24 + 9] = 1
	m.cover[5 * 24 + 9] = 2
	return m


static func _c(x: int, y: int) -> Vector2:
	return Vector2(x * 32 + 16, y * 32 + 16)


## 한 방향으로 secs초 걷는다(1/60초 틱)
static func _walk(a: Actor, dir: Vector2, secs: float) -> void:
	for i in int(secs * 60.0):
		a.move(dir, 1.0 / 60.0)


func _actor(m: InteriorMap, at: Vector2, fl: int) -> Actor:
	var a := Actor.new()
	a.setup("st_c_001", at, m)
	a.set_floor(fl)
	return a


func test_deck_floor_rules(t) -> void:
	var m := _map()
	t.eq([m.floor_after(Vector2i(1, 4), Vector2i(2, 4), 0), m.floor_after(Vector2i(5, 4), Vector2i(6, 4), 0), m.floor_after(Vector2i(6, 4), Vector2i(5, 4), 1),
		m.floor_after(Vector2i(2, 4), Vector2i(1, 4), 1), m.floor_after(Vector2i(7, 7), Vector2i(7, 6), 0)], [0, 1, 1, 0, 0],
		"층 전이: 램프에 올라도 그대로 · 램프 위 끝에서 상판 = 1 · 램프로 내려와도 1 · 램프 아래 끝에서 땅 = 0 · 그늘로 들어가도 0")
	t.ok(m._blocked_floor(Vector2i(5, 4), Vector2i(6, 4), 0), "상판 그늘(층 0)에서 램프로는 못 오른다")
	t.ok(not m._blocked_floor(Vector2i(2, 4), Vector2i(1, 4), 0), "램프는 아래 끝 땅에서 탄다")
	t.ok(m._blocked_floor(Vector2i(2, 3), Vector2i(1, 3), 0) and m._blocked_floor(Vector2i(4, 3), Vector2i(4, 4), 1), "램프 옆벽은 두 층 다 막는다")
	t.ok(m._blocked_floor(Vector2i(7, 3), Vector2i(7, 4), 1) and not m._blocked_floor(Vector2i(7, 3), Vector2i(7, 2), 0), "난간: 위는 막고 아래는 지나간다")
	t.ok(m._blocked_floor(Vector2i(9, 5), Vector2i(9, 6), 0) and not m._blocked_floor(Vector2i(9, 5), Vector2i(8, 5), 1), "기둥: 아래는 막고 위는 상판")
	t.ok(m._blocked_floor(Vector2i(13, 4), Vector2i(12, 4), 1), "무너진 경간: 층 1은 못 건넌다")
	t.ok(not m._blocked_floor(Vector2i(13, 4), Vector2i(12, 4), 0), "무너진 경간 아래(층 0)는 땅")
	m.free()


func test_deck_walk(t) -> void:
	var m := _map()
	var a := _actor(m, _c(0, 4), 0)
	_walk(a, Vector2.RIGHT, 2.5)
	t.ok(a.floor_id == 1 and a.loco.logical.x > 6 * 32, "땅 → 램프 → 상판: 걸어 올라 층 1 (x %.0f, 층 %d)" % [a.loco.logical.x, a.floor_id])
	t.eq(a.z_index, 3, "상판 위 인물은 상판(z 2) 위에 그린다")
	_walk(a, Vector2.RIGHT, 3.0)
	var stop_x := a.loco.logical.x
	t.ok(stop_x < 13 * 32 and stop_x > 12 * 32, "끊긴 경간 끝에서 멈춘다(떨어지지 않는다): x %.1f" % stop_x)
	t.eq(a.loco.motion, "idle", "막히면 선다(제자리걸음 없음)")
	_walk(a, Vector2.DOWN, 1.0)
	t.ok(a.loco.logical.y < 6 * 32 and a.floor_id == 1, "난간 너머로 내려서지 않는다: y %.1f" % a.loco.logical.y)
	_walk(a, Vector2.LEFT, 5.0)
	t.ok(a.floor_id == 0 and a.loco.logical.x < 2 * 32, "램프로 내려오면 땅(층 0): x %.0f 층 %d" % [a.loco.logical.x, a.floor_id])
	t.eq(a.z_index, 0, "땅의 인물은 상판 아래에 그린다")
	var b := _actor(m, _c(10, 8), 0)
	_walk(b, Vector2.UP, 2.5)
	t.ok(b.floor_id == 0 and b.loco.logical.y < 3 * 32, "층 0은 상판 아래를 지나 북쪽으로 빠진다: y %.0f 층 %d" % [b.loco.logical.y, b.floor_id])
	var c := _actor(m, _c(7, 4), 0)
	_walk(c, Vector2.LEFT, 1.5)
	t.ok(c.floor_id == 0 and c.loco.logical.x >= 6 * 32 + 9.0, "상판 그늘에서 램프 위로는 못 오른다(서서 멈춤): x %.1f" % c.loco.logical.x)
	var d := _actor(m, _c(9, 7), 0)
	_walk(d, Vector2.UP, 1.0)
	t.ok(d.loco.logical.y > 6 * 32 - 0.5, "층 0은 기둥에 막힌다: y %.1f" % d.loco.logical.y)
	for x in [a, b, c, d]:
		x.free()
	m.free()


func test_deck_blockers_and_path(t) -> void:
	var m := _map()
	var up := _actor(m, _c(8, 4), 1)
	m.blockers.append(up)
	var low := _actor(m, _c(8, 8), 0)
	_walk(low, Vector2.UP, 1.4)
	t.ok(low.loco.logical.y < 4 * 32, "다른 층 사람은 길을 막지 않는다(상판 위 사람 아래를 지나간다): y %.0f" % low.loco.logical.y)
	m.blockers.clear()
	var p := m.path(_c(10, 9), _c(11, 4), 4000, 0, 1)
	t.ok(not p.is_empty() and Array(p).any(func(q): return m.tile_of(q).x <= 2), "그늘에서 상판 위로: 램프를 돌아서 간다(%d칸)" % p.size())
	t.ok(m.path(_c(0, 4), _c(16, 4), 4000, 0, 1).is_empty(), "끊긴 경간 너머 상판에는 길이 없다")
	var q := m.path(_c(10, 9), _c(10, 1), 4000, 0)
	t.ok(not q.is_empty() and q.size() <= 10, "층 0은 상판 아래로 곧장 지난다(%d칸)" % q.size())
	var r := m.path(_c(8, 4), _c(0, 8), 4000, 1)
	t.ok(not r.is_empty() and m.tile_of(r[r.size() - 1]) == Vector2i(0, 8), "층 1에서 땅으로: 램프로 내려간다(%d칸)" % r.size())
	up.free()
	low.free()
	m.free()


func test_deck_shots_and_sight(t) -> void:
	var m := _map()
	var pj := Projectiles.new()
	pj.world = m
	var s1 := {"origin": _c(8, 4), "team": "player", "fl": 1}
	var blk := pj._blocked(_c(8, 4), _c(8, 9), s1)
	t.ok(blk.x >= 0.0 and blk.y >= 6 * 32 - 1 and blk.y < 7 * 32, "층 1 탄은 상판 끝(난간)에서 멎는다: %s" % str(blk))
	var s0 := {"origin": _c(10, 9), "team": "player", "fl": 0}
	t.eq(pj._blocked(_c(10, 9), _c(10, 1), s0), Vector2(-1, -1), "층 0 탄은 상판 아래를 지나간다")
	var bp := pj._blocked(_c(9, 9), _c(9, 1), s0)
	t.ok(bp.x >= 0.0 and bp.y >= 5 * 32 and bp.y < 6 * 32, "층 0 탄은 기둥에 막힌다: %s" % str(bp))
	var top := _actor(m, _c(11, 4), 1)
	var under := _actor(m, _c(11, 5), 0)
	var cu := Combatant.new()
	cu.actor = under
	cu.team = "enemy"
	pj.combatants = [cu]
	pj._rebucket()
	t.eq(pj._segment_hit(_c(11, 2), _c(11, 7), {"team": "player", "fl": 1}), null, "층 1 탄은 상판 아래 사람을 맞히지 않는다")
	t.ok(pj._segment_hit(_c(11, 8), _c(11, 4), {"team": "player", "fl": 0}) == cu, "같은 층(0) 탄은 맞힌다")
	t.eq(m.sight_mul(top.loco.logical, 1, under.loco.logical, 0), 0.0, "상판 위와 그 아래 그늘은 서로 못 본다")
	t.eq(m.sight_mul(top.loco.logical, 1, _c(11, 9), 0), 0.5, "상판 위와 옆 땅: 시야 거리 ×0.5")
	t.eq(m.sight_mul(top.loco.logical, 1, _c(7, 5), 1), 1.0, "같은 층은 그대로")
	t.eq(m.sight_mul(_c(4, 4), 0, _c(8, 4), 1), 1.0, "램프 위는 두 층 다로 본다")
	t.ok(m.floors_meet(_c(4, 4), 0, _c(4, 5), 1) and not m.floors_meet(_c(11, 4), 1, _c(11, 5), 0), "근접·탄: 같은 층이나 램프 위에서만 닿는다")
	top.free()
	under.free()
	pj.free()
	m.free()
