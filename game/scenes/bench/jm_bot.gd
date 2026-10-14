## 지하시장 봇(단계 1-4, SD-19 §10.2 봇 플레이): MQ-103 갈래를 실제 맵·대화·전투·해킹 위에서 처음부터 끝까지 돈다.
## 갈래(인자 첫째): job 출입세→상인회 일·박춘삼→둥지→출입패→문→해독→고백(과학)→북쪽 출구 매복 · vent 구청역 통로→둥지→환풍구(은신)→해독
##   · hack 역사 쇼핑몰→출입 단말 해킹→문→해독 · fee 카리스마 농담→면담료 300→문→해독→고백 실패(화술)
## 둘째 인자 = 스크린샷 폴더(없으면 찍지 않음). 끝에 '지하시장 봇 <갈래>: ○ n/m' 한 줄과 확인 줄을 찍는다.
## 실행: xvfb-run godot --path game res://scenes/bench/jm_bot.tscn -- job /tmp/shots
extends Node

var host: InteriorHost
var paths: Act1Paths
var st: StoryState
var route := "job"
var shots := ""
var plan: Array = []
var i := 0
var t := 0.0
var step_t := 0.0
var path := PackedVector2Array()
var want: Array = []
var checks: Array = []
var hold := 0.0
var shot_n := 0
var last_report := 0.0
var menu_t := 0.0
var shot_on := ""                                    ## 이 글귀가 든 대사 줄에서 한 장 찍는다(연출 확인)
var shot_tag := ""
var shot_wait := 0.0
var step_map := 0                                    ## 걸음 단계를 시작한 맵 노드(출구를 밟아 맵이 바뀌면 그 단계는 끝 — 월드 안 구역 이름 바뀜은 아니다)


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	route = a[0] if a.size() > 0 else "job"
	shots = a[1] if a.size() > 1 else ""
	host = InteriorHost.new()
	add_child(host)
	st = host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.quests.set_stage("MQ-101", 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 3)
	st.vars.set_v("PC_CAPS", 600)
	st.vars.set_v("PC_CH", 6 if route == "fee" else 5)
	st.vars.set_v("PC_SKP_SNEAK", 40 if route == "vent" else 0)
	st.vars.set_v("PC_SKP_SCIENCE", 50 if route == "job" else 40)
	Wanted.add(st, 10)
	for kv in [["W-002", 1], ["10mm 탄", 120], ["I-001", 6]]:
		st.call_fn("give", kv)
	host.body = "adult"
	host.hud_on = true
	host.date_text = "2277. 10. 25.  13:10"
	paths = Act1Paths.new()
	add_child(paths)
	paths.setup(host, true)
	host.combat.equip("W-002", st)
	match route:
		"job":
			host.enter("J-01", "from_W")
			plan = [["go", 14, 11], ["want", ["출입세를 낸다"]], ["go", 14, 13], ["check", "MQ103_GATE == 1 and MQ103_STAGE == 20", "출입세 → 단계 20"],
				["shot", "toll"],
				["go", 14, 18], ["go", 14, 19], ["go", 20, 6, "J-02"], ["go", 39, 13, "J-02"], ["go", 39, 15, "J-02"],
				["want", ["마영식", "무슨 일이든"]], ["talk", "C-050"], ["check", "MQ103_JOB == 1", "상인회 일 맡음"],
				["go", 19, 4, "J-03"], ["go", 19, 0, "J-03"], ["go", 4, 4, "J-02"], ["go", 4, 0, "J-02"],
				["want", ["같이 가자"]], ["talk", "C-018"], ["check", "MQ103_HIRE == 1", "박춘삼 고용(50캡)"],
				["go", 14, 18, "J-01"], ["go", 14, 19, "J-01"], ["go", 39, 14, "J-02"], ["go", 39, 15, "J-02"],
				["go", 19, 27, "J-03"], ["go", 19, 29, "J-03"], ["go", 60, 5, "J-09"], ["fight"], ["shot", "nest"],
				["check", "MQ103_NEST == 1 and MQ103_JOB == 2", "둥지 비움"],
				["loot", "청소부의 유해"],
				["go", 65, 3, "J-09"], ["go", 65, 0, "J-09"], ["want", ["(인사만"]], ["talk", "C-050"],
				["check", "has(\"M-078\") and JM_REG == 1 and MQ103_STAGE == 30", "출입패·단골·단계 30"],
				["go", 27, 4, "J-03"], ["go", 27, 3, "J-03"], ["check", "MQ103_DOOR == 1", "출입패로 문 열림"], ["go", 27, 0, "J-03"],
				["want", ["핍-보이를 내민다", "어떻게 아느냐", "회선 이야기"]], ["talk", "C-006"], ["shot", "ma"],
				["check", "K_CODE == 1 and K_NET == 1 and has(\"M-207\")", "해독(K_CODE·K_NET·메모)"],
				["check", "K_LINE == 1 and has(\"M-206\") and has(\"M-232\") and MQ103_STAGE == 100", "고백(시공 일지·사양서)"],
				["go", 11, 17, "J-06"], ["go", 19, 0, "J-03"], ["go", 4, 0, "J-02"], ["go", 14, 15, "J-01"], ["fight"], ["shot", "ambush"],
				["check", "MQ103_AMBUSH == 2", "북쪽 출구 매복을 이겼다"], ["check", "MQ102_STAGE == 100", "MQ-102 닫힘"]]
		"vent":
			host.enter("J-09", "from_W")
			plan = [["check", "MQ103_STAGE == 20 and MQ103_GATE == 3", "구청역 통로로 들어옴"], ["go", 10, 5], ["fight"],
				["go", 40, 3], ["want", ["소리 없이"]], ["use", 40, 2], ["check", "MQ103_SNEAK == 1 and MQ103_STAGE == 30", "환풍구(은신 50)"],
				["shot", "vent"], ["want", ["핍-보이를 내민다", "고맙다"]], ["talk", "C-006"],
				["check", "K_CODE == 1 and has(\"M-207\")", "해독"], ["go", 11, 17, "J-06"], ["check", "MQ103_STAGE == 100", "배전실을 나서면 끝"]]
		"hack":
			host.enter("J-02", "from_mall")
			plan = [["check", "MQ103_STAGE == 20 and MQ103_GATE == 4", "역사 쇼핑몰로 들어옴(출입세 없음)"],
				["go", 39, 14], ["go", 39, 15], ["go", 28, 4, "J-03"], ["go", 28, 3, "J-03"], ["use", 28, 2], ["hack"], ["shot", "hack"],
				["check", "MQ103_DOOR == 2", "출입 단말 해킹 → 문 열림"], ["go", 27, 3, "J-03"], ["go", 27, 0, "J-03"],
				["want", ["핍-보이를 내민다", "고맙다"]], ["talk", "C-006"], ["check", "K_CODE == 1", "해독"]]
		"fee":
			host.enter("J-01", "from_W")
			plan = [["go", 14, 11], ["want", ["피부 좋은"]], ["go", 14, 13], ["check", "MQ103_GATE == 2", "카리스마 6 농담으로 통과"],
				["go", 14, 18], ["go", 14, 19], ["go", 20, 6, "J-02"], ["go", 39, 13, "J-02"], ["go", 39, 15, "J-02"],
				["want", ["마영식", "면담료"]], ["talk", "C-050"], ["check", "has(\"M-078\") and PC_CAPS <= 300", "면담료 300 → 출입패"],
				["go", 27, 4, "J-03"], ["go", 27, 3, "J-03"], ["go", 27, 0, "J-03"],
				["want", ["핍-보이를 내민다", "어떻게 아느냐", "직접 깔았죠"]], ["talk", "C-006"],
				["check", "K_CODE == 1 and (MQ103_CONF == 1 or MQ103_CONF == 2)", "해독 + 화술 판정(성공·실패 둘 다 길이 있다)"]]
		"hub":                                                          # MQ-102 허브: 잠든 파수(월드 발견 자리) → 구울 행상 주성호(단서 1) → 하숙자(단서 2)
			st.vars.set_v("MQ101_RAD", 1)
			host.enter("W", "L-R01-32")
			plan = [["go", 911, 1395], ["shoton", "판독", "sentry_lit"], ["go", 912, 1393],
				["check", "MQ102_ROBOT == 1 and MQ102_STAGE == 10", "잠든 파수가 깨어났다 꺼짐"],
				["use", 912, 1392], ["shot", "sentry_after"],
				["go", 891, 1381], ["go", 891, 1378], ["go", 894, 1374], ["want", ["읽을 사람"]], ["talk", "N-R02-018"],
				["check", "MQ102_C1 == 1 and MQ103_STAGE == 10", "구울 행상 → 단서 1(MQ-103 열림)"],
				["go", 884, 1365], ["go", 884, 1364], ["go", 7, 7, "B-03"], ["want", ["깨진 숫자 줄"]], ["talk", "C-057"], ["shot", "hasukja"],
				["check", "MQ102_C2 == 1 and MQ104_STAGE == 10", "하숙자 옛 여의도 지도 → 단서 2(MQ-104 열림)"]]
	plan.append(["end"])


