## 심리스 바깥 월드(단계 1-1, SD-08 §3.8·SD-19 §6.5): world_chunks.py가 구운 world.bin을 청크 40×40씩 스트리밍한다.
## InteriorMap을 이어받아 충돌·시선·길찾기·문·소품·조사 API를 그대로 쓰고, 칸 조회만 붙은 청크 자료에서 읽는다.
##   · 사전 로드 5×5(작업 스레드에서 읽기·압축 풀기) · 7×7 밖 해제 · 한 프레임에 1청크만 붙인다(끊김 예산).
##   · 층: 바닥 합성(z -11) · 그림자(z -10, 오른쪽 아래 높이 1단당 16px, 35%) · 구조 타일(z -9) · 덧층(z -8) · 물건 층(y 정렬: 나무·소품·인물).
##   · 손 맵(X-S07 관악산 비탈 · X-BC 봉천)은 실제 좌표에 찍혀 있다(바닥·막힘은 청크 자료, 소품·문·글·출구·NPC는 여기서 옮겨 얹는다).
##     id는 주인공이 선 손 맵 이름(밖이면 "W") — 손 맵 기준으로 짠 연출·봇이 그대로 돈다. to_world(맵, x, y)로 손 맵 좌표를 바꾼다.
class_name WorldMap
extends InteriorMap

## 월드 청크의 소품 중 상호작용하는 것(작업대·불·침대 — 1-8c): 불러온 청크의 것만 props에 올린다
const INTERACT := ["hangyeol_bench", "workbench", "drum_fire", "forge", "cot", "bedroll", "bedroll2", "straw_mat", "straw_mat2", "bunk",
	"hosp_bed", "vip_bed", "yo_bed"]

const HAZARD := ["car_wreck", "car_wreck2", "bus_wreck", "convoy_truck", "drum", "lp_gas",   ## 원자력 차량 · 드럼 · 가스통(1-9c 환경 폭발)
	"rad_puddle", "rad_puddle2", "waste_drum", "rad_cask"]                                 ## 방사능 근원(1-9d): 웅덩이 · 폐기물 드럼 · 차폐 용기

const WDIR := "res://data/world/"
const SIGN_TEXT := {                              ## 1-B3 문 앞 떠돌이 분필 표식 — 실내 생성 결과에서 뽑았다(거짓말하지 않는다, SD-20 P1). 문마다 글은 굽기가 고른 sign_text, 없을 때만 이것
	"skull": "문 앞 바닥에 분필 해골. 떠돌이들 말로 '안에 사람 같은 게 있다'.",
	"claw": "문 앞 바닥에 분필로 그은 발톱 자국 세 줄. 떠돌이들 말로 '짐승 굴'.",
	"trap": "분필 동그라미 속 톱니. 떠돌이들 말로 '덫 있음'. 누가 한 번 당하고 남겼다.",
	"live": "분필로 그린 지붕과 연기 한 줄. 떠돌이들 말로 '누가 드나든다'.",
	"x": "분필 동그라미 속 ✕. 떠돌이들 말로 '헛수고 — 안이 막혔다'.",
	"water": "분필 물결 세 줄. 떠돌이들 말로 '물 받을 데 있음'.",
}
const L_FG := 0                                  ## 바닥·덮개 교대(칸 i: 바닥 2i, 덮개 2i+1)
const L_SOLID := 3200
const L_COVER := 4800
const L_LEVEL := 6400
const L_STAIR := 8000
const L_BODY := 9600
const L_DECO := 12800
const L_DECK := 16000                            ## 고가(1-Rd): 상판 부호 1바이트 · 위층 그림 2바이트 · 아래층 그림 2바이트
const L_DKTOP := 17600
const L_DKLOW := 20800
var L_TAIL := 16000                              ## 나무·그림자 목록 시작(고가 층이 있으면 24000)
const SHADOW := Color(0, 0, 0, 0.35)
const SPR_PER_FRAME := 40

