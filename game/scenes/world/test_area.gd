## 단계 T 시험 구역: 관악산 비탈 청크 월드 + S-07 정문 실내, 문 전환, 실시간 전투(권총·진압봉 대 큰바퀴·보병 계엄병).
## 인자(-- 뒤): --autopilot  정해진 입력으로 걸어서 정문을 드나든다
##              --combat     적 쪽으로 이동하며 가장 가까운 적을 조준·사격한다(녹화·회귀 시험용).
##                           멀면 질주, 가까우면 4초마다 옆으로 구르기, AP가 남으면 집중 사격
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
const PER := 5
const FOCUS_AIM := 0.3                        ## 집중 사격 조준 시간(SD-11 §5.3), 그동안 이동 50%
const FOCUS_COST_DEFAULT := 17.0              ## SD-13에 AP 비용 열이 없을 때(정합 목록): §5.3 예산표의 경권총 17
var ap := APPool.new(5)
var _walk := false
var _sprint_latch := false                    ## AP 0으로 질주가 끝나면 Shift를 뗐다 눌러야 다시 질주
var sprinting := false
var _focus_t := -1.0                          ## 집중 사격 조준 중이면 0 이상
var _bot_roll_t := 0.0
var ap_stats := {"sprint_s": 0.0, "rolls": 0, "focused": 0, "winded": 0}
var _apbar: Control
var _prof_frames: Array = []
var _shot := ""
var console: DebugConsole
var overlay: DebugOverlay
var god := false
var game_minutes := 8.0 * 60.0               ## 게임 시각(분). 시간 체계는 단계 0 — 여기서는 원작 기본 배율 30배로 흐른다
const TIMESCALE := 30.0
var _combat_snapshot := {}                    ## 교전 시작 직전 상태(교전 중 자동 저장은 이것을 쓴다, SD-19 §6.10)
var _in_combat := false
var _save_task := -1
var autosave_stats := {"count": 0, "main_ms_max": 0.0}
var _pause_layer: PauseOverlay
var _autosave_test := false


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
	player.setup_doll({"torso": "T01"}, Vector2(sp[0] * 32 + 16, sp[1] * 32 + 16), world)
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
	_apbar = Control.new()
	_apbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apbar.draw.connect(_draw_ap)
	layer.add_child(_apbar)
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
		touch.buttons["회피"] = Rect2(560, 256, 48, 48)
		touch.buttons["집중"] = Rect2(500, 176, 48, 48)
		touch.layout(ScreenFit.logical)
		Input.emulate_touch_from_mouse = true
	save_rt = "--save-roundtrip" in args
	soak = "--soak" in args
	if soak:
		combat_bot = true
	passive = "--passive" in args
	Enemy.profiling = "--ai-profile" in args
	_autosave_test = "--autosave-test" in args
	overlay = DebugOverlay.new()
	overlay.world = world
	overlay.enemies = enemies
	overlay.nav = nav
	world.add_child(overlay)
	console = DebugConsole.new()
	console.host = self
	add_child(console)
	_make_pause_layer()
	if "--continue" in args:
		var path := SaveGame.latest_auto()
		var r := SaveGame.read(path) if path != "" else {"ok": false}
		if r["ok"]:
			apply(r["world"])
			print("이어하기: %s (seq %d, %s)" % [path, int(r["slot"]["seq"]), r["slot"].get("why", "")])
		else:
			print("이어하기: 자동 저장 없음")
	for a in args:
		if a.begins_with("--shot="):
			_shot = a.substr(7)
		elif a.begins_with("--cmd="):
			console.run_script.call_deferred(a.substr(6))


