## 단계 1-9e1 사기(SD-11 §7.5 · §7.6 · §4.8 · SD-14 §12.1): 속성 표 · 자신감별 도주 · 다시 교전 · 궁지 항복 · 놓아주기 · 항복한 적 사살 카르마 ·
## 분대장(+1 · 사망 −1) · 무리 우두머리 사망 50% 도주 · 이야기 적(사기 없음) · 약물 광란 · 부위 손상 효과.
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
	return [m, c, a, o]


func _at(o: Vector2i, dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _foe(c: InteriorCombat, m: InteriorMap, st: StoryState, id: String, at: Vector2, morale := true) -> Enemy:
	var e := c.spawn(id, at, m, st, {"lv": 3, "morale": morale})
	e.brain.state = AIBrain.S.COMBAT
	e.brain.gauge = 100.0
	return e


func _run(c: InteriorCombat, st: StoryState, secs: float) -> void:
	for i in int(secs * 60.0):
		c.tick(1.0 / 60.0, true, st)


func test_mor_traits(t) -> void:
	var r := EnemyTraits.of("CR-420")
	t.eq(int(r["conf"]), 2, "약탈자 자신감 2(보통)")
	t.ok(float(r["surr"]) > 0.0 and bool(r["drug"]), "약탈자: 일부 항복 · 약물")
	t.eq(float(EnemyTraits.of("CR-401")["surr"]), 0.0, "계엄군 항복 없음")
	t.eq(int(EnemyTraits.of("CR-104")["conf"]), 4, "들개 무모(4)")
	t.ok(bool(EnemyTraits.of("CR-106")["pack_lead"]), "들개 우두머리")
	t.ok(bool(EnemyTraits.of("CR-438")["leader"]), "새벽인력 반장 = 분대장")
	t.ok(EnemyTraits.should_flee(2, 0.35) and not EnemyTraits.should_flee(2, 0.36), "보통: HP 35% 이하")
	t.ok(EnemyTraits.should_flee(1, 0.7) and EnemyTraits.should_flee(0, 1.0), "신중 70% · 겁쟁이는 보자마자")
	t.ok(not EnemyTraits.should_flee(4, 0.01), "무모는 도주하지 않는다")


func test_mor_flee(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var e := _foe(c, m, st, "CR-420", _at(o, 6, 3))
	e.cmb.hp = e.cmb.max_hp * 0.3
	_run(c, st, 0.3)
	t.eq(e.brain.state, AIBrain.S.FLEE, "HP 30% 약탈자(자신감 2) → 도주")
	t.ok(e.say_text != "" and e.say_t > 0.0, "말풍선 '%s'" % e.say_text)
	var d0 := e.loco.logical.distance_to(a.loco.logical)
	var shots0 := e.shots_fired
	_run(c, st, 1.5)
	t.ok(e.loco.logical.distance_to(a.loco.logical) > d0 + 16.0, "주인공에게서 멀어진다(%.0f → %.0f)" % [d0, e.loco.logical.distance_to(a.loco.logical)])
	t.eq(e.shots_fired, shots0, "도주 중엔 쏘지 않는다")
	e.brain.flee_for = 0.0
	_run(c, st, 0.3)
	t.eq(e.brain.state, AIBrain.S.COMBAT, "시간이 지나면 다시 교전(원작 '용기를 되찾아')")
	var s := _foe(c, m, st, "CR-420", _at(o, 9, 5), false)
	s.cmb.hp = s.cmb.max_hp * 0.2
	_run(c, st, 0.3)
	t.ok(s.brain.state != AIBrain.S.FLEE, "진행기가 세운 적(사기 없음)은 끝까지 싸운다")
	m.free()


func test_mor_surrender(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var e := _foe(c, m, st, "CR-435", _at(o, 4, 3))                      # 새벽인력 모집원: 항복 100%
	e.flee_now(a.loco.logical)
	e._cornered()
	t.eq(e.brain.state, AIBrain.S.SURRENDER, "궁지 → 항복")
	t.ok(e.has_meta("surrendered"), "항복 표시")
	var shots0 := e.shots_fired
	_run(c, st, 1.0)
	t.eq(e.shots_fired, shots0, "항복한 적은 쏘지 않는다")
	t.eq(e.brain.state, AIBrain.S.SURRENDER, "가만히 있으면 항복 유지")
	a.loco.place(e.loco.logical + Vector2(-30, 0))
	t.ok(c.surrendered_near(a.loco.logical) == e, "1.5t 안 = 놓아주기 대상")
	c.release(e)
	t.ok(e.released and e.cmb.team == "gone" and e.foes.is_empty(), "놓아줌: 적대하지 않는다")
	_run(c, st, 16.0)
	t.ok(not c.enemies.has(e), "멀어지면 전장에서 빠진다")
	var k0 := int(st.vars.get_v("V_KARMA"))
	var e2 := _foe(c, m, st, "CR-435", _at(o, 8, 3))
	e2._cornered()
	e2.cmb.last_by = "player"
	e2.cmb.take({"hp": 9999.0}, a.loco.logical)
	t.eq(int(st.vars.get_v("V_KARMA")), k0 - 10, "항복한 적을 쏘아 죽이면 카르마 −10")
	m.free()


func test_mor_leader_pack(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var boss := _foe(c, m, st, "CR-438", _at(o, 8, 2))
	var mem := _foe(c, m, st, "CR-437", _at(o, 10, 2))
	t.eq(mem.confidence(), 2, "분대장이 곁에 있으면 자신감 +1(1 → 2)")
	boss.cmb.last_by = "player"
	boss.cmb.take({"hp": 9999.0}, a.loco.logical)
	t.eq(mem.conf_mod, -1, "분대장 사망: 자신감 −1")
	t.eq(mem.brain.state, AIBrain.S.FLEE, "신중(1) 이하가 된 분대원은 도주")
	var routs := 0
	for k in 8:                                                           # 우두머리 사망: 무리 50% 도주(전부 또는 아무도)
		var lead := _foe(c, m, st, "CR-106", _at(o, 3, 5))
		var dogs: Array = []
		for i in 3:
			dogs.append(_foe(c, m, st, "CR-104", _at(o, 4 + i, 6)))
		lead.cmb.last_by = "player"
		lead.cmb.take({"hp": 9999.0}, a.loco.logical)
		var n := dogs.filter(func(d): return d.brain.state == AIBrain.S.FLEE).size()
		t.ok(n == 0 or n == 3, "무리는 함께 흩어지거나 함께 남는다(%d)" % n)
		if n == 3:
			routs += 1
		for d in dogs:
			c.drop_enemy(d)
	t.ok(routs >= 1 and routs <= 7, "8번 중 흩어짐 %d번(50%%)" % routs)
	m.free()


func test_mor_drug_limbs(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var e := _foe(c, m, st, "CR-421", _at(o, 6, 3))
	e._drug_done = true
	e._drug_t = 0.1
	_run(c, st, 0.3)
	t.ok(e.frenzied and e.brain.state == AIBrain.S.FRENZY, "약물 → 광란")
	e.cmb.hp = e.cmb.max_hp * 0.1
	_run(c, st, 0.3)
	t.eq(e.brain.state, AIBrain.S.FRENZY, "광란은 도주하지 않는다")
	var g := _foe(c, m, st, "CR-420", _at(o, 9, 3))
	var hp0 := g.cmb.hp
	g.cmb.take({"hp": 1.0, "part": "leg", "limb": 999.0}, a.loco.logical)
	t.ok(g.cmb.crippled.has("leg"), "다리 부위 체력 바닥 → 부위 손상")
	t.near(g.loco.speed_mul, 0.5, 0.001, "다리 손상: 이동 −50%")
	t.ok(g.cmb.held_by("flinch"), "부위 손상 순간 0.6초 멈춤")
	g.cmb.take({"hp": 1.0, "part": "arm", "limb": 999.0}, a.loco.logical)
	t.near(g._spread_add, 8.0, 0.001, "팔 손상: 퍼짐 +8°")
	var p0 := g.per
	g.cmb.take({"hp": 1.0, "part": "head", "limb": 999.0}, a.loco.logical)
	t.near(g.per, p0 * 0.6, 0.001, "머리 손상: 인지 −40%")
	t.near(g.cmb.hp, hp0 - 3.0, 0.001, "HP는 HP 피해만")
	var f := _foe(c, m, st, "CR-435", _at(o, 11, 3))
	f.flee_now(a.loco.logical)
	f.cmb.take({"hp": 1.0, "part": "leg", "limb": 999.0}, a.loco.logical)
	t.eq(f.brain.state, AIBrain.S.SURRENDER, "도주 중 다리 손상 → 항복(항복 가능 개체)")
	m.free()