var meta: Dictionary
var cs := 40
var nchunks := Vector2i(53, 43)
var chunks := {}                                 ## Vector2i -> {"a": 원자료, "nodes": [노드…], "g": GroundLayer}
var _pending := {}
var _ready_q: Array = []
var _mutex := Mutex.new()
var focus := Vector2i(-999, -999)
var follow: Node2D                               ## 스트리밍 기준(없으면 첫 인물)
var insets: Array = []                           ## [{"id", "origin": Vector2i, "size": Vector2i, "data"}]
var overrides := {}                              ## Vector2i -> [막힘, 엄폐] (조건부 소품·문·연출이 바꾼 칸; -1 = 청크 값)
var attach_usec_max := 0
var attach_count := 0
var _spr_q: Array = []                           ## [청크, 그림 영역, 위치, 정렬 y] — 나눠 붙일 소품
var _tiles_ground: Node2D
var _tiles_shadow: Node2D
var _tiles_body: Node2D
var _tiles_dlow: Node2D                          ## 고가 아래층(그늘·기둥 밑동·램프·옹벽·비상계단·잔해) z -7
var _tiles_dtop: Node2D                          ## 고가 상판(인물 위) z 2 — 층 1 인물은 z 3
var deck_mat: ShaderMaterial
var hole := Vector2(-99999, -99999)              ## 상판 디더 구멍(주인공이 상판 아래·끝 앞에 설 때) — 탄 그리기도 본다
var hole_r := 0.0
static var world_ts: TileSet
static var ts_cols := 32
static var tree_names: Array = []


