## 단계 T 시험 구역: 관악산 비탈 청크 월드 + S-07 정문 실내, 문 전환, 실시간 전투(권총·진압봉 대 큰바퀴·보병 계엄병).
## 인자(-- 뒤): --autopilot  정해진 입력으로 걸어서 정문을 드나든다
##              --combat     적 쪽으로 이동하며 가장 가까운 적을 조준·사격한다(녹화·회귀 시험용)
extends Node2D

var world: ChunkWorld
var interior: InteriorRoom
var player: Actor
var pc := Combatant.new()
var cam: Camera2D
var hud: Label
var fade: ColorRect
var area
var ui_font: FontFile
var autopilot: Array = []
var combat_bot := false
var _ap_t := 0.0
var _fading := 0.0
var _fade_to := ""
var frames := 0
var shots: Projectiles
var nav := NavGrid.new()
var enemies: Array = []
var weapons: Dictionary
var weapon_id := "W-002"
var mag := 12
var _reload := 0.0
var _cool := 0.0
var _nav_dirty := true
var _nav_t := 0.0
var _nav_center := Vector2i(-999, -999)
var _token_t := 0.0
var ai_usec := 0
var ai_usec_max := 0
var _dead_t := 0.0
var msg := ""
var passive := false
var save_rt := false
var touch: TouchUI
var touch_demo := false
var _touch_shot := false
var _touch_last := Vector2.RIGHT
var _demo_t := 0.0
var soak := false
var soak_stats := {"waves": 0, "saves": 0, "save_diffs": 0, "deaths": 0}
var _step_sound_t := 0.0
var stats := {"enemy_shots": 0, "player_hits_taken": 0, "bites": 0}
const SKILL := 30.0                           ## 태그 스킬 초기값(SD-10)


func _ready() -> void:
	ui_font = load("res://assets/fonts/Galmuri11.ttf")
	ui_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	ui_font.hinting = TextServer.HINTING_NONE
	ui_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	weapons = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	var erows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	world = ChunkWorld.new()
	world.y_sort_enabled = true
	add_child(world)
	world.chunk_attached.connect(_on_chunk)
	area = world
	var sp: Array = world.index["spawns"]["player"]
	player = Actor.new()
	player.setup("pc_comp_t01_pf00_loco", Vector2(sp[0] * 32 + 16, sp[1] * 32 + 16), world)
	world.add_child(player)
	pc.actor = player
	pc.team = "player"
	pc.max_hp = 200.0                                          # 90 + EN5×20 + Lv1×10 (SD-10 §2.3)
	pc.hp = pc.max_hp
	shots = Projectiles.new()
	shots.world = world
	world.add_child(shots)
	shots.combatants.append(pc)
	for id in ["CR-002", "CR-401"]:
		for p in world.index["spawns"][id]:
			var e := Enemy.new()
			# 보병 계엄병의 주무기(레이저 소총·돌격소총)는 단계 T 무기 범위 밖이라 시험용으로 W-002를 든다
			e.setup_enemy(erows[id], weapons["W-002"], Vector2(p[0] * 32 + 16, p[1] * 32 + 16), world)
			world.add_child(e)
			enemies.append(e)
			shots.combatants.append(e.cmb)
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
	var args := OS.get_cmdline_user_args()
	if "--autopilot" in args:
		autopilot = [[0.5, 0, 0, "run"], [1.0, 1, 0, "run"], [0.8, 1, 1, "run"], [0.6, 0, 1, "walk"],
			[1.6, -1, 0, "run"], [0.8, -1, -1, "run"], [0.5, 1, 0, "walk"], [0.9, 0, -1, "run"],
			[0.6, 0, 0, "run"], [0.7, 0, -1, "walk"], [0.5, 0, 0, "run"], [1.2, 0, 1, "run"], [0.6, 0, 1, "walk"],
			[1.0, 0, 0, "run"]]
	combat_bot = "--combat" in args or "--save-roundtrip" in args
	touch_demo = "--touch-demo" in args
	if "--touch" in args or touch_demo or DisplayServer.is_touchscreen_available():
		touch = TouchUI.new()
		add_child(touch)
		touch.fire_released.connect(_touch_fire)
		Input.emulate_touch_from_mouse = true
	save_rt = "--save-roundtrip" in args
	soak = "--soak" in args
	if soak:
		combat_bot = true
	passive = "--passive" in args


