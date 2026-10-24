## 밸런스 첫 전수(SD-25 · 조율사 보고 2026-10-23): 손 맵 사람 적 주무기(Lv6 이상 · 셋에 연사 하나) · 스토리 보스 레벨 비례 HP ·
## 이름 있는 사람 하한 · 낮춘 짐승 물기 · 센 물기 예비 동작 · 근접 토큰(무리 둘 · 떼 넷) · 역무원 · 침수 구울 근접.
extends RefCounted

const ARMS := preload("res://tests/unit/test_enemy_arms.gd")


func _spawn(c: InteriorCombat, m: InteriorMap, st: StoryState, id: String, at: Vector2, opts: Dictionary) -> Enemy:
	var o := opts.duplicate()
	o["morale"] = false
	var e := c.spawn(id, at, m, st, o)
	e.brain.state = AIBrain.S.COMBAT
	e.brain.gauge = 100.0
	return e


func test_balance_hand_arms(t) -> void:
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var ws: Array = []
	for i in 6:
		ws.append(str(_spawn(c, m, st, "CR-437", h._at(o, i, 1), {"lv": 8}).weapon.get("id", "")))
	t.eq(ws, ["W-017", "W-004", "W-004", "W-017", "W-004", "W-004"], "인솔조원 Lv8: 셋에 자동소총 하나, 나머지 군용 권총")
	t.eq(str(_spawn(c, m, st, "CR-437", h._at(o, 7, 1), {"lv": 4}).weapon.get("id", "")), "W-002", "Lv5 이하는 10mm 권총 그대로")
	t.eq(str(_spawn(c, m, st, "CR-401", h._at(o, 8, 1), {"lv": 8}).weapon.get("id", "")), "W-002", "진행기 계엄병은 생포 사격 장비 그대로")
	t.eq(str(_spawn(c, m, st, "CR-534", h._at(o, 9, 1), {"lv": 4}).weapon.get("id", "")), "W-002", "MQ-101 독사(lv4)는 권총")
	c.on_map(m, r[2], st)
	for e in c.enemies.duplicate():
		c.drop_enemy(e)
	t.eq(str(_spawn(c, m, st, "CR-437", h._at(o, 1, 1), {"lv": 8}).weapon.get("id", "")), "W-017", "맵에 다시 들어오면 같은 순서 = 같은 무기")
	var g := _spawn(c, m, st, "CR-205", h._at(o, 2, 2), {"lv": 5})
	t.eq([g.style, str(g.weapon.get("name", "")), float(g.weapon.get("dmg", 0))], ["melee", "경광봉", 12.0], "역무원 구울은 경광봉 12(권총을 쏘지 않는다)")
	var w := _spawn(c, m, st, "CR-206", h._at(o, 3, 2), {"lv": 6})
	t.eq([w.style, float(w.weapon.get("dmg", 0))], ["melee", 18.0], "침수 구울은 근접 18")
	m.free()


func test_balance_boss_hp(t) -> void:
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var b := _spawn(c, m, st, "CR-513", h._at(o, 1, 1), {"lv": 12})
	t.eq([b.cmb.max_hp, b.level], [180.0, 12], "황두칠 HP = 60 + Lv × 10(SD-14 §10.2 — 플레이어 비례)")
	var d := _spawn(c, m, st, "CR-534", h._at(o, 2, 1), {"lv": 4})
	t.eq(d.cmb.max_hp, 83.0, "이름 있는 사람을 낮추면 사람 식 × 1.6(52 → 83)")
	var k := _spawn(c, m, st, "CR-130", h._at(o, 3, 1), {"lv": 4})
	t.eq(k.bite, 18.0, "낮춘 메기 새끼는 물기도 반(36 → 18)")
	m.free()


func test_balance_melee_tokens(t) -> void:
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var dogs: Array = []
	for i in 4:
		dogs.append(_spawn(c, m, st, "CR-105", h._at(o, 2 + i, 1), {"lv": 4}))
	var rats: Array = []
	for i in 5:
		rats.append(_spawn(c, m, st, "CR-095", h._at(o, 2 + i, 5), {"lv": 2}))
	c.tick(1.0 / 60.0, true, st)
	t.eq(dogs.filter(func(e): return e.has_mtoken).size(), 2, "들개 무리는 둘만 문다")
	t.eq(rats.filter(func(e): return e.has_mtoken).size(), 4, "시궁쥐 떼는 넷까지")
	m.free()


func test_balance_windup_dash(t) -> void:
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var k := _spawn(c, m, st, "CR-096", h._at(o, 3, 3), {"lv": 5})
	var hp0 := c.pc.hp
	var to := c.pc.pos() - k.loco.logical
	k._bite(0.1, c.pc, to)
	t.ok(k._wind > 0.0 and c.pc.hp == hp0, "첫 물기 전 예비 동작(바로 물지 않는다)")
	t.eq(k.say_text in ["으르렁…", "그르르…", "크르릉…"], true, "센 물기(18)는 으르렁 예고")
	for i in 10:
		k._bite(0.1, c.pc, to)
	t.ok(c.pc.hp < hp0 and k._wind == 0.0, "예비 동작 뒤에 문다")
	var b := _spawn(c, m, st, "CR-513", h._at(o, 6, 3), {"lv": 10})
	var dr0 := b.cmb.dr
	b.start_dash(h._at(o, 10, 3))
	t.eq(b.cmb.dr, dr0 + 25.0, "금고로 뛰는 동안 DR +25")
	b.end_dash()
	t.eq([b.cmb.dr, b.dash_to], [dr0, Vector2.INF], "멈추면 그대로")
	m.free()


