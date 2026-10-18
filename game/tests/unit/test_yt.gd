## 단계 1-D9 여의도 유리탑 3동 · 증권가 객장(DG-YT · UQ-06 「마지막 시세」, SD-09a L-R02-08 · L-R02-07 · SD-05 §3.4 · 1-D 계획 §15.7):
## 자료(맵 넷 · 장면 · 카드 넷 · 테이프 · 던전 표) · 발급 시각 범위(22:41~23:20) · 게이트 판독(등급 · 인사 · 날개) · 18층 로봇 대조(남기범 통과 · 도미란 질문 ·
## 사망 확정 · 오정택 잔업 사유 · 임시 출입증 동행 · 미확인 출입 · 보안 사고 격리) · 로봇 부숨(전 층 봉쇄) · 서기(졸음 · 훔치기 · 밤 반사 · 쓰러지면 카드) ·
## 테이프 세 갈래(전광판 · 우도하 남산 · 가짜 마감)와 하루 판정(떠남 · 돌아옴 · 방송).
extends RefCounted


func _host(map_id := "YT-01", mark := "from_W", hhmm := "10:00") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	st.vars.set_v("PC_SKP_SCIENCE", 100)
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_SKP_SNEAK", 100)
	st.vars.set_v("PC_SKP_LOCKPICK", 100)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  %s" % hhmm
	st.vars.set_v("GAME_HOUR", int(hhmm.substr(0, 2)))
	var c := Yt.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: Yt, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "yt":
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


func _opts(st: StoryState, id: String) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var guard := 0
	while cur["type"] != "choices" and cur["type"] != "end" and guard < 50:
		guard += 1
		cur = dr.advance()
	if cur["type"] != "choices":
		return []
	return cur["opts"].filter(func(o): return bool(o["enabled"])).map(func(o): return str(o["text"]))


func _at(h: InteriorHost, st: StoryState, hhmm: String) -> void:
	h.date_text = "2277. 11. 01.  %s" % hhmm
	st.vars.set_v("GAME_HOUR", int(hhmm.substr(0, 2)))


func test_yt_data(t) -> void:
	for m in ["YT-01", "YT-02", "YT-03", "SG-01"]:
		t.ok(FileAccess.file_exists("res://data/maps/%s.json" % m), "맵 %s" % m)
	for s in ["YT_GATE1", "YT_GATE2", "YT_GATE3", "YT_STAIR", "YT_LOG", "YT_POWER", "YT_ELEV", "YT_SHUT", "YT_CLERK", "YT_OJ", "YT_HABORAM", "YT_LEDGER", "YT_ISSUE",
			"YT_VENT", "YT_VENT18", "YT_ELEV18", "YT_READ18", "YT_SHUT18_IN", "YT_ROBOT", "YT_ROBOT_IN", "YT_DOMI", "YT_DECK", "YT_MOUND", "UQ06_KS", "YT_BOARD"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % s), "장면 %s" % s)
	var r := _host()
	var h: InteriorHost = r[0]
	for id in ["M-072", "M-401", "M-402", "M-403", "M-404", "M-405"]:
		t.ok(h.items_db.has(id), "아이템 %s" % id)
	var st: StoryState = r[1]
	t.ok(FileAccess.get_file_as_string("res://data/quests.json").contains("\"UQ-06\""), "퀘스트 UQ-06")
	var dg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dungeons.json"))
	t.ok(str(dg).contains("DG-YT"), "던전 표 DG-YT")


func test_yt_issue_range(t) -> void:
	t.ok(not Yt.issue_ok(1350), "22:30 — 대장 마지막 줄(22:40)보다 앞: 무효")
	t.ok(not Yt.issue_ok(1360), "22:40 — 같은 시각(번호가 겹침): 무효")
	t.ok(Yt.issue_ok(1370), "22:50 — 진짜")
	t.ok(Yt.issue_ok(1390), "23:10 — 진짜")
	t.ok(not Yt.issue_ok(1401), "23:21 — 집행 모드: 무효")
	t.ok(not Yt.issue_ok(1410), "23:30 — 무효")
	t.ok(not Yt.issue_ok(0), "지금 시각 — 무효")


