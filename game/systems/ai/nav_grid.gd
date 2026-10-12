## 격자 A* (SD-19 §6.8: 엔진 내장 격자 A* + 프레임당 4건 제한). 활성 영역(주인공 중심 3×3청크)만 갖는다.
class_name NavGrid
extends RefCounted

var astar := AStarGrid2D.new()
var origin := Vector2i.ZERO
var size := Vector2i.ZERO
var budget := 4
var query_usec_max := 0
var queries_this_frame := 0
var last_build_usec := 0


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
	# 붙은 청크의 deco 배열을 직접 훑는다(타일마다 함수 호출보다 빠르다). 붙지 않은 칸은 막힘.
	for cy in range(center_chunk.y - 1, center_chunk.y + 2):
		for cx in range(center_chunk.x - 1, center_chunk.x + 2):
			var k := Vector2i(cx, cy)
			var o := k * cs
			if not world.loaded.has(k):
				astar.fill_solid_region(Rect2i(o, Vector2i(cs, cs)), true)
				continue
			var deco: Array = world.loaded[k]["data"]["deco"]
			var solid: Dictionary = world.solid_atlas
			for i in deco.size():
				var a: int = deco[i]
				if a >= 0 and solid.get(a, false):
					astar.set_point_solid(o + Vector2i(i % cs, i / cs), true)
	last_build_usec = Time.get_ticks_usec() - t0


func new_frame() -> void:
	queries_this_frame = 0


## 경로(픽셀 좌표 배열). 이번 프레임 예산을 넘으면 빈 배열(다음 프레임에 다시 요청).
func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	if queries_this_frame >= budget:
		return PackedVector2Array()
	queries_this_frame += 1
	var ta := Vector2i(floori(a.x / 32), floori(a.y / 32))
	var tb := Vector2i(floori(b.x / 32), floori(b.y / 32))
	if not astar.is_in_boundsv(ta) or not astar.is_in_boundsv(tb):
		return PackedVector2Array()
	var t0 := Time.get_ticks_usec()
	var p := astar.get_point_path(ta, tb, true)
	query_usec_max = maxi(query_usec_max, Time.get_ticks_usec() - t0)
	return p