func load_map(map_id: String, st: StoryState = null) -> void:
	_load_static()
	id = "W"
	meta = JSON.parse_string(FileAccess.get_file_as_string(WDIR + "world.json"))
	cs = int(meta["chunk_size"])
	nchunks = Vector2i(int(meta["chunks"][0]), int(meta["chunks"][1]))
	size = Vector2i(int(meta["size"][0]), int(meta["size"][1]))
	ext = true
	has_deck = bool(meta.get("deck", false))
	L_TAIL = 24000 if has_deck else 16000
	tree_names = meta["props"]
	if world_ts == null:
		world_ts = load("res://assets/tiles/ts_world.tres")
		ts_cols = int(JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/ts_world.json"))["cols"])
	GroundLayer.get_set("r01")                                            # 바닥 재질·셰이더를 미리 읽어 둔다(붙이기 예산)
	PlaceLog.load_db()                                                   # 장소 425곳(발견·방위 링·지도, 1-2)
	data = {"id": "W", "name": "서울", "npcs": [], "triggers": [], "enemies": [], "props": [], "doors": [], "signs": [], "texts": [],
		"exits": [], "boxes": [], "marks": {}}
	marks = {}
	for n in ["_tiles_ground", "_tiles_shadow", "_tiles_body"]:
		var nd := Node2D.new()
		set(n, nd)
		add_child(nd)
	_tiles_ground.z_index = -11
	_tiles_shadow.z_index = -10
	_tiles_body.z_index = -9
	_tiles_dlow = Node2D.new()
	_tiles_dlow.z_index = -7
	add_child(_tiles_dlow)
	_tiles_dtop = Node2D.new()
	_tiles_dtop.z_index = 2
	deck_mat = ShaderMaterial.new()
	deck_mat.shader = load("res://systems/world/deck_cut.gdshader")
	_tiles_dtop.material = deck_mat
	add_child(_tiles_dtop)
	objects = Node2D.new()
	objects.y_sort_enabled = true
	add_child(objects)
	var ids: Array = []
	for e in meta["insets"]:
		ids.append(str(e["id"]))
	for e in meta["insets"]:
		var iid := str(e["id"])
		var d: Dictionary = InteriorMap.read_data(iid)
		var o := Vector2i(int(e["origin"][0]), int(e["origin"][1]))
		insets.append({"id": iid, "origin": o, "size": Vector2i(int(e["size"][0]), int(e["size"][1])), "data": d})
		var sp := "res://assets/maps/%s_struct.png" % iid                  # 손 맵 구조물 한 장(0-10)
		if ResourceLoader.exists(sp):
			var spr := Sprite2D.new()
			spr.texture = load(sp)
			spr.centered = false
			spr.position = Vector2(o * T)
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_tiles_body.add_child(spr)
		_add_objects(iid, d, st, o)
		for k in d["marks"]:
			var m: Array = d["marks"][k]
			var v := [int(m[0]) + o.x, int(m[1]) + o.y, m[2]]
			marks["%s:%s" % [iid, k]] = v
			if not marks.has(k):
				marks[k] = v
		for n in d["npcs"]:
			var nn: Dictionary = n.duplicate(true)
			nn["x"] = int(n["x"]) + o.x
			nn["y"] = int(n["y"]) + o.y
			for r in nn["route"]:
				r[1] = int(r[1]) + o.x
				r[2] = int(r[2]) + o.y
			data["npcs"].append(nn)
		for key in ["triggers", "enemies"]:
			for g in d.get(key, []):
				var gg: Dictionary = g.duplicate(true)
				gg["x"] = int(g["x"]) + o.x
				gg["y"] = int(g["y"]) + o.y
				gg["key"] = "%s:%d,%d" % [iid, int(g["x"]), int(g["y"])]          # 한 번만 여는 칸의 기록 열쇠는 손 맵 좌표 그대로
				data[key].append(gg)
	var dd := {"props": [], "doors": [], "signs": [], "exits": [], "texts": []}   # 지하로 내려가는 문(1-4): 계단 소품 + 2칸 출구
	for door in PlaceLog.doors:
		var at := Vector2i(int(door["at"][0]), int(door["at"][1]))
		if str(door.get("kind", "")) == "facade":                       # 건물 1층 문(1-5e): 그려진 문 타일에 대고 E — 출구 없음, 문 앞에 닳은 발판(들어갈 수 있다는 표시)
			gos[at] = door
			var mm: Dictionary = prop_meta.get("door_mat", {})
			if not mm.is_empty():
				var mo: Array = mm.get("off", [0, 0])
				dd["props"].append({"name": "door_mat", "x": at.x, "y": at.y + 1, "px": [at.x * T + int(mo[0]), (at.y + 1) * T + 1],
					"sort_y": (at.y + 1) * T + 4})
			if door.has("sign"):                                           # 1-B3 문 앞 분필 표식
				var sa := Vector2i(int(door["sign_at"][0]), int(door["sign_at"][1]))
				var sn := "chalk_" + str(door["sign"])
				var sm: Dictionary = prop_meta.get(sn, {})
				if not sm.is_empty():
					var so: Array = sm.get("off", [0, 0])
					dd["props"].append({"name": sn, "x": sa.x, "y": sa.y, "px": [sa.x * T + int(so[0]), sa.y * T + int(so[1])], "sort_y": sa.y * T + 2})
					dd["texts"].append({"x": sa.x, "y": sa.y, "w": 1, "h": 1, "text": str(door.get("sign_text", SIGN_TEXT.get(str(door["sign"]), "")))})
			continue
		var pm: Dictionary = prop_meta.get(str(door["prop"]), {})
		var off: Array = pm.get("off", [0, 0])
		dd["props"].append({"name": str(door["prop"]), "x": at.x, "y": at.y, "px": [at.x * T + int(off[0]), at.y * T + int(off[1])],
			"sort_y": at.y * T})                                         # 땅에 뚫린 입구: 그 위를 걷는 사람이 앞에 그려진다
		var hint := str(door.get("hint", "계단을 내려가면 지하다."))
		for hc in door.get("hints", []):                                 # 1-D 조건부 문구: 안의 상태가 밖으로 새어 나온다(첫 참인 줄)
			if _cond_ok(str(hc[0]), st):
				hint = str(hc[1])
				break
		var shut: bool = door.has("open") and not _cond_ok(str(door["open"]), st)   # 1-D2 막힌 입구(봉인 · 무너진 맨홀): 글만 남고 들어가지 못한다
		for i in 2:
			if not shut:
				dd["exits"].append({"x": at.x + i, "y": at.y, "to": str(door["to"]), "mark": str(door["mark"])})
			dd["texts"].append({"x": at.x + i, "y": at.y - 1, "w": 1, "h": 1, "text": str(door["name"]) + " — " + hint})
		var dg := Dungeon.of_map(str(door["to"]))
		if not dg.is_empty() and st != null and not (dg.get("chalk", []) as Array).is_empty():   # 1-D 던전 입구 분필 표식: 정리 상태를 밖에서(사실 한 곳 — DG_ 변수 · 글은 던전 표)
			var ch: Array = dg["chalk"][clampi(Dungeon.state(st, dg), 0, 2)]
			var dsn := str(ch[0])
			var dst := str(ch[1])
			var csm: Dictionary = prop_meta.get(dsn, {})
			var ca := Vector2i(at.x + 2, at.y)
			if not csm.is_empty():
				var co: Array = csm.get("off", [0, 0])
				dd["props"].append({"name": dsn, "x": ca.x, "y": ca.y, "px": [ca.x * T + int(co[0]), ca.y * T + int(co[1])], "sort_y": ca.y * T + 2})
				dd["texts"].append({"x": ca.x, "y": ca.y, "w": 1, "h": 1, "text": dst})
	_add_objects("W", dd, st, Vector2i.ZERO)
	for sp in PlaceLog.spots:                                            # 발견 자리(1-4): 잠든 파수·길 위 유해·쪽지 — 구역 기준 좌표를 옮겨 붙인다
		if not _cond_ok(str(sp.get("cond", "")), st):
			continue
		var so := Vector2i(int(sp["at"][0]), int(sp["at"][1]))
		var sd: Dictionary = sp["data"]
		var key := "W:" + str(sp["key"])
		_add_objects(key, sd, st, so)
		for k in sd["marks"]:
			var m: Array = sd["marks"][k]
			marks[k] = [int(m[0]) + so.x, int(m[1]) + so.y, m[2]]
		for n in sd["npcs"]:
			var nn: Dictionary = n.duplicate(true)
			nn["x"] = int(n["x"]) + so.x
			nn["y"] = int(n["y"]) + so.y
			for r in nn["route"]:
				r[1] = int(r[1]) + so.x
				r[2] = int(r[2]) + so.y
			data["npcs"].append(nn)
		for k2 in ["triggers", "enemies"]:
			for g in sd.get(k2, []):
				var gg: Dictionary = g.duplicate(true)
				gg["x"] = int(g["x"]) + so.x
				gg["y"] = int(g["y"]) + so.y
				gg["key"] = "%s:%d,%d" % [key, int(g["x"]), int(g["y"])]
				data[k2].append(gg)
	if FileAccess.file_exists(WDIR + "pois.json"):                      # 길 위 발견물(1-4f, SD-08 §13.2): 소품은 청크에 구워져 있고 용기·조사 글만 여기서 단다
		var pz: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WDIR + "pois.json"))
		for b in pz["boxes"]:
			var bb: Dictionary = b
			bb["cond"] = ""
			for j in int(bb["h"]):
				for i in int(bb["w"]):
					boxes[Vector2i(int(bb["x"]) + i, int(bb["y"]) + j)] = bb
		for t in pz["texts"]:
			texts[Vector2i(int(t["x"]), int(t["y"]))] = str(t["text"])
			if t.has("fx"):
				text_fx[Vector2i(int(t["x"]), int(t["y"]))] = str(t["fx"])
	for k in exits.keys():                                               # 손 맵끼리 잇던 가장자리 출구는 월드에서 이어진 땅이다
		if str(exits[k]["to"]) in ids:
			exits.erase(k)
	data["marks"] = marks


