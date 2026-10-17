## 던전 확인 장면(단계 1-D, 1-D 계획 §1 · SD-09a L-R02-17): 대방 지하차도(DB-01)의 북쪽 경사로 · 보행로 · 반쯤 잠긴 버스 · 펌프실 · 남쪽 경사로와
## 월드의 두 입구(북 · 남)를 찍고, 출구가 각 입구 앞으로 나오는지 · 침수 칸 이동 배수 · 층 표시를 확인한다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/dungeon_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var steps: Array = []
var i := 0
var t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 8)
	host.body = "adult"
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 30.  10:20"
	host.enter("DB-01", "from_N")
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0
	_freeze()
	steps = [
		[func() -> void:
			_check(host._place_name().ends_with("대방 지하차도 · 지하"), "층 표시 '%s'" % host._place_name())
			_check(host.combat.enemies.any(func(e): return str(e.who) == "N-R02-048"), "북쪽 경사로에 대방 분대(배수관)")
			_at(3, 13), "01_north_ramp"],
		[func() -> void: _at(15, 11), "02_walkway"],
		[func() -> void:
			_at(21, 15)
			_check(host.map.wet_at(Vector2i(21, 15)) == 2, "버스 둘레는 허리 물(F)"), "03_bus"],
		[func() -> void:
			_check(is_equal_approx(host.player.loco.terrain_mul, 0.6), "허리 물 이동 ×0.6(%.2f)" % host.player.loco.terrain_mul)
			_at(28, 5), "04_pump"],
		[func() -> void: _at(48, 13), "05_south_ramp"],
		[func() -> void:
			host.enter("W", "L-R02-17>from_N")
			_check(host.map.tile_of(host.player.loco.logical) == Vector2i(819, 1164), "북쪽 출구 → 북쪽 입구 앞"), "06_world_north"],
		[func() -> void:
			host.enter("W", "L-R02-17>from_S")
			_check(host.map.tile_of(host.player.loco.logical) == Vector2i(819, 1189), "남쪽 출구 → 남쪽 입구 앞"), "07_world_south"],
	]


func _freeze() -> void:
	for e in host.combat.enemies:
		if is_instance_valid(e):
			e.set_process(false)
			e.set_physics_process(false)


func _at(x: int, y: int) -> void:
	host.player.loco.place(Vector2(x * 32 + 16, y * 32 + 16))
	host.player.position = host.player.loco.render
	host.player.loco.facing = 2


func _process(dt: float) -> void:
	t += dt
	if t < 1.2:
		return
	if i >= steps.size():
		print("던전 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
		get_tree().quit()
		return
	if t < 1.2 + 0.0001:
		return
	var s: Array = steps[i]
	if not s.has(&"done"):
		(s[0] as Callable).call()
		s.append(&"done")
		t = 0.4
		return
	await _shot(str(s[1]))
	i += 1
	t = 0.4


func _shot(nm: String) -> void:
	if shots == "":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(nm + ".png"))


func _check(ok: bool, what: String) -> void:
	checks.append([ok, what])
	print(("○ " if ok else "✕ ") + what)
