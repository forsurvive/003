## 단계 1-12i i3 R01 비표시 UQ-66 「전지 하나, 냉장고 둘」(SD-05 §3.30, 계획 docs/seoul-fallout/_plans/1-12i_UQ-62-67_plan.md §5 · §5b):
## 시장 전지 이야기 → 기한 · 꼬리표 · 운반조가 가져감(90) · ① 지킴 · ② 뺌 · 잃음 · 혈액은행으로 · ③ 예비 전지 · 관악 전지(둘 다 삶) ·
## 흑석 퇴원 서류 · 정지/깨움 · 병동 정리 · 냉장고 · 로비 글 → 다음 06:00 들것 협력 · 정류지(MEDIC_AT 6) · 내 퇴원 서류.
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


# ---------------------------------------------------------------- 시장
func test_uq66_heard_tag_taken(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	t.ok(_says(st, c, "L25_SIM", "나흘 뒤 열 시", ["저 냉동고는"]), "심도겸 — 운반조 일정(직접 봄)")
	t.eq(_v(st, "UQ66_DUE"), 9, "기한 = 들은 날 + 4")
	t.eq(st.quests.stage("UQ-66"), 10, "단계 10")
	c._uq66_day(6)
	t.eq(_v(st, "UQ66_TAG"), 1, "다음 날 붉은 천 꼬리표")
	t.ok(_says(st, c, "UQ66_FREEZER", "수거 예정", ["그만둔다"]), "냉동고에 꼬리표 글")
	t.ok(_says(st, c, "UQ66_CARRY", "내일 열 시"), "전날 순례조")
	_put(st, {"GAME_DAY": 9, "GAME_HOUR": 14})
	c._uq66_tick()
	t.eq(_v(st, "UQ66_BATT"), 5, "14시 — 운반조가 가져감")
	t.eq(_v(st, "UQ66_PULLED"), 1, "냉동고 멎음")
	t.eq(st.quests.stage("UQ-66"), 90, "혈액은행이 꺼져 있으면 90")
	t.eq(_v(st, "UQ66_XP"), 0, "XP 없음")
	t.ok(_says(st, c, "L25_SIM", "열 시에 손수레가 왔어", ["저 냉동고는"]), "심도겸 결과 한 줄")


func test_uq66_skip_time(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_play(st, c, "L25_SIM", ["저 냉동고는"])
	c._uq66_day(12)
	t.eq(_v(st, "UQ66_BATT"), 5, "시간 도약으로 기한을 넘김 — 다음 06:00 판정에서 같은 결과(P6)")


func test_uq66_keep_scare(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_play(st, c, "L25_SIM", ["저 냉동고는"])
	_put(st, {"GAME_DAY": 9, "GAME_HOUR": 11, "PC_ST": 7})
	var gs := _v(st, "AFF_GS")
	t.ok(_says(st, c, "UQ66_CARRY", "싸우러 온 게 아니에요", ["손수레 놓고"]), "운반조 — [힘 7]")
	t.eq(_v(st, "UQ66_BATT"), 1, "① 지킴")
	t.eq(_v(st, "AFF_GS"), gs - 5, "위협 GS −5")
	t.eq(st.quests.stage("UQ-66"), 100, "매듭")
	t.eq(_v(st, "UQ66_XP"), 1, "120 XP 한 번")
	_put(st, {"GAME_HOUR": 15})
	c._uq66_tick()
	t.eq(_v(st, "UQ66_BATT"), 1, "14시가 지나도 그대로")
	t.ok(_says(st, c, "L25_SIM", "네가 말렸지", ["저 냉동고는"]), "심도겸 — 봤다 · 할인 약속(한 번)")
	t.eq(_v(st, "UQ66_HOW"), 2, "① 길 — 위협")


func test_uq66_pull_lost_and_fridge(t) -> void:
	var a := _host("K-24", "from_W")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_SKP_REPAIR": 60})
	h.combat.crouch = false
	t.ok(_says(st, c, "UQ66_FREEZER", "손 떼", ["들창을 연다"]), "심도겸이 본다")
	h.combat.crouch = true
	t.ok(_says(st, c, "UQ66_FREEZER", "손 떼", ["들창을 연다"]), "한 번 들킨 뒤로는 낮엔 웅크려도 본다")
	st.vars.set_v("GAME_HOUR", 22)
	_play(st, c, "UQ66_FREEZER", ["들창을 연다", "전지를 뺀다"])
	t.eq(_v(st, "UQ66_PULLED"), 1, "밤 · 웅크려 뺌")
	t.eq(st.count_of("M-442"), 1, "시장 전지")
	t.ok(_says(st, c, "L25_SIM", "너였지", ["저 냉동고는"]), "들킨 적이 있으면 심도겸 — '너였지'")
	st.call_fn("take", ["M-442", 1])
	c._uq66_day(6)
	t.eq(_v(st, "UQ66_BATT"), 4, "잃음")
	t.eq(st.quests.stage("UQ-66"), 90, "90")
	st.call_fn("give", ["M-442", 1])
	_play(st, c, "UQ66_FRIDGE", ["수산시장 냉동고 전지"])
	t.eq(_v(st, "UQ66_FRIDGE"), 3, "혈액은행 냉장고에 꽂음")
	t.eq(_v(st, "UQ66_BATT"), 7, "시장 전지는 혈액은행으로")
	t.eq(st.quests.stage("UQ-66"), 100, "90 뒤에도 냉장고가 돌면 100")
	t.eq(_v(st, "UQ66_BOTH"), 0, "시장은 멎었으니 둘 다는 아님")


func test_uq66_spare_and_gwanak_both(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_play(st, c, "L25_SIM", ["저 냉동고는"])
	_play(st, c, "UQ66_CELL", ["예비 전지를 꺼낸다"])
	t.eq(st.count_of("M-441"), 1, "예비 전지 하나")
	var gs := _v(st, "AFF_GS")
	var kr := _v(st, "V_KARMA")
	_play(st, c, "UQ66_RACK", ["B계통 예비 전지"])
	t.eq(_v(st, "UQ66_BATT"), 3, "③ 예비 전지로 대신 — 시장이 산다")
	t.eq(_v(st, "AFF_GS"), gs + 3, "GS +3")
	t.eq(_v(st, "V_KARMA"), kr + 10, "카르마 +10")
	t.eq(st.quests.stage("UQ-66"), 100, "매듭")
	_put(st, {"SQ_S04_BATT": 1, "SQH_BATT": -1})
	st.call_fn("give", ["M-162", 1])
	_play(st, c, "UQ66_FRIDGE", ["관악 레이더"])
	t.eq(_v(st, "UQ66_FRIDGE"), 2, "관악 전지로 혈액은행")
	t.eq(_v(st, "SQH_BATT"), 26, "SQ-S04 인도처 새 값(A111)")
	t.eq(_v(st, "UQ66_BOTH"), 1, "둘 다 삶")
	t.eq(_v(st, "V_KARMA"), kr + 35, "카르마 +25 한 번 더")
	t.eq(_v(st, "UQ66_XP"), 1, "XP는 한 번")


func test_uq66_gwanak_midquest(t) -> void:
	var a := _host("K-24", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_play(st, c, "L25_SIM", ["저 냉동고는"])
	st.vars.set_v("SQH_BATT", 7)
	c._uq66_day(6)
	t.eq(_v(st, "UQ66_BATT"), 6, "관악 전지가 대기등 예비 전원으로 — 시장이 산다")
	t.eq(st.quests.stage("UQ-66"), 100, "매듭")
	t.ok(_says(st, c, "L25_SIM", "다른 전지로 돈다", ["저 냉동고는"]), "심도겸 — 손수레가 안 옴")


# ---------------------------------------------------------------- 흑석
func test_uq66_discharge_fridge_dg(t) -> void:
	var a := _host("K-26", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_SKP_SCIENCE": 60, "PN_NURSE": 1, "TR_SO_MET": 1})
	t.ok(_says(st, c, "UQ66_DOOR", "간호 7호", ["물러선다"]), "철문 — 승인 규정")
	t.eq(st.quests.stage("UQ-66"), 10, "단계 10")
	t.eq(_v(st, "UQ66_DUE"), 0, "병원만 봤으면 기한 없음(W4)")
	_play(st, c, "UQ66_DESK", ["병동 다섯의 퇴원 서류"])
	t.eq(_v(st, "UQ66_FORMS"), 1, "퇴원 서류")
	t.ok(_says(st, c, "K-26_NURSE", "뒤뜰 벤치로", ["퇴원 서류 다섯 장"]), "7호 — 퇴원")
	t.eq(_v(st, "UQ66_WARD"), 1, "퇴원")
	t.eq(_v(st, "UQ66_OPEN"), 1, "철문 열림")
	t.eq(st.quests.stage("UQ-66"), 20, "단계 20")
	t.ok(_says(st, c, "K-26_NURSE", "뒤뜰 벤치에 계세요"), "다시 오면 퇴원한 분들 이야기")
	_play(st, c, "UQ66_CELL", ["예비 전지를 꺼낸다"])
	t.ok(_says(st, c, "UQ66_FRIDGE", "로비 문에 써 붙일게요", ["B계통 예비 전지"]), "냉장고 — 7호가 내려옴")
	t.eq(_v(st, "UQ66_NOTICE"), 1, "로비 글")
	t.eq(st.quests.stage("UQ-66"), 100, "매듭")
	c._uq66_day(6)
	t.eq(_v(st, "UQ66_DG"), 0, "들것이 강 건너에 있는 날엔 아직(P7)")
	c._uq66_day(7)
	t.eq(_v(st, "UQ66_DG"), 1, "들것이 강 이쪽을 도는 날 06:00 — 글을 읽음")
	t.eq(_v(st, "DG_STOP"), 2, "정류지 흑석")
	t.eq(Caravans.medic_at(4, 2), 6, "이레 중 4일째 흑석 로비")
	t.ok(_says(st, c, "TR_SO", "넷째 날은 흑석으로", ["됐다"]), "소윤희 — 글을 봤다(출처)")


func test_uq66_stop_wake_direct(t) -> void:
	var a := _host("K-26", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_SKP_SCIENCE": 60, "TR_SO_MET": 1})
	_play(st, c, "UQ66_DOCK", ["정비 모드 코드"])
	t.eq(_v(st, "UQ66_NURSE"), 2, "정지")
	t.ok(_says(st, c, "UQ66_DOOR", "비상 개방"), "승인자 응답 없음 — 비상 개방")
	t.eq(_v(st, "UQ66_OPEN"), 1, "열림")
	_play(st, c, "UQ66_CELL", ["예비 전지를 꺼낸다"])
	_play(st, c, "UQ66_FRIDGE", ["B계통 예비 전지"])
	t.eq(_v(st, "UQ66_NOTICE"), 0, "7호가 꺼져 있으면 글 없음")
	c._uq66_day(6)
	t.eq(_v(st, "UQ66_DG"), 0, "글이 없으니 들것은 모름")
	t.ok(_says(st, c, "TR_SO", "정류장으로는 못 써요", ["혈액은행이 열렸어요"]), "소윤희에게 직접 — 로봇이 멈춰 있으면 정류장은 아님")
	t.eq(_v(st, "UQ66_DG"), 1, "DG 협력")
	t.eq(_v(st, "DG_STOP"), 0, "간호 로봇이 꺼져 있으면 정류지는 아님")
	t.ok(_says(st, c, "UQ66_DOCK", "지하가 4도예요", ["정비 모드를 푼다"]), "깨어난 7호가 지하를 알아챔")
	t.eq(_v(st, "UQ66_NURSE"), 0, "다시 깨움")
	t.eq(_v(st, "UQ66_NOTICE"), 1, "로비 글은 지금")


func test_uq66_ward_cleared_and_self(t) -> void:
	var a := _host("K-26", "from_W")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_SKP_SCIENCE": 60, "PN_NURSE": 1})
	_play(st, c, "UQ66_DESK", ["내 등록 번호로"])
	t.ok(_says(st, c, "K-26_NURSE", "입원 기록이 없으시네요", ["내 퇴원 서류"]), "엉뚱한 짓 — 내 퇴원 서류")
	t.eq(_v(st, "UQ66_SELF"), 2, "받음")
	t.ok(_says(st, c, "K-26_NURSE", "재진이세요", ["붕대를 갈아"]), "붕대 — 재진")
	for p in UqR01.U66_WARD:
		st.boxes["kill:K-26:%d,%d" % [p.x, p.y]] = {"t": 0}
	c._u66_clear_ward()
	c._uq66_tick()
	t.eq(_v(st, "UQ66_WARD"), 3, "병동 정리")
	st.vars.set_v("GAME_DAY", 6)
	t.ok(_says(st, c, "K-26_NURSE", "병상 가동률은 0%"), "7호가 기억한다 — '환자분'")
	t.ok(_says(st, c, "UQ66_DOOR", "통제는 해제"), "환자가 없으니 통제 해제")
