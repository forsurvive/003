## 실내 맵 v1 (단계 0-5): 맵 변환기(tools/pipeline/map_compile.py)가 만든 data/maps/<ID>.json을 그린다.
## 층: 바닥 합성(GroundLayer, z -11) · 벽 자동 타일(ts_s07_wall, z -10) · 물건 층(y 정렬: 소품·문·문패·인물).
## 청크 월드·InteriorRoom과 같은 충돌 API(move_circle·circle_hits·is_solid·cover_at·line_of_sight·update_focus)라
## Actor·이벤트 실행기가 그대로 쓴다. 문은 인물이 가까이 오면 열리고(잠긴 문은 막힌 채), 출구·조사 글은 칸으로 찾는다.
class_name InteriorMap
extends Node2D

const T := 32
const DOOR_NEAR := 44.0                          ## 문 아래 칸 가운데에서 이 거리 안에 인물이 있으면 열린다

var id := ""
var data: Dictionary
var size := Vector2i.ZERO
var solid := PackedByteArray()                   ## [y * w + x] 1 = 막힘(벽·소품·잠긴 문)
var cover := PackedByteArray()                   ## [y * w + x] 엄폐(SD-11 §4.2): 2 높음(벽·키 큰 소품, 탄·시선을 막는다) · 1 낮음 · 0 없음
var objects: Node2D                              ## y 정렬 층(소품·문·인물이 같은 층에서 앞뒤를 가린다)
var doors: Array = []                            ## [{"node": Sprite2D, "x", "y", "locked", "closed": Rect2, "open": Rect2, "is_open"}]
var exits := {}                                  ## Vector2i -> {"to", "mark"}
var texts := {}                                  ## Vector2i -> 글
var boxes := {}                                  ## Vector2i -> 용기(0-9): {"x","y","w","h","kind","owner","lock","name","cond"} — 조건은 조사할 때 본다
var text_meta := {}                              ## Vector2i -> {"cond", "seq": [글…], "scene", "key"} — 여러 번 조사하는 글(0-7)
var marks := {}
var actors: Array = []                           ## 문을 여는 인물(주인공·NPC)
var props: Array = []                            ## [{"name", "x", "y", "w", "h", "node"}] — 연출이 상태 그림을 바꾼다
var blockers: Array = []                         ## 길을 막는 인물(맵 NPC, 쯔꾸르식): 움직이는 본인은 빼고 원으로 막는다
const BLOCK_R := 8.0
var _mover := Vector2.INF
static var prop_meta: Dictionary
static var prop_tex: Texture2D
static var _tile_ids := {}


static func _load_static() -> void:
	if prop_meta.is_empty():
		prop_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/s07_props.json"))["props"]
		prop_tex = load("res://assets/props/s07_props.png")
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/ts_s07_int.json"))
		for k in m:
			_tile_ids[k] = int(m[k]["atlas"][0])


static func exists(map_id: String) -> bool:
	return FileAccess.file_exists("res://data/maps/%s.json" % map_id)