func test_balance_dog_no_overlap(t) -> void:
	# 1-13 rq 봇 시간 초과: 토큰 없는 들개가 '반쯤 달려들기'로 주인공 몸에 겹치면(거리 0) 방향이 0이 되어 굳고, 탄은 옆으로 비낀 총구에서 나가 빗나갔다
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var dogs: Array = []
	for i in 4:
		dogs.append(_spawn(c, m, st, "CR-104", c.pc.pos() + Vector2(48, 0).rotated(PI / 2.0 * i), {"lv": 2}))
	c.tick(1.0 / 60.0, true, st)
	var free_dogs := dogs.filter(func(e): return not e.has_mtoken)
	t.eq(free_dogs.size(), 2, "토큰 없는 개 둘")
	var worst := 999.0
	for f in 90:
		for e in free_dogs:                                            # 반쯤 달려들기를 계속 건다(물지 않고 다가오는 몸짓)
			e._circ_v = -0.9
			e._circ_t = 2.5
		c.tick(1.0 / 60.0, true, st)
		for e in free_dogs:
			worst = minf(worst, e.loco.logical.distance_to(c.pc.pos()) - e.cmb.radius - c.pc.radius)
	t.ok(worst > 4.0, "토큰 없는 개는 몸에 겹치지 않는다(가장 가까울 때 %.1f px)" % worst)
	var z := free_dogs[0] as Enemy
	z.loco.logical = c.pc.pos()                                        # 이미 겹친 개는 빠져나온다(방향 0에 굳지 않는다)
	for f in 30:
		c.tick(1.0 / 60.0, true, st)
	t.ok(z.loco.logical.distance_to(c.pc.pos()) > 4.0, "겹친 개가 빠져나온다")
	m.free()


func test_balance_far_dog_closes(t) -> void:
	# 1-13 D-380: 미끼가 없는데도 6칸(BAIT_FIGHT_R) 밖 교전 짐승의 길을 매 프레임 비워 제자리에 굳던 것 — 이제 다가와야 한다
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var dog := _spawn(c, m, st, "CR-104", Vector2((o.x + 11) * 32 + 16, (o.y + 3) * 32 + 16), {"lv": 2})   # 트인 14×7칸 한쪽 끝 — 주인공에서 11칸
	var d0 := dog.loco.logical.distance_to(c.pc.pos())
	for f in 180:
		c.tick(1.0 / 60.0, true, st)
	var d1 := dog.loco.logical.distance_to(c.pc.pos())
	t.ok(d1 < d0 - 64.0, "11칸 밖 교전 들개가 3초에 두 칸 넘게 다가온다(%.0f → %.0f px)" % [d0, d1])
	m.free()


