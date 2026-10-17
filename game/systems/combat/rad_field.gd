## 방사능 지대(SD-11 §11.2 · §9.2 · §9.3, 단계 1-9d): 한 칸의 초당 라드(저항 전)를 모든 근원에서 모아 가장 센 값을 준다.
##   · 맵 자료 `rad Z x y w h`(손 맵 · 실내) · 월드 구역 고리(data/world/rad.json — 김포 · 이촌 · 우면 · 공릉 · 남산 비산 · 서쪽 안개)
##   · 소품: 방사능 웅덩이 Z1(1.2t) · 폐기물 드럼 Z2(2.2t, 터져 그을려도 샌다)
##   · 임시 지대(Ordnance.zones kind rad): 원자력 차량 폭발 5라드/초 3t 15초 · 핵 투사기 8라드/초 4t 20초
##   · 열린 차폐 용기(방사능 함정): 20라드/초 2.5t — 봉인(수리 75)할 때까지.
## 그림: 지대 안 칸마다 해시로 고른 자리에 녹색 아지랑이(zone_rad, 바닥층) — 칸에 붙어 있어 걸어도 따라오지 않는다.
class_name RadField
extends Node2D

const PROPS := {"rad_puddle": [1, 1.2], "rad_puddle2": [1, 1.2], "waste_drum": [2, 2.2]}
const CASK_RATE := 20.0
const CASK_R := 2.5
var map
var st: StoryState
var ord: Ordnance
var hazards: Hazards
var rects: Array = []                          ## [Rect2i, 등급]
var world: Array = []                          ## rad.json zones
var srcs: Array = []                           ## {"p": Vector2, "r": 픽셀, "rate"}
var _sync_t := 0.0
var _motes: Array = []                         ## [위치, 위상] — 0.25초마다 다시 고른다
var _mote_t := 0.0
var _anim := 0.0
var view_center := Vector2.ZERO
static var _world_db := {}


func _init() -> void:
	z_index = -9


func bind(o: Ordnance, h: Hazards) -> void:
	ord = o
	hazards = h


func setup(m, s: StoryState) -> void:
	map = m
	st = s
	rects.clear()
	world.clear()
	srcs.clear()
	_motes.clear()
	for r in m.data.get("rad", []):
		if InteriorMap._cond_ok(str(r.get("cond", "")), s):
			rects.append([Rect2i(int(r["x"]), int(r["y"]), int(r["w"]), int(r["h"])), int(r["z"])])
	if m is WorldMap:
		if _world_db.is_empty() and FileAccess.file_exists("res://data/world/rad.json"):
			_world_db = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/rad.json"))
		world = (_world_db.get("zones", []) as Array).filter(func(z): return InteriorMap._cond_ok(str(z.get("cond", "")), s))   # 조건부 지대(UQ-71 ③ 신길 빌라)
	_sync_props()


func _sync_props() -> void:
	srcs.clear()
	for p in map.props:
		var nm := str(p["name"])
		if PROPS.has(nm):
			var c := Vector2i(int(p["x"]), int(p["y"]))
			srcs.append({"p": Vector2(c.x * 32 + 16, c.y * 32 + 16), "r": float(PROPS[nm][1]) * 32.0, "rate": Radiation.DOSE[int(PROPS[nm][0])], "puddle": nm.begins_with("rad_puddle")})


## 월드 구역 고리의 등급(칸 좌표)
static func world_grade(zones: Array, t: Vector2) -> int:
	var best := 0
	for z in zones:
		if z.has("box"):
			var b: Array = z["box"]
			if t.x >= float(b[0]) and t.x < float(b[2]) and t.y >= float(b[1]) and t.y < float(b[3]):
				best = maxi(best, int(z["z"]))
			continue
		var d := t.distance_to(Vector2(float(z["c"][0]), float(z["c"][1])))
		for ring in z["rings"]:
			if d <= float(ring[0]):
				best = maxi(best, int(ring[1]))
				break
	return best


