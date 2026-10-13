## 단계 0-7 실내 전투·핍-보이·MQ-P2 자료: 주인공 HP(SD-10), 사격장 표적·은신 표적(정합), 낮은 엄폐(SD-11 §4.2), 재장전 식(§3.5),
## 근접·큰바퀴·바퀴 고기(SD-14), 스팀팩 회복 대기열(§2.7), 단축키, 맵 사이 길, 여러 번 조사하는 글, 핍-보이 목록.
extends RefCounted


func _state(stage := 50) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	st.quests.set_stage("MQ-P1", 100)
	st.quests.set_stage("MQ-P2", stage)
	return st


func _setup(map_id: String, st: StoryState, at: Vector2) -> Array:
	var m := InteriorMap.new()
	m.load_map(map_id, st)
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	var lk := CharDocs.paperdoll_look(CharDocs.look_of(st))
	lk["body"] = "K1"
	a.setup_doll(lk, at, m)
	m.add_actor(a)
	m.objects.add_child(a)
	c.on_map(m, a, st)
	return [m, c, a]


func test_derived_hp(t) -> void:
	var st := _state()
	t.eq(InteriorCombat.derived(st)["hp_max"], 200.0, "Lv1 HP = 90 + 지구력 5 × 20 + 10 (SD-10 §2.3)")
	st.vars.set_v("PC_EN", 6)
	st.vars.set_v("PC_AG", 7)
	var d := InteriorCombat.derived(st)
	t.eq(d["hp_max"], 220.0, "지구력 6 → 220")
	t.eq(d["ap_max"], 79.0, "AP = 65 + 민첩성 7 × 2")


func test_range_targets(t) -> void:
	var st := _state()
	var r := _setup("V-09", st, Vector2(30 * 32 + 16, 13 * 32 + 16))
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	t.eq(c.targets_left("target"), 10, "일반 표적 10")
	t.eq(c.targets_left("stealth"), 2, "은신 표적 2")
	st.call_fn("give", ["W-065"])
	st.call_fn("give", ["BB탄", 80])
	c.equip("W-065", st)
	t.eq(int(c.mags["W-065"]), 50, "탄창 50(SD-13 W-065)")
	t.eq(c.ammo_left(st), 30, "남은 BB탄")
	t.eq(m.cover_at(Vector2i(31, 12)), 1, "모래주머니 = 낮은 엄폐")
	t.eq(m.cover_at(Vector2i(0, 0)), 2, "벽 = 높은 엄폐")
	var downs := [0]
	c.target_down.connect(func(_k, _s, _l): downs[0] += 1)
	var tg: Dictionary = c.targets.filter(func(x): return x["kind"] == "target" and int(x["prop"]["y"]) == 13)[0]
	c.bot = {"aim": tg["cmb"].pos() + Vector2(0, -4), "fire": true, "aimed": true}
	for i in 600:
		c.tick(1.0 / 60.0, true, st)
		if tg["down"]:
			break
	t.ok(tg["down"] and downs[0] == 1, "같은 줄의 표적을 쏘아 넘긴다(%d발)" % c.stats["shots"])
	c.mags["W-065"] = 10
	c.bot = {}
	c.start_reload(st)
	t.near(c.reload_t, 2.0 * (1.2 - 0.004 * st.skill("SMALL_GUNS")), 0.001, "재장전 = 기본 2.0 × (1.2 − 0.004 × 스킬)")
	m.free()


