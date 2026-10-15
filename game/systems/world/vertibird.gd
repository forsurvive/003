## 계엄군 버티버드(단계 1-7, SD-03a §8.6 MQ-106 · SD-16 §13.6 '픽처 없이 맵 위 인게임 연출'): 그림자 + 기체 + 회전익 둘.
## 날아옴(높이 220px, 화면 밖 북서쪽에서) → 하강(높이 220 → 0, 끝으로 갈수록 느리게 — 그림자가 작은 칸에서 큰 칸으로 커진다) →
## 착지 1.2초 전부터 회전익 바람에 먼지가 일고, 닿는 순간 화면이 흔들린다 → 내려앉은 동안 기체 밑 칸을 막고 엄폐가 된다(WorldMap.overrides)
## → 이륙은 거꾸로(올라가며 남동쪽으로 빠진다). 반투명 없음: 그림자는 디더 칸, 먼지는 줄어드는 점.
## 노드 위치 = 기체가 땅에 닿는 점(스키드 줄). y 정렬 층(map.objects)에 들어가 인물과 앞뒤를 가린다.
class_name Vertibird
extends Node2D

signal landed
signal gone

const SHEET := "res://assets/sprites/vertibird.png"
const META := "res://assets/sprites/vertibird.json"
const GROUND_Y := 129.0                    ## 기체 칸 안에서 스키드가 땅에 닿는 줄(vertibird.py CY + 29)
const ALT_HIGH := 220.0
const FLY_SECS := 6.0
const DESCEND_SECS := 6.0
const LIFT_SECS := 5.0
var tex: Texture2D
var meta: Dictionary
var alt := ALT_HIGH
var state := "idle"                        ## fly | descend | landed | lift | gone
var t := 0.0
var door_open := false
var grille := false                        ## 화물칸 철창(하도윤이 잠긴 채)
var rotor_t := 0.0
var dust: Array = []                       ## [위치(노드 기준), 속도, 남은 초, 처음 크기]
var world                                  ## WorldMap(칸 막기)
var cam: Camera2D
var land_at := Vector2.ZERO
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _cells: Array = []                     ## [칸, 옛 overrides 값(없으면 null)]
var _shake := 0.0
var _rng := RandomNumberGenerator.new()


func setup(w, camera: Camera2D, at: Vector2) -> Vertibird:
	world = w
	cam = camera
	land_at = at
	tex = load(SHEET)
	meta = JSON.parse_string(FileAccess.get_file_as_string(META))
	_rng.seed = int(at.x * 3 + at.y * 7)
	z_index = 0
	return self


## 날아와서 내려앉는다(화면 밖 북서쪽에서)
func arrive() -> void:
	_from = land_at + Vector2(-560, -300)
	_to = land_at
	position = _from
	alt = ALT_HIGH
	state = "fly"
	t = 0.0


## 바로 내려앉은 채로(불러온 판 · 시험)
func sit() -> void:
	position = land_at
	alt = 0.0
	state = "landed"
	_block(true)


## 떠난다(올라가며 남동쪽으로)
func leave() -> void:
	if state == "gone" or state == "lift":
		return
	_block(false)
	door_open = false
	grille = false
	_from = position
	_to = position + Vector2(620, -260)
	state = "lift"
	t = 0.0


func _process(dt: float) -> void:
	rotor_t += dt
	t += dt
	z_index = 4 if alt > 24.0 else 0                                       # 높이 떠 있으면 건물·인물 위로(y 정렬 밖)
	match state:
		"fly":
			var k := minf(1.0, t / FLY_SECS)
			var e := 1.0 - pow(1.0 - k, 2.0)
			position = _from.lerp(_to, e)
			if k >= 1.0:
				state = "descend"
				t = 0.0
		"descend":
			var k := minf(1.0, t / DESCEND_SECS)
			alt = ALT_HIGH * pow(1.0 - k, 2.2)
			if alt < 70.0:
				_kick_dust(dt, 1.0 - alt / 70.0)
			if k >= 1.0:
				alt = 0.0
				state = "landed"
				_shake = 0.5
				for i in 26:
					_dust_one(1.6)
				_block(true)
				landed.emit()
		"landed":
			if _rng.randf() < dt * 6.0:
				_dust_one(0.6)
		"lift":
			var k := minf(1.0, t / LIFT_SECS)
			alt = ALT_HIGH * 1.4 * pow(k, 1.6)
			position = _from.lerp(_to, pow(k, 2.0))
			if alt < 60.0:
				_kick_dust(dt, 1.0 - alt / 60.0)
			if k >= 1.0:
				state = "gone"
				gone.emit()
				queue_free()
	for p in dust:
		p[0] += p[1] * dt
		p[1] *= 1.0 - minf(1.0, dt * 1.6)
		p[2] -= dt
	dust = dust.filter(func(p): return p[2] > 0.0)
	if _shake > 0.0 and cam != null:
		_shake -= dt
		cam.offset = Vector2(_rng.randi_range(-3, 3), _rng.randi_range(-2, 2)) if _shake > 0.0 else Vector2.ZERO
	queue_redraw()


func _kick_dust(dt: float, power: float) -> void:
	var n := int(ceil(dt * 40.0 * power))
	for i in n:
		_dust_one(power)


