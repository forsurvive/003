## 단계 0-7 실내 전투·핍-보이·MQ-P2 자료: 주인공 HP(SD-10), 사격장 표적·은신 표적(정합), 낮은 엄폐(SD-11 §4.2), 재장전 식(§3.5),
## 근접·큰바퀴·바퀴 고기(SD-14), 스팀팩 회복 대기열(§2.7), 단축키, 맵 사이 길, 여러 번 조사하는 글, 핍-보이 목록.
extends RefCounted


func _state(stage := 50) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	st.quests.set_stage("MQ-P1", 100)
	st.quests.set_stage("MQ-P2", stage)
	return st


## -s 실행에는 자동 로드(InputSetup)가 없다 — 전투가 읽는 행동(fire·aim·crouch·holster…)을 시험 안에서 만든다
func _inputs() -> void:
	if not InputMap.has_action("fire"):
		var setup: Node = load("res://systems/input/input_setup.gd").new()
		setup._ready()
		setup.free()


func _setup(map_id: String, st: StoryState, at: Vector2) -> Array:
	_inputs()
	var m := InteriorMap.new()
	m.load_map(map_id, st)
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	var lk := CharDocs.paperdoll_look(CharDocs.look_of(st))
	lk["body"] = "K1"
	a.setup_doll(lk, at, m)
	m.add_actor(a)
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
	t.eq(p._rows()[0]["text"], "BB총 (새것) [장착]", "무기: 장착 표시")
	t.eq(p._rows()[0]["right"], "(1)", "단축키 1")
	p.open_at(1, 4)
	t.eq(p._rows()[0]["right"], "40", "탄약: BB탄 40")
	p.open_at(2, 2)
	t.ok(p._rows().size() >= 2, "퀘스트: MQ-P2·MQ-P1")
	p.open_at(2, 3)
	t.eq(p._rows()[0]["id"], "M-201", "기록: 퀘스트 문서")
	var got := []
	p.action.connect(func(k, id): got.append([k, id]))
	p.open_at(1, 0)
	p._enter()
	t.eq(got, [["unequip", "W-065"]], "장착한 무기에서 결정 = 해제")
	p.free()


## 조준 자세(SD-16 §5.10): 걷기만 할 때는 조준하지 않는다(뒷걸음 없음) · 쏘면 그쪽을 보고 1초 유지 · 탄도는 360°(8방향 스냅 아님)
func test_aim_pose_and_360(t) -> void:
	var st := _state()
	var r := _setup("V-09", st, Vector2(30 * 32 + 16, 16 * 32 + 16))
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	st.call_fn("give", ["W-065"])
	st.call_fn("give", ["BB탄", 100])
	c.equip("W-065", st)
	c.bot = {"walk": true}
	for i in 30:
		a.move(Vector2(-1, 0), 1.0 / 60.0)                                # 서쪽으로 걷는다
		c.tick(1.0 / 60.0, true, st)
	t.eq(a.aim_dir, -1, "걷기만 하면 조준 자세가 아니다(무기를 들고 있어도)")
	t.ok(not a.loco.reverse, "뒷걸음이 아니다")
	var eye := a.loco.logical + Vector2(0, -14)
	var aim := eye + Vector2.RIGHT.rotated(deg_to_rad(-33.0)) * 200.0     # 8방향 사이의 비스듬한 각
	c.shots.rng.seed = 7                                                  # 맵이 트리 밖이라 _ready 시드가 없다 — 퍼짐 굴림 고정
	c.bot = {"aim": aim, "fire": true, "aimed": true}
	c.cool = 0.0
	c.tick(1.0 / 60.0, true, st)
	t.ok(c.shots.shots.size() >= 1, "쐈다")
	var ang := rad_to_deg((c.shots.shots[-1]["v"] as Vector2).angle())
	var base := rad_to_deg((aim - (c.shots.shots[-1]["origin"] as Vector2)).angle())   # 총구에서 조준점으로(눈높이 기준 -33°와 1~2° 차이)
	var sp := CombatRules.spread(st.skill("SMALL_GUNS"), "aim", false)
	t.ok(absf(base - (-33.0)) < 3.0, "총구→조준점 각은 조준한 각 근처: %.1f°" % base)
	t.ok(absf(ang - base) <= sp + 0.5, "탄은 총구에서 조준점으로 ± 퍼짐 %.1f°로 난다: %.1f° (기준 %.1f°)" % [sp, ang, base])
	t.ok(absf(fposmod(ang, 45.0)) > 0.01, "45° 단위로 붙지 않는다")
	t.eq(a.aim_dir, Locomotion.snap8(aim - (a.loco.logical + Vector2(0, -14)), 0.0), "쏘는 동안 상체(그림)는 가까운 8방향")
	c.bot = {"walk": true}
	for i in 30:
		c.tick(1.0 / 60.0, true, st)
	t.ok(a.aim_dir >= 0, "쏜 뒤 1초는 조준 자세를 유지")
	for i in 40:
		c.tick(1.0 / 60.0, true, st)
	t.eq(a.aim_dir, -1, "1초가 지나면 걷는 쪽을 보는 전신 자세로")
	m.free()


