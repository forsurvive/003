## 단계 0-8 MQ-P3 적성 평가: 복도 소동 6갈래(V_DY_P3·MQP3_RESULT·카르마·배급 쿠폰), 화술 실패 뒤 선택지로 돌아오기,
## 응시 방법 3가지(시험·건너뛰기·대리 작성 — 10번은 본인이), 결과지 대리 작성 추천, 등록 카드 단계 1·특별 퍽, 2274 맵 배치·다시 세우기.
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	CharDocs.write_name(st, "윤", "서진")
	st.quests.set_stage("MQ-P1", 100)
	st.quests.set_stage("MQ-P2", 100)
	st.quests.set_stage("MQ-P3", 10)
	return st


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 선택지가 나올 때까지(또는 끝까지) 넘긴다. 명령은 건너뛴다(연출 없음)
func _until_choice(dr: DialogueRunner, cur: Dictionary) -> Dictionary:
	var guard := 0
	while cur["type"] != "choices" and cur["type"] != "end" and guard < 200:
		guard += 1
		cur = dr.advance()
	return cur


func _pick(cur: Dictionary, key: String) -> int:
	for i in cur["opts"].size():
		if str(cur["opts"][i]["text"]).contains(key):
			return i
	return -1


## 소동 한 갈래를 끝까지: [V_DY_P3, MQP3_RESULT, 카르마, 배급 쿠폰 수, 단계]
func _incident(key: String, setup: Callable = Callable()) -> Array:
	var st := _state()
	if setup.is_valid():
		setup.call(st)
	var dr := DialogueRunner.new(st)
	var cur := _until_choice(dr, dr.start(_scene("MQ-P3_S01")))
	var i := _pick(cur, key)
	if i < 0:
		return [-1, -1, 0, 0, st.quests.stage("MQ-P3"), cur]
	cur = _until_choice(dr, dr.choose(i))
	while cur["type"] != "end":
		cur = dr.advance()
	return [int(st.vars.get_v("V_DY_P3")), int(st.vars.get_v("MQP3_RESULT")), int(st.vars.get_v("V_KARMA")),
		int(st.items.get("M-249", 0)), st.quests.stage("MQ-P3"), dr.errors]


func test_incident_branches(t) -> void:
	var r := _incident("살핀다", func(st): st.vars.set_v("PC_PE", 6))
	t.eq(r.slice(0, 5), [1, 1, 50, 0, 30], "[인지력 6] 잉크 번짐 → 도움 · 나채윤 적발 · +50")
	r = _incident("등사 잉크", func(st): st.vars.set_v("PC_PE", 5); st.vars.set_v("PC_SKP_SCIENCE", 15))
	t.eq(r.slice(0, 5), [1, 1, 50, 0, 30], "[과학 25]는 인지력이 모자랄 때의 같은 갈래")
	r = _incident("출입 기록", func(st): st.vars.set_v("PC_SKP_LOCKPICK", 15))
	t.eq(r.slice(0, 5), [1, 2, 50, 0, 30], "[자물쇠 따기 25] 출입 기록")
	r = _incident("앞을 막는다")
	t.eq(r.slice(0, 5), [1, 4, 25, 0, 30], "막아섬 → 도움 · 둘 다 응시 · +25")
	r = _incident("봤다고")
	t.eq(r.slice(0, 5), [3, 5, -50, 5, 30], "고발 → 배신 · 배급 쿠폰 5장 · −50")
	r = _incident("지나친다")
	t.eq(r.slice(0, 5), [2, 6, 0, 0, 30], "지나침 → 방관 · 0")
	t.eq(r[5].size(), 0, "실행 오류 없음")
	# 판정 문턱: 인지력 5 · 과학·자물쇠 따기 기본이면 둘 다 숨는다(잠긴 선택지 감춤)
	var st := _state()
	st.vars.set_v("PC_PE", 5)
	var dr := DialogueRunner.new(st)
	var cur := _until_choice(dr, dr.start(_scene("MQ-P3_S01")))
	t.ok(_pick(cur, "살핀다") < 0 and _pick(cur, "출입 기록") < 0, "판정 문턱 미달 선택지는 숨는다")
	t.eq(cur["opts"].size(), 4, "화술 · 막아섬 · 고발 · 지나침")


