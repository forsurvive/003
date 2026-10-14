## 퀘스트 기록(단계 1-2, SD-12 §3.12): 막·경로 상태, 추적·고정, HUD 목표 줄, 퀘스트 마커, 핍-보이 목록 묶음, 저장 왕복.
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	return st


func test_quest_log_acts(t) -> void:
	var st := _st()
	var q := st.quests
	t.eq(q.acts.size(), 9, "막 표(SD-03a §3.1): 프롤로그 · 1~7막 · 에필로그")
	t.eq(str(q.act_def(1)["name"]), "1막 「미등록자」", "1막 이름")
	t.ok(str(q.act_def(1)["goal"]).begins_with("내 핍-보이의 관리자 코드"), "막 목표 = 로그 상단 문장(SD-03a 1막 절)")
	t.eq(q.act_def(1)["paths"], ["MQ-103", "MQ-104", "MQ-105"], "1막 경로 셋")
	t.eq(q.act_of("MQ-104"), 1, "퀘스트 → 막")
	t.eq(q.act_tag(0), "[이룸]", "프롤로그 목표 이룸(MQ-P4 종료)")
	t.eq(q.act_tag(1), "[진행 중]", "지금 막")
	t.eq(q.path_tag("MQ-103"), "[알려진 것 없음]", "시작 안 한 경로")
	t.eq(q.path_tag("MQ-101"), "", "경로가 아닌 퀘스트는 시작 전 표기 없음")
	q.set_stage("MQ-103", 10)
	t.eq(q.path_tag("MQ-103"), "[진행 중]", "시작한 경로")
	q.set_stage("MQ-105", 200)
	t.eq(q.path_tag("MQ-105"), "[놓침]", "실패한 경로")
	st.vars.set_v("K_CODE", 1)
	t.eq(q.act_tag(1), "[이룸]", "코드의 정체를 알면 1막 목표 이룸")
	t.eq(q.path_tag("MQ-103"), "[다른 길로 이룸]", "막 목표를 이룬 뒤 남은 경로(닫지 않는다)")
	t.eq(q.path_tag("MQ-104"), "[끝남]", "손대지 않은 경로는 끝남")
	t.eq(q.latest_line("MQ-103"), q.log_text("MQ-103", 10), "가장 최근 사실 줄")


func test_quest_log_track(t) -> void:
	var st := _st()
	var q := st.quests
	q.set_stage("MQ-101", 20)
	t.eq(q.objectives(), ["▶ " + q.log_text("MQ-101", 20)], "추적 없음 → 지금 막의 진행 중 퀘스트")
	q.auto_track("MQ-101")
	t.eq(q.tracked, "MQ-101", "주 퀘스트 시작 = 자동 추적")
	q.set_stage("MQ-103", 10)
	q.auto_track("MQ-103")
	t.eq(q.tracked, "MQ-101", "추적 중인 퀘스트가 있으면 넘기지 않는다")
	q.pin("MQ-103")
	q.pin("MQ-104")
	q.pin("MQ-105")
	t.eq(q.pinned, ["MQ-104", "MQ-105"], "고정은 2개까지(먼저 고정한 것이 빠진다)")
	q.pin("MQ-101")
	t.eq(q.pinned.size(), 2, "추적 중인 퀘스트는 고정하지 않는다")
	q.pinned = ["MQ-103"]
	var o := q.objectives()
	t.eq(o.size(), 2, "HUD 목표 줄 = 추적 1 + 고정")
	t.ok(str(o[1]).begins_with("◆ "), "고정 줄 표식")
	q.track("MQ-103")
	t.eq(q.tracked, "MQ-103", "Enter = 추적(고정에서 옮겨 온다)")
	t.ok(not "MQ-103" in q.pinned, "추적하면 고정에서 빠진다")
	q.track("MQ-103")
	t.eq(q.tracked, "", "같은 줄을 다시 고르면 추적 끔")
	q.track("act:1")
	t.eq(q.tracked_ids("act:1"), ["MQ-103", "MQ-104", "MQ-105"], "막 머리 추적 = 경로 전부")
	t.eq(q.objectives()[0], "▶ " + str(q.act_def(1)["goal"]), "막 추적 줄 = 막 목표")
	var d := GameSnapshot.story(st)
	var st2 := _st()
	GameSnapshot.apply_story(st2, JSON.parse_string(JSON.stringify(d)))
	t.eq(st2.quests.tracked, "act:1", "추적 저장 왕복")
	t.eq(st2.quests.pinned, q.pinned, "고정 저장 왕복")


func test_quest_log_marks(t) -> void:
	var st := _st()
	var q := st.quests
	q.set_stage("MQ-104", 10)
	q.track("MQ-104")
	t.eq(q.marks(st.places).size(), 0, "위치를 모르는 목표는 마커 없음")
	st.places.raise("L-R02-01", PlaceLog.RUMOR)
	var m := q.marks(st.places)
	t.ok(m.size() == 1 and m[0]["rumor"] and int(m[0]["n"]) == 0, "소문 = ? 원 마커 1개(번호 없음)")
	st.places.raise("L-R02-01", PlaceLog.MARKED)
	st.places.raise("L-R02-02", PlaceLog.MARKED)
	m = q.marks(st.places)
	t.eq(m.size(), 2, "알려진 위치 2곳")
	t.eq([int(m[0]["n"]), int(m[1]["n"])], [1, 2], "2개 이상이면 번호 ①②")
	t.ok(m[0]["main"], "추적 퀘스트 마커")
	q.set_stage("MQ-104", 100)
	t.eq(q.marks(st.places).size(), 0, "끝난 퀘스트는 마커 없음")


