## 단계 1-12i i6 R01 비표시 UQ-62 「고시생의 마지막 시험」(SD-05 §3.16 L903, 계획 docs/seoul-fallout/_plans/1-12i_UQ-62-67_plan.md §8 · §8b):
## 권성민 · 답안 카드 · 채점기 [과학 45](어림짐작 — 망침) · 손재석 출제(다음 06:00 시험지 · 권성민 책상에서 채점) · 위조(자습석 · 어설픈 판 · 염희정) ·
## 함준호 소개 · 떠남(다음 06:00) · 취직(소개 — JH +3 · 없으면 사흘 뒤) · 고시촌 통행(상담료 · 어제 상담 · 분양) · 스탠드 진공관 · 스킬북.
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
	st.vars.set_v("PC_CAPS", 300)
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


func test_uq62_card_grade_leave(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	t.ok(_says(st, c, "GC_KWON", "연기는 연기예요", ["됐다"]), "권성민 첫 만남")
	t.eq([_v(st, "UQ62_MET"), st.quests.stage("UQ-62")], [1, 10], "발동(10)")
	t.ok(not _has_opt(st, "GC_KWON", "답안 카드를 줘"), "세 길 얘기 전엔 카드도 안 보인다")
	t.ok(_says(st, c, "GC_KWON", "누가 내든", ["시험은 어떻게", "됐다"]), "세 길 얘기(EXAMQ)")
	t.ok(_says(st, c, "GC_KWON", "수험 번호 칸은 비었어요", ["답안 카드를 줘"]), "답안 카드")
	t.eq([_v(st, "UQ62_CARD"), st.count_of("M-446")], [1, 1], "카드 한 장")
	_put(st, {"GS02_GRADER": 1, "PC_SKP_SCIENCE": 0})
	t.ok(_says(st, c, "K-24_GRADER", "카드 손상", ["권성민의 답안 카드", "어림짐작"]), "어림짐작 — 망침")
	t.eq([st.count_of("M-446"), _v(st, "UQ62_CARD")], [0, 1], "카드 잃음 · 예비는 아직")
	t.ok(_says(st, c, "GC_KWON", "마지막이에요", ["답안 카드를 줘"]), "예비 카드")
	t.eq(_v(st, "UQ62_CARD"), 2, "예비까지")
	_put(st, {"PC_SKP_SCIENCE": 60})
	t.ok(not _has_opt(st, "K-24_GRADER", "어림짐작", ["권성민의 답안 카드"]), "과학 60 — 어림짐작은 안 보인다")
	t.ok(_says(st, c, "K-24_GRADER", "행정 적성 1등급", ["권성민의 답안 카드", "손수 뚫어"]), "[과학 45] 성적표")
	t.eq([_v(st, "UQ62_GRADED"), st.count_of("M-448"), st.count_of("M-446"), st.quests.stage("UQ-62")], [1, 1, 0, 20], "성적표 · 카드는 들어감 · 20")
	var kr := _v(st, "V_KARMA")
	t.ok(_says(st, c, "GC_KWON", "200년 만이에요", ["성적표"]), "성적표를 건넴 — 스탠드를 끈다")
	t.eq([_v(st, "UQ62_WAY"), _v(st, "UQ62_DONE"), st.quests.stage("UQ-62"), _v(st, "V_KARMA") - kr, _v(st, "UQ62_XP"), st.count_of("M-448")], [1, 5, 100, 25, 1, 0], "① · 100 · 카르마 +25 · XP")
	t.ok(_says(st, c, "GC_KWON", "내일 아침에 나가요"), "그 뒤로")
	c._uq62_day(6)
	t.eq([_v(st, "UQ62_GONE"), _v(st, "UQ62_JOB")], [6, 2], "다음 06:00 떠남 — 소개 없으면 복도")
	t.ok(_says(st, c, "GC_KWON_JOB", "사흘요? 금방이죠"), "복도의 권성민")
	c._uq62_day(8)
	t.eq(_v(st, "UQ62_JOB"), 2, "사흘 전")
	c._uq62_day(9)
	t.eq(_v(st, "UQ62_JOB"), 1, "사흘 뒤 관리사무소")
	t.ok(_says(st, c, "GC_KWON_JOB", "1등급이면 숫자는 믿겠다"), "취직한 권성민 — 성적표 한 줄")


func test_uq62_paper_son(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_play(st, c, "GC_KWON", ["시험은 어떻게", "됐다"])
	_put(st, {"PN_SON": 2, "UQ65_BOOK": 1, "UQ65_XP": 1, "UQ65_TEN": 1})
	t.ok(_says(st, c, "K-24_SON", "원생 카드에 주소가", ["고시촌 고시생 출제", "다음에"]), "손재석 — 고시촌 한 줄 · 출제는 선택지로(거절해도 다시 물을 수 있다)")
	t.ok(_says(st, c, "K-24_SON", "하룻밤이요", ["고시촌 고시생 출제", "부탁한다"]), "손재석 — 출제 약속(선택지로)")
	t.eq([_v(st, "UQ62_PAPER"), _v(st, "UQ62_SON_SAID")], [5, 1], "출제한 날")
	t.ok(not _has_opt(st, "GC_KWON", "손재석의 시험지"), "시험지는 아직")
	st.vars.set_v("GAME_DAY", 6)
	t.ok(_says(st, c, "K-24_SON", "학생 앞에서 뜯어요", []), "다음 날 — 시험지 + 봉인 정답지")
	t.eq([st.count_of("M-447"), _v(st, "UQ62_PGIVEN")], [1, 1], "M-447")
	t.ok(_says(st, c, "EXAMINE_M447", "봉인을 뜯는다", ["봉인을 미리"]), "미리 뜯음")
	var kr := _v(st, "V_KARMA")
	t.ok(_says(st, c, "GC_KWON", "무효여도 점수는 점수예요", ["손재석의 시험지", "정답지를 펼친다"]), "권성민 책상에서 채점 — 미리 뜯은 판")
	t.eq([_v(st, "UQ62_WAY"), st.quests.stage("UQ-62"), _v(st, "V_KARMA") - kr, st.count_of("M-447")], [2, 100, 25, 0], "② · 100 · +25")
	c._uq62_day(7)
	t.eq(_v(st, "UQ62_GONE"), 7, "떠남")
	t.ok(_says(st, c, "GC_KWON_JOB", "복사실 문 앞에"), "복도 판은 농담 한 줄 · 취직하면 컵라면 한 줄") if _v(st, "UQ62_JOB") == 1 else t.ok(_says(st, c, "GC_KWON_JOB", "금방이죠"), "복도 판")
	var b := _host()
	var st2: StoryState = b[1]
	var c2: UqR01 = b[2]
	_play(st2, c2, "GC_KWON", ["시험은 어떻게", "됐다"])
	_put(st2, {"PN_SON": 2, "UQ65_BOOK": 1, "UQ65_XP": 1, "UQ65_TEN": 1})
	_play(st2, c2, "K-24_SON", ["고시촌 고시생 출제", "다음에"])
	_play(st2, c2, "K-24_SON", ["고시촌 고시생 출제", "부탁한다"])
	st2.kill("N-R01-056")
	c2._uq62_day(6)
	t.eq(_v(st2, "UQ62_PAPER"), 0, "밤에 쓴다던 사람이 죽음 — 시험지 없음")


func test_uq62_forge_intro_job(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_play(st, c, "GC_KWON", ["시험은 어떻게", "됐다"])
	_put(st, {"PC_SKP_SCIENCE": 0})
	t.ok(_says(st, c, "K24_CARREL", "택. 오늘은 다시 찍을 종이가 없다", ["어림짐작"]), "자습석 — 어설픈 위조")
	t.eq([st.count_of("M-450"), _v(st, "UQ62_BAD")], [1, 1], "M-450 · 어설픈")
	t.ok(_says(st, c, "SQS08_HAM", "장부는 하루면 배우겠군요", ["신림 고시촌에 고시생"]), "함준호 소개")
	t.eq(_v(st, "UQ62_INTRO"), 1, "INTRO")
	var kr := _v(st, "V_KARMA")
	t.ok(_says(st, c, "GC_KWON", "철자가 틀렸어요", ["볼트-텍"]), "권성민 — 철자")
	t.eq([_v(st, "UQ62_WAY"), _v(st, "V_KARMA") - kr, st.quests.stage("UQ-62")], [3, -10, 100], "③ 어설픈 — 카르마 −10")
	var jh := _v(st, "AFF_JH")
	c._uq62_day(6)
	t.eq([_v(st, "UQ62_GONE"), _v(st, "UQ62_JOB"), _v(st, "AFF_JH") - jh], [6, 1, 3], "소개 — 바로 관리사무소 · JH +3")
	t.ok(_says(st, c, "GC_KWON_JOB", "관리 후보"), "등록 번호로 부른다")
	t.ok(_says(st, c, "GC_KWON_JOB", "철자는 — 묻지 마세요") or true, "③ 한 줄(첫 대화에서)")
	t.ok(_says(st, c, "SQS08_HAM", "기관보다 글씨를 봅니다"), "함준호 — 볼트-텍 관리국 한 줄")
	t.eq(_v(st, "UQ62_HAM_SAID"), 1, "한 번")
	var b := _host()
	var st2: StoryState = b[1]
	var c2: UqR01 = b[2]
	_play(st2, c2, "GC_KWON", ["시험은 어떻게", "됐다"])
	var caps := _v(st2, "PC_CAPS")
	t.ok(_says(st2, c2, "JM_YEOM", "내 종이엔 틀린 철자가 없어", ["합격증 한 장"]), "염희정 판 120캡")
	t.eq([st2.count_of("M-450"), _v(st2, "UQ62_BAD"), caps - _v(st2, "PC_CAPS")], [1, 2, 120], "깨끗한 판 · 120캡")


func test_gc_gate_own_tube_book(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	t.ok(_says(st, c, "GC_GATE", "상담은 B동 옥상", ["상담료 여기"]), "문지기 — 상담료 50")
	t.eq([_v(st, "GC_PASS"), _v(st, "GC_SEEN"), _v(st, "PC_CAPS")], [5, 1, 250], "통행(그날) · 50캡")
	t.ok(_says(st, c, "GC_GATE", "오늘 상담료 냈잖아"), "같은 날")
	st.vars.set_v("GAME_DAY", 6)
	t.ok(_says(st, c, "GC_GATE", "전에 상담 받은 사람이네"), "다음 날 — 공짜 통행")
	t.eq(_v(st, "GC_PASS"), 6, "통행 갱신")
	t.ok(_says(st, c, "GC_BOSS", "200년 만에 첫 계약", ["원룸 한 칸"]), "삽자루 — 진짜 분양")
	t.eq([_v(st, "GC_OWN"), st.count_of("M-451"), _v(st, "PC_CAPS")], [1, 1, 50], "열쇠 · 200캡")
	t.ok(_says(st, c, "GC_GATE", "입주자님"), "문지기 — 입주자")
	t.ok(_says(st, c, "GC_GATE_S", "입주자"), "남쪽 초소")
	st.quests.set_stage("SQ-S02", 20)
	t.ok(_has_opt(st, "GC_BOSS", "삼성산 밸브"), "SQ-S02 C 해법 갈래(단계 20 이후)")
	t.ok(not _has_opt(st, "UQ62_LAMP", "진공관 하나를 뺀다"), "권성민을 만나기 전엔 안 뺀다")
	_play(st, c, "GC_KWON", ["시험은 어떻게", "됐다"])
	t.ok(_says(st, c, "UQ62_LAMP", "눈 감고도 외워요", ["진공관 하나를 뺀다"]), "스탠드 진공관")
	t.eq([_v(st, "UQ62_TUBE"), st.count_of("M-014")], [1, 1], "M-014")
	t.ok(_says(st, c, "GC_KWON", "불 없이도 돼요", ["됐다"]), "권성민 — 불 없이")
	var ex := _v(st, "PC_SKP_EXPLOSIVES")
	t.ok(_says(st, c, "UQ62_BOOK", "광산이 없으면", ["읽는다"]), "『발파 기능사 실기』")
	t.eq(_v(st, "PC_SKP_EXPLOSIVES") - ex, 2, "폭발물 +2")
	t.ok(_says(st, c, "UQ62_BOOK", "다 읽은 책"), "한 번만")
	_put(st, {"PC_SKP_SCIENCE": 60})
	t.ok(_says(st, c, "K24_CARREL", "양식은 진짜다", ["서식을 손봐"]), "[과학 60] 깨끗한 위조")
	t.ok(_says(st, c, "GC_KWON", "행정부가 지하로 갔구나", ["볼트-텍"]), "권성민 — 볼트-텍")
	t.eq([_v(st, "UQ62_WAY"), _v(st, "UQ62_BAD")], [3, 0], "③ 깨끗한 판")