func test_balance_one_phases(t) -> void:
	# 1-13h 외눈 국면(SD-14 §10.3): ① 무리를 먼저 보내고 지켜본다 ② 무리가 절반 이하면 울부짖고 돌진 ③ HP 30%에서 숲으로(다리를 다치면 버틴다) · 무리 절반이 흩어진다
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var one := c.spawn("CR-500", Vector2((o.x + 12) * 32 + 16, (o.y + 3) * 32 + 16), m, st, {"lv": 6})
	one.brain.state = AIBrain.S.COMBAT
	one.brain.gauge = 100.0
	var dogs: Array = []
	for i in 4:
		var dg := c.spawn("CR-104", Vector2((o.x + 12) * 32 + 16, (o.y + 1 + i) * 32 + 16) + Vector2(0, 8), m, st, {"lv": 2})   # 사기 판정 그대로(흩어질 수 있게)
		dg.brain.state = AIBrain.S.COMBAT
		dg.brain.gauge = 100.0
		dogs.append(dg)
	for d in dogs:
		d.cmb.invuln = true                                            # 주인공을 물어도 되지만 이 시험 동안은 무리 수가 그대로
	c.pc.invuln = true
	var p0 := one.loco.logical
	for f in 120:
		c.tick(1.0 / 60.0, true, st)
	t.eq(one.one_phase, 0, "무리가 다 살아 있으면 ① 지켜봄")
	t.ok(one.loco.logical.distance_to(p0) < 12.0, "지켜보는 동안 자리를 지킨다(%.0fpx)" % one.loco.logical.distance_to(p0))
	t.eq(int(c.stats.get("howls", 0)), 0, "① 동안은 울부짖지 않는다")
	for d in dogs.slice(0, 2):
		d.cmb.invuln = false
		d.cmb.hp = 0.0
		d.cmb.dead = true
	for f in 60:
		c.tick(1.0 / 60.0, true, st)
	t.eq(one.one_phase, 1, "무리가 절반이 되면 ②")
	t.ok(int(c.stats.get("howls", 0)) >= 1, "②에 들며 울부짖는다")
	t.ok(dogs[2].buff_t > 0.0, "울부짖기를 받은 들개(물기 +20%)")
	for f in 60:
		c.tick(1.0 / 60.0, true, st)
	t.ok(one.loco.logical.distance_to(c.pc.pos()) < p0.distance_to(c.pc.pos()) - 32.0, "② 돌진(주인공 쪽으로 다가온다)")
	one.cmb.hp = one.cmb.max_hp * 0.25
	for f in 60:
		c.tick(1.0 / 60.0, true, st)
	t.eq(one.one_phase, 2, "HP 30% 이하 = ③")
	t.ok(one.brain.fleeing(), "다리가 멀쩡하면 숲으로 달아난다")
	var fled := dogs.slice(2).filter(func(d): return d.brain.fleeing()).size()
	t.eq(fled, 1, "남은 무리 둘 가운데 절반(하나)이 흩어진다")
	var gone: Enemy = dogs.slice(2).filter(func(d): return d.brain.fleeing())[0]
	t.ok(gone.routed, "흩어진 개 = 끝나는 도주")
	gone.brain._t_state = 999.0                                         # 도주 시간이 다 지나도
	for f in 40:
		c.tick(1.0 / 60.0, true, st)
	t.ok(not is_instance_valid(gone) or gone.brain.fleeing() or gone.has_meta("gone"), "흩어진 개는 다시 덤비지 않는다(멀어지면 빠진다)")
	# 다리를 다친 외눈: 달아나지 못하고 버틴다
	var one2 := c.spawn("CR-500", Vector2((o.x + 10) * 32 + 16, (o.y + 5) * 32 + 16), m, st, {"lv": 6})
	one2.brain.state = AIBrain.S.COMBAT
	one2.brain.gauge = 100.0
	one2.one_phase = 1
	one2.cmb.crippled["leg"] = true
	one2.cmb.hp = one2.cmb.max_hp * 0.25
	for f in 60:
		c.tick(1.0 / 60.0, true, st)
	t.ok(one2.one_phase == 2 and not one2.brain.fleeing(), "다리를 다치면 달아나지 못한다(끝까지 싸운다)")
	m.free()


func test_balance_one_hit_wakes(t) -> void:
	# ①이라도 외눈이 먼저 맞으면 바로 ② — 우두머리를 먼저 노리는 길이 산다
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var one := c.spawn("CR-500", Vector2((o.x + 12) * 32 + 16, (o.y + 3) * 32 + 16), m, st, {"lv": 6})
	one.brain.state = AIBrain.S.COMBAT
	one.brain.gauge = 100.0
	for i in 4:
		_spawn(c, m, st, "CR-104", Vector2((o.x + 12) * 32 + 16, (o.y + 1 + i) * 32 + 16) + Vector2(0, 8), {"lv": 2}).cmb.invuln = true
	c.pc.invuln = true
	for f in 60:
		c.tick(1.0 / 60.0, true, st)
	t.eq(one.one_phase, 0, "맞기 전 ①")
	one.cmb.take({"hp": 10.0}, c.pc.pos())
	for f in 60:
		c.tick(1.0 / 60.0, true, st)
	t.eq(one.one_phase, 1, "외눈이 맞으면 ②(울부짖고 내려온다)")
	m.free()


func test_balance_one_watch_tokens(t) -> void:
	# 1-13h 조율: 외눈 ① 동안 무리 근접 토큰 하나(하나씩 떠본다) · 상처 입고 돌아온 외눈(HP 60%)도 ①부터
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var one := c.spawn("CR-500", Vector2((o.x + 13) * 32 + 16, (o.y + 3) * 32 + 16), m, st, {"lv": 6})
	one.brain.state = AIBrain.S.COMBAT
	one.brain.gauge = 100.0
	one.cmb.hp = one.cmb.max_hp * 0.6
	var dogs: Array = []
	for i in 4:
		var dg := _spawn(c, m, st, "CR-104", Vector2((o.x + 2) * 32 + 16, (o.y + 1 + i) * 32 + 16), {"lv": 2})
		dg.cmb.invuln = true
		dogs.append(dg)
	c.pc.invuln = true
	for f in 120:
		c.tick(1.0 / 60.0, true, st)
	t.eq(one.one_phase, 0, "상처 입은 외눈도 무리가 다 살아 있으면 ①")
	t.eq(dogs.filter(func(d): return d.has_mtoken).size(), 1, "① 동안 무리 근접 토큰 하나")
	one.cmb.take({"hp": 5.0}, c.pc.pos())
	for f in 120:
		c.tick(1.0 / 60.0, true, st)
	t.eq(one.one_phase, 1, "맞으면 ②")
	t.eq(dogs.filter(func(d): return d.has_mtoken).size(), 2, "② 뒤 토큰 둘")
	m.free()