func test_yt_gates(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Yt = r[2]
	t.ok(h.map.is_solid(Yt.GATE3), "3동 게이트는 닫혀 막는다")
	st.call_fn("give", ["M-403", 1])
	t.eq(_play(st, c, "YT_GATE3", ["오정택"]), [], "오정택 카드 원고")
	t.eq(_v(st, "YT_R"), 0, "파랑 카드는 3동 거부")
	t.ok(h.map.is_solid(Yt.GATE3), "그대로 닫힘")
	t.eq(_play(st, c, "YT_GATE2", ["오정택"]), [], "2동 게이트 원고")
	t.eq(_v(st, "YT_R"), 1, "파랑 카드는 2동 통과")
	t.ok(not h.map.is_solid(Yt.GATE2), "2동 날개가 접혀 지나간다")
	# 1동 시험대: 아무 카드나 받고 마지막 기록
	t.eq(_play(st, c, "YT_GATE1", ["오정택", "그만둔다"]), [], "1동 시험대 원고")
	t.eq(_v(st, "YT_GATE1"), 1, "시험대를 써 봄")
	# 위조: 범위 안 → 진짜 빨강
	t.eq(_play(st, c, "YT_ISSUE", ["관리자", "오정택", "22:50"]), [], "발급 단말 원고")
	t.eq(_v(st, "YT_FORGE"), 3, "오정택 카드를 덧씀")
	t.eq(_v(st, "YT_TEMP"), 0, "22:50 — 진짜")
	t.eq(c.grade(3), 3, "빨강")
	t.eq(_play(st, c, "YT_GATE3", ["오정택"]), [], "다시 3동")
	t.eq(_v(st, "YT_R"), 1, "통과")
	t.ok(not h.map.is_solid(Yt.GATE3), "3동 날개가 접힌다")
	t.ok(not ("(오정택 카드를 넣는다)" in _opts(st, "YT_ISSUE")), "단말은 한 번 — 두 번째 갱신 메뉴 없음")
	# 비상 계단 철문
	t.eq(_play(st, c, "YT_STAIR", ["오정택"]), [], "계단 판독")
	t.ok(h.map.locked_door_at(Vector2i(36, 2)).is_empty(), "철문 잠금쇠가 풀린다")


func test_yt_robot_paths(t) -> void:
	# ① 남기범 카드 — 그날 밤의 심부름꾼: 바로 통과
	var r := _host("YT-03", "from_stair")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Yt = r[2]
	t.ok(h.map.is_solid(Yt.SHUT_18), "18층 셔터는 닫혀 있다")
	st.call_fn("give", ["M-401", 1])
	t.eq(_play(st, c, "YT_READ18", ["남기범"]), [], "남기범 판독")
	t.eq(_v(st, "YT_ROBOT_OK"), 1, "로봇 대조 통과")
	t.ok(not h.map.is_solid(Yt.SHUT_18), "셔터가 오른다")
	# ② 도미란 카드 — 질문 → 화술로 교대
	r = _host("YT-03", "from_stair")
	h = r[0]
	st = r[1]
	c = r[2]
	st.call_fn("give", ["M-402", 1])
	t.eq(_play(st, c, "YT_READ18", ["도미란", "당번 교대"]), [], "도미란 판독 · 교대")
	t.eq(_v(st, "YT_ROBOT_OK"), 1, "교대 확인")
	# ③ 도미란 사망 확정(엉뚱한 짓) — 그 카드는 어디서도 안 열린다
	r = _host("YT-03", "from_stair")
	h = r[0]
	st = r[1]
	c = r[2]
	st.call_fn("give", ["M-402", 1])
	t.eq(_play(st, c, "YT_READ18", ["도미란", "이미 죽었다"]), [], "사망 처리 원고")
	t.eq(_v(st, "YT_DEAD_DM"), 1, "도미란 사망 확정")
	t.eq(c.grade(2), 0, "카드 무효")
	t.ok(h.map.is_solid(Yt.SHUT_18), "셔터는 닫힌 채")
	t.eq(_play(st, c, "YT_READ18", ["도미란"]), [], "다시 대 봄")
	t.eq(_v(st, "YT_R"), 7, "사망 처리 사원 — 거부")
	# ④ 오정택(위조 진짜) — 잔업 사유는 근무지(송출)와 맞아야
	r = _host("YT-03", "from_stair")
	h = r[0]
	st = r[1]
	c = r[2]
	st.call_fn("give", ["M-403", 1])
	c.forge(3, 1390)
	t.eq(_play(st, c, "YT_READ18", ["오정택", "정산 마감"]), [], "틀린 사유")
	t.eq(_v(st, "YT_ROBOT_OK"), 0, "보류")
	t.eq(_play(st, c, "YT_READ18", ["오정택", "송출 지원"]), [], "맞는 사유")
	t.eq(_v(st, "YT_ROBOT_OK"), 1, "송출 지원 확인")
	# ⑤ 임시 출입증 — 동행 · 테이프를 꺼내면 보안 사고(격리)
	r = _host("YT-03", "from_stair")
	h = r[0]
	st = r[1]
	c = r[2]
	st.call_fn("give", ["M-072", 1])
	c.forge(4, 1410)
	t.eq(c.grade(4), 4, "23:30 — 임시 출입증")
	t.eq(_play(st, c, "YT_READ18", ["하보람"]), [], "임시 판독")
	t.eq(_v(st, "YT_ESCORT"), 1, "로봇 동행")
	t.ok(not h.map.is_solid(Yt.SHUT_18), "셔터는 오른다")
	t.eq(_play(st, c, "YT_DECK", ["꺼낸다"]), [], "데크 원고")
	t.ok(st.items.has("M-404"), "테이프는 손에")
	t.eq(_v(st, "YT_INC"), 1, "반출 금지 — 보안 사고")
	t.ok(h.map.is_solid(Yt.SHUT_18), "셔터가 걸린다(격리)")
	t.eq(_play(st, c, "YT_SHUT18_IN"), [], "안쪽 단추 원고")
	t.ok(h.map.is_solid(Yt.SHUT_18), "격리 중엔 안에서도 안 열린다 — 환풍구로")


func test_yt_vent_and_smash(t) -> void:
	var r := _host("YT-02", "from_YT01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Yt = r[2]
	h.enter("YT-03", "from_vent")
	t.eq(h.map.id, "YT-03", "환풍구로 18층 송출실")
	t.eq(_play(st, c, "YT_ROBOT_IN", ["대답하지 않는다"]), [], "미확인 출입 원고")
	t.eq(_v(st, "YT_INC"), 1, "대답 없음 — 보안 사고")
	t.eq(_play(st, c, "YT_ROBOT", ["부순다"]), [], "로봇 부숨 원고")
	t.eq(_v(st, "YT_LOCK"), 1, "전 층 판독 봉쇄")
	t.ok(not h.map.is_solid(Yt.SHUT_18), "셔터는 반쯤 오른 채 굳어 지나간다")
	st.call_fn("give", ["M-401", 1])
	t.eq(_play(st, c, "YT_ELEV18"), [], "승강기 원고")
	h.enter("YT-01", "from_W")
	t.ok(not h.map.is_solid(Yt.GATE3), "봉쇄 뒤 3동 날개도 접힌 채 굳었다")
	var o := _opts(st, "YT_GATE1")
	t.ok(o.is_empty(), "봉쇄 — 1동 시험대도 빨간 엑스(선택지 없음)")


func test_yt_clerk(t) -> void:
	var r := _host("YT-01", "from_W", "10:00")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Yt = r[2]
	var e = c._clerk()
	t.ok(e != null, "서기 남기범이 로비에 있다")
	t.eq(_v(st, "YT_DOZE"), 1, "낮엔 소파에서 존다")
	t.ok(e.asleep, "잠듦")
	t.eq(_play(st, c, "YT_CLERK", ["목걸이"]), [], "카드 풀기 원고")
	t.ok(st.items.has("M-401"), "진짜 빨강 카드를 훔쳤다")
	t.ok(e.asleep, "깨지 않았다")
	# 밤 반사: 22:50 — 게이트를 지나 승강기 문 앞으로
	r = _host("YT-01", "from_W", "22:50")
	h = r[0]
	st = r[1]
	c = r[2]
	e = c._clerk()
	t.eq(_v(st, "YT_DOZE"), 0, "밤엔 졸지 않는다")
	t.ok(not e.route.is_empty(), "승강기 문 앞으로 걷는다")
	t.ok(not h.map.is_solid(Yt.GATE3), "그의 카드는 진짜 — 3동 게이트가 혼자 열린다")
	# 쓰러뜨리면 카드는 유해에
	c._on_down(e)
	t.eq(st.is_dead("N-YTB-1"), true, "서기 사망")
	var found := false
	for k in h.map.boxes:
		var b: Dictionary = h.map.boxes[k]
		if str(b.get("name", "")) == "남기범의 유해":
			found = int(h.box_contents(b)["items"].get("M-401", 0)) == 1
	t.ok(found, "유해에 빨강 사원증")


func test_yt_tape_board(t) -> void:
	var r := _host("SG-01", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Yt = r[2]
	t.eq(_play(st, c, "UQ06_KS", ["됐다"]), [], "경상현 첫 대화")
	t.eq(_v(st, "UQ06_MET"), 1, "만남")
	t.eq(st.quests.stage("UQ-06"), 20, "18층 이야기 — 단계 20")
	st.call_fn("give", ["M-404", 1])
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(st, c, "YT_BOARD", ["시세 테이프"]), [], "전광판 원고")
	t.eq(_v(st, "UQ06_RESULT"), 1, "① 마감 종")
	t.ok(not st.items.has("M-404") and st.items.has("M-405"), "테이프는 지워졌다(빈 테이프)")
	t.eq(_v(st, "V_KARMA") - k0, 25, "카르마 +25")
	t.eq(st.quests.stage("UQ-06"), 100, "UQ-06 끝")
	t.eq(_play(st, c, "UQ06_KS", ["구울이 됐어"]), [], "남 서기 물음")
	t.eq(_v(st, "UQ06_ASKED"), 1, "구울이 됐다고 말함")
	c._on_day(11)
	t.eq(_v(st, "UQ06_GONE"), 1, "다음 날 지하시장 관리사무소로")
	t.ok(not ("(시세 테이프를 넣는다)" in _opts(st, "YT_BOARD")), "빈 테이프는 다시 못 넣는다")


func test_yt_tape_woo_and_fake(t) -> void:
	var r := _host("SG-01", "from_W")
	var st: StoryState = r[1]
	var c: Yt = r[2]
	st.call_fn("give", ["M-404", 1])
	var caps0 := _v(st, "PC_CAPS")
	c.woo()
	t.eq(_v(st, "UQ06_RESULT"), 2, "② 우도하")
	t.ok(not st.items.has("M-404"), "테이프는 남산으로")
	t.eq(_v(st, "PC_CAPS") - caps0, 80, "80캡")
	t.eq(_v(st, "UQ06_RADIO"), 1, "넘김")
	c._on_day(11)
	t.eq(_v(st, "UQ06_RADIO"), 2, "다음 06:00 남산 방송")
	t.eq(_v(st, "UQ06_GONE"), 0, "경상현은 숫자 없이 남는다")
	# ③ 가짜 마감 → 떠났다가 7일 뒤 돌아옴 · 그 사이 진짜 테이프면 ①
	r = _host("SG-01", "from_W")
	st = r[1]
	c = r[2]
	t.eq(_play(st, c, "YT_BOARD", ["아무 숫자"]), [], "가짜 마감 원고")
	t.eq(_v(st, "UQ06_RESULT"), 3, "③")
	c._on_day(11)
	t.eq(_v(st, "UQ06_GONE"), 1, "떠남")
	c._on_day(17)
	t.eq(_v(st, "UQ06_BACK"), 1, "7일 뒤 돌아옴 — '숫자가 너무 예뻤어요'")
	t.eq(_v(st, "UQ06_GONE"), 0, "객장에")
	st.call_fn("give", ["M-404", 1])
	t.eq(_play(st, c, "YT_BOARD", ["시세 테이프"]), [], "진짜 테이프")
	t.eq(_v(st, "UQ06_RESULT"), 1, "①로 바뀜")
	t.eq(_v(st, "UQ06_BACK"), 0, "돌아온 표시도 지움")