func _input_vector() -> Vector2:
	if passive:
		player.mode = "run"
		var tgt: Array = world.index["spawns"]["CR-401"][0]
		var front := Vector2(tgt[0] * 32 + 16, (tgt[1] + 6) * 32 + 16)      # 계엄병 정면(남쪽) 6t에 선다
		var d := front - player.loco.logical
		return d if d.length() > 8 else Vector2.ZERO
	if combat_bot:
		return _bot_move()
	if not autopilot.is_empty():
		var t := _ap_t
		for seg in autopilot:
			if t < seg[0]:
				player.mode = seg[3]
				return Vector2(seg[1], seg[2])
			t -= seg[0]
		return Vector2.ZERO
	if touch != null and (touch.move != Vector2.ZERO or touch_demo):
		player.mode = "run" if touch.move.length() > 0.9 else "walk"           # 끝까지 밀면 달리기
		return touch.move
	player.mode = "walk" if Input.is_action_pressed("walk_hold") or Input.is_action_pressed("aim") else "run"
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _physics_process(dt: float) -> void:
	frames += 1
	_ap_t += dt
	if _fading > 0.0:
		_fade_step(dt)
		return
	if pc.dead:
		_dead_t += dt
		if _dead_t > 2.0:
			_respawn()
	else:
		player.move(_input_vector(), dt)
		_player_combat(dt)
		_step_sound_t -= dt
		if player.loco.motion != "idle" and _step_sound_t <= 0.0:      # 이동 소음: 달리기 2.0t·걷기 1.5t (§2.4)
			_step_sound_t = 0.5
			for e in enemies:
				e.hear("move" if player.mode == "run" else "sneak", player.loco.logical)
	area.update_focus(player.loco.logical)
	if area == world:
		_combat_tick(dt)
	cam.position = player.loco.logical.round()
	if not pc.dead:
		_check_door()
	if touch_demo:
		_touch_demo_step(dt)
	if save_rt and frames == 300:
		_save_roundtrip()
	if soak:
		_soak_step()
	if not combat_bot and Input.is_action_just_pressed("save"):
		SaveGame.write_atomic("user://quick.sav", SaveGame.encode({"name": "빠른 저장"}, capture()))
		msg = "빠른 저장"
	if not combat_bot and Input.is_action_just_pressed("load"):
		var r := SaveGame.read("user://quick.sav")
		if r["ok"]:
			apply(r["world"])
			msg = "불러오기"
	_hud()


# ---------------------------------------------------------------- combat
func _combat_tick(dt: float) -> void:
	_nav_t += dt
	if world.focus != _nav_center and world.focus.x > -999:
		_nav_center = world.focus
		_nav_dirty = true
	if _nav_dirty and _nav_t >= 0.5 and world.focus.x > -999:
		nav.rebuild(world, world.focus, world.cs)
		_nav_dirty = false
		_nav_t = 0.0
	nav.new_frame()
	_token_t += dt
	if _token_t >= 1.5:                                           # 공격 토큰: 원거리 3 (난이도 보통, §7.4)
		_token_t = 0.0
		var cands := enemies.filter(func(e): return e.style == "shooter" and not e.cmb.dead)
		cands.sort_custom(func(a, b): return a.loco.logical.distance_to(pc.pos()) < b.loco.logical.distance_to(pc.pos()))
		for i in cands.size():
			cands[i].has_token = i < 3
	var t0 := Time.get_ticks_usec()
	for e in enemies:
		if absi(world.chunk_of_px(e.loco.logical).x - world.focus.x) <= 1 and absi(world.chunk_of_px(e.loco.logical).y - world.focus.y) <= 1:
			e.think(dt, pc, nav, shots)
	ai_usec = Time.get_ticks_usec() - t0
	ai_usec_max = maxi(ai_usec_max, ai_usec)
	shots.step(dt)
	if pc.flash > 0:
		pc.flash -= 1
	player.sprite.modulate = Color(4, 4, 4) if pc.flash > 0 else Color(1, 1, 1)


## 터치 사격: 오른쪽 스틱을 놓는 순간 쏜다. 조준 보정: 스틱 방향 반각 12° 안의 가장 가까운 적(SD-19 §6.13)
func _touch_fire() -> void:
	_touch_shot = true