## st가 있으면 소품·문패의 cond(시대·퀘스트)를 보고 고른다. 없으면 조건부 소품은 모두 뺀다(미리보기·시험)
func load_map(map_id: String, st: StoryState = null) -> void:
	_load_static()
	id = map_id
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	size = Vector2i(int(data["size"][0]), int(data["size"][1]))
	marks = data["marks"]
	var ground := GroundLayer.new()                                  # 바닥: 재질 합성 셰이더(SD-16 §6.10)
	ground.setup(data["set"], Vector2i.ZERO, size)
	ground.z_index = -11
	var walls := TileMapLayer.new()
	walls.tile_set = load("res://assets/tiles/ts_%s_wall.tres" % data["set"])
	walls.z_index = -10
	var wall_deco: int = _tile_ids["wall_top"]                       # 바닥 합성에 '벽에 덮인 칸'(덮개 1)을 알리는 타일
	solid.resize(size.x * size.y)
	cover.resize(size.x * size.y)
	for y in size.y:
		var srow: String = data["solid"][y]
		for x in size.x:
			var w: int = int(data["wall"][y][x])
			ground.put(x, y, int(data["floor"][y][x]), wall_deco if w >= 0 else -1)
			if w >= 0:
				walls.set_cell(Vector2i(x, y), 0, Vector2i(w, 0))
			solid[y * size.x + x] = 1 if srow[x] == "1" else 0
			cover[y * size.x + x] = 2 if w >= 0 else (1 if srow[x] == "1" else 0)
	ground.pad()
	ground.commit()
	add_child(ground)
	add_child(walls)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	for p in data["props"]:
		if not _cond_ok(p.get("cond", ""), st):
			continue
		for c in p.get("cells", []):
			solid[int(c[1]) * size.x + int(c[0])] = 1                       # 조건부 소품의 발 칸
		var e: Dictionary = prop_meta[p["name"]]
		var rect: Array = e["frames"][0] if e.has("frames") else e["rect"]
		var tall: bool = int(rect[3]) - int(e["foot"][1]) * T > 24          # 발 칸 위로 24px 넘게 서는 소품(사물함·선반) = 높은 엄폐
		var fx := int(p["x"])
		var fy := int(p["y"])
		for yy in range(fy, fy + maxi(1, int(e["foot"][1]))):
			for xx in range(fx, fx + maxi(1, int(e["foot"][0]))):
				if xx >= 0 and yy >= 0 and xx < size.x and yy < size.y and solid[yy * size.x + xx] == 1:
					cover[yy * size.x + xx] = 2 if tall else 1
		var node := _sprite(rect, Vector2(p["px"][0], p["px"][1]), float(p["sort_y"]))
		props.append({"name": p["name"], "x": int(p["x"]), "y": int(p["y"]), "w": maxi(1, int(e["foot"][0])),
			"h": maxi(1, int(e["foot"][1])), "node": node})
	for d in data["doors"]:
		var e: Dictionary = prop_meta[d["kind"]]
		var pos := Vector2(int(d["x"]) * T + int(e["off"][0]), int(d["y"]) * T + int(e["off"][1]))
		var s := _sprite(e["rect"], pos, (int(d["y"]) + 2) * T)
		doors.append({"node": s, "x": int(d["x"]), "y": int(d["y"]), "locked": bool(d["locked"]), "is_open": false,
			"closed": _r(e["rect"]), "open": _r(e.get("open", e["rect"]))})
		if d["locked"]:
			texts[Vector2i(int(d["x"]), int(d["y"]) + 1)] = "잠겨 있다."
	for s in data["signs"]:
		if not _cond_ok(s.get("cond", ""), st):
			continue
		var plate := SignPlate.new()
		plate.text = s["text"]
		plate.position = Vector2(int(s["x"]) * T + 16, (int(s["y"]) + 2) * T)
		plate.lift = 2 * T - 2
		objects.add_child(plate)
	for b in data.get("boxes", []):
		for j in int(b["h"]):
			for i in int(b["w"]):
				boxes[Vector2i(int(b["x"]) + i, int(b["y"]) + j)] = b
	for e in data["exits"]:
		exits[Vector2i(int(e["x"]), int(e["y"]))] = {"to": e["to"], "mark": e["mark"]}
	for t in data["texts"]:
		var live := _cond_ok(t.get("cond", ""), st)
		var staged: bool = t.has("scene") or t.has("seq")              # 장면이 달린 글: 조건은 조사하는 순간에 본다(무기고를 연 뒤의 총기 거치대 등, 0-9)
		if not live and not staged:
			continue
		for j in int(t["h"]):
			for i in int(t["w"]):
				var c := Vector2i(int(t["x"]) + i, int(t["y"]) + j)
				var plain: String = texts.get(c, "")
				if live or not texts.has(c):
					texts[c] = t["text"]
				if staged or t.has("cond"):
					text_meta[c] = {"cond": t.get("cond", ""), "seq": t.get("seq", []), "scene": t.get("scene", ""),
						"key": "%s:%d,%d" % [map_id, int(t["x"]), int(t["y"])], "plain": plain}


