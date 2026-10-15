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
var text_fx := {}                                 ## 조사 글 효과(1-W 소장소 쪽지): 칸 → "reveal_near"(읽으면 가까운 장소 하나를 지도에 표시)
var gos := {}                                    ## Vector2i -> 들어가는 문(1-5e 월드 건물 1층 문: {"to", "mark", "name", "lock", "at"})
var terms := {}                                  ## Vector2i -> 단말(1-4): {"x","y","w","h","id","cond"}
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
static var prop_texs := {}                       ## 아틀라스 이름 -> 그림(s07 실내 · r01 바깥, 0-10)
static var _tile_ids := {}
var ext := false                                 ## 바깥 맵(0-10): 높이 칸·구조물 층
var level := PackedInt32Array()                  ## [y * w + x] 걷는 칸의 높이(타일 단위), 막힌 칸 -1
var stair := PackedByteArray()                   ## [y * w + x] 1 = 계단·사다리(높이가 다른 칸을 잇는다)
## 고가 상판 층(1-Rd, SD-21 §6.1~6.2 · SD-16 §6.5 '층 ID 0 지면 · 1 고가 상판'): 칸마다 상판 부호. 지형 높이(level)와 따로,
## 한 칸에 '땅(층 0)'과 '상판(층 1)'이 겹친다. 층은 램프·비상계단 칸에서만 바뀐다. 인물·탄은 저마다 층을 가진다.
const DK_NONE := 0
const DK_DECK := 1                               ## 상판: 층 1이 걷는다 · 층 0은 그 아래(그늘)를 걷는다
const DK_RAIL := 2                               ## 상판 가장자리 난간: 층 1 막힘 · 아래는 지나간다
const DK_RAMP := 3                               ## 램프 노면: 층 0 ↔ 1을 잇는다(아래 끝은 땅, 위 끝은 상판)
const DK_WALL := 4                               ## 램프 옆벽·옹벽: 두 층 다 막힘
const DK_PILLAR := 5                             ## 기둥 위 상판: 층 1 상판 · 층 0 막힘(높은 엄폐)
const DK_BROKEN := 6                             ## 끊긴 경간 끝 상판: 층 1이 걷되 다음 칸이 비어 거기서 선다(낙하 없음)
const DK_STAIR := 7                              ## 비상계단: 램프와 같은 규칙(걷는 사람 지름길)
const DK_JUNK := 8                               ## 상판 위 버려진 차: 층 1 막힘·엄폐 · 아래(층 0)는 그늘
var deck := PackedByteArray()                    ## [y * w + x] 상판 부호(손 맵·시험). 빈 배열 = 상판 없음. 월드는 청크 자료에서 읽는다
var has_deck := false
var mover_floor := 0                             ## move_circle·circle_hits를 부르는 인물의 층(Actor가 부르기 전에 맞춘다)


static func _load_static() -> void:
	if prop_meta.is_empty():
		prop_meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/s07_props.json"))["props"]
		prop_tex = load("res://assets/props/s07_props.png")
		prop_texs["s07"] = prop_tex
		if FileAccess.file_exists("res://assets/props/r01_props.json"):
			var r: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/r01_props.json"))["props"]
			for k in r:
				prop_meta[k] = r[k]
			prop_texs["r01"] = load("res://assets/props/r01_props.png")
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
	ext = bool(data.get("ext", false))
	var ground := GroundLayer.new()                                  # 바닥: 재질 합성 셰이더(SD-16 §6.10)
	ground.setup("r01" if ext else "s07", Vector2i.ZERO, size)
	ground.z_index = -11
	solid.resize(size.x * size.y)
	cover.resize(size.x * size.y)
	if ext:                                                          # 바깥(0-10): 덮개·엄폐·높이를 자료에서 바로, 구조물은 구운 한 장
		level.resize(size.x * size.y)
		stair.resize(size.x * size.y)
		for y in size.y:
			var srow: String = data["solid"][y]
			var grow: String = data["gflag"][y]
			var crow: String = data["cover"][y]
			var lrow: String = data["level"][y]
			var trow: String = data["stair"][y]
			for x in size.x:
				var i := y * size.x + x
				ground.put_flag(x, y, int(data["floor"][y][x]), int(grow[x]))
				solid[i] = 1 if srow[x] == "1" else 0
				cover[i] = int(crow[x])
				level[i] = -1 if lrow[x] == "." else int(lrow[x])
				stair[i] = 1 if trow[x] == "1" else 0
		ground.pad()
		ground.commit()
		add_child(ground)
		var sp := "res://assets/maps/%s_struct.png" % map_id
		if ResourceLoader.exists(sp):
			var st_spr := Sprite2D.new()
			st_spr.texture = load(sp)
			st_spr.centered = false
			st_spr.z_index = -10
			st_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(st_spr)
	else:
		var walls := TileMapLayer.new()
		walls.tile_set = load("res://assets/tiles/ts_%s_wall.tres" % data["set"])
		walls.z_index = -10
		var wall_deco: int = _tile_ids["wall_top"]                   # 바닥 합성에 '벽에 덮인 칸'(덮개 1)을 알리는 타일
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
	_add_objects(map_id, data, st, Vector2i.ZERO)