## 고전 조작(키보드 단독, SD-11 §2.3): 바라보는 방향 반각 15° 안의 가장 가까운 표적으로 조준을 끌어당긴다
func test_classic_auto_aim(t) -> void:
	var st := _state()
	var r := _setup("V-09", st, Vector2(30 * 32 + 16, 13 * 32 + 16))
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	st.call_fn("give", ["W-065"])
	c.equip("W-065", st)
	a.loco.facing = 0                                                     # 동쪽을 본다
	var tg: Dictionary = c.targets.filter(func(x): return x["kind"] == "target" and int(x["prop"]["y"]) == 13)[0]
	t.eq(c.auto_aim(a), tg["cmb"].pos() + Vector2(0, -12), "정면의 표적(같은 줄)으로 끌어당긴다")
	a.loco.facing = 6                                                     # 북쪽: 원뿔 안에 표적이 없다
	var p := c.auto_aim(a)
	t.ok(absf((p - (a.loco.logical + Vector2(0, -14))).angle() - deg_to_rad(-90.0)) < 0.01, "원뿔 안에 없으면 바라보는 방향 그대로")
	c._aim_point(a)
	t.ok(not c._aim_real, "표적이 없으면 가상 조준점 — 탄은 총구가 아니라 바라보는 방향 그대로 난다(눈높이 차이로 틀어지지 않게)")
	a.loco.facing = 0
	c._aim_point(a)
	t.ok(c._aim_real, "표적을 잡으면 총구에서 그 표적으로 쏜다")
	_inputs()
	t.ok(InputMap.action_has_event("fire", _key(KEY_Z)) and InputMap.action_has_event("aim", _key(KEY_X)), "Z = 공격 · X = 정조준")
	m.free()


