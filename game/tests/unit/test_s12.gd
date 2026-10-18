## 단계 1-11k SQ-S12 「관리 요원의 유족」(SD-04a §5.5 · 구현 정합 이름 정합, 계획 docs/seoul-fallout/_plans/1-11k_SQ-S12_plan.md §4):
## 발동(살펴보기 · 지하시장 진입 · 연락부 먼저) · 호수 따라가기(TM-J04 · 인지영) · 셋이 바라는 것(진재석 B · 사공민영 C · 엄수연 A) ·
## 회의 증거 장 수(EVID) · 유품 셋(벙커 세 자리) · 판매(염희정 V13 · 사공민영 거절) · 사흘 뒤 알려짐 · 가족이 죽었으면 내려놓기 · 완료 · 보상 값.
extends RefCounted


func _host(map_id := "J-02", mark := "from_J-01") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	var c := SideS12.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: SideS12, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s12":
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
	return str(r[r.size() - 1])


func _errs(r: Array) -> Array:
	return r.slice(0, r.size() - 1)


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


func _bundle(st: StoryState) -> void:
	st.call_fn("give", ["M-210", 1])
	st.vars.set_v("MQ104_IDS", 1)


func test_s12_data(t) -> void:
	for s in ["EXAMINE_M210", "SQS12_REM_K", "SQS12_REM_G", "SQS12_REM_M", "SQS12_LAY_J", "SQS12_LAY_E", "SQS12_LAY_S"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % s), "장면 %s" % s)
	var r := _host()
	var h: InteriorHost = r[0]
	for id in ["M-412", "M-413", "M-414", "M-210"]:
		t.ok(h.items_db.has(id), "아이템 %s" % id)
	var y2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/Y-02.json"))
	var ys := str(y2)
	for s in ["SQS12_REM_K", "SQS12_REM_G", "SQS12_REM_M"]:
		t.ok(ys.contains(s), "벙커 세 자리 %s" % s)
	var tm := FileAccess.get_file_as_string("res://data/terminals.json")
	t.ok(tm.contains("SQ_S12_LOOK"), "연락부 단말 항목(TM-J04)")
	t.ok(FileAccess.get_file_as_string("res://data/quests.json").contains("SQ-S12"), "퀘스트 표")


## 핍-보이 살펴보기로 발동 · 뒷면 호수 · 증거 장 수
func test_s12_start_examine(t) -> void:
	var r := _host("J-03", "from_J-02")
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	t.eq(c.stage(), 0, "묶음 없이 — 발동 안 함")
	_bundle(st)
	var p := _play(st, c, "EXAMINE_M210")
	t.eq(_errs(p), [], "살펴보기 오류 없음")
	t.ok(_said(p).contains("A-11") and _said(p).contains("B-04") and _said(p).contains("A-13"), "뒷면 비상 연락 — 세 호수")
	t.eq(c.stage(), 10, "발동 10")
	t.eq(c.q("EVID"), 12, "묶음 열두 장")
	p = _play(st, c, "EXAMINE_M210")
	t.ok(_said(p).contains("12") , "다시 보면 남은 장 수")


