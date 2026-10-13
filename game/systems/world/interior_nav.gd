## 실내 맵 길찾기를 적 AI(Enemy)의 경로 격자(NavGrid)와 같은 모양으로: path(a, b)는 출발점을 맨 앞에 둔 픽셀 좌표 배열.
## 한 프레임 질의 예산(NavGrid와 같은 8회)을 넘으면 빈 배열 — 적은 다음 전술 틱에 다시 묻는다.
class_name InteriorNav
extends RefCounted

var map: InteriorMap
var budget := 8
var queries_this_frame := 0


func _init(m: InteriorMap) -> void:
	map = m


func new_frame() -> void:
	queries_this_frame = 0


func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	if queries_this_frame >= budget:
		return PackedVector2Array()
	queries_this_frame += 1
	var p := map.path(a, b)
	if p.is_empty():
		if map.tile_of(a) == map.tile_of(b):
			return PackedVector2Array([a, b])
		return p
	p.insert(0, a)
	return p
