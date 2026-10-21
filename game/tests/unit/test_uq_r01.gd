## 단계 1-12g 관악 비표시 퀘스트 넷(SD-05 §3.23~§3.26, 계획 docs/seoul-fallout/_plans/1-12g_UQ-01-02-03-05_plan.md §7):
## UQ-01 순서(카드 → 뜯기) · 목격 씨앗 한 번 · 출입 막힘 · 연보경 편 카드 / UQ-02 나들이 창 · 동행 중 나들이 없음 · 새끼 30일 /
## UQ-03 교대 창 부탁 · 전함 → 사진 → 건넴 · 7일 냉담 · 30일 갖기 · 알림 → 강등 → 7일 뒤 떠남 · 없음 판 식 /
## UQ-05 잃기 조건(연보경 · MQ-106 · S06 짐칸) · 3일 척후 · 7일 빌린 소 · 짐 돌려줌 사례 한 번 · 잡기 · 거래 거부.
extends RefCounted


func _host(map_id := "X-BC", mark := "from_X-S07") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("MQ101_STAGE", 100)
	st.vars.set_v("MQ101_RESULT", 1)
	st.vars.set_v("GAME_DAY", 5)
	st.vars.set_v("GAME_HOUR", 10)
	st.vars.set_v("PC_CAPS", 200)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 28.  10:00"
	var c := UqR01.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: UqR01, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "uqr":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				i = -1
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
						break
				k += 1
			else:
				i = cur["opts"].size() - 1
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			if cur.has("text"):
				said.append(str(cur["text"]))
			cur = dr.advance()
	return dr.errors + ["말:" + " / ".join(said)]


func _says(st: StoryState, c: UqR01, id: String, needle: String, picks: Array = []) -> bool:
	var r := _play(st, c, id, picks)
	return r.size() == 1 and str(r[0]).begins_with("말:") and str(r[0]).contains(needle)


func _has_opt(st: StoryState, id: String, needle: String, picks: Array = []) -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 200:
		guard += 1
		if cur["type"] == "choices":
			if k >= picks.size():
				for o in cur["opts"]:
					if str(o["text"]).contains(needle) and bool(o["enabled"]):
						return true
				return false
			var i := -1
			for j in cur["opts"].size():
				if str(cur["opts"][j]["text"]).contains(str(picks[k])):
					i = j
			k += 1
			if i < 0:
				return false
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return false


