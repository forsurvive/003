## 단계 1-D10 U04 여의도 지하(L-UG-06 · 07 · 08, SD-09f · 1-D 계획 §16.6~§16.8):
## 자료(맵 다섯 · 장면 · 짐 아이템 · 던전 표 · 운반조 짐칸) · 수레 밀기(한 칸씩 · 막히면 선다) · 이음매 덜컹은 앞 무리를 먼저 깨운다(천 감으면 가깝게만) ·
## 맵 끝에서 수레가 따라 넘어감 · 내리막 타기와 브레이크 · 귀 대기 · 두드림(공병 통제선 · 밤 운반조 비켜 감) · 운송 왕복(진공관 깨짐 · 받을 사람 죽음) ·
## 대기 명단(뽑기 · 순복 · 남산 낭독 → 흩어짐) · 신길 대피민 모시기 · 정리 · 점검구 → 벙커 · 지하시장 후문.
extends RefCounted


func _host(map_id := "U4-01", mark := "from_E", hhmm := "10:00") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	st.vars.set_v("PC_SKP_SNEAK", 100)
	st.vars.set_v("PC_SKP_LOCKPICK", 100)
	st.vars.set_v("PC_SKP_REPAIR", 100)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  %s" % hhmm
	st.vars.set_v("GAME_HOUR", int(hhmm.substr(0, 2)))
	var c := U04.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: U04, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "u04":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				i = -1
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
				k += 1
			else:
				i = cur["opts"].size() - 1                                # 고를 것이 끝나면 마지막(그만둔다 · 다음에)
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return dr.errors


func _opts(st: StoryState, id: String) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var guard := 0
	while cur["type"] != "choices" and cur["type"] != "end" and guard < 50:
		guard += 1
		cur = dr.advance()
	if cur["type"] != "choices":
		return []
	return cur["opts"].filter(func(o): return bool(o["enabled"])).map(func(o): return str(o["text"]))


func _put(h: InteriorHost, x: int, y: int) -> void:
	h.player.loco.place(Vector2(x * 32 + 16, y * 32 + 16))


## 수레 뒤에 서서 걸어 들어간다(한 칸 민다)
func _push(h: InteriorHost, c: U04, d: int) -> bool:
	var x0 := c.cart_x()
	_put(h, x0 - 1 if d > 0 else x0 + 2, c._row())
	h.last_move = Vector2(d, 0)
	c._cd = 0.0
	c._process(0.05)
	h.last_move = Vector2.ZERO
	return c.cart_x() != x0


func _doze(h: InteriorHost, st: StoryState, x: int, y: int) -> Enemy:
	return h.combat.spawn("CR-204", Vector2(x * 32 + 16, y * 32 + 16), h.map, st, {"sheet": "en_cr204_loco", "dir": "S", "lv": 4, "arm": "claw", "doze": "sit"})


func _hints(h: InteriorHost) -> String:
	return " / ".join(h.hints.map(func(x): return str(x[0])))


func test_u04_data(t) -> void:
	for m in ["U4-01", "U4-02", "U4-03", "U4-04", "U4-05"]:
		t.ok(FileAccess.file_exists("res://data/maps/%s.json" % m), "맵 %s" % m)
	for s in ["U04_BACKDOOR", "U04_GOSANG", "U04_CHALK", "U04_SOMIN", "U04_CART", "U04_RAIL", "U04_SINGIL", "U04_DIG", "U04_RELAY", "U04_WOO", "U04_BOARD",
			"U04_HATCH", "U04_FLAP", "U04_LINE", "U04_HATCH_UP", "U04_KIGUN", "U04_SOONBOK", "U04_LIST", "U04_SEAT", "U04_LR11", "U04_SEAL", "U04_CARRIERS"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % s), "장면 %s" % s)
	var r := _host()
	var h: InteriorHost = r[0]
	for id in ["M-406", "M-407", "M-408", "M-409", "M-410", "M-215"]:
		t.ok(h.items_db.has(id), "아이템 %s" % id)
	var dg := FileAccess.get_file_as_string("res://data/dungeons.json")
	t.ok(dg.contains("DG_U04"), "던전 표 U04")
	t.ok(FileAccess.get_file_as_string("res://data/merchants.json").contains("VU4"), "운반조 짐칸 VU4")
	var m5: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/U4-02.json"))
	t.ok(str(m5.get("boxes", [])).contains("claim"), "신길 중계 사물함 = 내 몫으로 삼는 보관 자리")


