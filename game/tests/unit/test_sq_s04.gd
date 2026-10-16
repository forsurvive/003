## 단계 1-11c SQ-S04 「도성이 뒤척인다」(SD-04a §4.4): MQ-102 뒤 48시간 첫 21시 깨어남 · 종(가까움 — 실시간 경보 · 멂 — 게시판 쪽지) ·
## 파수 셋(정지 → 3초 → 경고 사격 → 제압 · K_CODE 멈칫과 관리자 인증 · 쪼그림) · 해법 A~F · 보호 기간 만료(노량진 · 다음 날 돌아옴) ·
## 잠든 뒤 마을이 꺼냄 · 편지(화술 +10 한 번) · 전지 인도처 · 순서 파괴(전지를 먼저 · 남솔이 죽음) · 주민센터 문과 파수 자리 · 저장 왕복.
extends RefCounted


func _host(date: String, map_id: String, mark: String) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = date
	var c := SideS04.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: SideS04, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s04":
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


func _says(st: StoryState, id: String, needle: String, picks: Array = []) -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if str(cur.get("text", "")).contains(needle):
			return true
		if cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])):
						i = j
				k += 1
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return false


func _opts(st: StoryState, id: String) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var guard := 0
	while cur["type"] != "end" and cur["type"] != "choices" and guard < 100:
		guard += 1
		cur = dr.advance()
	if cur["type"] != "choices":
		return []
	return (cur["opts"] as Array).filter(func(o): return not bool(o.get("hidden", false))).map(func(o): return str(o["text"]))


## 절대 분 a까지 시간을 보낸다(날이 바뀌면 GAME_DAY도 — 하루 판정은 시험이 따로 부른다)
func _to(h: InteriorHost, a: int) -> void:
	var d := a - Clock.abs_min(h.date_text)
	if d > 0:
		h.date_text = Clock.add_minutes(h.date_text, d, h.st)


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


## MQ-102를 연다(10월 25일 14시) → 깨어날 21시까지 시간을 보낸다
func _arm_wake(h: InteriorHost, st: StoryState, c: SideS04) -> void:
	st.quests.set_stage("MQ-102", 10)
	c.tick()
	var at := _v(st, "SQ_S04_WAKE_AT")
	_to(h, at)
	c.tick()


func _near_guard(h: InteriorHost, c: SideS04, d := 3) -> void:
	h.player.loco.place(h.map.mark_pos("sentry") + Vector2(0, d * 32))
	c.tick()


func _live(c: SideS04) -> Array:
	return c.bots.filter(func(b): return is_instance_valid(b) and not b.cmb.dead)