func _input_vector() -> Vector2:
	if console.opened:
		return Vector2.ZERO
	if passive:
		player.mode = "run"
		var tgt: Array = world.index["spawns"]["CR-401"][0]
		var front := Vector2(tgt[0] * 32 + 16, (tgt[1] + 6) * 32 + 16)      # 계엄병 정면(남쪽) 6t에 선다
		var d := front - player.loco.logical
		return d if d.length() > 8 else Vector2.ZERO
	if combat_bot:
		return player.steer(_bot_move())                              # 봇도 AI처럼 막히면 돌아서 걷는다(벽 비비기 없음)
	if not autopilot.is_empty():
		var t := _ap_t
		for seg in autopilot:
			if t < seg[0]:
				player.mode = seg[3]
				return Vector2(seg[1], seg[2])
			t -= seg[0]
		return Vector2.ZERO
	if touch != null and (touch.move != Vector2.ZERO or touch_demo):
		player.mode = "run" if touch.move.length() >= 0.25 else "walk"         # 반경 25% 안쪽 = 걷기(SD-11 §15.5)
		return touch.move
	if Input.is_action_just_pressed("walk_toggle"):
		_walk = not _walk
	player.mode = "walk" if _walk or Input.is_action_pressed("aim") else "run"
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _physics_process(dt: float) -> void:
	frames += 1
	_ap_t += dt
	game_minutes += dt * TIMESCALE / 60.0
	overlay.view_center = player.loco.logical
	if god:
		pc.hp = pc.max_hp
	_track_combat()
	if _autosave_test:
		_autosave_test_step()
	if _fading > 0.0:
		_fade_step(dt)
		return
	if pc.dead:
		_dead_t += dt
		if _dead_t > 2.0:
			_respawn()
	else:
		_player_move(dt)
		_player_combat(dt)
		_step_sound_t -= dt
		if player.loco.motion != "idle" and _step_sound_t <= 0.0:      # 이동 소음: 질주 5t·달리기 2.0t·걷기 1.5t (§2.4)
			_step_sound_t = 0.5
			var snd := "sprint" if sprinting else ("move" if player.mode == "run" else "sneak")
			for e in enemies:
				e.hear(snd, player.loco.logical)
	area.update_focus(player.loco.logical)
	if area == world:
		_combat_tick(dt)
	cam.position = player.loco.logical.round()
	if not pc.dead:
		_check_door()
	if touch_demo:
		_touch_demo_step(dt)
	if _shot != "" and frames == 150:                                 # 비교 화면(H-11): 논리 해상도 화면을 그대로 저장
		get_viewport().get_texture().get_image().save_png(_shot)
		print("화면 저장: %s %s" % [_shot, ScreenFit.logical])
		get_tree().quit()
	if save_rt and frames == 300:
		_save_roundtrip()
	if soak:
		_soak_step()
	if not combat_bot and not console.opened and Input.is_action_just_pressed("save"):
		SaveGame.write_atomic("user://quick.sav", SaveGame.encode({"name": "빠른 저장"}, capture()))
		msg = "빠른 저장"
	if not combat_bot and not console.opened and Input.is_action_just_pressed("load"):
		var r := SaveGame.read("user://quick.sav")
		if r["ok"]:
			apply(r["world"])
			msg = "불러오기"
	_hud()


# ---------------------------------------------------------------- AP 행동 (SD-11 §5): 질주·회피 구르기·집중 사격
func _player_move(dt: float) -> void:
	player.roll_cool = maxf(0.0, player.roll_cool - dt)
	if player.rolling():
		player.roll_step(dt)
		pc.invuln = player.rolling() and player.roll_frame() in [1, 2, 3]      # 5컷 중 2~4번째
		ap.tick(dt, false)
		return
	pc.invuln = false
	var inp := _input_vector()
	if _want("dodge") and player.roll_cool <= 0.0:
		if ap.spend(APPool.DODGE):
			_focus_t = -1.0
			_reload = 0.0                                             # 구르면 재장전이 끊긴다
			player.aim_dir = -1
			player.start_roll(inp)
			ap_stats["rolls"] += 1
			sprinting = false
			return
		msg = "숨참 — AP 부족"
	var key := _sprint_key(inp)
	if not key:
		_sprint_latch = false
	var moving := inp.length() > 0.2
	var was := sprinting
	sprinting = ap.tick(dt, key and moving and not _sprint_latch and _focus_t < 0.0)
	if key and moving and not sprinting and was and ap.winded():
		_sprint_latch = true
		ap_stats["winded"] += 1
		msg = "숨참 — 질주 끝"
	if sprinting:
		player.mode = "sprint"
		player.aim_dir = -1
		ap_stats["sprint_s"] += dt
	player.move(inp, dt * (0.5 if _focus_t >= 0.0 else 1.0))     # 집중 조준 중 이동 50%: 거리 구동이라 보폭은 그대로