static func _cond_ok(cond: String, st: StoryState) -> bool:
	if cond == "":
		return true
	return st != null and StoryExpr.test(cond, st)


## 이 칸을 덮는 밟는 칸(trigger) 목록
func triggers_at(t: Vector2i) -> Array:
	var out := []
	for g in data.get("triggers", []):
		if t.x >= int(g["x"]) and t.x < int(g["x"]) + int(g["w"]) and t.y >= int(g["y"]) and t.y < int(g["y"]) + int(g["h"]):
			out.append(g)
	return out


func _r(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])


## 소품 하나: 노드 위치 = 정렬 기준(발 칸 아래 변), 그림은 오프셋으로 놓는다
func _sprite(rect: Array, top_left: Vector2, sort_y: float) -> Sprite2D:
	var s := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = prop_tex
	at.region = _r(rect)
	s.texture = at
	s.centered = false
	s.position = Vector2(top_left.x, sort_y)
	s.offset = Vector2(0, top_left.y - sort_y)
	objects.add_child(s)
	return s


## 연출: 이 칸(또는 위·아래 칸)에 있는 소품을 상태 그림으로 바꾼다(state "" = 기본 그림). 바꾼 소품 이름, 없으면 ""
func set_prop_state(cell: Vector2i, state: String) -> String:
	for c in [cell, cell + Vector2i(0, -1), cell + Vector2i(0, 1)]:
		for p in props:
			var e: Dictionary = prop_meta[p["name"]]
			if c.x >= p["x"] and c.x < p["x"] + p["w"] and c.y >= p["y"] and c.y < p["y"] + p["h"]:
				if state != "" and not e.get("states", {}).has(state):
					continue
				var rect: Array = e["states"][state] if state != "" else e["rect"]
				(p["node"].texture as AtlasTexture).region = _r(rect)
				return p["name"]
	return ""


## 톱니 방폭문(V-00, 단계 0-9 개방식): k 0 닫힘 → 1 열림. 문은 오른쪽으로 210px 굴러가며 컷마다 정확히 10px·거리/반지름만큼 돈다
## (그림이 그 각도로 구워져 있어 미끄러지지 않는다 — props_s07.GEAR_FRAMES). 빈 구멍에는 바깥의 흰 빛과 바닥에 번지는 빛줄기.
const GATE_ROLL := 210.0
const GATE_C := Vector2(128, 108)                 ## 문틀 그림 안 구멍 중심(픽셀 경계 좌표, art/tools/tiles_s07.GATE_C 127.5 + 0.5)
const GATE_R := 97.0                              ## 구멍 반지름(tiles_s07.GATE_R)
var gate_k := 0.0
var _gate_light: Node2D


func set_gate(k: float) -> void:
	gate_k = clampf(k, 0.0, 1.0)
	var door: Dictionary = {}
	var frame: Dictionary = {}
	for p in props:
		if p["name"] == "gear_door":
			door = p
		elif p["name"] == "gear_frame":
			frame = p
	if door.is_empty():
		return
	var fr: Array = prop_meta["gear_door"]["frames"]
	var f := int(round(gate_k * (fr.size() - 1)))
	var node: Sprite2D = door["node"]
	(node.texture as AtlasTexture).region = _r(fr[f])
	if not door.has("x0"):
		door["x0"] = node.position.x
	node.position.x = float(door["x0"]) + roundf(GATE_ROLL * f / float(fr.size() - 1))   # 컷과 같은 거리만(미끄러짐 없음)
	if not frame.is_empty():
		set_prop_frame("gear_frame", 1 if gate_k > 0.0 else 0)                 # 열린 구멍 = 문틀 그림의 열림 컷(흰 빛이 테 안쪽에 정확히 맞는다)
	if _gate_light == null and not frame.is_empty():
		_gate_light = Node2D.new()
		_gate_light.draw.connect(_draw_gate_light.bind(node))
		(frame["node"] as Node2D).add_child(_gate_light)                       # 문틀 바로 위·문 아래에 그린다
		var fn: Sprite2D = frame["node"]
		_gate_light.position = -fn.position
		var top_left := fn.position + fn.offset + Vector2.ONE                 # 아틀라스 테두리 1px 안쪽 = 그림 왼쪽 위
		_gate_light.set_meta("c", top_left + GATE_C)
	if _gate_light != null:
		_gate_light.queue_redraw()


