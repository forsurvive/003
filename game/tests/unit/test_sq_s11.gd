## 단계 1-11j SQ-S11 「토요일의 여의도」(SD-04a §5.4): 발동 셋(인지영 · 의사록 · LR-11) · 경찰서(서장 열쇠 · 경비 파수 넷 · 배관 우회 · 별첨 출력) ·
## 기록관(서고 번호 — 화술 · 유인물 · 카드 목록함 · 원본 상자) · 명단 a 낭독(호위 · 머리띠) · b 남산(다음 06시) · c 계엄군(인수증 · 낭독 닫힘) ·
## 원본 a · b(거점 · 깃발 · 연동) · c 보관 · d 되돌림 · 처음 넘긴 곳이 행방(P1) · 7일 자동 보관 · 5일 반출 소문 · 순찰 회수 · 인지영 · 의사록 · 우도하 사망.
extends RefCounted

const INJI := "N-R02-014"
const LOG := "N-R02-027"
const WOO := "N-R02-026"


func _host(date: String, map_id: String, mark: String, gday := 4) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", gday)
	st.vars.set_v("P_REGNO", "S07-2259-0412")
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_SKP_SNEAK", 100)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = date
	var c := SideS11.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 원고를 끝까지(또는 picks 차례로 고르며): s11 명령은 진행기로(넘겨받기 talk · 배관 pipe는 연출이라 건너뜀)