func _want(action: String) -> bool:
	if console.opened:
		return false
	if combat_bot:
		return action == "dodge" and _bot_wants_roll()
	if touch != null and touch.take({"dodge": "회피", "focus": "집중", "reload": "재장전", "swap": "교체"}[action]):
		return true
	return action != "swap" and Input.is_action_just_pressed(action)


func _sprint_key(inp: Vector2) -> bool:
	if combat_bot:
		var e = _nearest_enemy()
		return e == null or e.loco.logical.distance_to(player.loco.logical) > 9 * 32
	if touch != null and touch.move != Vector2.ZERO:
		return touch.move_full >= 0.3                                    # 질주 링 밖 0.3초(SD-11 §15.5)
	return Input.is_action_pressed("sprint")


## 시험 봇: 적이 7t 안에 있으면 4초마다 옆으로 구른다(무적 프레임으로 탄을 흘리는지 센다)
func _bot_wants_roll() -> bool:
	_bot_roll_t += get_physics_process_delta_time()
	var e = _nearest_enemy()
	if e == null or _bot_roll_t < 4.0 or e.loco.logical.distance_to(player.loco.logical) > 7 * 32:
		return false
	_bot_roll_t = 0.0
	return true


func _focus_cost(w: Dictionary) -> float:
	return FOCUS_COST_DEFAULT if w.get("ap_cost") == null else float(w["ap_cost"])


