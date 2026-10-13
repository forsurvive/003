## 실내 맵 v0: 문 전환 대상(SD-19 §5.2 '실내 1곳(S-07 정문 일부) + 문 전환').
## 청크 월드와 같은 충돌 API(move_circle·is_solid·cover_at·line_of_sight·update_focus)를 가진다.
class_name InteriorRoom
extends Node2D

const W := 20
const H := 12
var tile := 32
var tileset: TileSet
var names := {}
var grid := []                               ## [y][x] atlas index
var solid := {}
var exit_tile := Vector2i(10, 11)
var entry_px := Vector2(10 * 32 + 16, 9 * 32 + 20)


func _ready() -> void:
	tileset = load("res://assets/tiles/ts_s07_int.tres")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/ts_s07_int.json"))
	for k in meta:
		names[k] = int(meta[k]["atlas"][0])
		solid[int(meta[k]["atlas"][0])] = bool(meta[k]["solid"])
	var ground := GroundLayer.new()                                  # 바닥: 재질 합성 셰이더(SD-16 §6.10)
	ground.setup("s07", Vector2i.ZERO, Vector2i(W, H))
	ground.z_index = -11
	var layer := TileMapLayer.new()
	layer.tile_set = tileset
	layer.z_index = -10
	for y in H:
		var row := []
		for x in W:
			var n := "panel"
			if y == 0:
				n = "wall_top_s"
			elif y == 1:
				n = "face_top_pipe" if x % 5 == 2 else "face_top"
			elif y == 2:
				n = "face_bot"
			elif x == 0 or x == W - 1 or (y == H - 1 and x != exit_tile.x):
				n = "wall_top"
			elif y == 3:
				n = "grate_a" if x % 2 else "grate_b"
			elif y == 7:
				n = "guide_x" if x == exit_tile.x else "guide_h"
			elif x == exit_tile.x:
				n = "guide_v"
			elif (x * 7 + y) % 6 == 0:
				n = "panel_scuff"
			row.append(names[n])
			if solid[names[n]]:                                       # 벽은 타일, 바닥은 합성 층
				layer.set_cell(Vector2i(x, y), 0, Vector2i(names[n], 0))
				ground.put(x, y, names["panel"], names[n])
			else:
				ground.put(x, y, names[n], -1)
		grid.append(row)
	ground.pad()
	ground.commit()
	add_child(ground)
	add_child(layer)
	y_sort_enabled = true


func update_focus(_p: Vector2) -> void:
	pass


func is_solid(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= W or t.y >= H:
		return t != exit_tile + Vector2i(0, 1)
	return solid.get(grid[t.y][t.x], false)


func cover_at(t: Vector2i) -> int:
	return 2 if is_solid(t) else 0


func move_circle(from: Vector2, to: Vector2, r: float) -> Vector2:
	return Sweep.move(from, to, r, _hits)


func circle_hits(c: Vector2, r: float) -> bool:
	return _hits(c, r)


func _hits(c: Vector2, r: float) -> bool:
	for ty in range(floori((c.y - r) / tile), floori((c.y + r) / tile) + 1):
		for tx in range(floori((c.x - r) / tile), floori((c.x + r) / tile) + 1):
			if is_solid(Vector2i(tx, ty)):
				var q := Vector2(clampf(c.x, tx * tile, tx * tile + tile), clampf(c.y, ty * tile, ty * tile + tile))
				if q.distance_squared_to(c) < r * r:
					return true
	return false


func line_of_sight(_a: Vector2, _b: Vector2) -> bool:
	return true
