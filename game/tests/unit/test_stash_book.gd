## 단계 1-12o 핍-보이 수첩 '숨겨 둔 자리'(D-225, 계획 `_plans/1-12o_stash_book_plan.md`):
## 삼은 때 · 닫은 때의 기억(그때 든 것 · 방울 · 위험) · 털림은 열어 흔적을 본 뒤에야 · 방울이 막은 날도 열기 전엔 '방울' ·
## 지난 일 줄(모르는 털림 · 놓침은 적지 않음) · 맡긴 자리 · 소굴은 삼기 불가 · 목록 행 · 지도 점 · 가까운 순.
extends RefCounted


func _host(map_id := "G-880-1244") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  10:00"
	var s := Stash.new()
	s.setup(h)
	h.enter(map_id, "from_W")
	return [h, s, st]


func _first_box(h: InteriorHost) -> Dictionary:
	for c in h.map.boxes:
		var b: Dictionary = h.map.boxes[c]
		if str(b.get("kind", "")) in Stash.CLAIM_KINDS and str(b.get("owner", "")) == "":
			return b
	return {}


func _open(h: InteriorHost, s: Stash, b: Dictionary, c: Dictionary) -> ContainerScreen:
	var scr := ContainerScreen.new().setup(h.st, b, c, h.items_db, "", 150.0)
	s.on_open(b, c, scr)
	return scr


func _claim(h: InteriorHost, s: Stash, b: Dictionary) -> Dictionary:
	var c := h.box_contents(b)
	c["items"] = {}
	var scr := _open(h, s, b, c)
	scr.stash_act.emit("claim")
	scr.free()
	return c