func _draw_ap() -> void:
	var x0 := 6.0
	var y0 := 54.0
	var full := ap.max_ap
	_apbar.draw_rect(Rect2(x0 - 1, y0 - 1, full + 2, 5), Color("0b0a0d"))
	var col := Color("e8c23a") if not ap.winded() else (Color("e04a35") if frames % 20 < 10 else Color("6e6966"))
	_apbar.draw_rect(Rect2(x0, y0, floorf(ap.ap), 3), col)
	var w: Dictionary = weapons[weapon_id]
	for c in [APPool.DODGE, _focus_cost(w)]:                        # 비용 눈금: 회피 20, 집중 사격
		_apbar.draw_rect(Rect2(x0 + c, y0 - 1, 1, 5), Color("e9e4d8"))
	_apbar.draw_string(ui_font, Vector2(x0 + full + 5, y0 + 5), "AP %d%s" % [int(ap.ap), " 숨참" if ap.winded() else ""],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e9e4d8"))
	if _focus_t >= 0.0:                                                # 집중 조준 진행
		_apbar.draw_rect(Rect2(x0, y0 + 5, floorf(full * _focus_t / FOCUS_AIM), 1), Color("e9e4d8"))


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
	if Enemy.profiling:
		for k in Enemy.prof:
			Enemy.prof[k] = 0
	for e in enemies:
		if absi(world.chunk_of_px(e.loco.logical).x - world.focus.x) <= 1 and absi(world.chunk_of_px(e.loco.logical).y - world.focus.y) <= 1:
			e.think(dt, pc, nav, shots)
	ai_usec = Time.get_ticks_usec() - t0
	ai_usec_max = maxi(ai_usec_max, ai_usec)
	if Enemy.profiling:
		var rec := Enemy.prof.duplicate()
		rec["total"] = ai_usec
		rec["frame"] = frames
		rec["active"] = enemies.filter(func(e): return not e.cmb.dead).size()
		var c0 := Time.get_ticks_usec()                                # 대조군: 매 프레임 같은 양의 계산(AI와 무관)
		var acc := Vector2.ZERO
		for i in 1500:
			acc += Vector2(i, 1).rotated(0.01 * i).normalized()
		rec["control"] = Time.get_ticks_usec() - c0 + int(acc.x) * 0
		_prof_frames.append(rec)
	shots.step(dt)
	if pc.flash > 0:
		pc.flash -= 1
	player.doll.set_flash(1.0 if pc.flash > 0 else 0.0)


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
	if touch != null and (touch.aim != Vector2.ZERO or _touch_shot or _focus_t >= 0.0):
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
	if console.opened:
		return
	if player.rolling() or sprinting:                                 # 구르기·질주 중에는 쏘지도 재장전하지도 않는다
		return
	if _reload > 0.0:
		_reload -= dt
		if _reload <= 0.0:
			mag = int(weapons["W-002"]["mag"])
		return
	if not combat_bot:
		if _want("reload") and weapon_id == "W-002" and _focus_t < 0.0:
			_reload = 1.5
			return
		_equip_keys()
		var pick := ""
		if Input.is_action_just_pressed("slot_1"):
			pick = "W-002"
		elif Input.is_action_just_pressed("slot_2"):
			pick = "W-041"
		elif _want("swap"):
			pick = "W-041" if weapon_id == "W-002" else "W-002"
		if pick != "" and pick != weapon_id and _focus_t < 0.0:
			weapon_id = pick
			_cool = 0.3
			msg = weapons[pick]["name"]
			return
	var aim_pt := _aim_point()
	var to := aim_pt - (player.loco.logical + Vector2(0, -14))
	var aiming := combat_bot or Input.is_action_pressed("aim") or Input.is_action_pressed("fire") \
		or (touch != null and touch.aim != Vector2.ZERO) or _focus_t >= 0.0
	player.aim_dir = Locomotion.snap8(to, 0.0) if aiming else -1
	var w0: Dictionary = weapons[weapon_id]
	if _focus_t >= 0.0:                                               # 집중 사격: 0.3초 조준 뒤 발사
		_focus_t += dt
		if _focus_t >= FOCUS_AIM:
			_focus_t = -1.0
			var ang0 := CombatRules.shot_angle(rad_to_deg(to.angle()), float(w0.get("min_spread", 1.0)), shots.rng)
			if shots.fire(player.loco.logical + Vector2(0, -14) + to.normalized() * 10.0, ang0, 640.0, "player", w0, SKILL, true, PER):
				mag -= 1
				_cool = 1.0 / float(w0["rate"])
				ap_stats["focused"] += 1
				for e in enemies:
					e.hear("pistol", player.loco.logical)
		return
	var want_focus := _want("focus") if not combat_bot else (_nearest_enemy() != null and to.length() < 8 * 32
		and ap.ap >= _focus_cost(w0) + APPool.DODGE)                  # 봇: 구르기 몫을 남기고 집중 사격
	if want_focus and _cool <= 0.0:
		if w0["kind"] != "ranged":
			msg = "근접 파워 공격은 단계 0"
		elif mag <= 0:
			_reload = 1.5
		elif ap.spend(_focus_cost(w0)):
			_focus_t = 0.0
			return
		else:
			msg = "숨참 — AP 부족"
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
			"weapon": weapon_id, "facing": player.loco.facing, "ap": ap.ap},
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
	ap.ap = p.get("ap", ap.max_ap)
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
	if frames % 1800 == 0 and "--soak-log" in OS.get_cmdline_user_args():
		var alive := enemies.filter(func(e): return not e.cmb.dead)
		print("[soak %ds] 주인공 %s %s · 적 %s" % [frames / 60, Vector2i(player.loco.logical / 32), player.loco.motion,
			", ".join(alive.map(func(e): return "%s%s %s" % [e.row["id"], Vector2i(e.loco.logical / 32), AIBrain.S.keys()[e.brain.state]]))])
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
	if Enemy.profiling and not _prof_frames.is_empty():
		_prof_report()
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
		print("AP 행동: 질주 %.1f초, 구르기 %d회(무적 중 흘린 탄 %d), 집중 사격 %d발(명중 부위 %s), 숨참 %d회" % [
			ap_stats["sprint_s"], ap_stats["rolls"], shots.ghosted_total, ap_stats["focused"],
			JSON.stringify(_count(shots.focused_hits)), ap_stats["winded"]])


## 장비 교체 시험(P9 즉시 반영): Alt + 1 몸통 2 머리카락 3 머리 장비 4 눈 장비 5 세력 6 피부·머리색
const CYCLE := {KEY_1: ["torso", ["T01", "T02", "T03", "T06"]], KEY_2: ["hair", ["HR03", "HR05", "HR07", "HR08", "HR09"]],
	KEY_3: ["gear", ["", "HD02", "HD03", "HD04", "HD05"]], KEY_4: ["eyes", ["", "EY01", "EY05"]],
	KEY_5: ["faction", ["", "PF-01", "PF-05", "PF-11", "PF-12"]], KEY_6: ["skin", ["S3", "S1", "S5", "SG1"]]}
var _equip_down := {}


