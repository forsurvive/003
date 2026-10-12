## 심리스 청크 스트리밍 v0 (SD-19 §6.5, SD-08 §3.8).
## 활성 3×3(AI·이벤트) · 사전 로드 5×5(타일만) · 7×7 밖 해제. 청크 파일 읽기·해석은 작업 스레드,
## 본 스레드는 한 프레임에 1청크만 붙인다(끊김 예산: 붙이기 1회 4ms 이하, 측정 항목 5).
## 충돌은 물리 엔진이 아니라 자체 충돌 격자(타일 solid·cover)로 판정한다(SD-19 §6.8).
class_name ChunkWorld
extends Node2D

signal chunk_attached(id: String, usec: int)
signal chunk_detached(id: String)

const DATA := "res://data/chunks/"
var index: Dictionary
var cs: int                                  ## 청크 크기(타일)
var tile := 32
var tileset: TileSet
var solid_atlas := {}                        ## atlas x -> true
var cover_of := {}                           ## atlas x -> 0/1/2
var loaded := {}                             ## Vector2i -> {"ground": TileMapLayer, "deco": TileMapLayer, "data": Dictionary}
var _pending := {}                           ## Vector2i -> task id
var _ready_q: Array = []                     ## [Vector2i, Dictionary] parsed on worker threads
var _mutex := Mutex.new()
var focus := Vector2i(-999, -999)
var attach_usec_max := 0
var attach_count := 0
var objects: Array = []                      ## 붙은 청크의 오브젝트(문 등), 월드 타일 좌표


func _ready() -> void:
	index = JSON.parse_string(FileAccess.get_file_as_string(DATA + "_index.json"))
	cs = int(index["chunk_size"])
	tile = int(index["tile"])
	tileset = load("res://assets/tiles/ts_r01_ext.tres")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/ts_r01_ext.json"))
	for k in meta:
		var ax := int(meta[k]["atlas"][0])
		solid_atlas[ax] = bool(meta[k]["solid"])
		cover_of[ax] = int(meta[k]["cover"])


func chunk_of_px(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / (cs * tile)), floori(p.y / (cs * tile)))