func test_stealth_targets(t) -> void:
	var st := _state()
	var r := _setup("V-09", st, Vector2(30 * 32 + 16, 16 * 32 + 16))
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var tg: Dictionary = c.targets.filter(func(x): return x["kind"] == "stealth" and int(x["prop"]["y"]) == 12)[0]
	t.ok(not tg["live"], "1부: 은신 표적은 숨어 있다")
	c.set_stealth_live(true)
	for i in 240:                                                     # 서서 보이는 자리: 들킨다
		c.tick(1.0 / 60.0, true, st)
	t.ok(tg["seen_t"] > 0.0 and c.stats["spotted"] >= 1, "서 있으면 들킨다(게이지 %.0f)" % tg["gauge"])
	var hide := Vector2(30 * 32 + 16, 12 * 32 + 16)
	t.ok(m.line_of_sight(tg["cmb"].pos(), hide, false), "서 있으면 모래주머니 너머로 보인다")
	t.ok(not m.line_of_sight(tg["cmb"].pos(), hide, true), "웅크리면 낮은 엄폐가 시야를 막는다(SD-11 §4.2)")
	st.call_fn("give", ["W-065"])
	st.call_fn("give", ["BB탄", 60])
	c.equip("W-065", st)
	a.loco.place(hide)
	c.crouch = true
	tg["seen_t"] = 0.0
	tg["gauge"] = 0.0
	m.set_prop_state(Vector2i(35, 12), "")
	t.eq(c.shots._blocked(hide + Vector2(10, -14), hide + Vector2(40, -14), {"origin": hide + Vector2(10, -14), "team": "player"}),
		Vector2(-1, -1), "바로 앞 모래주머니는 내 탄을 막지 않는다")
	c.bot = {"aim": tg["cmb"].pos() + Vector2(0, -4), "fire": true, "crouch": true, "aimed": true}
	for i in 900:
		c.tick(1.0 / 60.0, true, st)
		if tg["down"]:
			break
	t.ok(tg["down"] and c.stats["sneak"] >= 1, "숨은 채 맞히면 은신 기습으로 넘어간다")
	t.ok(c.detect_state() != "", "HUD 탐지 표시: 웅크리면 보인다(%s)" % c.detect_state())
	c.crouch = false
	c.bot = {}
	t.ok(c.detect_state() in ["", "위험"], "서 있으면 [위험]만")
	m.free()


func test_roach_melee_and_loot(t) -> void:
	var st := _state(60)
	var r := _setup("V-11", st, Vector2(11 * 32 + 16, 10 * 32 + 16))
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	t.eq(c.alive_enemies(), 6, "배관실 큰바퀴 6(cond MQP2_STAGE == 60)")
	st.call_fn("give", ["W-067"])
	c.equip("W-067", st)
	t.ok(c.weapon()["two_handed"] and c.weapon()["kind"] == "melee", "대걸레 자루 = 양손 근접(W-067)")
	var e: Enemy = c.enemies[0]
	e.loco.place(c.pc.pos() + Vector2(30, 0))
	c.bot = {"aim": e.loco.logical + Vector2(0, -6), "fire": true}
	var xp0 := int(st.vars.get_v("PC_XP"))
	for i in 600:
		e.loco.place(c.pc.pos() + Vector2(30, 0))
		c.tick(1.0 / 60.0, true, st)
		if e.cmb.dead:
			break
	t.ok(e.cmb.dead, "대걸레 자루로 큰바퀴를 잡는다(%d번)" % c.stats["hits"])
	t.ok(c.stats["hits"] <= 3, "큰바퀴 HP 8 — 두세 대")
	t.eq(int(st.items.get("I-036", 0)), 1, "바퀴 고기 100%(SD-14 §3.1)")
	t.eq(int(st.vars.get_v("PC_XP")) - xp0, 1, "XP 1")
	m.free()


