## 단계 1-D3 독산 육가공 단지(DG-DS) · UQ-04 「7호 냉동 창고」(SD-05 §2.6 · §3.18 · SD-09a L-R01-29 · SD-14 CR-004 · CR-096 · SD-13 W-068 · 1-D 계획 §9.6):
## 자료(알집바퀴 · 굴쥐 · 미끼 · 썩은 고기 더미 · 던전 표) · 굴쥐(흙 칸에서만 땅속 · 들썩임 1.0초 · 솟으며 물기 · 언 흙) · 알집바퀴(소리에만 부화 · 딸깍 · 밸브 ·
## 처치 시 흩어짐) · 미끼(짐승이 먹으러 감 · 흙 위 미끼에 굴쥐가 나옴) · 소리 덮개 · UQ-04(일지 · 번호 · 넷 해법 · 정착민 운반 · 짐꾼 · 냉동기 정지 · 미룸 ·
## RE-045 · 냉기 · 왕쥐 가두기 · 자리 잡기) · 죽은 사람 판.
extends RefCounted


func _host(map_id := "DS-02", mark := "from_W") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	st.vars.set_v("PC_CAPS", 100)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  10:00"
	st.vars.set_v("GAME_HOUR", 10)
	var c := Uq04.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _aff(st: StoryState, code: String) -> int:
	return int(st.vars.get_v(st._aff_key(code)))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: Uq04, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "uq04":
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
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return dr.errors


func _opts(st: StoryState, c: Uq04, id: String) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var g := 0
	while cur["type"] != "choices" and cur["type"] != "end" and g < 80:
		g += 1
		if cur["type"] == "cmd" and str(cur["name"]) == "uq04":
			c._cmd(cur["args"], func() -> void: pass)
		cur = dr.advance()
	return (cur.get("opts", []) as Array).map(func(o): return str(o["text"]))


func _find(h: InteriorHost, id: String, cell := Vector2i(-1, -1)) -> Enemy:
	for e in h.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == id:
			if cell.x < 0 or h.map.tile_of(e.loco.logical) == cell:
				return e
	return null


func _place(h: InteriorHost, c: Vector2i) -> void:
	h.player.loco.logical = Vector2(c) * 32.0 + Vector2(16, 16)
	h.player.position = h.player.loco.logical


func _think(h: InteriorHost, e: Enemy, secs: float, watch := Callable()) -> void:
	var t := 0.0
	while t < secs:
		h.combat.nav.new_frame()                                        # 실제 전투 틱처럼 프레임마다 길찾기 예산(8회)을 되돌린다
		e.think(0.05, h.combat.pc, h.combat.nav, h.combat.shots)
		h.combat.ord.step(0.05, [])
		if watch.is_valid():
			watch.call()
		t += 0.05


func test_uq04_data(t) -> void:
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	t.ok(en.has("CR-004") and int(en["CR-004"]["hp"]) == 90 and int(en["CR-004"]["dr"]) == 10, "알집바퀴 HP 90 · DR 10(SD-14)")
	t.ok(en.has("CR-096") and int(en["CR-096"]["hp"]) == 80 and str(en["CR-096"]["attack"]) == "물기 18", "굴쥐 HP 80 · 물기 18")
	var th: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/throwables.json"))
	t.ok(th.has("W-068") and str(th["W-068"]["zone"]) == "bait" and float(th["W-068"]["zone_r"]) == 3.0 and float(th["W-068"]["zone_s"]) == 20.0,
		"미끼 W-068: 냄새 지대 3타일 20초")
	var loot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/loot.json"))
	t.ok(loot["tables"].has("carcass") and str(loot["tables"]["carcass"]["rows"][0][0]) == "W-068", "썩은 고기 더미 = 미끼 줍는 곳")
	var dg := Dungeon.of_map("DS-02")
	t.eq(str(dg.get("id", "")), "DG-DS", "던전 표 DG-DS")
	t.eq((dg.get("bosses", []) as Array).size(), 1, "우두머리 한 줄(굴의 왕쥐)")
	var d2: Dictionary = InteriorMap.read_data("DS-02")
	t.ok(d2.has("soil") and str(d2.get("soil_off", "")).contains("UQ04_COLD"), "흙 칸 줄 · 냉기를 돌리면 언다")
	t.ok((d2.get("hush", []) as Array).size() == 1, "5호 파리 떼 소리 덮개")
	for sid in ["UQ04_TAPE", "UQ04_PAD", "UQ04_SHELF", "UQ04_PANEL", "UQ04_TERM", "UQ04_WAGON", "UQ04_JO", "UQ04_FEUD", "DS_VALVE", "UQ04_RATK", "UQ04_CALF"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % sid), "장면 " + sid)


