## 단계 1-11i SQ-S10 「오늘의 4번 인력」(SD-04a §5.3): 발동 둘(22번 칸 문 · 고척 칠판) · 06시 이송 · 10시 경매(박자 입찰 · 십장 · 예산 600) ·
## 놓침(10:30 주인공 없이) · B 친척(귀빈석) · D 방송(장부함 번호 → 우도하 → 다음 06시) · 장부와 계약서 · C 습격 · 대기실 해방 ·
## E 소유(22번 칸) · 본소 매입 300/520 · 우리 열기(옮겨진 뒤) · 정착(스스로 고름) · 늦게 낌 · 견적 사망 · 기라희 사망.
extends RefCounted

const KIRA := "N-R02-040"


func _host(date: String, map_id: String, mark: String, gday := 4) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", gday)
	st.vars.set_v("P_REGNO", "S07-2259-0412")
	st.vars.set_v("PC_CAPS", 2000)
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_SKP_BARTER", 60)
	st.vars.set_v("PC_SKP_LOCKPICK", 60)
	st.vars.set_v("PC_SKP_SNEAK", 60)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = date
	var p := Act1Paths.new()
	p.setup(h)
	var c := SideS10.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c, p]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(h: InteriorHost, st: StoryState, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			var nm := str(cur["name"])
			if h.ev.handlers.has(nm) and not (nm == "s10" and str(cur["args"][0]) in ["up", "down"]):
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


func _k(st: StoryState) -> int:
	return int(st.vars.get_v("SQ_S10_KIRA"))


## 22번 칸 문에서 발동(10. 26. — 4일째) → 경매일 6일째(10. 28.)
func _started(gday := 4) -> Array:
	var r := _host("2277. 10. 26.  14:00", "H-03", "from_yard", gday)
	_play(r[0], r[1], "SQS10_CAGE22", ["기다려"])
	return r


## 경매일 06시 이송(고척 그라운드에 서 있다)
func _moved(r: Array, time := "08:00") -> void:
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	st.vars.set_v("GAME_DAY", 6)
	h.date_text = "2277. 10. 28.  " + time
	h.enter("GD-01", "from_W")
	r[2].tick()


func test_sq_s10_start_cage(t) -> void:
	var r := _started()
	var st: StoryState = r[1]
	t.eq(st.quests.stage("SQ-S10"), 10, "22번 칸 문에서 발동")
	t.eq(_v(st, "SQ_S10_START"), 4, "발동 날")
	t.eq(_v(st, "SQ_S10_AUCTION"), 6, "다음 날부터 처음 오는 경매일(GAME_DAY % 3 == 0)")
	t.eq([_v(st, "SQ_S10_AM"), _v(st, "SQ_S10_AD")], [10, 28], "절대 날짜 10월 28일")
	t.eq(_play(r[0], st, "SQS10_CAGE22", ["기씨 집이라니", "칸 벽에 긁힌", "기다려"]), [], "진술 · 각인 원고")
	t.eq([_v(st, "SQ_S10_TOLD"), _v(st, "SQ_S10_CARVE")], [1, 1], "B의 증거 둘")


func test_sq_s10_board_start(t) -> void:
	var r := _host("2277. 10. 27.  12:00", "GD-01", "from_W", 5)
	var st: StoryState = r[1]
	r[2].tick()
	t.eq(_play(r[0], st, "SQS10_BOARD"), [], "칠판 원고")
	t.eq(st.quests.stage("SQ-S10"), 20, "칠판에서 발동 — 10 → 20(경매 주기를 앎)")
	t.eq(_v(st, "SQ_S10_AUCTION"), 6, "5일째 발동 → 6일째 경매")
	t.eq([_v(st, "SQ_S10_NM"), _v(st, "SQ_S10_ND")], [10, 28], "칠판 귀퉁이 다음 경기 날짜")


func test_sq_s10_move_and_auction_a(t) -> void:
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	st.vars.set_v("GAME_DAY", 6)
	h.date_text = "2277. 10. 28.  05:30"
	h.enter("X-SB", "arrive")
	c.tick()
	t.eq(_k(st), 0, "06시 전엔 우리에")
	h.date_text = "2277. 10. 28.  06:10"
	c.tick()
	t.eq(_k(st), 1, "06시 고척 지하로 이송")
	# 견적에게 패(보증금) · 귀빈석에서 예산 600
	h.date_text = "2277. 10. 28.  09:20"
	h.enter("GD-02", "from_GD-01")
	c.tick()
	t.eq(_v(st, "SQ_S10_SEO"), 1, "09시 기서윤이 귀빈석에")
	t.eq(st.quests.stage("SQ-S10"), 30, "경매일 09시 뒤 고척 — 30")
	t.eq(_play(h, st, "SQS10_SEO", ["물물교환 50", "그만둔다"]), [], "귀빈석 원고")
	t.eq(_v(st, "SQ_S10_BUDGET"), 1, "예산 600을 털어놓음")
	h.enter("GD-01", "from_GD-02")
	t.eq(_play(h, st, "SQS10_HOST", ["구매자 패", "보증금을 낸다", "됐어"]), [], "견적 원고")
	t.eq(_v(st, "SQ_S10_PADDLE"), 1, "7번 패")
	var caps0 := _v(st, "PC_CAPS")
	h.date_text = "2277. 10. 28.  10:00"
	c.tick()
	t.eq(_k(st), 2, "10시 그라운드 — 경매 장면")
	# 3번은 지켜보고 · 100 · (십장 450) · 100 · (기서윤 600) · 50 → 650 낙찰
	var e := _play(h, st, "SQS10_AUCTION", ["지켜본다", "100 올린다", "100 올린다", "50 올린다", "계약서를 기라희에게"])
	t.eq(e, [], "박자 입찰 원고")
	t.eq(_v(st, "SQ_S10_FORE"), 1, "십장이 450에 한 번 끼었다")
	t.eq(_v(st, "SQ_S10_PRICE"), 650, "예산 600을 넘긴 650에 낙찰")
	t.eq(caps0 - _v(st, "PC_CAPS"), 550, "낙찰가 650 − 보증금 100")
	t.eq(_k(st), 3, "계약서를 받은 기라희 — 정문 앞")
	t.eq([_v(st, "SQ_S10_SOL"), _v(st, "SQR_S10")], [1, 1], "A 낙찰")
	t.eq(st.quests.stage("SQ-S10"), 100, "닫힘")
	# 정착: 스스로 고른다(127번 봉천 아님 → 노들) · 복권
	t.eq(_play(h, st, "SQS10_KIRA", ["받는다"]), [], "정문 앞 원고")
	t.eq(_v(st, "SQ_S10_PLACE"), 2, "고향 노들 남문 앞")
	t.eq(st.count_of("M-321"), 1, "할머니의 복권(M-321)")
	c._on_day(7)
	t.eq(_k(st), 4, "다음 날 그곳에 선다")


func test_sq_s10_missed(t) -> void:
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	st.vars.set_v("GAME_DAY", 6)
	h.date_text = "2277. 10. 28.  10:40"
	h.enter("X-SB", "arrive")
	c.tick()
	c.tick()
	t.eq(_k(st), 6, "주인공 없이 — 세이프빌 112동 노역")
	t.eq(_v(st, "SQR_S10"), 9, "SQR 9 팔림")
	t.eq(st.quests.stage("SQ-S10"), 100, "감점 없이 닫힘")
	h.enter("GD-01", "from_W")
	t.eq(h.map.props.filter(func(p): return p["name"] == "gd_board").size(), 1, "칠판(낙찰 — 세이프빌)")


func test_sq_s10_kin_b(t) -> void:
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	_play(h, st, "SQS10_CAGE22", ["기씨 집이라니", "기다려"])
	_moved(r, "09:30")
	h.enter("GD-02", "from_GD-01")
	c.tick()
	t.ok(_has(_opts(st, "SQS10_SEO"), "같은 집안"), "진술이 있으면 [화술 쉬움]")
	t.eq(_play(h, st, "SQS10_SEO", ["같은 집안"]), [], "친척 원고")
	t.eq(_v(st, "SQ_S10_KIN"), 1, "기서윤이 입찰을 거둔다")
	h.date_text = "2277. 10. 28.  10:35"
	c.tick()
	t.eq(_k(st), 5, "세이프빌 식당 — 번호표 없이")
	t.eq(_v(st, "SQR_S10"), 2, "B")


func test_sq_s10_ledger_cast_d(t) -> void:
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	_moved(r, "08:00")
	h.enter("GD-03", "from_GD-01")
	st.call_fn("give", ["I-054", 1])
	t.eq(_play(h, st, "SQS10_CELL1", ["한강 물"]), [], "140번 탁현수 부탁")
	t.eq(_v(st, "SQ_S10_CODE"), 1, "장부함 번호를 앎")
	h.enter("GD-01", "from_GD-03")
	c.tick()
	t.eq(_play(h, st, "SQS10_LEDGERBOX"), [], "견적이 보는 앞 — 막힘")
	t.eq(_v(st, "SQ_S10_LEDGER"), 0, "견적 눈앞에선 못 연다")
	st.vars.set_v("SQ_S10_CAT", 1)                                         # 캣워크로 단상 뒤에 내려옴
	t.eq(_play(h, st, "SQS10_LEDGERBOX", ["4 · 0 · 8 · 8"]), [], "장부함 원고")
	t.eq([_v(st, "SQ_S10_LEDGER"), st.count_of("M-322")], [1, 1], "구매 장부 손에")
	h.enter("K-06", "from_W")
	t.eq(_play(h, st, "SQS10_WOO", ["구매 장부"]), [], "우도하 원고")
	t.eq(_v(st, "SQ_S10_CAST"), 1, "넘겼다")
	h.date_text = "2277. 10. 28.  10:40"
	h.enter("X-SB", "arrive")
	c.tick()
	t.eq(_k(st), 6, "방송은 내일 — 오늘은 기서윤이 산다")
	t.eq(_v(st, "SQR_S10"), 4, "D만 — 장부는 남산으로, 사람은 못 구함")
	c._on_day(7)
	t.eq([_v(st, "SQ_S10_CAST"), _v(st, "SQ_S10_STOP")], [2, 1], "다음 06시 송출 · 세이프빌 구매 중단")
	st.vars.set_v("GAME_DAY", 9)
	h.date_text = "2277. 10. 31.  09:30"
	c.tick()
	t.eq(_v(st, "SQ_S10_SEO"), 0, "기서윤이 다음 경매부터 안 온다")


func test_sq_s10_swap(t) -> void:
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	_moved(r, "09:30")
	st.vars.set_v("SQ_S10_CODE", 1)
	st.vars.set_v("SQ_S10_CAT", 1)
	_play(h, st, "SQS10_LEDGERBOX", ["4 · 0 · 8 · 8"])
	h.enter("GD-02", "from_GD-01")
	c.tick()
	t.eq(_play(h, st, "SQS10_SEO", ["구매 장부", "계약서를 줘"]), [], "장부와 계약서 원고")
	t.eq([_v(st, "SQ_S10_SWAP"), _v(st, "SQ_S10_LEDGER")], [1, 3], "장부를 넘겼다")
	h.date_text = "2277. 10. 28.  10:35"
	c.tick()
	t.eq(_k(st), 3, "300에 사서 계약서째 — 정문 앞")
	t.eq(_v(st, "SQR_S10"), 8, "교환")


func test_sq_s10_raid_and_pen(t) -> void:
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	_moved(r, "08:00")
	st.vars.set_v("SQ_S10_PADDLE", 1)
	h.date_text = "2277. 10. 28.  10:00"
	c.tick()
	t.eq(_k(st), 2, "경매 시작")
	t.eq(_play(h, st, "SQS10_AUCTION", ["지켜본다", "총을 뽑는다"]), [], "습격 원고")
	t.eq(_v(st, "SQ_S10_RAID"), 1, "습격")
	t.eq(_k(st), 3, "소동 속에 정문 쪽으로")
	t.eq(_v(st, "SQR_S10"), 3, "C")
	t.ok(c._gd.size() >= 8, "그라운드 새벽인력 + 증원이 적으로(%d)" % c._gd.size())
	h.enter("GD-03", "from_GD-01")
	t.eq(_play(h, st, "SQS10_PEN", ["당긴다"]), [], "개폐기 원고")
	t.eq([_v(st, "SQ_S10_PEN"), _v(st, "SQS_S10")], [1, 1], "대기실 해방 — MQ-504 순서 파괴 기록")
	t.eq(_v(st, "PD_R02_GD"), -15, "판도 PD-R02-5 −15")


func test_sq_s10_buy88_prices(t) -> void:
	var r := _host("2277. 10. 26.  14:00", "H-04", "from_H-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	st.vars.set_v("SB_PASS", 1)
	t.ok(_has(_opts(st, "MQ-105_HDC_BUY", "AGAIN"), "88번을 산다"), "발동 전 300")
	r[2]._start("시험")
	st.vars.set_v("GAME_DAY", 5)                                         # 520은 경매 전날부터
	var o := _opts(st, "MQ-105_HDC_BUY", "AGAIN")
	t.ok(_has(o, "88번을 뺀다"), "발동 뒤 520")
	t.ok(not _has(o, "88번을 산다"), "300은 닫힘")
	t.eq(_play(h, st, "MQ-105_HDC_BUY", ["88번을 뺀다", "다음에"], "AGAIN"), [], "520 매입 원고")
	t.eq(_k(st), 4, "본소에서 풀림 — 노들")
	t.eq(_v(st, "SQR_S10"), 6, "본소 매입")


func test_sq_s10_cage_after_move(t) -> void:
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	_moved(r, "07:00")
	t.eq(_k(st), 1, "고척 지하")
	h.enter("H-03", "from_yard")
	h.player.loco.logical = Vector2(22 * 32 + 16, 9 * 32 + 16)
	t.eq(_play(h, st, "SQS10_CAGE22", []), [], "빈 칸 원고")
	t.ok(not _has(_opts(st, "SQS10_CAGE22"), "기다려"), "빈 칸 — 문 메뉴 없음")
	c.tick()
	t.eq(_k(st), 1, "우리 열기가 고척의 그녀를 건드리지 않는다")


func test_sq_s10_keep_release(t) -> void:
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	_moved(r, "08:00")
	st.vars.set_v("SQ_S10_PADDLE", 1)
	h.date_text = "2277. 10. 28.  10:00"
	c.tick()
	var e := _play(h, st, "SQS10_AUCTION", ["지켜본다", "100 올린다", "100 올린다", "100 올린다", "100 올린다", "본소에 맡긴다"])
	t.eq(e, [], "E 원고(400 · 십장 450 · 550 · 600 · 700 · 750 · 850 낙찰)")
	t.eq(_v(st, "SQ_S10_PRICE"), 850, "상한 750을 넘긴 850")
	t.eq(_k(st), 7, "주인공 소유 — 본소 22번 칸")
	t.eq(_v(st, "SQR_S10"), 5, "E")
	h.enter("H-03", "from_yard")
	t.eq(_play(h, st, "SQS10_CAGE22", ["문을 열어 준다"]), [], "소유 판 원고")
	t.eq(_k(st), 4, "계약서를 찢고 풀어 줌")


func test_sq_s10_late_and_deaths(t) -> void:
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	st.vars.set_v("GAME_DAY", 6)
	h.date_text = "2277. 10. 28.  10:20"
	h.enter("GD-01", "from_W")
	c.tick()
	c.tick()
	t.eq(_k(st), 2, "10:20 들어옴 — 경매에 낀다")
	t.eq([_v(st, "SQ_S10_LATE"), _v(st, "SQ_S10_PRICE"), _v(st, "SQ_S10_LEAD")], [1, 450, 2], "늦게: 십장이 450을 든 뒤")
	# 견적 사망: 경매가 열리지 않는다
	var r2 := _started()
	var st2: StoryState = r2[1]
	st2.kill("N-R02-043")
	_moved(r2, "10:45")
	r2[2].tick()
	t.eq(_k(st2), 1, "견적이 없으면 경매 없음 — 지하에 남는다")
	# 기라희 사망
	var r3 := _started()
	var st3: StoryState = r3[1]
	st3.kill(KIRA)
	r3[2].tick()
	t.eq(_v(st3, "SQR_S10"), 12, "기라희 사망 — 닫힘")


func test_sq_s10_fun_fixes(t) -> void:
	# 유리창: 상한까지 남은 값 셋(재미 검수 1)
	var r := _started()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS10 = r[2]
	_moved(r, "08:00")
	st.vars.set_v("SQ_S10_PADDLE", 1)
	st.vars.set_v("PC_PE", 6)
	h.date_text = "2277. 10. 28.  10:00"
	c.tick()
	t.eq(_play(h, st, "SQS10_AUCTION", ["지켜본다", "100 올린다", "100 올린다", "100 올린다", "인지력 5", "지켜본다", "지켜본다"]), [], "유리창 원고")
	t.eq(_v(st, "SQ_S10_PRICE"), 750, "400 · 십장 450 · 550 · 600 · 700 · 기서윤 750(상한 — 유리창은 GEND)")
	t.eq(_k(st), 6, "두 번 지켜보면 세이프빌")
	# 기서윤이 없을 때(죽음): 십장 450 → 감독관 500 한 번 → 550이면 낙찰
	var r2 := _started()
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	st2.kill("N-R02-044")
	_moved(r2, "08:00")
	st2.vars.set_v("SQ_S10_PADDLE", 1)
	h2.date_text = "2277. 10. 28.  10:00"
	r2[2].tick()
	t.eq(_play(h2, st2, "SQS10_AUCTION", ["지켜본다", "100 올린다", "50 올린다", "50 올린다", "계약서를"]), [], "기서윤 없는 경매 원고")
	t.eq(_v(st2, "SQ_S10_PRICE"), 600, "300 → 400 · 십장 450 → 500 · 감독관 550(한 번) → 600 낙찰")
	t.eq(_k(st2), 3, "A")
	# 아무도 살 사람이 없으면 유찰 — 지하에 남는다
	var r3 := _started()
	var st3: StoryState = r3[1]
	for id in ["N-R02-044", "N-R02-508", "N-R02-509"]:
		st3.kill(id)
	_moved(r3, "10:40")
	r3[2].tick()
	t.eq([_k(st3), _v(st3, "SQ_S10_DONE")], [1, 1], "유찰 — 지하 대기실")
	# 되팔기는 회장단 선(상한)에서 수수료를 뗀 값
	var r4 := _started()
	var h4: InteriorHost = r4[0]
	var st4: StoryState = r4[1]
	_moved(r4, "09:30")
	st4.vars.set_v("SQ_S10_BUDGET", 1)
	st4.vars.set_v("SQ_S10_PADDLE", 1)
	h4.date_text = "2277. 10. 28.  10:00"
	r4[2].tick()
	var caps := _v(st4, "PC_CAPS")
	t.eq(_play(h4, st4, "SQS10_AUCTION", ["지켜본다", "100 올린다", "100 올린다", "50 올린다", "되판다"]), [], "되팔기 원고")
	t.eq(_v(st4, "PC_CAPS") - caps, 540 - 650, "650에 사서 600 − 10% = 540에 판다(손해)")
	t.eq(_k(st4), 6, "되팖 — 세이프빌")
	# 520은 경매 전날부터(그 전엔 300)
	var r5 := _started()
	var st5: StoryState = r5[1]
	st5.vars.set_v("SB_PASS", 1)
	t.ok(_has(_opts(st5, "MQ-105_HDC_BUY", "AGAIN"), "88번을 산다"), "발동 날(경매 이틀 전) — 아직 300")
	st5.vars.set_v("GAME_DAY", 5)
	t.ok(_has(_opts(st5, "MQ-105_HDC_BUY", "AGAIN"), "88번을 뺀다"), "경매 전날 — 520")
