## 거처 확인 장면(단계 1-8b, SD-15 §7.2 · §7.5 · §7.7 · SD-04a §2.5 · SD-12 §7.6 · SD-11 §11.5): 봉천 옥탑방을
##   ① 조건(MQ-101 완료 + 봉천 우호) → 그날은 열쇠가 안 나온다 → ② 다음 날 B-01에 들어오면 조만석이 열쇠(HOME_BC_KEY) → 방을 다시 들어와 가구가 선다
##   → ③ 보관함에 넣은 물건이 열흘 뒤에도 그대로 → ④ 내 침대에서 수면 창 · 8시간 자면 HP 전부 + 숙면(경험치 +10%)
##   → ⑤ 봉천 적대로 압류(보관함·침대가 닫힌다 · 딱지 장면) → ⑥ 중립으로 돌아오면 풀린다(물건 그대로) → ⑦ 백구 낮잠(문 앞에 있고 바깥 자리엔 없다)
##   순서로 돌며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/home_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var home: HomeBc
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var saw_key_line := false


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
	st.vars.set_v("MQ101_RESULT", 2)
	st.vars.set_v("MQ101_DOG", 2)
	st.vars.set_v("GAME_DAY", 3)
	st.vars.set_v("AFF_JC_BC", 25)
	st.vars.set_v("PC_CAPS", 300)
	st.events.clear()
	st.quests.events.clear()
	st.call_fn("give", ["I-002", 3])
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	host.date_text = "2277. 10. 26.  10:20"
	home = HomeBc.new()
	add_child(home)
	home.setup(host, true)
	host.enter("X-BC", "from_B-01")


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	match stage:
		0:
			if t > 1.0:
				home.check()
				_check(int(st.vars.get_v("HOME_BC_OK")) == 3 and not home.key_due(), "조건이 찬 날(3일)을 적고, 그날은 열쇠가 안 나온다")
				host.advance_minutes(24 * 60)
				_check(home.key_due(), "다음 날(%d일) 아침 뒤 열쇠 때가 된다" % int(st.vars.get_v("GAME_DAY")))
				host.enter("B-01", "from_X-BC")
				_go()
		1:                                                               # 열쇠 장면: 줄은 넘기고 고르기는 첫째
			if host.box.active:
				var s: Dictionary = host.box.state
				if str(s.get("type", "")) == "line" and t > 0.35:
					if str(s.get("text", "")).contains("이제 빌린 거 아니다") and not saw_key_line:
						saw_key_line = true
						_shot("1_key")
						t = 0.0
						return
					host.box.next()
					t = 0.0
				elif str(s.get("type", "")) == "choices" and t > 0.5:
					host.box.pick(0)
					t = 0.0
				return
			if int(st.vars.get_v("HOME_BC")) == 1 and not host.busy and not host.ev.busy() and t > 1.0:
				_check(saw_key_line and st.items.has("M-136-BC"), "조만석이 '빌린 침대였지. 이제 빌린 거 아니다.'와 함께 봉천 계단 열쇠(M-136-BC)를 준다")
				var names := host.map.props.map(func(p): return str(p["name"]))
				_check(host.map.id == "B-01" and names.has("keepsake_case") and names.has("bandaji") and names.has("home_locker"),
					"방을 다시 들어오니 입주 기념 진열장 · 반닫이 궤짝 · 철제 사물함이 선다")
				_go()
			elif t > 30.0:
				_check(false, "열쇠 장면이 끝나지 않았다(HOME_BC %d)" % int(st.vars.get_v("HOME_BC")))
				stage = 8
		2:
			if t > 0.8:
				_shot("2_room")
				var b := host._front_box([Vector2i(20, 12)])
				var b2 := host._front_box([Vector2i(24, 6)])
				_check(not b.is_empty() and not b2.is_empty() and str(b.get("owner", "")) == "PC", "보관함 둘(궤짝 · 사물함)이 열리고 내 것이다")
				var c := host.box_contents(b)
				_check((c["items"] as Dictionary).is_empty(), "새 보관함은 비어 있다")
				st.items.erase("I-002")
				c["items"]["I-002"] = 3                                          # 스팀팩 3개를 궤짝에 넣는다
				host.advance_minutes(10 * 24 * 60)
				var c2 := host.box_contents(b)
				_check(int(c2["items"].get("I-002", 0)) == 3, "열흘 뒤에도 궤짝의 스팀팩 3개가 그대로(다시 채우거나 비우지 않는다)")
				_go()
		3:
			if t > 0.5:
				var bd := host.bed_front([Vector2i(22, 5)])
				_check(not bd.is_empty() and bool(bd["owned"]) and not bool(bd["other"]), "옥탑방 요는 내 침대(숙면) — %s" % str(bd.get("name", "")))
				host.player.loco.logical = Vector2(21 * 32 + 16, 5 * 32 + 16)
				host.combat.pc.hp = host.combat.pc.max_hp * 0.3
				host.open_wait(bd)
				_go()
		4:
			if t > 0.8 and not has_meta("wait_shot"):
				set_meta("wait_shot", true)
				_shot("3_sleep")
				return
			if t > 1.2 and host.wait_ui != null:
				host.wait_ui.close(true)
				_go()
		5:
			if not host.busy and t > 1.0:
				_check(host.combat.pc.hp >= host.combat.pc.max_hp and int(st.vars.get_v("WELL_RESTED")) > 0, "8시간 자고 HP 전부 회복 + 숙면")
				var x0 := int(st.vars.get_v("PC_XP"))
				st.call_fn("xp", [100])
				_check(int(st.vars.get_v("PC_XP")) - x0 == 110, "숙면 중 경험치 100 → 110")
				st.vars.set_v("AFF_JC_BC", -40)
				home.check()
				_check(int(st.vars.get_v("HOME_BC_NOTE")) == 1 and int(st.vars.get_v("HOME_BC")) == 1, "봉천 경계(−40): '출입 자제' 쪽지(아직 들어간다)")
				_check(bool(host.bed_front([Vector2i(22, 5)]).get("other", false)) and not host._front_box([Vector2i(24, 6)]).is_empty(),
					"경계: 침대는 못 쓰고(SD-11 §11.5) 보관함은 열린다")
				st.vars.set_v("AFF_JC_BC", -70)
				home.check()
				_check(int(st.vars.get_v("HOME_BC")) == 2, "봉천 적대(−70): 압류")
				_check(host._front_box([Vector2i(20, 12)]).is_empty(), "압류 중 궤짝은 열리지 않는다")
				var bd := host.bed_front([Vector2i(22, 5)])
				_check(bool(bd.get("other", false)), "압류 중 침대도 못 쓴다")
				host.enter("B-01", "home_in")
				_go()
		6:                                                               # 압류 딱지 장면
			if host.box.active:
				if t > 0.35:
					if not has_meta("seize_shot"):
						set_meta("seize_shot", true)
						_shot("4_seized")
					host.box.next()
					t = 0.0
				return
			if t > 1.0:
				_check(int(st.vars.get_v("HOME_BC_NOTE")) == 4, "압류 딱지 장면을 한 번 본다")
				st.vars.set_v("AFF_JC_BC", -10)
				home.check()
				var c := host.box_contents(host.map.boxes[Vector2i(20, 12)])
				_check(int(st.vars.get_v("HOME_BC")) == 1 and int(c["items"].get("I-002", 0)) == 3, "중립(−10)으로 돌아오면 풀리고 스팀팩 3개가 그대로")
				_go()
		7:                                                               # 압류가 풀린 장면 → 백구 낮잠
			if host.box.active:
				if t > 0.35:
					host.box.next()
					t = 0.0
				return
			if t > 1.0 and not has_meta("nap"):
				set_meta("nap", true)
				_check(int(st.vars.get_v("HOME_BC_NOTE")) == 0, "'압류가 풀렸다' 장면 뒤 알림이 지워진다")
				var day := int(st.vars.get_v("GAME_DAY"))
				var naps := 0
				for d in 30:
					home._on_day(day + d)
					naps += int(st.vars.get_v("BAEKGU_NAP"))
				_check(naps >= 3 and naps <= 16, "백구 낮잠 30일 중 %d일(30%%)" % naps)
				var d2 := day
				while true:
					home._on_day(d2)
					if int(st.vars.get_v("BAEKGU_NAP")) == 1:
						break
					d2 += 1
				host.enter("B-01", "home_in")
				t = 0.0
				return
			if has_meta("nap") and t > 1.0 and not has_meta("nap_shot"):
				set_meta("nap_shot", true)
				var here := host.npcs.any(func(n): return str(n["id"]) == "C-015")
				_check(here, "낮잠 날: 백구가 옥탑방 문 앞에 있다")
				_shot("5_nap")
				return
			if has_meta("nap_shot") and t > 1.5:
				host.enter("X-BC", "from_B-01")
				_go()
		8:
			if t > 1.0:
				var there := host.npcs.any(func(n): return str(n["id"]) == "C-015")
				_check(not there, "낮잠 날: 봉천 바깥 자리에는 백구가 없다(한 곳에만, SD-20 P3)")
				var n := checks.filter(func(c): return c[0]).size()
				print("거처 벤치: %s %d/%d" % ["○" if n == checks.size() else "×", n, checks.size()])
				stage = 99
				get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


func _go() -> void:
	stage += 1
	t = 0.0


func _check(ok: bool, what: String) -> void:
	checks.append([ok, what])
	print("  [확인] %s %s" % ["○" if ok else "×", what])


func _shot(tag: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/home_%s.png" % [shots, tag])