func _touch_aim_point() -> Vector2:
	var dir: Vector2 = touch.aim if touch.aim != Vector2.ZERO else _touch_last
	_touch_last = dir
	var best = null
	var bd := 1e9
	for e in enemies:
		if e.cmb.dead:
			continue
		var d: Vector2 = e.loco.logical - player.loco.logical
		if absf(dir.angle_to(d)) <= deg_to_rad(12) and d.length() < bd:
			bd = d.length()
			best = e
	if best != null:
		return best.loco.logical + Vector2(0, -12)
	return player.loco.logical + Vector2(0, -14) + dir.normalized() * 200.0


func _aim_point() -> Vector2:
	if touch != null and (touch.aim != Vector2.ZERO or _touch_shot):
		return _touch_aim_point()
	if combat_bot:
		var e = _nearest_enemy()
		return e.loco.logical + Vector2(0, -12) if e != null else player.loco.logical + Vector2(32, 0)
	return get_global_mouse_position()


func _nearest_enemy():
	var best = null
	var bd := 1e9
	for e in enemies:
		if e.cmb.dead:
			continue
		var d: float = e.loco.logical.distance_to(player.loco.logical)
		if d < bd and world.line_of_sight(player.loco.logical, e.loco.logical):
			bd = d
			best = e
	return best


func _player_combat(dt: float) -> void:
	_cool = maxf(0.0, _cool - dt)
	if _reload > 0.0:
		_reload -= dt
		if _reload <= 0.0:
			mag = int(weapons["W-002"]["mag"])
		return
	if not combat_bot:
		if Input.is_action_just_pressed("reload") and weapon_id == "W-002":
			_reload = 1.5
			return
		if Input.is_key_pressed(KEY_Q) and _cool <= 0.0:
			weapon_id = "W-041" if weapon_id == "W-002" else "W-002"
			_cool = 0.3
			return
	var aim_pt := _aim_point()
	var to := aim_pt - (player.loco.logical + Vector2(0, -14))
	var aiming := combat_bot or Input.is_action_pressed("aim") or Input.is_action_pressed("fire") \
		or (touch != null and touch.aim != Vector2.ZERO)
	player.aim_dir = Locomotion.snap8(to, 0.0) if aiming else -1
	var want_fire := Input.is_action_pressed("fire") if not combat_bot else (_nearest_enemy() != null and to.length() < 9 * 32)
	if passive:
		want_fire = false
	if _touch_shot:
		want_fire = true
		_touch_shot = false
	if not want_fire or _cool > 0.0:
		return
	var w: Dictionary = weapons[weapon_id]
	if w["kind"] == "ranged":
		if mag <= 0:
			_reload = 1.5
			return
		var stance := "aim" if Input.is_action_pressed("aim") or combat_bot or (touch != null and touch.aim_full >= 0.3) else "stand"
		var sp := CombatRules.spread(SKILL, stance, player.loco.motion != "idle")
		var ang := CombatRules.shot_angle(rad_to_deg(to.angle()), sp, shots.rng)
		var muzzle := player.loco.logical + Vector2(0, -14) + to.normalized() * 10.0
		if shots.fire(muzzle, ang, 640.0, "player", w, SKILL):
			mag -= 1
			_cool = 1.0 / float(w["rate"])
			for e in enemies:
				e.hear("pistol", player.loco.logical)
	else:
		_cool = 1.0 / float(w["rate"])
		for e in enemies:                                         # 근접: 호(거리 1t + 반지름, ±60°) 안 충돌체 중심
			if e.cmb.dead:
				continue
			var d: Vector2 = e.loco.logical - player.loco.logical
			if d.length() <= float(w["range_eff"]) * 32.0 + e.cmb.radius + 8.0 and absf(to.angle_to(d)) <= deg_to_rad(60):
				var part := CombatRules.pick_part(e.cmb.weights, shots.rng)
				e.cmb.take(CombatRules.resolve({"weapon": w, "skill": SKILL, "attacker": {"str": 5}, "part": part, "dr": e.cmb.dr}),
					player.loco.logical)
				e.hear("melee", player.loco.logical)


## 활성 3×3 안의 청크가 붙거나 중심 청크가 바뀌면 경로 격자를 다시 만든다
func _on_chunk(id: String, _us: int) -> void:
	var p := id.split("-")
	var k := Vector2i(int(p[1]), int(p[2]))
	if absi(k.x - world.focus.x) <= 1 and absi(k.y - world.focus.y) <= 1:
		_nav_dirty = true