# ---------------------------------------------------------------- UQ-01
func test_uq01_relay_and_witness(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	st.call_fn("give", ["M-427", 1])
	st.vars.set_v("TR_YEON_MET", 1)
	st.vars.set_v("CARAVAN_V54", 2)
	c._cmd(["relay"], func() -> void: pass)
	t.eq(_v(st, "UQ01_RELAY"), 1, "카드를 연보경 편에")
	t.eq(st.count_of("M-427"), 0, "카드는 연보경 짐으로")
	c._relay_tick()
	t.eq(_v(st, "UQ01_SOL"), 0, "봉천 정류 전엔 안 닿음")
	st.vars.set_v("CARAVAN_V54", 1)
	c._relay_tick()
	t.eq(_v(st, "UQ01_SOL"), 1, "봉천 정류 때 등록기가 살아남")
	t.eq(st.quests.stage("UQ-01"), 100, "끝")
	var b := _host()
	var st2: StoryState = b[1]
	var c2: UqR01 = b[2]
	st2.vars.set_v("UQ01_RELAY", 1)
	st2.kill("N-R01-040")
	c2._relay_tick()
	t.eq(_v(st2, "UQ01_RELAY"), 0, "연보경이 죽으면 카드 전달이 끊김(재발급 길로)")
	# 목격 판정은 뜯은 날 씨앗으로 한 번
	st2.vars.set_v("UQ01_SOL", 3)
	st2.vars.set_v("UQ01_THEFT_DAY", 5)
	c2._on_day(6)
	t.eq(_v(st2, "UQ01_WITNESS"), 1, "다음 날 판정 한 번")
	var seen := _v(st2, "UQ01_SEEN")
	st2.vars.set_v("UQ01_SEEN", 1 - seen)
	c2._on_day(7)
	t.eq(_v(st2, "UQ01_SEEN"), 1 - seen, "두 번째 06시엔 다시 굴리지 않음")


func test_uq01_ban(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	c._cmd(["caught"], func() -> void: pass)
	t.eq(_v(st, "UQ01_BAN_DAY"), 5 + UqR01.BAN_DAYS, "들킨 날 + 7일까지 출입 막힘")


# ---------------------------------------------------------------- UQ-02
func test_uq02_outing_rules(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	h.date_text = "2277. 10. 28.  22:40"
	t.eq(c._out_window(), 1, "22:30~23:10 첫 나들이")
	h.date_text = "2277. 10. 29.  00:05"
	t.eq(c._out_window(), 2, "자정 넘어 00:10까지 둘째 나들이")
	h.date_text = "2277. 10. 29.  00:20"
	t.eq(c._out_window(), 0, "그 밖엔 없음")
	t.ok(c._dog_can_go(), "MQ-101 뒤 백구는 나간다")
	st.vars.set_v("SQ_S01_DOG", 1)
	t.ok(not c._dog_can_go(), "동행 중엔 나들이 없음(P3)")
	st.vars.set_v("SQ_S01_DOG", 0)
	st.vars.set_v("UQ02_PUP_SPOT", 3)
	c._on_day(3 + UqR01.PUP_DAYS)
	t.eq(_v(st, "UQ02_GONE_DAY"), 3 + UqR01.PUP_DAYS, "그냥 두면 30일 뒤 새끼는 산으로")
	t.ok(not c._dog_can_go(), "새끼가 떠나면 나들이도 끝")


# ---------------------------------------------------------------- UQ-03
func test_uq03_flow(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	st.vars.set_v("GAME_HOUR", 12)
	st.vars.set_v("UQ03_EOM", 0)
	st.book.meet("N-R01-050", "2277. 10. 27.")
	t.ok(not _says(st, c, "MQ-105_BJ_IDLE", "사적인 부탁"), "교대 시간(06~08 · 18~20) 밖엔 부탁 없음")
	st.vars.set_v("GAME_HOUR", 18)
	_play(st, c, "MQ-105_BJ_IDLE", ["전해 드리죠"])
	t.eq(st.quests.stage("UQ-03"), 10, "교대 시간 부탁 — 받음")
	t.eq(st.count_of("M-003"), 10, "배급표 열 장을 받음")
	t.eq(_v(st, "UQ03_GOT_DAY"), 5, "받은 날")
	_play(st, c, "UQ03_MOM", ["전할게요"])
	t.eq(st.quests.stage("UQ-03"), 30, "전하고 사진을 받음")
	t.eq(st.count_of("M-428"), 1, "사진")
	t.eq(st.count_of("M-003"), 0, "배급표는 엄옥순에게")
	_play(st, c, "MQ-105_BJ_IDLE")
	t.eq(_v(st, "UQ03_PASS"), 1, "사진을 건네면 PASS")
	t.eq(st.quests.stage("UQ-03"), 100, "끝")
	t.ok(StoryExpr.test("UQ03_PASS == 1 and UQ03_EOM == 0 and V_WANTED < 60", st), "S06 짐 검사 PASS 판 식이 참")


func test_uq03_clocks(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	st.quests.set_stage("UQ-03", 10)
	st.vars.set_v("UQ03_GOT_DAY", 5)
	c._on_day(12)
	t.eq(_v(st, "UQ03_COLD"), 1, "7일 — 냉담만")
	t.eq(_v(st, "UQ03_RES"), 0, "7일엔 갖기 정산 없음(계획 §8.3)")
	var k0 := _v(st, "V_KARMA")
	c._on_day(35)
	t.eq(_v(st, "UQ03_RES"), 3, "30일 — 갖기")
	t.eq(_v(st, "V_KARMA"), k0 - 10, "카르마 −10")
	t.eq(st.quests.stage("UQ-03"), 100, "끝")
	st.call_fn("give", ["M-003", 12])
	c._cmd(["bag"], func() -> void: pass)
	t.eq(st.count_of("M-003"), 2, "'가방 열어' — 자기 몫 열 장만 도로")
	c._cmd(["bag"], func() -> void: pass)
	t.eq(st.count_of("M-003"), 2, "한 번만")


func test_uq03_report(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	c._cmd(["report"], func() -> void: pass)
	t.eq(_v(st, "UQ03_EOM"), 1, "알림 — 강등")
	c._on_day(11)
	t.eq(_v(st, "UQ03_EOM"), 1, "6일째는 아직 초소")
	c._on_day(12)
	t.eq(_v(st, "UQ03_EOM"), 2, "7일 뒤 근무지 이탈")
	t.ok(StoryExpr.test("(known_dead(\"N-R01-050\") == 1 or UQ03_EOM >= 2)", st), "S06 · JH-03 없음 판 식이 참")


# ---------------------------------------------------------------- UQ-05
func test_uq05_lose_gate(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	c._last_v54 = 1
	st.vars.set_v("CARAVAN_V54", 0)
	c._cow_tick()
	t.eq(_v(st, "UQ05_COW"), 0, "연보경을 만나기 전엔 안 잃음")
	st.vars.set_v("TR_YEON_MET", 1)
	st.vars.set_v("SQ_S06_CARAVAN", 1)
	c._last_v54 = 1
	c._cow_tick()
	t.eq(_v(st, "UQ05_COW"), 0, "S06 짐칸 해법이 잡힌 구간엔 안 잃음(P4)")
	st.vars.set_v("SQ_S06_CARAVAN", 0)
	c._last_v54 = 1
	c._cow_tick()
	t.eq(_v(st, "UQ05_COW"), 1, "봉천 → 사당 구간 시작에 잃음")
	t.eq(_v(st, "UQ05_ABSENT"), 1, "수송대 짐소 줄이 빔")
	var o := WorldMap.origin_of("X-NS")
	var spot: Vector2i = UqR01.NS_SPOTS[_v(st, "UQ05_SPOT")]
	t.eq(Vector2i(_v(st, "UQ05_CX"), _v(st, "UQ05_CY")), o + spot, "자리 넷 중 하나(X-NS)")
	t.eq(_v(st, "UQ05_CAUSE"), 1, "척후장이 살아 있으면 '척후 총소리'")
	c._last_v54 = 1
	st.vars.set_v("UQ05_COW", 0)
	c._cow_tick()
	t.eq(_v(st, "UQ05_COW"), 0, "한 번만(잃은 날이 이미 있음)")


func test_uq05_clocks(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	st.vars.set_v("UQ05_COW", 1)
	st.vars.set_v("UQ05_ABSENT", 1)
	st.vars.set_v("UQ05_LOST_DAY", 5)
	c._on_day(7)
	t.eq(_v(st, "UQ05_COW"), 1, "이틀은 그대로")
	c._on_day(8)
	t.eq(_v(st, "UQ05_COW"), 5, "척후가 살아 있으면 3일 뒤 끌고 감")
	t.eq(_v(st, "UQ05_SPILL"), 1, "꾸러미는 캠프 버스 안")
	t.eq(st.quests.stage("UQ-05"), 100, "사라짐 — 끝")
	c._on_day(12)
	t.eq(_v(st, "UQ05_ABSENT"), 2, "7일 뒤 위강윤에게 빌린 소")


func test_uq05_rewards(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	st.vars.set_v("TR_YEON_MET", 1)
	st.vars.set_v("UQ05_COW", 1)
	st.vars.set_v("UQ05_CAUSE", 2)
	t.ok(_says(st, c, "TR_YEON", "들개 떼가 붙었어"), "연보경 — 까닭은 그날 세계에서(들개)")
	t.eq(_v(st, "UQ05_HEARD"), 1, "들음")
	_play(st, c, "UQ05_COW", ["짐 꾸러미만 푼다"])
	t.eq(st.count_of("M-429"), 1, "꾸러미")
	var k0 := _v(st, "V_KARMA")
	_play(st, c, "TR_YEON", ["누렁이 짐 꾸러미"])
	t.eq(st.count_of("M-429"), 0, "돌려줌")
	t.eq(st.count_of("I-066"), 2, "정화통 둘")
	t.eq(_v(st, "V_KARMA"), k0 + 25, "카르마 +25")
	t.eq(_v(st, "UQ05_DISC"), 0, "짐만 돌려주면 할인 없음")
	st.vars.set_v("UQ05_AT", 1)
	st.vars.set_v("CARAVAN_V54", 2)
	_play(st, c, "UQ05_BACK")
	t.eq(_v(st, "UQ05_DISC"), 1, "소까지 데려오면 할인")
	t.eq(_v(st, "V_KARMA"), k0 + 25, "사례(카르마)는 한 번(P9)")
	t.eq(_v(st, "UQ05_COW"), 3, "돌아감")
	t.eq(_v(st, "UQ05_ABSENT"), 0, "수송대 짐소 줄이 다시 섬")


func test_uq05_kill(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	st.vars.set_v("UQ05_COW", 1)
	var o := WorldMap.origin_of("X-SD") + UqR01.SD_POST
	st.vars.set_v("UQ05_CX", o.x + 3)
	st.vars.set_v("UQ05_CY", o.y)
	var k0 := _v(st, "V_KARMA")
	_play(st, c, "UQ05_COW", ["소를 잡는다", "잡는다"])
	t.eq(_v(st, "UQ05_COW"), 4, "잡힘")
	t.eq(st.count_of("M-430"), 1, "고기 꾸러미")
	t.eq(_v(st, "V_KARMA"), k0 - 25, "카르마 −25(가축)")
	t.eq(_v(st, "UQ05_REFUSE_DAY"), 5 + 3, "사당 광장 앞 낮 — 위강윤이 봄(3일 거부)")
	st.vars.set_v("TR_YEON_MET", 1)
	t.ok(_says(st, c, "TR_YEON", "오늘은 장사 안 해"), "거부 중 연보경")
	st.vars.set_v("UQ05_REFUSE_DAY", 0)
	t.ok(_has_opt(st, "TR_EOM", "고기 꾸러미를 판다"), "엄태경이 사 준다")
	_play(st, c, "TR_EOM", ["고기 꾸러미를 판다"])
	t.eq(_v(st, "PC_CAPS"), 280, "80캡")
	t.ok(not _has_opt(st, "TR_EOM", "고기 꾸러미를 판다"), "한 번만")