## p(픽셀) 자리의 초당 라드(저항 전)
func dose_at(p: Vector2) -> float:
	var rate := 0.0
	var t := Vector2i(floori(p.x / 32.0), floori(p.y / 32.0))
	for r in rects:
		if (r[0] as Rect2i).has_point(t):
			rate = maxf(rate, Radiation.DOSE[int(r[1])])
	if not world.is_empty():
		var g := world_grade(world, Vector2(t.x + 0.5, t.y + 0.5))
		if g > 0:
			rate = maxf(rate, Radiation.DOSE[g])
	for s in srcs:
		if (s["p"] as Vector2).distance_to(p) <= float(s["r"]):
			rate = maxf(rate, float(s["rate"]))
	if ord != null:
		for z in ord.zones:
			if z["kind"] == "rad" and (z["p"] as Vector2).distance_to(p) <= float(z["r"]):
				rate = maxf(rate, float((z["w"] as Dictionary).get("rad", 5.0)))
	if hazards != null:
		for it in hazards.items:
			if it["type"] == "radcask" and it["state"] == "open" and (it["p"] as Vector2).distance_to(p) <= CASK_R * 32.0:
				rate = maxf(rate, CASK_RATE)
	return rate


func step(dt: float, center: Vector2) -> void:
	_anim += dt
	view_center = center
	_sync_t -= dt
	if _sync_t <= 0.0 and map != null and map is WorldMap:
		_sync_t = 0.5
		_sync_props()
	_mote_t -= dt
	if _mote_t <= 0.0:
		_mote_t = 0.25
		_pick_motes()
	queue_redraw()


## 화면 안(가로 22 · 세로 13칸) 지대 칸 중 해시로 7칸에 하나꼴 — 선량이 셀수록 더 많이
func _pick_motes() -> void:
	_motes.clear()
	var c := Vector2i(floori(view_center.x / 32.0), floori(view_center.y / 32.0))
	for y in range(c.y - 7, c.y + 7):
		for x in range(c.x - 11, c.x + 12):
			var h := absi((x * 73856093) ^ (y * 19349663)) % 11
			if h > 2:
				continue
			var p := Vector2(x * 32 + 16, y * 32 + 16)
			var r := dose_at(p)
			if r <= 0.0 or (r < 3.0 and h > 0) or (r < 8.0 and h > 1):
				continue
			if map != null and map.is_solid(Vector2i(x, y)):
				continue
			_motes.append([p + Vector2(float((x * 7 + y * 3) % 13 - 6), float((x * 5 + y * 11) % 9 - 4)), float((x + y * 3) % 7) * 0.4])


func _draw() -> void:
	var tex := CombatFx.sheet()
	for m in _motes:
		var fr := int((_anim + float(m[1])) * 4.0) % 3
		var rg := CombatFx.region("zone_rad", 0.0, fr)
		draw_texture_rect_region(tex, Rect2((m[0] as Vector2) - rg.size * 0.5, rg.size), rg, Color(1, 1, 1, 0.85))
	for s in srcs:                                                        # 웅덩이 · 드럼 위 아지랑이(멀면 그리지 않는다)
		if (s["p"] as Vector2).distance_to(view_center) > 420.0:
			continue
		var fr := int(_anim * 4.0 + (s["p"] as Vector2).x * 0.1) % 3
		var rg := CombatFx.region("zone_rad", 0.0, fr)
		var o := Vector2(0, -6.0 if s["puddle"] else -26.0)
		draw_texture_rect_region(tex, Rect2((s["p"] as Vector2) + o - rg.size * 0.5, rg.size), rg)
	if hazards != null:
		for it in hazards.items:                                          # 열린 차폐 용기: 큰 빛 고리
			if it["type"] == "radcask" and it["state"] == "open":
				var k := int(_anim * 5.0) % 3
				for i in 5:
					var rg := CombatFx.region("zone_rad", 0.0, (k + i) % 3)
					var o := Vector2(cos(i * 1.26 + _anim) * 34.0, sin(i * 1.26 + _anim) * 18.0 - 10.0)
					draw_texture_rect_region(tex, Rect2((it["p"] as Vector2) + o - rg.size * 0.5, rg.size), rg)
	if ord != null:
		for z in ord.zones:                                               # 임시 지대(차 · 핵): 둘레 점선 + 안쪽 아지랑이
			if z["kind"] != "rad":
				continue
			var r := float(z["r"])
			var fade := clampf(float(z["t"]) / 2.0, 0.0, 1.0)
			draw_arc(z["p"], r, 0.0, TAU, 40, Color(0.49, 0.84, 0.17, 0.35 * fade), 1.0)
			for i in 8:
				var rg := CombatFx.region("zone_rad", 0.0, (int(_anim * 4.0) + i) % 3)
				var o := Vector2(cos(i * 0.785) * r * 0.6, sin(i * 0.785) * r * 0.45)
				draw_texture_rect_region(tex, Rect2((z["p"] as Vector2) + o - rg.size * 0.5, rg.size), rg, Color(1, 1, 1, fade))
