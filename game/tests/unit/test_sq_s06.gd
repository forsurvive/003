## 단계 1-11f SQ-S06 「근무자: 공란」(SD-04a §4.6): 발동(전단 · 탄약고 · 대화) · 수색 시계(24시간 → 30 · 48시간마다 권역) · 호위(전투복이면 빠른 이동 막힘 ·
## 굶주림 ×0.8 · ×1.25) · 길 안내(40) · 해법 A 짐칸(다리목 · 씨앗 고정) · B 등록증 · C 배 · D 자수(쪽지 · 권은서) · E 인도(데려감 · 위치만) · F 처치(군번줄) ·
## 혼자 길(7일 · 준비만큼 확률) · 수색조(상황 넷 · 같은 분대장) · 미끼 · 숨었다 돌아옴.
extends RefCounted


func _host(date: String, map_id: String, mark: String) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	st.vars.set_v("P_REGNO", "S07-2259-0412")
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = date
	var c := SideS06.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 원고를 끝까지(또는 picks 차례로 고르며): s06 명령은 진행기로
func _play(st: StoryState, c: SideS06, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s06" and str(cur["args"][0]) not in ["go", "boat"]:
				c._cmd(cur["args"], func() -> void: pass)
			elif str(cur["name"]) == "s06" and str(cur["args"][0]) == "boat":
				c._sv("SQ_S06_BOAT", 1)
				c._sv("SQ_S06_ROUTE", 2)
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


func _says(st: StoryState, c: SideS06, id: String, needle: String, picks: Array = [], label := "START") -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if str(cur.get("text", "")).contains(needle):
			return true
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s06" and str(cur["args"][0]) not in ["go", "boat"]:
				c._cmd(cur["args"], func() -> void: pass)
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


func _opts(st: StoryState, id: String, label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var guard := 0
	while cur["type"] != "end" and cur["type"] != "choices" and guard < 100:
		guard += 1
		cur = dr.advance()
	var out := []
	if cur["type"] == "choices":
		for o in cur["opts"]:
			if bool(o["enabled"]):
				out.append(str(o["text"]))
	return out


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


## 탄약고에 내려가 진해원을 만나고 따라오게 한다(시흥 고개 초소 위로 올라옴)
func _meet_and_join(h: InteriorHost, st: StoryState, c: SideS06) -> void:
	h.enter("Q-30", "from_X")
	_play(st, c, "SQS06_JIN", ["어디로", "노들섬까지"])
	h.enter("X-SH", "from_Q-30")
	c.tick()


func _at(h: InteriorHost, tile: Vector2i) -> void:
	var p := Vector2(tile.x * 32 + 16, tile.y * 32 + 16)
	(h.map as WorldMap).load_now(p)
	h.player.loco.place(p)
	h.player.position = p
	var m := h.combat.mates.get_mate("N-R01-064")
	if not m.is_empty():
		(m["actor"] as Actor).loco.place(p + Vector2(-32, 0))


func test_sq_s06_trigger_and_clock(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SG", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	t.ok(_says(st, c, "SG_BOARD", "생포 150캡"), "발동 ①: 게시판 탈영병 전단")
	t.eq(_play(st, c, "SG_BOARD"), [], "게시판 끝까지")
	t.eq(st.quests.stage("SQ-S06"), 10, "전단 → 10")
	t.eq(_v(st, "SQ_S06_DISC"), 0, "전단만으로는 수색 시계가 돌지 않는다(재미 검수 7)")
	h.enter("Q-30", "from_X")
	t.ok(_v(st, "SQ_S06_DISC") > 0, "탄약고 첫 진입 = 첫 접촉")
	t.ok(_says(st, c, "SQS06_JIN", "사람을 고르는 걸 봤어요"), "원문 핵심 대사")
	t.eq(_play(st, c, "SQS06_JIN", ["어디로", "됐어"]), [], "대화 끝까지(길 셋을 먼저 말한다)")
	t.eq(st.quests.stage("SQ-S06"), 20, "대화 → 20")
	t.eq(_v(st, "SQ_S06_ROUTE"), 1, "진해원이 들은 길 셋")
	t.eq(c.phase(), 0, "수색 전")
	h.date_text = "2277. 10. 27.  11:00"
	c.tick()
	t.eq(st.quests.stage("SQ-S06"), 30, "24시간 → 수색조가 시흥 고개에(30)")
	t.eq(c.phase(), 1, "권역 1 시흥")
	h.date_text = "2277. 10. 29.  12:00"
	t.eq(c.phase(), 2, "48시간 뒤 사당 고개")
	h.date_text = "2277. 11. 2.  12:00"
	t.eq(c.phase(), 4, "노량진까지")


func test_sq_s06_escort_rules(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	_meet_and_join(h, st, c)
	var m := h.combat.mates.get_mate("N-R01-064")
	t.ok(not m.is_empty(), "맵을 넘어도 동행")
	t.eq(str(m.get("mode", "")), "escort", "호위 모드 유지")
	t.eq(_v(st, "SQ_S06_JIN"), 1, "진해원의 자리 = 호위")
	c.tick()
	t.ok(c._travel_block("L-R01-09").contains("이 옷으로"), "전투복이면 빠른 이동이 막힌다")
	t.eq((m["actor"] as Actor).loco.speed_mul, 0.8, "굶주림 ×0.8")
	t.eq(h.travel_mul, 1.25, "굶주린 동행: 이동 시간 ×1.25")
	st.items["I-031"] = 1
	st.items["A-005"] = 1
	c.tick()
	t.ok(_says(st, c, "SQS06_JIN", "우리 거네요", ["먹을 거"]) or _v(st, "SQ_S06_FED") == 1, "전투식량 반응")
	_play(st, c, "SQS06_JIN", ["이 옷으로"])
	t.eq([_v(st, "SQ_S06_FED"), _v(st, "SQ_S06_CLOTH")], [1, 1], "밥 · 평상복")
	t.eq(st.count_of("A-031"), 1, "전투복이 주인공 손에(미끼 재료)")
	t.eq(int(st.items.get("A-031@2", 0)), 1, "이 년 입은 전투복 — 낡음(재미 검수 ⑤)")
	c.tick()
	t.eq((m["actor"] as Actor).sheet, SideS06.CIV_SHEET, "평상복 모습")
	t.eq((m["actor"] as Actor).loco.speed_mul, 1.0, "배부르면 ×1.0")
	t.eq(c._travel_block("L-R01-09"), "", "평상복이면 막지 않는다")
	h.enter("X-SH", "arrive")
	t.eq(h.ev.cast_sheets.get("N-R01-064", ""), SideS06.CIV_SHEET, "맵을 넘어도 평상복")


func test_sq_s06_checkpoint_uniform_and_papers(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	_meet_and_join(h, st, c)
	t.ok(_says(st, c, "SQS06_CHECK", "탈영병이다"), "전투복 = 다리목 즉시 정지")
	_at(h, Vector2i(965, 1159))
	t.eq(_play(st, c, "SQS06_CHECK", ["달아난다"]), [], "달아난다")
	t.eq(_v(st, "SQ_S06_HOT"), 1, "들켰다(한 번)")
	t.eq(_v(st, "SQ_S06_BFIGHT"), 1, "다리목 소동")
	t.ok(c.chasers.size() >= 1, "쫓는 계엄병")
	st.items["A-005"] = 1
	st.items["M-062"] = 1
	_play(st, c, "SQS06_JIN", ["이 옷으로"])
	_play(st, c, "SQS06_JIN", ["등록증"])
	t.eq(_v(st, "SQ_S06_PAPERS"), 1, "등록증을 건넴")
	t.ok(_says(st, c, "SQS06_CHECK", "통과"), "평상복 + 등록증 = 자동 통과")
	_play(st, c, "SQS06_CHECK")
	t.eq(_v(st, "SQ_S06_CHECK"), 3, "등록증으로 통과")
	t.eq(_play(st, c, "SQS06_GATE", ["견습"]), [], "남문(반검문)")
	t.eq([_v(st, "SQ_S06_JIN"), _v(st, "SQ_S06_SOL")], [3, 2], "노들섬 · 해법 B")
	t.eq(st.quests.stage("SQ-S06"), 100, "50 → 100")
	t.eq(_v(st, "SQE_DESERTER"), 1, "MQ-502 증인")
	t.eq(int(st.items.get("M-185", 0)), 1, "군번줄")
	t.ok(h.combat.mates.get_mate("N-R01-064").is_empty(), "동행이 끝났다")
	t.ok(c.chasers.is_empty(), "남문에 닿으면 쫓던 계엄병이 멈춘다")
	t.ok(_says(st, c, "SQS06_ROSTER", "근무 끝"), "근무표 마지막 칸 아래 연필")
	t.ok(_says(st, c, "SG_BOARD", "은닉자 신고 포상 300캡"), "전단이 바뀐다(기울기 체감)")


func test_sq_s06_cargo(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	_meet_and_join(h, st, c)
	st.vars.set_v("CARAVAN_V54", 2)
	st.vars.set_v("PC_CAPS", 200)
	c.tick()
	t.ok(_opts(st, "TR_YEON", "ASK").any(func(o): return o.contains("태워 줄")), "수송대가 사당에 있을 때만 짐칸 선택지")
	t.eq(_play(st, c, "TR_YEON", ["태워 줄", "짐삯"], "ASK"), [], "50캡 짐삯")
	t.eq(_v(st, "PC_CAPS"), 150, "50캡 한 번만")
	t.eq(_v(st, "SQ_S06_JIN"), 2, "짐칸")
	t.eq(st.quests.stage("SQ-S06"), 40, "길 안내 → 40")
	t.ok(_v(st, "SQ_S06_GATE_AT") > Clock.abs_min(h.date_text), "다리목에 닿는 시각")
	h.date_text = Clock.add_minutes(h.date_text, _v(st, "SQ_S06_GATE_AT") - Clock.abs_min(h.date_text) + 10)
	st.vars.set_v("SQ_S06_GATE_AT", Clock.abs_min(h.date_text) - 1)
	c._cargo_tick()
	t.ok(_v(st, "SQ_S06_SOL") in [1, 8], "주인공이 없으면 연보경 혼자(씨앗 고정 70%)")
	if _v(st, "SQ_S06_SOL") == 1:
		t.eq(st.count_of("M-185"), 0, "지켜보지 않았으면 군번줄은 아직(재미 검수 ③)")
		t.ok(_says(st, c, "SQS06_JIN", "이거 가지세요"), "남문에서 진해원이 직접 건넨다")
		_play(st, c, "SQS06_JIN")
		t.eq(st.count_of("M-185"), 1, "군번줄")
		_play(st, c, "SQS06_JIN")
		t.eq(st.count_of("M-185"), 1, "한 번만")
	else:
		t.eq(_v(st, "SQ_S06_HOW"), 2, "짐칸에서 잡힘 — 소문 판이 다르다(재미 검수 ④)")
	var first := _v(st, "SQ_S06_SOL")
	var r2 := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var st2: StoryState = r2[1]
	var c2: SideS06 = r2[2]
	st2.vars.set_v("SQ_S06_JIN", 2)
	st2.vars.set_v("SQ_S06_GATE_AT", 1)
	c2._cargo_tick()
	t.eq(_v(st2, "SQ_S06_SOL"), first, "같은 주인공 = 같은 결과(저장 · 불러오기로 바뀌지 않는다)")


func test_sq_s06_cargo_present(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	st.vars.set_v("SQ_S06_JIN", 2)
	st.vars.set_v("SQ_S06_MET", 1)
	st.vars.set_v("PC_CAPS", 300)
	t.eq(_play(st, c, "SQS06_CARGO", ["수고비"]), [], "다리목 짐 검사: 100캡")
	t.eq(_v(st, "PC_CAPS"), 200, "100캡 한 번만")
	t.eq([_v(st, "SQ_S06_JIN"), _v(st, "SQ_S06_SOL")], [3, 1], "해법 A")
	t.eq(_v(st, "SQE_DESERTER"), 1, "증인")


func test_sq_s06_boat(t) -> void:
	var r := _host("2277. 10. 26.  22:00", "X-SH", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	_meet_and_join(h, st, c)
	st.vars.set_v("PC_CAPS", 100)
	st.vars.set_v("PN_SIM", 1)
	st.vars.set_v("GAME_HOUR", 22)
	c.tick()
	t.eq(_play(st, c, "L25_SIM", ["배를 띄운다", "낸다"]), [], "심도겸 밤 배 30캡")
	t.eq(_v(st, "PC_CAPS"), 70, "30캡")
	t.eq(_v(st, "SQ_S06_BOAT"), 1, "배")
	t.ok(_says(st, c, "SQS06_BOAT", "근무 끝"), "갈대밭에서 군모를 던진다")
	_play(st, c, "SQS06_BOAT")
	t.eq([_v(st, "SQ_S06_JIN"), _v(st, "SQ_S06_SOL")], [3, 3], "해법 C")
	st.vars.set_v("GAME_HOUR", 14)
	st.vars.set_v("SQ_S06_BOAT", 0)
	st.vars.set_v("SQ_S06_JIN", 1)
	t.ok(_says(st, c, "L25_SIM", "대낮에", ["배를 띄운다"]), "낮엔 안 띄운다")


func test_sq_s06_surrender_d(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SG", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	st.vars.set_v("SQ_S06_MET", 1)
	st.vars.set_v("SG_MET_HWANG", 1)
	st.vars.set_v("AFF_BJ", 0)
	st.vars.set_v("SG_REFUSED", 1)
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_CH", 10)
	t.eq(_play(st, c, "SG_HWANG", ["자수하면", "자진 복귀는", "됐습니다"]), [], "황보서현 쪽지(순서 자유)")
	t.eq(_v(st, "SQ_S06_NOTE"), 1, "자진 복귀 확인 쪽지")
	h.enter("Q-30", "from_X")
	t.ok(_says(st, c, "SQS06_JIN", "황보 소위님 글씨", ["자수"]), "쪽지가 있으면 설득이 쉽다")
	_play(st, c, "SQS06_JIN", ["자수"])
	t.eq([_v(st, "SQ_S06_PERSUADE"), _v(st, "SQ_S06_JIN")], [1, 1], "자수 결심 · 함께 간다")
	h.enter("X-SG", "arrive")
	c.tick()
	t.eq(_v(st, "SQ_S06_NEAR"), 1, "진해원이 곁에")
	var karma0 := _v(st, "V_KARMA")
	t.eq(_play(st, c, "SG_HWANG", ["자수하러"]), [], "검문소장 앞")
	t.eq([_v(st, "SQ_S06_JIN"), _v(st, "SQ_S06_SOL")], [4, 4], "영창 · 해법 D")
	t.eq(st.quests.stage("SQ-S06"), 100, "51 → 100")
	t.eq(_v(st, "V_KARMA") - karma0, 25, "카르마 +25")
	t.ok(_says(st, c, "SG_HWANG", "경례"), "D: 황보서현이 경례")
	t.ok(_says(st, c, "SG_KWON", "손이 떨렸어요"), "권은서 원문 대사")


func test_sq_s06_kwon_mediates(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SG", "arrive")
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	st.vars.set_v("SQ_S06_PERSUADE", 1)
	st.vars.set_v("SQ_S06_JIN", 1)
	st.vars.set_v("SQ_S06_NEAR", 1)
	st.vars.set_v("SG_MET_KWON", 1)
	st.kill("N-R01-047")
	t.ok(_says(st, c, "SG_KWON", "제가 적겠습니다"), "황보서현이 죽었으면 권은서가 중재")
	_play(st, c, "SG_KWON")
	t.eq(_v(st, "SQ_S06_SOL"), 4, "D")


func test_sq_s06_tell_and_hand(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SG", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	st.vars.set_v("SQ_S06_MET", 1)
	st.vars.set_v("SG_MET_HWANG", 1)
	st.vars.set_v("SG_REFUSED", 1)
	st.vars.set_v("PC_CAPS", 0)
	var karma0 := _v(st, "V_KARMA")
	_play(st, c, "SG_HWANG", ["어디 숨었는지", "됐습니다"])
	t.eq(_v(st, "SQ_S06_TOLD"), 1, "위치만 알림")
	t.eq(_v(st, "SQ_S06_JIN"), 0, "그날은 아직 탄약고")
	st.vars.set_v("GAME_DAY", 5)
	c._on_day(5)
	t.eq([_v(st, "SQ_S06_JIN"), _v(st, "SQ_S06_SOL")], [5, 5], "다음 날 계엄군 손 · 해법 E")
	t.eq(_v(st, "V_KARMA") - karma0, -100, "카르마 −100")
	t.ok(_says(st, c, "SQS06_HATCH", "아직 따뜻하다"), "탄약고 램프가 아직 따뜻하다")
	h.enter("X-SG", "arrive")
	c.tick()
	t.eq(_v(st, "PC_CAPS"), 150, "다음에 오면 포상 150캡")
	t.ok(_says(st, c, "SG_BOARD", "처리 완료"), "전단 '처리 완료'")


func test_sq_s06_kill_tag(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "Q-30", "from_X")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	h.combat.resident_down.emit("N-R01-064", true)
	t.eq([_v(st, "SQ_S06_JIN"), _v(st, "SQ_S06_SOL")], [6, 6], "F 처치")
	t.eq(st.quests.stage("SQ-S06"), 100, "사망 → 100")
	var box: Dictionary = {}
	for k in h.map.boxes:
		if str(h.map.boxes[k].get("name", "")) == "진해원의 유해":
			box = h.map.boxes[k]
	t.ok(not box.is_empty(), "시신 자리에 유해")
	t.eq(int(h.box_contents(box)["items"].get("M-185", 0)), 1, "목에 군번줄")
	st.vars.set_v("SQ_S06_DISC", Clock.abs_min(h.date_text) - 30 * 60)
	st.items["M-185"] = 1
	c._on_day(5)
	t.eq(_v(st, "SQ_S06_TAG"), 1, "군번줄을 먼저 챙겼다 — 신원 확인 못 함(BJ +3 없음)")
	t.ok(_says(st, c, "SG_BOARD", "실종"), "전단 '실종'")
	t.ok(_says(st, c, "SQS06_ROSTER", "공란 그대로"), "근무표는 공란 그대로")


func test_sq_s06_solo(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "Q-30", "from_X")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	st.vars.set_v("SQ_S06_FED", 1)
	st.vars.set_v("SQ_S06_CLOTH", 1)
	st.vars.set_v("SQ_S06_PAPERS", 1)
	t.eq(c._solo_p(), 70, "평상복 + 등록증 = 원문 70%")
	st.vars.set_v("SQ_S06_PAPERS", 0)
	st.vars.set_v("SQ_S06_ROUTE", 1)
	t.eq(c._solo_p(), 65, "50 + 준비마다 5")
	st.vars.set_v("SQ_S06_FED", 0)
	st.vars.set_v("SQ_S06_CLOTH", 0)
	st.vars.set_v("SQ_S06_ROUTE", 0)
	t.eq(c._solo_p(), 50, "아무것도 없이 반반")
	st.vars.set_v("GAME_DAY", 11)
	c._on_day(11)
	t.eq(_v(st, "SQ_S06_JIN"), 7, "7일: 혼자 길을 나섰다(받고 안 한 퀘스트)")
	st.vars.set_v("GAME_DAY", 12)
	c._on_day(12)
	t.ok(_v(st, "SQ_S06_SOL") in [7, 8], "다음 날 06시 판정 한 번")
	t.eq(st.quests.stage("SQ-S06"), 100, "끝")


func test_sq_s06_squad(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	_meet_and_join(h, st, c)
	st.vars.set_v("SQ_S06_DISC", Clock.abs_min(h.date_text) - 25 * 60)
	_at(h, Vector2i(715, 1545))
	c.tick()
	t.ok(not c.squad.is_empty() or _v(st, "SQ_S06_SQUADS") & 1 != 0, "시흥 고개 권역: 수색조")
	t.ok(c.squad.is_empty() or (c.squad["men"] as Array).size() in [3, 4], "3~4명(분대장 포함)")
	t.ok(c.squad.is_empty() or c.squad["men"].all(func(e): return e.cmb.team == "calm_s06"), "처음엔 비적대")
	if not c.squad.is_empty():
		c._squad_meet()
	t.eq(_v(st, "SQ_S06_LEADER"), 1, "분대장 첫 만남")
	t.ok(_says(st, c, "SQS06_SQUAD", "저놈이다"), "전투복 진해원 = 바로 알아본다")
	st.vars.set_v("SQ_S06_CLOTH", 1)
	st.vars.set_v("SQ_S06_PAPERS", 1)
	st.vars.set_v("SQ_S06_LEADER", 2)
	t.ok(_says(st, c, "SQS06_SQUAD", "지난번 그 일행"), "같은 분대장 두 번째")
	_play(st, c, "SQS06_SQUAD")
	t.ok(c.squad.is_empty(), "등록증 통과 — 수색조가 떠난다")
	t.ok(_v(st, "SQ_S06_SQUADS") & 1 != 0, "권역 한 번")
	c.tick()
	t.ok(c.squad.is_empty(), "같은 권역은 다시 안 선다")


func test_sq_s06_decoy_and_hide(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	_meet_and_join(h, st, c)
	st.vars.set_v("SQ_S06_DISC", Clock.abs_min(h.date_text) - 25 * 60)
	var m := h.combat.mates.get_mate("N-R01-064")
	m["mode"] = "hidden"
	c._on_hid("N-R01-064")
	t.eq(_v(st, "SQ_S06_HID"), 1, "숨음")
	st.vars.set_v("PC_TORSO", "A-031")
	_at(h, Vector2i(715, 1545))
	m["mode"] = "hidden"
	c._squad_spawn(0)
	if not c.squad.is_empty():
		c._squad_meet()
		t.eq(_v(st, "SQ_S06_DECOY"), 1, "주인공이 전투복 · 진해원이 멀다 = 미끼")
		t.ok(_says(st, c, "SQS06_SQUAD", "너 누구야"), "분대장 '…넌 누구야?'")
		_play(st, c, "SQS06_SQUAD")
		t.eq(_v(st, "SQ_S06_DECOY"), 2, "미끼")
		t.ok(_v(st, "SQ_S06_SQUADS") & 1 != 0, "진해원은 그 사이 권역을 지나간다")
	m["mode"] = "escort"
	c._on_regrouped("N-R01-064")
	t.eq(_v(st, "SQ_S06_DECOY"), 3, "다시 만난 진해원: '제 옷 입으니까 어때요?'")
	t.eq(_v(st, "SQ_S06_HID"), 0, "돌아옴")


func test_sq_s06_route_people(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SG", "arrive")
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	st.vars.set_v("SQ_S06_MET", 1)
	t.ok(_says(st, c, "SD_BAN", "짐, 물, 종이", ["노들섬까지"], "ASK"), "반로아: 길 셋")
	_play(st, c, "SD_BAN", ["노들섬까지", "됐어"], "ASK")
	t.eq(_v(st, "SQ_S06_ROUTE"), 2, "길 안내")
	t.eq(st.quests.stage("SQ-S06"), 40, "→ 40(10 · 20을 따라 올린다)")
	st.vars.set_v("SQ_S06_ROUTE", 1)
	t.ok(_says(st, c, "JM_YEOM", "사진 칸 빈"), "염희정: 종이")
	st.vars.set_v("V_WANTED", 40)
	t.ok(not _says(st, c, "JM_YEOM", "사진 칸 빈"), "수배 30 이상이면 염희정은 장사 안 함(B 막힘)")


func test_sq_s06_capture_and_abandon(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	_meet_and_join(h, st, c)
	st.vars.set_v("CAPTURE_BY", 1)
	h.enter("H-03", "cage_pc")
	t.eq(_v(st, "SQ_S06_JIN"), 7, "새벽인력 생포: 진해원은 혼자 달아난다(우리에 함께 서지 않는다)")
	t.ok(h.combat.mates.get_mate("N-R01-064").is_empty(), "동행에서 빠짐")
	var r2 := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: SideS06 = r2[2]
	_meet_and_join(h2, st2, c2)
	h2.combat.mates.set_mode("N-R01-064", "wait")
	h2.enter("X-SG", "arrive")
	t.ok(h2.combat.mates.away.has("N-R01-064"), "시흥 고개에 기다리게 두고 감")
	st2.vars.set_v("GAME_DAY", 11)
	c2._on_day(11)
	t.eq(_v(st2, "SQ_S06_JIN"), 7, "7일 기다리다 혼자 길을 나선다(받고 안 한 퀘스트)")
	t.ok(not h2.combat.mates.away.has("N-R01-064"), "기다리던 자리에서도 사라진다(한 사람 한 곳)")


func test_sq_s06_fun_fixes(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "X-SH", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS06 = r[2]
	_meet_and_join(h, st, c)
	var m := h.combat.mates.get_mate("N-R01-064")
	(m["actor"] as Actor).loco.place(h.player.loco.logical + Vector2(20 * 32, 0))
	m["mode"] = "hidden"
	c.tick()
	t.eq(_v(st, "SQ_S06_NEAR"), 0, "숨어 멀리 있으면 곁이 아니다")
	st.vars.set_v("SQ_S06_MET", 1)
	st.vars.set_v("SG_MET_HWANG", 1)
	st.vars.set_v("SG_REFUSED", 1)
	t.ok(not _opts(st, "SG_HWANG", "ASK").any(func(o): return o.contains("데려왔습니다")), "곁에 없으면 '데려왔습니다' 선택지가 없다(재미 검수 ①)")
	st.vars.set_v("SQ_S06_KIND", 1)
	t.ok(_says(st, c, "SQS06_SQUAD", "쉬는 중에"), "쉼 상황의 첫 줄")
	st.vars.set_v("SQ_S06_KIND", 2)
	t.ok(_says(st, c, "SQS06_SQUAD", "아까부터 따라왔다"), "뒤따름 상황의 첫 줄")
	st.vars.set_v("SQ_S06_PAPERS", 0)
	t.ok(_says(st, c, "SQS06_GATE", "빈손이"), "등록증 없이 남문(재미 검수 ⑦)")
	st.vars.set_v("PC_TORSO", "A-031@3")
	st.vars.set_v("SQ_S06_CLOTH", 1)
	t.ok(_says(st, c, "SG_HWANG", "이름표 자리가 비었군요"), "진해원의 전투복을 입고 검문소에(해 보고 싶은 짓)")
	c.chasers.append(null)
	c._chase_tick()
	t.eq(_v(st, "SQ_S06_CHECK"), 4, "다리목 계엄병을 다 쓰러뜨리면 검문이 끝난다(재미 검수 ②)")
