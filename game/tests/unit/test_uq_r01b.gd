## 단계 1-12i R01 비표시(SD-05 §3.28 UQ-64 · §3.29 UQ-65, 계획 docs/seoul-fallout/_plans/1-12i_UQ-62-67_plan.md §1 · §2 · §2b):
## UQ-65 판정 셋 · 오답 끝말 · 문항집 · 지능 판정 보너스 1회(대화 엔진) · 4~9번 하루 두 문항(다음 날부터) · 10번 칸 · 카드 벽 · 다음 날 소식 · 몰래 집기 · 팖 · 수업 중 사망 /
## UQ-64 꼬리표 맡김 · 조담희 귀띔 · 대문 셋 · 벽시계 · 호감 한 번씩 · 마지막 대문 매듭 · 다음 06:00 소식 · 근무지 · 일부 · 잃음(보관함) · 415 · 받침 볼트 · 길덕수 사망 · 오봉수 부재.
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


# ---------------------------------------------------------------- UQ-65
func test_uq65_lesson_book_bonus(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	st.vars.set_v("PC_IN", 7)
	t.ok(_says(st, c, "K-24_SON", "나보다 잘 가르치겠어요", ["무슨 수업", "풀어 보자", "지상을 버리라는", "등록증을 기다리죠", "출제 의도", "고맙다"]), "판정 셋 다 — 1등급형 끝말")
	t.eq(_v(st, "UQ65_READ"), 3, "판정 셋")
	t.eq(st.count_of("M-439"), 1, "문항집")
	t.eq(_v(st, "UQ65_BONUS"), 1, "판정 보너스 1회")
	t.eq(st.quests.stage("UQ-65"), 100, "완료")
	t.eq(st.count_of("M-090"), 0, "교재 대신 문항집")


func test_uq65_bonus_once(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	st.vars.set_v("PC_IN", 5)
	st.vars.set_v("UQ65_BONUS", 1)
	t.ok(_has_opt(st, "K-24_SON", "문항 해설", ["무슨 수업", "풀어 보자", "가장 가까운 지하", "판독기 앞에 정지"]), "지능 5 · [지능 6] — 해설로 열림")
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene("K-24_SON"))
	var picks := ["무슨 수업", "풀어 보자", "가장 가까운 지하", "판독기 앞에 정지", "문항 해설"]
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 100 and k < picks.size():
		guard += 1
		if cur["type"] == "choices":
			for j in cur["opts"].size():
				if str(cur["opts"][j]["text"]).contains(picks[k]) and bool(cur["opts"][j]["enabled"]):
					cur = dr.choose(j)
					break
			k += 1
		else:
			cur = dr.advance()
	t.eq(_v(st, "UQ65_BONUS"), 0, "고르면 씀(한 번)")
	st.vars.set_v("PC_SKP_SPEECH", 0)
	t.ok(not _has_opt(st, "K-24_SON", "문항 해설", ["무슨 수업", "풀어 보자", "가장 가까운 지하", "판독기 앞에 정지"]), "다 쓰면 다시 잠김")


func test_uq65_rebel_and_lessons(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	st.vars.set_v("PC_IN", 3)
	t.ok(_says(st, c, "K-24_SON", "당신 얼굴도 기억할게요", ["무슨 수업", "풀어 보자", "집으로 간다", "뛴다", "돕는다", "고맙다"]), "오답 셋 — 반항형 끝말(지능 낮은 사람 몫)")
	t.eq(_v(st, "UQ65_REBEL"), 3, "오답 셈")
	t.ok(_says(st, c, "K-24_SON", "오늘 수업은 끝났어요"), "'다음 시간엔 4번부터' — 같은 날은 없다")
	st.vars.set_v("GAME_DAY", 6)
	t.ok(_says(st, c, "K-24_SON", "5번", ["줄을 지킨다", "한 문제 더", "판독기 앞으로"]), "다음 날 4번 · 한 문제 더 5번")
	t.eq(_v(st, "UQ65_LESSON"), 5, "두 문항")
	t.ok(_says(st, c, "K-24_SON", "오늘 수업은 끝났어요"), "하루 두 문항까지")
	st.vars.set_v("GAME_DAY", 7)
	t.ok(_says(st, c, "K-24_SON", "7번", ["기다린다", "한 문제 더", "손전등"]), "6번 오답 · 7번")
	t.eq(_v(st, "UQ65_REBEL"), 4, "6번 '기다린다'는 끝말 셈")
	st.vars.set_v("GAME_DAY", 8)
	t.ok(_says(st, c, "K-24_SON", "배급표를 잃어버렸다", ["고개를 끄덕인다", "한 문제 더"]), "8번 넘김 · 9번 배급표 분실")
	t.eq(_v(st, "UQ65_LESSON"), 9, "9번까지")
	t.ok(_says(st, c, "K-24_SON", "오늘 수업은 끝났어요"), "9번 날엔 10번 없음")
	st.vars.set_v("GAME_DAY", 9)
	st.call_fn("take", ["M-439", 1])
	t.ok(_says(st, c, "K-24_SON", "책 가져오면"), "10번은 문항집을 들고 와야")
	st.call_fn("give", ["M-439", 1])
	t.ok(_says(st, c, "K-24_SON", "출제자가 못 낸 문제", ["내 말을 적는다"]), "10번 칸 — 내 말")
	t.eq(_v(st, "UQ65_TEN"), 2, "10번 값")
	t.ok(_says(st, c, "K-24_SON", "정답 칸에"), "다음에 오면 '내 책에 낙서했네'")
	t.ok(_says(st, c, "UQ65_WALL", "답장이에요", ["핀에 꽂는다"]), "카드 벽 — 10번을 쓴 판(류정)")
	t.eq(_v(st, "UQ65_TO"), 1, "각성회 몫")
	t.eq(st.count_of("M-439"), 0, "꽂음")
	t.ok(not _says(st, c, "K-24_SON", "대기 문안"), "꽂은 날엔 손재석이 아직 모른다(P7)")
	st.vars.set_v("GAME_DAY", 10)
	t.ok(_says(st, c, "K-24_SON", "'대기 문안'이 됐다면서요"), "다음 날 순례조에게 듣는다")
	t.ok(not _says(st, c, "K-24_SON", "대기 문안"), "한 번만")


func test_uq65_steal_sell_dead(t) -> void:
	var a := _host("K-24", "from_W")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	h.combat.crouch = false
	t.ok(_says(st, c, "K24_BOOK65", "수업 끝나고 줘요"), "서서 집으면 손재석이 돌아본다")
	t.eq(_v(st, "UQ65_BOOK"), 0, "못 가져감")
	h.combat.crouch = true
	_play(st, c, "K24_BOOK65", ["몰래 문항집"])
	t.eq(_v(st, "UQ65_STOLE"), 1, "웅크리면 몰래")
	t.eq(st.count_of("M-439"), 1, "문항집")
	h.combat.crouch = false
	st.vars.set_v("PC_IN", 4)
	t.ok(_says(st, c, "K-24_SON", "교재 가져간 학생 있죠", ["무슨 수업", "풀어 보자", "가장 가까운 지하", "판독기 앞에 정지", "모른 척한다", "고맙다"]), "수업 끝 — 몰래 집은 판")
	t.eq(st.count_of("M-439"), 1, "두 권이 되지 않는다")
	t.eq(_v(st, "UQ65_BONUS"), 1, "보너스 · XP는 수업 몫")
	st.call_fn("take", ["M-439", 1])
	c._uq65_day(6)
	t.eq(_v(st, "UQ65_TO"), 3, "팖 · 버림")
	t.ok(not _has_opt(st, "UQ65_WALL", "핀에 꽂는다"), "카드 벽 갈래 닫힘")
	st.vars.set_v("GAME_DAY", 6)
	t.ok(_says(st, c, "K-24_SON", "교재는 돌고 도는 거예요"), "손재석 — 안 갖고 다니는 걸 본다")
	var b := _host("K-24", "from_W")
	var st2: StoryState = b[1]
	var c2: UqR01 = b[2]
	st2.kill("N-R01-056")
	_play(st2, c2, "K24_BOOK65", ["챙긴다"])
	t.eq(st2.count_of("M-439"), 1, "죽었으면 교탁 위 문항집")
	t.eq(_v(st2, "UQ65_BONUS"), 0, "판정 보너스 없음")
	c2._uq65_day(6)
	t.eq(st2.quests.stage("UQ-65"), 0, "수업을 시작한 적이 없으면 단계 없음")
	var d := _host("K-24", "from_W")
	var st3: StoryState = d[1]
	var c3: UqR01 = d[2]
	st3.quests.set_stage("UQ-65", 10)
	st3.vars.set_v("UQ65_STOLE", 1)
	st3.vars.set_v("UQ65_BOOK", 1)
	st3.kill("N-R01-056")
	c3._uq65_day(6)
	t.eq(st3.quests.stage("UQ-65"), 90, "수업 도중 사망 — 몰래 집었어도 90")


# ---------------------------------------------------------------- UQ-64
func _tags(st: StoryState, c: UqR01) -> void:
	_play(st, c, "L22_GIL", ["인수 대장", "꼬리표를 가족에게"])


func test_uq64_doors_and_news(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_tags(st, c)
	t.eq(_v(st, "UQ64_TAGS"), 1, "꼬리표를 맡음")
	t.eq(st.count_of("M-440"), 5, "다섯 장")
	t.eq(st.quests.stage("UQ-64"), 10, "단계 10")
	t.eq(str(h.scene_for("N-R01-029").get("id", "")), "BC_DAMHEE_TAG", "조담희 — 꼬리표를 든 동안 귀띔 장면이 먼저(A240)")
	t.ok(_says(st, c, "BC_DAMHEE_TAG", "3동 할매네가 902호 집안"), "어느 집인지 귀띔")
	t.eq(_v(st, "UQ64_HINT"), 1, "귀띔 한 번")
	var bc := _v(st, "AFF_JC_BC")
	t.ok(_says(st, c, "UQ64_D412", "예정으로 적혀", ["412번"]), "3동 — 조씨 할매")
	t.eq(_v(st, "AFF_JC_BC"), bc, "하나로는 아직")
	t.ok(_says(st, c, "UQ64_D414", "기다리는 집", ["414번"]) or _v(st, "UQ64_D414") == 1, "4동 — 남씨네")
	t.eq(_v(st, "AFF_JC_BC"), bc + 4, "봉천 둘 — BC +4")
	t.eq(st.quests.stage("UQ-64"), 20, "단계 20")
	t.ok(_says(st, c, "UQ64_D416", "아랫문 자리에서 올라온 집", ["416번"]), "오씨네 고물 — 오봉수")
	t.eq(_v(st, "AFF_JC_BC"), bc + 4, "BC는 한 번")
	var sa := _v(st, "AFF_JC_SA")
	t.ok(_says(st, c, "UQ64_CLOCK", "대대로 이 시계를", ["413번"]), "사당 — 역무실 벽시계 태엽 열쇠 끈")
	t.eq(_v(st, "AFF_JC_SA"), sa + 4, "SA +4")
	t.eq(st.quests.stage("UQ-64"), 100, "마지막 대문에서 매듭(왕복 없음)")
	t.eq(_v(st, "UQ64_XP"), 1, "70 XP 한 번")
	c._uq64_day(6)
	t.eq(_v(st, "UQ64_NEWS"), 1, "다음 06:00 소식")
	t.eq(_v(st, "UQ64_POST"), 3, "근무지 둘")
	t.ok(_says(st, c, "L22_GIL", "사당 역 경비가 하나"), "길덕수 에필로그 — 근무지 둘")
	t.ok(not _says(st, c, "L22_GIL", "반은 가고"), "네 집 다 — '반은' 없음 · 소식은 한 번")


func test_uq64_partial_lost(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_tags(st, c)
	_play(st, c, "UQ64_D412", ["412번"])
	st.call_fn("take", ["M-440", 4])
	c._uq64_day(6)
	t.eq(st.quests.stage("UQ-64"), 100, "한 집 건네고 나머지를 팖 — 매듭")
	t.eq(_v(st, "UQ64_LOST"), 0, "잃음 아님")
	t.eq(_v(st, "UQ64_POST"), 0, "근무지 없음(봉천 하나)")
	t.ok(_says(st, c, "L22_GIL", "한 집이라도"), "길덕수 — 한 집이라도")
	var b := _host()
	var st2: StoryState = b[1]
	var c2: UqR01 = b[2]
	_tags(st2, c2)
	st2.boxes["X-BC:test"] = {"items": {"M-440": 2}}
	st2.call_fn("take", ["M-440", 5])
	c2._uq64_day(6)
	t.eq(st2.quests.stage("UQ-64"), 10, "보관함에 남아 있으면 매듭 아님")
	st2.boxes.erase("X-BC:test")
	c2._uq64_day(7)
	t.eq(_v(st2, "UQ64_LOST"), 1, "하나도 안 건네고 다 잃음")
	t.eq(st2.quests.stage("UQ-64"), 100, "매듭(XP 없음)")
	t.ok(_says(st2, c2, "L22_GIL", "이름을 잃었네"), "길덕수 — 아침 교대 자경이 전함")


func test_uq64_415_mem_dead_absent(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_tags(st, c)
	_play(st, c, "L27_LR06", ["봉투 옆에 놓는다"])
	t.eq(_v(st, "UQ64_T415"), 1, "415 — 빌라에")
	t.eq(st.count_of("M-440"), 4, "한 장 놓음")
	st.vars.set_v("GAME_DAY", 6)
	t.ok(_says(st, c, "L27_LR06", "묘지기가 다녀갔다"), "다음 날 마른 꽃")
	st.vars.set_v("MQ101_NIGHT", 1)
	st.vars.set_v("MQ101_RESULT", 0)
	t.ok(not _has_opt(st, "UQ64_D416", "416번"), "MQ-101 밤 — 오봉수가 없으면 못 건넴")
	st.vars.set_v("MQ101_NIGHT", 0)
	st.vars.set_v("MQ101_RESULT", 1)
	t.ok(_says(st, c, "UQ64_MEM", "바람이 불자", ["볼트에 건다"]), "받침 볼트에 건다(엉뚱한 짓)")
	t.eq(_v(st, "UQ64_MEM"), 1, "다른 매듭")
	t.eq(st.count_of("M-440"), 0, "남은 꼬리표 다 걸림")
	t.eq(st.quests.stage("UQ-64"), 100, "매듭")
	c._uq64_day(7)
	t.eq(_v(st, "UQ64_POST"), 0, "근무지 없음")
	t.ok(_says(st, c, "L22_GIL", "이름은 걸리네"), "길덕수 — 탑은 못 세워도")
	var b := _host()
	var st2: StoryState = b[1]
	var c2: UqR01 = b[2]
	st2.kill("N-R01-052")
	_play(st2, c2, "UQ64_SHELF", ["직접 뗀다"])
	t.eq(st2.count_of("M-440"), 5, "길덕수가 없으면 선반에서 직접")
	_play(st2, c2, "L27_LR06", ["봉투 옆에 놓는다"])
	st2.vars.set_v("GAME_DAY", 6)
	t.ok(_says(st2, c2, "L27_LR06", "꼬리표가 놓여 있다"), "길덕수가 죽었으면 마른 꽃 없음")