# ---------------------------------------------------------------- save (SD-19 §6.10)
func capture() -> Dictionary:
	var es := []
	for e in enemies:
		es.append({"id": e.row["id"], "home": e.brain.home, "pos": e.loco.logical, "render": e.loco.render,
			"hp": e.cmb.hp, "dead": e.cmb.dead, "state": e.brain.state, "gauge": e.brain.gauge, "facing": e.loco.facing})
	return {"area": "world" if area == world else "interior", "frames": frames,
		"player": {"pos": player.loco.logical, "render": player.loco.render, "hp": pc.hp, "mag": mag,
			"weapon": weapon_id, "facing": player.loco.facing},
		"enemies": es, "rng": shots.rng.state, "chunk_changes": {}}


func apply(st: Dictionary) -> void:
	var p: Dictionary = st["player"]
	player.loco = Locomotion.new(p["pos"])
	player.loco.render = p["render"]
	player.loco.facing = p["facing"]
	player.position = player.loco.render
	pc.hp = p["hp"]
	pc.dead = pc.hp <= 0.0
	mag = p["mag"]
	weapon_id = p["weapon"]
	for i in enemies.size():
		var e: Enemy = enemies[i]
		var d: Dictionary = st["enemies"][i]
		e.loco = Locomotion.new(d["pos"])
		e.loco.render = d["render"]
		e.loco.facing = d["facing"]
		e.position = e.loco.render
		e.cmb.hp = d["hp"]
		e.cmb.dead = d["dead"]
		e.brain.state = d["state"]
		e.brain.gauge = d["gauge"]
		e.brain.home = d["home"]
	shots.rng.state = st["rng"]
	frames = st["frames"]


func _save_roundtrip() -> void:
	var slot := {"name": "시험", "level": 1, "act": "단계 T", "where": "관악산 비탈"}
	var a := SaveGame.encode(slot, capture())
	var d := SaveGame.decode(a)
	apply(d["world"])
	var b := SaveGame.encode(slot, capture())
	print("저장 왕복: %s (%d바이트, 적 %d, 프레임 %d)" % ["바이트 동일" if a == b else "차이 있음", a.size(), enemies.size(), frames])


## 측정 항목 6 시스템 통합 시험: 스트리밍·전투·저장이 한 씬에서 계속 돈다. 적이 다 쓰러지면 다시 놓고,
## 게임 시간 5분마다 저장 왕복을 비교한다. 끝에 오류 수를 출력한다.
func _soak_step() -> void:
	if enemies.all(func(e): return e.cmb.dead):
		soak_stats["waves"] += 1
		var i := 0
		for id in ["CR-002", "CR-401"]:
			for p in world.index["spawns"][id]:
				var e: Enemy = enemies[i]
				var at := Vector2(p[0] * 32 + 16, p[1] * 32 + 16)
				e.loco = Locomotion.new(at)
				if e.style == "swarm":
					e.loco.custom = enemies[0].loco.custom if enemies[0].style == "swarm" else {}
				e.position = e.loco.render
				e.cmb.dead = false
				e.cmb.hp = e.cmb.max_hp
				e.brain = AIBrain.new(at, e.per, e.brain.kind)
				e._dead_t = 0.0
				e.sprite.modulate = Color(1, 1, 1)
				i += 1
	if pc.dead and _dead_t < 0.02:
		soak_stats["deaths"] += 1
	if frames % (60 * 300) == 0:
		var slot := {"name": "소크"}
		var a := SaveGame.encode(slot, capture())
		apply(SaveGame.decode(a)["world"])
		soak_stats["saves"] += 1
		if SaveGame.encode(slot, capture()) != a:
			soak_stats["save_diffs"] += 1


