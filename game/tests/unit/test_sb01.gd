## 단계 1-12f FQ-SB-01 「출근부」(SD-04d §6.3, 계획 docs/seoul-fallout/_plans/1-12f_FQ-SB-01-02_plan.md §4 · §6):
## 받기 문턱(AFF_SB ≥ −19 · 모자라면 힌트) · 구만호 자리 한 값(04~06 마당 · 12시 실장실 · 일 동안 출근부실 · 꼬드김 30분) ·
## 3쪽(1쪽 빈칸 갈래 · 2쪽 빼기는 자리 비울 때만 · 3쪽 출동 명단) · 발각 씨앗 고정 · 다시 침(−5 · 몰수) / 대납(완납 비트) · 봉천 배수 ·
## 끊김(습격) · 대체 제공자(황두칠) · 쪽지 · 조만석(BC +8) · 추심 날(다음 달 3일).
extends RefCounted


func _host(map_id := "H-04", mark := "from_H-02", date := "2277. 10. 28.  10:00") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 6)
	st.vars.set_v("AFF_SB", -10)
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_CAPS", 2000)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = date
	var c := FqSb.new()
	c.setup(h)
	h.enter(map_id, mark)
	c.tick()
	return [h, st, c]


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
			if str(cur["name"]) == "sb01":
				c._cmd1(cur["args"], func() -> void: pass)
			elif str(cur["name"]) == "doc":
				LedgerCopy.type_now(st, [])
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


func _take(st: StoryState, c: FqSb) -> void:
	_play(st, c, "FQSB01_GU", ["게시판 쪽지", "하겠다"])