func test_incident_speech(t) -> void:
	var st := _state()
	var p := st.speech_chance("C-026", "아주 쉬움")
	st.check_seed = 0
	while Speech.roll(st.check_seed, "MQ-P3_S01:1:3") < p:          # 실패하는 씨앗(판정 고정)
		st.check_seed += 1
	var dr := DialogueRunner.new(st)
	var cur := _until_choice(dr, dr.start(_scene("MQ-P3_S01")))
	var n: int = cur["opts"].size()
	cur = _until_choice(dr, dr.choose(_pick(cur, "설득한다")))
	t.eq(dr.last_check.get("ok", true), false, "화술 실패")
	t.eq(cur["type"], "choices", "실패하면 선택지로 돌아온다(도경철이 오기 전)")
	t.eq(cur["opts"].size(), n - 1, "실패한 설득은 다시 나오지 않는다")
	t.eq(int(st.vars.get_v("MQP3_RESULT")), 0, "아직 결과 없음")
	st = _state()
	st.check_seed = 0
	while Speech.roll(st.check_seed, "MQ-P3_S01:1:3") >= p:
		st.check_seed += 1
	dr = DialogueRunner.new(st)
	cur = _until_choice(dr, dr.start(_scene("MQ-P3_S01")))
	cur = dr.choose(_pick(cur, "설득한다"))
	while cur["type"] != "end":
		cur = dr.advance()
	t.eq([int(st.vars.get_v("V_DY_P3")), int(st.vars.get_v("MQP3_RESULT")), int(st.vars.get_v("V_KARMA"))], [1, 3, 50], "설득 성공 → 자백 · +50")


## 응시 방법: 시험(카드 명령) · 건너뛰기(10번만) · 대리 작성(돌잡이에 맞춘 말 + 유형 + 10번)
func test_exam_routes(t) -> void:
	for route in ["시험을 본다", "꼭 봐야", "대신 써"]:
		var st := _state()
		st.quests.set_stage("MQ-P3", 30)
		st.vars.set_v("MQP3_RESULT", 4)
		st.vars.set_v("V_DOL", 5)
		var dr := DialogueRunner.new(st)
		var cur := _until_choice(dr, dr.start(_scene("MQ-P3_S02")))
		cur = dr.choose(_pick(cur, route))
		var cmds := []
		var guard := 0
		while cur["type"] != "end" and guard < 200:
			guard += 1
			if cur["type"] == "cmd":
				cmds.append(cur["name"])
			if cur["type"] == "choices":
				if _pick(cur, "총을 다루는 일") >= 0:
					cur = dr.choose(_pick(cur, "총을 다루는 일"))
				else:
					cur = dr.choose(3)                                   # 10번 ④ 문을 열고 밖을 본다
				continue
			cur = dr.advance()
		t.eq(st.quests.stage("MQ-P3"), 40, route + ": 단계 40(결과지)")
		if route == "시험을 본다":
			t.ok("doc" in cmds, "시험: 판독 카드를 연다")
			t.eq(int(st.vars.get_v("V_Q10")), 0, "시험: 10번은 카드가 적는다")
		else:
			t.ok(not "doc" in cmds, route + ": 카드 없음")
			t.eq(int(st.vars.get_v("V_Q10")), 4, route + ": 10번은 본인이 답한다")
		if route == "대신 써":
			t.eq(CharDocs.proxy_type(st), 4, "대리 작성 유형 = 총")
			t.ok(dr.log.any(func(l): return l.contains("탄알을 잡았다며")), "돌잡이 탄알 → 넷째 칸에 동그라미")
		t.ok("refresh" in cmds, route + ": 차명수가 평가관실로(맵 인물 다시 세우기)")


