## 단계 1-12i i4 R01 비표시 UQ-63 「연수원의 졸업장」(SD-05 §3.31, 계획 docs/seoul-fallout/_plans/1-12i_UQ-62-67_plan.md §6 · §6b):
## 깔끔이 · 명부 · 보존함(맞춤 [지능 5] / 30분 / 그냥) · ✕ 한 장 · 내 성씨 · 내 번호 · 인터컴(세 번째부터) · 투입구 · 다음 06:00 매듭 · 결과 한 번 · 깔끔이 다음 날 · 잃음 90.
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

func _put(st: StoryState, kv: Dictionary) -> void:
	for k in kv:
		st.vars.set_v(k, kv[k])


## 시험 하네스는 'uqr' 명령만 돌린다 — `s03 call`이 안 돌아 SQ_S03_CALLS가 0이라 첫 호출에 바로 받는다(세 번째 호출 규칙은 test_sq_s03 몫)
func _intercom_open(st: StoryState, c: UqR01) -> void:
	_play(st, c, "SQS03_INTERCOM", ["누른다", "끊는다"])


func test_uq63_match_left_mine_done(t) -> void:
	var a := _host("K-01", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_IN": 5, "P_SURNAME": "윤"})
	t.ok(_says(st, c, "K-01_CLEAN", "의자를 정리하고", ["졸업장은 어디", "됐다"]), "깔끔이 — 졸업식 준비 200년째")
	t.eq(st.quests.stage("UQ-63"), 10, "단계 10")
	t.ok(_says(st, c, "UQ63_ROSTER", "✕", ["명부를 읽는다"]), "명부 — ✕ 한 줄")
	t.eq(_v(st, "UQ63_ROSTER"), 1, "읽음")
	_play(st, c, "UQ63_BOX", ["봉인을 뜯고", "명부 순서대로", "✕ 한 장은", "내 성씨 것 한 장도"])
	t.eq([_v(st, "UQ63_MATCH"), _v(st, "UQ63_LEFT"), _v(st, "UQ63_MINE"), st.count_of("M-443")], [1, 1, 1, 1], "맞춤 · ✕ · 내 성씨 · 묶음")
	t.ok(_says(st, c, "K-01_CLEAN", "승인은 — 됐습니다", ["졸업장은 어디", "됐다"]), "깔끔이 — 자동 승인")
	t.ok(_says(st, c, "K-02_LEAFLET", "입주는 못 했지만", ["✕ 졸업장 한 장"]), "해골 손에 한 장")
	t.eq(_v(st, "UQ63_LEFT"), 2, "밖에 둠")
	_intercom_open(st, c)
	t.ok(_says(st, c, "SQS03_INTERCOM", "집안 첫 어른이 33기", ["누른다", "졸업장 312장", "끊는다"]), "방금례 — 투입구 안내(63세 — 집안 첫 어른)")
	t.ok(_says(st, c, "UQ63_SLOT", "무게가 꽤 되네요", ["밀어 넣는다"]), "투입 — 즉시 스피커")
	t.eq([_v(st, "UQ63_IN"), st.count_of("M-443"), st.quests.stage("UQ-63")], [5, 0, 20], "넣음(20)")
	var kr := _v(st, "V_KARMA")
	c._uq63_day(5)
	t.eq(_v(st, "UQ63_DONE"), 0, "그날은 아직")
	c._uq63_day(6)
	t.eq([_v(st, "UQ63_DONE"), st.quests.stage("UQ-63"), _v(st, "V_KARMA") - kr], [1, 100, 25], "다음 06:00 — 맞춤 판 · 카르마 +25 · 100")
	st.vars.set_v("GAME_DAY", 6)
	var r := _play(st, c, "SQS03_INTERCOM", ["누른다", "끊는다"])
	t.ok(str(r[0]).contains("서른 가문") and str(r[0]).contains("311장") and str(r[0]).contains("당신 성씨"), "인터컴 결과 — 서른 가문 · 311장 · 내 성씨")
	t.eq(_v(st, "UQ63_SAID"), 1, "한 번")
	t.ok(not _says(st, c, "SQS03_INTERCOM", "서른 가문", ["누른다", "끊는다"]), "다시는 안 함")
	t.ok(_says(st, c, "K-01_CLEAN", "졸업생 본인님", ["됐다"]), "깔끔이 — 본인님(내 성씨 판)")
	t.ok(_says(st, c, "K-01_CLEAN", "청소 중입니다", ["됐다"]), "다음에 오면 청소")


func test_uq63_plain_and_self(t) -> void:
	var a := _host("K-01", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_play(st, c, "UQ63_BOX", ["봉인을 뜯고"])
	t.eq([_v(st, "UQ63_BOX"), _v(st, "UQ63_MATCH"), st.count_of("M-443")], [1, 0, 1], "명부 없이 — 그냥 챙김")
	t.eq(st.quests.stage("UQ-63"), 10, "보존함에서 10")
	t.ok(_has_opt(st, "UQ63_BOX", "내 등록 번호"), "묶음을 든 채 빈 보존함 — 빈 양식(313번째)")
	_put(st, {"SQ_S03_VAULT": 0})
	t.ok(_says(st, c, "UQ63_SLOT", "스피커는 조용하다", ["밀어 넣는다"]), "회선을 아직 안 받았으면 조용히 넣는다")
	t.ok(_says(st, c, "UQ63_SLOT", "종이 뭉치가 든"), "투입 당일 — 안에 든 소리")
	t.ok(_says(st, c, "SQS03_INTERCOM", "종이 뭉치가 들어 있대요", ["누른다", "끊는다"]), "회선 뒤 첫 통화 — 투입함 한 줄")
	c._uq63_day(6)
	t.eq(_v(st, "UQ63_DONE"), 2, "그냥 판")
	st.vars.set_v("GAME_DAY", 6)
	t.ok(_says(st, c, "SQS03_INTERCOM", "스물세 장", ["누른다", "끊는다"]), "방금례 — 성씨만 같은 스물세 장(밤새 대조)")
	t.ok(_says(st, c, "K-01_CLEAN", "확인되지 않습니다", ["됐다"]), "깔끔이 — 가문별 교부는 확인되지 않음 · 호칭은 방문객")
	t.ok(not _says(st, c, "K-01_CLEAN", "보호자님", ["됐다"]), "보호자님은 맞춤 판에만")


func test_uq63_lost_and_wait(t) -> void:
	var a := _host("K-01", "from_W")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_IN": 3, "UQ63_MET": 1})
	_play(st, c, "UQ63_ROSTER", ["명부를 읽는다"])
	var m0 := Clock.abs_min(h.date_text)
	_play(st, c, "UQ63_BOX", ["봉인을 뜯고", "한 장씩 대조", "그대로 다"])
	t.eq(_v(st, "UQ63_MATCH"), 2, "30분 대조")
	t.eq(Clock.abs_min(h.date_text) - m0, 30, "시계가 30분 간다")
	st.call_fn("take", ["M-443", 1])
	c._uq63_day(6)
	t.eq([_v(st, "UQ63_LOST"), st.quests.stage("UQ-63")], [1, 90], "잃음 — 90")
	t.ok(_says(st, c, "K-01_CLEAN", "교무과는… 없습니다", ["됐다"]), "깔끔이 — 재발급 없음 · 대장 귀띔")
	t.ok(_says(st, c, "UQ63_LEDGER", "졸업장보다 가볍다", ["수료 대장을 챙긴다"]), "수료 대장 — 두 번째 길")
	_put(st, {"SQ_S03_VAULT": 1})
	_play(st, c, "UQ63_SLOT", ["수료 대장을 밀어"])
	c._uq63_day(7)
	t.eq([_v(st, "UQ63_DONE"), st.quests.stage("UQ-63")], [3, 100], "호명만 — DONE 3 · 100")
	st.vars.set_v("GAME_DAY", 7)
	t.ok(_says(st, c, "SQS03_INTERCOM", "이름만", ["누른다", "끊는다"]), "방금례 — 번호 없이 이름만")


func test_uq63_late_match_and_dead_robot(t) -> void:
	var a := _host("K-01", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_IN": 5, "UQ63_MET": 1})
	_play(st, c, "UQ63_BOX", ["봉인을 뜯고"])
	t.ok(_says(st, c, "UQ63_ROSTER", "서른 묶음", ["명부를 읽는다"]) or _v(st, "UQ63_ROSTER") == 1, "명부 읽기")
	t.ok(_has_opt(st, "UQ63_ROSTER", "다시 묶는다"), "상자부터 연 사람 — 명부 앞에서 다시 묶기")
	_play(st, c, "UQ63_ROSTER", ["명부 순서대로 다시", "그대로 다 둔다"])
	t.eq(_v(st, "UQ63_MATCH"), 1, "늦게 맞춤")
	st.kill("N-R01-065")
	_put(st, {"SQ_S03_VAULT": 1})
	_play(st, c, "UQ63_SLOT", ["밀어 넣는다"])
	c._uq63_day(6)
	st.vars.set_v("GAME_DAY", 6)
	t.ok(_says(st, c, "SQS03_INTERCOM", "의자 세는 로봇", ["누른다", "끊는다"]), "깔끔이를 부순 사람 — 방금례가 한 줄")