## 맵 자료의 소품·문·문패·용기·출구·조사 글을 o(타일)만큼 옮겨 얹는다. 월드(1-1)는 손 맵마다 그 자리로 부른다.
## 조사 글 열쇠는 손 맵 좌표 그대로("X-BC:5,36") — 저장된 조사 기록이 월드에서도 이어진다.
func _add_objects(map_id: String, d: Dictionary, st: StoryState, o: Vector2i) -> void:
	var op := Vector2(o * T)
	for p in d["props"]:
		if not _cond_ok(p.get("cond", ""), st):
			continue
		for c in p.get("cells", []):
			_put_solid(o.x + int(c[0]), o.y + int(c[1]), 1)                     # 조건부 소품의 발 칸
		var e: Dictionary = prop_meta[p["name"]]
		var rect: Array = e["frames"][0] if e.has("frames") else e["rect"]
		var tall: bool = int(rect[3]) - int(e["foot"][1]) * T > 24          # 발 칸 위로 24px 넘게 서는 소품(사물함·선반) = 높은 엄폐
		var fx := int(p["x"]) + o.x
		var fy := int(p["y"]) + o.y
		for yy in range(fy, fy + maxi(1, int(e["foot"][1]))):
			for xx in range(fx, fx + maxi(1, int(e["foot"][0]))):
				if _get_solid(xx, yy) == 1:
					_put_cover(xx, yy, 2 if tall else 1)
		var node := _sprite(rect, Vector2(p["px"][0], p["px"][1]) + op, float(p["sort_y"]) + op.y, str(e.get("atlas", "s07")))
		props.append({"name": p["name"], "x": fx, "y": fy, "w": maxi(1, int(e["foot"][0])),
			"h": maxi(1, int(e["foot"][1])), "node": node})
	for dd in d["doors"]:
		var e: Dictionary = prop_meta[dd["kind"]]
		var dx := int(dd["x"]) + o.x
		var dy := int(dd["y"]) + o.y
		var pos := Vector2(dx * T + int(e["off"][0]), dy * T + int(e["off"][1]))
		var s := _sprite(e["rect"], pos, (dy + 2) * T)
		doors.append({"node": s, "x": dx, "y": dy, "locked": bool(dd["locked"]), "is_open": false, "lock": int(dd.get("lock", -1)),
			"label": str(dd.get("label", "")), "closed": _r(e["rect"]), "open": _r(e.get("open", e["rect"]))})
		if dd["locked"]:
			texts[Vector2i(dx, dy + 1)] = "잠겨 있다."
	for s in d["signs"]:
		if not _cond_ok(s.get("cond", ""), st):
			continue
		var plate := SignPlate.new()
		plate.text = s["text"]
		plate.position = Vector2((int(s["x"]) + o.x) * T + 16, (int(s["y"]) + o.y + 2) * T)
		plate.lift = 2 * T - 2
		objects.add_child(plate)
	for b in d.get("boxes", []):
		var bb: Dictionary = b.duplicate()
		bb["x"] = int(b["x"]) + o.x
		bb["y"] = int(b["y"]) + o.y
		for j in int(b["h"]):
			for i in int(b["w"]):
				boxes[Vector2i(int(bb["x"]) + i, int(bb["y"]) + j)] = bb
	for tm in d.get("terms", []):
		var tt: Dictionary = tm.duplicate()
		for j in int(tm["h"]):
			for i in int(tm["w"]):
				terms[Vector2i(int(tm["x"]) + o.x + i, int(tm["y"]) + o.y + j)] = tt
	for e in d["exits"]:
		exits[Vector2i(int(e["x"]) + o.x, int(e["y"]) + o.y)] = {"to": e["to"], "mark": e["mark"]}
	for t in d["texts"]:
		var live := _cond_ok(t.get("cond", ""), st)
		var staged: bool = t.has("scene") or t.has("seq")              # 장면이 달린 글: 조건은 조사하는 순간에 본다(무기고를 연 뒤의 총기 거치대 등, 0-9)
		if not live and not staged:
			continue
		for j in int(t["h"]):
			for i in int(t["w"]):
				var c := Vector2i(int(t["x"]) + i + o.x, int(t["y"]) + j + o.y)
				var plain: String = texts.get(c, "")
				if live or not texts.has(c):
					texts[c] = t["text"]
				if staged or t.has("cond"):
					text_meta[c] = {"cond": t.get("cond", ""), "seq": t.get("seq", []), "scene": t.get("scene", ""),
						"key": "%s:%d,%d" % [map_id, int(t["x"]), int(t["y"])], "plain": plain}