## 탄·총구 효과(SD-16 §10.1, §5 'muzzle'): 16방향 시트의 열·컷 시간, 탄은 그려진 총의 총구에서 나가고,
## 총구 효과는 인형이 총과 같은 층에 그린다(N·NE면 몸 뒤). 벽에 막힌 탄은 맞은 자리에 불꽃을 남긴다.
func test_muzzle_and_fx(t) -> void:
	t.eq(CombatFx.col(0.0), 0, "동쪽 = 0열")
	t.eq(CombatFx.col(22.5), 1, "22.5° = 1열")
	t.eq(CombatFx.col(-90.0), 12, "북쪽(-90°) = 12열")
	t.eq(CombatFx.col(349.0), 0, "349°는 가까운 동쪽 열")
	t.eq(CombatFx.frame_at("flash_air", 0.0), 0, "분출 첫 컷")
	t.eq(CombatFx.frame_at("flash_air", 2.0 / 60.0), 1, "2틱 뒤 둘째 컷")
	t.eq(CombatFx.frame_at("flash_air", 4.0 / 60.0), -1, "4틱 뒤 끝")
	t.eq(CombatFx.flash_for({"sound": "suppressed"}), "flash_air", "공기총(소음)은 불꽃 대신 분출")
	t.eq(CombatFx.flash_for({"sound": "pistol"}), "flash_pistol", "화약 총은 총구 화염")
	t.ok(CombatFx.meta()["sets"].values().all(func(v): return int(v.get("cell", 16)) * int(v.get("dirs", 16)) <= CombatFx.sheet().get_width()), "시트 폭 안에 세트마다 16방향(또는 무방향 컷)이 다 든다")
	var st := _state()
	var r := _setup("V-09", st, Vector2(30 * 32 + 16, 18 * 32 + 16))
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	st.call_fn("give", ["W-065"])
	st.call_fn("give", ["BB탄", 100])
	c.equip("W-065", st)
	var mz_e := a.doll.muzzle_local(0)
	var mz_w := a.doll.muzzle_local(4)
	t.ok(mz_e.x > 8.0 and absf(mz_e.x + mz_w.x) < 0.01 and is_equal_approx(mz_e.y, mz_w.y), "서쪽 총구 = 동쪽 총구의 좌우 반전(%s · %s)" % [mz_e, mz_w])
	t.ok(a.doll.muzzle_local(6).y < a.doll.muzzle_local(2).y, "북쪽 총구가 남쪽 총구보다 위")
	c.bot = {"aim": a.loco.logical + Vector2(160, -14), "fire": true, "aimed": true}   # 동쪽
	c.cool = 0.0
	c.tick(1.0 / 60.0, true, st)
	var s: Dictionary = c.shots.shots[-1]
	t.ok((s["origin"] as Vector2).distance_to(a.position + a.doll.position + mz_e) < 0.01, "탄은 그려진 총구에서 나간다")
	t.eq(c.shots.flashes.size(), 0, "주인공의 총구 효과는 탄 풀이 아니라 인형이 그린다")
	t.ok(a.doll.muzzle_fx.visible and a.doll.muzzle_fx.z_index == 1, "동쪽 조준: 분출이 총 앞 층에 보인다")
	a.doll.fire_flash(6, -90.0, "flash_air")
	t.eq(a.doll.muzzle_fx.z_index, -1, "북쪽 조준: 분출도 총처럼 몸 뒤 층")
	c.bot = {"aim": a.loco.logical + Vector2(-160, -14), "fire": true, "aimed": true}  # 서쪽 벽(27열)
	c.cool = 0.0
	c.tick(1.0 / 60.0, true, st)
	c.bot = {"aim": a.loco.logical + Vector2(-160, -14)}
	for i in 20:
		c.tick(1.0 / 60.0, true, st)
	var sp: Array = c.shots.sparks.filter(func(f): return CombatFx.col(f["ang"]) == 8)
	t.ok(not sp.is_empty() and (sp[0]["at"] as Vector2).x <= 28 * 32 + 1, "서쪽 벽에 막힌 탄이 벽 자리에 불꽃을 남긴다")
	m.free()


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


## 0-10에서 찾은 결함: 실내·바깥 맵 적이 공격 토큰을 받지 못해 원거리 적이 한 발도 쏘지 않았다(SD-11 §7.4 보통 원거리 3)
func test_attack_tokens(t) -> void:
	var st := _state()
	var s := _setup("X-BC", st, Vector2(29 * 32 + 16, 36 * 32 + 16))
	var m: InteriorMap = s[0]
	var c: InteriorCombat = s[1]
	for i in 5:
		var e := c.spawn("CR-437", Vector2((24 + i * 3) * 32 + 16, 43 * 32 + 16), m, st, {"lv": 3})
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
	c.tick(0.1, true, st)
	var n := c.enemies.filter(func(e): return e.has_token).size()
	t.eq(n, 3, "사수 다섯 가운데 셋만 토큰을 받는다")
	var fired := 0
	for k in 60:
		c.tick(0.05, true, st)
	for e in c.enemies:
		fired += e.shots_fired
	t.ok(fired > 0, "토큰을 받은 사수는 실제로 쏜다(%d발)" % fired)
	m.free()