## 이 맵 ID를 월드가 맡나("W" 또는 월드에 찍힌 손 맵)
static func covers(map_id: String) -> bool:
	if map_id == "W":
		return true
	if _covered.is_empty() and FileAccess.file_exists(WDIR + "world.json"):
		for e in JSON.parse_string(FileAccess.get_file_as_string(WDIR + "world.json"))["insets"]:
			_covered[str(e["id"])] = true
	return _covered.has(map_id)


static var _covered := {}


## 손 맵이 월드에 찍힌 자리(타일)
static func origin_of(map_id: String) -> Vector2i:
	for e in JSON.parse_string(FileAccess.get_file_as_string(WDIR + "world.json"))["insets"]:
		if str(e["id"]) == map_id:
			return Vector2i(int(e["origin"][0]), int(e["origin"][1]))
	return Vector2i.ZERO


## 지금 구역 이름(배너): 손 맵 이름, 밖이면 권역 이름(SD-08 §7)
func zone_name() -> String:
	for ins in insets:
		if ins["id"] == id:
			return str(ins["data"]["name"])
	return region_name(region_at(focus * cs))


## 칸이 든 권역 코드(R01~R11·HR, 놀이 구역 밖이면 "")
func region_at(t: Vector2i) -> String:
	var k := chunk_of_tile(t)
	return str(meta.get("regions", {}).get("%d,%d" % [k.x, k.y], ""))


func region_name(code: String) -> String:
	return str(meta.get("region_names", {}).get(code, "서울"))


## 손 맵 좌표 → 월드 타일(손 맵이 아니면 그대로)
func to_world(map_id: String, x: int, y: int) -> Vector2i:
	for ins in insets:
		if ins["id"] == map_id:
			return Vector2i(x, y) + ins["origin"]
	return Vector2i(x, y)


func cell_local(x: int, y: int) -> Vector2i:
	return to_world(id, x, y)


func zone_key(name: String) -> String:
	var z := "%s:%s" % [id, name]
	if marks.has(z) or marks.has(name):
		return z if marks.has(z) else name
	for k in marks:                                                # 구역 경계 밖(월드 W)에서도 손 맵 표지를 찾는다(예: 비탈의 dogs)
		if str(k).ends_with(":" + name):
			return k
	return name


