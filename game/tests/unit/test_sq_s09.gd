## 단계 1-11h SQ-S09 「127번」(SD-04a §5.2): 발동 셋(판자 틈 · 우리 문 · 아내) · 7일 시계(줄 → 트럭) · 해법① A 몸값(구만호 · 흥정 · 황두칠 · 줄 웃돈) ·
## B 우리 열기(02~04시 · 목걸이부터) · C 장부(다음 06시) · D 습격 · 해법② a 지하로 · b 운송로 · c 막기 · d 갈고리 · 벽장 부서짐 · 재회(이름으로 · 돈 · 정착) ·
## 혼자 가기(수색 중 거부) · 우리에서 눈 붙이기 · 죽음(채윤재 · 채해인) · 88번을 그 돈으로.
extends RefCounted

const YJ := "N-R02-039"
const HAEIN := "N-R02-050"
const HOOK := "N-R02-041"


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
	var p := Act1Paths.new()
	p.setup(h)
	var c := SideS09.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c, p]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(h: InteriorHost, st: StoryState, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			var nm := str(cur["name"])
			if h.ev.handlers.has(nm) and not (nm == "s09" and str(cur["args"][0]) in ["go", "reunion", "nap"]):
				h.ev.handlers[nm].call(cur["args"], func() -> void: pass)
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


func _says(st: StoryState, id: String, needle: String, label := "START") -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if str(cur.get("text", "")).contains(needle):
			return true
		if cur["type"] == "choices":
			for o in cur["opts"]:
				if str(o["text"]).contains(needle) and bool(o["enabled"]):
					return true
			cur = dr.choose(0)
		else:
			cur = dr.advance()
	return false


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _pump(h: InteriorHost, n := 60) -> void:
	for i in n:
		h.ev._process(0.25)


## 02시 H-03: 우리 문을 따고 목걸이를 풀어 내보낸다(B)
func _free_b(h: InteriorHost, st: StoryState, c: SideS09) -> void:
	h.date_text = "2277. 10. 27.  02:30"
	h.enter("H-03", "from_yard")
	st.vars.set_v("PC_SKP_LOCKPICK", 30)
	st.vars.set_v("PC_SKP_REPAIR", 60)
	_play(h, st, "SQS09_CAGE10", ["자물쇠 따기"])
	_play(h, st, "SQS09_CAGE10", ["수리 50"], "OPENED")
	c.tick()


func test_sq_s09_crack_start(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-23", "from_K-20")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	t.eq(_play(h, st, "SQS09_CRACK"), [], "판자 틈 원고")
	t.eq(_v(st, "SQ_S09_CRACK"), 1, "속삭임을 들었다")
	t.eq(st.quests.stage("SQ-S09"), 40, "판자 틈은 통로를 이미 앎 — 10 → 40(P2)")
	t.eq(_v(st, "SQ_S09_START"), 4, "발동 날")
	t.eq(_v(st, "SQ_S09_DUE_M"), 11, "트럭 달(10/26 + 6일 = 11/1)")
	t.eq(_v(st, "SQ_S09_DUE_D"), 1, "트럭 날")
	t.ok(_says(st, "SQS09_CRACK", "아직 거기 있어"), "다시 보면 짧은 판")
	t.ok(_says(st, "SQS09_CAGE10", "판자 틈에서 들리던"), "우리 문에서 알아본다")


func test_sq_s09_wife_first(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-22", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var cap0 := _v(st, "PC_CAPS")
	t.eq(_play(h, st, "SQS09_HAEIN", ["채윤재", "돈을 받는다"]), [], "채해인 원고")
	t.eq(st.quests.stage("SQ-S09"), 30, "아내 먼저 — 10 → 20 → 30(빚 400)")
	t.eq(_v(st, "PC_CAPS") - cap0, 400, "아내의 400")
	t.eq(_v(st, "SQ_S09_TOOK"), 1, "받았다")
	t.eq(_v(st, "SB_127"), 1, "아내가 부탁함")
	t.ok(_says(st, "SQS09_HAEIN", "11월 1일까지"), "남은 날 — 절대 날짜")
	st.vars.set_v("GAME_DAY", 7)
	t.ok(_says(st, "SQS09_HAEIN", "숫자를 지우고"), "사흘째 판")
	st.vars.set_v("GAME_DAY", 9)
	t.ok(_says(st, "SQS09_GALGORI", "1일 새벽 트럭"), "갈고리 바크 판(5일째부터)")


func test_sq_s09_cage_b(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "H-03", "from_yard")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	_play(h, st, "SQS09_CAGE10", ["기다려"])
	t.eq(st.quests.stage("SQ-S09"), 10, "우리 문 대화로 발동")
	h.date_text = "2277. 10. 27.  02:30"
	st.vars.set_v("PC_SKP_LOCKPICK", 30)
	_play(h, st, "SQS09_CAGE10", ["자물쇠 따기"])
	t.eq(_v(st, "SQ_S09_DOOR"), 1, "문만 열림")
	t.eq(_v(st, "SB_127"), 0, "목걸이 — 칸에 남는다(확률 죽음 없음)")
	t.eq(_v(st, "SB_RAID"), 0, "교대 시간 — 들키지 않음")
	t.ok(_says(st, "SQS09_CAGE10", "목걸이부터"), "열린 문 판")
	st.vars.set_v("PC_SKP_REPAIR", 60)
	var k0 := _v(st, "V_KARMA")
	_play(h, st, "SQS09_CAGE10", ["수리 50"])
	c.tick()
	t.eq(_v(st, "SQ_S09_UNCOL"), 1, "목걸이 풀림")
	t.eq(_v(st, "SB_127"), 2, "판자 틈으로 — 길금순 칸")
	t.eq(_v(st, "SQ_S09_SOL1"), 2, "해법 B")
	t.eq(_v(st, "V_KARMA") - k0, 100, "+100")
	t.eq(_v(st, "PD_R02_SB"), -3, "판도 새벽 −3")
	t.eq(st.quests.stage("SQ-S09"), 50, "50")
	t.ok(st.boxes.has("sbcage:10"), "127번 칸이 열림(본소 쪽 사실)")


func test_sq_s09_cage_daylight_raid(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "H-03", "from_yard")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	st.vars.set_v("PC_SKP_LOCKPICK", 30)
	_play(h, st, "SQS09_CAGE10", ["자물쇠 따기"])
	c.tick()
	t.eq(_v(st, "SB_RAID"), 1, "낮에 열면 감시 의자 경비 — 습격")
	t.eq(_v(st, "SB_127"), 2, "습격 소동에 목걸이를 따고 나간다")
	t.eq(_v(st, "SQ_S09_SOL1"), 2, "한 칸 열다 들킨 소동은 D가 아니다(우리를 다 열어야 D)")
	t.eq(_v(st, "SQS_S09"), 0, "MQ-504 선해방 표지 없음")


func test_sq_s09_ransom_a(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "H-04", "from_H-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	st.vars.set_v("SQ_S09_START", 4)
	st.quests.set_stage("SQ-S09", 10)
	st.vars.set_v("PC_CAPS", 1000)
	st.vars.set_v("PC_SKP_BARTER", 60)
	t.eq(_play(h, st, "SQS09_GU", ["127번", "물물교환", "320"]), [], "구만호 원고")
	t.eq(_v(st, "PC_CAPS"), 680, "흥정 −20%(320)")
	t.eq(_v(st, "SB_127"), 3, "정문 앞")
	t.eq(_v(st, "SQ_S09_SOL1"), 1, "해법 A")
	t.ok(st.boxes.has("sb127"), "우리에서 빠짐(본소 사실)")
	# 황두칠 매입도 A
	var r2 := _host("2277. 10. 26.  10:00", "H-04", "from_H-02")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	st2.vars.set_v("PC_CAPS", 1000)
	h2.ev.handlers["s09"].call(["buy_hdc"], func() -> void: pass)
	t.eq(_v(st2, "SQ_S09_SOL1"), 1, "황두칠 매입 = A")


func test_sq_s09_ledger_c(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-20", "from_W")
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	st.vars.set_v("SQ_S09_START", 4)
	st.vars.set_v("HO_LEDGER", 81)  # MQ-105가 실제로 쓰는 값(80번대 — 장부 가져옴)
	t.eq(_v(st, "SB_127"), 0, "장부를 넘긴 날은 아직 우리")
	c._on_day(5)
	t.eq(_v(st, "SB_127"), 3, "다음 06시 석방 명단 — 정문 앞")
	t.eq(_v(st, "SQ_S09_SOL1"), 3, "해법 C")


func test_sq_s09_clock_line_and_sold(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-20", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	h.ev.handlers["s09"].call(["meet"], func() -> void: pass)
	st.vars.set_v("GAME_DAY", 10)
	h.date_text = "2277. 11. 01.  04:30"
	h.enter("H-03", "from_yard")
	c.tick()
	t.eq(_v(st, "SB_127"), 0, "H-03에서 보고 있으면 미룬다(P4)")
	h.enter("K-20", "from_W")
	c.tick()
	t.eq(_v(st, "SB_127"), 5, "7일째 04시 — 인력시장 줄")
	t.ok(_says(st, "SQS09_YJ", "트럭이 여섯 시래"), "줄의 채윤재")
	st.vars.set_v("PC_CAPS", 600)
	_play(h, st, "SQS09_YJ", ["웃돈"])
	t.eq(_v(st, "SB_127"), 3, "웃돈 — 정문 앞")
	t.eq(_v(st, "PC_CAPS"), 100, "500캡")
	# 트럭이 떠나면 팔림
	var r2 := _host("2277. 10. 26.  10:00", "K-20", "from_W")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: SideS09 = r2[2]
	h2.ev.handlers["s09"].call(["meet"], func() -> void: pass)
	st2.vars.set_v("GAME_DAY", 10)
	h2.date_text = "2277. 11. 01.  06:10"
	c2.tick()
	t.eq(_v(st2, "SB_127"), 8, "06시 — 현장으로 팔림")
	t.eq(st2.quests.stage("SQ-S09"), 100, "다른 결과로 닫힘")
	t.eq(_v(st2, "SQR_S09"), 9, "SQR 9")
	t.ok(_says(st2, "SQS09_HAEIN", "현장으로 감"), "채해인 판자")


func test_sq_s09_reunion(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-22", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	_play(h, st, "SQS09_HAEIN", ["채윤재", "돈을 받는다"])
	_free_b(h, st, c)
	t.eq(_v(st, "SB_127"), 2, "길금순 칸")
	h.enter("K-20", "from_W")
	h.ev.handlers["s09"].call(["go"], func() -> void: pass)
	_pump(h, 80)
	t.eq(h.map.id, "K-22", "같이 가자 — 화면 전환 뒤 구로 107동")
	t.eq(_v(st, "SB_127"), 4, "구로 집")
	t.ok(_says(st, "SQS09_REUNION", "목에 동그라미가 없는 아빠"), "이름을 부르면 아이가 그림을 뒤집는다")
	st.vars.set_v("MQ101_STAGE", 100)
	st.vars.set_v("PC_CAPS", 900)
	t.eq(_play(h, st, "SQS09_REUNION", ["127번", "채윤재", "봉천", "돌려준다"]), [], "재회 원고")
	t.eq(_v(st, "PC_CAPS"), 500, "아내의 400을 돌려줬다")
	t.eq(_v(st, "SQ_S09_PLACE"), 2, "봉천")
	t.eq(st.quests.stage("SQ-S09"), 100, "100")
	t.eq(int(st.items.get("M-184", 0)), 1, "근속 15년 명패")
	c._on_day(6)
	t.eq(_v(st, "SB_127"), 6, "다음 날 봉천")
	t.ok(_says(st, "SQS09_YJ", "봉천 계단 냄새"), "고향")


func test_sq_s09_passage(t) -> void:
	# B 뒤 다음 06시 갈고리가 눈치챔 → 혼자 가기 거부 → 운송로(b)
	var r := _host("2277. 10. 26.  10:00", "K-20", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	h.ev.handlers["s09"].call(["meet"], func() -> void: pass)
	_free_b(h, st, c)
	c._on_day(5)
	t.ok(_v(st, "SQ_S09_NOTICE") > 0, "갈고리가 눈치챔")
	t.ok(_says(st, "SQS09_YJ", "할매 칸에서 기다릴게"), "수색 중엔 혼자 가기를 거부")
	t.ok(_says(st, "SQS09_GEUM", "사흘이면"), "길금순 경고")
	st.vars.set_v("PC_CAPS", 300)
	h.enter("H-02", "from_X-SB")
	_play(h, st, "SQS09_PEN", ["캡 100"])
	t.eq(_v(st, "SQ_S09_ORDER"), 2, "빨간펜 지시서")
	_play(h, st, "SQS09_GALGORI", ["지시서"])
	t.eq(_v(st, "SQ_S09_SOL2"), 2, "해법 b")
	t.eq(st.quests.stage("SQ-S09"), 60, "60")
	h.enter("K-20", "from_W")
	var hook := false
	for n in h.npcs:
		if str(n["id"]) == HOOK:
			hook = true
	t.ok(not hook, "인솔조가 가리봉을 비웠다(영구)")
	# 사흘 방치 → 벽장 부서짐
	var r2 := _host("2277. 10. 26.  10:00", "K-20", "from_W")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: SideS09 = r2[2]
	_free_b(h2, st2, c2)
	c2._on_day(5)
	st2.vars.set_v("GAME_DAY", 8)
	c2._on_day(8)
	t.eq(_v(st2, "SQ_S09_CLOSED"), 1, "사흘 — 벽장 부서짐")
	t.ok(_says(st2, "SQS09_GEUM", "마흔한 번째가 마지막"), "길금순")
	# 갈고리를 먼저 죽였으면 눈치챌 사람이 없다
	var r3 := _host("2277. 10. 26.  10:00", "K-20", "from_W")
	var h3: InteriorHost = r3[0]
	var st3: StoryState = r3[1]
	var c3: SideS09 = r3[2]
	st3.kill(HOOK)
	_free_b(h3, st3, c3)
	c3.tick()
	t.eq(_v(st3, "SQ_S09_SOL2"), 4, "갈고리 먼저 — 60이 저절로")


func test_sq_s09_passage_a_c(t) -> void:
	# a 지하로 잇기
	var r := _host("2277. 10. 26.  10:00", "K-23", "from_K-20")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	for kv in [["SQ_S09_START", 4], ["SQ_S09_REQ", 1], ["PC_SKP_REPAIR", 60], ["MQ103_NEST", 1]]:
		st.vars.set_v(kv[0], kv[1])
	st.quests.set_stage("SQ-S09", 50)
	st.items["M-010"] = 6
	t.eq(_play(h, st, "SQS09_BREACH", ["수리 50"]), [], "무너진 벽 원고")
	t.eq(_v(st, "SQ_S09_SOL2"), 1, "해법 a")
	t.eq(int(st.items.get("M-010", 0)), 0, "고철 여섯 장")
	h.ev.handlers["s09"].call(["down"], func() -> void: pass)
	t.eq(h.map.id, "J-09", "구멍 아래 지하시장 남쪽 통로")
	t.ok(_says(st, "SQS09_UP", "올라간다"), "남쪽 통로에서 다시 올라감")
	# c 막고 넘기기 — 명단은 길금순
	var r2 := _host("2277. 10. 26.  10:00", "K-23", "from_K-20")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	for kv in [["SQ_S09_START", 4], ["SQ_S09_REQ", 1], ["PC_ST", 8]]:
		st2.vars.set_v(kv[0], kv[1])
	t.ok(_says(st2, "SQS09_PROP", "길금순 할매만 안다"), "명단 먼저")
	st2.vars.set_v("SQ_S09_LIST", 1)
	st2.items["W-060"] = 1
	_play(h2, st2, "SQS09_PROP", ["파편 수류탄"])
	t.eq(_v(st2, "SQ_S09_SOL2"), 3, "해법 c")
	h2.enter("K-23", "from_K-20")
	t.ok(h2.map.is_solid(Vector2i(27, 3)), "흙더미가 길을 막는다")
	_play(h2, st2, "SQS09_JO", ["마흔 명"])
	t.eq(_v(st2, "SQ_S09_LISTGIVEN"), 1, "조만석 명부")


func test_sq_s09_deaths_and_odd(t) -> void:
	# 채윤재 사망 → 닫힘
	var r := _host("2277. 10. 26.  10:00", "K-20", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	h.ev.handlers["s09"].call(["meet"], func() -> void: pass)
	st.kill(YJ)
	c.tick()
	t.eq(st.quests.stage("SQ-S09"), 100, "채윤재가 죽으면 닫힘")
	t.eq(_v(st, "SQR_S09"), 8, "SQR 8")
	t.ok(_says(st, "SQS09_HAEIN", "이제 나밖에"), "채해인 슬픔 판")
	t.ok(_says(st, "SQS09_CAGE10", "사람 모양 자국"), "빈 칸")
	# 채해인 사망 → 재회 대신 혼자
	var r2 := _host("2277. 10. 26.  10:00", "K-22", "from_W")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	st2.vars.set_v("SB_127", 4)
	st2.vars.set_v("SQ_S09_START", 4)
	st2.quests.set_stage("SQ-S09", 50)
	st2.kill(HAEIN)
	_play(h2, st2, "SQS09_REUNION")
	t.eq(_v(st2, "SQ_S09_PLACE"), 9, "이름을 불러 줄 사람이 없다")
	t.eq(st2.quests.stage("SQ-S09"), 100, "닫힘")
	# 아내의 400으로 88번을 샀다
	var r3 := _host("2277. 10. 26.  10:00", "K-22", "from_W")
	var st3: StoryState = r3[1]
	for kv in [["SQ_S09_WIFE", 1], ["SQ_S09_TOOK", 1], ["SB_BOUGHT", 1], ["SQ_S09_START", 4], ["SB_127", 1]]:
		st3.vars.set_v(kv[0], kv[1])
	t.ok(not _says(st3, "SQS09_HAEIN", "다른 사람을 샀다면서요"), "돈을 받기 전에 산 88번은 탓하지 않는다")
	st3.vars.set_v("SQ_S09_SPENT88", 1)
	t.ok(_says(st3, "SQS09_HAEIN", "노들 가는 길에"), "그 돈으로 88번 — 소문 출처")
	_play(r3[0], st3, "SQS09_HAEIN")
	t.ok(not _says(st3, "SQS09_HAEIN", "다른 사람을 샀다면서요"), "한 번만")
	# 6일째 정문
	st3.vars.set_v("SQ_S09_TOOK", 0)
	st3.vars.set_v("SB_BOUGHT", 0)
	st3.vars.set_v("GAME_DAY", 9)
	t.ok(_says(st3, "SQS09_HAEIN", "이름은 채윤재고요"), "6일째 본소 정문")
	# 혼자 가기(수색 없음) → 다음 06시 구로
	var r4 := _host("2277. 10. 26.  10:00", "K-20", "from_W")
	var h4: InteriorHost = r4[0]
	var st4: StoryState = r4[1]
	var c4: SideS09 = r4[2]
	for kv in [["SQ_S09_START", 4], ["SB_127", 3], ["SQ_S09_SOL1", 1]]:
		st4.vars.set_v(kv[0], kv[1])
	_play(h4, st4, "SQS09_YJ", ["혼자"])
	c4._on_day(5)
	t.eq(_v(st4, "SB_127"), 4, "혼자 구로에 닿음")
	# 우리에서 눈 붙이기
	var r5 := _host("2277. 10. 26.  21:00", "H-03", "from_yard")
	var h5: InteriorHost = r5[0]
	h5.ev.handlers["s09"].call(["nap"], func() -> void: pass)
	_pump(h5, 80)
	t.eq(Clock.hour(h5.date_text), 2, "새벽 두 시")


func test_sq_s09_fun_fixes(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-22", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS09 = r[2]
	_play(h, st, "SQS09_HAEIN", ["채윤재", "돈을 받는다"])
	# 줄에 선 사람은 '나온 사람'이 아니다
	st.vars.set_v("SB_127", 5)
	t.ok(_says(st, "SQS09_HAEIN", "정문 앞 줄에 섰대요"), "줄 판")
	st.vars.set_v("SB_127", 1)
	st.vars.set_v("GAME_DAY", 10)
	t.ok(_says(st, "SQS09_HAEIN", "오늘 새벽이에요"), "7일째 새벽")
	# 재회 무대: 채윤재는 정착 전엔 방 안에 없다
	st.vars.set_v("GAME_DAY", 4)
	st.vars.set_v("SB_127", 4)
	h.enter("K-22", "from_W")
	var inside := false
	for n in h.npcs:
		if str(n["id"]) == "N-R02-039" and is_instance_valid(n["actor"]) and n["actor"].visible:
			inside = true
	t.ok(not inside, "재회 전엔 방 안에 채윤재가 없다(판자 앞에 선다)")
	c._reunion()                                                        # 맵에 들어설 때 지연 호출로 부른다(시험은 메인 루프가 없어 직접)
	t.ok(h.ev.actors.has("S9YJ"), "판자 앞 무대 배우")
	t.ok(h.box.active, "재회 장면이 열렸다")
	t.ok(_says(st, "SQS09_REUNION", "윤재 씨"), "채해인의 첫마디")
	t.ok(_says(st, "SQS09_REUNION", "목 가벼워"), "아이 한 줄")
	st.vars.set_v("SQ_S09_WAITED", 1)
	t.ok(_says(st, "SQS09_REUNION", "밤새 여기서 기다렸어"), "혼자 와서 기다린 판")
	# 연습은 판정 없이 익힌다 → 생포 목걸이 [수리 25]
	var r2 := _host("2277. 10. 26.  10:00", "H-05", "from_H-02")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	_play(h2, st2, "H-05_PRACTICE", ["눈으로 익힌다"])
	t.eq(_v(st2, "SQ_S09_LEARN"), 1, "판정 없이 익힘")
	st2.vars.set_v("SB_COLLAR", 1)
	st2.vars.set_v("PC_SKP_REPAIR", 30)
	_play(h2, st2, "CAPTURE_COLLAR", ["세 번째 선부터"])
	t.eq(_v(st2, "SB_COLLAR"), 0, "익힌 대로 [수리 25]")
	# 단골 국 · 칠판 석방 명단
	st.vars.set_v("SQ_S09_PLACE", 1)
	st.vars.set_v("SQ_S09_START", 4)
	t.ok(_says(st, "SQS09_GEUM", "국 한 그릇"), "길금순 단골")
	st.vars.set_v("SQ_S09_SOL1", 3)
	t.ok(_says(st, "SQS09_BOARD", "석방 명단"), "칠판 — 장부로 풀려남")
	# 우리를 다 열면 D
	var r3 := _host("2277. 10. 26.  10:00", "H-03", "from_yard")
	var st3: StoryState = r3[1]
	var c3: SideS09 = r3[2]
	st3.vars.set_v("SB_127", 2)
	st3.boxes["sbfreed6"] = {"open": true}
	c3.tick()
	t.eq(_v(st3, "SQ_S09_SOL1"), 4, "여섯을 다 열면 D")
	t.eq(_v(st3, "SQS_S09"), 1, "MQ-504 선해방")