func test_u04_push_and_clack(t) -> void:
	var r := _host("U4-01", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.eq(c.cart_x(), 3, "차고 — 차막이 앞")
	t.ok(h.map.is_solid(Vector2i(3, 18)) and h.map.is_solid(Vector2i(4, 18)), "수레가 레일 두 칸을 막는다")
	var ahead := _doze(h, st, 30, 19)
	var behind := _doze(h, st, 1, 21)
	var far := _doze(h, st, 43, 18)
	t.ok(_push(h, c, 1), "한 칸 민다")
	t.eq(c.cart_x(), 4, "수레 4~5 — 앞바퀴 칸 5는 이음매 아님")
	t.ok(ahead.asleep, "이음매 전 — 조용")
	t.eq(_v(st, "U04_CART_MAP"), 1, "수레 자리 = 영등포시장(변수 한 곳)")
	t.ok(_push(h, c, 1), "둘째 — 앞바퀴가 이음매(6)를 친다")
	t.ok(not ahead.asleep, "덜컹 — 레일 앞쪽 무리가 먼저 깬다")
	t.ok(behind.asleep, "뒤쪽은 가까이(4칸)만 — 그대로 잔다")
	t.ok(not far.asleep, "이음매 6에서 37칸 — 앞 40칸 안 = 맵 끝까지 운다")
	while c.cart_x() + 2 < 12:
		_push(h, c, 1)
	t.ok(_hints(h).contains("덜컹"), "덜컹 알림")
	# 막히면 선다: 앞 칸에 사람이 있으면 수레가 안 나간다
	var x := c.cart_x()
	_put(h, x - 1, 18)
	var blk := h.combat.spawn("CR-095", Vector2((x + 2) * 32 + 16, 18 * 32 + 16), h.map, st, {})
	h.last_move = Vector2(1, 0)
	c._cd = 0.0
	c._process(0.05)
	t.eq(c.cart_x(), x, "앞이 막히면 수레도 나도 선다(미끄러짐 없음)")
	h.combat.drop_enemy(blk)
	# 위아래로 걸으면 밀지 않는다
	h.last_move = Vector2(0, 1)
	c._cd = 0.0
	c._process(0.05)
	t.eq(c.cart_x(), x, "레일 방향이 아닌 걸음은 밀지 않는다")
	# 서쪽으로도 민다
	t.ok(_push(h, c, -1), "반대쪽에서 서쪽으로 민다")


func test_u04_cloth_quiet(t) -> void:
	var r := _host("U4-01", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.eq(_play(st, c, "U04_SOMIN", ["바퀴에 천을"]), [], "소민서 — 천 감기")
	t.eq(_v(st, "U04_CLOTH"), 1, "바퀴 천")
	var near := _doze(h, st, 15, 19)
	var mid := _doze(h, st, 30, 19)
	while c.cart_x() + 2 < 12:
		_push(h, c, 1)
	t.ok(not near.asleep, "천 감아도 가까운(14칸 안) 무리는 깬다")
	t.ok(mid.asleep, "천 감으면 먼 무리는 못 듣는다")
	t.ok(c._push_secs() > 0.4, "대신 느리다")


func test_u04_follow_across_maps(t) -> void:
	var r := _host("U4-01", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	st.vars.set_v("U04_CART_MAP", 1)
	st.vars.set_v("U04_CART_X", 40)
	c._place_cart()
	_put(h, 39, 18)
	c._process(0.05)
	t.ok(c._last_near, "수레 곁")
	h.enter("U4-02", "from_W")
	t.eq(_v(st, "U04_CART_MAP"), 2, "수레를 끌고 터널 A로 넘어간다")
	t.eq(_v(st, "U04_CART_X"), 3, "터널 서쪽 끝")
	t.ok(h.map.is_solid(Vector2i(3, 7)), "터널 레일(7줄)에 수레")
	# 수레 곁이 아니면 따라오지 않는다
	_put(h, 60, 3)
	c._process(0.05)
	h.enter("U4-03", "from_W")
	t.eq(_v(st, "U04_CART_MAP"), 2, "멀리 두고 가면 수레는 그 자리")
	t.eq(_play(st, c, "U04_SOMIN", ["어디"]), [], "어디 있나 묻기")
	t.ok(_hints(h).contains("터널 A"), "소민서가 마지막 자리를 말한다(사실은 변수 한 곳)")


func test_u04_ride_and_brake(t) -> void:
	var r := _host("U4-04", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	st.vars.set_v("U04_CART_MAP", 4)
	st.vars.set_v("U04_CART_X", 8)
	c._place_cart()
	_put(h, 7, 7)
	c._near_flags()
	t.eq(_v(st, "U04_RIDE"), 1, "내리막 위 수레 곁 — 탈 수 있다")
	t.ok("올라탄다(내리막)" in _opts(st, "U04_CART"), "수레 장면에 '올라탄다'")
	c.ride()
	t.ok(c._riding, "탔다")
	for i in 20:
		c._process(0.1)
	t.ok(c.cart_x() > 9, "내리막 — 저절로 구른다")
	t.ok(c._ride_v > 1.0, "점점 빨라진다")
	t.ok(c._pre_interact(), "조사 키 = 브레이크(다른 조사를 가로챈다)")
	var guard := 0
	while c._riding and guard < 200:
		guard += 1
		c._process(0.1)
	t.ok(not c._riding, "브레이크 — 선다")
	t.ok(c.cart_x() < 70, "내리막 끝 전에 섰다")
	t.ok(not h.map.is_solid(h.map.tile_of(h.player.loco.logical)), "내려선 자리는 빈 칸")
	# 브레이크 없이 — 맵 끝을 넘어 여의나루로(타고 넘어감)
	st.vars.set_v("U04_CART_X", 60)
	c._place_cart()
	_put(h, 59, 7)
	c._near_flags()
	c.ride()
	c._ride_v = 9.0
	guard = 0
	while c._riding and guard < 400:
		guard += 1
		c._process(0.1)
	t.eq(_v(st, "U04_CART_MAP"), 5, "타고 여의나루로 넘어간다")
	t.ok(c._ride_carry, "다음 맵에 타고 들어간다")


func test_u04_line_and_tap(t) -> void:
	var r := _host("U4-03", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.ok(h.map.is_solid(Vector2i(40, 18)), "공병 통제선 — 레일 위 모래주머니")
	t.ok(not ("길게 하나, 둘(운반조 지나감)" in _opts(st, "U04_RAIL")), "레일 말을 모르면 아무렇게나만")
	st.vars.set_v("U04_KNOW", 1)
	_put(h, 30, 18)
	t.eq(_play(st, c, "U04_RAIL", ["길게 하나, 둘"]), [], "운반조 신호")
	t.eq(_v(st, "U04_ENG"), 1, "통제선이 걷힌다")
	t.ok(not h.map.is_solid(Vector2i(40, 18)) and not h.map.is_solid(Vector2i(40, 19)), "모래주머니 둘이 비켜 수레 길이 난다")
	t.ok(h.map.is_solid(Vector2i(40, 20)), "옆 선로 쪽은 그대로")
	h.enter("U4-02", "from_E")
	h.enter("U4-03", "from_W")
	t.ok(not h.map.is_solid(Vector2i(40, 18)), "다시 와도 걷힌 채(변수 한 곳)")
	# 계엄 적대: 신호로 안 속는다
	r = _host("U4-03", "from_W")
	h = r[0]
	st = r[1]
	c = r[2]
	st.vars.set_v("AFF_BJ", -80)
	st.vars.set_v("U04_KNOW", 1)
	_put(h, 30, 18)
	c.tap("L2")
	t.eq(_v(st, "U04_ENG"), 0, "적대면 안 걷힌다")
	# 네 번 빠르게 = 깬다
	var e := _doze(h, st, 25, 20)
	c.tap("4")
	t.ok(not e.asleep, "네 번 빠르게 — 가까운 무리가 깬다")


func test_u04_listen(t) -> void:
	var r := _host("U4-02", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	_put(h, 20, 7)
	h.hints.clear()
	t.eq(_play(st, c, "U04_RAIL", ["귀를"]), [], "귀 대기")
	t.eq(_v(st, "U04_HEARD"), 1, "들었다")
	var s := _hints(h)
	t.ok(s.contains("동쪽") and s.contains("잠든 숨"), "동쪽 신길 줄 — 잠든 숨: %s" % s)
	t.ok(c._post_interact(), "레일 줄에서 빈 조사 = 레일 장면")
	_put(h, 40, 1)
	t.ok(not c._post_interact(), "레일에서 멀면 열지 않는다")
	# 레일은 맵 너머 소리를 나른다
	r = _host("U4-01", "from_E")
	h = r[0]
	c = r[2]
	_put(h, 20, 18)
	h.hints.clear()
	c.listen()
	t.ok(_hints(h).contains("신길 쪽"), "영등포에서 신길 쪽 숨소리")


func test_u04_night_carriers(t) -> void:
	var r := _host("U4-02", "from_W", "22:20")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	_put(h, 20, 7)
	c._process(0.1)
	t.ok(not c._carrier.is_empty(), "22시 — 운반조 수레가 터널에 든다")
	t.eq(_v(st, "U04_CARR_DAY"), 10, "하룻밤 한 번")
	st.vars.set_v("U04_KNOW", 1)
	c.tap("2")
	t.eq(_v(st, "U04_YIELD"), 1, "두 번 — 알아듣는다")
	t.eq(int(c._carrier["row"]), U04.ALT["U4-02"], "옆 선로로 비켜 간다")
	h.enter("U4-01", "from_E")
	t.ok(c._carrier.is_empty(), "맵을 떠나면 그 밤 수레는 끝")
	h.enter("U4-02", "from_W")
	c._process(0.1)
	t.ok(c._carrier.is_empty(), "같은 밤 다시 오지 않는다")
	# 레일 위에 서 있으면 앞에서 서서 레일 말을 가르친다
	r = _host("U4-04", "from_W", "22:40")
	h = r[0]
	st = r[1]
	c = r[2]
	_put(h, 20, 7)
	c._process(0.1)
	t.ok(not c._carrier.is_empty(), "터널 B에도")
	c._carrier["actors"][0].loco.place(Vector2(23 * 32 + 16, 7 * 32 + 16))
	c._process(0.1)
	t.ok(bool(c._carrier["stopped"]), "레일 위 사람 — 수레가 선다")
	t.eq(_play(st, c, "U04_CARRIERS"), [], "운반조가 레일 말을 가르친다")
	t.eq(_v(st, "U04_KNOW"), 1, "레일 말을 안다")
	t.ok(bool(c._carrier["passed"]), "옆 선로로 지나간다")


func test_u04_job_round_trip(t) -> void:
	var r := _host("U4-01", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.eq(_play(st, c, "U04_SOMIN", ["짐을 받는다", "진공관"]), [], "진공관 짐")
	t.eq(_v(st, "U04_JOB"), 6, "맡은 짐")
	t.eq(int(st.items.get("M-406", 0)), 1, "진공관 상자")
	t.eq(_play(st, c, "U04_CART", ["싣는다"]), [], "수레에 싣기")
	t.eq(_v(st, "U04_CART_LOAD"), 6, "수레 위 진공관")
	t.eq(int(st.items.get("M-406", 0)), 0, "손은 비었다")
	st.vars.set_v("U04_JOB_DMG", 5)                                     # 덜컹 다섯 — 몇 알 갔다
	t.eq(_play(st, c, "U04_CART", ["내려"]), [], "차막이에서 내려 든다")
	t.eq(int(st.items.get("M-406", 0)), 1, "다시 손에")
	c._carry_tick()
	t.ok(h.carry_mul < 1.0, "짐을 들면 걸음이 무겁다")
	h.enter("U4-05", "from_W")
	var caps := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "U04_KIGUN"), [], "기건희에게 건넨다")
	t.eq(_v(st, "PC_CAPS") - caps, 27, "깨진 만큼 깎인 운임(45 − 6×3)")
	t.eq(_v(st, "U04_RUN"), 1, "운송 한 번")
	t.eq(_v(st, "U04_JOB"), 9, "돌아오는 짐")
	t.eq(int(st.items.get("M-409", 0)), 1, "펌프 부품 꾸러미")
	h.enter("U4-01", "from_E")
	caps = _v(st, "PC_CAPS")
	t.eq(_play(st, c, "U04_SOMIN"), [], "반장에게 돌아옴")
	t.eq(_v(st, "PC_CAPS") - caps, 20, "돌아오는 운임")
	t.eq(_v(st, "U04_JOB"), 0, "다시 짐을 받을 수 있다")
	# 셋째에 쉼터 · 중계 사물함
	st.vars.set_v("U04_RUN", 2)
	t.eq(_play(st, c, "U04_SOMIN", ["짐을 받는다", "닭"]), [], "닭 짐")
	h.enter("U4-05", "from_W")
	h.hints.clear()
	t.eq(_play(st, c, "U04_KIGUN"), [], "셋째 운송")
	t.ok(_hints(h).contains("쉼터"), "셋째에 쉼터")
	t.ok(_v(st, "U04_RUN") >= 3, "중계 사물함 열림 조건")


func test_u04_receiver_dead(t) -> void:
	var r := _host("U4-01", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.eq(_play(st, c, "U04_SOMIN", ["짐을 받는다", "전지"]), [], "전지 짐")
	t.eq(_play(st, c, "U04_CART", ["싣는다"]), [], "수레에 싣기")
	st.kill("N-UG-012")
	t.eq(_play(st, c, "U04_SOMIN"), [], "받을 사람이 죽었다")
	t.eq(_v(st, "U04_JOB"), 0, "짐이 취소된다(반쯤 된 상태 없음)")
	t.eq(_v(st, "U04_CART_LOAD"), 0, "수레 짐도 내린다")
	t.eq(int(st.items.get("M-408", 0)), 0, "전지를 가져가지 못한다")
	t.ok(not ("짐을 받는다" in _opts(st, "U04_SOMIN")), "새 짐도 없다")
	t.ok("짐 받을 사람은?" in _opts(st, "U04_SOMIN"), "왜 없는지 묻는 판")


func test_u04_list(t) -> void:
	var r := _host("U4-05", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.eq(c._stayers.size(), 10, "대기 줄 열")
	t.ok(c._stayers.all(func(e): return e.asleep), "모두 잔다")
	t.eq(_play(st, c, "U04_LIST", ["[은신"]), [], "명단 뽑기")
	t.eq(_v(st, "U04_LIST"), 1, "뽑았다")
	t.ok(c._stayers.all(func(e): return e.asleep), "은신 — 깨지 않는다")
	t.eq(_play(st, c, "U04_LIST"), [], "두 번째")
	t.eq(int(st.items.get("M-410", 0)), 1, "한 장뿐")
	var k := int(st.vars.get_v("V_KARMA"))
	t.eq(_play(st, c, "U04_SOONBOK", ["명단을"]), [], "순복에게")
	t.eq(_v(st, "U04_LIST"), 2, "순복이 받았다")
	t.ok(int(st.vars.get_v("V_KARMA")) > k, "카르마")
	c._on_day(10)
	t.eq(_v(st, "U04_LIST"), 2, "같은 날은 아직")
	c._on_day(11)
	t.eq(_v(st, "U04_LIST"), 3, "다음 날 남산이 읽는다")
	h.enter("U4-05", "from_W")
	t.eq(c._stayers.size(), 0, "대기 줄이 흩어졌다")
	h.enter("U4-04", "from_E")
	var w := h.combat.enemies.filter(func(e): return is_instance_valid(e) and e.has_meta("u04_w"))
	t.eq(w.size(), 2, "흩어진 둘이 터널에 남았다(명단의 값)")
	# 시끄럽게 뽑으면 줄이 깬다
	r = _host("U4-05", "from_W")
	h = r[0]
	st = r[1]
	c = r[2]
	c.list_take()
	c.wake_group()
	t.ok(c._stayers.all(func(e): return not e.asleep), "출력기 쇳소리 — 줄이 함께 일어난다")


func test_u04_ghoul_seat(t) -> void:
	var r := _host("U4-02", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.eq(c._stayers.size(), 6, "신길 여섯")
	st.vars.set_v("U04_CART_MAP", 2)
	st.vars.set_v("U04_CART_X", 50)
	c._place_cart()
	_put(h, 49, 7)
	c._near_flags()
	t.eq(_v(st, "U04_CART_NEAR"), 1, "수레가 승강장 앞")
	t.eq(_play(st, c, "U04_SINGIL", ["[은신"]), [], "하나를 수레에 눕힌다")
	t.eq(_v(st, "U04_CART_LOAD"), 10, "수레 위 대피민")
	t.eq(c._stayers.size(), 5, "줄에서 하나 빠졌다")
	t.ok(_v(st, "U04_SK") != 0, "빠진 자리(비트)")
	t.eq(_play(st, c, "U04_CART", ["업는다"]), [], "내려 업는다")
	t.eq(_v(st, "U04_GHOUL"), 2, "업었다")
	c._carry_tick()
	t.ok(h.carry_mul <= 0.7, "업으면 느리다")
	h.enter("U4-05", "from_W")
	var k := int(st.vars.get_v("V_KARMA"))
	t.eq(_play(st, c, "U04_SEAT"), [], "빈자리에 앉힌다")
	t.eq(_v(st, "U04_GHOUL"), 3, "0398번 — 대기 줄에")
	t.ok(int(st.vars.get_v("V_KARMA")) > k, "카르마")
	var seated := h.combat.enemies.filter(func(e): return is_instance_valid(e) and e.has_meta("u04_seat"))
	t.eq(seated.size(), 1, "자리에 앉아 잔다")
	h.enter("U4-04", "from_E")
	h.enter("U4-05", "from_W")
	seated = h.combat.enemies.filter(func(e): return is_instance_valid(e) and e.has_meta("u04_seat"))
	t.eq(seated.size(), 1, "다시 와도 그 자리")
	t.ok(seated[0].cmb.team != "enemy", "덤비지 않는다")
	# 덜컹에 깨면 수레 위에서 일어난다
	r = _host("U4-02", "from_W")
	h = r[0]
	st = r[1]
	c = r[2]
	st.vars.set_v("U04_CART_MAP", 2)
	st.vars.set_v("U04_CART_X", 50)
	st.vars.set_v("U04_CART_LOAD", 10)
	st.vars.set_v("U04_GHOUL", 1)
	c._place_cart()
	c._ghoul_wakes()
	t.eq(_v(st, "U04_CART_LOAD"), 0, "수레가 빈다")
	t.eq(_v(st, "U04_GHOUL"), 0, "모시기 실패")


func test_u04_clear(t) -> void:
	var r := _host("U4-02", "from_W")
	var st: StoryState = r[1]
	var c: U04 = r[2]
	for e in c._stayers.duplicate():
		c._on_down(e)
	t.eq(_v(st, "U04_SK"), 63, "신길 여섯이 다 없다")
	t.eq(_v(st, "U04_CLEAR"), 0, "여의나루 줄이 남았다")
	st.vars.set_v("U04_LIST", 3)
	c._check_clear()
	t.eq(_v(st, "U04_CLEAR"), 1, "명단으로 흩어져도 정리")
	t.eq(_play(st, c, "U04_SINGIL"), [], "빈 승강장")


func test_u04_hatch_and_backdoor(t) -> void:
	var r := _host("U4-03", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.eq(_play(st, c, "U04_WOO", ["같이 열자"]), [], "우다현")
	t.eq(_v(st, "U04_WOO"), 1, "만남")
	t.eq(_play(st, c, "U04_BOARD", ["[수리"]), [], "배전반")
	t.eq(_v(st, "U04_WOO"), 2, "회로표를 맞췄다")
	t.ok("우다현의 열쇠로 연다" in _opts(st, "U04_HATCH"), "우다현의 열쇠")
	t.eq(_play(st, c, "U04_HATCH", ["우다현의 열쇠"]), [], "점검구")
	t.eq(_v(st, "U04_HATCH"), 1, "열렸다")
	h.enter("Y-03", "from_U4")
	t.eq(h.map.id, "Y-03", "벙커 쪽 배선 통로")
	t.ok(h.map.text_meta.has(Vector2i(17, 3)), "올라가는 사다리")
	# 지하시장 후문: 지하시장과 사이가 나쁘면 용접
	r = _host("U4-01", "from_E")
	h = r[0]
	t.ok(not h.map.is_solid(Vector2i(36, 2)), "후문 셔터가 올라가 있다")
	r = _host("U4-01", "from_E")
	h = r[0]
	st = r[1]
	st.vars.set_v("AFF_JH", -80)
	h.enter("U4-02", "from_W")
	h.enter("U4-01", "from_E")
	t.ok(h.map.is_solid(Vector2i(36, 2)), "적대 — 용접")


func test_u04_late_and_recover(t) -> void:
	# 수레에 실은 채 사흘 — 운반조가 수레째 거둬 간다(§16.7 #3)
	var r := _host("U4-01", "from_E")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.eq(_play(st, c, "U04_SOMIN", ["짐을 받는다", "닭"]), [], "닭 짐")
	t.eq(_play(st, c, "U04_CART", ["싣는다"]), [], "싣기")
	while c.cart_x() < 10:
		_push(h, c, 1)
	h.enter("U4-02", "from_W")
	c._on_day(12)
	t.eq(_v(st, "U04_CART_LOAD"), 7, "이틀은 그대로")
	c._on_day(13)
	t.eq(_v(st, "U04_CART_LOAD"), 0, "사흘 — 짐을 거둬 갔다")
	t.eq(_v(st, "U04_JOB"), 0, "운송 끝(운임 없음)")
	t.eq(_v(st, "U04_CART_X"), 3, "수레는 차고로")
	h.enter("U4-01", "from_E")
	t.eq(_play(st, c, "U04_SOMIN", ["다음에"]), [], "반장이 말해 준다")
	t.eq(_v(st, "U04_BACK"), 0, "한 번만")
	# 손에 든 짐을 사흘 넘겨 가져가면 반값
	t.eq(_play(st, c, "U04_SOMIN", ["짐을 받는다", "전지"]), [], "전지 짐")
	st.vars.set_v("GAME_DAY", 14)
	h.enter("U4-05", "from_W")
	var caps := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "U04_KIGUN"), [], "늦은 짐")
	t.eq(_v(st, "PC_CAPS") - caps, 30, "운임 절반(60 → 30)")
	# 질주 충돌 — 앞을 막은 적이 다친다
	r = _host("U4-04", "from_W")
	h = r[0]
	st = r[1]
	c = r[2]
	st.vars.set_v("U04_CART_MAP", 4)
	st.vars.set_v("U04_CART_X", 20)
	c._place_cart()
	var e := h.combat.spawn("CR-095", Vector2(22 * 32 + 16, 7 * 32 + 16), h.map, st, {})
	var hp0: float = e.cmb.hp
	c._riding = true
	c._ride_v = 5.0
	c._crash()
	t.ok(e.cmb.hp < hp0, "들이받은 쥐가 다친다")
	t.ok(not c._riding, "수레는 선다")


func test_u04_fun_fixes(t) -> void:
	# ① 우다현이 서두르면 — '같이 열자'가 닫히고, 다음에 들면 점검구 앞 지뢰
	var r := _host("U4-03", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	t.eq(_play(st, c, "U04_WOO", ["선로 통제선", "다음에"]), [], "우다현을 만남")
	t.eq(_v(st, "U04_WOO"), 1, "만났다")
	st.vars.set_v("U04_KNOW", 1)
	_put(h, 30, 18)
	c.tap("4")
	t.eq(_v(st, "U04_RUSH"), 1, "네 번 — 우다현이 서두른다")
	t.ok(not ("같이 열자. 회로표 맞춰 줄게" in _opts(st, "U04_WOO")), "서두른 뒤엔 같이 열 수 없다")
	h.enter("U4-02", "from_E")
	h.enter("U4-03", "from_W")
	var ms: Array = h.combat.ord.mines.filter(func(m): return int(m.get("x", -1)) >= 0 or true)
	t.ok(ms.size() >= 2, "점검구 앞 지뢰 둘(%d)" % ms.size())
	# ② 모래주머니 들이받기 셋 = 터짐(계엄 적대여도)
	r = _host("U4-03", "from_W")
	h = r[0]
	st = r[1]
	c = r[2]
	st.vars.set_v("AFF_BJ", -80)
	st.vars.set_v("U04_CART_MAP", 3)
	for i in 3:
		st.vars.set_v("U04_CART_X", 38)
		c._place_cart()
		c._riding = true
		c._ride_dir = 1
		c._ride_v = 5.0
		c._crash()
	t.eq(_v(st, "U04_RAM"), 3, "세 번 받았다")
	t.ok(not h.map.is_solid(Vector2i(40, 18)), "모래주머니가 터져 수레 길이 났다")
	t.eq(int(st.vars.get_v("AFF_BJ")), -86, "받을 때마다 BJ −2")
	h.enter("U4-02", "from_E")
	h.enter("U4-03", "from_W")
	t.ok(not h.map.is_solid(Vector2i(40, 18)), "다시 와도 터진 채")
	# ③ 역은 덜 멎는다 — 브레이크 없이 여의나루에 들면 차막이 '쿵'
	r = _host("U4-05", "from_W")
	h = r[0]
	st = r[1]
	c = r[2]
	st.vars.set_v("U04_CART_MAP", 5)
	st.vars.set_v("U04_CART_X", 3)
	st.vars.set_v("U04_CART_LOAD", 8)
	c._place_cart()
	c._riding = true
	c._ride_dir = 1
	c._ride_v = 5.0
	h.hints.clear()
	var g := 0
	while c._riding and g < 300:
		g += 1
		c._process(0.1)
	t.ok(_hints(h).contains("차막이"), "차막이에 받혔다")
	t.ok(_hints(h).contains("전지"), "전지가 넘을 뻔했다")
	# ④ 바퀴 천은 닳는다 · 헌 천으로 다시 감는다
	r = _host("U4-01", "from_E")
	h = r[0]
	st = r[1]
	c = r[2]
	st.vars.set_v("U04_CLOTH", 1)
	for i in 20:
		c._clack(6, 1)
	t.eq(_v(st, "U04_CLOTH"), 0, "이음매 스물 — 천이 풀렸다")
	st.call_fn("give", ["M-411", 1])
	t.eq(_play(st, c, "U04_CART", ["바퀴에 천을"]), [], "헌 천을 감는다")
	t.eq(_v(st, "U04_CLOTH"), 1, "다시 조용")
	t.eq(int(st.items.get("M-411", 0)), 0, "천 하나를 썼다")
	# ⑤ 손짐도 소리가 난다 — 진공관을 들고 뛰면 깨진다
	t.eq(_play(st, c, "U04_SOMIN", ["짐을 받는다", "진공관"]), [], "진공관")
	h.player.mode = "run"
	for i in 20:
		c._hand_step()
	t.eq(_v(st, "U04_JOB_DMG"), 2, "스무 칸 뛰면 두 알")
	h.player.mode = "walk"
	for i in 20:
		c._hand_step()
	t.eq(_v(st, "U04_JOB_DMG"), 2, "걸으면 멀쩡")
	var e := _doze(h, st, 20, 18)
	c._cluck(15)
	t.ok(not e.asleep, "닭은 바퀴와 상관없이 운다")
	# ⑥ 업은 채 지하 밖으로 — 바깥 바람에 깨어 돌아간다
	st.vars.set_v("U04_GHOUL", 2)
	h.enter("J-09", "from_U401")
	t.eq(_v(st, "U04_GHOUL"), 0, "업은 사람이 어둠으로 돌아갔다")
	# ⑦ 넘긴 뒤 여의나루에 둔 빈 수레는 밤 편에 차고로
	r = _host("U4-01", "from_E")
	h = r[0]
	st = r[1]
	c = r[2]
	st.vars.set_v("U04_RUN", 1)
	st.vars.set_v("U04_CART_MAP", 5)
	st.vars.set_v("U04_CART_X", 34)
	c._on_day(11)
	t.eq(_v(st, "U04_CART_MAP"), 1, "수레가 차고로 돌아왔다")
	t.ok(h.map.is_solid(Vector2i(3, 18)), "차고에 보인다")
	t.eq(_play(st, c, "U04_SOMIN", ["다음에"]), [], "반장이 말해 준다")
	t.eq(_v(st, "U04_BACK"), 0, "소식은 한 번")
	# ⑧ 펌프 부품을 잃어버려도 막히지 않는다
	st.vars.set_v("U04_JOB", 9)
	t.ok("펌프 부품은 잃어버렸어" in _opts(st, "U04_SOMIN"), "잃어버린 판")
	t.eq(_play(st, c, "U04_SOMIN", ["잃어버렸어", "다음에"]), [], "잃어버렸다")
	t.eq(_v(st, "U04_JOB"), 0, "다시 짐을 받을 수 있다")
	# ⑨ 0398번부터 눕힌다
	r = _host("U4-02", "from_W")
	h = r[0]
	st = r[1]
	c = r[2]
	st.vars.set_v("U04_CART_MAP", 2)
	st.vars.set_v("U04_CART_X", 48)
	c._place_cart()
	c.ghoul_lift()
	t.eq(_v(st, "U04_GNO"), 5, "0398번(빈자리의 주인)")


func test_u04_carrier_talk(t) -> void:
	var r := _host("U4-02", "from_W", "22:20")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	_put(h, 20, 7)
	c._process(0.1)
	t.eq(int(c._carrier["dir"]), -1, "짝숫날 — 동에서 서로")
	t.eq(c._carrier["actors"].size(), 2, "둘")
	st.vars.set_v("U04_KNOW", 1)
	c.tap("3")
	t.ok(bool(c._carrier["stopped"]), "세 번 — 선다")
	st.call_fn("give", ["M-409", 1])
	st.vars.set_v("U04_JOB", 9)
	var caps := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "U04_CARRIERS", ["펌프 부품", "지나가"]), [], "섰다. 왜? — 맡기고 지나가")
	t.eq(_v(st, "PC_CAPS") - caps, 10, "운임 반")
	t.eq(_v(st, "U04_JOB"), 0, "귀환 걸음을 덜었다")
	t.ok(bool(c._carrier["passed"]), "옆 선로로 지나간다(멈춰 서 있지 않는다)")
	# 홀숫날 — 서에서 동으로 셋
	st.vars.set_v("GAME_DAY", 11)
	h.enter("U4-04", "from_W")
	c._process(0.1)
	t.eq(int(c._carrier["dir"]), 1, "홀숫날 — 서에서 동으로")
	t.eq(c._carrier["actors"].size(), 3, "셋")
	# '두 번' — 지나가며 한 줄 · JH 한 번
	var jh := int(st.vars.get_v("AFF_JH"))
	c.tap("2")
	c.tap("2")
	t.eq(int(st.vars.get_v("AFF_JH")) - jh, 1, "말 아는 사람 — JH +1 한 번")


func test_u04_rereview(t) -> void:
	# 빈자리는 하나 — 0398을 앉힌 뒤엔 더 눕히지 않는다(덮어쓰기 버그)
	var r := _host("U4-02", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U04 = r[2]
	st.vars.set_v("U04_GHOUL", 3)
	st.vars.set_v("U04_CART_MAP", 2)
	st.vars.set_v("U04_CART_X", 50)
	c._place_cart()
	c._near_flags()
	t.ok(not ("[은신 50] 하나를 수레에 눕힌다" in _opts(st, "U04_SINGIL")), "모신 뒤엔 눕히기 없음")
	c.ghoul_lift()
	t.eq(_v(st, "U04_GHOUL"), 3, "0398 자리 그대로")
	t.eq(_v(st, "U04_CART_LOAD"), 0, "수레도 빈 채")
	# 빈 조사 = 바로 귀 대기, 2초 안에 한 번 더 = 두드림 메뉴
	_put(h, 20, 7)
	h.hints.clear()
	t.ok(c._post_interact(), "레일 곁 빈 조사")
	t.ok(_hints(h).contains("레일에 귀를 댄다"), "메뉴 없이 바로 귀 대기")
	t.eq(_v(st, "U04_HEARD"), 1, "들었다")
	# 신길을 깨웠으면 반장이 안다
	st.vars.set_v("U04_GHOUL", 0)
	var e := _doze(h, st, 40, 7)
	c._clack(30, 1)
	t.eq(_v(st, "U04_LOUD"), 1, "신길 덜컹 — 기억")
	# 정면충돌 · 브레이크
	r = _host("U4-04", "from_W", "22:20")
	h = r[0]
	st = r[1]
	c = r[2]
	_put(h, 20, 3)
	c._process(0.1)
	t.ok(not c._carrier.is_empty(), "짝숫날 밤 — 동에서 오는 운반조")
	st.vars.set_v("U04_CART_MAP", 4)
	st.vars.set_v("U04_CART_X", 30)
	c._place_cart()
	c._carrier["actors"][0].loco.place(Vector2(36 * 32 + 16, 7 * 32 + 16))
	c._riding = true
	c._ride_dir = 1
	c._ride_v = 6.0
	var jh := int(st.vars.get_v("AFF_JH"))
	c._carrier_tick(0.01)
	t.ok(not c._riding, "맞부딪쳐 내린다")
	t.eq(_v(st, "U04_TAP"), 9, "충돌 판")
	t.eq(int(st.vars.get_v("AFF_JH")) - jh, -3, "운반조가 화났다")
	t.eq(_play(st, c, "U04_CARRIERS"), [], "충돌 장면 — 장사 없이 지나감")
	t.ok(bool(c._carrier["passed"]), "옆 선로로")
	# 얹혀 가기(짝숫날 영등포행) — 펌프 부품은 그 자리에서 반장에게
	r = _host("U4-04", "from_W", "22:20")
	h = r[0]
	st = r[1]
	c = r[2]
	_put(h, 20, 3)
	c._process(0.1)
	st.call_fn("give", ["M-409", 1])
	st.vars.set_v("U04_JOB", 9)
	st.vars.set_v("U04_TAP", 1)
	t.ok("영등포까지 얹혀 간다" in _opts(st, "U04_CARRIERS"), "얹혀 가기 판")
	var caps := _v(st, "PC_CAPS")
	c.hitch()
	t.eq(_v(st, "PC_CAPS") - caps, 20, "차고 앞에서 반장에게 — 20캡")
	t.eq(_v(st, "U04_JOB"), 0, "귀환 끝")
	t.ok(c._carrier.is_empty(), "수레는 떠났다")