func mark_pos(name: String) -> Vector2:
	return super.mark_pos(zone_key(name))


func mark_dir(name: String) -> String:
	return super.mark_dir(zone_key(name))


## 손 맵 사이 걷는 길(굽기가 찾은 경유점, ["W", x, y] 목록). 없으면 빈 배열
func route_between(a: String, b: String) -> Array:
	var rt: Dictionary = meta.get("routes", {})
	var out: Array = []
	if rt.has("%s>%s" % [a, b]):
		for q in rt["%s>%s" % [a, b]]:
			out.append(["W", int(q[0]), int(q[1])])
	elif rt.has("%s>%s" % [b, a]):
		var r: Array = rt["%s>%s" % [b, a]]
		for i in range(r.size() - 1, -1, -1):
			out.append(["W", int(r[i][0]), int(r[i][1])])
	return out


## 이 칸이 든 손 맵 이름(없으면 "W")
func zone_of(t: Vector2i) -> String:
	for ins in insets:
		var o: Vector2i = ins["origin"]
		var s: Vector2i = ins["size"]
		if t.x >= o.x and t.y >= o.y and t.x < o.x + s.x and t.y < o.y + s.y:
			return ins["id"]
	return "W"


func _process(dt: float) -> void:
	super._process(dt)
	var f: Node2D = follow if is_instance_valid(follow) else (actors[0] if not actors.is_empty() and is_instance_valid(actors[0]) else null)
	if f != null:
		var p: Vector2 = f.loco.logical if "loco" in f and f.loco != null else f.position
		update_focus(p)
		id = zone_of(tile_of(p))


# ---------------------------------------------------------------- 스트리밍
func chunk_of_tile(t: Vector2i) -> Vector2i:
	return Vector2i(floori(float(t.x) / cs), floori(float(t.y) / cs))


func _in_world(k: Vector2i) -> bool:
	if k.x < 0 or k.y < 0 or k.x >= nchunks.x or k.y >= nchunks.y:
		return false
	return int(meta["offsets"][k.y * nchunks.x + k.x][1]) > 0


func update_focus(p: Vector2) -> void:
	var c := chunk_of_tile(tile_of(p))
	if c != focus:
		focus = c
		for dy in range(-2, 3):
			for dx in range(-2, 3):                                         # 5×5 사전 로드
				var k := c + Vector2i(dx, dy)
				if _in_world(k) and not chunks.has(k) and not _pending.has(k):
					_pending[k] = WorkerThreadPool.add_task(_load_task.bind(k))
		for k in chunks.keys():                                             # 7×7 밖 해제
			if absi(k.x - c.x) > 3 or absi(k.y - c.y) > 3:
				_detach(k)
	_attach_one()


func _load_task(k: Vector2i) -> void:
	var o: Array = meta["offsets"][k.y * nchunks.x + k.x]
	var f := FileAccess.open(WDIR + "world.bin", FileAccess.READ)
	f.seek(int(o[0]))
	var raw := f.get_buffer(int(o[1])).decompress(int(o[2]), FileAccess.COMPRESSION_DEFLATE)
	_mutex.lock()
	_ready_q.append([k, raw])
	_mutex.unlock()


## 소품 스프라이트를 프레임마다 SPR_PER_FRAME개씩 붙인다(청크 하나에 수십 개 — 한 번에 만들면 붙이기 예산 4ms를 넘는다)
func _drain_sprites(n: int = SPR_PER_FRAME) -> void:
	while n > 0 and not _spr_q.is_empty():
		var q: Array = _spr_q.pop_front()
		var c = chunks.get(q[0])
		if c == null:
			continue
		c["nodes"].append(_sprite(q[1], q[2], q[3], "r01"))
		n -= 1


func _attach_one() -> bool:
	_drain_sprites()
	_mutex.lock()
	var item = _ready_q.pop_front() if not _ready_q.is_empty() else null
	_mutex.unlock()
	if item == null:
		return false
	var k: Vector2i = item[0]
	WorkerThreadPool.wait_for_task_completion(_pending[k])
	_pending.erase(k)
	if absi(k.x - focus.x) > 3 or absi(k.y - focus.y) > 3 or chunks.has(k):
		return true
	var t0 := Time.get_ticks_usec()
	_attach(k, item[1])
	var us := Time.get_ticks_usec() - t0
	attach_usec_max = maxi(attach_usec_max, us)
	attach_count += 1
	return true


