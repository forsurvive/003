## 단계 1-9e4 생물 특수(SD-14 §4.2 · §7.2 · SD-11 §9.2 · SD-13 W-058): 빛나는 구울 방사능 폭발(피해 5 · 방사능 5/초 2초 · 야생 구울 HP +30% · 간격) ·
## 구울 방사능 회복(라드 100당 HP +1) · 들개 우두머리 울부짖기(무리 속도 +15% · 물기 +20% · 20초 · 쿨 30초) · 들개 지뢰 50% 회피 ·
## 최루: 인간형 적 인지력 −2 · 주인공 기침(질주 불가 · AP 회복 −50% · 인지력 −2 · 나온 뒤 4초).
extends RefCounted

const DT := 1.0 / 60.0


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
	c.pc.hp = 9999.0
	c.pc.max_hp = 9999.0
	return [m, c, a, o]


func _at(o: Vector2i, dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _foe(c: InteriorCombat, m: InteriorMap, st: StoryState, id: String, at: Vector2, fight := true) -> Enemy:
	var e := c.spawn(id, at, m, st, {"lv": 9})
	if fight:
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
	e._cool = 999.0
	return e


func test_cr_glow_burst(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	a.loco.place(_at(o, 1, 3))
	var g := _foe(c, m, st, "CR-202", _at(o, 4, 3))
	t.ok(g.glow and g._aura != null, "빛나는 구울: 오라 덧그림(가산)")
	t.eq(g.style, "melee", "근접(맨손 32)")
	var f1 := _foe(c, m, st, "CR-200", _at(o, 6, 3))
	var f2 := _foe(c, m, st, "CR-200", _at(o, 12, 3))                     # 8t — 반경 밖
	for f in [f1, f2]:
		f.cmb.hp = f.cmb.max_hp * 0.4
	var hp0 := c.pc.hp
	g._burst_cd = 0.0
	g._intent = {"goal": "hold"}
	c.tick(DT, true, st)
	t.eq(int(c.stats.get("bursts", 0)), 1, "표적 4t 안 → 방사능 폭발")
	t.near(c.pc.hp, hp0 - 5.0, 0.6, "폭발 피해 5")
	t.near(f1.cmb.hp, f1.cmb.max_hp * 0.7, 0.6, "반경 안 야생 구울 HP +30%")
	t.near(f2.cmb.hp, f2.cmb.max_hp * 0.4, 0.6, "반경 밖은 그대로")
	t.ok(c.rad.dose_at(a.loco.logical) >= 5.0, "방사능 5/초 지대(%.0f)" % c.rad.dose_at(a.loco.logical))
	t.ok(g._ring_t >= 0.0, "폭발 고리 그림")
	for i in 150:                                                           # 2.5초
		c.tick(DT, true, st)
	t.ok(c.rad.dose_at(a.loco.logical) < 5.0, "2초 뒤 지대가 걷힌다")
	t.eq(int(c.stats.get("bursts", 0)), 1, "간격 8초 안에는 다시 터지지 않는다")
	a.loco.place(_at(o, 1, 0) + Vector2(-200, 0))
	var g2 := _foe(c, m, st, "CR-202", _at(o, 10, 5))
	var f3 := _foe(c, m, st, "CR-200", _at(o, 12, 5))
	f3.cmb.hp = f3.cmb.max_hp * 0.5
	g2._burst_cd = 0.0
	c.tick(DT, true, st)
	t.eq(int(c.stats.get("bursts", 0)), 2, "표적이 멀어도 다친 야생 구울이 곁에 있으면 터뜨린다")
	m.free()


func test_cr_ghoul_rad_heal(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var gh := _foe(c, m, st, "CR-200", _at(o, 8, 3), false)
	var man := _foe(c, m, st, "CR-420", _at(o, 9, 3), false)
	for e in [gh, man]:
		e.cmb.hp = e.cmb.max_hp * 0.5
	var h0 := gh.cmb.hp
	var m0 := man.cmb.hp
	c.ord.zones.append({"p": _at(o, 8, 3), "r": 96.0, "t": 99.0, "kind": "rad", "team": "env", "w": {"rad": 25.0}, "skill": 0.0})
	for i in 240:                                                           # 4초
		gh._move = Vector2.ZERO
		gh._path = PackedVector2Array()
		c.tick(DT, true, st)
	t.near(gh.cmb.hp - h0, 1.0, 0.15, "구울: 25라드/초 4초 = 100라드 → HP +1")
	t.near(man.cmb.hp, m0, 0.001, "사람은 낫지 않는다")
	m.free()


func test_cr_howl(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var lead := _foe(c, m, st, "CR-106", _at(o, 8, 3))
	var near := _foe(c, m, st, "CR-104", _at(o, 9, 2), false)
	var far := _foe(c, m, st, "CR-104", _at(o, 8, 3) + Vector2(14 * 32, 0), false)
	c.tick(DT, true, st)
	t.eq(int(c.stats.get("howls", 0)), 1, "교전에 들자마자 울부짖는다")
	t.ok(lead.say_text in ["아우우우—!", "우워어어—!"], "말풍선 '%s'" % lead.say_text)
	t.ok(near.buff_t > 19.0 and lead.buff_t > 19.0, "12t 안 무리(자기 포함) 20초")
	t.eq(far.buff_t, 0.0, "12t 밖은 못 듣는다")
	c.tick(DT, true, st)
	t.near(near.loco.speed_mul, 1.15, 0.001, "속도 +15%")
	var hp0 := c.pc.hp
	near._cool = 0.0
	for i in 60:                                                        # 물기 앞 예비 동작(밸런스 재미 검수)을 지나 한 번 문다
		near._bite(DT, c.pc, a.loco.logical - near.loco.logical)
		if c.pc.hp < hp0:
			break
	t.near(hp0 - c.pc.hp, near.bite * 1.2, 0.6, "물기 +20%%(%.1f)" % (hp0 - c.pc.hp))
	near.buff_t = 0.01
	c.tick(DT, true, st)
	c.tick(DT, true, st)
	t.near(near.loco.speed_mul, 1.0, 0.001, "20초가 지나면 원래대로")
	t.ok(lead._howl_cd > 29.0, "쿨 30초")
	m.free()


func test_cr_dog_mines(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var mp := _at(o, 7, 3)
	c.ord.mines.append({"p": mp, "team": "player", "w": {}, "skill": 30.0, "arm": 0.0, "alarm": -1.0, "chain": -1.0, "disarm": 0.0})
	var dodged := 0
	for i in 40:
		var d := _foe(c, m, st, "CR-104", _at(o, 5, 3) + Vector2(0, float(i % 5) - 2.0) + Vector2(float(i) * 0.37, 0), false)
		var v := d._mine_dodge(Vector2.RIGHT)
		var again := d._mine_dodge(Vector2.RIGHT)
		if v != Vector2.RIGHT:
			dodged += 1
			t.ok(v.x > 0.0 and absf(v.y) > 0.5, "옆으로 비켜 가며 앞으로")
		t.ok(again == v, "한 번 굴린 개는 같은 길로")
		c.drop_enemy(d)
	t.ok(dodged >= 10 and dodged <= 30, "40마리 중 %d마리가 돌아간다(50%%)" % dodged)
	var d2 := _foe(c, m, st, "CR-104", _at(o, 5, 3), false)
	t.eq(d2._mine_dodge(Vector2.LEFT), Vector2.LEFT, "뒤쪽 지뢰는 상관없다")
	c.ord.mines.clear()
	c.ord.mines.append({"p": mp, "team": "enemy", "w": {}, "skill": 30.0, "arm": 0.0, "alarm": -1.0, "chain": -1.0, "disarm": 0.0})
	t.eq(d2._mine_dodge(Vector2.RIGHT), Vector2.RIGHT, "제 편 지뢰는 피하지 않는다(밟아도 안 터진다)")
	m.free()


func test_cr_gas(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var man := _foe(c, m, st, "CR-420", _at(o, 8, 3), false)
	var dog := _foe(c, m, st, "CR-104", _at(o, 8, 4), false)
	c.ord.zones.append({"p": _at(o, 8, 3), "r": 96.0, "t": 99.0, "kind": "gas", "team": "player", "w": {}, "skill": 0.0})
	t.ok(man.gassed() and not dog.gassed(), "최루: 인간형만(들개 무시)")
	var pe0 := st.stat("PE")
	c.ord.zones.append({"p": a.loco.logical, "r": 64.0, "t": 0.5, "kind": "gas", "team": "enemy", "w": {}, "skill": 0.0})
	c.tick(DT, true, st)
	t.ok(c.cough_t > 3.9, "주인공 기침")
	t.eq(st.stat("PE"), maxi(1, pe0 - 2), "기침 중 인지력 −2")
	t.near(c.ap.regen_mult, 0.5, 0.001, "AP 회복 −50%")
	c.sprint_want = true
	for i in 6:
		a.mode = "sprint" if c.sprinting else "run"
		a.move(Vector2.RIGHT, DT)
		c.tick(DT, true, st)
	t.ok(not c.sprinting, "기침 중 질주 불가")
	c.sprint_want = false
	for i in 270:                                                           # 지대 0.5초 + 나온 뒤 4초
		c.tick(DT, true, st)
	t.eq(st.stat("PE"), pe0, "4초 뒤 풀린다")
	t.near(c.ap.regen_mult, 1.0, 0.001, "AP 회복 원래대로")
	m.free()
