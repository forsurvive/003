## 단계 T 시험 구역: 관악산 비탈 청크 월드 + S-07 정문 실내, 문 전환, 디버그 표시.
## 인자: -- --autopilot (정해진 입력 순서로 걸어 다닌다: 화면 녹화·회귀 시험용)
extends Node2D

var world: ChunkWorld
var interior: InteriorRoom
var player: Actor
var cam: Camera2D
var hud: Label
var fade: ColorRect
var area                                      ## 지금 플레이어가 있는 곳(world 또는 interior)
var ui_font: FontFile
var autopilot: Array = []
var _ap_t := 0.0
var _fading := 0.0
var _fade_to := ""
var frames := 0


func _ready() -> void:
	ui_font = load("res://assets/fonts/Galmuri11.ttf")
	ui_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	ui_font.hinting = TextServer.HINTING_NONE
	ui_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	world = ChunkWorld.new()
	world.y_sort_enabled = true
	add_child(world)
	area = world
	var sp: Array = world.index["spawns"]["player"]
	player = Actor.new()
	player.setup("pc_comp_t01_pf00_loco", Vector2(sp[0] * 32 + 16, sp[1] * 32 + 16), world)
	world.add_child(player)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.add_theme_font_override("font", ui_font)
	hud.add_theme_font_size_override("font_size", 12)
	hud.add_theme_color_override("font_color", Color("e9e4d8"))
	hud.add_theme_color_override("font_shadow_color", Color("0b0a0d"))
	hud.add_theme_constant_override("shadow_offset_x", 1)
	hud.add_theme_constant_override("shadow_offset_y", 1)
	hud.position = Vector2(6, 4)
	layer.add_child(hud)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.size = Vector2(1280, 720)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade)
	if "--autopilot" in OS.get_cmdline_user_args():
		# [초, 입력 x, 입력 y, 모드]  봉천 쪽 비탈을 돌아 정문으로 들어갔다가 나온다
		autopilot = [[0.5, 0, 0, "run"], [1.0, 1, 0, "run"], [0.8, 1, 1, "run"], [0.6, 0, 1, "walk"],
			[1.6, -1, 0, "run"], [0.8, -1, -1, "run"], [0.5, 1, 0, "walk"], [0.9, 0, -1, "run"],
			[0.6, 0, 0, "run"], [0.7, 0, -1, "walk"], [0.5, 0, 0, "run"], [1.2, 0, 1, "run"], [0.6, 0, 1, "walk"],
			[1.0, 0, 0, "run"]]


func _input_vector() -> Vector2:
	if not autopilot.is_empty():
		var t := _ap_t
		for seg in autopilot:
			if t < seg[0]:
				player.mode = seg[3]
				return Vector2(seg[1], seg[2])
			t -= seg[0]
		return Vector2.ZERO
	player.mode = "walk" if Input.is_action_pressed("walk_hold") else "run"
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _physics_process(dt: float) -> void:
	frames += 1
	_ap_t += dt
	if _fading > 0.0:
		_fade_step(dt)
		return
	player.move(_input_vector(), dt)
	area.update_focus(player.loco.logical)
	cam.position = player.loco.logical.round()
	_check_door()
	_hud()


func _check_door() -> void:
	var t := Vector2i(floori(player.loco.logical.x / 32), floori(player.loco.logical.y / 32))
	if area == world:
		for ob in world.objects:
			var half := int(ob.get("w", 1)) / 2
			if ob["type"] == "door" and absi(t.x - int(ob["x"])) <= half and t.y <= int(ob["y"]) + 1 \
					and t.y >= int(ob["y"]) and player.loco.facing == 6:
				_start_fade("in")
	elif t.y >= interior.exit_tile.y:
		_start_fade("out")


func _start_fade(to: String) -> void:
	_fade_to = to
	_fading = 0.5


## 실내 문 전환: 페이드만(SD-12 §1 '실내 문은 페이드만')
func _fade_step(dt: float) -> void:
	var before := _fading
	_fading -= dt
	var a := 1.0 - absf(_fading - 0.25) / 0.25
	fade.color = Color(0, 0, 0, snappedf(clampf(a, 0.0, 1.0), 0.25))
	if before > 0.25 and _fading <= 0.25:
		_swap()
	if _fading <= 0.0:
		fade.color = Color(0, 0, 0, 0)


func _swap() -> void:
	var at: Vector2
	if _fade_to == "in":
		if interior == null:
			interior = InteriorRoom.new()
			add_child(interior)
		world.visible = false
		interior.visible = true
		player.get_parent().remove_child(player)
		interior.add_child(player)
		area = interior
		at = interior.entry_px
		player.loco.facing = 6
	else:
		interior.visible = false
		world.visible = true
		player.get_parent().remove_child(player)
		world.add_child(player)
		area = world
		var d: Dictionary = world.objects.filter(func(o): return o["type"] == "door")[0]
		at = Vector2(int(d["x"]) * 32 + 16, (int(d["y"]) + 2) * 32 + 8)
		player.loco.facing = 2
	player.world = area
	player.loco.logical = at
	player.loco.render = at.round()
	player.loco.motion = "idle"
	player.position = player.loco.render
	cam.position = at.round()


func _hud() -> void:
	var l := player.loco
	hud.text = "단계 T 시험 구역  %s\n청크 %d개 · 붙이기 최대 %.2fms · %d fps\n%s %s 프레임 %d  타일 (%d, %d)" % [
		"관악산 비탈" if area == world else "볼트 S-07 정문 안", world.loaded.size(), world.attach_usec_max / 1000.0,
		Engine.get_frames_per_second(), l.motion, Locomotion.DIRS[l.facing], l.frame,
		floori(l.logical.x / 32), floori(l.logical.y / 32)]
