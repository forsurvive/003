## 그림체 비교 샘플: '바인딩 오브 아이작'풍 방(볼트 S-07 정문 앞 공터). 그림만 바꾸고 이동 규칙은 본편 그대로
## (Locomotion 거리 구동·미끄러짐 금지, 몸은 이동 방향·머리는 조준 방향).
## 실행: godot --path game res://scenes/style/isaac_room.tscn   WASD 이동, 마우스 조준, 왼쪽 클릭 사격, R 다시 놓기
##       -- --demo  정해진 길을 돌며 가장 가까운 적을 쏜다(녹화용)
extends Node2D

const DIR := "res://assets/style_isaac/"
var meta: Dictionary
var solid := {}
var player: IsaacChar
var soldiers: Array = []
var roaches: Array = []
var bullets: Array = []
var decals: Node2D
var splats := {}
var demo := false
var t := 0.0
var _cool := 0.0
var _respawn := -1.0
var rng := RandomNumberGenerator.new()
var font: Font
const ROUTE := [Vector2(400, 240), Vector2(420, 150), Vector2(300, 110), Vector2(190, 170), Vector2(190, 290), Vector2(280, 312), Vector2(420, 312)]
var _route_i := 0


func _ready() -> void:
	rng.seed = 2277
	RenderingServer.set_default_clear_color(Color("0b0a0d"))
	meta = JSON.parse_string(FileAccess.get_file_as_string(DIR + "isaac.json"))
	for c in meta["solids"]:
		solid[Vector2i(int(c[0]), int(c[1]))] = true
	var bg := Sprite2D.new()
	bg.texture = load(DIR + "room.png")
	bg.centered = false
	bg.z_index = -20
	add_child(bg)
	decals = Node2D.new()
	decals.z_index = -10
	add_child(decals)
	for k in ["blood", "ichor"]:
		splats[k] = load(DIR + "splat_%s.png" % k)
	y_sort_enabled = true
	font = load("res://assets/fonts/Galmuri9.ttf")
	var cam := Camera2D.new()
	cam.position = Vector2(320, 180)
	add_child(cam)
	cam.make_current()
	demo = "--demo" in OS.get_cmdline_user_args()
	player = IsaacChar.new()
	player.setup("pc", Vector2(300, 236), self, meta)
	add_child(player)
	_spawn()
	var hud := CanvasLayer.new()
	add_child(hud)
	var l := Label.new()
	l.text = "그림체 비교 샘플 · 아이작풍   WASD 이동 · 마우스 조준 · 클릭 사격 · R 다시"
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Color("cbc5b9"))
	l.add_theme_color_override("font_shadow_color", Color("0b0a0d"))
	l.position = Vector2(6, 2)
	hud.add_child(l)


func _spawn() -> void:
	for s in soldiers + roaches:
		s.queue_free()
	soldiers.clear()
	roaches.clear()
	var s := IsaacChar.new()
	s.setup("soldier", Vector2(470, 110), self, meta)
	s.hp = 4
	add_child(s)
	soldiers.append(s)
	for p in [Vector2(110, 290), Vector2(150, 300), Vector2(540, 300)]:
		var r := IsaacRoach.new()
		r.setup(p, self)
		add_child(r)
		roaches.append(r)


## 원 충돌: 막히기 직전까지만(벽을 따라 미끄러지지 않는다)
func move_circle(a: Vector2, b: Vector2, r: float) -> Vector2:
	return Sweep.move(a, b, r, _hits)


func circle_hits(c: Vector2, r: float) -> bool:
	return _hits(c, r)


func _hits(c: Vector2, r: float) -> bool:
	for ty in range(floori((c.y - r) / 32), floori((c.y + r) / 32) + 1):
		for tx in range(floori((c.x - r) / 32), floori((c.x + r) / 32) + 1):
			if solid.has(Vector2i(tx, ty)):
				var q := Vector2(clampf(c.x, tx * 32, tx * 32 + 32), clampf(c.y, ty * 32, ty * 32 + 32))
				if q.distance_to(c) < r:
					return true
	return false


