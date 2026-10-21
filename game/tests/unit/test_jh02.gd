## 단계 1-12d FQ-JH-02 「2077년 외상 장부」(SD-04d §8.4, 계획 docs/seoul-fallout/_plans/1-12c_FQ-JH-01-03_plan.md §2 · §4):
## 네 번째 장부(훅) · 부탁(나중에도 10) · S08 단축 · 소민서 귀띔(P7) · 먼저 만나도 따라 올림(P2) · 환산 36/60 · 지폐 · 대납 ·
## 거짓 → 7일 소문 → 들킴 −5 · 사흘 단골 값 끊김 · 코트 반품 농담 · 호위(지상 한 청크 · 버려두면 하루 뒤 혼자) · 운반조 길 다음 날 06시 ·
## 재회(보상 한 번 · 가게 B-07 / 광장) · 탁만수 죽음 = 덮음 · 노복희 죽음 = 실패.
extends RefCounted


func _host(map_id := "J-03", mark := "from_J-02") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 5)
	st.vars.set_v("GAME_HOUR", 10)
	st.vars.set_v("AFF_JH", 10)
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_CAPS", 200)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 28.  10:00"
	var c := FqJh.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: FqJh, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "jh01":
				c._cmd1(cur["args"], func() -> void: pass)
			elif str(cur["name"]) == "jh02":
				c._cmd2(cur["args"], func() -> void: pass)
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


func _says(st: StoryState, c: FqJh, id: String, needle: String, picks: Array = []) -> bool:
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


## 훅 → 부탁(단계 10) → 노복희가 B구역 말고 고터 쪽 사람이라고만 → 소민서(P7) → 20 → 고터에서 만남 → 30
func _ask(st: StoryState, c: FqJh) -> void:
	_play(st, c, "FQJH02_LEDGER")
	_play(st, c, "MQ-103_BOK", ["장부 마지막 줄", "자세히 듣는다"])