func _draw_gate_light(_door: Sprite2D) -> void:
	if gate_k <= 0.0:
		return
	var c: Vector2 = _gate_light.get_meta("c")
	var k := gate_k
	var pale := Color("CBC5B9")
	var pale2 := Color("ABA49A")
	var reach := 220.0 * k                                                    # 바닥 빛줄기: 문이 열린 만큼 앞으로 번진다. 단색 면 없이 디더 밀도로만
	var top := c.y + 96.0                                                     # (구멍 아래 끝 = 데크 첫 줄)
	var y0 := int(top)
	while float(y0) < top + reach:
		var t := (float(y0) - top) / maxf(1.0, reach)
		var hw := 44.0 + 96.0 * t
		var row := (y0 - int(top)) / 2
		var every := 2 if t < 0.2 else (3 if t < 0.45 else (4 if t < 0.75 else 6))   # 2칸마다 1 → 6칸마다 1
		var col := pale if t < 0.45 else pale2
		if row % (1 if every <= 2 else 2) == 0:
			var x := int(c.x - hw) + (row % every) * 2
			while x < int(c.x + hw):
				_gate_light.draw_rect(Rect2(Vector2(x, y0), Vector2(2, 2)), col)
				x += every * 2
		y0 += 2


## 컷이 여럿인 소품의 컷을 바꾼다(원형 철문 등, 연출 명령 anim, 0-9). 맵에 그 이름 소품이 없으면 false
func set_prop_frame(name: String, f: int) -> bool:
	var e: Dictionary = prop_meta.get(name, {})
	if not e.has("frames"):
		return false
	for p in props:
		if p["name"] == name:
			var fr: Array = e["frames"]
			(p["node"].texture as AtlasTexture).region = _r(fr[clampi(f, 0, fr.size() - 1)])
			p["frame"] = f
			return true
	return false


func unlock_door(x: int, y: int) -> bool:
	for d in doors:
		if int(d["x"]) == x and int(d["y"]) == y:
			d["locked"] = false
			for yy in [y, y + 1]:
				solid[yy * size.x + x] = 0
			texts.erase(Vector2i(x, y + 1))
			return true
	return false


func add_actor(a: Node2D) -> void:
	objects.add_child(a)
	actors.append(a)


func remove_actor(a: Node2D) -> void:
	actors.erase(a)


func mark_pos(name: String) -> Vector2:
	var m: Array = marks.get(name, [1, 1, "S"])
	return Vector2(int(m[0]) * T + 16, int(m[1]) * T + 16)


func mark_dir(name: String) -> String:
	return str(marks.get(name, [0, 0, "S"])[2])


func tile_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / T), floori(p.y / T))


func exit_at(t: Vector2i) -> Dictionary:
	return exits.get(t, {})


func _process(_dt: float) -> void:
	for d in doors:                                                 # 가까이 오면 열리고 멀어지면 닫힌다(잠긴 문은 그대로)
		if d["locked"]:
			continue
		var c := Vector2(int(d["x"]) * T + 16, (int(d["y"]) + 2) * T + 8)
		var near := false
		for a in actors:
			if is_instance_valid(a) and (a.position.distance_to(c) < DOOR_NEAR or a.position.distance_to(c - Vector2(0, 3 * T)) < DOOR_NEAR):
				near = true
				break
		if near != d["is_open"]:
			d["is_open"] = near
			(d["node"].texture as AtlasTexture).region = d["open"] if near else d["closed"]


# ---------------------------------------------------------------- 충돌 API(ChunkWorld·InteriorRoom과 같다)
func update_focus(_p: Vector2) -> void:
	pass