func test_quest_log_pipboy(t) -> void:
	var st := _st()
	var q := st.quests
	q.set_stage("MQ-101", 50)
	q.set_stage("MQ-102", 10)
	q.track("MQ-101")
	var p := PipBoy.new().setup(st, {}, {})
	p.open_at(2, 2)
	var rows := p._rows()
	t.eq(str(rows[0]["text"]), "[메인] 1막 「미등록자」", "맨 위 = 지금 막 머리")
	t.eq(str(rows[1]["text"]), "▶ 산 아래 마을", "추적 표식")
	t.eq(str(rows[2]["text"]), "└ 코드를 읽을 사람", "막 퀘스트 나무 줄")
	t.eq(rows.size(), 4, "시작 안 했고 소문도 없는 경로는 안 보인다 + 지난 막(접힘) 1줄")
	t.eq(str(rows[3]["id"]), "act:0", "지난 막 = 프롤로그 머리 한 줄")
	st.places.raise("L-R02-11", PlaceLog.RUMOR)
	rows = p._rows()
	t.ok(rows.any(func(r): return r["id"] == "MQ-103" and r["right"] == "?"), "장소 소문이 있으면 시작 전 경로가 [알려진 것 없음]으로 보인다")
	q.set_stage("MQ-205", 10)
	rows = p._rows()
	var hi := -1
	for i in rows.size():
		if rows[i]["text"] == "— 단서":
			hi = i
	t.ok(hi > 0 and rows[hi]["id"] == "", "아직 오지 않은 막의 퀘스트 = 단서 묶음")
	p.sel = hi - 1
	p.rows = rows
	p._step(1)
	t.eq(p.sel, hi + 1, "묶음 이름 줄은 건너뛴다")
	p.sel = 2
	p._enter()
	t.eq(q.tracked, "MQ-102", "Enter = 추적")
	p.free()


func test_npc_book(t) -> void:
	var st := _st()
	var b := st.book
	t.ok(b.meet("N-R01-001", "2268. 05. 14.  09:00"), "처음 대화 = 등록")
	t.ok(not b.meet("C-022", "2277. 10. 23.  16:40"), "같은 사람의 다른 ID(C-022 · N-R01-001)는 다시 등록하지 않는다")
	t.ok(not b.meet("SYS", "2277. 10. 23.  16:40") and not b.meet("X-999", ""), "자료에 없는 화자는 등록하지 않는다")
	t.eq(str(b.entries["C-022"]["met"]), "2268. 05. 14.", "처음 만난 날")
	t.eq(b.title("C-022"), "보안부장", "직함 = 역할 첫 마디")
	b.meet("C-010", "2277. 10. 23.  16:40")
	b.meet("C-057", "2277. 10. 23.  17:00")
	t.eq(b.faction_text("C-010"), "정착지 연합 · 봉천 계단마을", "소속 문장(JC·BC)")
	t.eq(b.services_text("C-010"), "상인 · 숙소 · 교습", "서비스")
	t.eq(b.place_of("C-010"), "L-R01-09", "주로 있는 곳")
	t.eq(b.list(), ["C-057", "C-010", "C-022"], "기본 = 최근 만난 순")
	t.ok(NpcBook.matches("조만석", "ㅈㅁㅅ") and NpcBook.matches("조만석", "만석") and NpcBook.matches("백인하", "ㅂㅇㅎ"), "이름·초성 찾기")
	t.ok(NpcBook.matches("조만석", "ㅁ석") and not NpcBook.matches("조만석", "ㅂㅇ"), "초성과 음절 섞어 찾기")
	t.eq(b.list(0, "", "ㅈㅁ"), ["C-010"], "목록 찾기")
	t.eq(b.list(1, "R01"), ["C-057", "C-010", "C-022"], "이 권역(R01)")
	t.eq(b.list(2), ["C-057", "C-010", "C-022"], "서비스 있는 사람")
	st.quests.set_stage("MQ-101", 20)
	t.eq(b.list(3, "", "", ["MQ-101"]), ["C-010"], "퀘스트 관련")
	b.died("C-057", "2277. 10. 24.  03:10")
	b.died("N-R01-002", "2277. 10. 24.  03:10")
	t.eq(str(b.entries["C-057"]["dead"]), "10. 24.", "고인 (10. 24.)")
	t.ok(not b.entries.has("C-023"), "모르는 사람의 죽음은 수첩에 없다")
	t.eq(b.list(4), ["C-010", "C-022"], "생존만")
	b.memo("C-010", "봉천에 머물 자리를 내주었다.")
	var st2 := _st()
	GameSnapshot.apply_story(st2, JSON.parse_string(JSON.stringify(GameSnapshot.story(st))))
	t.eq(st2.book.list(), ["C-057", "C-010", "C-022"], "저장 왕복(순서)")
	t.eq(str(st2.book.entries["C-010"]["memo"]), "봉천에 머물 자리를 내주었다.", "저장 왕복(메모)")
	var h := InteriorHost.new()
	h.st = st2
	h._ready()
	h.date_text = "2277. 10. 25.  10:00"
	h._barking = true
	h._on_line({"who": "N-R01-028"})
	t.ok(not st2.book.knows("N-R01-028"), "바크만 들은 인물은 등록하지 않는다")
	h._barking = false
	h._on_line({"who": "N-R01-028"})
	t.ok(st2.book.knows("N-R01-028"), "대화 줄 = 등록")
	var p := PipBoy.new().setup(st2, {}, {})
	p.open_at(2, 3)
	var rows := p._rows()
	t.eq(str(rows[0]["text"]), "— 인물 수첩 4", "기록: 인물 수첩 머리")
	t.eq(str(rows[1]["text"]), "남태하", "맨 위 = 가장 최근")
	t.eq(str(rows[2]["right"]), "고인", "고인 표시")
	p.free()
	h.free()