func test_jh02_hook_and_catch_up(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: FqJh = a[2]
	t.ok(not _has_opt(st, "MQ-103_BOK", "장부 마지막 줄"), "장부 줄을 보기 전엔 노복희 메뉴에 없다")
	t.ok(_says(st, c, "FQJH02_LEDGER", "180,000"), "네 번째 장부 마지막 줄")
	t.eq(_v(st, "FQ_JH02_SEEN"), 1, "훅 = 봄")
	t.ok(_says(st, c, "MQ-103_BOK", "장부는 안 도망가", ["장부 마지막 줄", "나중에"]), "부탁 — 나중에")
	t.eq(st.quests.stage("FQ-JH-02"), 10, "'나중에'도 로그에 남는다(단계 10)")
	t.ok(_says(st, c, "MQ-103_BOK", "탁만수 소식은", ["장부 마지막 줄"]), "다시 물으면 메뉴(탁만수 소식은?)")
	t.ok(_says(st, c, "U04_SOMIN", "", ["구두 고치는 구울"]) or _v(st, "FQ_JH02_KNOW") == 1, "소민서 귀띔")
	t.eq(_v(st, "FQ_JH02_KNOW"), 1, "P7 출처 — 소민서")
	t.eq(st.quests.stage("FQ-JH-02"), 20, "20 고터 지하상가")
	t.ok(_says(st, c, "GT_TAK", "18만 원이었지"), "고터 탁만수: 원문 대사")
	t.eq(st.quests.stage("FQ-JH-02"), 30, "30 코트를 입고 있다")
	# S08 단축(D-126): 명부 대장에서 바로 찾는다
	var b := _host()
	var st2: StoryState = b[1]
	st2.vars.set_v("SQ_S08_SOL", 1)
	_ask(st2, b[2])
	t.eq(st2.quests.stage("FQ-JH-02"), 20, "S08 끝냈으면 10 → 20 한 번에")
	# 먼저 만나고 나중에 부탁(P2 '이미 앎')
	var d := _host()
	var st3: StoryState = d[1]
	var c3: FqJh = d[2]
	t.ok(_says(st3, c3, "GT_TAK", "빚진 데가 있어", ["오래돼 보이네요"]), "부탁 전 — '빚진 데가 있어'만")
	t.eq(st3.quests.stage("FQ-JH-02"), 0, "만나기만 하면 퀘스트는 안 열린다")
	_ask(st3, c3)
	c3.tick(0.5)
	t.eq(st3.quests.stage("FQ-JH-02"), 30, "이미 만났으면 받자마자 30까지")


func test_jh02_caps_bills_sub(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: FqJh = a[2]
	_ask(st, c)
	_play(st, c, "GT_TAK", ["캡으로 셈해", "서른여섯 캡으로"])
	t.eq(_v(st, "FQ_JH02_PAY"), 36, "탁만수가 36캡을 맡긴다")
	t.eq(_v(st, "PC_CAPS"), 236, "맡긴 캡이 주머니에")
	var jh := _v(st, "AFF_JH")
	t.ok(_says(st, c, "MQ-103_BOK", "200년 걸렸네", ["장부 마지막 줄", "[캡 36]"]), "노복희: 원문 대사")
	t.eq(st.quests.stage("FQ-JH-02"), 100, "정리 = 100")
	t.eq(_v(st, "AFF_JH") - jh, 6, "JH +6")
	t.eq(_v(st, "PC_CAPS"), 200, "36캡을 건넸다")
	t.eq(int(st.items.get("A-019", 0)), 1, "A-019 장사꾼 코트")
	t.eq(_v(st, "FQ_JH02_SOL"), 2, "환산")
	t.ok(not _has_opt(st, "MQ-103_BOK", "장부 마지막 줄"), "끝나면 메뉴 줄이 사라진다")
	c._solve(3)
	t.eq(_v(st, "AFF_JH") - jh, 6, "두 번째 정리는 보상 없음(P1)")
	t.ok(_says(st, c, "GT_TAK", "반값"), "탁만수: 받았대? 반값")
	# 지폐
	var b := _host()
	var st2: StoryState = b[1]
	var c2: FqJh = b[2]
	_ask(st2, c2)
	st2.call_fn("give", ["M-002", 18])
	t.ok(_says(st2, c2, "MQ-103_BOK", "제일 맞는 돈", ["장부 마지막 줄", "만 원짜리"]), "만 원짜리 열여덟 장")
	t.eq(_v(st2, "FQ_JH02_SOL"), 4, "지폐")
	t.eq(int(st2.items.get("M-002", 0)), 0, "지폐를 건넸다")
	t.ok(_says(st2, c2, "FQJH02_LEDGER", "만 원짜리 지폐 끝"), "장부 사이에 지폐가 남는다(F5)")
	# 대납
	var d := _host()
	var st3: StoryState = d[1]
	var c3: FqJh = d[2]
	_ask(st3, c3)
	t.ok(_says(st3, c3, "MQ-103_BOK", "빚은 그 사람 거니까", ["장부 마지막 줄", "대신 갚겠습니다"]), "대납")
	t.eq(_v(st3, "PC_CAPS"), 140, "대납 60캡")
	t.eq(_v(st3, "FQ_JH02_SOL"), 3, "대납")


func test_jh02_lie_rumor_coat(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh = a[2]
	_ask(st, c)
	var jh := _v(st, "AFF_JH")
	_play(st, c, "MQ-103_BOK", ["장부 마지막 줄", "갚았대요"])
	t.eq(_v(st, "FQ_JH02_SOL"), 5, "거짓")
	t.eq(_v(st, "AFF_JH") - jh, 6, "거짓도 JH +6 즉시")
	st.vars.set_v("GAME_DAY", 11)
	c._day2()
	t.eq(_v(st, "FQ_JH02_RUMOR"), 0, "6일째 — 아직 소문 없음")
	st.vars.set_v("GAME_DAY", 12)
	c._day2()
	t.eq(_v(st, "FQ_JH02_RUMOR"), 1, "7일째 — 고터 운반조 소문")
	h.enter("J-03", "from_J-02")
	var r := false
	for n in h.npcs:
		r = r or str(n["id"]) == "N-J03-R1"
	t.ok(r, "소문의 출처가 광장에 서 있다(P7)")
	t.ok(_says(st, c, "MQ-103_BOK", "사람은 안 맞췄네"), "노복희: 들킴")
	t.eq(_v(st, "AFF_JH") - jh, 1, "들키면 −5")
	t.ok(_says(st, c, "MQ-103_BOK", "단골 값은 없어", ["물건을 보고"]), "사흘 단골 값 끊김")
	st.vars.set_v("GAME_DAY", 15)
	t.ok(not _says(st, c, "MQ-103_BOK", "단골 값은 없어", ["물건을 보고"]), "사흘 뒤 풀림")
	_play(st, c, "MQ-103_BOK")
	t.eq(_v(st, "AFF_JH") - jh, 1, "들킴은 한 번")
	# 코트 반품 농담
	var b := _host()
	var st2: StoryState = b[1]
	var c2: FqJh = b[2]
	_ask(st2, c2)
	_play(st2, c2, "GT_TAK", ["코트를 돌려드리는"])
	t.eq(_v(st2, "FQ_JH02_COAT"), 1, "[화술] 코트를 벗었다")
	t.eq(int(st2.items.get("M-424", 0)), 1, "M-424")
	t.ok(_says(st2, c2, "MQ-103_BOK", "반품 안 받아", ["장부 마지막 줄", "반품하러"]), "노복희: 200년 입은 옷은 반품 안 받아")
	t.eq(int(st2.items.get("M-424", 0)), 1, "코트는 돌려받았다")
	t.eq(_v(st2, "FQ_JH02_COAT"), 2, "돌려보냄")
	t.ok(_says(st2, c2, "GT_TAK", "몸이 맞네", ["코트를 돌려준다"]), "탁만수가 다시 입는다")
	t.eq(_v(st2, "FQ_JH02_COAT"), 3, "주인에게")
	t.eq(int(st2.items.get("M-424", 0)), 0, "코트를 건넸다")


func test_jh02_escort_reunion(t) -> void:
	var a := _host("GT-01", "from_W")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh = a[2]
	_ask(st, c)
	_play(st, c, "GT_TAK", ["직접 가서 갚으세요"])
	t.eq(_v(st, "FQ_JH02_TAK"), 2, "호위 시작")
	t.ok(not c._tak_mate().is_empty(), "탁만수가 곁에(호위 대상)")
	h.player.loco.logical = (c._tak_mate()["actor"] as Actor).loco.logical + Vector2(32, 0)   # 말을 건 자리(곁)
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH02_NEAR"), 1, "곁에 있음")
	t.ok(_says(st, c, "GT_YARD", "23시 40분"), "승차장: 영등포 막차 앞에서 멈춘다")
	t.eq(_v(st, "FQ_JH02_YARD"), 1, "승차장 장면 한 번")
	t.ok(_says(st, c, "GT_TUNNEL", "사다리를 내려간다"), "맨홀: 혼자 지하로")
	t.eq(_v(st, "FQ_JH02_TAK"), 3, "운반조 길")
	t.ok(c._tak_mate().is_empty(), "동행 끝")
	c._day2()
	t.eq(_v(st, "FQ_JH02_TAK"), 3, "같은 날엔 아직 길 위")
	st.vars.set_v("GAME_DAY", 6)
	c._day2()
	t.eq(_v(st, "FQ_JH02_TAK"), 4, "다음 날 06시 — J-03 칸막이 앞")
	h.enter("J-03", "from_J-02")
	var here := false
	for n in h.npcs:
		here = here or str(n["id"]) == "N-UG-501"
	t.ok(here, "칸막이 앞에 탁만수")
	var jh := _v(st, "AFF_JH")
	t.ok(_says(st, c, "GT_TAK", "단추 하나 바꿔 달았네", ["손님 오셨어요"]), "재회")
	t.eq(st.quests.stage("FQ-JH-02"), 100, "재회 = 100")
	t.eq(_v(st, "AFF_JH") - jh, 6, "JH +6")
	t.eq(_v(st, "FQ_JH02_SHOP"), 2, "JH-01 안 끝남 — 광장 노점")
	t.eq(int(st.items.get("A-019", 0)), 1, "A-019")
	h.enter("J-03", "from_J-02")
	var stall := false
	for n in h.npcs:
		stall = stall or (str(n["id"]) == "N-UG-501" and n["actor"].loco.logical.distance_to(Vector2(34 * 32 + 16, 11 * 32 + 16)) < 8.0)
	t.ok(stall, "광장 노점에 탁만수(한 곳, P3)")
	# 대납 뒤에 데려와도 재회가 결과 · 보상은 한 번
	var b := _host("GT-01", "from_W")
	var st2: StoryState = b[1]
	var c2: FqJh = b[2]
	_ask(st2, c2)
	st2.quests.set_stage("FQ-JH-01", 100)
	_play(st2, c2, "MQ-103_BOK", ["장부 마지막 줄", "대신 갚겠습니다"])
	var jh2 := _v(st2, "AFF_JH")
	_play(st2, c2, "GT_TAK", ["얼굴은 아직이잖아요"])
	t.eq(_v(st2, "FQ_JH02_TAK"), 2, "정리 뒤에도 데려갈 수 있다")
	c2._cmd2(["tunnel"], func() -> void: pass)
	st2.vars.set_v("GAME_DAY", 6)
	c2._day2()
	_play(st2, c2, "GT_TAK", ["손님 오셨어요"])
	t.eq(_v(st2, "AFF_JH") - jh2, 0, "재회 보상은 없음(이미 100)")
	t.eq(_v(st2, "FQ_JH02_SOL"), 1, "재회가 마지막 사실")
	t.eq(_v(st2, "FQ_JH02_SHOP"), 1, "JH-01 끝 — B-07")
	t.eq(int(st2.items.get("A-019", 0)), 1, "코트는 한 벌")


func test_jh02_abandon_death_fail(t) -> void:
	var a := _host("GT-01", "from_W")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh = a[2]
	_ask(st, c)
	_play(st, c, "GT_TAK", ["직접 가서 갚으세요"])
	h.player.loco.logical = Vector2(40 * 32 + 16, 16 * 32 + 16)            # 멀리 두고 감
	c.tick(0.5)
	st.vars.set_v("GAME_DAY", 6)
	c._day2()
	t.eq(_v(st, "FQ_JH02_TAK"), 3, "하루 뒤 '혼자 갈게'")
	t.ok(c._tak_mate().is_empty(), "동행에서 빠짐")
	st.vars.set_v("GAME_DAY", 7)
	c._day2()
	t.eq(_v(st, "FQ_JH02_TAK"), 4, "그다음 날 J-03")
	# 탁만수 죽음 = 장부를 덮는다
	var b := _host()
	var st2: StoryState = b[1]
	var c2: FqJh = b[2]
	_ask(st2, c2)
	st2.kill("N-UG-501")
	var jh := _v(st2, "AFF_JH")
	t.ok(_says(st2, c2, "MQ-103_BOK", "줄은 줄이 아니야", ["장부 마지막 줄"]), "노복희: 그냥 덮지")
	t.eq(st2.quests.stage("FQ-JH-02"), 200, "덮음 = 200")
	t.eq(_v(st2, "AFF_JH") - jh, 2, "다른 결과 JH +2")
	t.eq(int(st2.items.get("A-019", 0)), 0, "코트 없음")
	t.ok(_says(st2, c2, "GT_BOARD", "검은 리본"), "고터 공고판에 검은 리본")
	# 노복희 죽음 = 실패(진행 중)
	var d := _host()
	var st3: StoryState = d[1]
	var c3: FqJh = d[2]
	_ask(st3, c3)
	st3.kill("C-050")
	c3.tick(0.5)
	t.eq(st3.quests.stage("FQ-JH-02"), 200, "노복희가 죽으면 상인회가 장부를 덮는다")