func test_stimpak_queue(t) -> void:
	var st := _state(60)
	var r := _setup("V-11", st, Vector2(11 * 32 + 16, 17 * 32 + 16))
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	for e in c.enemies:
		e.cmb.dead = true
	c.pc.hp = 80.0
	st.call_fn("give", ["I-001", 2])
	t.ok(c.use_stimpak(st, true), "스팀팩을 쓴다")
	var amount := 30.0 * (1.0 + st.skill("MEDICINE") / 50.0)
	t.near(c.inject_t, 0.4, 0.001, "단축키 투여 0.4초")
	for i in 60:
		c.tick(1.0 / 60.0, true, st)
	t.near(c.pc.hp, 80.0 + amount / 2.0, 1.0, "1초 뒤 절반(2.0초에 고르게)")
	for i in 70:
		c.tick(1.0 / 60.0, true, st)
	t.near(c.pc.hp, 80.0 + amount, 0.5, "2초 뒤 30 × (1 + 의학/50) = %.1f" % amount)
	t.eq(int(st.items.get("I-001", 0)), 1, "하나 썼다")
	c.pc.hp = c.pc.max_hp
	t.ok(not c.use_stimpak(st), "다친 데가 없으면 쓰지 않는다")
	var downs := [0]
	c.player_down.connect(func(): downs[0] += 1)
	c.damage(9999.0)
	t.eq(downs[0], 1, "HP 0 → player_down 한 번")
	m.free()


func test_hotkeys(t) -> void:
	var c := InteriorCombat.new()
	c.auto_hotkey("W-065")
	c.auto_hotkey("W-067")
	c.auto_hotkey("I-001")
	c.auto_hotkey("W-065")
	t.eq(c.hotkeys, {1: "W-065", 2: "W-067", 3: "I-001"}, "받은 차례로 단축키 1·2, 스팀팩 3")
	c.free()


func test_map_graph_and_texts(t) -> void:
	var r := MapGraph.route("V-09", "V-11")
	t.ok(not r.is_empty() and r[-1] == "V-11", "보안과 → 하층 배관 길: %s" % str(r))
	var e := MapGraph.next_exit("V-03", "V-02")
	t.ok(e.x >= 0, "교무 구역 → 관리동 첫 출구 %s" % str(e))
	var st := _state(40)
	var m := InteriorMap.new()
	m.load_map("V-01", st)
	var meta: Dictionary = m.text_meta.get(Vector2i(37, 39), {})
	t.eq(meta.get("seq", []).size(), 2, "바닥 틈: 두 번 읽고")
	t.eq(meta.get("scene", ""), "MQ-P2_S04_CARD", "세 번째 조사에 카드 장면")
	t.ok(m.texts.get(Vector2i(34, 31), "").contains("생일자"), "2268 배급 창구 글(2277 글은 숨는다)")
	m.free()


func test_pipboy_rows(t) -> void:
	var st := _state()
	st.call_fn("give", ["W-065"])
	st.call_fn("give", ["BB탄", 40])
	st.call_fn("give", ["I-001", 2])
	st.call_fn("give", ["M-201"])
	var db := {"W-065": {"name": "BB총", "cat": "weapon"}, "I-001": {"name": "스팀팩", "cat": "aid"},
		"M-201": {"name": "첫 배정 통지서", "cat": "misc", "tag": "퀘스트"}}
	var p := PipBoy.new().setup(st, db, {"equipped": "W-065", "hotkeys": {1: "W-065"}})
	t.eq(p._rows().size(), 3, "능력치 > 상태: 신체·방사능·효과")
	p.open_at(0, 1)
	t.eq(p._rows().size(), 7, "S.P.E.C.I.A.L. 7")
	p.open_at(0, 2)
	t.eq(p._rows().size(), 13, "스킬 13")
	p.open_at(1, 0)
	t.eq(p._rows()[0]["text"], "BB총 [장착]", "무기: 장착 표시")
	t.eq(p._rows()[0]["right"], "(1)", "단축키 1")
	p.open_at(1, 4)
	t.eq(p._rows()[0]["right"], "40", "탄약: BB탄 40")
	p.open_at(2, 0)
	t.ok(p._rows().size() >= 2, "퀘스트: MQ-P2·MQ-P1")
	p.open_at(2, 1)
	t.eq(p._rows()[0]["id"], "M-201", "기록: 퀘스트 문서")
	var got := []
	p.action.connect(func(k, id): got.append([k, id]))
	p.open_at(1, 0)
	p._enter()
	t.eq(got, [["unequip", "W-065"]], "장착한 무기에서 결정 = 해제")
	p.free()