func test_sq_s04_trigger_live(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	st.quests.set_stage("MQ-102", 10)
	c.tick()
	var arm := _v(st, "SQ_S04_ARM")
	var at := _v(st, "SQ_S04_WAKE_AT")
	t.ok(at - arm >= 48 * 60 and posmod(at, 1440) == 21 * 60, "48시간 넘게 지난 첫 21시")
	t.eq(at - Clock.abs_min("2277. 10. 25.  14:00"), 55 * 60, "25일 14시 → 27일 21시(55시간 뒤)")
	_to(h, at - 60)
	c.tick()
	t.eq(_v(st, "SQ_S04_WAKE"), 0, "20시엔 아직")
	h.player.loco.place(h.map.mark_pos("X-BC:land2"))
	_to(h, at)
	c.tick()
	t.eq([_v(st, "SQ_S04_HELD"), _v(st, "SQ_S04_DEADLINE") - _v(st, "SQ_S04_WAKE")], [1, 72 * 60], "깨어남: 남솔이 철망 안 · 보호 기간 72시간")
	t.eq(_v(st, "SQ_S04_BELL"), 1, "봉천 안: 종 · 실시간 경보")
	t.eq(st.quests.stage("SQ-S04"), 10, "경보 장면 → 단계 10")
	t.ok(h.ev.actors.has("S04_CARRY"), "파수가 아이를 안고 걷는다(운반 그림)")
	t.eq(h.ev.actors["S04_CARRY"].sheet, "rb_cr305_carry_loco", "안은 그림")
	t.ok(not StoryExpr.test("(MQ101_NIGHT == 0 or MQ101_RESULT != 0) and SQ_S04_HELD == 0 and SQ_S04_AWAY == 0", st), "마당의 남솔은 사라진다(맵 조건)")
	c._carry_end()
	_near_guard(h, c, 12)
	t.eq(_live(c).size(), 3, "파수 셋(주민센터 · 아랫문 · 남부순환로)")
	t.ok(_live(c).all(func(e): return e.cmb.team == "calmsentry"), "먼저 쏘지 않는다(정지 명령부터)")
	t.ok(_live(c).all(func(e): return str(e.get_meta("enemy_id", "CR-305")) == "CR-305"), "파수-3 CR-305")
	_near_guard(h, c, 6)
	t.eq(st.quests.stage("SQ-S04"), 20, "주민센터 반경 10타일 → 20")
	t.ok(h.box.active or st.quests.stage("SQ-S04") >= 20, "방송이 들린다")
	if h.box.active:
		h.box._take({"type": "end"})
	t.eq(_play(st, c, "SQS04_BROADCAST"), [], "파수 방송")
	t.eq(st.quests.stage("SQ-S04"), 30, "방송 청취 → 30")
	t.ok(_says(st, "SQS04_BROADCAST", "보호 기간 72시간"), "핵심 대사")


func test_sq_s04_far_board(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-RD", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	_arm_wake(h, st, c)
	t.eq(_v(st, "SQ_S04_HELD"), 1, "멀리 있어도 깨어남은 일어난다(사실 한 곳)")
	t.eq([_v(st, "SQ_S04_BELL"), st.quests.stage("SQ-S04")], [0, 0], "레이더(봉천 반경 3청크 밖): 종소리가 안 닿는다")
	_to(h, _v(st, "SQ_S04_WAKE") + 100)
	c.tick()
	t.eq(_v(st, "SQ_S04_BELL"), 3, "때가 지났다 — 다음 봉천 방문 때 쪽지로")
	t.ok(c.radar_on, "레이더 마당 근처")
	t.eq(c.turrets.filter(func(x): return is_instance_valid(x)).size(), 2, "전지가 깨어 있다: 감시포 둘")
	t.ok(_says(st, "SQS04_BATT", "깨어난 심장"), "전지 받침: 깨어 있다")
	t.ok(_says(st, "X-BC_BOARD", "망루 남태하"), "쪽지 글")
	t.eq(_play(st, c, "X-BC_BOARD"), [], "반상회 게시판")
	t.eq(st.quests.stage("SQ-S04"), 10, "남태하의 쪽지 → 단계 10")
	c.tick()
	t.eq(st.quests.stage("SQ-S04"), 40, "레이더 반경 80타일: 핍-보이 '반송파 강함' → 40")


func test_sq_s04_halt_rules(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	h.player.loco.place(h.map.mark_pos("sentry") + Vector2(0, 30 * 32))
	_arm_wake(h, st, c)
	st.quests.set_stage("SQ-S04", 30)                                     # 방송은 들었다(이 시험은 정지 규칙만)
	_near_guard(h, c, 10)
	var g: Enemy = c.bots[0]
	h.combat.crouch = true
	h.player.loco.place(g.loco.logical + Vector2(0, 3 * 32))
	c._halt_step(0.1)
	t.eq(c.halt[0], -1.0, "쪼그려 3칸: 못 본다")
	h.combat.crouch = false
	c._halt_step(0.1)
	t.eq(c.halt[0], 0.0, "서서 3칸: 정지 명령")
	c._halt_step(2.9)
	t.ok(not c.warned[0], "3초 전엔 경고 사격 없음")
	c._halt_step(0.2)
	t.ok(c.warned[0], "3초 → 경고 사격")
	c._halt_step(3.1)
	t.eq(_v(st, "SQ_S04_HOT"), 1, "또 3초 → 제압")
	t.ok(_live(c).all(func(e): return e.cmb.team == "enemysentry"), "셋이 함께(관제망 한 판정)")
	# 물러나면 풀린다 · 관리자 후보는 1.5초 더
	h.player.loco.place(h.map.mark_pos("sentry") + Vector2(0, 90 * 32))
	c.tick()
	t.ok(not c.posts_on and _v(st, "SQ_S04_HOT") == 0, "멀어지면 치우고 다시 정지 명령부터")
	_near_guard(h, c, 10)
	g = c.bots[1]
	h.player.loco.place(g.loco.logical + Vector2(3 * 32, 0))
	c._halt_step(0.1)
	h.player.loco.place(g.loco.logical + Vector2(9 * 32, 0))
	c._halt_step(0.1)
	t.eq(c.halt[1], -1.0, "7칸 넘게 물러났다: 명령이 풀린다")
	st.vars.set_v("V_REGCARD", 4)
	h.player.loco.place(g.loco.logical + Vector2(3 * 32, 0))
	c._halt_step(0.1)
	c._halt_step(3.2)
	t.ok(not c.warned[1], "K_CODE: 3초가 지나도 멈칫(1.5초 더)")
	c._halt_step(1.4)
	t.ok(c.warned[1], "4.5초 → 경고 사격")


func test_sq_s04_auth_letter(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	h.player.loco.place(h.map.mark_pos("sentry") + Vector2(0, 30 * 32))
	_arm_wake(h, st, c)
	_near_guard(h, c, 10)
	st.vars.set_v("V_REGCARD", 4)
	st.vars.set_v("PC_SKP_SCIENCE", 60)
	t.eq(_opts(st, "SQS04_HALT").filter(func(o): return o.contains("보호 조치를 해제")).size(), 1, "등록 카드 4: [관리자 인증] 선택지")
	st.vars.set_v("V_REGCARD", 3)
	t.eq(_opts(st, "SQS04_HALT").filter(func(o): return o.contains("보호 조치를 해제")).size(), 0, "카드 4 전엔 숨는다")
	st.vars.set_v("V_REGCARD", 4)
	st.vars.set_v("PC_SKP_SCIENCE", 60)
	var w0 := _v(st, "V_WANTED")
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(st, c, "SQS04_HALT", ["보호 조치를 해제"]), [], "관리자 인증 [과학 50]")
	t.eq([_v(st, "SQ_S04_OUT"), _v(st, "SQ_S04_HELD")], [1, 0], "해법 A: 남솔이 나온다")
	t.eq(_v(st, "V_WANTED") - w0, 9, "파수 1기당 수배도 +3(셋 · 하루 +9 상한)")
	t.eq(_v(st, "V_KARMA") - k0, 50, "카르마 +50")
	t.ok(c.pause_t > 59.0, "파수 60초 정지(원인은 남는다)")
	c.tick()
	t.eq(st.quests.stage("SQ-S04"), 50, "단계 50")
	t.ok(_live(c).size() == 3, "파수는 그대로(다시 순찰)")
	c._process(61.0)
	t.eq(c.pause_t, 0.0, "60초 뒤 순찰 재개")
	t.ok(_says(st, "SQS04_LETTER", "로봇 대장"), "편지: '로봇 대장'")
	var sp := st.skill("SPEECH")
	t.eq(_play(st, c, "SQS04_LETTER"), [], "남솔의 편지")
	t.eq([st.count_of("M-303"), _v(st, "SQ_S04_LETTER")], [1, 1], "아이의 감사 편지 M-303")
	t.eq(st.skill("SPEECH") - sp, 10, "화술 +10 영구")
	c._cmd(["letter"], func() -> void: pass)
	t.eq(st.skill("SPEECH") - sp, 10, "효과는 첫 1회")


func test_sq_s04_destroy(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	h.player.loco.place(h.map.mark_pos("sentry") + Vector2(0, 30 * 32))
	_arm_wake(h, st, c)
	_near_guard(h, c, 10)
	st.vars.set_v("SQ_S04_HELP", 1)
	c._hostile_all("시험")
	var k0 := _v(st, "V_KARMA")
	var bc0 := _v(st, "AFF_JC_BC")
	for e in _live(c):
		e.cmb.dead = true
		e.cmb.last_by = "player"
	c._on_killed("CR-305", 0)
	t.eq(_v(st, "SQ_S04_KILLED"), 7, "셋 다 부서졌다")
	t.eq([_v(st, "SQ_S04_OUT"), _v(st, "SQ_S04_HELD")], [2, 0], "해법 B: 남태하가 철망을 연다")
	t.eq(_v(st, "V_KARMA") - k0, 50, "카르마 +50")
	t.eq(_v(st, "AFF_JC_BC") - bc0, 6, "봉천 +6(목격)")
	c.tick()
	t.ok(c.looks.has("guard") and c.looks.has("gate") and c.looks.has("road"), "잔해 셋이 자리에 남는다")
	t.ok(_says(st, "MQ-102_SENTRY_AFTER", "부서진 파수"), "잔해 살피기")
	c.posts_on = false
	c.tick()
	t.eq(_live(c).size(), 0, "다시 와도 파수는 없다(P3)")
	var gs0 := _v(st, "AFF_GS")
	st.deeds.tick(st, Clock.abs_min(h.date_text) + 25 * 60)
	t.eq(_v(st, "AFF_GS") - gs0, -6, "한가람이 잔해를 보고 안다(GS −6)")


func test_sq_s04_cage_chase(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	_arm_wake(h, st, c)
	h.enter("K-33", "from_W")
	c.tick()
	t.eq(st.quests.stage("SQ-S04"), 20, "민원실에 들어섰다 → 20(순서 파괴 — 종도 쪽지도 못 봤어도)")
	t.ok(_says(st, "SQS04_NUM", "413"), "번호표 발급기 413")
	t.ok(_says(st, "SQS04_SOL", "등록이 뭐야"), "철망 안 남솔")
	st.vars.set_v("PC_ST", 7)
	t.eq(_play(st, c, "SQS04_CAGE", ["힘 6"]), [], "철망을 비튼다")
	t.eq([_v(st, "SQ_S04_OUT"), _v(st, "SQ_S04_CHASE")], [3, 1], "해법 C: 나왔다 — 바깥에 나가면 이탈 경보")
	h.enter("X-BC", "from_X-S07")
	t.ok(c.chase_t > 29.0 and _v(st, "SQ_S04_HOT") == 1, "'보호 대상 이탈' — 30초 추격")
	c._process(30.5)
	t.ok(_v(st, "SQ_S04_LOITER") > Clock.abs_min(h.date_text), "추격 끝: 72시간 아랫문 서성임")
	t.eq(c._post_cell(0), c._post_cell(1) + Vector2i(-3, 0), "셋 다 아랫문 앞")
	var m := Mq101.new()
	var closed := [false]
	h.merchants["VTEST"] = {"settle": "BC"}
	m.host = h
	m.st = st
	m._trade_cmd(["VTEST"], func() -> void: closed[0] = true)
	t.ok(closed[0], "봉천 상인 휴업(거래 창 없이 끝)")
	m.free()
	t.eq(st.quests.stage("SQ-S04"), 50, "50 — 원인(②)이 남았다")


func test_sq_s04_gs_ritual(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-GS", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	_arm_wake(h, st, c)
	st.quests.set_stage("SQ-S04", 10)
	st.vars.set_v("AFF_GS", 25)
	t.eq(_play(st, c, "GS_HAN", ["아이를 가뒀습니다"]), [], "한가람에게 알린다")
	t.eq(_v(st, "SQ_S04_D"), 1, "정비 당번이 온다")
	t.eq(_v(st, "SQ_S04_D_AT") - Clock.abs_min(h.date_text), 360, "여섯 시간 뒤")
	_to(h, _v(st, "SQ_S04_D_AT") + 130)
	var k0 := _v(st, "V_KARMA")
	c.tick()
	t.eq([_v(st, "SQ_S04_D"), _v(st, "SQ_S04_OUT"), _v(st, "SQ_S04_SLEEP")], [2, 4, 3], "그 자리에 없었다: 결과만 — 남솔이 나오고 파수가 정비 모드로")
	t.eq(_v(st, "SQ_S04_TEST"), 1, "GS 우호: 아무도 은솔을 막지 않았다 — 시험 가동")
	t.eq(_v(st, "V_KARMA") - k0, 25, "카르마 +25")
	t.eq(_v(st, "PD_R01_GS"), 5, "판도 PD-R01-2 각성회 +5")
	t.eq(st.quests.stage("SQ-S04"), 100, "①·② 동시 → 100")
	t.ok(_v(st, "PC_XP") >= 350, "350 XP")
	t.ok(_says(st, "MQ-102_SENTRY_AFTER", "흰 천"), "후일담: 흰 천과 대기등")


func test_sq_s04_ritual_live(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	h.player.loco.place(h.map.mark_pos("sentry") + Vector2(0, 30 * 32))
	_arm_wake(h, st, c)
	st.vars.set_v("AFF_GS", 25)
	st.vars.set_v("SQ_S04_D", 1)
	st.vars.set_v("SQ_S04_D_AT", Clock.abs_min(h.date_text))
	st.quests.set_stage("SQ-S04", 30)
	_near_guard(h, c, 6)
	t.ok(h.box.active, "정비 의식(그 자리에 있다)")
	t.ok(h.ev.actors.has("N-R01-055"), "한가람")
	h.box._take({"type": "end"})
	st.vars.set_v("PC_SKP_SPEECH", 90)
	st.vars.set_v("PC_CH", 10)
	var t0 := Clock.abs_min(h.date_text)
	t.eq(_play(st, c, "SQS04_RITUAL", ["레버는 정비가"]), [], "은솔을 막는다 [화술 보통]")
	t.eq([_v(st, "SQ_S04_TEST"), _v(st, "SQ_S04_OUT"), _v(st, "SQ_S04_SLEEP")], [0, 4, 3], "시험 가동 없음 · 정비 모드")
	t.eq(Clock.abs_min(h.date_text) - t0, 120, "두 시간")
	t.ok(not h.ev.actors.has("N-R01-055"), "당번은 돌아간다")


func test_sq_s04_battery(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-RD", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	_arm_wake(h, st, c)
	c.tick()
	t.eq(c.turrets.filter(func(x): return is_instance_valid(x)).size(), 2, "감시포 둘")
	st.vars.set_v("PC_ST", 7)
	t.eq(_play(st, c, "SQS04_FENCE", ["힘 6"]), [], "약한 철조망")
	t.eq(_v(st, "SQ_S04_FENCE"), 1, "틈이 생겼다")
	c.tick()
	h.enter("K-36", "from_X")
	t.eq(_play(st, c, "SQS04_BATT", ["뽑는다"]), [], "전지를 뽑는다")
	t.eq([_v(st, "SQ_S04_BATT"), _v(st, "SQ_S04_SLEEP"), st.count_of("M-162")], [1, 1, 1], "해법 E: 핵분열 전지 M-162 · 파수 재수면")
	t.eq(_v(st, "SQ_S04_PD_LOCK"), 1, "거점 '관악산 송신소' 공백 고정")
	t.ok(_says(st, "SQS04_BRAIN", "꺼진 진공관"), "두뇌-4가 꺼졌다")
	h.enter("X-RD", "arrive")
	c.tick()
	t.eq(c.turrets.filter(func(x): return is_instance_valid(x)).size(), 0, "감시포가 고개를 떨군다")
	var gs0 := _v(st, "AFF_GS")
	st.deeds.tick(st, Clock.abs_min(h.date_text) + 25 * 60)
	t.eq(_v(st, "AFF_GS") - gs0, -10, "각성회 순례조가 안다(성지 훼손 −10)")
	var bc0 := _v(st, "AFF_JC_BC")
	t.eq(_play(st, c, "BC_NAM", ["전지를 보여", "마을에 쓰세요", "돌아선다"]), [], "대장간 남무진에게")
	t.eq([_v(st, "SQH_BATT"), st.count_of("M-162"), _v(st, "AFF_JC_BC") - bc0], [81, 0, 3], "인도처 봉천 · BC +3")
	t.eq(_opts(st, "BC_NAM").filter(func(o): return o.contains("전지")).size(), 0, "한 번만(전지는 하나 — P3)")


func test_sq_s04_standby_and_order(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-RD", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	# 순서 파괴: 깨어나기 전에 전지를 뽑았다 → 이번엔 뒤척이지 않는다
	st.quests.set_stage("MQ-102", 10)
	c.tick()
	c._cmd(["batt"], func() -> void: pass)
	_to(h, _v(st, "SQ_S04_WAKE_AT"))
	c.tick()
	t.eq([_v(st, "SQ_S04_WAKE"), _v(st, "SQ_S04_HELD"), st.quests.stage("SQ-S04")], [0, 0, 0], "전지를 먼저 뽑았다: 깨어나지 않는다")
	# 남솔이 죽었다(N2)
	var r2 := _host("2277. 10. 25.  14:00", "X-RD", "arrive")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: SideS04 = r2[2]
	st2.dead["N-R01-034"] = 2277
	_arm_wake(h2, st2, c2)
	t.eq(_v(st2, "SQ_S04_HELD"), 0, "데려갈 아이가 없다 — 퀘스트가 서지 않는다")
	# F 당직실 단말
	var r3 := _host("2277. 10. 25.  14:00", "X-RD", "arrive")
	var h3: InteriorHost = r3[0]
	var st3: StoryState = r3[1]
	var c3: SideS04 = r3[2]
	_arm_wake(h3, st3, c3)
	st3.vars.set_v("SQ_S04_F", 1)
	c3.tick()
	t.eq(_v(st3, "SQ_S04_SLEEP"), 2, "해법 F: 전지 '대기' — 파수 재수면(전지는 남는다)")
	t.ok(not c3.radar_awake(), "감시포 · 경광도 잠든다")
	t.eq(_v(st3, "SQ_S04_HELD"), 1, "남솔은 아직 철망 안")
	_to(h3, Clock.abs_min(h3.date_text) + 361)
	c3.tick()
	t.eq([_v(st3, "SQ_S04_OUT"), _v(st3, "SQ_S04_HELD")], [6, 0], "잠든 뒤 여섯 시간: 마을이 철망을 연다")
	t.eq(st3.quests.stage("SQ-S04"), 100, "50 + 60 → 100")


func test_sq_s04_expire(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-RD", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	_arm_wake(h, st, c)
	st.quests.set_stage("SQ-S04", 10)
	_to(h, _v(st, "SQ_S04_DEADLINE"))
	c.tick()
	t.eq([_v(st, "SQ_S04_OUT"), _v(st, "SQ_S04_HELD")], [5, 0], "보호 기간 만료: 노량진으로")
	t.ok(_v(st, "SQ_S04_AWAY") > 0, "남솔은 노량진에(봉천에도 철망 안에도 없다 — P3)")
	t.ok(not _says(st, "SQS04_LETTER", "노량진에 갔었어") or _v(st, "SQ_S04_AWAY") > 0, "돌아오기 전엔 편지 장면이 서지 않는다")
	var bc0 := _v(st, "AFF_JC_BC")
	var gs0 := _v(st, "AFF_GS")
	var d := _v(st, "SQ_S04_AWAY")
	st.vars.set_v("GAME_DAY", d)
	c._on_day(d)
	t.eq(_v(st, "SQ_S04_AWAY"), 0, "다음 날 류정이 돌려보낸다")
	t.eq(_v(st, "AFF_JC_BC") - bc0, -5, "다른 결과: BC −5")
	st.deeds.tick(st, Clock.abs_min(h.date_text) + 25 * 60)
	t.eq(_v(st, "AFF_GS") - gs0, 3, "GS +3")
	t.ok(_says(st, "SQS04_LETTER", "노량진에 갔었어"), "편지는 해법 무관하게")


## 월드 굽기가 정한 주민센터 정문(K-33)과 파수 자리가 어긋나지 않는다(건물이 다시 생성돼도 시험이 잡는다)
func test_sq_s04_door_spot(t) -> void:
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/place_geo.json"))
	var door := Vector2i(-1, -1)
	for d in g["_doors"]:
		if str(d.get("to", "")) == "K-33":
			door = Vector2i(int(d["at"][0]), int(d["at"][1]))
	var spot := Vector2i(-99, -99)
	for s in g.get("_spots", []):
		if str(s.get("lid", "")) == "L-R01-32":
			var m: Array = s["data"]["marks"]["sentry"]
			spot = Vector2i(int(s["at"][0]) + int(m[0]), int(s["at"][1]) + int(m[1]))
	t.ok(door.x >= 0, "주민센터 정문이 있다")
	t.ok(absi(spot.x - door.x) <= 3 and spot.y - door.y >= 1 and spot.y - door.y <= 3, "파수 자리는 정문 앞 3칸 안(%s · %s)" % [door, spot])


func test_sq_s04_save(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-RD", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS04 = r[2]
	_arm_wake(h, st, c)
	st.vars.set_v("SQ_S04_KILLED", 5)
	var js := JSON.stringify(GameSnapshot.story(st))
	var st2 := StoryState.new()
	st2.load_data()
	GameSnapshot.apply_story(st2, JSON.parse_string(js))
	t.eq([_v(st2, "SQ_S04_HELD"), _v(st2, "SQ_S04_KILLED"), _v(st2, "SQH_BATT")], [1, 5, -1], "저장 왕복: 사실 변수 · 인도처 기본 −1")