## Alt + 1~6 (1·2는 무기 단축키라 Alt를 함께 누른다)
func _equip_keys() -> void:
	for k in CYCLE:
		var down := Input.is_key_pressed(k) and Input.is_key_pressed(KEY_ALT)
		if down and not _equip_down.get(k, false):
			var slot: String = CYCLE[k][0]
			var opts: Array = CYCLE[k][1]
			var cur: String = player.doll.look[slot]
			player.doll.set_look({slot: opts[(opts.find(cur) + 1) % opts.size()]})
			msg = "%s → %s" % [slot, player.doll.look[slot]]
		_equip_down[k] = down


## AI 스파이크 분석(T8): 프레임별 AI 시간 분포와 상위 프레임의 층별 구성
func _prof_report() -> void:
	var tot: Array = _prof_frames.map(func(r): return r["total"])
	tot.sort()
	var n := tot.size()
	var pct := func(q: float) -> float: return tot[mini(n - 1, int(n * q))] / 1000.0
	print("AI 분포(ms): 프레임 %d, 중앙 %.3f, 99%% %.3f, 99.9%% %.3f, 최대 %.3f, 3ms 초과 %d, 2ms 초과 %d" % [
		n, pct.call(0.5), pct.call(0.99), pct.call(0.999), tot[n - 1] / 1000.0,
		tot.filter(func(x): return x > 3000).size(), tot.filter(func(x): return x > 2000).size()])
	var ctl: Array = _prof_frames.map(func(r): return r["control"])
	ctl.sort()
	print("대조군(같은 계산 매 프레임, ms): 중앙 %.3f, 99.9%% %.3f, 최대 %.3f, 중앙+1.5ms 초과 %d회" % [
		ctl[n / 2] / 1000.0, ctl[mini(n - 1, int(n * 0.999))] / 1000.0, ctl[n - 1] / 1000.0,
		ctl.filter(func(x): return x > ctl[n / 2] + 1500).size()])
	var top := _prof_frames.duplicate()
	top.sort_custom(func(a, b): return a["total"] > b["total"])
	for r in top.slice(0, 8):
		var acc: int = r["per"] + r["tac"] + r["act"]
		print("  프레임 %d: 합 %.2fms (인지 %.2f ×%d, 전술 %.2f ×%d [경로 %.2f ×%d], 행동 %.2f, 층 밖 %.2f), 활성 %d" % [
			r["frame"], r["total"] / 1000.0, r["per"] / 1000.0, r["n_per"], r["tac"] / 1000.0, r["n_tac"],
			r["path"] / 1000.0, r["n_path"], r["act"] / 1000.0, (r["total"] - acc) / 1000.0, r["active"]])


static func _count(a: Array) -> Dictionary:
	var d := {}
	for x in a:
		d[x] = d.get(x, 0) + 1
	return d


## 봇 길찾기: 적과 같은 격자 경로를 1초마다 다시 묻고 웨이포인트를 따라간다(사람처럼 장애물을 돌아간다)
var _bot_path := PackedVector2Array()
var _bot_i := 0
var _bot_t := 0.0


func _bot_follow(goal: Vector2) -> Vector2:
	_bot_t -= get_physics_process_delta_time()
	if _bot_t <= 0.0 or _bot_i >= _bot_path.size():
		var p := nav.path(player.loco.logical, goal)
		if p.size() > 1:
			_bot_path = p
			_bot_i = 1
			_bot_t = 1.0
	if _bot_i < _bot_path.size():
		if player.loco.logical.distance_to(_bot_path[_bot_i]) < 8.0:
			_bot_i += 1
		if _bot_i < _bot_path.size():
			return _bot_path[_bot_i] - player.loco.logical
	return goal - player.loco.logical


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
		return _bot_follow(any.loco.logical)
	var d: Vector2 = e.loco.logical - player.loco.logical
	if d.length() > 7 * 32:
		return _bot_follow(e.loco.logical)
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
	ap = APPool.new(5)
	_focus_t = -1.0
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
	print("문 전환: %s (프레임 %d)" % ["S-07 정문 안" if _fade_to == "in" else "관악산 비탈", frames])
	player.world = area
	player.loco.logical = at
	player.loco.render = at.round()
	player.loco.motion = "idle"
	player.position = player.loco.render
	cam.position = at.round()