## 먼지 한 점: 기체 밑 땅에서 바깥으로 퍼진다(회전익 바람)
func _dust_one(power: float) -> void:
	var a := _rng.randf() * TAU
	var r := Vector2(cos(a) * 60.0, sin(a) * 20.0)
	var gp := (land_at - position) if state != "landed" else Vector2.ZERO
	var v := Vector2(cos(a) * 1.0, sin(a) * 0.4) * _rng.randf_range(60.0, 150.0) * (0.5 + power)
	dust.append([gp + r + Vector2(0, 4), v, _rng.randf_range(0.5, 1.2), _rng.randi_range(2, 4)])


# ---------------------------------------------------------------- 칸 막기(내려앉은 동안 기체 밑 = 벽 · 높은 엄폐)
func cells() -> Array:
	var out: Array = []
	var c: Vector2i = world.tile_of(land_at)
	for dy in range(-1, 1):
		for dx in range(-3, 4):
			out.append(c + Vector2i(dx, dy))
	out.append(c + Vector2i(0, 1))                                      # 남쪽 날개 끝 엔진(앞)
	out.append(c + Vector2i(0, -2))                                     # 북쪽 날개 끝 엔진(뒤)
	return out


func _block(on: bool) -> void:
	if world == null or not ("overrides" in world):
		return
	if on:
		_cells.clear()
		for c in cells():
			_cells.append([c, world.overrides.get(c)])
			world.overrides[c] = [1, 2]
	else:
		for pair in _cells:
			if pair[1] == null:
				world.overrides.erase(pair[0])
			else:
				world.overrides[pair[0]] = pair[1]
		_cells.clear()


func _exit_tree() -> void:
	_block(false)
	if cam != null:
		cam.offset = Vector2.ZERO


# ---------------------------------------------------------------- 그리기
func _frame(name: String) -> Rect2:
	var f: Array = meta["frames"][name]
	return Rect2(f[0], f[1], f[2], f[3])


func _draw() -> void:
	if tex == null:
		return
	var sz: Array = meta["size"]
	var bw := float(sz[0])
	# 그림자: 땅 위(노드가 움직이는 동안은 착지점 쪽이 아니라 기체 바로 밑)
	var si := 0 if alt > 150.0 else (1 if alt > 90.0 else (2 if alt > 30.0 else 3))
	var sr := _frame("shadow%d" % si)
	draw_texture_rect_region(tex, Rect2(Vector2(-sr.size.x / 2.0, -sr.size.y / 2.0 + 4.0), sr.size), sr)
	for p in dust:                                                       # 먼지(그림자 위, 기체 아래)
		var s := maxf(1.0, float(p[3]) * minf(1.0, float(p[2]) / 0.6))
		draw_rect(Rect2((p[0] as Vector2).round() - Vector2(s, s) / 2.0, Vector2(s, s)), Color("CBC5B9") if int(p[3]) % 2 == 0 else Color("ABA49A"))
	var top := Vector2(-bw / 2.0, -GROUND_Y - alt).round()
	var br := _frame("body_open" if door_open else "body")
	draw_texture_rect_region(tex, Rect2(top, br.size), br)
	if door_open and grille:                                             # 화물칸 철창(잠김): 문 칸 위 세로 창살
		var d: Array = meta["door"]
		for x in range(int(d[0]) + 3, int(d[0]) + int(d[2]) - 1, 4):
			draw_rect(Rect2(top + Vector2(x, float(d[1]) + 1.0), Vector2(1, float(d[3]) - 2.0)), Color("8B857D"))
		draw_rect(Rect2(top + Vector2(float(d[0]) + 1.0, float(d[1]) + 1.0), Vector2(float(d[2]) - 2.0, 1)), Color("8B857D"))
		draw_rect(Rect2(top + Vector2(float(d[0]) + float(d[2]) - 9.0, float(d[1]) + 10.0), Vector2(4, 4)), Color("B08A1C"))   # 맹꽁이 자물쇠
	var fi := int(rotor_t * (24.0 if state != "landed" or not door_open else 14.0)) % 3
	var rr := _frame("rotor%d" % fi)
	for at in meta["rotor_at"]:
		draw_texture_rect_region(tex, Rect2(top + Vector2(float(at[0]), float(at[1])) - rr.size / 2.0, rr.size), rr)


## 화물칸 문 앞 땅(사람이 서서 말을 거는 칸) — 월드 좌표
func door_ground() -> Vector2:
	var d: Array = meta["door"]
	var sz: Array = meta["size"]
	return land_at + Vector2(float(d[0]) + float(d[2]) / 2.0 - float(sz[0]) / 2.0, 22.0)


## 문 안(화물칸에 앉은 사람의 발 자리) — 월드 좌표. 사람은 z_index를 올려 기체 앞에 그린다
func door_seat() -> Vector2:
	var d: Array = meta["door"]
	var sz: Array = meta["size"]
	return land_at + Vector2(float(d[0]) + float(d[2]) / 2.0 - float(sz[0]) / 2.0, float(d[1]) + float(d[3]) - GROUND_Y + 5.0)   # 문턱에 걸터앉음(문 앞 칸에서 말이 닿는다)