func is_solid(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
		return true
	return solid[t.y * size.x + t.x] == 1


func cover_at(t: Vector2i) -> int:
	if t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
		return 2
	return cover[t.y * size.x + t.x]


func move_circle(from: Vector2, to: Vector2, r: float) -> Vector2:
	_mover = from
	var out := Sweep.move(from, to, r, _hits)
	_mover = Vector2.INF
	return out


func circle_hits(c: Vector2, r: float) -> bool:
	return _hits(c, r)


func _hits(c: Vector2, r: float) -> bool:
	for ty in range(floori((c.y - r) / T), floori((c.y + r) / T) + 1):
		for tx in range(floori((c.x - r) / T), floori((c.x + r) / T) + 1):
			if is_solid(Vector2i(tx, ty)):
				var q := Vector2(clampf(c.x, tx * T, tx * T + T), clampf(c.y, ty * T, ty * T + T))
				if q.distance_squared_to(c) < r * r:
					return true
	for b in blockers:
		if is_instance_valid(b) and b.visible:
			var bp: Vector2 = b.loco.logical
			if bp.distance_to(_mover) > 0.5 and bp.distance_to(c) < r + BLOCK_R:
				return true
	return false


## 막는 인물이 선 칸(길찾기가 돌아가게)
func _occupied(except: Vector2i) -> Dictionary:
	var occ := {}
	for b in blockers:
		if is_instance_valid(b) and b.visible:
			var t := tile_of(b.loco.logical)
			if t != except:
				occ[t] = true
	return occ


## 시선: 칸 격자 위 브레젠험 선, 높은 엄폐(벽·키 큰 소품)만 막는다(SD-11 §4.2·§14.3, ChunkWorld와 같은 규칙).
## low_blocks: 웅크린 대상을 볼 때 — 낮은 엄폐도 시야를 막는다(§4.2 '웅크린 대상 차단')
func line_of_sight(a: Vector2, b: Vector2, low_blocks: bool = false) -> bool:
	var p0 := tile_of(a)
	var p1 := tile_of(b)
	var dx := absi(p1.x - p0.x)
	var dy := -absi(p1.y - p0.y)
	var sx := 1 if p0.x < p1.x else -1
	var sy := 1 if p0.y < p1.y else -1
	var err := dx + dy
	var p := p0
	while true:
		if p != p0 and p != p1 and cover_at(p) >= (1 if low_blocks else 2):
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


## 칸 단위 길찾기(8방향, 모서리 끼어 지나가기 없음). 돌려줌: 칸 가운데 점들(시작 칸 제외), 못 가면 빈 배열
func path(a: Vector2, b: Vector2, max_nodes: int = 4000) -> PackedVector2Array:
	var s := tile_of(a)
	var g := tile_of(b)
	var out := PackedVector2Array()
	if is_solid(g) or s == g:
		return out
	var occ := _occupied(s)
	occ.erase(g)
	var came := {s: s}
	var cost := {s: 0.0}
	var open: Array = [[0.0, s]]
	var n := 0
	while not open.is_empty() and n < max_nodes:
		n += 1
		var best := 0
		for i in open.size():
			if open[i][0] < open[best][0]:
				best = i
		var cur: Vector2i = open[best][1]
		open.remove_at(best)
		if cur == g:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var nx: Vector2i = cur + d
			if is_solid(nx) or occ.has(nx):
				continue
			if d.x != 0 and d.y != 0 and (is_solid(Vector2i(cur.x + d.x, cur.y)) or is_solid(Vector2i(cur.x, cur.y + d.y))):
				continue
			var c: float = cost[cur] + (1.414 if d.x != 0 and d.y != 0 else 1.0)
			if not cost.has(nx) or c < cost[nx]:
				cost[nx] = c
				came[nx] = cur
				open.append([c + Vector2(nx - g).length(), nx])
	if not came.has(g):
		return out
	var t := g
	var rev: Array[Vector2i] = []
	while t != s:
		rev.append(t)
		t = came[t]
	rev.reverse()
	for c in rev:
		out.append(Vector2(c.x * T + 16, c.y * T + 16))
	return out
