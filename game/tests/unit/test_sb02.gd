## 단계 1-12f FQ-SB-02 「현장 운송」(SD-04d §6.4, 계획 docs/seoul-fallout/_plans/1-12f_FQ-SB-01-02_plan.md §5 · §6):
## 04시 본소 마당 출발 줄(SB-01 완료 · 문턱) · 고가 끝 오태수(돌려보냄 · 못 본 척 · 숨김 — 본 사람 SEEN) · 쉬는 박자 원격기 · 방범대(싸움 · 말 · 넘김) ·
## 정찰 → 우회 · 인계 지점 통행세 60 · 10:00 마감 · 빠짐(맵 밖 30분 · 멀어짐 10분) · 흩어짐(인솔조에 총) · 조장이 쓰러지면 대리 반장(_L 판).
extends RefCounted


func _host(date := "2277. 10. 29.  04:10", sb01 := 100) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.quests.set_stage("FQ-SB-01", sb01)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 7)
	st.vars.set_v("GAME_HOUR", int(date.substr(15, 2)))
	st.vars.set_v("AFF_SB", -10)
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_SKP_SNEAK", 100)
	st.vars.set_v("PC_CAPS", 500)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = date
	var c := FqSb.new()
	c.setup(h)
	h.enter("X-SB", "gate_in")
	return [h, st, c]