func _attach(k: Vector2i, a: PackedByteArray) -> void:
	var o := k * cs
	var nodes: Array = []
	var g := GroundLayer.new()                                           # 바닥 합성(SD-16 §6.10)
	g.setup("r01", o, Vector2i(cs, cs))
	g.fill_rg(a, L_FG)
	for dy in range(-1, 2):                                              # 이웃 청크와 테두리를 서로 채운다(경계 섞임이 이어지게)
		for dx in range(-1, 2):
			var nk := k + Vector2i(dx, dy)
			if (dx == 0 and dy == 0) or not chunks.has(nk):
				continue
			var nb: Dictionary = chunks[nk]
			_share_ring(nk, nb["a"], g)
			var ng: GroundLayer = nb["g"]
			_share_ring(k, a, ng)
			ng.commit()
	g.pad()
	g.commit()
	_tiles_ground.add_child(g)
	nodes.append(g)
	var body := TileMapLayer.new()                                       # 구조 타일(건물·암벽·다리·성곽)
	body.tile_set = world_ts
	var dec := TileMapLayer.new()                                        # 덧층(옥상 설비·벼랑 끝)
	dec.tile_set = world_ts
	dec.z_index = 1
	for y in cs:
		for x in cs:
			var i := y * cs + x
			var b := a[L_BODY + i * 2] | (a[L_BODY + i * 2 + 1] << 8)
			if b > 0:
				body.set_cell(o + Vector2i(x, y), 0, Vector2i((b - 1) % ts_cols, (b - 1) / ts_cols))
			var dv := a[L_DECO + i * 2] | (a[L_DECO + i * 2 + 1] << 8)
			if dv > 0:
				dec.set_cell(o + Vector2i(x, y), 0, Vector2i((dv - 1) % ts_cols, (dv - 1) / ts_cols))
	_tiles_body.add_child(body)
	_tiles_body.add_child(dec)
	nodes.append(body)
	nodes.append(dec)
	if has_deck:                                                         # 고가(1-Rd·Re): 아래층(인물 아래) · 상판(인물 위, 디더 구멍)
		var dl := TileMapLayer.new()
		dl.tile_set = world_ts
		var dt := TileMapLayer.new()
		dt.tile_set = world_ts
		dt.use_parent_material = true
		var any := false
		for y in cs:
			for x in cs:
				var i := y * cs + x
				if a[L_DECK + i] == 0 and a[L_DKLOW + i * 2] == 0 and a[L_DKLOW + i * 2 + 1] == 0:
					continue
				var tv := a[L_DKTOP + i * 2] | (a[L_DKTOP + i * 2 + 1] << 8)
				var lv := a[L_DKLOW + i * 2] | (a[L_DKLOW + i * 2 + 1] << 8)
				if tv > 0:
					dt.set_cell(o + Vector2i(x, y), 0, Vector2i((tv - 1) % ts_cols, (tv - 1) / ts_cols))
					any = true
				if lv > 0:
					dl.set_cell(o + Vector2i(x, y), 0, Vector2i((lv - 1) % ts_cols, (lv - 1) / ts_cols))
					any = true
		if any:
			_tiles_dlow.add_child(dl)
			_tiles_dtop.add_child(dt)
			nodes.append(dl)
			nodes.append(dt)
		else:
			dl.free()
			dt.free()
	var p := L_TAIL                                                      # 나무·거리 소품(R01 소품, y 정렬)
	var nt := a[p] | (a[p + 1] << 8)
	p += 2
	for j in nt:
		var tx := o.x + a[p]
		var ty := o.y + a[p + 1]
		var e: Dictionary = prop_meta[tree_names[a[p + 2] | (a[p + 3] << 8)]]
		var fh := int(e["foot"][1])
		var sy := ty * T + 16 if fh == 0 else (ty + fh) * T                 # 바닥 덧그림(풀포기·맨홀)은 칸 가운데, 나머지는 발 칸 아래 변
		_spr_q.append([k, e["rect"], Vector2(tx * T + int(e["off"][0]), ty * T + int(e["off"][1])), sy])   # 다음 프레임들에 나눠 붙인다
		var pn: String = tree_names[a[p + 2] | (a[p + 3] << 8)]
		if INTERACT.has(pn) or HAZARD.has(pn):                                               # 작업대·화덕·침대(1-8c): 호스트가 앞 칸에서 찾는다
			props.append({"name": pn, "x": tx, "y": ty, "w": maxi(1, int(e["foot"][0])), "h": maxi(1, fh), "chunk": k})
		p += 4
	var ns := a[p] | (a[p + 1] << 8)                                     # 건물 그림자(SD-16 §3.9: 오른쪽 아래, 높이 1단당 16px, 곱하기 35%)
	p += 2
	if ns > 0:
		var sh := Node2D.new()
		var polys: Array = []
		for j in ns:
			var bx := _i16(a, p)
			var by := _i16(a, p + 2)
			var bw := a[p + 4]
			var bh := a[p + 5]
			var s := a[p + 6] * 16.0
			var x1 := (bx + bw) * T
			polys.append(PackedVector2Array([Vector2(x1, by * T), Vector2(x1 + s, by * T + s), Vector2(x1 + s, (by + bh) * T), Vector2(x1, (by + bh) * T)]))
			p += 8
		sh.draw.connect(func() -> void:
			for q in polys:
				sh.draw_colored_polygon(q, SHADOW))
		_tiles_shadow.add_child(sh)
		nodes.append(sh)
	chunks[k] = {"a": a, "nodes": nodes, "g": g}


