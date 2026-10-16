## SQ-S02 「물 반 컵의 값」 확인 장면(단계 1-11b, SD-04a §4.2 · SD-09a L-R01-10 · 31 · 12): 실제 월드에서
##   ① 봉천 배수지 마당(X-BS) — 조수안 · 급수 꼭지 줄 ② 밸브실(K-32) 수위계 둘째 칸 ③ 삼성산 능선 밸브 캠프(X-SS) — 수금원이 외친다
##   ④ 캠프가 비면 사슬 감긴 밸브 → 탈환(A) 뒤 끊긴 사슬 ⑤ 계엄군 관리(D) — 철판 표지 · 확성기 ⑥ 낙성대 고개(X-NS) 사이렌
##   ⑦ 22시 윗문 쪽문 — 남건희와 척후 ⑧ 03시 함정 — 계단참 감시조 셋 · 습격조 여섯 을 보이며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/sq_s02_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var side: SideS02
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var _next: Callable = Callable()
var _next_t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.hud_on = true
	host.pipboy_ok = true
	host.story_hold = true
	host.date_text = "2277. 10. 27.  10:20"
	side = SideS02.new()
	add_child(side)
	side.setup(host, true)
	side.tick()
	st.vars.set_v("GAME_DAY", 5)
	side._on_day(5)
	st.vars.set_v("GAME_DAY", 7)
	st.quests.set_stage("SQ-S02", 20)
	host.enter("X-BS", "arrive")
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0
	host.player.loco.place(host.map.mark_pos("X-BS:yard") + Vector2(-2 * 32, 1 * 32))
	host.player.loco.facing = 0
	host.hints.clear()


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	if _next.is_valid():
		_next_t += dt
		if _next_t > 0.3:
			var f := _next
			_next = Callable()
			f.call()
		return
	match stage:
		0:
			if t > 1.0:
				side.tick()
				_check(host.ev.actors.has("N-R01-032"), "배수지 마당: 조수안(낮)")
				_check(int(st.vars.get_v("SQ_S02_LEVEL")) == 2, "수위계 둘째 칸(셋째 날)")
				_shot("01_reservoir_yard")
				_later(func() -> void:
					host.enter("K-32", "from_X")
					stage = 1
					t = 0.0)
		1:
			if t > 1.0:
				_check(host.map.id == "K-32", "밸브실")
				_shot("02_valve_room_gauge")
				_later(func() -> void:
					host.date_text = "2277. 10. 29.  14:00"
					host.enter("X-SS", "arrive")
					host.player.loco.place(host.map.mark_pos("X-SS:valve_front") + Vector2(0, 7 * 32))
					host.player.loco.facing = 0
					stage = 2
					t = 0.0)
		2:
			if t > 1.2:
				_check(side.camp_on and side.camp.size() == 5 and is_instance_valid(side.toller), "밸브 캠프: 수금원 + 약탈자 셋 + 경비견")
				_check(host.box.active, "수금원이 외친다(물값 30캡)")
				_shot("03_valve_camp_toll")
				_later(func() -> void: host.box._take({"type": "end"}))
				stage = 3
				t = 0.0
		3:
			if t > 0.5:
				for e in side.camp:
					e.cmb.dead = true
				side._on_killed("CR-421", 0)
				side._clear(side.camp)
				host.player.loco.place(host.map.mark_pos("X-SS:valve_front") + Vector2(32, 32))
				stage = 4
				t = 0.0
		4:
			if t > 1.0:
				_check(int(st.vars.get_v("SQ_S02_CAMP")) == 1 and side._valve_look == "shut", "빈 캠프: 사슬 감긴 밸브")
				_shot("04_valve_shut")
				_later(func() -> void: side._cmd(["open"], func() -> void: pass))
				stage = 5
				t = 0.0
		5:
			if t > 1.0:
				_check(side._valve_look == "open" and int(st.quests.stage("SQ-S02")) == 70, "탈환: 끊긴 사슬 · 단계 70")
				_shot("05_valve_open")
				_later(func() -> void: st.vars.set_v("SQ_S02_BJ", 1))
				stage = 6
				t = 0.0
		6:
			if t > 1.0:
				_check(side._valve_look == "bj" and side.valve_props.size() == 3, "계엄사령부 관리: 철판 표지 · 확성기")
				_shot("06_valve_bj")
				_later(func() -> void:
					host.date_text = "2277. 10. 29.  15:00"
					host.enter("X-NS", "arrive")
					host.player.loco.place(host.map.mark_pos("X-NS:talk") + Vector2(0, -3 * 32))
					host.player.loco.facing = 0
					stage = 7
					t = 0.0)
		7:
			if t > 1.5:
				_check(is_instance_valid(side.siren) and side.siren.who == "N-R01-062", "낙성대 고개: 척후장 사이렌")
				_check(host.box.active, "사이렌이 말을 건다")
				_shot("07_siren")
				_later(func() -> void:
					host.box._take({"type": "end"})
					st.vars.set_v("SQ_S02_SIREN", 3)
					st.call_fn("give", ["M-301", 1])
					host.date_text = "2277. 10. 29.  22:30"
					host.enter("X-BC", "from_X-S07")
					stage = 8
					t = 0.0)
		8:
			if t > 0.6:
				side.tick()
				host.player.loco.place(host.map.mark_pos("X-BC:upgate") + Vector2(-5 * 32, 5 * 32))
				host.combat.crouch = true
				stage = 9
				t = 0.0
		9:
			if t > 0.3 and not host.box.active:
				_check(side.night_on, "22시 윗문 쪽문: 남건희와 척후")
				_shot("08_night_gate")
				stage = 10
				t = 0.0
			elif host.box.active and t > 0.6:
				_check(side.night_on, "22시 윗문 쪽문: 남건희와 척후 · 지켜보면 밤 원고")
				_shot("08_night_gate")
				_later(func() -> void: host.box._take({"type": "end"}))
				stage = 10
				t = 0.0
		10:
			if t > 0.5:
				host.combat.crouch = false
				side._night_off()
				st.vars.set_v("SQ_S02_KNOW", 1)
				side._cmd(["insider", "3"], func() -> void: pass)
				host.date_text = Clock.fmt(Clock.parse("2277. 10. 30.  03:02"))
				host.player.loco.place(host.map.mark_pos("X-BC:land1") + Vector2(0, -32))
				host.player.loco.facing = 2
				side.tick()
				stage = 11
				t = 0.0
		11:
			if t > 2.0:
				_check(side.trap_on and side.trap_foes.size() == 6 and host.combat.allies.size() == 3, "03시 함정: 습격조 6 · 감시조 3")
				_shot("09_trap_0300")
				stage = 12
				t = 0.0
		12:
			if t > 0.4:
				for e in side.trap_foes:
					e.cmb.dead = true
				side._trap_tick()
				_check(int(st.vars.get_v("SQ_S02_TRAP_DONE")) == 1 and int(st.vars.get_v("SQ_S02_NH_DEAD")) == 0, "계단참①을 지켰다 — 남건희 생존")
				_finish()


func _later(f: Callable) -> void:
	_next = f
	_next_t = 0.0


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
	print("SQ-S02 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
