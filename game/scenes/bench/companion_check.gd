## 일시 동행 확인 장면(단계 1-10a, SD-11 §8.2 · §8.4 · SD-12 §11.4 · §4.2): 생성 창고 G-444-1265에서 박춘삼(C-018) · 백구(C-015)를 붙여
##   ① 따라오기 · HUD [동행] 이름 + HP · 방위 링 푸른 원 ② 엄호(주인공이 친 적을 함께) ③ 기절 → '일으키기' 2초 + 스팀팩
##   ④ 말 걸기 '잠깐 여기서 기다려 줘' → 기다림 ⑤ 은신 동조: 백구가 숨은 적을 노려본다 를 보이며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/companion_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var o := Vector2i(2, 9)
var e1: Enemy
var e2: Enemy
var park: Dictionary
var dog: Dictionary


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
	st.vars.set_v("MQ103_HIRE", 1)                                    # 박춘삼을 이미 고용한 뒤(고용 장면이 끝난 상태)
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 24.  14:20"
	host.enter("G-444-1265", "")
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0
	for x in host.combat.enemies.duplicate():
		host.combat.drop_enemy(x)
	host.player.loco.place(_at(1, 0))
	host.player.loco.facing = 0
	host._bring_buddy("C-018")
	host._bring_buddy("C-015")
	park = host.combat.mates.get_mate("C-018")
	dog = host.combat.mates.get_mate("C-015")


func _at(dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _foe(id: String, at: Vector2, fight := true) -> Enemy:
	var e := host.combat.spawn(id, at, host.map, host.st, {"lv": 3})
	if fight:
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
	e._cool = 999.0
	return e


func _hold(e: Enemy) -> void:
	if e == null or not is_instance_valid(e):
		return
	e._cool = 999.0
	e._move = Vector2.ZERO
	e._path = PackedVector2Array()
	e._t_tac = -99.0


func _process(dt: float) -> void:
	t += dt
	var c := host.combat
	var p := host.player
	match stage:
		0:                                                              # 따라오기
			host.input_vec = Vector2.RIGHT if p.loco.logical.x < _at(9, 0).x else Vector2.ZERO
			if t > 2.4:
				host.input_vec = Vector2.ZERO
				_check(not park.is_empty() and not dog.is_empty(), "동행 둘: 박춘삼 · 백구")
				var d: float = (park["actor"] as Actor).loco.logical.distance_to(p.loco.logical)
				_check(d <= Companions.FOLLOW_FAR + 16.0, "박춘삼이 뒤 2~4칸을 따라온다(%.0fpx)" % d)
				_shot("1_follow")
				_go()
		1:                                                              # 엄호
			if e1 == null:
				p.loco.place(_at(1, 0))
				p.loco.facing = 0
				e1 = _foe("CR-420", _at(7, 0))
				e2 = _foe("CR-420", _at(9, 1))
				for e in [e1, e2]:
					e.cmb.hp = 400.0
					e.cmb.max_hp = 400.0
				e2.cmb.last_by = "player"
				e2.cmb.take({"hp": 10.0}, p.loco.logical)
			_hold(e1)
			_hold(e2)
			if t > 1.6 and t - dt <= 1.6:
				_shot("2_cover_fire")
			if t > 2.4:
				_check(c.pc_target == e2 and e2.cmb.hp < 390.0, "주인공이 친 적을 함께 친다(%.0f)" % e2.cmb.hp)
				_go()
		2:                                                              # 기절 · 일으키기
			_hold(e1)
			_hold(e2)
			if t < dt * 1.5:
				var cmb: Combatant = park["cmb"]
				cmb.last_by = "enemy"
				cmb.take({"hp": 9999.0}, e1.loco.logical)
				host.st.call_fn("give", [InteriorCombat.STIMPAK, 1])
			if t > 0.4 and t - dt <= 0.4:
				_check(park["down"] and not c.shots.combatants.has(park["cmb"]), "박춘삼 쓰러짐(기절 — 표적에서 빠짐)")
				p.loco.place((park["actor"] as Actor).loco.logical + Vector2(-24, 0))
				p.loco.facing = 0
			if t > 0.5 and t - dt <= 0.5:
				_check(host.interact_label() == "일으키기", "상호작용 안내: %s" % host.interact_label())
				_shot("3a_down")
				host.act_held = true
			if t > 1.6 and t - dt <= 1.6:
				_shot("3b_reviving")
			if t > 2.8:
				host.act_held = false
				_check(not park["down"] and int(host.st.items.get(InteriorCombat.STIMPAK, 0)) == 0, "2초 누르면 일어난다(스팀팩 1개)")
				c.drop_enemy(e1)
				c.drop_enemy(e2)
				e1 = null
				_go()
		3:                                                              # 말 걸기 → 기다림
			if t > 2.6 and t - dt <= 2.6:
				var a: Actor = park["actor"]
				p.loco.place(a.loco.logical + Vector2(-30, 0))
				p.loco.facing = 0
			if t > 2.8 and t - dt <= 2.8:
				_check(host.interact_label() == "말하기", "전투가 끝난 뒤 동행에게 '말하기'")
				host.interact()
			if t > 3.4 and t < 4.2 and host.box.active and str(host.box.state.get("type", "")) == "line":
				host.box.next()                                              # 인사 줄을 넘겨 선택지까지
			if t > 4.2 and t - dt <= 4.2:
				_shot("4a_talk")
				host.box.pick(1)                                             # 0 = '할 말이 있어'(퀘스트 장면) · 1 = '잠깐 여기서 기다려 줘'
			if t > 4.4 and t < 5.6 and host.box.active and str(host.box.state.get("type", "")) == "line":
				host.box.next()
			if t > 5.8:
				_check(str(park["mode"]) == "wait", "'잠깐 여기서 기다려 줘' → 기다림")
				_shot("4b_wait")
				_go()
		4:                                                              # 백구 노려보기
			for k in 20:                                                # 남은 대사 닫기
				if host.box.active and str(host.box.state.get("type", "")) == "line":
					host.box.next()
			if e1 == null:
				p.loco.place(_at(2, 0))
				p.loco.facing = 0
				(dog["actor"] as Actor).loco.place(_at(3, 1))
				e1 = _foe("CR-420", _at(5, 1), false)
				e1.brain.state = AIBrain.S.IDLE
				c.crouch = true
			_hold(e1)
			c.crouch = true
			if t > 0.6:
				_check(c.mates.glare == e1, "은신 동조: 백구가 숨은 적을 노려본다(흰 역삼각)")
				_shot("5_glare")
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
	print("동행 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