## 녹화용 터치 시연: 왼쪽 스틱으로 적 쪽으로 걷고, 오른쪽 스틱으로 조준했다가 놓아 쏜다
func _touch_demo_step(dt: float) -> void:
	_demo_t += dt
	var phase := fmod(_demo_t, 1.2)
	var e = _nearest_enemy()
	if e == null:
		var tgt: Array = world.index["spawns"]["CR-002"][0]
		_send_drag(0, Vector2(90, 280), (Vector2(tgt[0], tgt[1]) * 32.0 - player.loco.logical).normalized() * 34.0)
		return
	_send_drag(0, Vector2(90, 280), Vector2.ZERO if phase > 0.5 else (e.loco.logical - player.loco.logical).orthogonal().normalized() * 20.0)
	var aim_v: Vector2 = (e.loco.logical - player.loco.logical).normalized() * 30.0
	if phase < 0.9:
		_send_drag(1, Vector2(520, 280), aim_v)
	elif touch._right["id"] >= 0:
		var up := InputEventScreenTouch.new()
		up.index = 1
		up.pressed = false
		up.position = Vector2(520, 280) * 2.0
		Input.parse_input_event(up)


func _send_drag(idx: int, centre: Vector2, off: Vector2) -> void:
	var side: Dictionary = touch._left if idx == 0 else touch._right
	if side["id"] < 0:
		var down := InputEventScreenTouch.new()
		down.index = idx
		down.pressed = true
		down.position = centre * 2.0
		Input.parse_input_event(down)
	var dr := InputEventScreenDrag.new()
	dr.index = idx
	dr.position = (centre + off) * 2.0
	Input.parse_input_event(dr)


func _exit_tree() -> void:
	if soak:
		print("통합 시험: 게임 시간 %.1f분, 적 물결 %d, 저장 왕복 %d회(차이 %d), 주인공 쓰러짐 %d, AI 최대 %.2fms, 붙이기 최대 %.2fms" % [
			frames / 3600.0, soak_stats["waves"], soak_stats["saves"], soak_stats["save_diffs"], soak_stats["deaths"],
			ai_usec_max / 1000.0, world.attach_usec_max / 1000.0])
	if combat_bot or passive:
		var alive := enemies.filter(func(e): return not e.cmb.dead).size()
		print("전투 통계: 프레임 %d, 적 생존 %d/%d, 주인공 HP %d, 투사체 발사 %d, 명중 %d, 적 사격 %d, AI 최대 %.2fms, 경로 재구축 %.2fms" % [
			frames, alive, enemies.size(), int(pc.hp), shots.spawned_total, shots.hits_total,
			enemies.reduce(func(acc, e): return acc + e.shots_fired, 0),
			ai_usec_max / 1000.0, nav.last_build_usec / 1000.0])
		print("경로 질의 최대 %.2fms" % (nav.query_usec_max / 1000.0))


func _bot_move() -> Vector2:
	var e = _nearest_enemy()
	player.mode = "run"
	if e == null:
		var any = null
		for x in enemies:
			if not x.cmb.dead:
				any = x
				break
		if any == null:
			return Vector2.ZERO
		return (any.loco.logical - player.loco.logical)
	var d: Vector2 = e.loco.logical - player.loco.logical
	if d.length() > 7 * 32:
		return d
	if d.length() < 3 * 32:
		return -d                                                 # keep distance, backpedal while shooting
	player.mode = "walk"
	return d.orthogonal() * (1.0 if int(_ap_t / 2.0) % 2 == 0 else -1.0)


func _respawn() -> void:
	_dead_t = 0.0
	pc.dead = false
	pc.hp = pc.max_hp
	var sp: Array = world.index["spawns"]["player"]
	player.loco = Locomotion.new(Vector2(sp[0] * 32 + 16, sp[1] * 32 + 16))
	player.position = player.loco.render
	msg = "쓰러졌다 — 시험 구역 처음으로"


# ---------------------------------------------------------------- doors
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
	var alive := enemies.filter(func(e): return not e.cmb.dead).size()
	var w: Dictionary = weapons[weapon_id]
	hud.text = "%s · 청크 %d · 붙이기 최대 %.2fms · AI %.2fms · %d fps\nHP %d/%d · %s %s · 적 %d/%d · 탄 %d\n%s %s %d  (%d, %d) %s" % [
		"관악산 비탈" if area == world else "S-07 정문 안", world.loaded.size(), world.attach_usec_max / 1000.0,
		ai_usec / 1000.0, Engine.get_frames_per_second(), int(pc.hp), int(pc.max_hp), w["name"],
		("%d/12" % mag) if w["kind"] == "ranged" else "", alive, enemies.size(), shots.shots.size(),
		l.motion, Locomotion.DIRS[l.facing], l.frame, floori(l.logical.x / 32), floori(l.logical.y / 32), msg]
