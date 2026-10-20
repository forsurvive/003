## 단계 1-12b FQ-GS-01 「정비 당번」 · FQ-GS-02 「천공기」(SD-04d §9.3 · §9.4, 계획 docs/seoul-fallout/_plans/1-12b_FQ-GS-01-02_plan.md §2 · §4):
## 전단 · 오상구 · 당번표(오상구가 없을 때) · 정비 카드 · 로봇마다 다른 일 여섯 · 3번 순서(전원 → 기름, 거꾸로면 깸) · [관리자 인증] · 맞섬 · 물러남 ·
## 퓨즈(빈 정비고 · 들킴 · 한가람이 되끼움 · 은솔 '어두워요') · 태그(둥지 · 끼움 · 넘김) · 끝 · 적대 실패 ·
## 류정 바늘 부탁 · 벌써요 · 채점기 넷(바늘 · 진공관 먼저 · 머리째 · 대기자 카드) · 금고 번호 · 옆문(화술 · 자습 · 안에서) · 답안 카드 '학생' · 류정 사망 실패.
extends RefCounted


func _host(map_id := "X-GS", mark := "arrive", hour := 10) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 5)
	st.vars.set_v("GAME_HOUR", hour)
	st.vars.set_v("AFF_GS", 25)
	st.vars.set_v("PC_SKP_REPAIR", 100)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 28.  10:00"
	var c := FqGs.new()
	c.setup(h)
	h.enter(map_id, mark)
	st.vars.set_v("GAME_HOUR", hour)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: FqGs, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "gs01":
				c._cmd1(cur["args"], func() -> void: pass)
			elif str(cur["name"]) == "gs02":
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


func _ok(r: Array) -> bool:
	return r.size() == 1 and str(r[0]).begins_with("말:")


func _says(st: StoryState, c: FqGs, id: String, needle: String, picks: Array = []) -> bool:
	var r := _play(st, c, id, picks)
	return _ok(r) and str(r[0]).contains(needle)


func _has_opt(st: StoryState, id: String, needle: String) -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var guard := 0
	while cur["type"] != "end" and guard < 100:
		guard += 1
		if cur["type"] == "choices":
			for o in cur["opts"]:
				if str(o["text"]).contains(needle) and bool(o["enabled"]):
					return true
			return false
		cur = dr.advance()
	return false


## 당번표 받고 정비 카드까지
func _duty(st: StoryState, c: FqGs) -> void:
	_play(st, c, "FQGS01_OH", ["당번을 서겠습니다"])
	_play(st, c, "GS_PUNCH", ["정비 카드 여섯 장"])


func _all_six(st: StoryState, c: FqGs) -> void:
	_play(st, c, "FQGS01_R1", ["위에서 아래로"])
	_play(st, c, "FQGS01_R2", ["분필 글씨는 남기고"])
	_play(st, c, "FQGS01_R4", ["태그 없이"])
	_play(st, c, "FQGS01_R5", ["천을 풀어", "번호 순서대로"])
	_play(st, c, "FQGS01_R6", ["뚜껑을 연다"])
	_play(st, c, "FQGS01_R6", ["둥지를 쓸어", "집진통을 닦고"])
	_play(st, c, "FQGS01_R3", ["전원 스위치", "닦고, 관절에 기름"])