static func _i16(a: PackedByteArray, p: int) -> int:
	var v := a[p] | (a[p + 1] << 8)
	return v - 65536 if v >= 32768 else v


## 청크 k의 자료 중 dst 바닥 층의 테두리에 닿는 칸만 넣는다.
func _share_ring(k: Vector2i, a: PackedByteArray, dst: GroundLayer) -> void:
	var so := k * cs
	var x0 := maxi(so.x, dst.origin.x - 1)
	var x1 := mini(so.x + cs - 1, dst.origin.x + dst.size.x)
	var y0 := maxi(so.y, dst.origin.y - 1)
	var y1 := mini(so.y + cs - 1, dst.origin.y + dst.size.y)
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			var i := (ty - so.y) * cs + (tx - so.x)
			dst.put_flag(tx, ty, a[L_FG + i * 2], a[L_FG + i * 2 + 1])


func _detach(k: Vector2i) -> void:
	props = props.filter(func(q): return q.get("chunk", Vector2i(-9999, -9999)) != k)
	for n in chunks[k]["nodes"]:
		if is_instance_valid(n):
			n.queue_free()
	chunks.erase(k)


## 순간 이동·맵 열기용: p 둘레 3×3을 지금 붙인다(화면이 가려질 때만 — 끊김을 감수한다).
func load_now(p: Vector2) -> void:
	update_focus(p)
	var c := chunk_of_tile(tile_of(p))
	var t_end := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < t_end:
		var missing := false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var k := c + Vector2i(dx, dy)
				if _in_world(k) and not chunks.has(k):
					missing = true
		if not missing:
			_drain_sprites(1 << 30)                                       # 화면이 가려진 동안이니 소품도 다 붙인다
			return
		if not _attach_one():
			OS.delay_msec(1)


# ---------------------------------------------------------------- 칸 조회(붙은 청크 자료)
func _cell(t: Vector2i, layer: int) -> int:
	var k := chunk_of_tile(t)
	var c = chunks.get(k)
	if c == null:
		return -1
	return c["a"][layer + (t.y - k.y * cs) * cs + (t.x - k.x * cs)]


func is_solid(t: Vector2i) -> bool:
	var ov = overrides.get(t)
	if ov != null and ov[0] >= 0:
		return ov[0] == 1
	var v := _cell(t, L_SOLID)
	return v != 0                                                        # 붙지 않은 청크(-1)는 막힌 것으로 본다(밖으로 새지 않게)


func cover_at(t: Vector2i) -> int:
	var ov = overrides.get(t)
	if ov != null and ov[1] >= 0:
		return ov[1]
	var v := _cell(t, L_COVER)
	return 2 if v < 0 else v


func level_at(t: Vector2i) -> int:
	return maxi(0, _cell(t, L_LEVEL))


## 고가 상판 부호(InteriorMap.DK_*) — 붙지 않은 청크는 0
func deck_at(t: Vector2i) -> int:
	if not has_deck:
		return DK_NONE
	return maxi(0, _cell(t, L_DECK))


