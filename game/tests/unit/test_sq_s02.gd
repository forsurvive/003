## 단계 1-11b SQ-S02 「물 반 컵의 값」(SD-04a §4.2): 다음 날 06시 발동 · 수위계 하루 한 칸 · 순서 파괴(지도 먼저 → 40) ·
## 밸브 캠프(수금원 · 물값 E · 탈환 A) · 우회 관로 B(SQ-S03 자동) · 계엄군 D(결과만 · 연동) · 사이렌(지도 50캡 · 쓰러뜨리면 유해에) ·
## 내부자(글씨 대조 50 · 미행/남태하 60 · 고발 · 타이름 · 03시 함정) · 7일 묵인 · 봉천은 돌아와서 안다 · 물값 2배 · 밤 습격 RE · 저장 왕복.
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
	var c := SideS02.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 원고를 끝까지(또는 picks 차례로 고르며): s02 명령은 진행기로
func _play(st: StoryState, c: SideS02, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s02":
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


## 장면의 대사 한 줄이라도 needle을 담았나(그 장면을 끝까지 돌며)
func _says(st: StoryState, c: SideS02, id: String, needle: String, picks: Array = []) -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if str(cur.get("text", "")).contains(needle):
			return true
		if cur["type"] == "cmd":
			cur = dr.advance()
		elif cur["type"] == "choices":
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


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _post(h: InteriorHost, st: StoryState, c: SideS02) -> void:
	c.tick()                                                               # MQ-101이 끝난 날(ARM = 4)
	st.vars.set_v("GAME_DAY", 5)
	c._on_day(5)


func test_sq_s02_trigger_level(t) -> void:
	var r := _host("2277. 10. 26.  20:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	c.tick()
	t.eq(_v(st, "SQ_S02_ARM"), 4, "MQ-101이 끝난 날을 적는다")
	c._on_day(4)
	t.eq(_v(st, "SQ_S02_POSTED"), 0, "같은 날 06시엔 아직(다음 날 06시)")
	t.eq(c.level(), 5, "쪽지 전: 수위계 다섯 칸")
	t.ok(_says(st, c, "SQS02_SUAN", "두 통"), "쪽지 전 조수안: 평소 말(퀘스트 없음)")
	st.vars.set_v("GAME_DAY", 5)
	c._on_day(5)
	t.eq([_v(st, "SQ_S02_POSTED"), _v(st, "SQ_S02_DAY0")], [1, 5], "다음 날 06시: 급수 제한 쪽지 · 밸브가 잠긴 첫날")
	t.eq(st.quests.stage("SQ-S02"), 0, "쪽지만 붙었다 — 읽거나 들어야 단계 10")
	t.eq(_play(st, c, "X-BC_BOARD"), [], "반상회 게시판")
	t.eq(st.quests.stage("SQ-S02"), 10, "게시판 쪽지 → 단계 10")
	c.tick()
	t.eq(_v(st, "SQ_S02_LEVEL"), 4, "첫날 수위계 넷")
	t.eq(_play(st, c, "SQS02_SUAN", ["됐어"]), [], "조수안: 사정을 듣는다")
	t.eq(_v(st, "SQ_S02_HEARD"), 1, "들었다")
	t.eq(st.quests.stage("SQ-S02"), 10, "이미 10이면 그대로")
	var lv: Array = []
	for d in [6, 7, 8, 9, 10]:
		st.vars.set_v("GAME_DAY", d)
		c._on_day(d)
		c.tick()
		lv.append(_v(st, "SQ_S02_LEVEL"))
	t.eq(lv, [3, 2, 1, 0, 0], "하루 한 칸 — 닷새째(9일) 붉은 띠")
	t.ok(_says(st, c, "SQS02_GAUGE", "붉은 띠"), "수위계 원고: 바닥")
	t.ok(_says(st, c, "SQS02_SUAN", "두 배", ["됐어"]), "조수안: 물값 두 배")
	t.ok(_says(st, c, "SQS02_TANK", "텅 빈"), "저수조: 빈 소리")


func test_sq_s02_map_first(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-NS", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	h.player.loco.place(h.map.mark_pos("X-NS:talk"))
	c.tick()
	t.ok(c.scouts_on and is_instance_valid(c.siren), "낙성대 캠프: 사이렌과 척후")
	t.eq(c.scouts.size(), 5, "사이렌 + CR-420 ×2 + CR-423 ×2")
	t.ok(c.siren.cmb.team.begins_with("calm"), "먼저 쏘지 않으면 말을 건다")
	t.eq(c.siren.who, "N-R01-062", "이름표 사이렌")
	st.vars.set_v("PC_CAPS", 200)
	st.vars.set_v("PC_CH", 10)
	st.vars.set_v("PC_SKP_SPEECH", 80)
	t.eq(_play(st, c, "SQS02_SIREN", ["지도"]), [], "사이렌: '지도를 팔지?'")
	t.eq([_v(st, "SQ_S02_SIREN"), st.count_of("M-301"), _v(st, "PC_CAPS")], [3, 1, 150], "50캡에 척후 지도")
	c.tick()
	t.eq(st.quests.stage("SQ-S02"), 40, "순서 파괴: 지도를 먼저 쥐면 단계 40부터")
	t.eq(_v(st, "SQ_S02_MAP"), 1, "지도 사실")
	t.eq(_play(st, c, "EXAMINE_M301"), [], "살펴보기")
	t.ok(_says(st, c, "EXAMINE_M301", "당번표"), "아직 대조 전: '어디서 본 것 같다'")
	t.ok(_says(st, c, "SQS02_SIREN", "한 장뿐"), "다시 말 걸면: 지도는 한 장")


func test_sq_s02_siren_drop(t) -> void:
	var r := _host("2277. 10. 25.  14:00", "X-NS", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	h.player.loco.place(h.map.mark_pos("X-NS:talk"))
	c.tick()
	var s := c.siren
	s.cmb.last_by = "player"
	s.cmb.dead = true
	h._on_enemy_down(s)
	c._on_killed("CR-420", 4)
	t.eq(_v(st, "SQ_S02_SIREN"), 2, "사이렌이 쓰러졌다")
	var cell: Vector2i = h.map.tile_of(s.loco.logical)
	var items: Dictionary = h.box_contents(h.map.boxes[cell]).get("items", {}) if h.map.boxes.has(cell) else {}
	t.ok(items.has("M-301") or st.count_of("M-301") == 1, "지도는 그녀 품(유해)에")
	c._clear(c.scouts)
	c.scouts_on = false
	c.tick()
	t.ok(c.siren == null, "다시 와도 사이렌은 없다(P3)")


func test_sq_s02_camp_toll_valve(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "X-SS", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	_post(h, st, c)
	st.quests.set_stage("SQ-S02", 20)
	c.camp_on = false
	c._clear(c.camp)
	c.tick()
	t.ok(c.camp_on and is_instance_valid(c.toller), "밸브 캠프: 수금원")
	t.eq(c.camp.size(), 5, "약탈자 ×4 + 경비견")
	t.eq(c.toller.who, "N-YT-1", "이름표 패거리 수금원")
	t.ok(c.camp.all(func(e): return e.cmb.team == "calmss"), "잠근 뒤: 먼저 쏘지 않는다")
	t.eq(st.quests.stage("SQ-S02"), 30, "밸브 반경 30타일: 단계 30")
	t.eq(_play(st, c, "SQS02_VALVE"), [], "밸브 살피기")
	t.ok(_says(st, c, "SQS02_VALVE", "싸움"), "캠프가 있으면 손을 못 댄다")
	st.vars.set_v("PC_CAPS", 100)
	t.eq(_play(st, c, "SQS02_TOLL", ["낸다"]), [], "수금원에게 물값")
	t.eq([_v(st, "SQ_S02_OPEN"), _v(st, "SQ_S02_PAID"), _v(st, "PC_CAPS")], [2, 8, 70], "해법 E: 30캡 · 사흘")
	c.tick()
	t.eq(_v(st, "SQ_S02_LEVEL"), 5, "물값 기간: 수위계 다섯 칸")
	t.eq(st.quests.stage("SQ-S02"), 30, "E는 퀘스트를 닫지 않는다")
	var bc0 := _v(st, "AFF_JC_BC")
	h.enter("X-BC", "from_X-S07")
	t.eq(_v(st, "AFF_JC_BC"), bc0 + 2, "봉천에 돌아오면 +2(한 번)")
	st.vars.set_v("GAME_DAY", 8)
	c.tick()
	t.eq([_v(st, "SQ_S02_OPEN"), _v(st, "SQ_S02_DAY0"), _v(st, "SQ_S02_LEVEL")], [0, 8, 4], "사흘 뒤 다시 잠긴다 — 다시 하루 한 칸")
	# 탈환(A)
	h.enter("X-SS", "arrive")
	c.tick()
	for e in c.camp:
		e.cmb.dead = true
		e.cmb.last_by = "player"
	c._on_killed("CR-421", 0)
	t.eq(_v(st, "SQ_S02_CAMP"), 1, "캠프가 비었다")
	st.vars.set_v("PC_ST", 6)
	t.eq(_play(st, c, "SQS02_VALVE", ["힘 5"]), [], "사슬째 비틀어 돌린다")
	t.eq([_v(st, "SQ_S02_SOL"), _v(st, "SQ_S02_OPEN"), st.quests.stage("SQ-S02")], [1, 1, 70], "해법 A: 물 복구 · 단계 70")
	t.eq(_v(st, "JC_PROB_BC"), 1, "봉천 거처 '문제 해결'")
	c.tick()
	t.eq(c._valve_look, "open", "밸브 그림: 끊긴 사슬")
	var bc1 := _v(st, "AFF_JC_BC")
	h.enter("X-BC", "from_X-S07")
	t.eq(_v(st, "AFF_JC_BC"), bc1 + 8, "봉천이 알게 된다(+8)")
	t.eq(_play(st, c, "SQS02_NAMTAEHA2", ["지키면"]), [], "남태하에게 알림")
	t.eq(_v(st, "SQ_S02_GUARD"), 1, "감시조 둘이 밸브에 상주")
	st.vars.set_v("GAME_DAY", 8)
	t.eq(_play(st, c, "SQS02_SUAN"), [], "조수안 사례")
	t.eq([st.count_of("I-056"), _v(st, "SQ_S02_REWARD")], [5, 1], "관악산 약수 ×5 + 100캡")
	st.vars.set_v("GAME_DAY", 15)
	c.tick()
	t.eq([_v(st, "SQ_S02_IN"), st.quests.stage("SQ-S02")], [4, 100], "7일 묵인 → 자동 종료(밤 습격 +20%)")


func test_sq_s02_bypass(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	_post(h, st, c)
	st.quests.set_stage("SQ-S02", 20)
	t.ok(_says(st, c, "SQS02_JOINT", "관리인"), "관로 지도 없이는 모른다")
	st.vars.set_v("SQ_S02_PIPEMAP", 1)
	st.call_fn("give", ["M-010", 4])
	st.call_fn("give", ["M-025", 2])
	st.vars.set_v("PC_IN", 10)
	st.vars.set_v("PC_SKP_REPAIR", 40)
	var k0 := _v(st, "V_KARMA")
	h.player.loco.place(Vector2(30 * 32 + 16, 4 * 32 + 16))
	c.tick()
	t.eq(_play(st, c, "SQS02_JOINT", ["덧대고"]), [], "첫 이음 지점")
	t.eq([_v(st, "SQ_S02_J1"), _v(st, "SQ_S02_J2")], [1, 0], "J1")
	c.tick()
	t.ok(_says(st, c, "SQS02_JOINT", "물이 흐른다") or _v(st, "SQ_S02_AT") == 1, "이은 자리에서는 '이었다'")
	h.player.loco.place(Vector2(37 * 32 + 16, 4 * 32 + 16))
	c.tick()
	t.eq(_v(st, "SQ_S02_AT"), 0, "다른 지점은 아직")
	t.eq(_play(st, c, "SQS02_JOINT", ["덧대고"]), [], "둘째 이음 지점")
	t.eq([_v(st, "SQ_S02_B"), _v(st, "SQ_S02_SOL"), st.quests.stage("SQ-S02")], [1, 2, 70], "해법 B 우회 관로 · 단계 70")
	t.eq([st.count_of("M-010"), st.count_of("M-025")], [0, 0], "고철 넷 · 테이프 둘을 썼다")
	t.eq(_v(st, "V_KARMA") - k0, 50, "카르마 +50")
	t.eq(st.quests.stage("SQ-S03"), 10, "SQ-S03 자동 발동(계곡 배수로 곰팡이)")
	t.eq(_v(st, "SQ_S02_RAID_UNTIL"), _v(st, "GAME_DAY") + 3, "사흘 동안 봉천 밤 습격 +30%")
	var en := Encounters.new(st, 3)
	en.ctx["hour"] = 23
	var raid := {"cat": "raider"}
	t.ok(absf(en.cat_mult(raid, "R01", Vector2i(892, 1362), true) - 1.3 * 1.3) < 0.01, "봉천 둘레 밤 약탈자 ×1.3(밤) ×1.3(B)")
	t.ok(absf(en.cat_mult(raid, "R01", Vector2i(700, 1300), true) - 1.3) < 0.01, "봉천 밖은 밤 배수만")
	st.vars.set_v("SQ_S01_LEFT", 1)
	st.vars.set_v("SQ_S01_LEFT_DAY", _v(st, "GAME_DAY") - 7)
	t.ok(absf(en.cat_mult(raid, "R01", Vector2i(868, 1581), false) - 0.75) < 0.01, "외눈 무리가 옮기고 7일: 삼성산 능선 약탈자 매복 −25%(S01 후일담)")
	st.vars.set_v("SQ_S01_LEFT_DAY", _v(st, "GAME_DAY") - 6)
	t.ok(absf(en.cat_mult(raid, "R01", Vector2i(868, 1581), false) - 1.0) < 0.01, "7일 전엔 그대로")


func test_sq_s02_bj(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "X-SG", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	_post(h, st, c)
	st.quests.set_stage("SQ-S02", 30)
	st.vars.set_v("AFF_BJ", 0)
	var jc := _v(st, "AFF_JC")
	t.eq(_play(st, c, "SG_HWANG", ["상수 밸브", "됐습니다"], "ASK"), [], "황보서현에게 밸브 위치")
	var at := _v(st, "SQ_S02_BJ_AT")
	t.eq(posmod(at, 1440), 360, "다음 06시")
	t.ok(at > Clock.abs_min(h.date_text), "앞날")
	h.date_text = "2277. 10. 27.  06:10"
	c.tick()
	t.eq([_v(st, "SQ_S02_BJ"), _v(st, "SQ_S02_SOL"), _v(st, "SQ_S02_CAMP"), st.quests.stage("SQ-S02")], [1, 4, 1, 70], "주인공이 없다: 결과만 — 해법 D")
	t.eq(_v(st, "AFF_BJ"), 6, "BJ +6")
	t.eq(_v(st, "AFF_JC") - jc, -2, "연동 JC −2")
	t.eq(_v(st, "PD_R01_BJ"), 5, "판도 PD-R01-1 비상 +5")
	t.ok(_says(st, c, "SQS02_VALVE", "계엄사령부"), "밸브: 철판 표지")
	t.ok(_says(st, c, "X-BC_BOARD", "협조"), "봉천 게시판: 공보 공고")


func test_sq_s02_insider(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	_post(h, st, c)
	st.call_fn("give", ["M-301", 1])
	c.tick()
	t.eq(st.quests.stage("SQ-S02"), 40, "지도 → 40")
	t.eq(_play(st, c, "X-BC_BOARD"), [], "게시판")
	t.eq([_v(st, "SQ_S02_HAND"), st.quests.stage("SQ-S02")], [1, 50], "빗물 당번표 글씨 대조 → 50")
	t.ok(_says(st, c, "EXAMINE_M301", "남건희"), "지도 살펴보기: 이제 누구 글씨인지 안다")
	h.date_text = "2277. 10. 27.  22:30"
	c.tick()
	t.ok(c.night_on, "22시 이후: 윗문 쪽문에 남건희와 척후")
	var nh: Actor = h.ev.actors.get("N-R01-039")
	h.player.loco.place(nh.loco.logical + Vector2(0, 2 * 32))
	h.combat.crouch = false
	c.tick()
	t.ok(not c.night_on and _v(st, "SQ_S02_KNOW") == 0, "쪼그리지 않고 다가가면 들킨다 — 오늘 밤은 끝")
	c.tick()
	t.ok(not c.night_on, "같은 밤엔 다시 오지 않는다")
	h.player.loco.place(h.map.mark_pos("X-BC:land4"))
	h.date_text = "2277. 10. 28.  22:20"
	c.tick()
	t.ok(c.night_on, "다음 밤 다시")
	h.player.loco.place(h.ev.actors["N-R01-039"].loco.logical + Vector2(0, 6 * 32))
	c.tick()
	t.ok(h.box.active, "멀찍이 지켜보면 밤 원고")
	h.box._take({"type": "end"})
	c._cmd(["seen"], func() -> void: pass)
	t.eq([_v(st, "SQ_S02_KNOW"), st.quests.stage("SQ-S02")], [1, 60], "미행 → 60")
	t.ok(not c.night_on, "본 뒤엔 둘이 흩어진다")
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(st, c, "SQS02_GEONHUI", ["증거", "그만둬"]), [], "남건희: 지도를 내민다 → 타이름")
	t.eq(_v(st, "SQ_S02_IN"), 2, "b 타이름")
	t.eq(_v(st, "V_KARMA") - k0, 50, "카르마 +50")
	t.ok(_says(st, c, "SQS02_GEONHUI0", "대장간"), "이후 남건희: 대장간 일")
	t.eq(st.quests.stage("SQ-S02"), 60, "밸브가 아직 — 70 전엔 끝나지 않는다")
	c._cmd(["open"], func() -> void: pass)
	c.tick()
	t.eq(st.quests.stage("SQ-S02"), 100, "밸브(70) + 내부자 처리 → 100")
	t.eq(_v(st, "SQS02_RESULT"), 1, "결과 = 밸브 해법")


func test_sq_s02_trap(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	_post(h, st, c)
	st.vars.set_v("SQ_S02_MAP", 1)
	st.vars.set_v("SQ_S02_KNOW", 1)
	st.call_fn("give", ["M-301", 1])
	h.date_text = "2277. 10. 26.  23:50"
	t.eq(_play(st, c, "SQS02_GEONHUI", ["증거", "03시"]), [], "남건희: 거짓 교대 시간을 흘려라")
	t.eq(_v(st, "SQ_S02_IN"), 3, "c 함정")
	t.eq(_v(st, "SQ_S02_TRAP_AT"), Clock.abs_min("2277. 10. 27.  03:00"), "다음 03시(세 시간 넘게 남았다)")
	h.date_text = "2277. 10. 27.  03:05"
	c.tick()
	t.ok(c.trap_on, "03시 봉천: 습격조 여섯 · 감시조 셋")
	t.eq(c.trap_foes.size(), 6, "습격조 6")
	t.eq(h.combat.allies.size(), 3, "감시조 3")
	t.eq(_v(st, "SQ_S02_FIGHT"), 1, "맵 감시조는 전투 개체로")
	h.player.loco.place(h.map.mark_pos("X-BC:land1"))
	for i in 8:
		c._trap_tick()
	var bc0 := _v(st, "AFF_JC_BC")
	var pd0 := _v(st, "PD_BC")
	for e in c.trap_foes:
		e.cmb.dead = true
	c._trap_tick()
	t.ok(not c.trap_on and _v(st, "SQ_S02_TRAP_DONE") == 1, "함정이 끝났다")
	t.eq([_v(st, "SQ_S02_NH_DEAD"), st.dead.has("N-R01-039")], [0, false], "계단참①을 지켰다 — 남건희 생존")
	t.eq([_v(st, "AFF_JC_BC") - bc0, _v(st, "PD_BC") - pd0], [5, 5], "봉천 +5 · 판도 약탈 −5")
	t.eq([h.combat.allies.size(), _v(st, "SQ_S02_FIGHT")], [0, 0], "감시조는 제자리로")
	t.ok(_says(st, c, "SQS02_GEONHUI0", "다시는"), "이후 남건희")


func test_sq_s02_trap_away(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	_post(h, st, c)
	c._cmd(["insider", "3"], func() -> void: pass)
	h.enter("X-BS", "arrive")
	var at := _v(st, "SQ_S02_TRAP_AT")
	h.date_text = Clock.fmt(Clock.parse("2277. 10. 27.  04:00"))
	c.tick()
	t.eq(_v(st, "SQ_S02_TRAP_DONE"), 1, "주인공이 없었다: 감시조가 막았다(결과만)")
	var rr := RandomNumberGenerator.new()
	rr.seed = hash("S02TRAP:%d" % at)
	t.eq(_v(st, "SQ_S02_NH_DEAD") == 1, rr.randf() < 0.5, "남건희는 50%(씨앗 — 다시 불러와도 같다)")


func test_sq_s02_prices_save(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS02 = r[2]
	_post(h, st, c)
	st.vars.set_v("GAME_DAY", 9)
	c.tick()
	t.eq(_v(st, "SQ_S02_LEVEL"), 0, "붉은 띠")
	var m := Mq101.new()
	m.host = h
	m.st = st
	var k := m.trade_mult("V01")
	t.ok(absf(float(k[0][0]) - 1.1) < 0.001, "봉천 상인 +10%")
	t.ok(absf(float(k[2].get("I-055", 1.0)) - 2.0) < 0.001, "봉천 물값 2배")
	st.vars.set_v("SQ_S02_LEVEL", 5)
	st.vars.set_v("SQ_S02_B", 1)
	k = m.trade_mult("V01")
	t.ok(absf(float(k[2].get("I-055", 1.0)) - 0.8) < 0.001, "우회 관로 뒤: 정수 물 상시 −20%")
	m.free()
	st.vars.set_v("SQ_S02_SOL", 2)
	var js := JSON.stringify(GameSnapshot.story(st))
	var st2 := StoryState.new()
	st2.load_data()
	GameSnapshot.apply_story(st2, JSON.parse_string(js))
	t.eq([int(st2.vars.get_v("SQ_S02_SOL")), int(st2.vars.get_v("SQ_S02_B")), int(st2.vars.get_v("SQ_S02_POSTED"))], [2, 1, 1], "저장 왕복: 사실 변수")