## 결과지: 대리 작성 추천 · 미응시 · 결과지 장면(등록 카드 1, 통지서, 단계 100) · 핍-보이 등록 카드·특별 퍽
func test_result_and_card(t) -> void:
	var st := _state()
	st.vars.set_v("PC_APT_PROXY", 1)
	var rs := ResultSheet.new()
	rs.setup(st)
	t.eq(rs.picks, ["REPAIR", "SCIENCE", "LOCKPICK"], "대리 작성(기계) → 수리·과학·자물쇠 따기 추천")
	rs.free()
	st.vars.set_v("PC_APT_PROXY", 0)
	rs = ResultSheet.new()
	rs.setup(st)
	t.eq(rs.picks, [], "미응시 → 추천 없음")
	rs.free()
	CharDocs.write_aptitude(st, [1, 1, 1, 3, 2, 1, 3, 1, 4, 1])
	st.vars.set_v("PC_APT_PROXY", 2)
	rs = ResultSheet.new()
	rs.setup(st)
	t.eq(rs.proxy, 0, "답이 있으면 대리 작성 유형은 쓰지 않는다")
	t.eq(rs.picks.slice(0, 2), ["SMALL_GUNS", "REPAIR"], "답대로 추천: 소형 화기 3(10-① 포함) · 수리 3 동점 → 더 나중 문항(10번)이 앞")
	rs.free()
	st.quests.set_stage("MQ-P3", 40)
	st.vars.set_v("MQP3_RESULT", 6)
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene("MQ-P3_S03"))
	while cur["type"] != "end":
		cur = dr.advance()
	t.eq(int(st.vars.get_v("V_REGCARD")), 1, "결과지 수령 → 등록 카드 단계 1(SD-03a §4.8)")
	t.eq(int(st.items.get("M-250", 0)), 1, "결과 통지서(기념품)")
	t.eq(st.quests.stage("MQ-P3"), 100, "MQ-P3 끝")
	t.ok(dr.log.any(func(l): return l.contains("응시를 안 해도 나와")), "하도윤이 응시 못 한 갈래의 대사")
	var pb := PipBoy.new()
	pb.st = st
	pb.tab = 0
	pb.sub = [3, 0, 0]
	t.eq(pb._rows().map(func(r): return r["id"]), ["PK-103"], "퍽: 관리 후보 1순위")
	st.vars.set_v("V_REGCARD", 0)
	t.eq(pb._rows().size(), 0, "결과지 전에는 퍽이 없다")
	pb.free()


## 2274 맵: 사건 결과에 따라 교실 자리가 바뀐다(조건) · 장면 열림 조건이 시대를 가른다
func test_map_2274(t) -> void:
	var st := _state()
	var m := InteriorMap.new()
	m.load_map("V-03", st)
	var on := func(id: String) -> Array:
		return m.data["npcs"].filter(func(n): return n["id"] == id and (str(n.get("cond", "")) == "" or StoryExpr.test(str(n["cond"]), st))).map(
			func(n): return Vector2i(int(n["x"]), int(n["y"])))
	t.eq(on.call("C-026"), [Vector2i(22, 16)], "단계 10: 나채윤은 사물함 앞")
	t.eq(on.call("C-023"), [Vector2i(10, 25)], "차명수는 교실 교탁")
	t.ok(m.data["triggers"].any(func(tr): return str(tr["scene"]) == "MQ-P3_S01"), "복도 소동 트리거")
	st.quests.set_stage("MQ-P3", 30)
	for res in [[1, [], [Vector2i(12, 29)]], [4, [Vector2i(6, 29)], [Vector2i(12, 29)]], [5, [Vector2i(6, 29)], []]]:
		st.vars.set_v("MQP3_RESULT", res[0])
		t.eq([on.call("C-026"), on.call("C-002")], [res[1], res[2]], "결과 %d: 교실의 나채윤·하도윤" % res[0])
	st.quests.set_stage("MQ-P3", 40)
	t.eq(on.call("C-023"), [Vector2i(45, 7)], "단계 40: 차명수는 평가관실")
	m.free()
	t.eq(st.year(), 2274, "MQ-P3 동안은 2274년")
	var g: Dictionary = _scene("MQ-P2_S01")
	t.ok(not StoryExpr.test(str(g.get("cond", "")), st), "2268 생활기록부 장면은 2274년 차명수에게 다시 열리지 않는다")