func _physics_process(dt: float) -> void:
	t += dt
	_cool = maxf(0.0, _cool - dt)
	if Input.is_key_pressed(KEY_R):
		_spawn()
	# 주인공
	var inp: Vector2
	var aim_pt := get_global_mouse_position()
	var want := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var target = _nearest()
	if demo:
		var goal: Vector2 = ROUTE[_route_i]
		if player.loco.logical.distance_to(goal) < 10:
			_route_i = (_route_i + 1) % ROUTE.size()
		inp = goal - player.loco.logical
		aim_pt = target.loco.logical + Vector2(0, -10) if target != null else player.loco.logical + Vector2(0, 40)
		want = target != null and int(t * 3) % 4 != 3
	else:
		inp = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var from := player.loco.logical + Vector2(0, -12)
	player.aim_dir = Locomotion.snap8(aim_pt - from, 0.0)
	player.move(inp, dt, "run")
	if want and _cool <= 0.0:
		_cool = 0.28
		player.face_t = 0.14
		_fire(from, (aim_pt - from).normalized().rotated(rng.randf_range(-0.04, 0.04)), "player")
	# 계엄병: 위쪽을 오가다 주인공을 보면 멈춰 쏜다
	for s in soldiers:
		var to: Vector2 = player.loco.logical - s.loco.logical
		s.aim_dir = Locomotion.snap8(to, 0.0)
		var go := Vector2(1 if int(t / 2.5) % 2 == 0 else -1, 0)
		s.move(go if to.length() > 7 * 32 else Vector2.ZERO, dt, "walk")
		if to.length() < 9 * 32 and fmod(t + 0.3, 1.6) < dt:
			s.face_t = 0.14
			_fire(s.loco.logical + Vector2(0, -12), to.normalized().rotated(rng.randf_range(-0.12, 0.12)), "enemy")
	# 큰바퀴: 주인공 쪽으로 종종걸음, 붙으면 문다
	for r in roaches:
		var to2: Vector2 = player.loco.logical - r.loco.logical
		r.move(to2 if to2.length() > 14 else Vector2.ZERO, dt)
		if to2.length() <= 16 and fmod(t, 0.8) < dt:
			player.flash = 0.15
	_step_bullets(dt)
	if soldiers.is_empty() and roaches.is_empty():
		if _respawn < 0.0:
			_respawn = 1.5
		_respawn -= dt
		if _respawn <= 0.0:
			_respawn = -1.0
			_spawn()
	queue_redraw()


func _nearest():
	var best = null
	var bd := 1e9
	for e in soldiers + roaches:
		var d: float = e.loco.logical.distance_to(player.loco.logical)
		if d < bd:
			bd = d
			best = e
	return best


func _fire(p: Vector2, dir: Vector2, team: String) -> void:
	bullets.append({"p": p + dir * 10.0, "v": dir * (460.0 if team == "player" else 300.0), "team": team, "life": 1.4})


func _step_bullets(dt: float) -> void:
	var keep := []
	for b in bullets:
		var hit := false
		for k in 4:                                                    # 짧게 나눠 움직여 얇은 표적도 맞힌다
			b["p"] += b["v"] * dt / 4.0
			var tp := Vector2i(floori(b["p"].x / 32), floori(b["p"].y / 32))
			if solid.has(tp) and b["p"].y > 70:
				hit = true
				break
			var targets: Array = (soldiers + roaches) if b["team"] == "player" else [player]
			for e in targets:
				if b["p"].distance_to(e.loco.logical + Vector2(0, -10)) < 11.0:
					_damage(e)
					hit = true
					break
			if hit:
				break
		b["life"] -= dt
		if not hit and b["life"] > 0.0:
			keep.append(b)
	bullets = keep


func _damage(e) -> void:
	e.flash = 0.12
	if e == player:
		return
	e.hp -= 1
	if e.hp > 0:
		return
	var s := Sprite2D.new()                                           # 바닥에 남는 자국
	s.texture = splats["ichor" if e is IsaacRoach else "blood"]
	s.hframes = 4
	s.frame = rng.randi() % 4
	s.position = e.loco.logical + Vector2(0, -4)
	decals.add_child(s)
	soldiers.erase(e)
	roaches.erase(e)
	e.queue_free()


func _draw() -> void:
	for b in bullets:
		var p: Vector2 = (b["p"] as Vector2).round()
		var tail: Vector2 = (p - (b["v"] as Vector2).normalized() * 5.0).round()
		var col := Color("e8c23a") if b["team"] == "player" else Color("e04a35")
		draw_line(tail, p, Color("1a181d"), 3.0)
		draw_line(tail, p, col, 1.0)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color("ffec9a"))