func _at(h: InteriorHost, st: StoryState, date: String) -> void:
	h.date_text = date
	st.vars.set_v("GAME_HOUR", int(date.substr(15, 2)))


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: FqSb, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "sb02":
				c._cmd2(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := -1
			if k < picks.size():
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


func _said(r: Array) -> String:
	return str(r[r.size() - 1]) if r.size() > 0 else ""


## 마당에 줄이 서고 '호위 서겠다'로 출발한 상태
func _go(st: StoryState, c: FqSb) -> void:
	c.tick2()
	_play(st, c, "FQSB02_YARD", ["호위 서겠다"])


func _has_deed(st: StoryState, tag: String) -> bool:
	for d in st.deeds.list:
		if str(d.get("tag", "")) == tag:
			return true
	return false


## 출발 줄: 04시 · 본소 마당 · SB-01 완료일 때만 선다 · 문턱(차가움 · 구울 · 수배) · 출발하면 단계 10 · 걷기
func test_sb02_yard(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	t.ok(not c._route.is_empty(), "경로 자료를 읽었다")
	t.ok(c._in_yard(), "정문 안쪽은 X-SB 구역")
	var r0 := _host("2277. 10. 29.  04:10", 30)
	(r0[2] as FqSb).tick2()
	t.ok((r0[2] as FqSb).cv.is_empty(), "SB-01이 안 끝났으면 줄이 안 선다")
	t.ok(_said(_play(r0[1], r0[2], "FQSB02_YARD")).contains("일부터"), "말을 걸면 '일부터 받아'")
	_at(h, st, "2277. 10. 29.  06:10")
	c.tick2()
	t.ok(c.cv.is_empty(), "06시엔 줄이 없다")
	_at(h, st, "2277. 10. 29.  04:10")
	c.tick2()
	t.eq(str(c.cv.get("phase", "")), "yard", "04시 마당에 줄")
	t.eq(c.lead().who, FqSb.HOOK, "선두는 갈고리")
	t.eq(c.cv["folk"].size(), 4, "인력 넷")
	t.eq(c.cv["men"].size(), 2, "조원 둘")
	st.vars.set_v("AFF_SB", -25)
	t.ok(_said(_play(st, c, "FQSB02_YARD")).contains("등 맡길"), "AFF −25: 안 쓴다")
	st.vars.set_v("AFF_SB", -10)
	st.vars.set_v("V_WANTED", 40)
	t.ok(_said(_play(st, c, "FQSB02_YARD")).contains("전단"), "수배 40: 안 쓴다")
	st.vars.set_v("V_WANTED", 0)
	t.eq(st.quests.stage("FQ-SB-02"), 0, "아직 안 받음")
	_play(st, c, "FQSB02_YARD", ["호위 서겠다"])
	t.eq(st.quests.stage("FQ-SB-02"), 10, "출발: 단계 10")
	t.eq(str(c.cv["phase"]), "walk", "줄이 걷는다")
	t.eq(_v(st, "FQ_SB02_DAY"), c.now(), "출발 시각 한 값")
	t.ok(c._travel_veto2("") != "", "운송 중엔 빠른 이동을 막는다")
	t.ok(c._wait_veto2() != "", "운송 중엔 기다리기를 막는다")
	t.eq(c.deadline_abs() % 1440, 600, "마감 10:00")


## 줄을 두고 떠나면 그날 줄은 혼자 떠났다(화면 밖) — 다음 날 다시 선다
func test_sb02_yard_leave(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	c.tick2()
	t.ok(not c.cv.is_empty(), "줄이 섰다")
	_at(h, st, "2277. 10. 29.  05:00")
	c.tick2()
	t.ok(c.cv.is_empty(), "05시: 줄은 떠났다")
	t.eq(st.quests.stage("FQ-SB-02"), 0, "받지 않은 채")
	_at(h, st, "2277. 10. 30.  04:05")
	c.tick2()
	t.eq(str(c.cv.get("phase", "")), "yard", "다음 날 04시 다시 선다")


## 조장이 죽었거나 고척으로 옮겼으면 대리 반장 — 같은 장면의 _L 판
func test_sb02_lead_variant(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	st.kill(FqSb.HOOK)
	c.tick2()
	t.eq(_v(st, "FQ_SB02_LEAD"), 1, "갈고리 사망: 대리 반장")
	t.eq(c.sc("FQSB02_YARD"), "FQSB02_YARD_L", "_L 판")
	t.ok(FileAccess.file_exists("res://data/dialogue/FQSB02_YARD_L.json"), "_L 판이 구워졌다")
	var said := _said(_play(st, c, "FQSB02_YARD_L", ["호위 서겠다"]))
	t.ok(not said.contains("갈고리"), "_L 판엔 갈고리 이름이 없다")
	t.eq(c.lead().who, "", "대리 반장은 이름 없는 조원")
	t.eq(st.quests.stage("FQ-SB-02"), 10, "_L 판으로도 출발")
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: FqSb = r2[2]
	st2.vars.set_v("SQ_S09_SOL2", 2)
	c2.tick2()
	t.eq(_v(st2, "FQ_SB02_LEAD"), 1, "SQ-S09 고척 노선: 대리 반장")


## 고가 끝: 오태수가 달아난다 → 돌려보냄(본 사람 SEEN 1, 손해 없음) · 못 본 척(못 찾았다 — 손해 없음) · 숨김(+50 · 보였으면 SB −6)
func test_sb02_taesu(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	var rn := int(c._meta["ramp_n"])
	c._s2("LEG", rn + 1)
	c.cv["i"] = rn + 1
	c._events()
	t.eq(_v(st, "FQ_SB02_TAESU"), 1, "달아남")
	t.eq(st.quests.stage("FQ-SB-02"), 30, "단계 30")
	t.eq(str(c.cv["hold"]), "esc", "줄이 선다")
	t.eq(c._pending2, "FQSB02_ESCAPE", "탈주 장면")
	t.ok(c.cv["taesu"] != null and c.cv["folk"].size() == 3, "아이는 줄 밖")
	c.cv["seen_now"] = 1
	_play(st, c, "FQSB02_TAESU", ["줄로 돌아가자"])
	t.eq(_v(st, "FQ_SB02_TAESU"), 2, "돌려보냄")
	t.eq(c.cv["folk"].size(), 4, "다시 넷")
	t.eq(str(c.cv["hold"]), "report", "갈고리에게 보고")
	t.ok(_said(_play(st, c, "FQSB02_REPORT")).contains("다시 넷"), "보고: 다시 넷")
	t.eq(str(c.cv["hold"]), "", "보고가 끝나면 줄이 다시 간다")
	t.eq(_v(st, "AFF_SB"), -10, "돌려보내면 손해 없음")

	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: FqSb = r2[2]
	_go(st2, c2)
	c2._s2("LEG", rn + 1)
	c2._events()
	c2.cv["seen_now"] = 0
	_play(st2, c2, "FQSB02_TAESU", ["못 본 척"])
	t.eq(_v(st2, "FQ_SB02_TAESU"), 3, "못 본 척")
	t.ok(_said(_play(st2, c2, "FQSB02_REPORT", ["못 찾았다"])).contains("셋이라고"), "못 찾았다: 넷이 셋")
	t.eq(_v(st2, "AFF_SB"), -10, "안 보였으면 손해 없음")
	t.ok(c2.cv["taesu"] == null, "아이는 사라졌다")

	var r3 := _host()
	var st3: StoryState = r3[1]
	var c3: FqSb = r3[2]
	_go(st3, c3)
	c3._s2("LEG", rn + 1)
	c3._events()
	c3._s2("SNEAK", 1)
	c3.cv["seen_now"] = 1
	var k0 := _v(st3, "V_KARMA")
	_play(st3, c3, "FQSB02_TAESU", ["숨겨 줄게"])
	t.eq(_v(st3, "FQ_SB02_TAESU"), 4, "숨김")
	t.eq(_v(st3, "V_KARMA") - k0, 50, "카르마 +50")
	t.eq(_v(st3, "FQ_SB02_SEEN"), 2, "상판에서 보였다")
	t.eq(_v(st3, "AFF_SB"), -16, "보였으면 SB −6")
	_play(st3, c3, "FQSB02_REPORT", ["못 찾았다"])
	t.eq(_v(st3, "AFF_SB"), -16, "벌은 한 번만")


## 아무도 안 찾으면 30분 뒤 조원이 끌고 온다
func test_sb02_escape_timeout(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	c._s2("LEG", int(c._meta["ramp_n"]) + 1)
	c._events()
	_at(h, st, "2277. 10. 29.  04:45")
	c._events()
	t.eq(_v(st, "FQ_SB02_TAESU"), 2, "조원이 끌고 왔다")
	t.eq(str(c.cv["hold"]), "", "줄이 다시 간다")


## 신도림 쉬는 박자: 웅크려서 원격기 슬쩍(REMOTE 1) · 서서 하면 들킴(SB −6) · 두 번은 안 된다
func test_sb02_pocket(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	c._s2("TAESU", 2)
	c._s2("LEG", int(c._meta["sindorim"]) + 1)
	c._events()
	t.eq(_v(st, "FQ_SB02_REST"), 1, "쉬는 박자")
	t.eq(c._pending2, "FQSB02_REST", "쉬는 장면")
	t.ok(c._holding(), "줄이 선다(5분)")
	h.combat.crouch = true
	_play(st, c, "FQSB02_POCKET", ["원격기를 슬쩍"])
	t.eq(_v(st, "FQ_SB02_REMOTE"), 1, "원격기를 가졌다")
	t.ok(_said(_play(st, c, "FQSB02_POCKET")).contains("두 번은"), "두 번은 안 된다")

	var r2 := _host()
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: FqSb = r2[2]
	_go(st2, c2)
	c2._s2("LEG", int(c2._meta["sindorim"]) + 1)
	c2._events()
	h2.combat.crouch = false
	_play(st2, c2, "FQSB02_POCKET", ["원격기를 슬쩍"])
	t.eq(c2._pending2, "FQSB02_POCKET_FAIL", "서서 손대면 들킴")
	_play(st2, c2, "FQSB02_POCKET_FAIL")
	t.eq(_v(st2, "FQ_SB02_REMOTE"), 0, "원격기 없음")
	t.eq(_v(st2, "AFF_SB"), -16, "SB −6")


## 방범대: 말(화술 보통) → 지나감 · 넘김 → RES 3(+100 · SB −10 · 행적) · 원격기로 끄고 넘김 → RES 3 · 조원은 물러난다
func test_sb02_patrol(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	c._s2("TAESU", 2)
	c._s2("REST", 1)
	c._s2("LEG", int(c._meta["patrol"]) - 1)
	c._events()
	t.eq(st.quests.stage("FQ-SB-02"), 40, "단계 40")
	t.eq(str(c.cv["hold"]), "patrol", "줄이 선다")
	t.eq(c._patrol.size(), 3, "방범대 셋")
	t.eq(c._pending2, "FQSB02_PATROL", "방범대 장면")
	_play(st, c, "FQSB02_PATROL", ["길만 지나간다"])
	t.eq(_v(st, "FQ_SB02_PATROL"), 2, "말로 지나감")
	t.eq(str(c.cv["hold"]), "", "줄이 다시 간다")
	t.ok(c._patrol.is_empty(), "방범대는 물러난다")
	c._events()
	t.eq(str(c.cv["hold"]), "", "방범대는 한 번만")

	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: FqSb = r2[2]
	_go(st2, c2)
	c2._s2("TAESU", 2)
	c2._s2("REST", 1)
	c2._s2("LEG", int(c2._meta["patrol"]) - 1)
	c2._events()
	var k0 := _v(st2, "V_KARMA")
	_play(st2, c2, "FQSB02_PATROL", ["방범대에 넘긴다"])
	t.eq(_v(st2, "FQ_SB02_RES"), 3, "넘김: RES 3")
	t.eq(st2.quests.stage("FQ-SB-02"), 100, "끝")
	t.eq(_v(st2, "V_KARMA") - k0, 100, "카르마 +100")
	t.eq(_v(st2, "AFF_SB"), -20, "SB −10")
	t.ok(_has_deed(st2, "FQSB02_FREED"), "행적: 목걸이를 끊었다")
	t.ok(c2.cv["folk"].is_empty(), "인력은 방범대와 간다")
	t.ok(not c2.walking(), "운송 끝")
	t.eq(c2._travel_veto2(""), "", "빠른 이동이 풀린다")

	var r3 := _host()
	var st3: StoryState = r3[1]
	var c3: FqSb = r3[2]
	_go(st3, c3)
	c3._s2("TAESU", 2)
	c3._s2("REST", 1)
	c3._s2("REMOTE", 1)
	c3._s2("LEG", int(c3._meta["patrol"]) - 1)
	c3._events()
	_play(st3, c3, "FQSB02_PATROL", ["원격기로 목걸이를"])
	t.eq(_v(st3, "FQ_SB02_RES"), 3, "원격기로 끄고 넘김: RES 3")
	t.eq(_v(st3, "FQ_SB02_REMOTE"), 2, "원격기는 버려진다(아이템 아님)")
	t.ok(not st3.items.has("REMOTE"), "가방에 남지 않는다")
	t.ok(c3.cv.is_empty(), "조원은 물러났다")


## 인계 지점: 10시 전 — 통행세 60(캡) · 넷 → 일당 150 − 60 · RES 1 · SB +10 · 카르마 −200 · 행적 · AFF_SB 20 넘으면 번호표 목걸이
func test_sb02_hand(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	st.vars.set_v("AFF_SB", 15)
	_go(st, c)
	c._s2("TAESU", 2)
	c._s2("REST", 1)
	c._s2("PATROL", 2)
	c.cv["patrol_done"] = true
	c._s2("LEG", c.points().size())
	c._events()
	t.eq(st.quests.stage("FQ-SB-02"), 50, "인계 지점: 단계 50")
	t.eq(c._pending2, "FQSB02_TOLL", "통행세")
	t.eq(c._hand_people.size(), 3, "인수원 · 경비 둘")
	var caps0 := _v(st, "PC_CAPS")
	var k0 := _v(st, "V_KARMA")
	_play(st, c, "FQSB02_TOLL", ["낸다"])
	t.eq(_v(st, "FQ_SB02_TOLL"), 1, "냈다")
	t.eq(c._pending2, "FQSB02_HAND", "인수원")
	var said := _said(_play(st, c, "FQSB02_HAND"))
	t.ok(said.contains("넷. 다 왔어"), "넷")
	t.eq(_v(st, "FQ_SB02_N"), 4, "인계 넷")
	t.eq(_v(st, "FQ_SB02_RES"), 1, "RES 1")
	t.eq(_v(st, "PC_CAPS") - caps0, 150 - 60, "일당 150 − 통행세 60")
	t.eq(_v(st, "V_KARMA") - k0, -200, "카르마 −200")
	t.eq(_v(st, "AFF_SB"), 25, "SB +10")
	t.ok(st.items.has("M-129"), "번호표 목걸이(우호)")
	t.ok(said.contains("네 번호다"), "목걸이 줄")
	t.ok(_has_deed(st, "FQSB02_HANDED"), "행적: 철교 남단 인계")
	t.eq(st.quests.stage("FQ-SB-02"), 100, "끝")

	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: FqSb = r2[2]
	_go(st2, c2)
	c2._s2("TAESU", 4)
	c2._s2("REST", 1)
	c2._s2("PATROL", 2)
	c2.cv["patrol_done"] = true
	c2.cv["folk"].pop_front()
	c2._s2("LEG", c2.points().size())
	c2._events()
	var caps1 := _v(st2, "PC_CAPS")
	_play(st2, c2, "FQSB02_TOLL", ["갈고리에게"])
	var said2 := _said(_play(st2, c2, "FQSB02_HAND"))
	t.ok(said2.contains("셋. 하나는 고가에서"), "셋 — 고가에서 하나")
	t.eq(_v(st2, "PC_CAPS") - caps1, 70, "갈고리에게 맡기면 통행세 + 품 20을 깐다(70)")
	t.ok(not st2.items.has("M-129"), "우호 아니면 목걸이 없음")


## 10:00을 넘기면 인수원은 돌아갔다 — RES 2(일당 75 · SB +4) · 인력은 본소로
func test_sb02_late(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	c._s2("TAESU", 2)
	c._s2("REST", 1)
	c._s2("PATROL", 2)
	c.cv["patrol_done"] = true
	_at(h, st, "2277. 10. 29.  10:20")
	c._s2("LEG", c.points().size())
	c._events()
	t.eq(_v(st, "FQ_SB02_LATE"), 1, "늦었다")
	t.eq(c._pending2, "FQSB02_HAND", "곧장 인수원 장면(LATE 판)")
	var caps0 := _v(st, "PC_CAPS")
	t.ok(_said(_play(st, c, "FQSB02_HAND")).contains("배가 떠났어"), "출장소 배가 떠났다")
	t.eq(_v(st, "FQ_SB02_RES"), 2, "RES 2")
	t.eq(_v(st, "PC_CAPS") - caps0, 75, "일당 반")
	t.eq(_v(st, "AFF_SB"), -6, "SB +4")


## 빠짐: 실내로 들어가 30분 · 행렬에서 40칸 넘게 10분 → RES 4 · SB −3
func test_sb02_drop_out(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	h.enter("H-04", "from_H-02")
	c.tick2()
	t.ok(c.cv.is_empty(), "맵을 건너면 줄 사람은 지워진다")
	t.eq(_v(st, "FQ_SB02_RES"), 0, "아직 빠짐 아님")
	_at(h, st, "2277. 10. 29.  04:45")
	c.tick2()
	t.eq(_v(st, "FQ_SB02_RES"), 4, "30분: 빠짐")
	t.eq(st.quests.stage("FQ-SB-02"), 100, "끝")
	t.eq(_v(st, "AFF_SB"), -13, "SB −3")

	var r2 := _host()
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: FqSb = r2[2]
	_go(st2, c2)
	h2.enter("X-SB", "gate_in")
	c2.tick2()
	t.ok(not c2.cv.is_empty(), "돌아오면 LEG에서 다시 선다")
	t.eq(_v(st2, "FQ_SB02_RES"), 0, "30분 안이면 이어간다")
	h2.player.loco.logical = c2.lead().loco.logical + Vector2(60 * 32, 0)
	c2._lag_tick()
	_at(h2, st2, "2277. 10. 29.  04:21")
	c2._lag_tick()
	t.eq(_v(st2, "FQ_SB02_RES"), 4, "40칸 넘게 10분: 빠짐")


## 흩어짐: 인솔조를 건드려 무리가 돌아섰다 → RES 5 · 단계 200 · SB −10 · 행적
func test_sb02_scatter(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	c.lead().cmb.team = "enemy_calm_sb02"
	t.ok(c._check_fallen(), "돌아섰다")
	t.eq(_v(st, "FQ_SB02_RES"), 5, "RES 5")
	t.eq(st.quests.stage("FQ-SB-02"), 200, "단계 200")
	t.eq(_v(st, "AFF_SB"), -20, "SB −10")
	t.ok(_has_deed(st, "FQSB02_SCATTER"), "행적")
	t.ok(c.cv["folk"].is_empty(), "인력은 흩어졌다")


## 길 위 무리에 조장이 쓰러지면 생사 장부(P3) · 조원이 대리 반장으로 이어 끈다
func test_sb02_lead_falls(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	var old := c.lead()
	var next: Enemy = c.cv["men"][0]
	old.cmb.dead = true
	t.ok(not c._check_fallen(), "운송은 이어진다")
	t.ok(st.is_dead(FqSb.HOOK), "갈고리 사망 기록")
	t.eq(_v(st, "FQ_SB02_LEAD"), 1, "대리 반장")
	t.ok(c.lead() == next, "조원이 선두")
	t.eq(c.sc("FQSB02_HAND"), "FQSB02_HAND_L", "이후 장면은 _L 판")
	t.ok(FileAccess.file_exists("res://data/dialogue/FQSB02_HAND_L.json"), "인계 _L 판")
	t.eq(_v(st, "FQ_SB02_RES"), 0, "흩어지지 않았다")


## 정찰: 행렬보다 먼저 방범대를 보면 → 갈고리에게 알려 우회 · 방범대 사건 없음
func test_sb02_detour(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	c._s2("TAESU", 2)
	c._s2("REST", 1)
	var main_n := c.points().size()
	c._s2("LEG", int(c._meta["sindorim"]) + 2)
	c.cv["i"] = int(c._meta["sindorim"]) + 2
	var pa: Array = c._meta["patrol_at"]
	h.player.loco.logical = Vector2(int(pa[0]) * 32 + 16, int(pa[1]) * 32 + 16)
	c._events()
	t.eq(_v(st, "FQ_SB02_SCOUT"), 1, "먼저 봤다")
	t.eq(c._patrol.size(), 3, "방범대가 서 있다")
	_play(st, c, "FQSB02_TELL", ["남쪽으로 돌자"])
	t.eq(_v(st, "FQ_SB02_DETOUR"), 1, "우회")
	t.ok(c._patrol.is_empty(), "방범대는 없는 길")
	t.ok(c.points().size() != main_n, "경유점이 우회 길로 바뀐다")
	t.ok(_v(st, "FQ_SB02_LEG") >= int(c._meta["sindorim"]), "신도림 뒤에서 이어간다")
	c._s2("LEG", int(c._meta["patrol"]))
	c._events()
	t.ok(str(c.cv["hold"]) != "patrol", "우회면 방범대 사건 없음")


## 한 번만: 끝난 운송은 다음 날 마당에 다시 서지 않는다
func test_sb02_once(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	c._drop_out()
	t.eq(_v(st, "FQ_SB02_RES"), 4, "빠짐")
	_at(h, st, "2277. 10. 30.  04:10")
	c.tick2()
	t.ok(c.cv.is_empty(), "다시 안 선다")
	t.ok(_said(_play(st, c, "FQSB02_YARD")).contains("호위는 찼어"), "말을 걸어도 '찼어'")


## 교차(1-12f): 출근부 일꾼은 마당 사람 — MQ-105 담 안 감시가 표찰 없다고 습격을 열지 않는다 · 일꾼이 아니면 그대로 연다
func test_sb02_yard_watch(t) -> void:
	for worker in [true, false]:
		var r := _host("2277. 10. 29.  04:10", 100 if worker else 0)
		var h: InteriorHost = r[0]
		var st: StoryState = r[1]
		var p := Act1Paths.new()
		p.setup(h)
		h.enter("X-SB", "gate_in")
		h.player.loco.logical = Vector2((606 + 22) * 32 + 16, (1307 + 32) * 32 + 16)   # 정문 십장(22,33) 곁 — 담 안
		for k in 10:
			p._sb_watch(p._sb_where())
		if worker:
			t.eq(_v(st, "SB_RAID"), 0, "출근부 일꾼: 습격 없음")
		else:
			t.eq(_v(st, "SB_RAID"), 1, "표찰도 일도 없으면: 들켜서 습격")


## 재미 검수 반영(1-12f): 데려온 오태수를 신도림 뒤 원격기로 풀어 줌 → TAESU 4 · FREE · 인계 '하나는 길에서 없어졌어' · 돌려주면 들킴
func test_sb02_free_remote(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	c._s2("LEG", int(c._meta["ramp_n"]) + 1)
	c._events()
	c.cv["seen_now"] = 0
	_play(st, c, "FQSB02_TAESU", ["줄로 돌아가자"])
	_play(st, c, "FQSB02_REPORT")
	t.eq(_v(st, "FQ_SB02_TAESU"), 2, "데려왔다")
	c._s2("REMOTE", 1)
	c._s2("REST", 1)
	c.cv["seen_now"] = 0
	var k0 := _v(st, "V_KARMA")
	_play(st, c, "FQSB02_TAESU", ["원격기로 목걸이를"])
	t.eq(_v(st, "FQ_SB02_TAESU"), 4, "풀어 줌 → 봉천")
	t.eq(_v(st, "FQ_SB02_FREE"), 1, "원격기로")
	t.eq(_v(st, "V_KARMA") - k0, 50, "카르마 +50")
	t.eq(c.cv["folk"].size(), 3, "줄에서 빠짐")
	t.eq(_v(st, "AFF_SB"), -10, "안 보였으면 손해 없음")
	c._s2("PATROL", 2)
	c.cv["patrol_done"] = true
	c._s2("LEG", c.points().size())
	c._events()
	_play(st, c, "FQSB02_TOLL", ["낸다"])
	var said := _said(_play(st, c, "FQSB02_HAND", ["그냥 넘긴다", "돌려준다"]))
	t.ok(said.contains("하나는 길에서 없어졌어"), "인계: 하나는 길에서 없어졌다(갈고리는 원격기가 없다)")
	t.ok(said.contains("단추 하나가 눌린 채"), "돌려주면 눌린 단추로 안다")
	t.eq(_v(st, "FQ_SB02_SEEN"), 2, "돌려주면 들킴")
	t.eq(_v(st, "FQ_SB02_RES"), 1, "운송은 끝까지(셋)")
	t.eq(_v(st, "FQ_SB02_N"), 3, "인계 셋")


## 재미 검수 반영: 인계 지점에서 원격기로 넷을 끔 → RES 6(+100 · SB −10 · 일당 없음 · 행적)
func test_sb02_unhook(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	st.vars.set_v("AFF_SB", 25)
	_go(st, c)
	c._s2("TAESU", 2)
	c._s2("REST", 1)
	c._s2("REMOTE", 1)
	c._s2("PATROL", 2)
	c.cv["patrol_done"] = true
	c._s2("LEG", c.points().size())
	c._events()
	_play(st, c, "FQSB02_TOLL", ["낸다"])
	var caps0 := _v(st, "PC_CAPS")
	var k0 := _v(st, "V_KARMA")
	var said := _said(_play(st, c, "FQSB02_HAND", ["원격기 단추를 모두"]))
	t.ok(said.contains("도착 0"), "인수원: 도착 0")
	t.eq(_v(st, "FQ_SB02_RES"), 6, "RES 6")
	t.eq(_v(st, "FQ_SB02_N"), 0, "넘긴 사람 없음")
	t.eq(_v(st, "V_KARMA") - k0, 100, "카르마 +100")
	t.eq(_v(st, "AFF_SB"), 15, "SB −10")
	t.eq(_v(st, "PC_CAPS"), caps0, "일당 없음")
	t.ok(not st.items.has("M-129"), "목걸이 없음")
	t.ok(_has_deed(st, "FQSB02_UNHOOK"), "행적")
	t.eq(st.quests.stage("FQ-SB-02"), 100, "끝")


## 재미 검수 반영: 일부러 늦춤(찾는 척 60분 · 두 시간 쉬자 — 조는 틈) · 보고 LIE의 '다 보였어' 판(판정은 명령 앞)
func test_sb02_stall(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	c._s2("LEG", int(c._meta["ramp_n"]) + 1)
	c._events()
	c.cv["seen_now"] = 1
	_play(st, c, "FQSB02_TAESU", ["못 본 척"])
	t.eq(_v(st, "FQ_SB02_SEEN"), 1, "보였다")
	var m0 := c.now()
	var said := _said(_play(st, c, "FQSB02_REPORT", ["찾는 척"]))
	t.eq(c.now() - m0, 60, "찾는 척 — 60분")
	t.ok(said.contains("상판 끝에서 다 보였어"), "보였으면 '다 보였어' 판")
	t.eq(_v(st, "AFF_SB"), -16, "SB −6")
	c._s2("LEG", int(c._meta["sindorim"]) + 1)
	c._events()
	var m1 := c.now()
	_play(st, c, "FQSB02_REST", ["두 시간 쉬자"])
	t.eq(c.now() - m1, 120, "쉬자 — 120분(화술 100)")
	t.ok(c._holding(), "쉰 끝에 갈고리가 존다 — 허리춤 틈이 남는다")


## 재미 검수 반영: 앞서 나가 정찰하면 줄이 서지 않는다 · 뒤로 멀어지면 선다
func test_sb02_ahead(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_go(st, c)
	var ld := c.lead()
	var pts := c.points()
	var j := mini(int(c.cv["i"]) + 6, pts.size() - 1)
	var ahead_t: Vector2 = c._px(pts[j][0])
	h.player.loco.logical = ld.loco.logical.move_toward(ahead_t, 20 * 32)
	c._lag_tick()
	t.ok(not bool(c.cv.get("lag", false)), "앞(20칸)이면 서지 않음")
	h.player.loco.logical = ld.loco.logical + (ld.loco.logical - ahead_t).normalized() * 30 * 32
	c._lag_tick()
	t.ok(bool(c.cv.get("lag", false)), "뒤로 30칸이면 선다")


## 1-12f 서사 대조(계획 §6.5 #61~70 · D-296): 출발 때 목걸이를 원격기에 묶음 · 인계 뒤 배로 · 통행세는 경비 개인 뒷돈 ·
## 오태수 자리 한 값(TWHERE) · K-20 숙소 갈고리가 운송 결과를 기억함(맨 위 갈래 · 지시서도 차갑게)
func test_sb02_narrative_fixes(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	st.vars.set_v("AFF_SB", 25)
	c.tick2()
	var y := _said(_play(st, c, "FQSB02_YARD", ["호위 서겠다"]))
	t.ok(y.contains("담에서 떼어 냈다"), "출발: 담 → 원격기")
	c._s2("TAESU", 2)
	c._s2("REST", 1)
	c._s2("REMOTE", 1)
	c._s2("PATROL", 2)
	c.cv["patrol_done"] = true
	c._s2("LEG", c.points().size())
	c._events()
	var toll := _said(_play(st, c, "FQSB02_TOLL", ["낸다"]))
	t.ok(toll.contains("조합장은 모르는 값"), "통행세 = 경비 뒷돈(MQ-201 '몰래'와 같은 사실)")
	var hand := _said(_play(st, c, "FQSB02_HAND", ["그냥 넘긴다", "돌려준다"]))
	t.ok(hand.contains("거룻배") and not hand.contains("침목"), "인계 뒤 배로 섬 남쪽 선착장")
	t.eq(_v(st, "FQ_SB02_RES"), 1, "끝까지")
	t.eq(_v(st, "FQ_SB02_TWHERE"), 1, "오태수 자리: 출장소")
	t.ok(not hand.contains("다음에도 새벽 네 시"), "다시 서지 않는 줄을 약속하지 않는다")
	# 숨겨 준 판 · 늦은 판 · 방범대 판의 자리
	for k in [[4, 1, 3], [2, 2, 2], [2, 3, 4], [3, 1, 5], [2, 6, 5]]:
		var r2 := _host()
		var c2: FqSb = r2[2]
		_go(r2[1], c2)
		c2._s2("TAESU", k[0])
		c2._finish2(k[1])
		t.eq(_v(r2[1], "FQ_SB02_TWHERE"), k[2], "TAESU %d · RES %d → 자리 %d" % k)
	# K-20 숙소: 맨 위 갈래가 운송 결과를 기억한다
	var r3 := _host()
	var st3: StoryState = r3[1]
	var c3: FqSb = r3[2]
	st3.vars.set_v("FQ_SB02_RES", 6)
	t.ok(_said(_play(st3, c3, "SQS09_GALGORI")).contains("기억하고 있어"), "인계 지점에서 끈 판: '기억해 둔다'의 회수")
	st3.vars.set_v("FQ_SB02_RES", 5)
	t.ok(_said(_play(st3, c3, "SQS09_GALGORI")).contains("총 겨눈 호위"), "흩어짐 판")
	st3.vars.set_v("FQ_SB02_RES", 1)
	st3.vars.set_v("FQ_SB02_REMOTE", 2)
	st3.vars.set_v("FQ_SB02_SEEN", 2)
	t.ok(_said(_play(st3, c3, "SQS09_GALGORI")).contains("네 이름 옆에"), "원격기 분실 — 본 판")
	st3.vars.set_v("FQ_SB02_SEEN", 0)
	t.ok(_said(_play(st3, c3, "SQS09_GALGORI")).contains("몇이나 됐을까"), "원격기 분실 — 의심 판")
	st3.vars.set_v("FQ_SB02_RES", 3)
	st3.vars.set_v("SQ_S09_ORDER", 1)
	t.ok(_said(_play(st3, c3, "SQS09_GALGORI", ["지시서"])).contains("따르는 건 서명이지"), "배신 판에도 지시서는 받는다(S09 길이 막히지 않게)")
	var mp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/K-20.json"))
	st3.vars.set_v("GAME_HOUR", 12)
	var n := 0
	for np in mp["npcs"]:
		if str(np["id"]) == "N-R02-041" and StoryExpr.test(str(np.get("cond", "")), st3):
			n += 1
			t.ok(not str(np.get("bark", "")).contains("줄 맞춰"), "배신 판 바크는 차갑게")
	t.eq(n, 1, "K-20 갈고리는 한 명(배타 조건)")
	st3.vars.set_v("FQ_SB02_PATROL", 3)
	st3.vars.set_v("SQ_S09_ORDER", 0)
	t.ok(_said(_play(st3, c3, "SQS09_GALGORI")).contains("방범대에 판 호위"), "그냥 넘긴 판: '기억해 둔다'는 말하지 않은 판이라 다른 줄")
	st3.vars.set_v("FQ_SB02_RES", 1)
	st3.vars.set_v("FQ_SB02_REMOTE", 0)
	st3.vars.set_v("FQ_SB02_TOLL", 2)
	t.ok(_said(_play(st3, c3, "SQS09_GALGORI")).contains("서른에 끝냈다며"), "좋은 기억도 남는다")
	st3.vars.set_v("FQSB02_STAGE", 30)
	n = 0
	for np in mp["npcs"]:
		if str(np["id"]) == "N-R02-041" and StoryExpr.test(str(np.get("cond", "")), st3):
			n += 1
	t.eq(n, 0, "운송 중엔 숙소에 없다(그날 동선 한 곳)")
	# 장부가 사라진 세계: 넷은 출근부 빚(종이 두 장)
	var r4 := _host()
	var st4: StoryState = r4[1]
	st4.vars.set_v("SB_DEBT", 1)
	r4[2].tick2()
	t.ok(_said(_play(st4, r4[2], "FQSB02_YARD", ["오늘은 아니다"])).contains("이 넷은 출근부 빚"), "장부를 태운 판의 출발 줄")
