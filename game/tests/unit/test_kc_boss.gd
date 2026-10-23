## 단계 1-13a3 깡철이 보스전(SD-14 CR-512 · SD-09a L-R01-15): 마당에 세우기 · 국면 문턱(70% · 40%) · 사슬 풀기 2초 · 램프 · 항복 XP 한 번 ·
## 세 갈래(놓아줌 · 헬멧 · 쏨) · 사흘 뒤 고물상 헬멧 · 애니멀 프렌드 · 통행세 · 사슬 고리 · 말로 물러남 · 현상금 · 머리 DR 합산.
extends RefCounted


func _host(hour := 14) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 6)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 29.  %02d:00" % hour
	var c := KcBoss.new()
	c.setup(h)
	h.enter("X-BC", "@838,1358")
	c.tick()
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: KcBoss, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "kc":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				i = -1
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
				k += 1
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return dr.errors


func _hurt(e: Enemy, to_frac: float) -> void:
	e.cmb.last_by = "player"
	e.cmb.take({"hp": e.cmb.hp - e.cmb.max_hp * to_frac + 5.0}, e.loco.logical + Vector2(64, 0))


func test_kc_spawn_phases(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: KcBoss = a[2]
	t.ok(c.on and c._alive(c.kc), "마당 40칸 안: 깡철이가 선다")
	t.eq([c.dogs.size(), c.gang.size()], [3, 3], "사슬 개 셋 · 드럼불 졸개 셋(낮)")
	t.ok(c.kc.cmb.team == "calmkc" and c.gang.all(func(g): return g.cmb.team == "calmkc"), "말을 걸기 전엔 아무도 덤비지 않는다")
	t.eq(c.kc.weapon.get("id", ""), "W-014", "주무기 사냥용 소총(BOSS_ARMS)")
	t.eq(c.kc.alt_weapon.get("name", ""), "렌치", "붙으면 렌치(쇠파이프 판정)")
	_hurt(c.kc, 0.2)
	t.ok(c.kc.cmb.hp >= c.kc.cmb.max_hp * 0.7 - 0.5, "램프 전엔 70% 아래로 안 내려간다(기습이 국면을 건너뛰지 못함)")
	t.eq(c.phase, 1, "맞으면 싸움 — 사슬 풀기")
	t.ok(c.dogs.all(func(d): return d.cmb.team == "enemy"), "경비견이 풀린다")
	t.eq(c.kc.cmb.team, "calmkc", "사슬을 푸는 2초 동안 깡철이는 쏘지 않는다")
	c.tick(2.2)
	t.eq(c.kc.cmb.team, "enemy", "그 뒤 총을 든다")
	c.tick(0.25)
	t.eq(c.phase, 2, "HP 70%: 동쪽 램프 윗단으로")
	t.eq(c.kc._dash_dr, 0.0, "달리는 동안 DR 덤은 없다")
	c.kc.set_meta("dash_done", true)
	c.tick(0.25)
	t.ok(c.phase == 3 and c.kc.fixed and is_equal_approx(c.kc.cmb.hp_floor, c.kc.cmb.max_hp * 0.4), "램프 자리: 버티며 쏜다 · 문턱 40%")
	var xp0 := int(st.vars.get_v("PC_XP"))
	_hurt(c.kc, 0.1)
	c.tick(0.25)
	t.eq(c.phase, 4, "HP 40%: 항복")
	t.eq(c.kc.brain.state, AIBrain.S.SURRENDER, "손을 든다")
	t.eq(int(st.vars.get_v("PC_XP")) - xp0, 40, "항복 순간 XP 40 한 번")
	t.ok(c._interact() or h.box.active, "항복한 깡철이에게 조사 키 = 결말 장면")
	h.free()


func test_kc_endings(t) -> void:
	for pick in ["놓아준다", "헬멧은", "쏜다"]:
		var a := _host()
		var h: InteriorHost = a[0]
		var st: StoryState = a[1]
		var c: KcBoss = a[2]
		c._fight("시험")
		c.tick(2.2)
		_hurt(c.kc, 0.6)
		c.tick(0.25)
		c.kc.set_meta("dash_done", true)
		c.tick(0.25)
		_hurt(c.kc, 0.1)
		c.tick(0.25)
		var k0 := int(st.vars.get_v("V_KARMA"))
		var xp0 := int(st.vars.get_v("PC_XP"))
		t.eq(_play(st, c, "KC_GIVE", [pick]), [], "결말 장면(%s)" % pick)
		match pick:
			"놓아준다":
				t.eq(int(st.vars.get_v("KC_STATE")), 2, "놓아줌")
				t.eq(st.count_of("A-102"), 0, "헬멧은 그가 가져간다")
				st.vars.set_v("GAME_DAY", 9)
				c.tick()
				t.eq(int((st.boxes.get("shop:V01", {}).get("mine", {}) as Dictionary).get("A-102", 0)), 1, "사흘 뒤 봉천 고물상 진열대에 헬멧")
			"헬멧은":
				t.ok(int(st.vars.get_v("KC_STATE")) == 3 and st.count_of("A-102") == 1, "헬멧을 벗겨 가고 놓아줌")
				t.eq(int(st.vars.get_v("KC_BALD")), 6, "맨머리 소문의 날(그날 고시촌 상담료 두 배)")
			"쏜다":
				t.ok(int(st.vars.get_v("KC_STATE")) == 4 and st.count_of("A-102") == 1, "쏨: 죽음 · 헬멧은 몸에서")
				t.eq(int(st.vars.get_v("PC_XP")) - xp0, 0, "항복 뒤 사살엔 XP가 없다")
				t.eq(int(st.vars.get_v("V_KARMA")) - k0, -10, "항복한 자를 쏨: 카르마 −10")
		h.free()


func test_kc_talk_toll_loose_perk(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: KcBoss = a[2]
	st.vars.set_v("PC_CAPS", 100)
	t.eq(_play(st, c, "KC_MEET", ["캡으로 낸다"]), [], "통행세 30캡")
	t.ok(int(st.vars.get_v("KC_TOLL")) == 6 and int(st.vars.get_v("PC_CAPS")) == 70, "통행세 낸 날(RE-002 cond)")
	t.ok(StoryExpr.test("KC_TOLL == 0 or KC_TOLL != GAME_DAY", st) == false, "그날은 고가 아래 매복이 뜨지 않는다")
	st.vars.set_v("KC_TOLL", 0)
	st.vars.set_v("GAME_DAY", 0)
	t.ok(StoryExpr.test("KC_TOLL == 0 or KC_TOLL != GAME_DAY", st), "날짜가 0이어도 통행세를 안 냈으면 매복은 그대로")
	t.eq(c.phase, 0, "통행세를 내면 싸움 없음")
	h.free()
	a = _host()
	h = a[0]
	st = a[1]
	c = a[2]
	st.call_fn("give", ["M-158", 1])
	st.vars.set_v("PC_SKP_SPEECH", 100)
	var errs := _play(st, c, "KC_MEET", ["외눈", "봉천 계단"])
	t.eq(errs, [], "외눈 인식표 → 화술")
	t.ok(int(st.vars.get_v("KC_STATE")) == 2 and int(st.vars.get_v("KC_TALK")) == 1 or int(st.vars.get_v("KC_STATE")) == 0, "말로 물러나게 하면 놓아줌과 같은 결말(실패면 싸움)")
	h.free()
	a = _host()
	h = a[0]
	st = a[1]
	c = a[2]
	c._cmd(["loose"], func() -> void: pass)
	t.ok(int(st.vars.get_v("KC_LOOSE")) == 1 and c.dogs.is_empty(), "사슬 고리를 빼면 개가 흩어진다")
	c._clear()
	c.tick()
	t.eq(c.dogs.size(), 0, "다음에 와도 개가 없다")
	h.free()
	a = _host()
	h = a[0]
	st = a[1]
	c = a[2]
	st.vars.set_v("PK_045", 1)
	c._clear()
	c.tick()
	var xp0 := int(st.vars.get_v("PC_XP"))
	c._fight("시험")
	t.eq(c.phase, 4, "애니멀 프렌드: 개가 곁에 앉고 깡철이 혼자 바로 항복")
	t.eq(int(st.vars.get_v("PC_XP")) - xp0, 70, "해법 XP 30 + 항복 XP 40")
	h.free()


func test_kc_bounty_head_dr(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: KcBoss = a[2]
	st.vars.set_v("KC_STATE", 3)
	st.call_fn("give", ["A-102", 1])
	var caps0 := int(st.vars.get_v("PC_CAPS"))
	t.eq(_play(st, c, "KC_BOUNTY"), [], "현상금 장면")
	t.ok(int(st.vars.get_v("PC_CAPS")) - caps0 == 300 and int(st.vars.get_v("KC_BOUNTY")) == 1, "헬멧을 보이면 300")
	st.vars.set_v("KC_BOUNTY", 0)
	st.vars.set_v("KC_STATE", 2)
	caps0 = int(st.vars.get_v("PC_CAPS"))
	_play(st, c, "KC_BOUNTY")
	t.eq(int(st.vars.get_v("PC_CAPS")) - caps0, 150, "놓아줬으면 반값 150")
	var dr0 := h.pc_dr()
	st.vars.set_v("PC_HEAD", "A-102")
	t.eq(h.pc_dr() - dr0, 7.0, "머리 장비 DR도 더한다(깡철이의 헬멧 7)")
	h.free()


func test_kc_memory(t) -> void:
	# 재미 검수(구현 뒤) ①: 깡철이는 지난 만남을 기억한다 — 그날 다시 오면 말 없이 싸움 · 깎인 HP 그대로, 다음 날부터 통행세 두 배
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: KcBoss = a[2]
	c._fight("시험")
	c.tick(2.2)
	_hurt(c.kc, 0.75)
	c._clear()
	t.eq(int(st.vars.get_v("KC_FOUGHT")), 6, "싸운 날")
	c.tick()
	t.ok(c.phase == 1 and c.met, "그날 다시 오면 말 없이 바로 싸움")
	t.ok(c.kc.cmb.hp < c.kc.cmb.max_hp * 0.9, "깎인 HP 그대로(%d/%d)" % [c.kc.cmb.hp, c.kc.cmb.max_hp])
	c._clear()
	st.vars.set_v("GAME_DAY", 7)
	c.tick()
	t.eq(c.phase, 0, "다음 날엔 다시 말부터")
	st.vars.set_v("PC_CAPS", 100)
	t.eq(_play(st, c, "KC_MEET", ["두 배로"]), [], "어제 그놈 — 통행세 두 배")
	t.eq(int(st.vars.get_v("PC_CAPS")), 40, "예순을 낸다")
	h.free()
	a = _host()
	h = a[0]
	st = a[1]
	c = a[2]
	c._fight("시험")
	c.tick(2.2)
	_hurt(c.kc, 0.6)
	c.tick(0.25)
	c.kc.set_meta("dash_done", true)
	c.tick(0.25)
	_hurt(c.kc, 0.1)
	c.tick(0.25)
	var k0 := int(st.vars.get_v("V_KARMA"))
	_play(st, c, "KC_GIVE", ["놓아준다"])
	t.eq(int(st.vars.get_v("V_KARMA")) - k0, 10, "놓아줌 카르마 +10")
	t.ok(c.kc.released and c.kc.say_text == "…빚졌다.", "엔진 '고맙다' 대신 결말 바크")
	h.free()