func _hud() -> void:
	_apbar.queue_redraw()
	if Input.is_action_just_pressed("debug") and not console.opened:          # F3: 디버그 표시 전부 켜고 끄기
		dbg_show(["off" if overlay.any() else "all"])
	if touch != null:
		touch.dim["회피"] = not ap.can(APPool.DODGE)
		touch.dim["집중"] = not ap.can(_focus_cost(weapons[weapon_id]))
	var l := player.loco
	var alive := enemies.filter(func(e): return not e.cmb.dead).size()
	var w: Dictionary = weapons[weapon_id]
	hud.text = "%02d:%02d · %s · 청크 %d · 붙이기 최대 %.2fms · AI %.2fms · %d fps\nHP %d/%d · %s %s · 적 %d/%d · 탄 %d\n%s %s %d  (%d, %d) %s" % [
		int(game_minutes / 60.0) % 24, int(game_minutes) % 60, "관악산 비탈" if area == world else "S-07 정문 안", world.loaded.size(), world.attach_usec_max / 1000.0,
		ai_usec / 1000.0, Engine.get_frames_per_second(), int(pc.hp), int(pc.max_hp), w["name"],
		("%d/12" % mag) if w["kind"] == "ranged" else "", alive, enemies.size(), shots.shots.size(),
		l.motion, Locomotion.DIRS[l.facing], l.frame, floori(l.logical.x / 32), floori(l.logical.y / 32),
		("무적 · " if god else "") + msg]


# ---------------------------------------------------------------- 디버그 콘솔 명령 (DebugConsole이 부른다)
func dbg_set(a: Array) -> String:
	var v: String = a[1]
	match a[0]:
		"hp":
			pc.hp = pc.max_hp if v == "max" else clampf(float(v), 1.0, pc.max_hp)
			pc.dead = false
			return "HP %d" % int(pc.hp)
		"ap":
			ap.ap = ap.max_ap if v == "max" else clampf(float(v), 0.0, ap.max_ap)
			return "AP %d" % int(ap.ap)
		"mag":
			mag = int(weapons["W-002"]["mag"]) if v == "max" else clampi(int(v), 0, 99)
			return "탄 %d" % mag
		"skill":
			return "스킬은 시험판에서 상수(%d) — 능력치 체계와 함께 단계 0" % int(SKILL)
	return ""


func dbg_places(_a: Array) -> String:
	var out := []
	for id in world.index.get("places", {}):
		out.append("%s %s" % [id, world.index["places"][id]["name"]])
	return ", ".join(out) + ", L-R01-01-IN 볼트 S-07 정문 안"


func dbg_tp(a: Array) -> String:
	var tile: Vector2i
	if a.size() == 2:
		tile = Vector2i(int(a[0]), int(a[1]))
	else:
		var id: String = (a[0] as String).to_upper()
		if id == "L-R01-01-IN":
			if area == world:
				_start_fade("in")
			return "볼트 S-07 정문 안으로"
		var places: Dictionary = world.index.get("places", {})
		if not places.has(id):
			return "없는 장소: %s (places)" % id
		tile = Vector2i(places[id]["tile"][0], places[id]["tile"][1])
	if area != world:
		return "실내에서는 tp L-R01-01-IN 밖으로 나간 뒤 쓴다"
	world.load_now(Vector2(tile) * 32.0)                              # 아직 안 붙은 청크면 먼저 붙인다(막힘 판정용)
	var free := tile
	for r in 4:                                                     # 막힌 칸이면 가까운 열린 칸(반경 3)
		var found := false
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if not found and not world.is_solid(tile + Vector2i(dx, dy)):
					free = tile + Vector2i(dx, dy)
					found = true
		if found:
			break
	if world.is_solid(free):
		return "막힌 칸: %s" % tile
	tile = free
	var at := Vector2(tile) * 32.0 + Vector2(16, 16)
	player.loco.place(at)
	player.position = player.loco.render
	world.update_focus(at)
	_nav_dirty = true
	return "순간 이동 %s" % tile


func dbg_show(a: Array) -> String:
	var k: String = a[0]
	if k == "all" or k == "off":
		for x in overlay.show:
			overlay.show[x] = k == "all"
	else:
		overlay.show[k] = not overlay.show[k]
	var on := []
	for x in overlay.show:
		if overlay.show[x]:
			on.append(x)
	return "표시: " + (", ".join(on) if on.size() > 0 else "없음")


