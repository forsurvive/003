## 적 무기 확인 장면(단계 1-9e2, SD-11 §7.4 · §3.3): 생성 창고 G-444-1265에서 ① 근접 약탈자가 붙기 전 수류탄('수류탄!' · 붉은 경고 원)
##   ② 계엄병 돌격소총 점사(쏨 · 쉼) ③ 경호 구울이 붙으면 도끼로 ④ 주인공 미사일이 로봇 쪽으로 휘는 궤적 을 보이며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/enemy_arms_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var o := Vector2i.ZERO
var e: Enemy
var trail: Array = []
var shot_times: Array = []
var _n0 := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.quests.set_stage("MQ-101", 100)
	st.vars.set_v("MQ101_RESULT", 1)
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 24.  10:20"
	host.enter("G-444-1265", "")
	o = _open(host.map, 10, 4)
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0


func _open(m: InteriorMap, w: int, h: int) -> Vector2i:
	for y in range(2, 40):
		for x in range(2, 60):
			var ok := true
			for dy in h:
				for dx in w:
					var tt := Vector2i(x + dx, y + dy)
					if m.is_solid(tt) or m.cover_at(tt) != 0:
						ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(4, 4)


func _at(dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _foe(id: String, dx: int, dy: int, generic := true) -> Enemy:
	var f := host.combat.spawn(id, _at(dx, dy), host.map, host.st, {"lv": 3, "morale": generic})
	f.brain.state = AIBrain.S.COMBAT
	f.brain.gauge = 100.0
	return f


func _clear() -> void:
	for x in host.combat.enemies.duplicate():
		host.combat.drop_enemy(x)


func _process(dt: float) -> void:
	t += dt
	var c := host.combat
	host.player.loco.place(_at(0, 2))
	match stage:
		0:                                                              # 근접 약탈자 수류탄
			if e == null:
				_clear()
				e = _foe("CR-423", 6, 2)
			if c.ord.nades.size() > 0 and not has_meta("nade_shot") and t > 0.15:
				set_meta("nade_shot", true)
				_check(e.say_text in ["수류탄!", "받아라!"], "근접 약탈자: 붙기 전 수류탄 '%s'" % e.say_text)
				_shot("1_enemy_nade")
			if c.shots.booms.size() > 0 and not has_meta("boom_shot"):
				set_meta("boom_shot", true)
				_shot("1b_enemy_nade_boom")
			if t > 3.6:
				_check(has_meta("nade_shot") and has_meta("boom_shot"), "적 수류탄이 날아와(붉은 경고 원) 터졌다")
				e = null
				_go()
		1:                                                              # 점사
			if e == null:
				_clear()
				e = _foe("CR-401", 8, 2)
				e.weapon = c.weapons["W-018"].duplicate()
				e.nades = 0
				_n0 = e.shots_fired
			e.has_token = true
			e._move = Vector2.ZERO
			e._path = PackedVector2Array()
			if e.shots_fired != _n0:
				shot_times.append(t)
				_n0 = e.shots_fired
			if t > 0.9 and t - dt <= 0.9:
				_shot("2_burst")
			if t > 4.0:
				var gaps := 0
				for i in range(1, shot_times.size()):
					if float(shot_times[i]) - float(shot_times[i - 1]) >= 0.45:
						gaps += 1
				_check(shot_times.size() >= 8 and gaps >= 1, "돌격소총 점사 %d발 · 쉼 %d번" % [shot_times.size(), gaps])
				e = null
				_go()
		2:                                                              # 도끼 전환
			if e == null:
				_clear()
				e = _foe("CR-457", 1, 2)
			if t > 1.2:
				_check(e.on_alt and e.style == "melee", "경호 구울: 붙으면 소방 도끼")
				_shot("3_axe")
				e = null
				_go()
		3:                                                              # 미사일 유도
			if e == null:
				_clear()
				e = _foe("CR-401", 9, 3, false)
				e.cmb.robot = true
				e.cmb.hp = 99999.0
				e._cool = 999.0
				c.shots._rebucket()
				var from: Vector2 = host.player.loco.logical + Vector2(10, -12)
				c.shots.fire_weapon(from, rad_to_deg((e.loco.logical - from).angle()) - 25.0, "player", c.weapons["W-033"], 50.0)
			e._cool = 999.0
			for s in c.shots.shots:
				if str(s.get("proj", "")) == "missile":
					trail.append(s["p"])
					if bool(s.get("homing", false)):
						set_meta("homed", true)
			queue_redraw_trail()
			if t > 0.35 and t - dt <= 0.35:
				_shot("4_missile_home")
			if t > 1.5:
				_check(has_meta("homed"), "미사일이 로봇 쪽으로 휘었다(궤적 점)")
				_finish()


var _trail_node: Node2D


func queue_redraw_trail() -> void:
	if _trail_node == null:
		_trail_node = Node2D.new()
		_trail_node.z_index = 20
		host.map.add_child(_trail_node)
		_trail_node.draw.connect(func() -> void:
			for p in trail:
				_trail_node.draw_rect(Rect2((p as Vector2) - Vector2(1, 1), Vector2(2, 2)), Color("E8C23A")))
	_trail_node.queue_redraw()


func _go() -> void:
	stage += 1
	t = 0.0


func _shot(nm: String) -> void:
	if shots == "":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(nm + ".png"))


func _check(ok: bool, what: String) -> void:
	checks.append([ok, what])
	print(("○ " if ok else "✕ ") + what)


func _finish() -> void:
	stage = 99
	print("적 무기 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