func test_gs01_flyer_and_roster(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	t.ok(_says(st, c, "FQGS01_FLYER", "정비 당번 모집"), "안내 신도가 전단을 건넴")
	t.eq(_v(st, "FQ_GS01_FLYER"), 1, "전단 받음")
	t.ok(_says(st, c, "FQGS01_OH", "전단 받으셨구나", ["당번을 서겠습니다"]), "오상구: 전단을 안다(이미 앎)")
	t.eq(st.quests.stage("FQ-GS-01"), 10, "당번표 = 단계 10")
	t.eq(_v(st, "FQ_GS01_WARN"), 1, "'3번은 전원부터' 들음")
	t.ok(_has_opt(st, "FQGS01_R1", "정비 카드가 없다"), "카드 없이는 끝내는 선택지가 없다")
	t.ok(_says(st, c, "GS_PUNCH", "여섯 장", ["정비 카드 여섯 장"]), "대기실 정비 카드용 천공기")
	t.eq(_v(st, "FQ_GS01_CARDS"), 6, "정비 카드 여섯 장")
	var b := _host()
	var st2: StoryState = b[1]
	st2.vars.set_v("AFF_GS", 10)
	t.ok(_says(st2, b[2], "FQGS01_OH", "아직 응답이 없으시네요"), "우호 아래: 당번을 주지 않는다(원문 ≥ +20)")
	t.eq(st2.quests.stage("FQ-GS-01"), 0, "발동 안 함")


func test_gs01_six_robots_done(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	_duty(st, c)
	_all_six(st, c)
	t.eq([_v(st, "FQ_GS01_R1"), _v(st, "FQ_GS01_R2"), _v(st, "FQ_GS01_R3"), _v(st, "FQ_GS01_R4"), _v(st, "FQ_GS01_R5"), _v(st, "FQ_GS01_R6")], [1, 1, 1, 1, 2, 3], "여섯 대 각자의 끝")
	t.eq(_v(st, "FQ_GS01_WAKE"), 0, "전원부터 내렸으니 3번은 깨지 않았다")
	t.eq(_v(st, "FQ_GS01_POWER"), 0, "정비 뒤 전원을 다시 올림")
	t.eq(st.quests.stage("FQ-GS-01"), 30, "3번을 봄 = 단계 30")
	t.eq(int(st.items.get("M-418", 0)), 1, "둥지에서 4번 태그")
	t.eq(_v(st, "FQ_GS01_PAPER"), 1, "2077 청소 확인서(학원 금고로 이어짐)")
	var aff := _v(st, "AFF_GS")
	var tube := int(st.items.get("M-014", 0))
	t.ok(_says(st, c, "FQGS01_OH", "오늘의 정비 끝"), "오상구에게 보고")
	t.eq(st.quests.stage("FQ-GS-01"), 100, "끝")
	t.eq(_v(st, "AFF_GS") - aff, 6, "GS +6")
	t.eq(int(st.items.get("M-014", 0)) - tube, 2, "진공관 둘")
	t.eq(_v(st, "GS_ROBOT"), 0, "깨울 로봇은 그대로")
	t.ok(_says(st, c, "FQGS01_R1", "당번"), "끝난 뒤 가슴 판에 내 번호")


func test_gs01_three_wakes_by_order(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	_duty(st, c)
	_play(st, c, "FQGS01_R3", ["닦고, 관절에 기름"])
	t.eq(_v(st, "FQ_GS01_WAKE"), 1, "전원을 안 내리고 기름부터 = 깸(확률 아님)")
	t.eq(_v(st, "FQ_GS01_R3"), 0, "정비는 안 된 채")
	st.vars.set_v("V_REGCARD", 0)
	t.ok(not _has_opt(st, "FQGS01_WAKE", "관리자 인증"), "관리자 후보가 아니면 [관리자 인증] 없음")
	t.ok(_says(st, c, "FQGS01_WAKE", "잦아든다", ["물러난다"]), "물러남")
	t.eq(_v(st, "FQ_GS01_WAKE"), 0, "다시 잠듦")
	_play(st, c, "FQGS01_R3", ["닦고, 관절에 기름"])
	st.vars.set_v("V_REGCARD", 4)
	var aff := _v(st, "AFF_GS")
	var w := _v(st, "V_WANTED")
	t.ok(_says(st, c, "FQGS01_WAKE", "정비 모드", ["관리자 인증"]), "[관리자 인증]으로 멈춤")
	t.eq(_v(st, "FQ_GS01_R3"), 2, "인증으로 세운 뒤 정비 끝")
	t.eq(_v(st, "AFF_GS") - aff, 3, "GS +3")
	t.ok(_v(st, "V_WANTED") > w, "수배도가 오른다")


func test_gs01_three_fight_wreck(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	_duty(st, c)
	_play(st, c, "FQGS01_R3", ["닦고, 관절에 기름"])
	var aff := _v(st, "AFF_GS")
	_play(st, c, "FQGS01_WAKE", ["맞선다"])
	t.ok(c._bot != null and is_instance_valid(c._bot), "깨어난 파수-3이 선다")
	c._bot.cmb.dead = true
	c.tick()
	t.eq(_v(st, "FQ_GS01_R3"), 3, "부숨")
	t.eq(_v(st, "AFF_GS") - aff, -6, "GS −6(수호자 몸을 상하게 함)")
	t.eq(_v(st, "GS_ROBOT"), -1, "깨울 로봇 −1")
	t.ok(_says(st, c, "FQGS01_R3", "흰 천을 덮어"), "부서진 3번")
	_all_six(st, c)
	t.ok(_says(st, c, "FQGS01_OH", "금이 갔네요"), "보고: 3번은 금")
	t.eq(st.quests.stage("FQ-GS-01"), 100, "그래도 끝")
	h.free()


func test_gs01_fuse(t) -> void:
	var a := _host("X-GS", "arrive", 11)
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	_duty(st, c)
	t.ok(not c.watched(), "11시 대기음 — 정비고가 빈다")
	_play(st, c, "FQGS01_R3", ["퓨즈를 몰래"])
	t.eq(_v(st, "FQ_GS01_FUSE"), 1, "퓨즈를 뺌")
	t.eq(int(st.items.get("M-419", 0)), 1, "퓨즈가 손에")
	t.eq(_v(st, "GS_ROBOT"), -1, "깨울 로봇 −1")
	_play(st, c, "FQGS01_R3", ["닦고, 관절에 기름"])
	t.eq(_v(st, "FQ_GS01_WAKE"), 0, "퓨즈가 빠진 3번은 깨지 않는다")
	t.eq(_v(st, "FQ_GS01_R3"), 1, "그대로 정비")
	c._on_day(6)
	t.eq(_v(st, "FQ_GS01_DIM"), 1, "다음 날 — 대기등이 어둡다")
	st.vars.set_v("GS_MET_EUNSOL", 1)
	t.ok(_says(st, c, "GS_EUNSOL", "어제보다 어두워요"), "은솔이 알아챈다(범인 단정 없음)")
	st.vars.set_v("GS_MET_HAN", 1)
	t.ok(_says(st, c, "GS_HAN", "3번 거잖아", ["퓨즈를 보여"]), "한가람이 알아본다")
	t.eq(_v(st, "FQ_GS01_FUSE"), 3, "되끼움")
	t.eq(_v(st, "GS_ROBOT"), 0, "깨울 로봇 되돌림")
	var b := _host("X-GS", "arrive", 10)
	var st2: StoryState = b[1]
	_duty(st2, b[2])
	t.ok(b[2].watched(), "낮 10시 — 오상구가 차양에 있다")
	var aff := _v(st2, "AFF_GS")
	_play(st2, b[2], "FQGS01_R3", ["퓨즈를 몰래"])
	t.eq(_v(st2, "FQ_GS01_FUSE"), 2, "들켜 압수")
	t.eq(_v(st2, "AFF_GS") - aff, -5, "GS −5")
	t.eq(_v(st2, "GS_ROBOT"), 0, "로봇은 그대로")


func test_gs01_tag(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	_duty(st, c)
	_play(st, c, "FQGS01_R6", ["뚜껑을 연다"])
	_play(st, c, "FQGS01_R6", ["둥지를 쓸어", "나중에"])
	t.eq(_v(st, "FQ_GS01_TAG"), 1, "태그를 주움")
	t.ok(_says(st, c, "FQGS01_R4", "딸깍", ["식별 태그를 목 고리에"]), "4번에 끼움")
	t.eq(_v(st, "FQ_GS01_TAG"), 2, "내가 끼움")
	t.eq(_v(st, "FQ_GS01_R4"), 1, "4번 정비 끝")
	var b := _host()
	var st2: StoryState = b[1]
	_duty(st2, b[2])
	_play(st2, b[2], "FQGS01_R6", ["뚜껑을 연다"])
	_play(st2, b[2], "FQGS01_R6", ["둥지를 쓸어", "나중에"])
	st2.vars.set_v("GS_MET_HAN", 1)
	var caps := _v(st2, "PC_CAPS")
	t.ok(_says(st2, b[2], "GS_HAN", "4번 거네", ["식별 태그를 넘긴다"]), "한가람에게 넘김")
	t.eq(_v(st2, "PC_CAPS") - caps, 20, "20캡")
	t.eq(_v(st2, "FQ_GS01_TAG"), 3, "한가람이 끼움")


func test_gs01_oh_dead_and_hostile(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	st.kill("N-R01-503")
	t.ok(_says(st, c, "FQGS01_POST", "검은 줄", ["빈칸에 내 번호"]), "오상구가 없으면 당번표에 스스로")
	t.eq(st.quests.stage("FQ-GS-01"), 10, "당번 시작")
	t.ok(not c.watched(), "오상구가 없으면 정비고가 빈다")
	_play(st, c, "GS_PUNCH", ["정비 카드 여섯 장"])
	_all_six(st, c)
	st.vars.set_v("GS_MET_HAN", 1)
	t.ok(_says(st, c, "GS_HAN", "끝까지 했구나", ["다 닦았습니다"]), "한가람에게 보고")
	t.eq(st.quests.stage("FQ-GS-01"), 100, "끝")
	var b := _host()
	var st2: StoryState = b[1]
	_duty(st2, b[2])
	st2.vars.set_v("AFF_GS", -60)
	b[2].tick()
	t.eq(st2.quests.stage("FQ-GS-01"), 200, "각성회 적대 = 정비고 문을 닫음(실패)")


func test_gs02_offer_and_grader(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	st.vars.set_v("GS_MET_RJ", 1)
	t.ok(_says(st, c, "GS_RJ", "바늘이 부러졌어요"), "류정의 부탁")
	t.eq(st.quests.stage("FQ-GS-02"), 20, "학원가 채점실까지 = 20")
	st.vars.set_v("PC_SKP_REPAIR", 100)
	t.ok(_says(st, c, "K-24_GRADER", "영영 채점되지 않는다", ["바늘 뭉치만"]), "바늘 분리 — 걸린 카드는 영영")
	t.eq(_v(st, "GS02_GRADER"), 2, "채점기 = 바늘 뽑힘(P1)")
	t.eq(st.quests.stage("FQ-GS-02"), 40, "바늘이 손에 = 40")
	var aff := _v(st, "AFF_GS")
	var caps := _v(st, "PC_CAPS")
	var pd := _v(st, "PD_R01_GS")
	t.ok(_says(st, c, "GS_RJ", "다 살아 있어요", ["천공 바늘 묶음을 건넨다"]), "류정에게 건넴")
	t.eq(st.quests.stage("FQ-GS-02"), 100, "끝")
	t.eq(_v(st, "AFF_GS") - aff, 8, "GS +8")
	t.eq(_v(st, "PC_CAPS") - caps, 50, "헌금 50캡")
	t.eq(_v(st, "PD_R01_GS") - pd, 3, "판도 +3")
	t.ok(_says(st, c, "FQGS02_REG", "학원에서 온 것"), "등록용 천공기가 다시 돈다")


func test_gs02_tube_first_and_m135(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	st.call_fn("give", ["M-014", 1])
	st.call_fn("give", ["M-135", 1])
	t.ok(_says(st, c, "K-24_GRADER", "행정 적성 2등급", ["진공관을 갈아", "대기자 천공 카드", "그만둔다"]), "진공관을 먼저 — 권성민 카드가 채점됨")
	t.eq(_v(st, "GS02_GRADER"), 1, "채점기 = 다시 돌아감")
	t.eq(int(st.items.get("M-423", 0)), 1, "채점된 카드(UQ-62로)")
	t.eq(_v(st, "FQ_GS02_M135"), 1, "대기자 카드: 판독 불능")
	t.eq(_v(st, "GS_TRUTH"), 0, "GS_TRUTH는 오르지 않는다(GS-05 복선)")
	t.ok(_says(st, c, "K-24_GRADER", "바늘 뭉치가 통째로", ["바늘 뭉치만"]), "그 뒤 바늘")
	t.eq(_v(st, "GS02_GRADER"), 2, "바늘 뽑힘")
	st.vars.set_v("GS_MET_RJ", 1)
	t.ok(_says(st, c, "GS_RJ", "…벌써요?"), "받기 전에 바늘 — 벌써요(이미 앎)")
	t.eq(st.quests.stage("FQ-GS-02"), 40, "바로 40")
	t.ok(_says(st, c, "GS_RJ", "수호자가 아니에요", ["대기자 카드를 넣어"]), "류정: 학원 기계는 수호자가 아니다")


func test_gs02_rip_head(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	st.vars.set_v("GS_MET_RJ", 1)
	_play(st, c, "GS_RJ", ["됐습니다"])
	st.vars.set_v("PC_SKP_REPAIR", 0)
	t.ok(not _has_opt(st, "K-24_GRADER", "바늘 뭉치만"), "수리 50 없이는 분리 못 함")
	_play(st, c, "K-24_GRADER", ["머리판째"])
	t.eq(_v(st, "GS02_GRADER"), 3, "뜯김(UQ-62: 기계는 끝)")
	t.eq(int(st.items.get("M-421", 0)), 1, "천공 머리 뭉치")
	_play(st, c, "FQGS01_OH", ["다음에"])
	t.ok(_says(st, c, "FQGS01_OH", "기름종이에", ["천공 머리를 뜯어 왔습니다"]), "오상구가 바늘만 뽑음")
	t.eq(int(st.items.get("M-420", 0)), 1, "바늘 묶음")


func test_gs02_door_safe_cards(t) -> void:
	var a := _host("K-24", "from_W")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	t.eq(h.map.is_solid(c.DOOR), true, "원장실 옆문이 막는다")
	st.vars.set_v("PC_SKP_SPEECH", 100)
	var hr := _v(st, "GAME_HOUR")
	t.ok(_says(st, c, "K24_CARREL", "203년째", ["자습석에 앉아"]), "자습 한 시간 → 원장실 면담")
	t.eq(_v(st, "GAME_HOUR"), hr + 1, "한 시간이 흐름")
	t.eq(_v(st, "FQ_GS02_DOOR"), 1, "옆문 열림")
	t.eq(h.map.is_solid(c.DOOR), false, "발 칸이 트임")
	_play(st, c, "K24_BANNER")
	_play(st, c, "K24_CAL")
	t.ok(_has_opt(st, "K24_SAFE", "3 · 7 · 2 · 3"), "현수막 37 · 달력 23 → 번호")
	_play(st, c, "K24_SAFE", ["3 · 7 · 2 · 3"])
	var b: Dictionary = h.map.boxes.get(c.SAFE, {})
	t.ok(not b.is_empty() and bool(h.box_contents(b).get("unlocked", false)), "금고가 풀림")
	t.ok(int(h.box_contents(b)["items"].get("M-420", 0)) == 1, "수리 기사 예비 부품 = 바늘 묶음")
	_play(st, c, "K-24_GRADER", ["답안 카드 묶음을"])
	t.eq(int(st.items.get("M-422", 0)), 1, "답안 카드 묶음")
	st.vars.set_v("GS_MET_RJ", 1)
	_play(st, c, "GS_RJ", ["됐습니다"])
	t.ok(_says(st, c, "GS_RJ", "'학생들'", ["답안 카드 묶음을 보여", "학생 답안지"]), "'학생 답안지'")
	t.eq(_v(st, "GS_TRUTH"), 1, "GS_TRUTH +1")
	t.eq(_v(st, "FQ_GS02_NAME"), 2, "벽에는 '학생들'")
	t.ok(_says(st, c, "GS_CARDS", "학생들. 2077"), "카드 벽 맨 윗줄")
	var a2 := _host("K-24", "from_W")
	var st2: StoryState = a2[1]
	st2.vars.set_v("PC_SKP_SPEECH", 100)
	t.ok(_says(st2, a2[2], "K24_PROXY", "딸깍 열린다", ["원장님 호출입니다"]) or _v(st2, "FQ_GS02_DOOR") == 0, "화술: 원장님 호출(판정)")
	h.free()


func test_gs02_rj_dead_fails(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: FqGs = a[2]
	st.vars.set_v("GS_MET_RJ", 1)
	_play(st, c, "GS_RJ", ["됐습니다"])
	t.eq(st.quests.stage("FQ-GS-02"), 20, "받음")
	st.kill("C-014")
	c.tick()
	t.eq(st.quests.stage("FQ-GS-02"), 200, "류정 사망 = 실패(영구 적대)")
