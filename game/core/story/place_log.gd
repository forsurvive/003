## 장소 발견 기록(단계 1-2, SD-12 §5.5 · SD-10 §4.4): 장소 425곳(data/world/places.json, SD-09a~f 개요 표)의 상태.
## 상태: 0 미상(정보 없음) · 1 소문(대략 위치, 지도에 반경 원 +?) · 2 표시(정확한 위치, 빈 아이콘) · 3 발견(채운 아이콘, 빠른 이동 가능).
## 상태는 올라가기만 한다. 발견 = 장소 중심 반경 4타일 안에 들어섰을 때(월드 좌표). 마커 N 장소는 발견해도 지도에 남지 않고
## 구역 진입 알림만(발견 XP 없음, SD-09b). 발견 XP: 지하철역 5 · 주요 25 · 그 밖 10 · 볼트 S-07 0(통계 제외).
class_name PlaceLog
extends RefCounted

const UNKNOWN := 0
const RUMOR := 1
const MARKED := 2
const FOUND := 3
const RADIUS := 4
const CHUNK := 40
const PATH := "res://data/world/places.json"
const GEO := "res://data/world/place_geo.json"

static var db: Dictionary = {}                  ## lid -> {name, type, region, tx, ty, icon, marker, hidden, xp, ...}
static var _grid: Dictionary = {}               ## 청크 Vector2i -> [lid] (발견 검사용)
static var doors: Array = []                    ## 월드 → 실내 문(1-4, 굽기 "_doors"): [{"lid", "at", "to", "mark", "name", "prop"}]
static var spots: Array = []                    ## 월드 발견 자리(1-4, 굽기 "_spots"): [{"key", "lid", "at", "cond", "data"}] — data는 맵 명령 결과(구역 기준 좌표)
static var han: Array = []                      ## 한강 본류 세로 가운데(가로 칸마다, 굽기 place_geo.json "_han")
var state := {}                                 ## lid -> 상태(0이면 적지 않는다)
var found_order: Array = []                     ## 발견한 순서(통계·최근 목록)
var regions := {}                               ## 들어가 본 권역 코드 -> true(월드 지도에서 이름을 진하게, SD-12 §5.1)
var explored := {}                              ## 청크 "cx,cy" -> 비트 200바이트(40×40칸, 지역 지도 안개 걷기 SD-12 §5.2)


static func load_db() -> void:
	if not db.is_empty() or not FileAccess.file_exists(PATH):
		return
	db = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var geo: Dictionary = {}
	if FileAccess.file_exists(GEO):
		geo = JSON.parse_string(FileAccess.get_file_as_string(GEO))
	han = geo.get("_han", [])
	doors = geo.get("_doors", [])
	spots = geo.get("_spots", [])
	for lid in db:
		var e: Dictionary = db[lid]
		var g: Dictionary = geo.get(lid, {})
		e["bank"] = str(g.get("bank", ""))                                # 강변 N·S(빠른 이동 한강 횡단, SD-12 §5.6)
		e["arrive"] = g.get("arrive")                                      # 도착 칸 [x, y] — 없으면 빠른 이동 불가
		if str(e["region"]) == "UG":                                      # 지하 장소는 지하 맵에서(1-2는 지상만)
			continue
		var k := Vector2i(int(e["tx"]) / CHUNK, int(e["ty"]) / CHUNK)
		if not _grid.has(k):
			_grid[k] = []
		_grid[k].append(lid)


func get_state(lid: String) -> int:
	return int(state.get(lid, UNKNOWN))


## 상태를 올린다(내려가지 않는다). 올렸으면 true
func raise(lid: String, s: int) -> bool:
	load_db()
	if s <= get_state(lid) or not db.has(lid):
		return false
	state[lid] = s
	if s == FOUND:
		found_order.append(lid)
	return true


## 칸 t(월드)에서 반경 안에 든 장소 중 아직 발견하지 않은 것을 발견으로 올린다 → 새로 발견한 lid 목록
func discover_near(t: Vector2i) -> Array:
	load_db()
	var out: Array = []
	var k := Vector2i(t.x / CHUNK, t.y / CHUNK)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			for lid in _grid.get(k + Vector2i(dx, dy), []):
				if get_state(lid) >= FOUND:
					continue
				var e: Dictionary = db[lid]
				if absi(int(e["tx"]) - t.x) <= RADIUS and absi(int(e["ty"]) - t.y) <= RADIUS:
					raise(lid, FOUND)
					out.append(lid)
	return out


## 칸 t의 강변(N 북안 · S 남안, SD-12 §5.6)
static func bank_at(t: Vector2i) -> String:
	if han.is_empty():
		return "S"
	return "N" if t.y < int(han[clampi(t.x, 0, han.size() - 1)]) else "S"


## 지도에 보이나(마커 Y이고 상태가 소문 이상, 숨김 장소는 발견 뒤에만)
func on_map(lid: String) -> bool:
	var e: Dictionary = db.get(lid, {})
	if e.is_empty() or not bool(e["marker"]):
		return false
	var s := get_state(lid)
	return s >= FOUND or (s >= RUMOR and not bool(e["hidden"]))


func count_found(with_stats := true) -> int:
	var n := 0
	for lid in state:
		if int(state[lid]) >= FOUND and (not with_stats or not bool(db.get(lid, {}).get("no_stats", false))) and bool(db.get(lid, {}).get("marker", false)):
			n += 1
	return n


## 본 칸으로 적는다: t 둘레 가로 ±rx · 세로 ±ry(화면 시야 약 20×11타일)
func mark_seen(t: Vector2i, rx := 10, ry := 6) -> void:
	for y in range(t.y - ry, t.y + ry + 1):
		for x in range(t.x - rx, t.x + rx + 1):
			if x < 0 or y < 0:
				continue
			var key := "%d,%d" % [x / CHUNK, y / CHUNK]
			var b: PackedByteArray = explored.get(key, PackedByteArray())
			if b.is_empty():
				b.resize(200)
			var i := (y % CHUNK) * CHUNK + (x % CHUNK)
			b[i >> 3] = b[i >> 3] | (1 << (i & 7))
			explored[key] = b


func seen(t: Vector2i) -> bool:
	if t.x < 0 or t.y < 0:
		return false
	var b: PackedByteArray = explored.get("%d,%d" % [t.x / CHUNK, t.y / CHUNK], PackedByteArray())
	if b.is_empty():
		return false
	var i := (t.y % CHUNK) * CHUNK + (t.x % CHUNK)
	return (b[i >> 3] >> (i & 7)) & 1 == 1


func to_dict() -> Dictionary:
	var keys := state.keys()
	keys.sort()
	var s := {}
	for k in keys:
		s[k] = state[k]
	var ex := {}
	var ek := explored.keys()
	ek.sort()
	for k in ek:
		ex[k] = Marshalls.raw_to_base64(explored[k])
	var rg := regions.keys()
	rg.sort()
	return {"state": s, "order": found_order.duplicate(), "regions": rg, "explored": ex}


func from_dict(d: Dictionary) -> void:
	state = (d.get("state", {}) as Dictionary).duplicate()
	found_order = (d.get("order", []) as Array).duplicate()
	regions = {}
	for r in d.get("regions", []):
		regions[str(r)] = true
	explored = {}
	var ex: Dictionary = d.get("explored", {})
	for k in ex:
		explored[k] = Marshalls.base64_to_raw(str(ex[k]))