## 상판 디더 구멍: 주인공이 층 0에서 상판 아래(그늘)나 상판 남쪽 끝 바로 앞(머리가 상판 그림에 걸리는 칸)에 서면 둘레를 비춘다
func update_hole(p: Vector2, fl: int) -> void:
	if not has_deck or deck_mat == null:
		return
	var t := tile_of(p)
	var under := fl == 0 and (is_top(deck_at(t)) or is_top(deck_at(t + Vector2i(0, -1))))
	var r := 5.0 * T if under else 0.0
	if r != hole_r or (under and p.distance_to(hole + Vector2(0, 16)) > 0.5):
		hole_r = r
		hole = p - Vector2(0, 16)
		deck_mat.set_shader_parameter("hole", hole)
		deck_mat.set_shader_parameter("radius", hole_r)


func is_stair(t: Vector2i) -> bool:
	return _cell(t, L_STAIR) == 1


func _put_solid(x: int, y: int, v: int) -> void:
	var t := Vector2i(x, y)
	var ov: Array = overrides.get(t, [-1, -1])
	ov[0] = v
	overrides[t] = ov


func _put_cover(x: int, y: int, v: int) -> void:
	var t := Vector2i(x, y)
	var ov: Array = overrides.get(t, [-1, -1])
	ov[1] = v
	overrides[t] = ov


## 손 맵 적재 중에는 청크가 아직 없으니 손 맵 자료에서 읽는다
func _get_solid(x: int, y: int) -> int:
	var t := Vector2i(x, y)
	var ov = overrides.get(t)
	if ov != null and ov[0] >= 0:
		return ov[0]
	for ins in insets:
		var o: Vector2i = ins["origin"]
		var s: Vector2i = ins["size"]
		if x >= o.x and y >= o.y and x < o.x + s.x and y < o.y + s.y:
			return 1 if str(ins["data"]["solid"][y - o.y][x - o.x]) == "1" else 0
	return 1 if is_solid(t) else 0


## 지역 지도 칸 분류: 0 모름(청크 없음) · 1 걷는 땅 · 2 길 · 3 물 · 4 건물·구조물 · 5 나무·소품
func tile_class(t: Vector2i) -> int:
	var k := chunk_of_tile(t)
	var c = chunks.get(k)
	if c == null:
		return 0
	var a: PackedByteArray = c["a"]
	var i := (t.y - k.y * cs) * cs + (t.x - k.x * cs)
	var fl := a[L_FG + i * 2]
	if _floor_kind.is_empty():
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/ts_r01_ext.json"))
		for n in m:
			var cls := 3 if str(n).begins_with("water") else (2 if str(n) in ["asphalt", "asphalt_lane", "pavers", "pavers_b", "concrete_o", "ballast"] else 1)
			_floor_kind[int(m[n]["atlas"][0])] = cls
	var body := a[L_BODY + i * 2] | (a[L_BODY + i * 2 + 1] << 8)
	if a[L_SOLID + i] == 1:
		if body > 0:
			return 4
		return 3 if int(_floor_kind.get(fl, 1)) == 3 else 5
	if body > 0:
		return 2                                                             # 다리 상판·돌계단
	return int(_floor_kind.get(fl, 1))


static var _floor_kind := {}
static var _floor_name := {}


## 길 위계(SD-21 · SD-22 §3.6 인카운터 확률): 3 큰길·고가 둘레(아스팔트·보도, 청크 태그 큰길·고가) · 2 다른 찻길 · 1 동네 길·골목 · 0 길 아님
func road_rank(t: Vector2i) -> int:
	var k := chunk_of_tile(t)
	var c = chunks.get(k)
	if c == null:
		return 0
	if _floor_name.is_empty():
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/ts_r01_ext.json"))
		for n in m:
			_floor_name[int(m[n]["atlas"][0])] = str(n)
	var a: PackedByteArray = c["a"]
	var fl := str(_floor_name.get(a[L_FG + ((t.y - k.y * cs) * cs + (t.x - k.x * cs)) * 2], ""))
	var tags: Array = Loot.tags_at(t.x, t.y)
	var big: bool = "큰길" in tags or "고가" in tags
	if fl in ["asphalt", "asphalt_lane", "pavers", "pavers_b"]:
		return 3 if big else 2
	if fl == "concrete_o" or (fl == "dirt" and ("구도심" in tags or "언덕" in tags)):
		return 1
	return 0


func triggers_at(t: Vector2i) -> Array:
	var out := []
	for g in data["triggers"]:
		if t.x >= int(g["x"]) and t.x < int(g["x"]) + int(g["w"]) and t.y >= int(g["y"]) and t.y < int(g["y"]) + int(g["h"]):
			out.append(g)
	return out