## 칸 쓰기·읽기(월드는 청크 자료에 쓴다 — WorldMap이 덮어쓴다)
func _put_solid(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < size.x and y < size.y:
		solid[y * size.x + x] = v


func _get_solid(x: int, y: int) -> int:
	if x >= 0 and y >= 0 and x < size.x and y < size.y:
		return solid[y * size.x + x]
	return 1


func _put_cover(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < size.x and y < size.y:
		cover[y * size.x + x] = v


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
func _sprite(rect: Array, top_left: Vector2, sort_y: float, atlas := "s07") -> Sprite2D:
	var s := Sprite2D.new()
	var at := AtlasTexture.new()
	at.atlas = prop_texs.get(atlas, prop_tex)
	at.region = _r(rect)
	s.texture = at
	s.centered = false
	s.position = Vector2(top_left.x, sort_y)
	s.offset = Vector2(0, top_left.y - sort_y)
	objects.add_child(s)
	return s


## 실행 중에 세우는 소품(1-E 인카운터 야영지의 불 드럼·거적 등): 발 칸을 막고(낮은 엄폐) 그림을 세운다. 돌려준 자료로 remove_runtime_prop
func add_runtime_prop(pname: String, c: Vector2i) -> Dictionary:
	var e: Dictionary = prop_meta.get(pname, {})
	if e.is_empty():
		return {}
	var rect: Array = e["frames"][0] if e.has("frames") else e["rect"]
	var fw := maxi(1, int(e["foot"][0]))
	var fh := maxi(1, int(e["foot"][1]))
	var node := _sprite(rect, Vector2(c.x * T + int(e["off"][0]), c.y * T + int(e["off"][1])), (c.y + fh) * T, str(e.get("atlas", "s07")))
	var p := {"name": pname, "x": c.x, "y": c.y, "w": fw, "h": fh, "node": node, "cells": []}
	if int(e["foot"][0]) > 0 and str(e.get("kind", "floor")) != "deco":
		for yy in range(c.y, c.y + fh):
			for xx in range(c.x, c.x + fw):
				_put_solid(xx, yy, 1)
				_put_cover(xx, yy, 1)
				p["cells"].append(Vector2i(xx, yy))
	props.append(p)
	return p


func remove_runtime_prop(p: Dictionary) -> void:
	if p.is_empty():
		return
	for cc in p.get("cells", []):
		_put_solid(cc.x, cc.y, 0)
		_put_cover(cc.x, cc.y, 0)
	if is_instance_valid(p.get("node")):
		p["node"].queue_free()
	props.erase(p)


## 연출: 이 칸(또는 위·아래 칸)에 있는 소품을 상태 그림으로 바꾼다(state "" = 기본 그림). 바꾼 소품 이름, 없으면 ""
func set_prop_state(cell: Vector2i, state: String) -> String:
	for c in [cell, cell + Vector2i(0, -1), cell + Vector2i(0, 1)]:
		for p in props:
			var e: Dictionary = prop_meta[p["name"]]
			if c.x >= p["x"] and c.x < p["x"] + p["w"] and c.y >= p["y"] and c.y < p["y"] + p["h"]:
				if not p.has("node"):
					continue                                                 # 월드 청크 소품(상호작용 목록만 — 그림은 청크가 붙인다)
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


## 이 칸(문 두 칸 중 하나)의 잠긴 문(없으면 빈 사전)
func locked_door_at(c: Vector2i) -> Dictionary:
	for d in doors:
		if bool(d["locked"]) and int(d["x"]) == c.x and (int(d["y"]) == c.y or int(d["y"]) + 1 == c.y):
			return d
	return {}


func unlock_door(x: int, y: int) -> bool:
	for d in doors:
		if int(d["x"]) == x and int(d["y"]) == y:
			d["locked"] = false
			for yy in [y, y + 1]:
				_put_solid(x, yy, 0)
			texts.erase(Vector2i(x, y + 1))
			return true
	return false


func add_actor(a: Node2D) -> void:
	objects.add_child(a)
	actors.append(a)


func remove_actor(a: Node2D) -> void:
	actors.erase(a)


## 맵 좌표(연출·봇이 쓰는 손 맵 좌표) → 이 맵의 칸. 월드는 지금 구역의 손 맵 자리만큼 옮긴다(WorldMap).
func cell_local(x: int, y: int) -> Vector2i:
	return Vector2i(x, y)


## 표지 이름 → 이 맵의 표지 열쇠(월드는 지금 구역의 표지를 먼저 고른다)
func zone_key(name: String) -> String:
	return name


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


## 높이(0-10 바깥): 서 있는 칸과 높이가 다른 칸은 막힌 것으로 본다(벼랑·옥상 끝). 계단·사다리 칸은 양쪽 높이를 잇는다.
func level_at(t: Vector2i) -> int:
	if not ext or t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
		return 0
	return level[t.y * size.x + t.x]


func is_stair(t: Vector2i) -> bool:
	return ext and t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y and stair[t.y * size.x + t.x] == 1


## from 칸에서 to 칸으로 넘어갈 수 있나(높이 규칙만, 막힘은 따로)
func level_link(from: Vector2i, to: Vector2i) -> bool:
	if not ext or from == to:
		return true
	if is_stair(from) or is_stair(to):
		return true
	return level_at(from) == level_at(to)


func _blocked_from(t: Vector2i, from: Vector2i) -> bool:
	return is_solid(t) or (ext and not level_link(from, t))


# ---------------------------------------------------------------- 고가 상판 층(1-Rd)
func deck_at(t: Vector2i) -> int:
	if deck.is_empty() or t.x < 0 or t.y < 0 or t.x >= size.x or t.y >= size.y:
		return DK_NONE
	return deck[t.y * size.x + t.x]


## 상판이 덮은 칸(층 1 노면 또는 난간) — 층 0에서는 그 아래 그늘
static func is_top(d: int) -> bool:
	return d == DK_DECK or d == DK_RAIL or d == DK_PILLAR or d == DK_BROKEN or d == DK_JUNK


## 층을 잇는 칸(램프·비상계단)
static func is_link(d: int) -> bool:
	return d == DK_RAMP or d == DK_STAIR


## 층 fl인 인물이 home 칸에서 t 칸으로 들어갈 수 없나.
##   층 1: 상판·램프만 걷는다. 상판 밖(빈 경간·상판 없는 칸)은 막혀 끝에서 선다. 램프 아래 끝에서만 땅으로 내려선다.
##   층 0: 땅 규칙 + 기둥·옹벽이 막는다. 상판 그늘에서 램프로는 못 오른다(램프는 아래 끝 땅에서만 탄다).
##   램프 위 끝에서 상판으로 들어서면 층 1 규칙(층 0으로 램프를 올라온 인물이 상판에 닿는 순간).
func _blocked_floor(t: Vector2i, home: Vector2i, fl: int) -> bool:
	var d := deck_at(t)
	var hd := deck_at(home)
	if fl >= 1 or (is_link(hd) and is_top(d)):
		if d == DK_DECK or d == DK_PILLAR or d == DK_BROKEN or is_link(d):
			return false
		if d == DK_RAIL or d == DK_WALL or d == DK_JUNK:
			return true
		return not is_link(hd) or _blocked_from(t, home)
	if d == DK_WALL or d == DK_PILLAR:
		return true
	if is_link(d) and is_top(hd):
		return true
	return _blocked_from(t, home)


func _blocked_at(t: Vector2i, home: Vector2i) -> bool:
	return _blocked_floor(t, home, mover_floor) if has_deck else _blocked_from(t, home)


## 칸을 옮긴 뒤의 층: 램프·계단 위에서는 그대로, 상판 칸은 위에서 왔거나 램프에서 올라섰으면 1, 땅은 0
func floor_after(from_t: Vector2i, to_t: Vector2i, fl: int) -> int:
	if not has_deck or from_t == to_t:
		return fl
	var d := deck_at(to_t)
	if is_link(d):
		return fl
	if is_top(d):
		return 1 if fl >= 1 or is_link(deck_at(from_t)) else 0
	return 0


## 두 인물 사이 시야 배수(SD-21 §6.2 '층이 다르면 시야 판정 거리 ×0.5'): 1 같은 층 · 0.5 다른 층 · 0 못 봄.
## 상판 그늘(층 0, 상판이 덮은 칸)에 선 사람과 상판 위 사람은 서로 못 본다. 램프 위는 두 층 다로 본다.
func sight_mul(a: Vector2, fa: int, b: Vector2, fb: int, low_blocks: bool = false) -> float:
	if has_deck and fa != fb:
		var ta := tile_of(a)
		var tb := tile_of(b)
		if not (is_link(deck_at(ta)) or is_link(deck_at(tb))):
			var low := ta if fa < fb else tb
			if is_top(deck_at(low)):
				return 0.0
			return 0.5 if line_of_sight(a, b, low_blocks, true) else 0.0
	return 1.0 if line_of_sight(a, b, low_blocks, has_deck and fa >= 1 and fb >= 1) else 0.0


## 두 층이 서로 닿나(근접·탄·막기): 같은 층이거나 어느 한쪽이 램프 위
func floors_meet(a: Vector2, fa: int, b: Vector2, fb: int) -> bool:
	return fa == fb or not has_deck or is_link(deck_at(tile_of(a))) or is_link(deck_at(tile_of(b)))


func _hits(c: Vector2, r: float) -> bool:
	var home := tile_of(_mover) if _mover != Vector2.INF else tile_of(c)
	for ty in range(floori((c.y - r) / T), floori((c.y + r) / T) + 1):
		for tx in range(floori((c.x - r) / T), floori((c.x + r) / T) + 1):
			if _blocked_at(Vector2i(tx, ty), home):
				var q := Vector2(clampf(c.x, tx * T, tx * T + T), clampf(c.y, ty * T, ty * T + T))
				if q.distance_squared_to(c) < r * r:
					return true
	for b in blockers:
		if is_instance_valid(b) and b.visible:
			var bp: Vector2 = b.loco.logical
			if has_deck and not floors_meet(bp, int(b.get("floor_id")), c, mover_floor):
				continue                                             # 다른 층 사람(상판 위·아래)은 서로 막지 않는다
			# 이미 겹친 인물은 막지 않는다(인물이 주인공 자리로 걸어 들어와 겹치면 서로 영영 못 빠져나오던 것 — 막히면 서되, 갇히지는 않는다)
			var d0 := bp.distance_to(_mover)
			if d0 > 0.5 and d0 >= r + BLOCK_R and bp.distance_to(c) < r + BLOCK_R:
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
func line_of_sight(a: Vector2, b: Vector2, low_blocks: bool = false, over_deck: bool = false) -> bool:
	var p0 := tile_of(a)
	var p1 := tile_of(b)
	var dx := absi(p1.x - p0.x)
	var dy := -absi(p1.y - p0.y)
	var sx := 1 if p0.x < p1.x else -1
	var sy := 1 if p0.y < p1.y else -1
	var err := dx + dy
	var p := p0
	while true:
		if p != p0 and p != p1 and cover_at(p) >= (1 if low_blocks else 2) and not (over_deck and is_top(deck_at(p))):
			return false                                          # over_deck: 상판 위에서 보는 시선은 상판이 덮은 칸(기둥·그늘의 물건)을 넘는다
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
func path(a: Vector2, b: Vector2, max_nodes: int = 4000, fl: int = 0, goal_fl: int = -1) -> PackedVector2Array:
	if has_deck:
		return _path_deck(a, b, max_nodes, fl, goal_fl)
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
			if _blocked_from(nx, cur) or occ.has(nx):
				continue
			if d.x != 0 and d.y != 0 and (_blocked_from(Vector2i(cur.x + d.x, cur.y), cur) or _blocked_from(Vector2i(cur.x, cur.y + d.y), cur)):
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


## 상판이 있는 맵의 길찾기(1-Rd, SD-21 §6.2 '층별 그래프 + 램프·계단 간선'): 상태 = (칸, 층). 층 1에서 땅으로는 램프 아래 끝으로만,
## 층 0에서 상판으로는 램프를 올라서만 간다(추적대는 램프를 돌아서 온다). goal_fl < 0이면 목표 칸에 어느 층으로 닿아도 된다.
func _path_deck(a: Vector2, b: Vector2, max_nodes: int, fl: int, goal_fl: int) -> PackedVector2Array:
	var s := tile_of(a)
	var g := tile_of(b)
	var out := PackedVector2Array()
	if s == g:
		return out
	var occ := {}
	for bl in blockers:
		if is_instance_valid(bl) and bl.visible:
			var bt := tile_of(bl.loco.logical)
			if bt != s and bt != g:
				occ[Vector3i(bt.x, bt.y, int(bl.get("floor_id")))] = true
	var s3 := Vector3i(s.x, s.y, fl)
	var came := {s3: s3}
	var cost := {s3: 0.0}
	var open: Array = [[0.0, s3]]
	var n := 0
	var hit := Vector3i(-1, -1, -1)
	var keep := mover_floor
	while not open.is_empty() and n < max_nodes:
		n += 1
		var best := 0
		for i in open.size():
			if open[i][0] < open[best][0]:
				best = i
		var cur: Vector3i = open[best][1]
		open.remove_at(best)
		if cur.x == g.x and cur.y == g.y and (goal_fl < 0 or cur.z == goal_fl):
			hit = cur
			break
		var ct := Vector2i(cur.x, cur.y)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var nx: Vector2i = ct + d
			if _blocked_floor(nx, ct, cur.z):
				continue
			if d.x != 0 and d.y != 0 and (_blocked_floor(Vector2i(ct.x + d.x, ct.y), ct, cur.z) or _blocked_floor(Vector2i(ct.x, ct.y + d.y), ct, cur.z)):
				continue
			var nf := floor_after(ct, nx, cur.z)
			var n3 := Vector3i(nx.x, nx.y, nf)
			if occ.has(n3):
				continue
			var c: float = cost[cur] + (1.414 if d.x != 0 and d.y != 0 else 1.0)
			if not cost.has(n3) or c < cost[n3]:
				cost[n3] = c
				came[n3] = cur
				open.append([c + Vector2(nx - g).length(), n3])
	mover_floor = keep
	if hit.x < 0:
		return out
	var t := hit
	var rev: Array[Vector3i] = []
	while t != s3:
		rev.append(t)
		t = came[t]
	rev.reverse()
	for c in rev:
		out.append(Vector2(c.x * T + 16, c.y * T + 16))
	return out