func _process(dt: float) -> void:
	t += dt
	step_t += dt
	if t > 400.0:
		_finish("시간 초과")
		return
	_box(dt)
	if i >= plan.size():
		return
	var s: Array = plan[i]
	if host.box.active or host.ev.busy() or host.busy:
		host.input_fn = func() -> Vector2: return Vector2.ZERO
		if s[0] != "fight":
			return
	match str(s[0]):
		"go":
			if s.size() > 3 and host.map.id != str(s[3]) and step_map == 0:
				return
			if step_map == 0:
				step_map = host.map.get_instance_id()
			elif host.map.get_instance_id() != step_map:
				_next()
				return
			host.input_fn = _walk.bind(Vector2(int(s[1]) * 32 + 16, int(s[2]) * 32 + 16))
			if host.player.loco.render.distance_to(Vector2(int(s[1]) * 32 + 16, int(s[2]) * 32 + 16)) < 6.0 or step_t > 40.0:
				if step_t > 40.0:
					print("  [봇] 걸어서 못 감: ", s, " 지금 ", host.map.id, " ", host.map.tile_of(host.player.loco.logical))
				_next()
		"want":
			want = s[1]
			_next()
		"shoton":
			shot_on = str(s[1])
			shot_tag = str(s[2])
			_next()
		"talk":
			var n := _npc(str(s[1]))
			if n.is_empty():
				print("  [봇] 인물 없음: ", s[1])
				_next()
				return
			var goal: Vector2 = n["actor"].loco.logical
			var p := host.player.loco.logical
			if p.distance_to(goal) < 80.0 or step_t >= 30.0:              # 가까우면(계산대 너머 포함) 바라보고 말을 건다
				host.input_fn = func() -> Vector2: return Vector2.ZERO
				host.player.loco.facing = Locomotion.snap8(goal - p, 0.0)
				host.player._show()
				if host.interact() or step_t >= 30.0:
					if step_t >= 30.0:
						print("  [봇] 말 걸기 실패: ", s[1], " 거리 ", p.distance_to(goal), " 맵 ", host.map.id, " ", host.map.tile_of(p), " 상대 ", host.map.tile_of(goal))
						_shot("talkfail")
					_next()
					return
			host.input_fn = _walk.bind(goal + (p - goal).normalized() * 34.0)
		"use":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			host.player.loco.facing = Locomotion.snap8(Vector2(int(s[1]) * 32 + 16, int(s[2]) * 32 + 16) - host.player.loco.logical, 0.0)
			host.player._show()
			host.interact()
			_next()
		"loot":
			for c in host.map.boxes:
				var b: Dictionary = host.map.boxes[c]
				if str(b.get("name", "")) == str(s[1]):
					var items: Dictionary = host.box_contents(b)["items"]
					print("  [봇] %s: %s" % [s[1], str(items)])
					checks.append([not items.is_empty(), "유해 소지품이 나온다(%d종)" % items.size()])
			_next()
		"fight":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			var alive := host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy")
			if alive.is_empty():
				if step_t > 1.5:
					host.combat.bot = {}
					_next()
				return
			step_t = 0.0 if step_t > 1.0 and not alive.is_empty() and t < 380.0 else step_t
			if t - last_report > 10.0:
				last_report = t
				print("  [봇] 싸움 %.0f초: 남은 %s · 체력 %d" % [t, str(alive.map(func(e): return "%s hp%d" % [str(host.map.tile_of(e.loco.logical)), int(e.cmb.hp)])), int(host.combat.pc.hp)])
			alive.sort_custom(func(a, b): return a.loco.logical.distance_to(host.player.loco.logical) < b.loco.logical.distance_to(host.player.loco.logical))
			var far: float = alive[0].loco.logical.distance_to(host.player.loco.logical)
			if far > 160.0:                                                # 멀면 다가간다(사거리·시야 안으로)
				host.input_fn = _walk.bind(alive[0].loco.logical)
			host.combat.bot = {"aim": alive[0].loco.logical + Vector2(0, -12), "fire": true, "aimed": true,
				"reload": host.combat.mags.get(host.combat.weapon_id, 1) == 0, "stim": host.combat.pc.hp < host.combat.pc.max_hp * 0.4}
		"hack":
			var tm: TerminalScreen = host.terminal
			if tm == null:
				if step_t > 3.0:
					print("  [봇] 단말이 안 열렸다")
					_next()
				return
			if tm.mode == "hack" and tm.hack.state == "play" and tm.shown > 9999:
				var wrong := -1
				for wi in tm.hack.words.size():
					if tm.hack.words[wi] != tm.hack.answer and not tm.hack.removed.has(wi):
						wrong = wi
				if tm.hack.tries == 4 and wrong >= 0:
					tm.pick(tm.hack.starts[wrong])                         # 한 번 틀려 본다(일치 표시 확인)
				else:
					tm.pick(tm.hack.starts[tm.hack.words.find(tm.hack.answer)])
			elif tm.mode == "hack":
				tm.shown = 1e9
			elif tm.mode == "menu":
				menu_t += get_process_delta_time()
				if menu_t < 1.5:                                        # 글이 다 찍힌 뒤에 찍는다(타자 효과)
					return
				menu_t = 0.0
				_shot("hack_menu")
				tm._open_entry(0)
			elif tm.mode == "read" and menu_t < 1.5:
				menu_t += get_process_delta_time()
				if menu_t >= 1.5:
					_shot("hack_read")
			elif tm.mode == "read":
				menu_t = 0.0
				tm.close(true)
				_next()
		"check":
			var ok := StoryExpr.test(str(s[1]), st)
			checks.append([ok, str(s[2])])
			print("  [확인] %s %s" % ["○" if ok else "×", s[2]])
			_next()
		"shot":
			_shot(str(s[1]))
			_next()
		"end":
			_finish("")


