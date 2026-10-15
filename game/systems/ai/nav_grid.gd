## 격자 A* (SD-19 §6.8: 엔진 내장 격자 A* + 프레임당 4건 제한). 활성 영역(주인공 중심 3×3청크)만 갖는다.
## 2단 경로(T8, 대응 사다리 ①): 체비셰프 거리 FAR 타일 이하는 타일 격자 그대로. 그보다 멀면 4×4타일 거친 격자에서
## 길을 잡고, 그 길의 LEAD칸 앞 지점까지만 타일 격자로 다듬는다(부분 경로 허용). 적은 0.5초마다 다시 묻으므로
## 남은 구간은 다음 전술 틱이 잇는다. 거친 칸은 막힌 타일이 COARSE_BLOCK개 이상이면 막힘.
class_name NavGrid
extends RefCounted

var astar := AStarGrid2D.new()
var origin := Vector2i.ZERO
var size := Vector2i.ZERO
var budget := 4
var query_usec_max := 0
var queries_this_frame := 0
var last_build_usec := 0
const FAR := 32
const CELL := 4
const LEAD := 3
const COARSE_BLOCK := 11                      ## 16칸 중 11칸 이상 막히면 지나갈 수 없는 칸으로 본다
var coarse := AStarGrid2D.new()
var coarse_queries := 0


func rebuild(world, center_chunk: Vector2i, cs: int) -> void:
	var t0 := Time.get_ticks_usec()
	origin = (center_chunk - Vector2i(1, 1)) * cs
	size = Vector2i(cs * 3, cs * 3)
	astar.region = Rect2i(origin, size)
	astar.cell_size = Vector2(32, 32)
	astar.offset = Vector2(16, 16)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.jumping_enabled = true                                  # 점프 탐색: 열린 비탈에서 탐색 칸 수를 크게 줄인다
	astar.update()
	var nc := size / CELL
	var blocked := PackedInt32Array()
	blocked.resize(nc.x * nc.y)
	# 붙은 청크의 deco 배열을 직접 훑는다(타일마다 함수 호출보다 빠르다). 붙지 않은 칸은 막힘.
	for cy in range(center_chunk.y - 1, center_chunk.y + 2):
		for cx in range(center_chunk.x - 1, center_chunk.x + 2):
			var k := Vector2i(cx, cy)
			var o := k * cs
			var lo := (o - origin) / CELL
			if not world.loaded.has(k):
				astar.fill_solid_region(Rect2i(o, Vector2i(cs, cs)), true)
				for yy in cs / CELL:
					for xx in cs / CELL:
						blocked[(lo.y + yy) * nc.x + lo.x + xx] = CELL * CELL
				continue
			var deco: Array = world.loaded[k]["data"]["deco"]
			var solid: Dictionary = world.solid_atlas
			for i in deco.size():
				var a: int = deco[i]
				if a >= 0 and solid.get(a, false):
					var tx := i % cs
					var ty := i / cs
					astar.set_point_solid(o + Vector2i(tx, ty), true)
					blocked[(lo.y + ty / CELL) * nc.x + lo.x + tx / CELL] += 1
	coarse.region = Rect2i(origin / CELL, nc)
	coarse.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	coarse.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	coarse.update()
	for i in blocked.size():
		if blocked[i] >= COARSE_BLOCK:
			coarse.set_point_solid(origin / CELL + Vector2i(i % nc.x, i / nc.x), true)
	last_build_usec = Time.get_ticks_usec() - t0


func new_frame() -> void:
	queries_this_frame = 0


## 경로(픽셀 좌표 배열). 이번 프레임 예산을 넘으면 빈 배열(다음 프레임에 다시 요청).
func path(a: Vector2, b: Vector2, _fl: int = 0, _goal_fl: int = -1) -> PackedVector2Array:
	if queries_this_frame >= budget:
		return PackedVector2Array()
	queries_this_frame += 1
	var ta := Vector2i(floori(a.x / 32), floori(a.y / 32))
	var tb := Vector2i(floori(b.x / 32), floori(b.y / 32))
	if not astar.is_in_boundsv(ta) or not astar.is_in_boundsv(tb):
		return PackedVector2Array()
	var t0 := Time.get_ticks_usec()
	var p: PackedVector2Array
	var far := maxi(absi(ta.x - tb.x), absi(ta.y - tb.y)) > FAR
	if far:
		var wp := _coarse_waypoint(ta, tb)
		p = astar.get_point_path(ta, wp if wp.x > -999 else tb, true)
	else:
		p = astar.get_point_path(ta, tb, true)
	var us := Time.get_ticks_usec() - t0
	query_usec_max = maxi(query_usec_max, us)
	if Enemy.profiling:
		Enemy.prof["n_path"] += 1
		Enemy.prof["path"] += us
	return p


## 먼 목표: 거친 격자 길의 LEAD칸 앞 거친 칸에서 가운데에 가장 가까운 열린 타일. 길이 없으면 (-999, -999).
func _coarse_waypoint(ta: Vector2i, tb: Vector2i) -> Vector2i:
	coarse_queries += 1
	var ca := Vector2i(floori(ta.x / float(CELL)), floori(ta.y / float(CELL)))
	var cb := Vector2i(floori(tb.x / float(CELL)), floori(tb.y / float(CELL)))
	if not coarse.is_in_boundsv(ca) or not coarse.is_in_boundsv(cb):
		return Vector2i(-999, -999)
	var cp := coarse.get_id_path(ca, cb, true)
	if cp.size() < 2:
		return Vector2i(-999, -999)
	var c: Vector2i = cp[mini(LEAD, cp.size() - 1)]
	var best := Vector2i(-999, -999)
	var bd := 1 << 30
	var mid := c * CELL + Vector2i(CELL / 2, CELL / 2)
	for y in CELL:
		for x in CELL:
			var t := c * CELL + Vector2i(x, y)
			if astar.is_in_boundsv(t) and not astar.is_point_solid(t):
				var d := (t - mid).length_squared()
				if d < bd:
					bd = d
					best = t
	return best
