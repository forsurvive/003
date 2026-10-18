## 보관 자리 · 털림 · UQ-125 털린 은닉처(단계 1-L, 계획 `_plans/1-L_loot_stash_plan.md` §3 · §5 · §6 · §9 · SD-05 §3.20):
## 비운 용기만 삼는다 · 남의 것 · 손 맵은 안 된다 · 첫 삼기 뒤 3일 · 퀘스트 물건은 남긴다 · 같은 씨앗 같은 행방 · 털린 흔적 → 단계 10 ·
## 범인 자리 → 30 · 아이(나눠 주기 = 방울 줄 둘 · 먹을 것은 아이 몫) · 장물아비(반값 진열 · 되사면 끝) · 생포 중엔 쉰다 · 놓침 30일.
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


func _first_box(h: InteriorHost, kinds: Array) -> Dictionary:
	for c in h.map.boxes:
		var b: Dictionary = h.map.boxes[c]
		if str(b.get("kind", "")) in kinds and str(b.get("owner", "")) == "":
			return b
	return {}


func _claim(h: InteriorHost, s: Stash, b: Dictionary) -> Dictionary:
	var c := h.box_contents(b)
	c["items"] = {}
	var scr := ContainerScreen.new().setup(h.st, b, c, h.items_db, "", 150.0)
	s.on_open(b, c, scr)
	scr.stash_act.emit("claim")
	scr.free()
	return c