func dbg_skip(a: Array) -> String:
	game_minutes += float(a[0])
	return "게임 시각 %02d:%02d (+%s분)" % [int(game_minutes / 60.0) % 24, int(game_minutes) % 60, a[0]]


func dbg_god(_a: Array) -> String:
	god = not god
	return "무적 " + ("켬" if god else "끔")


func dbg_kill(_a: Array) -> String:
	var n := 0
	for e in enemies:
		if not e.cmb.dead and absi(world.chunk_of_px(e.loco.logical).x - world.focus.x) <= 1 \
				and absi(world.chunk_of_px(e.loco.logical).y - world.focus.y) <= 1:
			e.cmb.take({"hp": e.cmb.hp + 1.0}, player.loco.logical)
			n += 1
	return "적 %d 쓰러뜨림" % n


func dbg_heal(_a: Array) -> String:
	pc.hp = pc.max_hp
	pc.dead = false
	ap.ap = ap.max_ap
	return "HP·AP 가득"


# ---------------------------------------------------------------- 자동 저장 (SD-19 §6.10·A7: 일시 정지 알림 → 즉시 자동 저장)
## 교전에 들어가는 순간의 상태를 기억해 둔다. 교전 중에 앱이 내려가면 그 상태를 저장한다(전투 한가운데서 이어하지 않게).
func _track_combat() -> void:
	var now: bool = enemies.any(func(e): return not e.cmb.dead and e.brain.state == AIBrain.S.COMBAT)
	if now and not _in_combat:
		_combat_snapshot = capture()
	_in_combat = now


## 본 스레드는 상태를 모으기만 하고(capture), 직렬화·검사합·쓰기는 작업 스레드가 한다. 반환: 본 스레드 정지 ms.
func autosave(why: String) -> float:
	var t0 := Time.get_ticks_usec()
	if _save_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_save_task)
		_save_task = -1
	var st: Dictionary = _combat_snapshot if _in_combat and not _combat_snapshot.is_empty() else capture()
	var nx := SaveGame.next_auto()
	var slot := {"name": "자동 저장", "why": why, "seq": nx[1], "combat": _in_combat, "where": "관악산 비탈" if area == world else "S-07 정문 안"}
	_save_task = WorkerThreadPool.add_task(func(): SaveGame.write_atomic(nx[0], SaveGame.encode(slot, st)))
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	autosave_stats["count"] += 1
	autosave_stats["main_ms_max"] = maxf(autosave_stats["main_ms_max"], ms)
	return ms


func finish_saves() -> void:
	if _save_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_save_task)
		_save_task = -1


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if get_tree() != null and not get_tree().paused and not combat_bot:
				autosave("일시 정지 알림")
				_pause(true)
		NOTIFICATION_WM_GO_BACK_REQUEST:                              # Android 뒤로 가기 = 일시 정지 메뉴
			_pause(not _pause_layer.visible)
		NOTIFICATION_WM_CLOSE_REQUEST:
			autosave("종료")
			finish_saves()


func _make_pause_layer() -> void:
	_pause_layer = PauseOverlay.new(ui_font)
	add_child(_pause_layer)


func _pause(on: bool) -> void:
	if on:
		_pause_layer.open("일시 정지 — 자동 저장했다\n아무 키나 누르거나 화면을 누르면 계속")
	else:
		_pause_layer.close()


## 자동 저장 시험: 교전 전·교전 중 일시 정지 알림을 흉내 내고, 저장된 칸을 읽어 되돌린 뒤 같은지 본다.
func _autosave_test_step() -> void:
	if frames == 120 or frames == 900:
		var before: Dictionary = _combat_snapshot if _in_combat else capture()
		var ms := autosave("시험 %d" % frames)
		finish_saves()
		var r := SaveGame.read(SaveGame.latest_auto())
		var same: bool = r["ok"] and var_to_bytes(r["world"]) == var_to_bytes(before)
		print("자동 저장 시험 %d: 본 스레드 %.2fms, 칸 %s, seq %d, 교전 중 %s, %s" % [frames, ms, SaveGame.latest_auto().get_file(),
			int(r["slot"]["seq"]), r["slot"]["combat"], "상태 동일" if same else "차이 있음"])
	if frames == 1000:
		get_tree().quit()