## 굴쥐: 흙 칸에서 땅속(무적 · 안 보임) → 표적 발밑에서 들썩임 1.0초 → 솟으며 물기 → 땅 위 4초 뒤 다시 판다 · 흙이 얼면 못 판다
func test_uq04_mole(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var m := _find(h, "CR-096", Vector2i(28, 18))
	t.ok(m != null and m.mole, "6호 흙 바닥에 굴쥐")
	t.ok(m.burrow == "under" and m.cmb.invuln and not m.visible, "흙 칸에서 시작하면 땅속(무적 · 안 보임)")
	_place(h, Vector2i(26, 17))
	h.combat.pc.hp = 100.0
	m.brain.state = AIBrain.S.COMBAT
	m.brain.gauge = 100.0
	var seen := {}
	_think(h, m, 4.0, func() -> void: seen[m.burrow] = true)
	t.ok(seen.has("heave"), "발밑에서 흙 들썩임(예비 동작)")
	t.ok(seen.has("emerge"), "솟아오른다")
	t.ok(h.combat.pc.hp < 100.0, "솟으며 문다(물기 18)")
	_place(h, Vector2i(10, 11))                                         # 흙에서 먼 복도로
	var tr := []
	_think(h, m, 9.0, func() -> void:
		m.brain.state = AIBrain.S.COMBAT                                 # 표적을 계속 안다(놓치면 숨는다 — 그건 따로)
		var k := m.burrow + "@" + str(h.map.tile_of(m.loco.logical))
		if tr.is_empty() or tr[-1] != k:
			tr.append(k))
	t.ok(m.burrow == "" and not m.cmb.invuln, "표적이 흙에서 멀면 땅 위로 쫓는다(들락날락하지 않는다) %s" % str(tr.slice(0, 12)))
	_place(h, Vector2i(30, 19))                                         # 다시 6호 흙 위로
	var dug := [false]
	_think(h, m, 14.0, func() -> void:                                 # 복도 끝(10,11)까지 쫓아간 굴쥐가 흙(약 20칸)으로 돌아와 판다 — 1-13 D-380 짐승 길 고침 뒤(전엔 6칸 밖에서 굳어 흙 곁에 남았다)
		m.brain.state = AIBrain.S.COMBAT                                 # 순간이동한 표적을 계속 안다(놓치면 그 자리를 뒤진다 — 그건 따로)
		m.brain.last_seen = h.player.loco.logical
		if m.burrow == "under" or m.burrow == "dig":
			dug[0] = true)
	t.ok(dug[0], "표적이 흙 위면 땅 위 4초 뒤 다시 판다(굴쥐 %s 흙 %s · 표적 %s)" % [str(h.map.tile_of(m.loco.logical)), str(h.map.soil_at(h.map.tile_of(m.loco.logical))), str(h.map.tile_of(h.player.loco.logical))])
	st.vars.set_v("UQ04_COLD", 1)
	h.enter("DS-02", "from_W")
	var m2 := _find(h, "CR-096", Vector2i(28, 18))
	t.ok(h.map.soil_off and m2 != null and m2.burrow == "" and not m2.cmb.invuln, "흙이 얼면 땅 위(맞는다)")


## 미끼: 교전 전 짐승이 냄새로 간다 · 먹는 동안 감지 ×0.4 · 흙 위 미끼에 굴쥐가 나온다(공짜 한 대)
func test_uq04_bait(t) -> void:
	var r := _host("DS-01", "from_W")
	var h: InteriorHost = r[0]
	var rat := _find(h, "CR-095", Vector2i(21, 6))
	t.ok(rat != null and rat.bait_at.is_valid(), "쥐에 미끼 감각 연결")
	_place(h, Vector2i(5, 19))
	var w: Dictionary = h.combat.weapons["W-068"]
	var n := h.combat.ord.throw(Vector2(23 * 32, 6 * 32), Vector2(25 * 32 + 16, 6 * 32 + 16), w, "player", 50.0, 8.0)
	n["fly"] = 0.01
	h.combat.ord.step(0.05, [])
	t.eq(h.combat.ord.zones.size(), 1, "착탄 즉시 냄새 지대")
	_think(h, rat, 4.0)
	t.ok(rat.eating and rat.pose == "eat", "쥐가 미끼로 가서 먹는다")
	# 흙 위 미끼 → 땅속 굴쥐가 나와 먹는다
	var r2 := _host()
	var h2: InteriorHost = r2[0]
	var m := _find(h2, "CR-096", Vector2i(28, 18))
	_place(h2, Vector2i(5, 11))
	var n2 := h2.combat.ord.throw(Vector2(26 * 32, 17 * 32), Vector2(30 * 32 + 16, 17 * 32 + 16), w, "player", 50.0, 8.0)
	n2["fly"] = 0.01
	h2.combat.ord.step(0.05, [])
	var seen := {}
	var trail := []
	_think(h2, m, 4.0, func() -> void:
		seen[m.burrow] = true
		if trail.is_empty() or trail[-1] != m.burrow + str(m.eating):
			trail.append(m.burrow + str(m.eating)))
	t.ok(seen.has("heave") and m.burrow == "" and m.eating and not m.cmb.invuln, "흙 위 미끼: 굴쥐가 솟아 먹는다(땅 위 — 맞는다) %s 지대 %s" % [str(trail), str(h2.combat.ord.zones.map(func(z): return h2.map.tile_of(z["p"])))])


## 알집바퀴: 웅크린 사람에겐 조용 · 소리에 들썩이면 9초에 '딸깍' · 10초에 부화(최대 6) · 밸브 = 알집이 떠내려감 · 처치 = 큰바퀴 흩어짐
func test_uq04_eggroach(t) -> void:
	var r := _host("DS-01", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq04 = r[2]
	var q := _find(h, "CR-004")
	t.ok(q != null and q.nest and q.hatch_cb.is_valid(), "도랑 둥지에 알집바퀴")
	_place(h, Vector2i(5, 19))
	h.combat.pc.posture = "crouch"
	_think(h, q, 12.0)
	t.eq(int(h.combat.stats.get("hatched", 0)), 0, "멀리서 웅크린 사람엔 부화하지 않는다")
	q.hear("pistol", q.loco.logical)
	var clicked := [false]
	_think(h, q, 10.2, func() -> void:
		if q.say_text.contains("딸") or q.say_text.contains("따"):
			clicked[0] = true)
	t.ok(clicked[0], "부화 1초 전 '딸깍'(자리를 알린다)")
	t.ok(int(h.combat.stats.get("hatched", 0)) >= 1, "소리에 들썩이면 10초에 부화")
	for i in 8:
		h.combat._hatch(q)
	var kids := h.combat.enemies.filter(func(o): return is_instance_valid(o) and not o.cmb.dead and int(o.get_meta("mother", 0)) == q.get_instance_id())
	t.ok(kids.size() <= Enemy.HATCH_MAX, "동시 최대 6")
	c._cmd(["valve"], func() -> void: pass)
	t.ok(_v(st, "DS_VALVE") == 1 and q.bare and q.brain.state == AIBrain.S.FLEE, "밸브: 알집이 떠내려가 맨몸으로 도망")
	var before := int(h.combat.stats.get("hatched", 0))
	q._stir = 15.0
	_think(h, q, 11.0)
	t.eq(int(h.combat.stats.get("hatched", 0)), before, "알집이 없으면 더 깨지 않는다")
	var fled := 0
	q.cmb.last_by = "player"
	q.cmb.take({"hp": 999.0}, Vector2.ZERO)
	for o in kids:
		if is_instance_valid(o) and o.brain.state == AIBrain.S.FLEE:
			fled += 1
	t.ok(fled >= 1 or kids.size() <= 1, "처치: 주변 큰바퀴가 흩어진다(50%)")


## 소리 덮개: 5호 파리 떼 안에 선 표적은 감지 ×0.6 · 냉기를 돌리면 사라진다
func test_uq04_hush(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var rat := _find(h, "CR-095", Vector2i(9, 11))
	_place(h, Vector2i(20, 18))
	t.ok(h.map.hush_at(Vector2i(20, 18)) and is_equal_approx(rat._hush_mul(h.combat.pc), 0.6), "5호 안: 감지 ×0.6")
	_place(h, Vector2i(10, 12))
	t.ok(is_equal_approx(rat._hush_mul(h.combat.pc), 1.0), "복도: 그대로")
	st.vars.set_v("UQ04_COLD", 1)
	h.enter("DS-02", "from_W")
	t.ok(not h.map.hush_at(Vector2i(20, 18)), "파리가 얼어 죽으면 덮개도 없다")


## 일지 → 번호 → 7호 · 선반(직접 나름 ④) · 30일 뒤 정지 · 독산 안이면 하루 미룸
func test_uq04_open_take_thaw(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq04 = r[2]
	var o := _opts(st, c, "UQ04_PAD")
	t.ok(not o.any(func(x): return str(x).contains("1 · 0 · 2 · 2")), "일지를 듣기 전엔 날짜 버튼이 없다")
	t.eq(_play(st, c, "UQ04_TAPE"), [], "일지")
	t.ok(_v(st, "UQ04_KNOW") == 1 and st.quests.stage("UQ-04") == 10, "발동(단계 10 — 메모 한 줄)")
	t.eq(_play(st, c, "UQ04_PAD", ["1 · 0 · 2 · 2"]), [], "1022")
	t.ok(_v(st, "UQ04_OPEN") == 1 and _v(st, "UQ04_DUE") == 40 and st.quests.stage("UQ-04") == 20, "7호 열림 · 30일 뒤 정지")
	t.ok(not h.map.is_solid(Vector2i(34, 10)), "문이 열렸다(지나갈 수 있다)")
	t.eq(_play(st, c, "UQ04_SHELF", ["열 개"]), [], "상자 열 개")
	t.ok(int(st.items.get("I-027", 0)) == 5 and int(st.items.get("I-035", 0)) == 5 and _v(st, "UQ04_GONE") == 10, "런천미트 다섯 · 꽁치 다섯")
	t.ok(st.quests.stage("UQ-04") == 100 and _v(st, "UQ04_SOL") == 4, "④ 직접 나름 — 닫힘(XP 80)")
	t.eq(_v(st, "UQ04_LEFT"), 30, "남은 상자 30")
	st.vars.set_v("GAME_DAY", 40)
	c._on_day(40)
	t.ok(_v(st, "UQ04_THAW") == 0 and _v(st, "UQ04_DUE") == 41, "독산 안이면 하루 미룸(P4)")
	h.enter("DS-01", "from_W")
	h.cur_map = "X-BC"
	h.map.id = "X-BC"
	st.vars.set_v("GAME_DAY", 41)
	c._on_day(41)
	t.ok(_v(st, "UQ04_THAW") == 1 and _v(st, "UQ04_LEFT") == 0 and _v(st, "UQ04_SHELF") == 4, "멈춤: 남은 상자는 상한다 · 선반 '녹음'")


## ① 봉천 · ② 사당 · ③ 함준호 — 정착민 운반 · 짐꾼(지키면 쫓겨남) · 소문(BC −3) · RE-045(멈추는 날 대치 · 순번)
func test_uq04_tell_sell_feud(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq04 = r[2]
	c._cmd(["tape"], func() -> void: pass)
	c._cmd(["open", 1], func() -> void: pass)
	h.cur_map = "X-BC"
	h.map.id = "X-BC"
	var bc0 := _aff(st, "BC")
	t.eq(_play(st, c, "UQ04_JO", ["1022"]), [], "① 조만석에게")
	t.ok(_v(st, "UQ04_BC") == 1 and _aff(st, "BC") == bc0 + 6 and st.quests.stage("UQ-04") == 100, "BC +6 · 닫힘")
	t.eq(_play(st, c, "SQS08_HAM", ["팔게요", "그 값에"]), [], "③ 함준호에게 팖")
	t.ok(_v(st, "UQ04_JH") == 1 and _v(st, "PC_CAPS") == 300 and _v(st, "UQ04_BACK") == 100, "마흔 상자 200캡(상자당 5)")
	for d in [11, 12]:
		st.vars.set_v("GAME_DAY", d)
		c._on_day(d)
	t.eq(_v(st, "UQ04_JH"), 3, "감시조가 지키고 있어 짐꾼이 쫓겨난다")
	t.eq(_v(st, "UQ04_GONE"), 8, "감시조가 하루 4상자씩")
	for d in range(13, 16):
		st.vars.set_v("GAME_DAY", d)
		c._on_day(d)
	t.ok(_v(st, "UQ04_LEAK") == 1 and _aff(st, "BC") == bc0 + 3, "③ 소문이 닿아 BC −3")
	t.eq(_play(st, c, "SQS08_HAM", ["돌려준다"]), [], "짐꾼이 빈손 — 봉투 절반을 돌려준다")
	t.ok(_v(st, "UQ04_REFUND") == 1 and _v(st, "PC_CAPS") == 200, "100캡 돌려줌")
	var sa_a := _aff(st, "SA")
	t.eq(_play(st, c, "SD_HUH", ["1022", "됐어요"]), [], "② 허순자에게도")
	t.eq(_aff(st, "SA"), sa_a + 3, "남은 상자 20 — SA +3(먼저 빠진 만큼, A109)")
	for d in range(16, 22):
		st.vars.set_v("GAME_DAY", d)
		c._on_day(d)
		if _v(st, "UQ04_FEUD") == 1:
			break
	t.ok(_v(st, "UQ04_FEUD") == 1 and _v(st, "UQ04_THAW") == 0 and _v(st, "UQ04_LEFT") > 0 and _v(st, "UQ04_LEFT") <= Uq04.FEUD_LEFT, "둘 다 지키다 마지막 상자 — 7호 앞 대치(RE-045 · A107)")
	var left0 := _v(st, "UQ04_LEFT")
	var sa0 := _aff(st, "SA")
	var bc1 := _aff(st, "BC")
	t.eq(_play(st, c, "UQ04_FEUD", ["순번"]), [], "대치 장면")
	t.ok(_v(st, "UQ04_FEUD") == 2 and _v(st, "UQ04_THAW") == 0 and _v(st, "UQ04_LEFT") == 0, "이른 대치: 남은 %d상자를 나눠 지고 끝 · 냉동기는 아직" % left0)
	t.ok(_aff(st, "SA") != sa0 or _aff(st, "BC") != bc1, "순번 · 편 결과가 호감에 남는다")
	st.vars.set_v("GAME_DAY", 40)
	c._on_day(40)
	t.eq(_v(st, "UQ04_THAW"), 1, "냉동기는 제 날에 멈춘다(빈 7호)")


## RE-045에 오지 않으면 7일 뒤 스스로 나눈다(P10)
func test_uq04_feud_timeout(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq04 = r[2]
	c._cmd(["open", 1], func() -> void: pass)
	h.cur_map = "X-BC"
	h.map.id = "X-BC"
	c._cmd(["tell", "bc"], func() -> void: pass)
	c._cmd(["tell", "sa"], func() -> void: pass)
	st.vars.set_v("UQ04_DUE", 12)
	st.vars.set_v("GAME_DAY", 12)
	c._on_day(12)
	t.eq(_v(st, "UQ04_FEUD"), 1, "대치 시작")
	st.vars.set_v("GAME_DAY", 19)
	c._on_day(19)
	t.ok(_v(st, "UQ04_FEUD") == 2 and _v(st, "UQ04_THAW") == 1, "7일 뒤 스스로 나눠 끝 · 녹음")


## 냉기를 굴로: 10일 · 굴 무리가 언다(왕쥐 = 던전 정리) · 흙이 언다 · 선반 '땀'
func test_uq04_cold(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq04 = r[2]
	c._cmd(["open", 1], func() -> void: pass)
	t.ok(_find(h, "CR-097") != null, "굴에 왕쥐")
	t.ok(_opts(st, c, "UQ04_PANEL").any(func(x): return str(x).contains("[수리 50]")) or st.skill("수리") < 50, "[수리 50] 선택지")
	c._cmd(["cold"], func() -> void: pass)
	t.ok(_v(st, "UQ04_COLD") == 1 and _v(st, "UQ04_DUE") == 20, "냉동기 날이 10일로 준다(40 → 20)")
	t.ok(_v(st, "UQ04_RATK") == 2 and _v(st, "DG_DS") == 1, "둥지째 언 왕쥐 — 던전 정리")
	t.ok(_find(h, "CR-097") == null, "굴 무리가 사라졌다(언 채)")
	t.eq(_v(st, "UQ04_SHELF"), 3, "7호 선반이 땀을 흘린다")
	h.enter("DS-02", "from_W")
	t.ok(h.map.soil_off, "흙이 얼었다")
	t.ok(h.map.props.any(func(p): return str(p["name"]) == "frozen_ratking"), "언 왕쥐 조각상")
	c._cmd(["shard"], func() -> void: pass)
	t.eq(_v(st, "UQ04_SHARD"), 1, "치면 깨진다")


## 엉뚱한 짓: 왕쥐를 7호에 꾀어 문을 잠그면 8초 뒤 언다(상자 −5) · 열어 둔 채 떠나면 7호에 자리 잡는다
func test_uq04_trap(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq04 = r[2]
	c._cmd(["open", 1], func() -> void: pass)
	var k := _find(h, "CR-097")
	k.loco.logical = Vector2(36 * 32 + 16, 5 * 32 + 16)
	c._cmd(["lock"], func() -> void: pass)
	t.ok(h.map.is_solid(Vector2i(34, 10)), "문이 다시 잠겼다")
	c._process(Uq04.TRAP_S + 0.5)
	t.ok(_v(st, "UQ04_RATK") == 3 and _v(st, "UQ04_GONE") == Uq04.GNAW and _v(st, "DG_DS") == 1, "갇힌 왕쥐가 언다 · 갉은 상자 −5 · 정리")
	# 두 번째 판: 꾀어 두고 문을 열어 둔 채 떠남
	var r2 := _host()
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: Uq04 = r2[2]
	c2._cmd(["open", 1], func() -> void: pass)
	var k2 := _find(h2, "CR-097")
	k2.loco.logical = Vector2(36 * 32 + 16, 5 * 32 + 16)
	c2._process(0.6)
	h2.enter("DS-01", "from_DS02")
	c2._process(0.6)
	t.ok(_v(st2, "UQ04_RATK") == 4 and _v(st2, "UQ04_GONE") == Uq04.GNAW, "열어 둔 채 떠남: 왕쥐가 7호에 자리 잡는다")
	h2.enter("DS-02", "from_W")
	t.ok(_find(h2, "CR-097", Vector2i(36, 5)) != null and _v(st2, "UQ04_SHELF") == 5, "다음에 오면 7호 안에 · 선반 갉힘")
	h2.combat.enemy_killed.emit("CR-097", 0)
	t.ok(_v(st2, "UQ04_RATK") == 1 and _v(st2, "DG_DS") == 1, "7호에서 쓰러뜨려도 정리")


## 죽은 사람 판: 조만석 · 허순자 · 함준호가 죽었으면 그 길이 없다 · 성지후가 죽었으면 허순자가 직접 고른다
func test_uq04_dead(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Uq04 = r[2]
	c._cmd(["open", 1], func() -> void: pass)
	st.kill("N-R01-044")
	st.book.died("N-R01-044", "")
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene("SD_HUH"))
	var txt := ""
	var g := 0
	while cur["type"] != "end" and g < 60:
		g += 1
		if cur["type"] == "line":
			txt += str(cur.get("text", ""))
		if cur["type"] == "choices":
			var pick := -1
			for j in cur["opts"].size():
				if str(cur["opts"][j]["text"]).contains("1022"):
					pick = j
			if pick < 0:
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains("됐어요"):
						pick = j
			cur = dr.choose(maxi(0, pick))
		elif cur["type"] == "cmd":
			cur = dr.advance()
		else:
			cur = dr.advance()
	t.ok(not txt.contains("성지후한테") and txt.contains("내가 직접 고를게"), "성지후가 죽은 판의 대사")


## 순서 꼼수(A109) · 날짜 추리 · 출고 확인 · 7호 왕쥐와 짐꾼
func test_uq04_order(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq04 = r[2]
	t.ok(not _opts(st, c, "UQ04_PAD").any(func(x): return str(x).contains("1 · 0 · 2 · 2")), "단서 없이는 번호 버튼이 없다")
	t.eq(_play(st, c, "UQ04_NOTE2"), [], "2호 낙서")
	t.eq(_v(st, "UQ04_DATE"), 1, "그 밤의 날짜를 알아봄")
	t.eq(_play(st, c, "UQ04_PAD", ["1 · 0 · 2 · 2"]), [], "테이프 없이 날짜로 엶")
	t.eq(_v(st, "UQ04_OPEN"), 1, "7호 열림")
	c._cmd(["take", 30], func() -> void: pass)
	t.eq(_v(st, "UQ04_PRICE"), 50, "남은 10상자 — 값 50")
	st.vars.set_v("UQ04_RATK", 4)
	h.cur_map = "X-BC"
	h.map.id = "X-BC"
	var caps0 := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "SQS08_HAM", ["팔게요", "그 값에"]), [], "함준호에게 남은 만큼")
	t.ok(_v(st, "PC_CAPS") == caps0 + 50 and _v(st, "UQ04_BACK") == 25, "50캡 · 돌려받을 몫 25")
	for d in [11, 12]:
		st.vars.set_v("GAME_DAY", d)
		c._on_day(d)
	t.eq(_v(st, "UQ04_JH"), 4, "7호의 왕쥐 — 짐꾼이 물려 도망")
	t.eq(_v(st, "UQ04_LEFT"), 10, "선반은 그대로(갉힘)")
	var jh0 := _aff(st, "JH")
	t.eq(_play(st, c, "SQS08_HAM", ["못 준다"]), [], "치료비 — 못 준다")
	t.ok(_v(st, "UQ04_REFUND") == 2 and _aff(st, "JH") == jh0 - 3, "장부에 남음(JH −3)")
	var bc0 := _aff(st, "BC")
	t.eq(_play(st, c, "UQ04_JO", ["1022"]), [], "먼저 털고 조만석에게")
	t.eq(_aff(st, "BC"), bc0 + 3, "남은 10상자 — BC +3")
	h.enter("DS-02", "from_W")
	t.ok(h.map.props.any(func(p): return str(p["name"]) == "cart_tipped_ds"), "엎어진 상인회 수레")
	t.ok(not _opts(st, c, "UQ04_TERM").any(func(x): return str(x).contains("출고 확인")), "고리 셋 전엔 출고 확인이 없다")
	c._cmd(["tape"], func() -> void: pass)
	c._cmd(["link", 3], func() -> void: pass)
	t.eq(_play(st, c, "UQ04_TERM", ["출고 확인"]), [], "출고 확인을 누른다")
	t.eq(_v(st, "UQ04_SIGN"), 1, "200년 만의 출고 확인")