func test_stash_claim(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var b := _first_box(h, Stash.CLAIM_KINDS)
	t.ok(not b.is_empty(), "살림집에 삼을 만한 용기가 있다")
	var c := h.box_contents(b)
	c["items"] = {"M-010": 1}
	t.eq(s.can_claim(h.map.id, b, c), "먼저 비워야 한다", "물건이 든 용기는 먼저 비워야 삼는다")
	c = _claim(h, s, b)
	t.ok(s.is_mine(c) and s.spots().size() == 1, "비운 용기를 내 자리로 삼았다")
	t.ok(s.risk_text(h.map.id, b, c).contains("."), "위험을 세계 말로 한 줄")
	t.ok(s.can_claim("J-02", b, {"items": {}}) != "", "손 맵 용기는 삼을 수 없다")
	t.ok(s.can_claim(h.map.id, {"kind": "swap", "owner": ""}, {"items": {}}) != "", "바꿈 상자는 삼을 수 없다")
	t.ok(s.can_claim(h.map.id, {"kind": "apartment", "owner": "N-VG-D1"}, {"items": {}}) != "", "남의 자리(장사꾼 것)는 삼을 수 없다")
	c["items"] = {"W-013": 1, "M-001": 120, "I-030": 2}
	st.vars.set_v("GAME_DAY", 11)
	for i in 30:
		s._on_day(0)
	t.eq(int((c["items"] as Dictionary).get("M-001", 0)), 120, "삼은 날부터 3일은 털리지 않고 · 그날 그 맵에 있으면 넘어간다")
	h.free()


func test_stash_theft(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var b := _first_box(h, Stash.CLAIM_KINDS)
	var c := _claim(h, s, b)
	c["items"] = {"W-013": 1, "M-001": 120, "I-030": 2, "M-211": 1, "M-096": 1}
	var k := Loot.key(h.map.id, b, 2277)
	var sp: Dictionary = s.spots()[k]
	sp["th"] = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	s._theft(k, sp, c, 12, rng)
	t.ok((c["items"] as Dictionary).has("M-211"), "퀘스트 물건(장부)은 가져가지 않는다(P10)")
	t.eq(int(c["items"].get("M-001", 0)), 60, "캡은 절반")
	t.ok(not (c["items"] as Dictionary).has("W-013"), "가장 값진 것부터 가져갔다")
	var bn := s.bundle(int(s.data()["qb"]))
	t.ok(not bn.is_empty() and bool(bn["quest"]), "처음 털린 묶음에 퀘스트가 붙었다")
	t.ok(str(c.get("trace", "")) != "", "흔적 글이 남았다")
	var r1 := RandomNumberGenerator.new()
	r1.seed = 99
	var r2 := RandomNumberGenerator.new()
	r2.seed = 99
	t.eq(s._dest(sp, true, r1), s._dest(sp, true, r2), "같은 씨앗이면 같은 행방(불러와도 같다)")
	var scr := ContainerScreen.new().setup(st, b, c, h.items_db, "", 150.0)
	s.on_open(b, c, scr)
	scr.free()
	t.eq(st.quests.stage("UQ-125"), 10, "털린 자리를 열어 흔적을 보면 UQ-125 단계 10")
	st.vars.set_v("SB_COLLAR", 1)
	var before := (s.data()["bundles"] as Array).size()
	s._on_day(0)
	t.eq((s.data()["bundles"] as Array).size(), before, "생포 중엔 털림 판정을 쉰다")
	st.vars.set_v("SB_COLLAR", 0)
	h.free()


func test_stash_kid(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var d := s.data()
	d["n"] = 1
	d["qb"] = 1
	var bn := {"id": 1, "key": "x", "map": "G-1-1", "spot": "장롱", "day": 10, "items": {"I-030": 2, "M-096": 1, "M-012": 2}, "who": "kid",
		"dest": h.map.id, "state": "held", "quest": true, "th": 1}
	(d["bundles"] as Array).append(bn)
	st.quests.set_stage("UQ-125", 10)
	s._on_map(h.map.id)
	t.eq(st.quests.stage("UQ-125"), 30, "흔적이 가리킨 빈집에 들어서면 단계 30")
	t.eq(int(st.vars.get_v("UQ125_KID")), 1, "빈집에 아이가 있다")
	t.ok(st.is_child("N-UQ-K1"), "아이는 공격 대상이 아니다(외형 K)")
	s._cmd(["kid_share"], func() -> void: pass)
	t.eq(int(st.items.get("M-012", 0)), 2, "나머지는 돌려받았다")
	t.eq(int(st.items.get("I-030", 0)), 0, "먹을 것은 아이 몫")
	t.eq(int(st.items.get("M-195", 0)), 2, "아이가 방울 줄 둘을 준다")
	t.eq(st.quests.stage("UQ-125"), 100, "끝")
	t.eq(int(st.vars.get_v("UQ125_R")), 2, "결과 = 나눠 줌")
	h.free()


func test_stash_fence(t) -> void:
	var tr: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/traders.json"))
	var mid := ""
	for k in tr:
		if str(tr[k]["region"]) == "R01":
			mid = str(k)
			break
	var r := _host(mid)
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var d := s.data()
	d["n"] = 1
	d["qb"] = 1
	var bn := {"id": 1, "key": "x", "map": "G-1-1", "spot": "금고", "day": 10, "items": {"M-085": 1}, "who": "fence", "dest": mid,
		"state": "held", "quest": true, "th": 2}
	(d["bundles"] as Array).append(bn)
	s._to_fence(bn)
	var vid := s._fence_vid(mid)
	var sh := h.shop_state(vid)
	t.ok(int(sh["items"].get("M-085", 0)) >= 1 and (sh["mine"] as Dictionary).has("M-085"), "털린 타자기가 장사꾼 진열에 올랐다(긁힌 자국)")
	st.vars.set_v("GAME_DAY", 20)
	sh = h.shop_state(vid)
	t.ok(int(sh["items"].get("M-085", 0)) >= 1, "진열을 갈아도 장물은 팔리기 전까지 남는다")
	sh["items"].erase("M-085")
	s.after_trade(vid)
	t.eq(st.quests.stage("UQ-125"), 100, "되사면 끝(되삼)")
	t.eq(int(st.vars.get_v("UQ125_R")), 4, "결과 = 되삼")
	h.free()


func test_stash_age(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var d := s.data()
	d["n"] = 1
	d["qb"] = 1
	(d["bundles"] as Array).append({"id": 1, "key": "x", "map": "G-1-1", "spot": "서랍", "day": 1, "items": {"I-030": 1, "M-096": 1},
		"who": "kid", "dest": "G-2-2", "state": "held", "quest": true, "th": 1})
	st.quests.set_stage("UQ-125", 10)
	s._age(9)
	t.ok(not (s.bundle(1)["items"] as Dictionary).has("I-030"), "7일 — 아이는 먹을 것을 다 먹었다")
	s._age(31)
	t.eq(str(s.bundle(1)["state"]), "gone", "30일 — 행방이 끝났다")
	t.eq(int(st.vars.get_v("UQ125_R")), 9, "놓침")
	h.free()


## 재미 검수 반영(1-L⑦): 첫 털림 오름 · 맡기기의 대가 · 지켜본 털림 · 낮 소굴의 말 판
func test_stash_review(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var s: Stash = r[1]
	var st: StoryState = r[2]
	var sp := {"since": 1, "th": 2}
	t.eq(s._ramp(sp, 3), 0.0, "유예 안에는 오름 없음")
	t.eq(s._ramp(sp, 9), 0.05, "유예 뒤 하루 +1%p")
	t.eq(s._ramp(sp, 40), 0.12, "상한 12%")
	t.eq(s._favorite({"items": {"W-013": 1, "I-030": 2, "M-001": 30}}), "W-013", "장난감이 없으면 아이는 처음 집은 것(값진 것)을 고집한다 — 맡기기의 대가")
	t.eq(s._favorite({"items": {"W-013": 1, "M-096": 1}}), "M-096", "장난감이 있으면 장난감")
	var b := _first_box(h, Stash.CLAIM_KINDS)
	var c := _claim(h, s, b)
	c["items"] = {"W-013": 1, "M-001": 120, "I-030": 2}
	var k := Loot.key(h.map.id, b, 2277)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	s._theft(k, s.spots()[k], c, 12, rng, "crew", true)
	var bn := s.bundle(int(s.data()["qb"]))
	if str(bn.get("who", "")) == "crew":
		t.ok(str(c["trace"]).begins_with("내가 본 것"), "지켜봤으면 흔적 대신 내가 본 것")
		t.eq(st.quests.stage("UQ-125"), 10, "지켜본 털림은 단계 10이 바로 열린다")
		var den := str(bn["dest"])
		st.vars.set_v("GAME_HOUR", 13)
		h.enter(den, "from_W")
		t.ok(not s._crew_calm().is_empty(), "낮 소굴의 털이꾼은 말이 통한다(먼저 치기 전)")
		t.eq(st.quests.stage("UQ-125"), 30, "소굴에 들어서면 단계 30")
		s._cmd(["crew_talk"], func() -> void: pass)
		t.eq(int(st.items.get("W-013", 0)), 1, "말로 자루를 돌려받았다")
		t.eq(int(st.vars.get_v("UQ125_R")), 8, "결과 = 털이꾼에게 말로")
		t.eq(int(st.items.get("M-195", 0)), 2, "입구 방울 줄 둘")
	else:
		t.ok(false, "털이꾼으로 고정한 털림이 소굴을 찾지 못했다: " + str(bn.get("who", "")))
	t.eq(s._ramp(sp, 40), 0.0, "퀘스트가 열린 뒤엔 오름 없음")
	h.free()