func _play(h: InteriorHost, st: StoryState, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			var nm := str(cur["name"])
			if h.ev.handlers.has(nm) and not (nm == "s11" and str(cur["args"][0]) in ["talk", "pipe"]) and nm != "note":
				h.ev.handlers[nm].call(cur["args"], func() -> void: pass)
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


func _opts(st: StoryState, id: String, label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var guard := 0
	while cur["type"] != "end" and cur["type"] != "choices" and guard < 200:
		guard += 1
		cur = dr.advance()
	var out := []
	if cur["type"] == "choices":
		for o in cur["opts"]:
			if bool(o["enabled"]):
				out.append(str(o["text"]))
	return out


func _has(arr: Array, needle: String) -> bool:
	for s in arr:
		if str(s).contains(needle):
			return true
	return false


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _items(st: StoryState, id: String) -> int:
	return int(st.items.get(id, 0))


## 경찰서에서 별첨을 읽고 명단을 한 장 뽑은 상태
func _printed(r: Array, n := 1) -> void:
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	h.enter("K-29", "from_W")
	st.vars.set_v("SQ_S11_REPORT", 1)
	for i in n:
		_play(h, st, "SQS11_PRINT", ["사본을 뽑는다"])


## 기록관에서 원본을 꺼낸 상태(의사록에게 번호를 듣고)
func _took(r: Array) -> void:
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	h.enter("KH-03", "from_KH-01")
	_play(h, st, "SQS11_LOG", ["원본을 볼 수 있나", "지키는 사람이", "됐어"])
	_play(h, st, "SQS11_BOX", ["가져간다"])


func test_sq_s11_start_inji(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "J-03", "from_J-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var g := h.scene_for(INJI)
	t.eq(str(g.get("id", "")), "MQ-103_INJI", "인지영의 첫 장면은 MQ-103_INJI(넘겨받기)")
	t.eq(_play(h, st, "SQS11_INJI", ["열한 명?", "그날 이야기", "됐어"]), [], "인지영 원고")
	t.eq(st.quests.stage("SQ-S11"), 20, "발동 ① → 보고서는 경찰서에(20)")
	t.ok(not _has(_opts(st, "SQS11_INJI"), "사망자 명단"), "명단이 없으면 보여 줄 수 없다")


func test_sq_s11_leaflet_start(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "K-02", "")
	var st: StoryState = r[1]
	t.eq(_play(r[0], st, "K-02_LEAFLET"), [], "연수원 해골 유인물")
	t.eq([_v(st, "SQ_S11_LEAF"), st.quests.stage("SQ-S11")], [1, 10], "발동 ③ LR-11")
	t.ok(_has(_opts(st, "SQS11_INJI", "MENU"), "종전 유인물"), "인지영에게 유인물을 보여 줄 수 있다")


func test_sq_s11_police(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "K-29", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS11 = r[2]
	var wb: Variant = h.map.boxes.get(Vector2i(19, 3))
	t.eq(int((h.box_contents(wb)["items"] as Dictionary).get("M-323", 0)), 1, "서장 열쇠는 무기 보관함에")
	var term: Dictionary = h._terms()["TM-K29"]
	t.eq([int(term["lock"]), str(term.get("key", ""))], [25, "M-323"], "단말 [과학 25] 또는 서장 열쇠(원문)")
	t.ok(_has(_opts(st, "SQS11_PRINT"), "사본") == false, "별첨을 읽기 전엔 프린터가 대기만")
	StoryExpr.run(str(term["entries"][0]["set"]), st)                     # LR-12를 읽음
	t.eq([_v(st, "SQ_S11_REPORT"), _v(st, "SQK_MARCH")], [1, 1], "LR-12 → 파수-3 240기를 앎(MQ-302 · S18)")
	_play(h, st, "SQS11_PRINT", ["사본을 뽑는다"])
	_play(h, st, "SQS11_PRINT", ["사본을 뽑는다"])
	c.tick()
	t.eq([_items(st, "M-305"), st.quests.stage("SQ-S11")], [2, 30], "명단은 여러 장 · 따라 올림(10 → 30)")


func test_sq_s11_guard(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "K-29", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS11 = r[2]
	var a := c._guard_actor()
	t.ok(a != null, "서장실 문 앞 경비 파수")
	t.eq(h.map.tile_of(a.loco.logical), Vector2i(4, 10), "문 칸을 막고 선다")
	h.player.loco.place(a.loco.logical + Vector2(0, 64))
	c.tick()
	t.eq(_v(st, "SQ_S11_GUARD"), 1, "다가가면 깨어난다")
	var o := _opts(st, "SQS11_GUARD", "MENU")
	t.ok(not _has(o, "판독 기록 조회"), "조회는 기록을 알아야")
	st.vars.set_v("SQ_S11_TOLD", 1)
	t.eq(_play(h, st, "SQS11_GUARD", ["판독 기록 조회"]), [], "조회 원고")
	t.eq(_v(st, "SQ_S11_GUARD"), 2, "말로 넘김 — 사건 조사 종결")
	t.eq(int(st.vars.get_v("V_WANTED")), 0, "조회는 수배도 없음")
	h.refresh_npcs()
	t.eq(h.map.tile_of(c._guard_actor().loco.logical), Vector2i(6, 12), "옆으로 비켜 선다")
	# 관리자 인증 · 명단 보여 주기(해 보고 싶은 짓) · 부수기
	st.vars.set_v("SQ_S11_GUARD", 1)
	st.vars.set_v("V_REGCARD", 4)                                       # 관리자 인증은 등록증 4단계부터(선택지 표시)
	h.refresh_npcs()
	st.call_fn("give", ["M-305", 1])
	t.eq(_play(h, st, "SQS11_GUARD", ["사망자 명단을 보여", "조사를 종결한다"]), [], "명단 → 인증")
	t.eq([_v(st, "SQ_S11_SHOWN"), _v(st, "SQK_MARCH"), _v(st, "SQ_S11_GUARD")], [1, 1, 2], "'YD-0233. 해당 판독은 정확했습니다.' · 인증 통과")
	t.ok(int(st.vars.get_v("V_WANTED")) >= 3, "관리자 인증 수배도 +3")
	st.vars.set_v("SQ_S11_GUARD", 1)
	h.refresh_npcs()
	_play(h, st, "SQS11_GUARD", ["부순다"])
	t.eq(_v(st, "SQ_S11_GUARD"), 9, "파괴")
	t.ok(c._guard_e != null and not c._guard_e.cmb.dead, "적이 된 파수-3")
	t.ok(c._guard_actor() == null, "맵 인물 경비는 사라진다")
	h.enter("K-29", "from_W")
	t.ok(c._guard_e != null and not c._guard_e.cmb.dead, "부순 파수는 쓰러질 때까지 다시 선다(불러오기 · 맵 이탈)")


func test_sq_s11_pipe(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "K-29", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS11 = r[2]
	st.vars.set_v("SQ_S11_GUARD", 1)
	h.player.loco.place(h.map.mark_pos("pipe_cell"))
	c.tick()
	t.eq(_v(st, "SQ_S11_ATOFFICE"), 0, "유치장 쪽")
	t.ok(_has(_opts(st, "SQS11_PIPE"), "소리 없이"), "깨어 있는 파수 앞에선 은신 판정")
	c._cmd(["pipe", "in"], func() -> void: pass)
	t.eq(_v(st, "SQ_S11_GUARD"), 3, "배관 우회(파수는 문 앞 그대로)")
	h.player.loco.place(h.map.mark_pos("pipe_office"))
	c.tick()
	t.eq(_v(st, "SQ_S11_ATOFFICE"), 1, "서장실 안")
	t.ok(_has(_opts(st, "SQS11_PIPE", "OUT"), "기어 나간다"), "돌아 나가는 배관")
	t.ok(_has(_opts(st, "SQS11_GUARD", "MENU"), "물러난다"), "안에서 말을 걸면 '출입 기록 없음' 판")


func test_sq_s11_archive(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "KH-03", "from_KH-01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS11 = r[2]
	t.ok(h.map.doors.any(func(d): return int(d["x"]) == 24 and int(d["y"]) == 9 and bool(d["locked"])), "제7 서고는 잠겨 있다")
	t.eq(_play(h, st, "SQS11_LOG", ["휴회 결의?", "원본을 볼 수 있나", "지키는 사람이", "됐어"]), [], "의사록 원고")
	c.tick()
	t.eq([_v(st, "SQ_S11_KNOWS"), _v(st, "SQ_S11_STACK"), st.quests.stage("SQ-S11")], [1, 1, 40], "발동 ② · 서고 번호 · 40")
	t.ok(h.map.doors.any(func(d): return int(d["x"]) == 24 and int(d["y"]) == 9 and not bool(d["locked"])), "번호를 들으면 문이 열린다")
	t.eq(_play(h, st, "SQS11_BOX", ["가져간다"]), [], "원본 상자")
	c.tick()
	t.eq([_items(st, "M-306"), _v(st, "SQ_S11_TOOK"), _v(st, "SQ_S11_HELD_DAY"), st.quests.stage("SQ-S11")], [1, 1, 4, 50], "원본이 손에(50)")
	t.eq(h.map.set_prop_state(Vector2i(24, 5), "open"), "kh_box", "빈 보존 상자 그림(상태 open)")
	# 같은 문장, 두 해석의 실마리: 제118석 · 전광판 → 의사록
	st.vars.set_v("SQ_S11_PLATE", 1)
	st.vars.set_v("SQ_S11_VOTE", 1)
	t.eq(_play(h, st, "SQS11_LOG", ["제118석 쪽지", "붉은 테", "됐어"]), [], "재개 조항 · 붉은 테")
	t.eq([_v(st, "SQ_S11_CLAUSE"), _v(st, "SQ_S11_VOTE")], [1, 2], "조항 제3항을 앎 · 전광판 대사 한 번")
	t.ok(_has(_opts(st, "SQS11_SUN", "DOC3"), "재개 조항 제3항"), "선우진에게 조항으로 맞설 수 있다")


func test_sq_s11_catalog_and_log_dead(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "KH-03", "from_KH-01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	st.kill(LOG)
	st.vars.set_v("PC_PE", 6)
	t.eq(_play(h, st, "SQS11_CATALOG", ["10월 서랍"]), [], "카드 목록함 원고")
	t.eq(_v(st, "SQ_S11_STACK"), 1, "의사록이 죽어도 카드에서 서고 번호(재미 검수 7)")
	_play(h, st, "SQS11_BOX", ["가져간다"])
	st.vars.set_v("SQ_S11_WARN", 1)
	t.ok(_has(_opts(st, "SQS11_BOX", "EMPTY"), "되돌려 넣는다"), "상자에 직접 되돌릴 수 있다")
	_play(h, st, "SQS11_BOX", ["되돌려 넣는다"])
	t.eq([_v(st, "SQH_RECESS"), _v(st, "SQ_S11_SOL_D"), _items(st, "M-306")], [97, 4, 0], "d 기록관에 되돌림")


func test_sq_s11_list_b_doc_b_close(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "K-06", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS11 = r[2]
	_printed(r, 2)
	_took(r)
	h.enter("K-06", "from_W")
	c.tick()
	t.eq([_v(st, "SQ_S11_WOOQ"), _v(st, "SQ_S11_SUNQ")], [1, 1], "꺼낼 국회 기록이 있다")
	t.ok(_has(_opts(st, "SQS10_WOO"), "여의도 기록"), "우도하 메뉴에 여의도 기록")
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(h, st, "SQS11_WOO", ["사망자 명단을 건넨다"]), [], "우도하 명단")
	t.eq([_v(st, "SQH_LIST11"), _v(st, "SQE_LIST11"), _v(st, "SQ_S11_CASTL"), _v(st, "NS_COOP")], [14, 1, 1, 1], "b 남산 · 방송 대기 · 협력")
	t.eq(_v(st, "V_KARMA") - k0, 50, "명단 b +50")
	st.vars.set_v("GAME_DAY", 5)
	h._daily()
	t.eq(_v(st, "SQ_S11_CASTL"), 2, "다음 06시 송미래 낭독")
	# 원본 b 선우진(같은 조항, 다른 읽기)
	var bj := _v(st, "AFF_BJ")
	t.eq(_play(h, st, "SQS11_SUN", ["휴회 결의 원본", "넘긴다"]), [], "선우진 원본")
	t.eq([_v(st, "SQH_RECESS"), _v(st, "PD_R02_KH"), _v(st, "AFF_BJ") - bj], [1, 1, 8], "b 비상정부 · 거점 '국회 폐허' → BJ")
	t.eq([_v(st, "SQ_S11_DONE"), st.quests.stage("SQ-S11"), _v(st, "SQR_S11")], [1, 100, 1], "두 기록이 자리를 찾았다(100)")
	t.eq(_items(st, "M-305"), 1, "명단 사본은 남는다")


func test_sq_s11_first_place_wins(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "K-06", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	_printed(r, 3)
	_play(h, st, "SQS11_SUN", ["사망자 명단을 건넨다"])
	t.eq([_v(st, "SQH_LIST11"), _v(st, "SQ_S11_PASS"), _v(st, "SQ_S11_SOL_L")], [1, 1, 4], "c 계엄군 · 인수증(낮 통행)")
	_play(h, st, "SQS11_WOO", ["사망자 명단을 건넨다"])
	t.eq(_v(st, "SQH_LIST11"), 1, "처음 넘긴 곳이 행방(P1) — 남은 사본은 한 줄만")
	t.eq(_v(st, "SQ_S11_CASTL"), 0, "사본으로는 방송하지 않는다")
	h.enter("J-03", "from_J-02")
	t.eq(_play(h, st, "SQS11_INJI"), [], "인지영 — 인수증 판")
	t.ok(not _has(_opts(st, "SQS11_INJI"), "같이 가자"), "낭독은 닫혔다")
	r[2]._cmd(["escort"], func() -> void: pass)
	t.eq(_v(st, "SQ_S11_ESCORT"), 0, "명단이 간 뒤엔 호위가 서지 않는다")


func test_sq_s11_read_a(t) -> void:
	var r := _host("2277. 10. 26.  21:00", "J-03", "from_J-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS11 = r[2]
	st.call_fn("give", ["M-305", 1])
	t.eq(_play(h, st, "SQS11_INJI", ["사망자 명단을 보여", "같이 가자"]), [], "호위 시작")
	t.eq(_v(st, "SQ_S11_ESCORT"), 1, "인지영 동행")
	t.ok(not c._mate().is_empty(), "동행 목록에")
	h.refresh_npcs()
	t.ok(not h.npcs.any(func(n): return str(n["id"]) == INJI), "벤치가 빈다")
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(h, st, "SQS11_READ"), [], "낭독 원고(이름 열하나)")
	t.eq([_v(st, "SQ_S11_READ"), _v(st, "SQH_LIST11"), _v(st, "SQ_S11_SOL_L"), _v(st, "SQE_LIST11")], [1, 4, 1, 1], "a 인지영 낭독")
	t.eq([_v(st, "V_KARMA") - k0, _items(st, "A-084")], [100, 1], "+100 · 종전 행진 머리띠")
	t.ok(c._mate().is_empty(), "동행 끝")
	t.eq(_v(st, "SQ_S11_ESCORT"), 3, "벤치로 돌아간다")
	t.eq(_play(h, st, "SQS11_INJI"), [], "낭독 뒤 대사")


func test_sq_s11_escort_captured(t) -> void:
	var r := _host("2277. 10. 26.  21:00", "J-03", "from_J-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS11 = r[2]
	st.call_fn("give", ["M-305", 1])
	_play(h, st, "SQS11_INJI", ["사망자 명단을 보여", "같이 가자"])
	h.enter("H-03", "from_yard")
	t.eq(_v(st, "SQ_S11_ESCORT"), 0, "호위 중 생포 — 인지영은 우리까지 오지 않는다")
	t.ok(c._mate().is_empty(), "동행에서 빠진다")
	h.enter("J-03", "from_J-02")
	t.ok(h.npcs.any(func(n): return str(n["id"]) == INJI), "벤치로 돌아와 있다")
	t.ok(_has(_opts(st, "SQS11_INJI", "MENU"), "사망자 명단"), "다시 부탁할 수 있다")


func test_sq_s11_inji_dead_self_read(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "J-03", "from_J-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	st.call_fn("give", ["M-305", 1])
	st.kill(INJI)
	t.ok(_has(_opts(st, "SQS11_STEPS", "SELF"), "계단에 놓고"), "인지영이 죽으면 혼자 읽는다")
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(h, st, "SQS11_STEPS", ["계단에 놓고"]), [], "혼자 낭독 원고")
	t.eq([_v(st, "SQH_LIST11"), _v(st, "SQ_S11_SOL_L"), _v(st, "SQ_S11_READ"), _v(st, "V_KARMA") - k0, _items(st, "A-084")], [4, 2, 2, 50, 0], "+50 · 머리띠 없음")
	h.enter("J-03", "from_J-02")
	t.ok(h.map.texts.values().any(func(s): return str(s).contains("빈 벤치")), "벤치에 유인물 한 장")


func test_sq_s11_keep_7days(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "KH-03", "from_KH-01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	_printed(r, 1)
	_took(r)
	for d in [5, 6, 7, 8]:
		st.vars.set_v("GAME_DAY", d)
		r[2]._on_day(d)
	t.eq(_v(st, "SQ_S11_WARN"), 0, "4일째까지는 소문 없음")
	st.vars.set_v("GAME_DAY", 9)
	r[2]._on_day(9)
	t.eq(_v(st, "SQ_S11_WARN"), 1, "5일째 반출 소문(재미 검수 6)")
	t.ok(_has(_opts(st, "SQS11_BOX", "EMPTY"), "되돌려 넣는다"), "빈 상자 위 의사록 쪽지 판")
	st.vars.set_v("GAME_DAY", 11)
	r[2]._on_day(11)
	t.eq([_v(st, "SQH_RECESS"), _v(st, "SQE_RECESS"), _v(st, "SQH_LIST11"), _v(st, "SQE_LIST11")], [0, 1, 0, 1], "7일 → 원본 · 명단 보관")
	t.eq(st.quests.stage("SQ-S11"), 100, "보관으로 자동 종료")
	t.eq([_items(st, "M-306"), _items(st, "M-305")], [1, 1], "보관 = 주인공 손에")


func test_sq_s11_patrol_and_misc(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "J-03", "from_J-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS11 = r[2]
	_took(r)
	st.vars.set_v("SQ_S11_WARN", 1)
	t.eq(c._patrol_kind(), 2, "반출 소문 뒤 원본을 든 채 → 문서 검문")
	st.vars.set_v("SQ_S11_PKIND", 2)
	t.ok(_has(_opts(st, "SQS11_PATROL", "DMENU"), "원본을 내준다"), "검문 선택지")
	c._patrol("give")
	t.eq([_v(st, "SQH_RECESS"), _v(st, "PD_R02_KH"), _items(st, "M-306")], [1, 1, 0], "검문 회수 = 비상정부(행방 1)")
	h.enter("J-03", "from_J-02")
	st.call_fn("give", ["M-306", 1])
	t.eq(_play(h, st, "JM_SAGONG"), [], "골동품상 원고")
	t.eq(_v(st, "SQ_S11_SAGONG"), 1, "원본 매입 거절 한 줄(해 보고 싶은 짓)")
	st.kill(WOO)
	c.tick()
	t.eq(_v(st, "SQ_S11_WOOQ"), 0, "우도하가 죽으면 남산 인도는 닫힌다")
	t.eq(_play(h, st, "SQS11_WOO"), [], "죽은 우도하 장면은 바로 끝")
