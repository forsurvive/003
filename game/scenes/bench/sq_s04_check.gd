## SQ-S04 「도성이 뒤척인다」 확인 장면(단계 1-11c, SD-04a §4.4 · SD-09a L-R01-32 · 04): 실제 월드에서
##   ① 깨어나기 전 주민센터 정문(세움 간판 · 엎드린 파수) ② 21시 경보 — 파수가 남솔을 안고 아랫문을 지난다 ③ 정문 앞 파수 셋 · 정지 명령
##   ④ 관리자 후보 앞에서 멈칫(파수 초상 · [관리자 인증]) ⑤ 민원실 — 413 · 철망 안 남솔 ⑥ 해법 B 잔해 ⑦ 해법 D 흰 천 · 대기등
##   ⑧ 레이더 중계소 — 감시포 둘 · 앰버 경광 · 약한 철조망 ⑨ 돔 안 — 핵분열 전지 · 두뇌-4 ⑩ 전지를 뽑은 뒤 을 보이며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/sq_s04_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var side: SideS04
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
	st.vars.set_v("GAME_DAY", 3)
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.hud_on = true
	host.pipboy_ok = true
	host.story_hold = true
	host.date_text = "2277. 10. 25.  14:00"
	side = SideS04.new()
	add_child(side)
	side.setup(host, true)
	host.enter("X-BC", "from_X-S07")
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0
	host.player.loco.place(host.map.mark_pos("sentry") + Vector2(-2 * 32, 3 * 32))
	host.player.loco.facing = 4
	host.hints.clear()


func _at(a: int) -> void:
	var d := a - Clock.abs_min(host.date_text)
	if d > 0:
		host.date_text = Clock.add_minutes(host.date_text, d, host.st)


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
			if t > 1.2:
				side.tick()
				_check(side.looks.has("guard"), "깨어나기 전: 정문 앞 엎드린 파수")
				_shot("01_civic_before")
				_later(func() -> void:
					st.quests.set_stage("MQ-102", 10)
					side.tick()
					host.story_hold = false
					_at(int(st.vars.get_v("SQ_S04_WAKE_AT")))
					host.player.loco.place(host.map.mark_pos("X-BC:land1") + Vector2(3 * 32, 1 * 32))
					host.player.loco.facing = 6
					side.tick()
					stage = 1
					t = 0.0)
		1:
			if t > 2.4:
				_check(int(st.vars.get_v("SQ_S04_HELD")) == 1 and host.ev.actors.has("S04_CARRY"), "21시 경보: 파수가 남솔을 안고 걷는다")
				_shot("02_alarm_carry")
				_later(func() -> void:
					side._carry_end()
					st.quests.set_stage("SQ-S04", 30)
					host.player.loco.place(host.map.mark_pos("sentry") + Vector2(-1 * 32, 4 * 32))
					host.player.loco.facing = 0
					stage = 2
					t = 0.0)
		2:
			if t > 1.5:
				side.tick()
				_check(side.bots.filter(func(b): return is_instance_valid(b)).size() >= 2, "정문 앞 · 길 위 파수")
				_shot("03_sentries_halt")
				_later(func() -> void:
					st.vars.set_v("V_REGCARD", 4)
					st.vars.set_v("PC_SKP_SCIENCE", 60)
					host.play_scene("SQS04_HALT")
					stage = 3
					t = 0.0)
		3:
			if t > 1.6:
				_check(host.box.active, "관리자 후보 앞에서 멈칫 — 파수 초상과 [관리자 인증]")
				_shot("04_halt_portrait")
				_later(func() -> void:
					host.box._take({"type": "end"})
					host.date_text = "2277. 10. 27.  22:10"
					host.enter("K-33", "from_W")
					stage = 4
					t = 0.0)
		4:
			if t > 1.4:
				if host.box.active:
					host.box._take({"type": "end"})
				_check(host.map.id == "K-33", "민원실 — 번호표 413 · 철망 안 남솔")
				_shot("05_civic_room")
				_later(func() -> void:
					host.enter("X-BC", "from_X-S07")
					host.player.loco.place(host.map.mark_pos("sentry") + Vector2(-1 * 32, 4 * 32))
					side.tick()
					for e in side.bots:
						if is_instance_valid(e):
							e.cmb.dead = true
					side._on_killed("CR-305", 0)
					stage = 5
					t = 0.0)
		5:
			if t > 1.6:
				side.tick()
				_check(int(st.vars.get_v("SQ_S04_KILLED")) == 7 and side.looks.has("guard"), "해법 B: 정문 앞 잔해")
				_shot("06_wrecks")
				_later(func() -> void:
					st.vars.set_v("SQ_S04_KILLED", 0)
					st.vars.set_v("SQ_S04_OUT", 4)
					st.vars.set_v("SQ_S04_SLEEP", 3)
					side.tick()
					stage = 6
					t = 0.0)
		6:
			if t > 1.2:
				side.tick()
				_check(side.looks.has("cloth") and side.looks.has("lamp"), "해법 D: 흰 천 · 대기등")
				_shot("07_care_cloth")
				_later(func() -> void:
					st.vars.set_v("SQ_S04_OUT", 0)
					st.vars.set_v("SQ_S04_SLEEP", 0)
					host.date_text = "2277. 10. 28.  11:00"
					host.enter("X-RD", "arrive")
					host.player.loco.place(host.map.mark_pos("X-RD:dome_yard") + Vector2(0, 3 * 32))
					host.player.loco.facing = 0
					side.tick()
					stage = 7
					t = 0.0)
		7:
			if t > 1.6:
				side.tick()
				_check(side.turrets.filter(func(x): return is_instance_valid(x)).size() == 2 and side.radar_props.size() == 2, "레이더: 감시포 둘 · 경광 · 약한 철조망")
				_shot("08_radar")
				_later(func() -> void:
					host.enter("K-36", "from_X")
					stage = 8
					t = 0.0)
		8:
			if t > 1.2:
				_check(host.map.id == "K-36", "돔 안: 핵분열 전지 · 두뇌-4")
				_shot("09_dome_inside")
				_later(func() -> void:
					side._cmd(["batt"], func() -> void: pass)
					stage = 9
					t = 0.0)
		9:
			if t > 0.8:
				_check(int(st.vars.get_v("SQ_S04_BATT")) == 1 and int(st.vars.get_v("SQ_S04_SLEEP")) == 1, "전지를 뽑았다: 받침이 비고 두뇌-4가 꺼진다")
				_shot("10_battery_pulled")
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
	print("SQ-S04 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
