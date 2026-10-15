## 단계 1-9e2 적 무기(SD-11 §7.4 · SD-14 주무기 · §3.3 미사일): 길 위 · 생성 건물 적 무기 다양화(자리로 시드 — 같은 자리 같은 무기) · 진행기 적은 그대로 ·
## 근접형 약탈자 수류탄 뒤 돌격 · 엄폐 3초 수류탄 · 개체 8초 · 분대 4초 · 연사 점사 리듬 · 붙으면 근접 무기로 전환 · 미사일 약한 유도.
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	return st


func _open(m: InteriorMap, w: int, h: int) -> Vector2i:
	for y in range(1, 60):
		for x in range(1, 80):
			var ok := true
			for dy in h:
				for dx in w:
					var t := Vector2i(x + dx, y + dy)
					if m.is_solid(t) or m.cover_at(t) != 0:
						ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _setup(st: StoryState) -> Array:
	if not InputMap.has_action("fire"):
		var setup: Node = load("res://systems/input/input_setup.gd").new()
		setup._ready()
		setup.free()
	var m := InteriorMap.new()
	m.load_map("D-02", st)
	var o := _open(m, 14, 7)
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	a.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), Vector2(o.x * 32 + 16, (o.y + 3) * 32 + 16), m)
	m.add_actor(a)
	c.on_map(m, a, st)
	for e in c.enemies.duplicate():
		c.drop_enemy(e)
	c.pc.hp = 99999.0
	c.pc.max_hp = 99999.0
	return [m, c, a, o]