func test_stash_book_memory(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var b := _first_box(h)
	var c := _claim(h, s, b)
	var k := Loot.key(h.map.id, b, 2277)
	var sp: Dictionary = s.spots()[k]
	t.ok(str(sp.get("room", "")) != "" and sp.has("seen"), "삼은 실내 이름 · 기억")
	t.ok(StashBook.memo(sp, h.items_db).ends_with("비어 있었다"), "삼고 아무것도 안 넣음 — '비어 있었다'")
	t.ok(str(sp["log"][0]["text"]) == "삼음", "지난 일 — 삼음")
	c["items"] = {"W-013": 1, "M-001": 120, "I-030": 2}
	s.on_close(b, c)
	var mem := StashBook.memory_lines(sp["seen"]["items"], h.items_db)
	t.ok(mem.size() == 3 and str(mem[2]) == "캡 120", "그때 든 것 — 값 순 · 캡은 끝")
	t.ok(StashBook.memo(sp, h.items_db).contains(str(h.items_db["W-013"]["name"])), "행 = 내 메모(가장 값진 것)")
	var rows := StashBook.rows(st, h.date_text, Vector2i(880, 1244), h.items_db)
	t.ok(rows.size() == 1 and str(rows[0]["right"]) == "11.01", "목록 — 마지막으로 본 날")
	# 털림 — 열어 보기 전엔 모른다(P2)
	sp["th"] = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	s._theft(k, sp, c, 12, rng)
	t.eq(StashBook.status(st, sp, h.date_text), "11.01", "털렸지만 아직 모른다 — 목록은 그대로")
	t.ok(StashBook.memory_lines(sp["seen"]["items"], h.items_db).size() == 3, "그때 든 것도 그대로(지금 내용이 아니다)")
	t.ok(not (sp["log"] as Array).any(func(e): return str(e["text"]).begins_with("털림")), "지난 일에도 없다")
	t.ok(StashBook.worry(st, sp) != "", "마음에 걸림은 털림과 상관없이 같은 식")
	var scr := _open(h, s, b, c)
	scr.free()
	t.eq(StashBook.status(st, sp, h.date_text), "털림", "열어서 흔적을 보니 '털림'")
	t.ok((sp["log"] as Array).any(func(e): return str(e["text"]).begins_with("털림 — ")), "지난 일 — 흔적 첫 마디")
	t.ok(StashBook.points(st).any(func(p): return bool(p["robbed"])), "지도 상자에 사선")
	t.ok((sp["known"]["lost"] as Dictionary).has("W-013"), "잃은 것 — 마지막으로 본 것 − 열어서 본 것")
	s.on_close(b, c)
	t.ok(StashBook.memory_lines(sp["seen"]["items"], h.items_db).size() < 3, "다시 닫으면 남은 것으로 새 기억")
	t.eq(StashBook.status(st, sp, h.date_text), "털림", "그냥 닫으면 털림은 그대로(되찾으러 갈 이유)")
	var bn := s.bundle(int(s.data()["qb"]))
	s._give_back(bn, [])
	s._done(bn, 1)
	t.eq(StashBook.status(st, sp, h.date_text), "되찾음", "되찾음")
	t.ok((sp["log"] as Array).any(func(e): return str(e["text"]) == "아이에게서 되찾음"), "지난 일 — 어떻게 되찾았나")
	h.free()


func test_stash_book_bell(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var b := _first_box(h)
	var c := _claim(h, s, b)
	var k := Loot.key(h.map.id, b, 2277)
	var sp: Dictionary = s.spots()[k]
	c["items"] = {"W-013": 1}
	c["bell"] = true
	s.on_close(b, c)
	t.eq(StashBook.status(st, sp, h.date_text), "방울", "방울을 맨 자리")
	c["bell"] = false                                                    # 방울이 털이를 막은 날(하루 판정이 방울 줄을 끊는다)
	c["trace"] = "방울 줄이 끊겨 바닥에 늘어져 있다. 누가 손을 대다 방울 소리에 달아났다 — 물건은 그대로다."
	c["trace_seen"] = false
	t.eq(StashBook.status(st, sp, h.date_text), "방울", "열기 전 수첩은 여전히 '방울'(새지 않는다)")
	var scr := _open(h, s, b, c)
	scr.free()
	t.ok(StashBook.status(st, sp, h.date_text) != "털림", "방울이 막은 것은 털림이 아니다")
	t.ok((sp["log"] as Array).any(func(e): return str(e["text"]).begins_with("방울이 막음")), "지난 일 — 방울이 막음")
	h.free()


func test_stash_book_unknown_loss(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var b := _first_box(h)
	var c := _claim(h, s, b)
	var k := Loot.key(h.map.id, b, 2277)
	var sp: Dictionary = s.spots()[k]
	c["items"] = {"W-013": 1, "M-001": 50}
	s.on_close(b, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	s._theft(k, sp, c, 12, rng)
	var bn := s.bundle(int(s.data()["qb"]))
	s._done(bn, 9)
	t.ok(not (sp["log"] as Array).any(func(e): return str(e["text"]) == "끝내 못 찾았다"), "모르는 털림의 놓침은 수첩에 적지 않는다(P2)")
	h.free()


func test_stash_book_safe_and_den(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	h.enter("B-01", "from_X-BC")
	st.vars.set_v("HOME_BC", 1)
	var hb := {}
	for cc in h.map.boxes:
		if str(h.map.boxes[cc].get("owner", "")) == "PC":
			hb = h.map.boxes[cc]
	t.ok(not hb.is_empty(), "옥탑방 철제 사물함")
	var c := h.box_contents(hb)
	c["items"] = {"W-013": 1}
	s.on_close(hb, c)
	var rows := StashBook.rows(st, h.date_text, Vector2i(-1, -1), h.items_db)
	t.ok(rows.any(func(x): return bool(x["safe"]) and str(x["right"]) == "안전"), "맡긴 자리 — 안전")
	t.ok(StashBook.at_of(st, str(rows[0]["id"])) == Vector2i(889, 1348), "맡긴 자리 지도 칸")
	st.vars.set_v("MR_LOCKER", 2)
	t.eq(StashBook.safe_status(st, {"map": "X-MR"}, h.date_text), "기한 지남", "공구 사물함 기한 지남")
	st.vars.set_v("MR_LOCKER", 1)
	st.vars.set_v("MR_LOCKER_DAY", 15)
	t.eq(StashBook.safe_status(st, {"map": "X-MR"}, h.date_text), "~11.06", "공구 사물함 기한")
	var den: Array = s._hide.get("den", [])
	if not den.is_empty():
		t.eq(s.can_claim(str(den[0][0]), {"kind": "cabinet", "owner": ""}, {"items": {}}), "털이꾼 굴이다 — 여기 숨겼다간 제 발로 갖다 바치는 꼴이다", "털이꾼 소굴엔 숨길 수 없다")
	h.free()


func test_stash_book_near(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[2]
	var s: Stash = r[1]
	s.data()["spots"] = {"a": {"name": "장롱", "wx": 900, "wy": 1300, "since": 5, "seen": {"day": 5, "items": {}}},
		"b": {"name": "서류함", "wx": 700, "wy": 1100, "since": 3, "seen": {"day": 3, "items": {}}}}
	var near := StashBook.rows(st, h.date_text, Vector2i(705, 1105), h.items_db)
	t.eq(str(near[0]["id"]), "stash:b", "가까운 순")
	t.ok(StashBook.long_where(st, s.data()["spots"]["a"]).contains("구역"), "어디 — 구역 칸(아는 곳이 없으면)")
	h.free()


func test_stash_book_refill(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var b := _first_box(h)
	var c := _claim(h, s, b)
	var k := Loot.key(h.map.id, b, 2277)
	var sp: Dictionary = s.spots()[k]
	c["items"] = {"W-013": 1, "I-030": 2, "M-001": 80}
	s.on_close(b, c)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	s._theft(k, sp, c, 12, rng)
	var scr := _open(h, s, b, c)
	scr.free()
	t.eq(StashBook.status(st, sp, h.date_text), "털림", "털림")
	c["items"]["I-001"] = 3
	s.on_close(b, c)
	t.ok(StashBook.status(st, sp, h.date_text) != "털림" and sp.has("past"), "다시 채워 닫으면 털림은 지난 일로")
	t.ok(not StashBook.points(st).any(func(p): return bool(p["robbed"])), "지도 사선도 풀린다")
	var cc := h.box_contents(b)
	var why := ""
	var b2 := {}
	for c2 in h.map.boxes:
		var bb: Dictionary = h.map.boxes[c2]
		if bb != b and str(bb.get("kind", "")) in Stash.CLAIM_KINDS and str(bb.get("owner", "")) == "":
			b2 = bb
	if not b2.is_empty():
		var c3 := h.box_contents(b2)
		c3["items"] = {"M-010": 1}
		var scr2 := _open(h, s, b2, c3)
		why = scr2.stash_line
		scr2.free()
		t.eq(why, "먼저 비워야 한다", "막힌 까닭을 용기 창에 한 줄")
	h.free()