func _next() -> void:
	i += 1
	step_t = 0.0
	step_map = 0
	path = PackedVector2Array()


func _npc(id: String) -> Dictionary:
	for n in host.npcs:
		if str(n["id"]) == id and is_instance_valid(n["actor"]):
			return n
	return {}


func _walk(goal: Vector2) -> Vector2:
	var p := host.player.loco.render
	if p.distance_to(goal) < 4.0:
		return Vector2.ZERO
	if path.is_empty() or step_t < 0.05 or int(step_t * 2.0) % 6 == 0:
		path = NpcRoutine.with_start(host.map, p, goal)
	while path.size() > 0 and (NpcRoutine.arrived(p, path[0]) or (path.size() > 1 and p.distance_to(path[1]) <= path[0].distance_to(path[1]) + 2.0)):
		path.remove_at(0)
	if path.is_empty():
		return (goal - p).normalized()
	return NpcRoutine.step_dir(p, path[0])


## 대화: 줄은 넘기고, 선택지는 원하는 글귀(want 앞쪽 우선)를 고른다. 없으면 첫째
func _box(dt: float) -> void:
	if not host.box.active:
		return
	hold += dt
	if hold < 0.25:
		return
	hold = 0.0
	match str(host.box.state.get("type", "")):
		"line":
			if shot_on != "" and str(host.box.state.get("text", "")).contains(shot_on):
				shot_wait += 0.25
				if shot_wait < 1.75:                                    # 글이 다 찍히게 1.5초 더 기다렸다 찍는다
					return
				_shot(shot_tag)
				shot_on = ""
			host.box.next()
		"choices":
			var opts: Array = host.box.state.get("opts", [])
			var pick := -1
			for w in want:
				for k in opts.size():
					if pick < 0 and str(opts[k]["text"]).contains(str(w)) and bool(opts[k].get("enabled", true)):
						pick = k
			_shot("choice")
			host.box.pick(maxi(0, pick))


func _shot(tag: String) -> void:
	if shots == "":
		return
	shot_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%s_%02d_%s.png" % [shots, route, shot_n, tag])


func _finish(why: String) -> void:
	set_process(false)
	if why != "" and i < plan.size():
		print("  [봇] 멈춘 단계 %d: %s · 맵 %s %s" % [i, str(plan[i]), host.map.id if host.map else "-", str(host.map.tile_of(host.player.loco.logical)) if host.map else ""])
	var ok := checks.filter(func(c): return c[0]).size()
	print("지하시장 봇 %s: %s %d/%d%s · MQ-103 %d · 캡 %d · XP %d · 지하 %d" % [route, "○" if ok == checks.size() and why == "" else "×", ok,
		checks.size(), (" (" + why + ")") if why != "" else "", st.quests.stage("MQ-103"), int(st.vars.get_v("PC_CAPS")),
		int(st.vars.get_v("PC_XP")), int(st.vars.get_v("AFF_JH")) if st.vars.has("AFF_JH") else 0])
	get_tree().create_timer(0.3).timeout.connect(get_tree().quit)