func _at(o: Vector2i, dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _foe(c: InteriorCombat, m: InteriorMap, st: StoryState, id: String, at: Vector2, generic := true) -> Enemy:
	var e := c.spawn(id, at, m, st, {"lv": 3, "morale": generic})
	e.brain.state = AIBrain.S.COMBAT
	e.brain.gauge = 100.0
	return e


func _run(c: InteriorCombat, st: StoryState, secs: float, still: Array = []) -> void:
	for i in int(secs * 60.0):
		for e in still:
			e._t_tac = -99.0
			e._move = Vector2.ZERO
			e._path = PackedVector2Array()
		c.tick(1.0 / 60.0, true, st)


func test_arms_pick(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var seen := {}
	for i in 12:
		var e := _foe(c, m, st, "CR-421", _at(o, i % 12, (i * 5) % 6))
		seen[str(e.weapon.get("id", ""))] = true
		c.drop_enemy(e)
	t.ok(seen.size() >= 2 and seen.keys().all(func(k): return k in ["W-014", "W-025", "W-017"]), "약탈자 랭크 2: 사냥총 · 산탄총 · 자동소총 중(%s)" % ", ".join(seen.keys()))
	var a1 := _foe(c, m, st, "CR-421", _at(o, 3, 3))
	var w1 := str(a1.weapon.get("id", ""))
	c.drop_enemy(a1)
	var a2 := _foe(c, m, st, "CR-421", _at(o, 3, 3))
	t.eq(str(a2.weapon.get("id", "")), w1, "같은 자리 = 같은 무기(다시 열어도 같다)")
	var s := _foe(c, m, st, "CR-401", _at(o, 5, 3), false)
	t.eq(str(s.weapon.get("id", "")), "W-002", "진행기가 세운 계엄병은 다듬어 둔 장비 그대로")
	var g := _foe(c, m, st, "CR-401", _at(o, 6, 3))
	t.ok(str(g.weapon.get("id", "")) in ["W-018", "W-023"] and g.nades == 1, "길 위 계엄병: 돌격소총/레이저 소총 + 수류탄 1")
	var mel := _foe(c, m, st, "CR-423", _at(o, 7, 3))
	t.eq(mel.style, "melee", "근접 약탈자 = 근접 성향(%s)" % str(mel.weapon.get("name", "")))
	m.free()


func test_arms_nades(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var mel := _foe(c, m, st, "CR-423", _at(o, 6, 3))
	mel._arms_tactics(c.pc, 5.0, true)
	t.eq(mel.nades, 0, "근접형 약탈자: 붙기 전에 수류탄(3~9t)")
	t.ok(c.ord.nades.any(func(n): return str(n["team"]) != "player"), "적 수류탄이 날아간다(붉은 경고 원)")
	t.ok(mel.say_text in ["수류탄!", "받아라!"], "말풍선 '%s'" % mel.say_text)
	_run(c, st, 4.2, [mel])                                               # 같은 편 분대 재사용 4초가 지나게
	var b1 := _foe(c, m, st, "CR-401", _at(o, 9, 1))
	var b2 := _foe(c, m, st, "CR-401", _at(o, 9, 5))
	b1._hide_t = 2.0
	b1._arms_tactics(c.pc, 6.0, false)
	t.eq(b1.nades, 1, "엄폐 3초 전엔 던지지 않는다")
	b1._arms_tactics(c.pc, 6.0, false)
	t.eq(b1.nades, 0, "엄폐 뒤 3초 넘게 버티면 던진다")
	b2._hide_t = 5.0
	b2._arms_tactics(c.pc, 6.0, false)
	t.eq(b2.nades, 1, "분대 재사용 4초 안엔 다른 분대원이 못 던진다")
	_run(c, st, 4.2, [b1, b2])
	b2._hide_t = 5.0
	b2._arms_tactics(c.pc, 6.0, false)
	t.eq(b2.nades, 0, "4초 뒤엔 던진다")
	m.free()


func test_arms_burst_switch(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	a.loco.place(_at(o, 1, 3))
	var e := _foe(c, m, st, "CR-421", _at(o, 9, 3))
	e.weapon = c.weapons["W-018"].duplicate()
	e.style = "shooter"
	var times: Array = []
	var n0 := e.shots_fired
	for i in 240:
		e.has_token = true
		e._t_tac = -99.0
		e._move = Vector2.ZERO
		e._path = PackedVector2Array()
		c.tick(1.0 / 60.0, true, st)
		if e.shots_fired != n0:
			times.append(i / 60.0)
			n0 = e.shots_fired
	var gaps := 0
	for i in range(1, times.size()):
		if float(times[i]) - float(times[i - 1]) >= 0.45:
			gaps += 1
	t.ok(times.size() >= 8, "돌격소총 4초 %d발(점사 동안 최대 연사)" % times.size())
	t.ok(gaps >= 1, "점사 뒤 0.5~1.0초 쉰다(쉼 %d번)" % gaps)
	var g := _foe(c, m, st, "CR-457", _at(o, 2, 3))
	t.ok(not g.alt_weapon.is_empty(), "계약 경호 구울: 소방 도끼를 차고 있다")
	g._arms_tactics(c.pc, 1.0, true)
	t.ok(g.on_alt and g.style == "melee" and g._switch_t > 0.0, "붙으면 도끼로(바꾸는 0.6초)")
	g._arms_tactics(c.pc, 3.0, true)
	t.ok(not g.on_alt and g.style == "shooter", "떨어지면 다시 산탄총")
	m.free()


func test_arms_missile_home(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	a.loco.place(_at(o, 1, 3))
	var bot := _foe(c, m, st, "CR-401", _at(o, 10, 5), false)
	bot.cmb.robot = true
	bot.cmb.hp = 99999.0
	bot._cool = 999.0
	c.shots._rebucket()
	var from := a.loco.logical + Vector2(10, -12)
	var straight := rad_to_deg((bot.loco.logical - from).angle()) - 20.0          # 20° 빗겨 쏜다
	c.shots.fire_weapon(from, straight, "player", c.weapons["W-033"], 50.0)
	var s: Dictionary = c.shots.shots[-1]
	var a0 := (s["v"] as Vector2).angle()
	for i in 18:
		bot._t_tac = -99.0
		c.shots.step(1.0 / 60.0)
	var turned := rad_to_deg(angle_difference(a0, (s["v"] as Vector2).angle()))
	t.ok(bool(s.get("homing", false)) and turned >= 5.0 and turned <= 30.0 * 0.3 + 0.5, "미사일이 로봇 쪽으로 돈다(0.3초에 %.1f°, 초당 30° 한도)" % turned)
	var man := _foe(c, m, st, "CR-401", _at(o, 10, 1), false)
	man._cool = 999.0
	bot.cmb.robot = false
	c.shots.fire_weapon(from, rad_to_deg((man.loco.logical - from).angle()) - 20.0, "player", c.weapons["W-033"], 50.0)
	var s2: Dictionary = c.shots.shots[-1]
	for i in 18:
		c.shots.step(1.0 / 60.0)
	t.ok(not s2.has("homing"), "사람은 쫓지 않는다(로봇 · 파워 아머만)")
	m.free()
