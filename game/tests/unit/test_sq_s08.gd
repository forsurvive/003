## 단계 1-11g SQ-S08 「같은 명찰의 두 사람」(SD-04a §5.1): 발동(광장 다툼 · 명부 · 서류함) · 명부(함준호의 '안 보는 사이' · 사망자 칸) ·
## 창구 네 방법(줄 · 화술 · 출입 카드 · 서류함 원본) + 이름으로 · 번호표 대기(한 시간) · 해골 번호표 대리 민원 · 사진 맞히기 · 근무 수첩 · 수습(C) ·
## 둘 다(B · 노복희) · 그대로 두기(D 시계 7일) · 하나 남은 김민수 · 죽음(창구 · 한쪽 · 둘 다) · 출입 카드 · 봉 수리 주 1회.
extends RefCounted

const A := "N-R02-015"
const B := "N-R02-016"
const WI := "N-R02-023"


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
	var c := SideS08.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 원고를 끝까지(또는 picks 차례로 고르며): s08 명령은 진행기로(대기 · 수습 · 수첩 장면 잇기는 시험이 따로 부른다)
func _play(st: StoryState, c: SideS08, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s08" and str(cur["args"][0]) not in ["wait", "carry", "note"]:
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


func _says(st: StoryState, c: SideS08, id: String, needle: String, picks: Array = [], label := "START") -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if str(cur.get("text", "")).contains(needle):
			return true
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s08" and str(cur["args"][0]) not in ["wait", "carry", "note"]:
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


## 맵 소품이 그 상태 그림인가
func _state_is(m: InteriorMap, cell: Vector2i, state: String) -> bool:
	for p in m.props:
		if cell.x >= p["x"] and cell.x < p["x"] + p["w"] and cell.y >= p["y"] and cell.y < p["y"] + p["h"] and p.has("node"):
			var e: Dictionary = m.prop_meta[p["name"]]
			if e.get("states", {}).has(state):
				return (p["node"].texture as AtlasTexture).region == m._r(e["states"][state])
	return false


func _pump(h: InteriorHost, n := 60) -> void:
	for i in n:
		h.ev._process(0.25)


## 명부까지(함준호 허락 → 두 항목 열람): 단말이 세우는 사실을 그대로
func _ledger(h: InteriorHost, st: StoryState, c: SideS08) -> void:
	_play(st, c, "SQS08_HAM")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/terminals.json"))["terms"]["TM-J04"]
	for e in d["entries"]:
		if str(e.get("set", "")) != "":
			StoryExpr.run(str(e["set"]), st)
	c.tick()


## 창구를 화술로 넘겨 사진 대조까지
func _desk_talk(h: InteriorHost, st: StoryState, c: SideS08) -> void:
	st.vars.set_v("PC_SKP_SPEECH", 90)
	_play(st, c, "SQS08_DESK", ["급한 민원"])


func test_sq_s08_quarrel_trigger(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "J-03", "from_J-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	t.eq(_v(st, "SQ_S08_SEEN_B"), 1, "광장 첫 방문 셈")
	h.player.loco.place(h.map.mark_pos("quarrel"))
	c.tick()
	t.eq(_v(st, "SQ_S08_SAW"), 0, "첫 방문엔 다툼이 없다('첫 방문 이후')")
	h.enter("J-02", "from_J-03")
	h.enter("J-03", "from_J-02")
	t.eq(_v(st, "SQ_S08_SEEN_B"), 2, "두 번째 방문")
	h.player.loco.place(h.map.mark_pos("quarrel"))
	c.tick()
	t.eq(_v(st, "SQ_S08_SAW"), 1, "두 번째 방문에 다툼 장면")
	t.ok(h.box.active, "다툼 대화가 열렸다")
	t.eq(_play(st, c, "SQS08_QUARREL"), [], "다툼 원고 오류 없음")
	t.eq(st.quests.stage("SQ-S08"), 10, "다툼을 보면 10")
	st.vars.set_v("GAME_HOUR", 18)
	t.ok(_says(st, c, "SQS08_QUARREL", "걸레"), "저녁 판은 셔터 걸레")
	st.kill("N-R02-009")
	t.ok(_says(st, c, "SQS08_QUARREL", "혼자 깜박인다"), "함준호가 죽으면 문간 대사 대신 빈 관리사무소")


func test_sq_s08_quarrel_needs_both(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "J-03", "from_J-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	st.kill(A)
	h.enter("J-02", "from_J-03")
	h.enter("J-03", "from_J-02")
	h.player.loco.place(h.map.mark_pos("quarrel"))
	c.tick()
	t.eq(_v(st, "SQ_S08_SAW"), 0, "한쪽이 죽었으면 다툼은 열리지 않는다")


func test_sq_s08_ledger_catches_up(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "J-04", "from_J-03")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	t.eq(st.quests.stage("SQ-S08"), 0, "아직 모름")
	_ledger(h, st, c)
	t.ok(bool(h.term_state("TM-J04").get("unlocked", false)), "함준호가 '안 보는 사이' — 단말이 열린다")
	t.eq(st.quests.stage("SQ-S08"), 30, "다툼을 안 봤어도 명부 · 사망자 칸이 따라 올린다(P2)")
	t.ok(_says(st, c, "SQS08_HAM", "야간조", ["경비원"]), "사망자 칸을 보면 함준호의 경비원 판")


func test_sq_s08_desk_ways(t) -> void:
	# 화술
	var r := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	t.eq(st.quests.stage("SQ-S08"), 0, "아무것도 모르고 구청에 오면 발동하지 않는다")
	t.ok(_says(st, c, "SQS08_DESK", "줄을 비켜"), "민원 없는 낯선 이는 돌려보낸다")
	st.vars.set_v("SQ_S08_SAW", 1)
	h.enter("K-15", "from_W")
	t.eq(st.quests.stage("SQ-S08"), 10, "다툼을 봤으면 구청에서 발동")
	_desk_talk(h, st, c)
	t.eq(_v(st, "SQ_S08_DESK"), 2, "화술 창구")
	t.eq(_v(st, "SQ_S08_MATCH"), 1, "사진 대조")
	t.eq(st.quests.stage("SQ-S08"), 50, "창구 → 40 → 50")
	t.ok(_v(st, "SQ_S08_FOUND_DAY") > 0, "기록을 찾은 날부터 D 시계")
	t.ok(_says(st, c, "SQS08_DESK", "사본은 드렸습니다"), "다시 오면 처리 끝")
	# 출입 카드
	var r2 := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var st2: StoryState = r2[1]
	var c2: SideS08 = r2[2]
	st2.vars.set_v("SQ_S08_SAW", 1)
	t.ok(not ("(관공서 출입 카드를 보인다)" in _opts(st2, "SQS08_DESK", "MENU")), "카드가 없으면 줄이 없다")
	st2.items["M-073"] = 1
	t.eq(_play(st2, c2, "SQS08_DESK", ["출입 카드"]), [], "카드 원고")
	t.eq(_v(st2, "SQ_S08_DESK"), 3, "카드 창구")
	t.eq(_v(st2, "SQ_S08_GRADE"), 1, "카드면 등급까지")
	# 이름으로(B 공구함 '봉' 각인을 본 뒤)
	var r3 := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var st3: StoryState = r3[1]
	var c3: SideS08 = r3[2]
	st3.vars.set_v("SQ_S08_SAW", 1)
	_play(st3, c3, "SQS08_SIGN")
	t.eq(_v(st3, "SQ_S08_TOOL"), 1, "간판 공구함의 '봉'")
	_play(st3, c3, "SQS08_DESK", ["주소로 찾아"])
	t.eq(_v(st3, "SQ_S08_DESK"), 5, "이름으로 찾기")


func test_sq_s08_ticket_wait(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	st.vars.set_v("SQ_S08_SAW", 1)
	t.ok(_says(st, c, "SQS08_WAIT", "규정에 없다"), "번호표 없이 앉으면")
	_play(st, c, "SQS08_NUM")
	t.eq(_v(st, "SQ_S08_TICKET"), 1, "번호표 0413")
	var m0 := Clock.abs_min(h.date_text)
	c._cmd(["wait"], func() -> void: pass)
	_pump(h)
	t.eq(Clock.abs_min(h.date_text) - m0, 60, "한 시간 기다림")
	t.eq(_v(st, "SQ_S08_WAIT"), SideS08.TICKET_MINE, "전광판이 내 번호까지")
	t.ok(h.box.active, "위동현이 번호를 부른다(CALLED_IN)")
	t.ok(_says(st, c, "SQS08_DESK", "0001번", [], "CALLED_IN"), "위동현의 번호표 0001")
	_play(st, c, "SQS08_DESK", ["2077년 주민 기록"], "CALLED_IN")
	t.eq(_v(st, "SQ_S08_DESK"), 1, "줄로 기다린 창구")
	t.ok(_says(st, c, "SQS08_BOARD", "내 번호"), "전광판 0413")


func test_sq_s08_drawer_and_guess(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	var k0 := int(st.vars.get_v("V_KARMA"))
	var b: Variant = h.map.boxes.get(SideS08.DRAWER)
	t.ok(b != null, "창구 뒤 서류함")
	h.box_contents(b)["opened"] = 1
	c.tick()
	t.eq(_v(st, "SQ_S08_DESK"), 4, "서류함 원본")
	t.eq(int(st.vars.get_v("V_KARMA")) - k0, -5, "산 공무원의 서류함 −5")
	t.eq(st.quests.stage("SQ-S08"), 40, "서류함만으로 창구 단계")
	t.eq(_v(st, "SQ_S08_MATCH"), 0, "원본은 직접 맞춰 봐야")
	t.eq(_play(st, c, "SQS08_A", ["증명사진", "사진 ②"]), [], "A에게 틀린 얼굴")
	t.eq(_v(st, "SQ_S08_TOLD_A"), 0, "틀리면 그대로")
	_play(st, c, "SQS08_A", ["증명사진", "사진 ①"])
	t.eq(_v(st, "SQ_S08_MATCH"), 1, "맞히면 대조")
	t.eq(_v(st, "SQ_S08_TOLD_A"), 1, "하경수")
	t.eq(st.quests.stage("SQ-S08"), 50, "대조 → 50")
	t.eq(_v(st, "SQ_S08_SOL"), 0, "B가 남았다")
	st.vars.set_v("PC_SKP_SPEECH", 90)
	_play(st, c, "SQS08_B", ["증명사진", "사진 ②", "줄은 끝났어"])
	t.eq(_v(st, "SQ_S08_TOLD_B"), 1, "봉재민")
	t.eq(_v(st, "SQ_S08_SOL"), 1, "해법 A 이름 돌려주기")
	t.eq(st.quests.stage("SQ-S08"), 100, "끝")


func test_sq_s08_proxy(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	st.vars.set_v("SQ_S08_SAW", 1)
	_play(st, c, "SQS08_SKEL", ["빼낸다"])
	t.eq(_v(st, "SQ_S08_PROXY"), 1, "해골의 번호표 0411")
	var k0 := int(st.vars.get_v("V_KARMA"))
	t.ok(_says(st, c, "SQS08_DESK", "오순례", ["0411"]), "위동현이 이름을 소리 내어 읽는다")
	_play(st, c, "SQS08_DESK", ["0411"])
	t.eq(_v(st, "SQ_S08_PROXY"), 2, "대리 민원")
	t.eq(int(st.vars.get_v("V_KARMA")) - k0, 5, "+5")
	t.eq(_v(st, "SQ_S08_DESK"), 0, "대리 민원은 기록을 주지 않는다(위임장)")
	t.ok(_says(st, c, "SQS08_SKEL", "오순례"), "해골 판이 바뀐다")


func test_sq_s08_notebook_and_carry(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "J-04", "from_J-03")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	_ledger(h, st, c)
	h.enter("J-09", "from_J-03")
	var g := 0
	for e in h.combat.enemies:
		if is_instance_valid(e) and e.has_meta("s08g"):
			g += 1
	t.eq(g, 4, "초소에 구울 넷(30 뒤 · 수첩 전)")
	t.eq(_v(st, "SQ_S08_GHOULS"), 1, "구울 깨어남")
	_play(st, c, "SQS08_GUARD")
	t.eq(_v(st, "SQ_S08_NOTEBOOK"), 1, "근무 수첩")
	t.eq(_v(st, "SQ_S08_FOUND_DAY"), 0, "다툼 전 수첩은 D 시계를 켜지 않는다")
	c._cmd(["saw"], func() -> void: pass)
	t.ok(_v(st, "SQ_S08_FOUND_DAY") > 0, "다툼을 보면 수첩 기록부터 D 시계")
	h.enter("J-03", "from_J-09")
	h.enter("J-09", "from_J-03")
	var g2 := 0
	for e in h.combat.enemies:
		if is_instance_valid(e) and e.has_meta("s08g"):
			g2 += 1
	t.eq(g2, 0, "수첩 뒤엔 다시 나오지 않는다")
	t.ok("진짜 김민수의 근무 수첩을 보여 준다" in _opts(st, "SQS08_A"), "A에게 수첩")
	t.eq(_play(st, c, "SQS08_NOTEBOOK", ["같이 가자"]), [], "수첩 장면 원고")
	h.enter("J-03", "from_J-09")
	c._cmd(["carry"], func() -> void: pass)
	_pump(h, 80)
	t.eq(_v(st, "SQ_S08_SOL"), 3, "해법 C 진짜 김민수")
	t.ok(_state_is(h.map, Vector2i(24, 1), "named"), "김민수 셔터")
	t.ok(_state_is(h.map, Vector2i(36, 4), "bong"), "봉 수리 간판")
	t.ok(_says(st, c, "SQS08_SHUTTER", "국화"), "셔터 아래 국화")
	t.ok(_says(st, c, "SQS08_NOTEBOOK", "국화 옆"), "수첩 장면은 다시 열리지 않는다")
	# 한 사람만 남았을 때의 수첩
	var r2 := _host("2277. 10. 26.  10:00", "J-03", "from_J-02")
	var st2: StoryState = r2[1]
	var c2: SideS08 = r2[2]
	st2.vars.set_v("SQ_S08_NOTEBOOK", 1)
	st2.kill(B)
	t.ok(_says(st2, c2, "SQS08_NOTEBOOK", "혼자라도"), "수리공이 죽으면 짐꾼 혼자")
	st2.vars.set_v("SQ_S08_SOL", 0)
	var r3 := _host("2277. 10. 26.  10:00", "J-03", "from_J-02")
	var st3: StoryState = r3[1]
	var c3: SideS08 = r3[2]
	st3.vars.set_v("SQ_S08_NOTEBOOK", 1)
	st3.kill(A)
	t.ok(_says(st3, c3, "SQS08_NOTEBOOK", "들것은 내가"), "짐꾼이 죽으면 수리공 혼자")


func test_sq_s08_both_names(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "J-04", "from_J-03")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	t.ok(not ("김민수 둘 말인데요" in _opts(st, "MQ-103_BOK", "MENU")), "다툼 전엔 노복희 줄이 없다")
	st.vars.set_v("SQ_S08_SAW", 1)
	c.tick()
	t.ok("김민수 둘 말인데요" in _opts(st, "MQ-103_BOK", "MENU"), "노복희 해법 B 줄")
	st.vars.set_v("PC_SKP_SPEECH", 90)
	t.eq(_play(st, c, "MQ-103_BOK", ["김민수 둘", "둘 다 김민수로"], "MENU"), [], "노복희 원고")
	t.eq(_v(st, "SQ_S08_SOL"), 2, "둘 다 김민수")
	t.ok(_says(st, c, "SQS08_A", "큰 민수"), "A 큰 민수")
	t.ok(_says(st, c, "SQS08_B", "작은 민수"), "B 작은 민수")
	t.ok(not ("김민수 둘 말인데요" in _opts(st, "MQ-103_BOK", "MENU")), "해법 뒤엔 줄이 사라진다")


func test_sq_s08_leave_it_d(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "J-04", "from_J-03")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	c._cmd(["saw"], func() -> void: pass)
	_ledger(h, st, c)
	h.enter("K-15", "from_W")
	_desk_talk(h, st, c)
	var d0 := _v(st, "SQ_S08_FOUND_DAY")
	for n in [3, 5]:
		st.vars.set_v("GAME_DAY", d0 + n)
		c._on_day(d0 + n)
	t.eq(_v(st, "SQ_S08_STRAIN"), 2, "5일째 간판 칼줄")
	h.enter("J-04", "from_J-03")
	h.enter("J-03", "from_J-04")
	t.ok(_says(st, c, "SQS08_SIGN", "칼로 줄을"), "간판 이름 위 칼줄")
	st.vars.set_v("GAME_DAY", d0 + 7)
	c._on_day(d0 + 7)
	t.eq(_v(st, "SQ_S08_SOL"), 4, "7일 그대로 두면 D")
	t.eq(st.quests.stage("SQ-S08"), 100, "끝")
	t.ok(_says(st, c, "JM_GEUM", "반쪽씩 쥐고"), "금하람 진료소의 두 침상")
	_play(st, c, "JM_GEUM", ["괜찮다고"])
	t.eq(_v(st, "SQ_S08_SEEN_A"), 1, "진료소 판은 한 번")
	t.ok(not _says(st, c, "JM_GEUM", "반쪽씩 쥐고"), "다시는 안 나온다")
	t.ok(_says(st, c, "SQS08_A", "말 걸지 마"), "A 붕대")


func test_sq_s08_one_left(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	st.vars.set_v("SQ_S08_SAW", 1)
	h.enter("K-15", "from_W")
	_desk_talk(h, st, c)
	_play(st, c, "SQS08_A", ["기록을 보여"])
	t.eq(_v(st, "SQ_S08_TOLD_A"), 1, "A만 받아들였다")
	var d0 := _v(st, "SQ_S08_FOUND_DAY")
	st.vars.set_v("GAME_DAY", d0 + 7)
	c._on_day(d0 + 7)
	t.eq(_v(st, "SQ_S08_SOL"), 5, "하나 남은 김민수")
	t.ok(_says(st, c, "SQS08_B", "김민수는 나 하나"), "B가 김민수로 남는다")
	t.ok(_says(st, c, "SQS08_A", "하경수야"), "A는 하경수")
	# 반대로 B만
	var r2 := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var st2: StoryState = r2[1]
	var c2: SideS08 = r2[2]
	for kv in [["SQ_S08_SOL", 5], ["SQ_S08_TOLD_B", 1]]:
		st2.vars.set_v(kv[0], kv[1])
	t.ok(_says(st2, c2, "SQS08_A", "김민수는 나 하나"), "A가 김민수로 남는 판")
	t.ok(_says(st2, c2, "SQS08_B", "봉 수리야"), "B는 봉재민")
	t.ok(_says(st2, c2, "SQS08_SIGN", "봉"), "간판은 봉 수리")


func test_sq_s08_deaths(t) -> void:
	# 위동현이 죽으면 빈 창구 — 서류함은 남는다(카르마 없음)
	var r := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	st.kill(WI)
	st.vars.set_v("SQ_S08_SAW", 1)
	t.ok(_says(st, c, "SQS08_DESK", "도장이 서류 위에"), "빈 창구")
	t.ok(_says(st, c, "SQS08_WAIT", "부를 사람이 없다"), "대기 의자")
	t.ok(_says(st, c, "SQS08_VIP", "빈 의자"), "넷째 창구")
	var k0 := int(st.vars.get_v("V_KARMA"))
	h.box_contents(h.map.boxes.get(SideS08.DRAWER))["opened"] = 1
	c.tick()
	t.eq(_v(st, "SQ_S08_DESK"), 4, "서류함은 연다")
	t.eq(int(st.vars.get_v("V_KARMA")), k0, "죽은 공무원 — 카르마 없음")
	t.ok(_says(st, c, "SQS08_DESK", "이미 손에"), "빈 창구 · 기록은 손에")
	# 한쪽이 죽은 채 남은 쪽이 받아들이면 A
	var r2 := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var st2: StoryState = r2[1]
	var c2: SideS08 = r2[2]
	c2._cmd(["saw"], func() -> void: pass)
	st2.kill(B)
	c2._cmd(["told", "a"], func() -> void: pass)
	t.eq(_v(st2, "SQ_S08_SOL"), 1, "죽은 쪽을 빼고 해법 A")
	# 둘 다 죽으면 끝(반쯤 된 상태 없음)
	var r3 := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var st3: StoryState = r3[1]
	var c3: SideS08 = r3[2]
	c3._cmd(["saw"], func() -> void: pass)
	st3.kill(A)
	st3.kill(B)
	c3.tick()
	t.eq(_v(st3, "SQ_S08_SOL"), 6, "둘 다 죽음")
	t.eq(st3.quests.stage("SQ-S08"), 100, "퀘스트가 닫힌다")
	# 둘 다 죽었는데 퀘스트를 몰랐으면 열지 않는다
	var r4 := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var st4: StoryState = r4[1]
	var c4: SideS08 = r4[2]
	st4.kill(A)
	st4.kill(B)
	c4.tick()
	t.eq(st4.quests.stage("SQ-S08"), 0, "모르는 퀘스트는 열지 않는다")


func test_sq_s08_card_and_fix(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "K-33", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	var cb: Variant = h.map.boxes.get(SideS08.CARD_DESK)
	t.ok(cb != null, "주민센터 직원 서랍")
	t.eq(int(h.box_contents(cb)["items"].get("M-073", 0)), 1, "출입 카드 한 장")
	h.enter("K-33", "from_W")
	t.eq(int(h.box_contents(cb)["items"].get("M-073", 0)), 1, "다시 와도 한 장")
	# 봉 수리 주 1회
	st.vars.set_v("SQ_S08_SOL", 1)
	st.vars.set_v("SQ_S08_FIX_DAY", 4 - 7)
	st.items["W-002@3"] = 1
	t.ok(_says(st, c, "SQS08_B", "봉 수리야"), "봉재민 판")
	t.ok("총 좀 봐 줘(주 1회 무료)" in _opts(st, "SQS08_B"), "무료 수리 줄")
	_play(st, c, "SQS08_B", ["총 좀"])
	t.eq(int(st.items.get("W-002@2", 0)), 1, "한 단계 고친다")
	t.eq(_v(st, "SQ_S08_FIX_DAY"), 4, "이번 주는 썼다")
	t.ok(not ("총 좀 봐 줘(주 1회 무료)" in _opts(st, "SQS08_B")), "다음 주까지 없다")
	st.vars.set_v("GAME_DAY", 11)
	t.ok("총 좀 봐 줘(주 1회 무료)" in _opts(st, "SQS08_B"), "7일 뒤 다시")
	# 보상(함준호)
	var c0 := int(st.vars.get_v("PC_CAPS"))
	_play(st, c, "SQS08_HAM")
	t.eq(int(st.vars.get_v("PC_CAPS")) - c0, 100, "함준호 100캡")
	t.eq(_v(st, "SQ_S08_REWARD"), 1, "보상 한 번")


func test_sq_s08_fun_fixes(t) -> void:
	var r := _host("2277. 10. 26.  10:00", "J-04", "from_J-03")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS08 = r[2]
	_ledger(h, st, c)
	t.ok(_says(st, c, "SQS08_HAM", "영등포 구청", ["경비원"]), "함준호가 구청으로 길을 잇는다")
	t.ok(_says(st, c, "SQS08_HAM", "노복희", ["둘 다 김민수로"]), "함준호가 해법 B를 노복희에게 넘긴다")
	# 창구: 서류함 · 폐쇄 · 낯선 번호표
	var r2 := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var st2: StoryState = r2[1]
	var c2: SideS08 = r2[2]
	t.ok(_says(st2, c2, "SQS08_DESK", "민원 내용이 없으시군요", [], "CALLED_IN"), "모르는 사람이 번호표로 불리면 '다음 분'")
	t.eq(_v(st2, "SQ_S08_DESK"), 0, "기록은 주지 않는다")
	st2.vars.set_v("SQ_S08_DESK", 4)
	t.ok(_says(st2, c2, "SQS08_DESK", "원본이 한 장 비는군요"), "서류함 털이를 안다")
	st2.vars.set_v("SQ_S08_SHUT", 5)
	t.ok(_says(st2, c2, "SQS08_DESK", "업무 마감"), "목격했으면 폐쇄가 먼저")
	# 노복희 — 한쪽이 이미 본명을 받아들였으면 하나 남은 김민수
	var r3 := _host("2277. 10. 26.  10:00", "J-04", "from_J-03")
	var st3: StoryState = r3[1]
	var c3: SideS08 = r3[2]
	c3._cmd(["saw"], func() -> void: pass)
	st3.vars.set_v("SQ_S08_TOLD_A", 1)
	_play(st3, c3, "MQ-103_BOK", ["김민수 둘"], "MENU")
	t.eq(_v(st3, "SQ_S08_SOL"), 5, "짐꾼은 하경수 — 김민수 칸은 수리공 몫")
	t.ok(_says(st3, c3, "SQS08_B", "나 하나"), "수리공이 김민수로 남는다")
	# 해법 B 뒤 무료 수리
	var r4 := _host("2277. 10. 26.  10:00", "J-03", "from_J-02")
	var h4: InteriorHost = r4[0]
	var st4: StoryState = r4[1]
	var c4: SideS08 = r4[2]
	st4.vars.set_v("SQ_S08_SOL", 2)
	st4.vars.set_v("SQ_S08_FIX_DAY", -10)
	t.ok("총 좀 봐 줘(주 1회 무료)" in _opts(st4, "SQS08_B"), "작은 민수네도 주 1회 무료")
	h4.enter("J-02", "from_J-03")
	var ab := ""
	for n in h4.npcs:
		if str(n["id"]) == "N-R02-015":
			ab = str(n["bark"])
	t.ok(ab.contains("큰 민수"), "짐꾼 바크가 해법을 안다")
	# D 뒤 늦은 이름
	var r5 := _host("2277. 10. 26.  10:00", "J-03", "from_J-02")
	var st5: StoryState = r5[1]
	var c5: SideS08 = r5[2]
	for kv in [["SQ_S08_SOL", 4], ["SQ_S08_MATCH", 1]]:
		st5.vars.set_v(kv[0], kv[1])
	t.ok(_says(st5, c5, "SQS08_A", "셔터에 걸게", ["배급 기록 사본"]), "진료소 뒤에도 기록을 내밀 수 있다")
	_play(st5, c5, "SQS08_A", ["배급 기록 사본"])
	t.eq(_v(st5, "SQ_S08_SOL"), 1, "늦은 이름 → A")
	t.eq(_v(st5, "SQ_S08_LATE"), 1, "늦은 표지")
	t.ok(_says(st5, c5, "SQS08_SHUTTER", "반쪽 명찰"), "반쪽 명찰 셔터")
	_play(st5, c5, "SQS08_A", ["배급 기록 사본"])
	t.eq(_v(st5, "SQ_S08_LATE"), 1, "한 번만")
	# 오순례로 봉재민 설득
	var r6 := _host("2277. 10. 26.  10:00", "J-03", "from_J-02")
	var st6: StoryState = r6[1]
	var c6: SideS08 = r6[2]
	for kv in [["SQ_S08_MATCH", 1], ["SQ_S08_PROXY", 2], ["PC_SKP_SPEECH", 0]]:
		st6.vars.set_v(kv[0], kv[1])
	_play(st6, c6, "SQS08_B", ["기록을 보여", "오순례"])
	t.eq(_v(st6, "SQ_S08_TOLD_B"), 1, "0411번 오순례로 봉재민")
	t.ok(_says(st6, c6, "SQS08_BOARD", "0412"), "전광판은 0412")
	# 위동현이 죽은 빈 창구에 번호표
	var r7 := _host("2277. 10. 26.  10:00", "K-15", "from_W")
	var st7: StoryState = r7[1]
	var c7: SideS08 = r7[2]
	st7.kill(WI)
	st7.vars.set_v("SQ_S08_PROXY", 1)
	_play(st7, c7, "SQS08_DESK", ["도장 옆에"])
	t.eq(_v(st7, "SQ_S08_PROXY"), 3, "빈 창구에 올려 둔다")
	t.ok(_says(st7, c7, "SQS08_SKEL", "도장 옆"), "해골 판")
	# 수습 뒤 초소 · 둘 다 죽음 셔터 · 다툼은 해법 뒤 다시 안 열림
	var r8 := _host("2277. 10. 26.  10:00", "J-03", "from_J-02")
	var h8: InteriorHost = r8[0]
	var st8: StoryState = r8[1]
	var c8: SideS08 = r8[2]
	for kv in [["SQ_S08_NOTEBOOK", 1], ["SQ_S08_SOL", 3]]:
		st8.vars.set_v(kv[0], kv[1])
	t.ok(_says(st8, c8, "SQS08_GUARD", "빈 벽"), "수습 뒤 초소는 빈 벽")
	st8.vars.set_v("SQ_S08_SOL", 6)
	t.ok(_says(st8, c8, "SQS08_SHUTTER", "하경수 · 봉재민"), "둘 다 죽으면 이름 셋 셔터")
	st8.vars.set_v("SQ_S08_SOL", 2)
	st8.vars.set_v("SQ_S08_SEEN_B", 5)
	h8.player.loco.place(h8.map.mark_pos("quarrel"))
	c8.tick()
	t.eq(_v(st8, "SQ_S08_SAW"), 0, "해법 뒤엔 다툼이 없다")
	# 함준호가 죽으면 노복희가 보상
	var r9 := _host("2277. 10. 26.  10:00", "J-04", "from_J-03")
	var st9: StoryState = r9[1]
	var c9: SideS08 = r9[2]
	st9.vars.set_v("SQ_S08_SOL", 1)
	st9.kill("N-R02-009")
	var cap0 := _v(st9, "PC_CAPS")
	_play(st9, c9, "MQ-103_BOK", ["끝났어요"], "MENU")
	t.eq(_v(st9, "PC_CAPS") - cap0, 100, "노복희가 함준호 몫")