func in_world(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < int(index["chunks"][0]) and c.y < int(index["chunks"][1])


## 매 프레임 주인공 위치로 부른다.
func update_focus(p: Vector2) -> void:
	var c := chunk_of_px(p)
	if c != focus:
		focus = c
		for dy in range(-2, 3):
			for dx in range(-2, 3):                                     # 5×5 사전 로드 요청
				var k := c + Vector2i(dx, dy)
				if in_world(k) and not loaded.has(k) and not _pending.has(k):
					_pending[k] = WorkerThreadPool.add_task(_load_task.bind(k))
		for k in loaded.keys():                                         # 7×7 밖 해제
			if absi(k.x - c.x) > 3 or absi(k.y - c.y) > 3:
				_detach(k)
	_attach_one()


func _load_task(k: Vector2i) -> void:
	var id := "C-%02d-%02d" % [k.x, k.y]
	var data = JSON.parse_string(FileAccess.get_file_as_string(DATA + id + ".json"))
	_mutex.lock()
	_ready_q.append([k, data])
	_mutex.unlock()


func _attach_one() -> void:
	_mutex.lock()
	var item = _ready_q.pop_front() if not _ready_q.is_empty() else null
	_mutex.unlock()
	if item == null:
		return
	var k: Vector2i = item[0]
	var data: Dictionary = item[1]
	WorkerThreadPool.wait_for_task_completion(_pending[k])
	_pending.erase(k)
	if absi(k.x - focus.x) > 3 or absi(k.y - focus.y) > 3:
		return                                                           # player moved away meanwhile
	var t0 := Time.get_ticks_usec()
	var g := TileMapLayer.new()
	var d := TileMapLayer.new()
	g.tile_set = tileset
	d.tile_set = tileset
	var o := Vector2i(int(data["origin"][0]), int(data["origin"][1]))
	var ground: Array = data["ground"]
	var deco: Array = data["deco"]
	for y in cs:
		for x in cs:
			var i := y * cs + x
			g.set_cell(o + Vector2i(x, y), 0, Vector2i(int(ground[i]), 0))
			if int(deco[i]) >= 0:
				d.set_cell(o + Vector2i(x, y), 0, Vector2i(int(deco[i]), 0))
	g.z_index = -10
	d.y_sort_enabled = false
	add_child(g)
	add_child(d)
	loaded[k] = {"ground": g, "deco": d, "data": data}
	for ob in data.get("objects", []):
		objects.append(ob)
	var us := Time.get_ticks_usec() - t0
	attach_usec_max = maxi(attach_usec_max, us)
	attach_count += 1
	chunk_attached.emit(data["id"], us)


## 순간 이동·불러오기용: p 둘레 3×3을 지금 붙인다(끊김을 감수하는 경로 — 화면이 페이드로 가려질 때만 쓴다).
func load_now(p: Vector2) -> void:
	update_focus(p)
	var c := chunk_of_px(p)
	var t_end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < t_end:
		var missing := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var k := c + Vector2i(dx, dy)
				if in_world(k) and not loaded.has(k):
					missing = true
		if not missing:
			return
		_attach_one()
		OS.delay_msec(1)


func _detach(k: Vector2i) -> void:
	var c: Dictionary = loaded[k]
	c["ground"].queue_free()
	c["deco"].queue_free()
	for ob in c["data"].get("objects", []):
		objects.erase(ob)
	loaded.erase(k)
	chunk_detached.emit(c["data"]["id"])


## 타일 좌표의 deco atlas(없으면 -1). 붙지 않은 청크는 막힌 것으로 본다(밖으로 새지 않게).
func deco_at(t: Vector2i) -> int:
	var k := Vector2i(floori(float(t.x) / cs), floori(float(t.y) / cs))
	if not loaded.has(k):
		return -2
	var c: Dictionary = loaded[k]
	var o := Vector2i(int(c["data"]["origin"][0]), int(c["data"]["origin"][1]))
	return int(c["data"]["deco"][(t.y - o.y) * cs + (t.x - o.x)])


func is_solid(t: Vector2i) -> bool:
	var a := deco_at(t)
	return a == -2 or (a >= 0 and solid_atlas.get(a, false))


func cover_at(t: Vector2i) -> int:
	var a := deco_at(t)
	return 2 if a == -2 else (cover_of.get(a, 0) if a >= 0 else 0)


## 원형 충돌체(반지름 r px)를 축 분리로 옮긴다. 도착점 반환. Locomotion.step의 blocked 콜백.
func move_circle(from: Vector2, to: Vector2, r: float) -> Vector2:
	var p := from
	var tx := Vector2(to.x, p.y)
	if not _circle_hits(tx, r):
		p = tx
	var ty := Vector2(p.x, to.y)
	if not _circle_hits(ty, r):
		p = ty
	return p


func _circle_hits(c: Vector2, r: float) -> bool:
	var x0 := floori((c.x - r) / tile)
	var x1 := floori((c.x + r) / tile)
	var y0 := floori((c.y - r) / tile)
	var y1 := floori((c.y + r) / tile)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if is_solid(Vector2i(tx, ty)):
				var cx := clampf(c.x, tx * tile, tx * tile + tile)
				var cy := clampf(c.y, ty * tile, ty * tile + tile)
				if Vector2(cx, cy).distance_squared_to(c) < r * r:
					return true
	return false


## 시선 판정: 충돌 격자 위 브레젠험 선(높은 엄폐만 막는다, SD-11 §4.2·§14.3)
func line_of_sight(a: Vector2, b: Vector2) -> bool:
	var p0 := Vector2i(floori(a.x / tile), floori(a.y / tile))
	var p1 := Vector2i(floori(b.x / tile), floori(b.y / tile))
	var dx := absi(p1.x - p0.x)
	var dy := -absi(p1.y - p0.y)
	var sx := 1 if p0.x < p1.x else -1
	var sy := 1 if p0.y < p1.y else -1
	var err := dx + dy
	var p := p0
	while true:
		if p != p0 and p != p1 and cover_at(p) >= 2:
			return false
		if p == p1:
			return true
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			p.x += sx
		if e2 <= dx:
			err += dx
			p.y += sy
	return true
