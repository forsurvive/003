## 사기 확인 장면(단계 1-9e1, SD-11 §7.5 · §7.6 · §4.8): 생성 창고 G-444-1265에서
##   ① 약탈자 HP 30% → 도주('살려 줘!') ② 새벽인력 모집원 궁지 → 항복(흰 천 · '놓아준다') ③ 놓아줌 → 떠남 ④ 약물 → 광란(붉은 눈)
##   ⑤ 분대장(반장) 사망 → 신중한 분대원 도주 ⑥ 다리 손상 → 절뚝 를 차례로 보이며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/morale_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var o := Vector2i.ZERO
var e: Enemy
var e2: Enemy


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
	st.vars.set_v("GAME_DAY", 3)
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 24.  10:20"
	host.enter("G-444-1265", "")
	o = _open(host.map, 8, 4)
	host.combat.pc.hp = 9999.0
	host.combat.pc.max_hp = 9999.0


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


func _foe(id: String, dx: int, dy: int) -> Enemy:
	var f := host.combat.spawn(id, _at(dx, dy), host.map, host.st, {"lv": 3, "morale": true})
	f.brain.state = AIBrain.S.COMBAT
	f.brain.gauge = 100.0
	f._cool = 99.0
	return f


func _clear() -> void:
	for x in host.combat.enemies.duplicate():
		host.combat.drop_enemy(x)


func _process(dt: float) -> void:
	t += dt
	var c := host.combat
	host.player.loco.place(_at(1, 2) if stage != 1 and stage != 2 else host.player.loco.logical)
	match stage:
		0:                                                              # 도주
			if e == null:
				_clear()
				e = _foe("CR-420", 4, 2)
				e.cmb.hp = e.cmb.max_hp * 0.3
			if t > 0.7:
				_check(e.brain.state == AIBrain.S.FLEE, "약탈자 HP 30%% → 도주 '%s'" % e.say_text)
				_shot("1_flee")
				e = null
				_go()
		1:                                                              # 항복
			if e == null:
				_clear()
				e = _foe("CR-435", 3, 1)
				e.flee_now(_at(1, 2))
				e._cornered()
				host.player.loco.place(_at(2, 1))
			if t > 0.6:
				_check(e.brain.state == AIBrain.S.SURRENDER, "새벽인력 모집원 궁지 → 항복")
				_check(host.interact_label() == "놓아준다", "상호작용 안내: %s" % host.interact_label())
				_shot("2_surrender")
				_go()
		2:                                                              # 놓아줌
			if t < dt * 1.5:
				host.interact()
			if t > 1.2:
				_check(e.released and e.cmb.team == "gone", "놓아줌: 떠난다")
				_shot("3_release")
				e = null
				_go()
		3:                                                              # 약물 광란
			if e == null:
				_clear()
				e = _foe("CR-421", 4, 2)
				e._drug_done = true
				e._drug_t = 0.4
				e._say("drug")
			if t > 0.3 and t - dt <= 0.3:
				_shot("4a_drug")
			if t > 1.0:
				_check(e.frenzied and e.brain.state == AIBrain.S.FRENZY, "약물 1.5초 정지 → 광란(붉은 눈)")
				_shot("4b_frenzy")
				e = null
				_go()
		4:                                                              # 분대장 사망
			if e == null:
				_clear()
				e = _foe("CR-438", 5, 1)
				e2 = _foe("CR-437", 4, 3)
			if t > 0.3 and t - dt <= 0.3:
				_check(e2.confidence() == 2, "반장 곁 분대원 자신감 1+1")
				e.cmb.last_by = "player"
				e.cmb.take({"hp": 9999.0}, _at(1, 2))
			if t > 1.0:
				_check(e2.brain.state in [AIBrain.S.FLEE, AIBrain.S.SURRENDER], "반장 사망 → 분대원 도주(길이 막히면 항복): %s" % AIBrain.NAMES[e2.brain.state])
				_shot("5_leader_dead")
				e = null
				_go()
		5:                                                              # 다리 손상
			if e == null:
				_clear()
				e = _foe("CR-420", 5, 2)
				e.cmb.take({"hp": 1.0, "part": "leg", "limb": 999.0}, _at(1, 2))
			if t > 0.5:
				_check(e.cmb.crippled.has("leg") and absf(e.loco.speed_mul - 0.5) < 0.01, "다리 손상: 이동 −50%")
				_finish()


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
	print("사기 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