## 묶음을 들고 지하시장에 들면 자동 발동
func test_s12_start_map(t) -> void:
	var r := _host("J-03", "from_J-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	h.enter("J-02", "from_J-03")
	t.eq(c.stage(), 10, "지하시장 진입 → 10")


## 연락부(단말)를 먼저 보고 나중에 묶음을 얻음 → 따라 올림(P2)
func test_s12_look_first(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	c.look("단말")
	t.eq(c.stage(), 0, "묶음이 없으면 단계 없음")
	t.eq(c.q("LOOK"), 1, "연락부는 봤다")
	_bundle(st)
	c._t = 1.0
	c._process(0.1)
	t.eq(c.stage(), 30, "묶음을 쥐면 따라 올림 — 셋 모두 앎(30)")
	t.eq(c.q("J"), 1, "진재석 앎")
	t.eq(c.q("S"), 1, "사공민영 앎")
	t.eq(c.q("E"), 1, "엄수연 앎")


## 인지영에게 보이기(SQ-S11 장면) — 얼굴로 알아봄
func test_s12_inji(t) -> void:
	var r := _host("J-03", "from_J-02")
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	var sc := _scene("SQS11_INJI")
	t.ok(str(sc).contains("s12"), "인지영 장면에 신분증 갈래")
	c._cmd(["look", "inji"], func() -> void: pass)
	t.eq(c.q("LOOK"), 1, "인지영 — 연락부와 같은 사실")
	t.ok(c.stage() >= 20, "단계 20 이상")


## 진재석: 회의 탁자(B)가 맞는 사람 — 증거는 묶음에 남는다
func test_s12_jin_keep(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	var k0 := _v(st, "V_KARMA")
	var p := _play(st, c, "JM_JIN", ["신분증", "회의 탁자"])
	t.eq(_errs(p), [], "진재석 대화 오류 없음")
	t.ok(_said(p).contains("권이준"), "사위 이름")
	t.eq(c.q("J"), 4, "회의에 올리기로(4)")
	t.eq(_v(st, "SQE_FAMILY"), 1, "유족 증언자")
	t.eq(_v(st, "V_KARMA") - k0, 15, "카르마 +15")
	t.eq(c.q("EVID"), 12, "증거 그대로 12")
	t.eq(_v(st, "SQH_IDCARD") & 1, 0, "가족 손에 간 비트 없음")
	p = _play(st, c, "JM_JIN")
	t.ok(_said(p).contains("출석"), "다시 말 걸면 '출석 부르듯이'")
	var m := Mq101.new()
	m.host = r[0]
	m.st = st
	var k := m.trade_mult("VJ05")
	t.ok(absf(float(k[0][1]) - 1.1) < 0.001, "말대로 해 준 손님 — 진공관 매입 +10%(B가 숫자로도 이긴다)")
	m.free()


## 진재석에게 건네면 — 노점 상자에 맡겨 둔다(묶음에서 빠짐 · 상자에 실제 한 장) · 보상 없음 · 되훔치면 묶음으로
func test_s12_jin_give(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	_play(st, c, "JM_JIN", ["신분증", "장인어른"])
	t.eq(c.q("J"), 3, "건넴(3)")
	t.eq(c.q("EVID"), 11, "상자에 맡긴 장은 묶음 밖 — 증거 11(P1 한 곳)")
	t.eq(_v(st, "SQH_IDCARD") & 1, 1, "비트 1 권이준")
	t.eq(c.q("REWARD") & 2, 0, "건네기만 하면 감정 보상 없음")
	var bx := {}
	for cc in h.map.boxes:
		if str(h.map.boxes[cc].get("name", "")) == "부품 상자":
			bx = h.box_contents(h.map.boxes[cc])
	t.eq(int(bx.get("items", {}).get("M-415", 0)), 1, "부품 상자 안에 권이준의 신분증 한 장")
	var p := _play(st, c, "JM_JIN")
	t.ok(_said(p).contains("노점 상자"), "상자 속 신분증 한 줄")
	# 해 보고 싶은 짓: 상자에서 되훔침
	bx["items"].erase("M-415")
	st.call_fn("give", ["M-415", 1])
	var jh0 := _v(st, "AFF_JH")
	c._t = 1.0
	c._process(0.1)
	t.eq(c.q("STOLE"), 1, "되훔침")
	t.eq(c.q("EVID"), 12, "묶음으로 돌아옴 — 증거 12")
	t.eq(int(st.items.get("M-415", 0)), 0, "한 장은 묶음에 합쳐짐")
	t.eq(c.q("J"), 3, "건넸던 사실은 그대로")
	t.eq(_v(st, "AFF_JH") - jh0, -2, "JH −2")
	p = _play(st, c, "JM_JIN")
	t.ok(_said(p).contains("상자가 가벼워졌더라"), "진재석이 안다")
	h.enter("J-03", "from_J-02")
	h.enter("J-02", "from_J-03")
	for cc in h.map.boxes:
		if str(h.map.boxes[cc].get("name", "")) == "부품 상자":
			t.eq(int(h.box_contents(h.map.boxes[cc])["items"].get("M-415", 0)), 0, "다시 들어와도 상자에 또 생기지 않음")


## 엄수연: 이름이 적힌 그것(A) — 증거 한 장이 진짜로 준다 · 약 −15%
func test_s12_eom_give(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	var p := _play(st, c, "JM_EOM", ["신분증", "건넨다"])
	t.eq(_errs(p), [], "엄수연 대화 오류 없음")
	t.ok(_said(p).contains("23시 25분"), "호송차 시각")
	t.eq(c.q("E"), 3, "건넴(3)")
	t.eq(c.q("EVID"), 11, "증거 11장")
	t.eq(_v(st, "SQH_IDCARD") & 4, 4, "비트 4 문도하")
	var m := Mq101.new()
	m.host = h
	m.st = st
	var k := m.trade_mult("V11")
	t.ok(float(k[0][0]) < 0.86, "약 −15%")
	m.free()
	p = _play(st, c, "JM_EOM")
	t.ok(_said(p).contains("그이 이름은 여기"), "약상자 사이 신분증")


## 엄수연 설득(B)은 화술 보통 — 실패하면 '이름은 내 손에'
func test_s12_eom_keep_check(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	st.vars.set_v("PC_SKP_SPEECH", 0)
	var sc := str(_scene("JM_EOM"))
	t.ok(sc.contains("NOKEEP"), "실패 갈래가 있다")
	st.vars.set_v("PC_SKP_SPEECH", 100)
	_play(st, c, "JM_EOM", ["신분증", "회의장"])
	t.ok(c.q("E") == 4 or c.q("E") == 2, "성공이면 4, 운이 나쁘면 보여 준 채(2)")


## 사공민영: 신분증보다 '그 달' — 묶음을 팔려 하면 '값을 못 매기겠네'(발견 길) · 배급표 묶음이 답
func test_s12_sagong(t) -> void:
	var r := _host("J-03", "from_J-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	t.ok(_opts(st, "JM_SAGONG").any(func(o): return str(o).contains("묶음을 판다")), "처음엔 '판다' 갈래")
	var p := _play(st, c, "JM_SAGONG", ["묶음을 판다", "어머님"])
	t.eq(_errs(p), [], "사공민영 대화 오류 없음")
	t.ok(_said(p).contains("값을 못 매기겠네") and _said(p).contains("강수아"), "팔려다 딸을 알아봄")
	t.eq(c.q("S"), 3, "건넴(3)")
	t.eq(c.q("EVID"), 11, "증거 11")
	t.eq(c.q("SB"), 0, "그래도 순회는 계속")
	st.call_fn("give", ["M-413", 1])
	var caps0 := _v(st, "PC_CAPS")
	p = _play(st, c, "JM_SAGONG", ["배급표 묶음"])
	t.eq(c.q("SB"), 1, "유품 건넴")
	t.eq(int(st.items.get("M-003", 0)), 3, "전시 배급표 세 장")
	t.eq(_v(st, "PC_CAPS"), caps0, "캡은 아님")
	h.refresh_npcs()
	p = _play(st, c, "JM_SAGONG")
	t.ok(_said(p).contains("앉아 있으니"), "벤치에 앉음")


## 유품 셋 — 벙커 세 자리(신분증을 이미 거둔 뒤) · 손에 든 것만
func test_s12_remains(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	var p := _play(st, c, "SQS12_REM_K", ["거둔다", "편다"])
	t.eq(_errs(p), [], "1조 자리 오류 없음")
	t.eq(_v(st, "MQ104_IDS"), 1, "어느 자리에서든 신분증을 거둔다(한 곳)")
	t.eq(int(st.items.get("M-210", 0)), 1, "묶음 하나")
	t.eq(int(st.items.get("M-412", 0)), 1, "반지")
	p = _play(st, c, "SQS12_REM_G", ["든다"])
	t.ok(not _said(p).contains("열두 장"), "이미 거뒀으면 거두기 갈래 없음")
	t.eq(int(st.items.get("M-210", 0)), 1, "묶음은 여전히 하나")
	t.eq(int(st.items.get("M-413", 0)), 1, "배급표 묶음")
	p = _play(st, c, "SQS12_REM_M", ["푼다"])
	t.ok(_said(p).contains("23:29"), "멈춘 시각")
	t.eq(int(st.items.get("M-414", 0)), 1, "손목시계")
	p = _play(st, c, "SQS12_REM_M")
	t.ok(_said(p).contains("시계 자국"), "다시 보면 빈 손목")


## 유품만 먼저(신분증 없이) — C 혼자도 된다
func test_s12_item_only(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	st.call_fn("give", ["M-414", 1])
	var p := _play(st, c, "JM_EOM", ["손목시계"])
	t.eq(_errs(p), [], "오류 없음")
	t.eq(c.q("EW"), 1, "시계 건넴")
	t.ok(c.stage() >= 10, "발동")
	t.eq(int(st.items.get("M-414", 0)), 0, "손에서 빠짐")


## 판매(D) — 염희정 · 장당 30 · 카르마 −25 · 사흘 뒤 알려짐(JH −3) · 가족 말이 바뀐다
func test_s12_sell(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	st.vars.set_v("SQ_S12_E", 3)
	c._after_card()
	t.eq(c.q("EVID"), 11, "한 장은 엄수연 손에")
	var caps0 := _v(st, "PC_CAPS")
	var k0 := _v(st, "V_KARMA")
	var xp0 := _v(st, "PC_XP")
	st.vars.set_v("SQ_S12_J", 4)
	var p := _play(st, c, "JM_YEOM", ["이건 안 판다"])
	t.eq(_errs(p), [], "염희정 오류 없음")
	t.eq(c.q("YASK"), 1, "제안을 들음")
	t.eq(c.q("SOLD"), 0, "안 팔았다")
	p = _play(st, c, "JM_YEOM", ["묶음을 내민다", "묶음째"])
	t.ok(_said(p).contains("11장"), "두 번째는 내가 내밀 때만 — 남은 장 수")
	t.eq(c.q("SOLD"), 1, "팔았다")
	t.eq(_v(st, "PC_CAPS") - caps0, 330, "11장 × 30")
	t.eq(_v(st, "V_KARMA") - k0, -25, "카르마 −25")
	t.eq(int(st.items.get("M-210", 0)), 0, "묶음이 손을 떠남")
	t.eq(c.stage(), 100, "판매로 완료")
	t.eq(_v(st, "PC_XP") - xp0, 100, "판매 결말 XP 100(최선과 다름)")
	var jh0 := _v(st, "AFF_JH")
	st.vars.set_v("GAME_DAY", 12)
	h.day_tick.emit(12)
	t.eq(c.q("KNOWN"), 0, "이틀 — 아직")
	st.vars.set_v("GAME_DAY", 13)
	h.day_tick.emit(13)
	t.eq(c.q("KNOWN"), 1, "사흘 뒤 알려짐")
	t.eq(_v(st, "AFF_JH") - jh0, -3, "JH −3")
	p = _play(st, c, "JM_JIN")
	t.ok(_said(p).contains("인쇄소에서 불렀냐"), "회의 약속을 판 판 — 진재석")
	st.call_fn("give", ["M-412", 1])
	p = _play(st, c, "JM_JIN", ["반지"])
	t.ok(_said(p).contains("너 때문은 아니야") and c.q("JR") == 1, "판 뒤에도 반지는 받는다")
	p = _play(st, c, "JM_EOM")
	t.ok(not _said(p).contains("팔았다면서"), "이미 건네받은 엄수연은 원망 대신 그 이름")


## 가족이 죽었으면 — 기다리던 자리에 내려놓는다 · 노복희가 시각을 적는다
func test_s12_lay(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	st.kill("N-R02-006")
	h.refresh_npcs()
	var m2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/J-02.json"))
	t.ok(str(m2).contains("SQS12_LAY_E"), "약 노점 자리")
	var p := _play(st, c, "SQS12_LAY_E", ["A-13"])
	t.eq(_errs(p), [], "내려놓기 오류 없음")
	t.eq(c.q("E"), 3, "자리에 놓임(3)")
	t.eq(c.q("LAYE"), 1, "자리 표시")
	t.eq(c.q("EVID"), 11, "증거 11")
	t.ok(_said(p).contains("노복희"), "노복희가 적는다")
	st.kill("C-050")
	st.vars.set_v("SQ_S12_LAYJ", 0)
	st.kill("N-R02-005")
	p = _play(st, c, "SQS12_LAY_J", ["A-11"])
	t.ok(not _said(p).contains("노복희"), "노복희가 죽었으면 그 줄 없음")
	t.eq(c.q("J"), 3, "진재석 자리에도")
	# 재미 검수 버그: 신분증을 먼저 놓아도 유품을 이어 놓을 수 있다
	st.call_fn("give", ["M-414", 1])
	t.ok(_opts(st, "SQS12_LAY_E").any(func(o): return str(o).contains("근무 시계")), "놓은 뒤에도 시계 갈래")
	p = _play(st, c, "SQS12_LAY_E", ["근무 시계"])
	t.eq(c.q("EW"), 1, "시계도 놓음")
	t.ok(_said(p).contains("신분증 곁에"), "신분증 곁에 둔다")


## 누구 가족인지 모를 때 내려놓기 선택지가 이름을 알려 주지 않는다(P2)
func test_s12_lay_noleak(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	st.kill("N-R02-006")
	var o := _opts(st, "SQS12_LAY_E")
	t.ok(o.any(func(x): return str(x).contains("A-13")) and not o.any(func(x): return str(x).contains("문도하")), "선택지는 호수만")


## 유품만(신분증 없이) — 한 단계 얕게: 누구 것인지 알게 되고, 이름은 아직
func test_s12_watch_shallow(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	st.call_fn("give", ["M-414", 1])
	var p := _play(st, c, "JM_EOM", ["손목시계"])
	t.ok(_said(p).contains("이름이 적힌 건요"), "얕은 반응 — 이름을 찾는다")
	t.eq(c.q("E"), 1, "누구 가족인지 앎(1)")


## 당직 일지를 읽었으면 '10. 31.'을 알려 줄 수 있다 — 분필이 바뀐다
func test_s12_log(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	st.vars.set_v("MQ104_LOG", 1)
	st.vars.set_v("SQ_S12_E", 2)
	_play(st, c, "JM_EOM", ["당직 일지"])
	t.eq(c.q("LOG"), 1, "10. 31.")
	var m2 := FileAccess.get_file_as_string("res://data/maps/J-02.json")
	t.ok(m2.contains("10. 31."), "분필 글")


## 사공민영에게 9월분(전시 배급표)을 내밀면 — 그 달 것이 아니다
func test_s12_sept(t) -> void:
	var r := _host("J-03", "from_J-02")
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	st.call_fn("give", ["M-003", 1])
	var p := _play(st, c, "JM_SAGONG", ["전시 배급표"])
	t.ok(_said(p).contains("9월 거네"), "9월분")
	t.eq(c.q("SB"), 0, "순회는 계속")


## 셋 모두 정해지면 100 · XP · JH +3(한 번)
func test_s12_done(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	var jh0 := _v(st, "AFF_JH")
	var xp0 := _v(st, "PC_XP")
	c.keep("j")
	c.give("e")
	t.ok(c.stage() < 100, "둘 — 아직")
	c.give("s")
	t.eq(c.stage(), 100, "셋 — 완료")
	t.eq(c.q("DONE"), 1, "완료 표시")
	t.eq(_v(st, "PC_XP") - xp0, 300, "XP 300")
	t.eq(_v(st, "AFF_JH") - jh0, 2 + 2 + 2 + 3, "JH 가족마다 +2 · 셋 모두 +3")
	t.eq(c.q("EVID"), 10, "증거 10장")
	c.give("s")
	t.eq(_v(st, "AFF_JH") - jh0, 9, "두 번 주지 않음")
	t.eq(_v(st, "SQH_IDCARD"), 2 | 4, "비트 2 · 4")


## 저장/불러오기 — 변수 한 곳
func test_s12_save(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS12 = r[2]
	_bundle(st)
	c.start("시험")
	c.give("e")
	var js := JSON.stringify(GameSnapshot.story(st))
	var st2 := StoryState.new()
	st2.load_data()
	GameSnapshot.apply_story(st2, JSON.parse_string(js))
	t.eq(int(st2.vars.get_v("SQ_S12_E")), 3, "불러온 뒤 E 3")
	t.eq(int(st2.vars.get_v("SQ_S12_EVID")), 11, "불러온 뒤 증거 11")
	t.eq(st2.quests.stage("SQ-S12"), c.stage(), "단계 그대로")