## 받기: 모자라면 거절(힌트) · 중립이면 받음(씨앗 = 오늘)
func test_sb01_offer(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	st.vars.set_v("AFF_SB", -25)
	t.ok(_said(_play(st, c, "FQSB01_GU", ["게시판 쪽지"])).contains("본소 일부터"), "AFF −25: 거절 + 힌트")
	t.eq(st.quests.stage("FQ-SB-01"), 0, "받지 않음")
	st.vars.set_v("AFF_SB", -10)
	var said := _said(_play(st, c, "FQSB01_GU", ["게시판 쪽지", "하겠다"]))
	t.ok(said.contains("서른 해 더 묵었어"), "2108 첫 장부 정합 줄")
	t.ok(said.contains("숫자만 세지"), "원문 대사")
	t.eq(st.quests.stage("FQ-SB-01"), 10, "받음 — 단계 10")
	t.eq(_v(st, "FQ_SB01_SEED"), 6, "씨앗 = 받은 날")
	t.eq(_v(st, "FQ_SB01_WHO"), 1, "구만호가 줌")


## 장부를 태웠으면(SB_DEBT 1) 첫 줄이 달라진다
func test_sb01_burnt_line(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	st.vars.set_v("SB_DEBT", 1)
	t.ok(_said(_play(st, r[2], "FQSB01_GU", ["됐다"])).contains("출근부는 안 탔어"), "태운 판 첫 줄")


## 구만호 자리: 일 동안 출근부실 · 04~06 마당 · 12시 실장실 · 사망이면 늘 비움
func test_sb01_where(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	t.eq(_v(st, "FQ_SB01_WHERE"), 0, "일 전: 2층 실장실")
	_take(st, c)
	c.tick()
	t.eq(_v(st, "FQ_SB01_WHERE"), 1, "일 동안: 출근부실 감독 책상")
	t.eq(_v(st, "FQ_SB01_AWAY"), 0, "보고 있다")
	h.date_text = "2277. 10. 28.  04:30"
	c.tick()
	t.eq(_v(st, "FQ_SB01_WHERE"), 2, "04~06: 마당")
	t.eq(_v(st, "FQ_SB01_AWAY"), 1, "비움")
	h.date_text = "2277. 10. 28.  12:20"
	c.tick()
	t.eq(_v(st, "FQ_SB01_WHERE"), 0, "12시: 실장실 점심")
	h.date_text = "2277. 10. 28.  14:00"
	c.tick()
	t.eq(_v(st, "FQ_SB01_AWAY"), 0, "다시 감독")
	st.kill("C-049")
	c.tick()
	t.eq(_v(st, "FQ_SB01_AWAY"), 1, "사망 — 늘 비움")


## 꼬드기기: 성공이면 30분 마당 · 실패면 의심(+10%p) · 하루 한 번
func test_sb01_lure(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_take(st, c)
	c._cmd1(["lure", 1], func() -> void: pass)
	c.tick()
	t.eq(_v(st, "FQ_SB01_WHERE"), 2, "꼬드김: 마당")
	t.ok(_said(_play(st, c, "FQSB01_GU")).contains("손님 어디 있어"), "마당에서 말 걸면 손님을 찾는다")
	h.date_text = "2277. 10. 28.  10:31"
	c.tick()
	t.eq(_v(st, "FQ_SB01_WHERE"), 1, "30분 뒤 돌아옴")
	t.eq(_v(st, "FQ_SB01_LURE_DAY"), 6, "오늘 썼다")
	c._cmd1(["lure", 0], func() -> void: pass)
	t.eq(_v(st, "FQ_SB01_SUS"), 1, "실패 = 의심")
	st.vars.set_v("FQ_SB01_X1", 1)
	t.ok(absf(c.catch_p() - 0.3) < 0.001, "하나 뺌 20% + 의심 10%p")


## 1쪽 빈칸 갈래 · 2쪽(보고 있으면 못 뺌) · 3쪽 출동 명단
func test_sb01_pages(t) -> void:
	var r := _host("H-02", "from_yard")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_take(st, c)
	var said := _said(_play(st, c, "FQSB01_TYPE", ["배차 없음"]))
	t.ok(said.contains("2077. 10. 23.") and said.contains("2108. 3. 1."), "1쪽: 2077 · 2108 줄")
	t.eq(_v(st, "FQ_SB01_BLANK"), 2, "빈칸 갈래")
	t.eq(_v(st, "FQ_SB01_TYPED"), 1, "1쪽 끝")
	t.eq(st.quests.stage("FQ-SB-01"), 20, "로그 20")
	t.ok(h.date_text.contains("11:00"), "한 시간")
	c.tick()
	LedgerCopy.type_now(st, ["1", "2"])
	t.eq(_v(st, "FQ_SB01_X1") + _v(st, "FQ_SB01_X2"), 0, "보고 있으면 못 뺀다")
	st.vars.set_v("FQ_SB01_TYPED", 1)
	h.date_text = "2277. 10. 28.  12:10"
	c.tick()
	LedgerCopy.type_now(st, ["1", "2", "6"])
	t.eq(_v(st, "FQ_SB01_X1") + _v(st, "FQ_SB01_X2") + _v(st, "FQ_SB01_X6"), 3, "비운 사이 셋 뺌")
	c._cmd1(["page", 2], func() -> void: pass)
	t.eq(st.quests.stage("FQ-SB-01"), 30, "로그 30")
	said = _said(_play(st, c, "FQSB01_TYPE"))
	t.ok(not said.contains("오봉수") and said.contains("오재윤"), "3쪽: 뺀 줄은 없고 남긴 줄은 있다")
	t.eq(_v(st, "FQ_SB01_TYPED"), 3, "3쪽 끝")


## 도장: 2쪽 전에만 · 찍은 줄은 옮길 줄이 아니다 · 15%
func test_sb01_stamp(t) -> void:
	var r := _host("H-02", "from_yard", "2277. 10. 28.  12:10")
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_take(st, c)
	c.tick()
	st.vars.set_v("FQ_SB01_DRAWER", 1)
	_play(st, c, "FQSB01_DRAWER", ["오영자", "서랍을 닫는다"])
	t.eq(_v(st, "FQ_SB01_PD5"), 1, "오영자 줄 완납")
	t.eq(_v(st, "FQ_SB01_STAMP"), 1, "도장 씀")
	LedgerCopy.type_now(st, ["5"])
	t.eq(_v(st, "FQ_SB01_X5"), 0, "도장 줄은 뺄 줄이 아니다")
	t.ok(absf(c.catch_p() - 0.15) < 0.001, "도장만 15%")
	t.ok(_said(_play(st, c, "FQSB01_DRAWER")).contains("늦었다"), "2쪽 뒤엔 늦음")


## 그대로 냄: SB +6 · 일당 · 250 XP · 추심 날(다음 달 3일) · 운송 알림
func test_sb01_submit_kept(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_take(st, c)
	st.vars.set_v("FQ_SB01_TYPED", 3)
	var sb := _v(st, "AFF_SB")
	var caps := _v(st, "PC_CAPS")
	var said := _said(_play(st, c, "FQSB01_GU"))
	t.ok(said.contains("다 있네"), "아홉 줄 다 있다")
	t.ok(said.contains("갈고리 찾아"), "운송 알림(중립)")
	t.eq(_v(st, "FQ_SB01_RES"), 1, "그대로")
	t.eq(_v(st, "AFF_SB") - sb, 6, "SB +6")
	t.eq(_v(st, "PC_CAPS") - caps, 100, "일당 100")
	t.eq(st.quests.stage("FQ-SB-01"), 100, "끝")
	t.eq(_v(st, "FQ_SB01_DUE_M"), 11, "다음 달")
	t.eq(_v(st, "FQ_SB01_DUE"), 12, "11. 3. = GAME_DAY 12(10. 28. = 6)")
	t.eq(_v(st, "FQ_SB02_TOLD"), 1, "SB-02 알림")
	t.eq(c.host.st.vars.get_v("FQ_SB01_WHERE"), 0, "끝나면 실장실로")


## 씨앗 고정: 같은 받은 날이면 늘 같은 판정 · 들키면 갈래(대납 · 다시 침)
func _caught_host() -> Array:
	for d in range(1, 60):
		var r := _host()
		var st: StoryState = r[1]
		var c: FqSb = r[2]
		st.vars.set_v("GAME_DAY", d)
		_take(st, c)
		for k in ["1", "2", "3", "4"]:
			st.vars.set_v("FQ_SB01_X" + k, 1)
		if c.caught():
			return r
	return []


func test_sb01_caught_payoff(t) -> void:
	var r := _caught_host()
	t.ok(not r.is_empty(), "들키는 씨앗이 있다(40%)")
	if r.is_empty():
		return
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	t.ok(c.caught() and c.caught(), "같은 씨앗은 같은 판정")
	st.vars.set_v("FQ_SB01_TYPED", 3)
	var caps := _v(st, "PC_CAPS")
	var said := _said(_play(st, c, "FQSB01_GU", ["빈 줄 빚을 내가 낸다"]))
	t.ok(said.contains("줄이 비었어") and said.contains("다시 칠래, 네가 낼래"), "발각 갈래")
	t.eq(caps - _v(st, "PC_CAPS"), 180 + 200 + 60 + 90 - 100, "대납 530 − 일당 100")
	t.eq(_v(st, "FQ_SB01_RES"), 4, "대납")
	t.eq(_v(st, "FQ_SB01_PD1") + _v(st, "FQ_SB01_PD4"), 2, "산 줄은 완납 비트")
	t.eq(_v(st, "FQ_SB01_X1"), 0, "뺀 줄 표시는 지움")
	var enc := Encounters.new(st)
	t.eq(enc.sb01_bc(SideS02.BC_CENTER), 0.5, "대납도 봉천 배수")


func test_sb01_caught_retype(t) -> void:
	var r := _caught_host()
	if r.is_empty():
		t.ok(false, "들키는 씨앗")
		return
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	st.vars.set_v("FQ_SB01_TYPED", 3)
	var sb := _v(st, "AFF_SB")
	var caps := _v(st, "PC_CAPS")
	_play(st, c, "FQSB01_GU", ["다시 친다"])
	t.eq(_v(st, "FQ_SB01_RES"), 3, "다시 침")
	t.eq(_v(st, "AFF_SB") - sb, -5, "SB −5")
	t.eq(_v(st, "PC_CAPS") - caps, 0, "일당 몰수")
	t.eq(_v(st, "FQ_SB01_X1"), 0, "빈 줄은 빨간펜이 채움")
	t.eq(Encounters.new(st).sb01_bc(SideS02.BC_CENTER), 1.0, "빈도 그대로")


## 안 들키고 뺌: RES 2 · 봉천 반경만 ×0.5 · 조만석 BC +8(한 번)
func test_sb01_clean_and_told(t) -> void:
	for d in range(1, 60):
		var r := _host()
		var st: StoryState = r[1]
		var c: FqSb = r[2]
		st.vars.set_v("GAME_DAY", d)
		_take(st, c)
		st.vars.set_v("FQ_SB01_X4", 1)
		if c.caught():
			continue
		st.vars.set_v("FQ_SB01_TYPED", 3)
		t.ok(_said(_play(st, c, "FQSB01_GU")).contains("봉천 줄이 적네"), "안 들킴 줄")
		t.eq(_v(st, "FQ_SB01_RES"), 2, "RES 2")
		var enc := Encounters.new(st)
		t.eq(enc.sb01_bc(SideS02.BC_CENTER), 0.5, "봉천 ×0.5")
		t.eq(enc.sb01_bc(Vector2i(628, 1348)), 1.0, "본소 쪽은 그대로")
		var bc := _v(st, "AFF_JC_BC") if st.vars.has("AFF_JC_BC") else _v(st, "AFF_BC")
		var said := _said(_play(st, c, "FQSB01_JO", ["봉천 이름을 뺐다"]))
		t.ok(said.contains("남건희 그놈"), "남건희를 뺐으면 이장 한 줄")
		var bc2 := _v(st, "AFF_JC_BC") if st.vars.has("AFF_JC_BC") else _v(st, "AFF_BC")
		t.eq(bc2 - bc, 8, "BC +8")
		t.eq(_v(st, "FQ_SB01_TOLD"), 1, "한 번")
		return
	t.ok(false, "안 들키는 씨앗")


## 습격 = 끊김 · 구만호 사망이면 황두칠 · 쪽지
func test_sb01_cut_and_fallback(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	var dr := DialogueRunner.new(st)
	var said := ""
	var cur := dr.start(_scene("X-SB_BOARD"))
	while cur["type"] != "end":
		if cur.has("text"):
			said += str(cur["text"])
		cur = dr.advance()
	t.ok(said.contains("장부 정리 일용직"), "칠판 쪽지")
	_take(st, c)
	st.vars.set_v("SB_RAID", 1)
	c.tick()
	t.eq(st.quests.stage("FQ-SB-01"), 200, "습격 = 끊김")
	var r2 := _host()
	var st2: StoryState = r2[1]
	st2.kill("C-049")
	t.ok(StoryExpr.test(str(_scene("FQSB01_HDC")["cond"]), st2), "구만호 사망 → 황두칠 장면")
	_play(st2, r2[2], "FQSB01_HDC", ["하겠다"])
	t.eq(_v(st2, "FQ_SB01_WHO"), 2, "황두칠이 줌")


## 서사 정합(1-12f 재검수): 3쪽 출동 명단의 날짜는 치는 순간 정해지고, 종이에 적힌 날과 봉천에 추심원이 서는 날이 한 값
func test_sb01_due_on_page3(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: FqSb = r[2]
	_take(st, c)
	st.vars.set_v("FQ_SB01_TYPED", 2)
	var said := _said(_play(st, c, "FQSB01_TYPE"))
	t.eq(_v(st, "FQ_SB01_DUE_M"), 11, "3쪽을 치는 순간 날짜가 선다(다음 달)")
	var due := _v(st, "FQ_SB01_DUE")
	t.ok(said.contains("11월 3일"), "서식 머리: 11월 3일(하루)")
	t.ok(not said.contains("11. 5.") and not said.contains("11. 8."), "줄마다 다른 날짜 없음")
	st.vars.set_v("FQ_SB01_TYPED", 3)
	(r[0] as InteriorHost).date_text = "2277. 11. 02.  10:00"           # 한 달 가까이 지나 내도
	_play(st, c, "FQSB01_GU")
	t.eq(_v(st, "FQ_SB01_DUE"), due, "낸 날이 늦어도 종이에 적힌 날 그대로")


## 1-12f 서사 대조(계획 §6.5 #45~59): 조만석 남건희 줄은 SQ-S02가 밝힌 것만 · 마을을 판 판은 차갑게 · 3쪽 사망 줄은 유족 승계 ·
## 장부를 태운 손 / 없어진 장부 / 목걸이 찬 목 · 줄 수 말은 뺀 줄이 없을 때만
func test_sb01_narrative_fixes(t) -> void:
	for d in range(1, 60):
		var r := _host()
		var st: StoryState = r[1]
		var c: FqSb = r[2]
		st.vars.set_v("GAME_DAY", d)
		_take(st, c)
		st.vars.set_v("FQ_SB01_X4", 1)
		if c.caught():
			continue
		st.vars.set_v("FQ_SB01_TYPED", 3)
		_play(st, c, "FQSB01_GU")
		var said := _said(_play(st, c, "FQSB01_JO", ["봉천 이름을 뺐다"]))
		t.ok(said.contains("입이 가벼워") and not said.contains("윗문"), "SQ-S02 전: '윗문 밖' 비밀은 말하지 않는다(P2)")
		st.vars.set_v("FQ_SB01_TOLD", 0)
		st.vars.set_v("SQ_S02_IN", 1)
		t.ok(_said(_play(st, c, "FQSB01_JO", ["봉천 이름을 뺐다"])).contains("봉천 사람이 아니야"), "쫓아낸 판")
		st.vars.set_v("FQ_SB01_TOLD", 0)
		st.vars.set_v("SQ_S02_IN", 2)
		t.ok(_said(_play(st, c, "FQSB01_JO", ["봉천 이름을 뺐다"])).contains("대장간"), "타이른 판")
		st.vars.set_v("FQ_SB01_TOLD", 0)
		st.vars.set_v("MQ101_RESULT", 5)
		t.ok(_said(_play(st, c, "FQSB01_JO", ["봉천 이름을 뺐다"])).contains("봉천을 판 손"), "마을을 판 판은 차갑게")
		break
	# 3쪽: 죽은 사람 줄은 유족 승계
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: FqSb = r2[2]
	_take(st2, c2)
	st2.kill("N-R01-035")
	st2.vars.set_v("FQ_SB01_TYPED", 2)
	var p3 := _said(_play(st2, c2, "FQSB01_TYPE"))
	t.ok(p3.contains("오재윤(사망 — 유족 승계)"), "3쪽 사망 줄")
	t.ok(p3.contains("남은 집마다 추심원 하나"), "출동 인원은 남은 줄 수대로")
	# 장부 상태에 따른 첫 줄
	var r3 := _host()
	var st3: StoryState = r3[1]
	st3.vars.set_v("SB_DEBT", 1)
	t.ok(_said(_play(st3, r3[2], "FQSB01_GU", ["됐다"])).contains("태운 손이 그 손"), "태운 사람을 알아본다")
	st3.vars.set_v("SB_DEBT", 0)
	st3.vars.set_v("HO_LEDGER", 1)
	t.ok(_said(_play(st3, r3[2], "FQSB01_GU", ["됐다"])).contains("금고에서 없어졌다며"), "계엄군에 넘긴 판도 같은 줄(누가 가졌는지는 말 안 함)")
	st3.vars.set_v("SB_COLLAR", 1)
	t.ok(_said(_play(st3, r3[2], "FQSB01_GU")).contains("번호 찬 목"), "목걸이 찬 채면 일을 주지 않는다")
	t.eq(st3.quests.stage("FQ-SB-01"), 0, "받지 않음")
	# 감사 줄: 장부가 정착지 손이면 '문 밖 명단' · 보낼 사람이 없으면 열리지 않음
	var st5 := StoryState.new()
	st5.load_data()
	st5.quests.set_stage("MQ-101", 100)
	for k in [["V_ACT", 1], ["FQ_SB01_DUE", 40], ["GAME_DAY", 41], ["FQ_SB01_X5", 1], ["FQ_SB01_RES", 2], ["HO_LEDGER", 81]]:
		st5.vars.set_v(k[0], k[1])
	var thx: Dictionary = _scene("FQSB01_THX5")
	t.ok(StoryExpr.test(str(thx["cond"]), st5), "감사 줄 열림")
	t.ok(_said(_play(st5, c2, "FQSB01_THX5")).contains("문 밖에서 명단"), "출입 금지 판: 문 밖 명단")
	for who in ["C-049", "C-013", "C-021"]:
		st5.kill(who)
	t.ok(not StoryExpr.test(str(thx["cond"]), st5), "보낼 사람이 없으면 '건너뛰더라'도 없다")


## 1-12f 서사 대조(#48~52): 추심 날 X-BC — 죽은 사람은 유족 바크 · 장부가 정착지 손이면 문 밖 하나 · 보낼 사람이 없으면 없음
func test_sb01_due_day_map(t) -> void:
	var mp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/X-BC.json"))
	var st := StoryState.new()
	st.load_data()
	st.quests.set_stage("MQ-101", 100)
	st.vars.set_v("FQ_SB01_DUE", 40)
	st.vars.set_v("GAME_DAY", 40)
	st.vars.set_v("GAME_HOUR", 10)
	var shown := func() -> Array:
		var out := []
		for n in mp["npcs"]:
			if str(n["id"]) in ["CR-436", "CR-437"] and StoryExpr.test(str(n.get("cond", "")), st):
				out.append(str(n.get("bark", "")))
		return out
	var b: Array = shown.call()
	t.eq(b.size(), 6, "다섯 집 + 번호 줄")
	t.ok(not " ".join(b).contains("윗문"), "추심원은 남건희의 밤길을 모른다")
	t.ok(not " ".join(b).contains("218"), "번호 줄은 번호를 읽지 않는다")
	st.kill("N-R01-026")
	b = shown.call()
	t.ok(" ".join(b).contains("고철 선금 180 — 유족 승계"), "죽은 오봉수 집은 유족 바크")
	t.eq(b.size(), 6, "같은 자리 하나만(배타)")
	st.vars.set_v("HO_LEDGER", 81)
	b = shown.call()
	t.eq(b.size(), 1, "장부가 봉천 손: 아랫문 밖 하나")
	t.ok(str(b[0]).contains("출입 금지?"), "실랑이 바크")
	st.vars.set_v("HO_LEDGER", 0)
	for who in ["C-049", "C-013", "C-021"]:
		st.kill(who)
	t.eq((shown.call() as Array).size(), 0, "보낼 사람이 없으면 추심조 없음")
