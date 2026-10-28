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


func test_balance_mom_chase_and_charge(t) -> void:
	# 1-13k 배수구 어미 ② 바닥 돌진(SD-14 CR-501 · J-10 실전 벤치): 깬 어미는 둥지에 묶이지 않고 쫓아와 문다 · 붉은 직선 경고 뒤 7칸/초 돌진 · 벽에 박으면 비틀거림.
	# 알집바퀴(CR-004)는 둥지 규칙 그대로(2.5칸 밖 표적에게 움직이지 않는다)
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var nest := _spawn(c, m, st, "CR-004", h._at(o, 7, 1), {"lv": 3})
	var n0 := nest.loco.logical
	var mom := _spawn(c, m, st, "CR-501", h._at(o, 12, 5), {"lv": 5})
	t.ok(mom.leash and nest.leash, "처음엔 둘 다 둥지에 묶임(어미는 천장에 붙어 있는 동안)")
	mom.asleep = true                                                  # J-10에선 천장에 잠복(lurk)한 채 선다 — 여기선 깨는 순간만 본다
	mom.wake()
	mom._chg_cd = 99.0                                                 # 먼저 쫓기만 본다
	t.ok(not mom.leash and nest.leash, "깬 어미만 풀린다")
	var d0 := mom.loco.logical.distance_to(c.pc.pos())
	var hp0 := c.pc.hp
	for f in 600:
		c.tick(1.0 / 60.0, true, st)
		if c.pc.hp < hp0:
			break
	t.ok(mom.loco.logical.distance_to(c.pc.pos()) < d0 - 96.0, "깬 어미가 쫓아온다(%.0f → %.0f px)" % [d0, mom.loco.logical.distance_to(c.pc.pos())])
	t.ok(c.pc.hp < hp0, "붙으면 문다(큰 몸도 몸끼리 닿는 거리에서 — 1-13k)")
	t.ok(nest.loco.logical.distance_to(n0) < 20.0, "알집바퀴는 둥지 자리 그대로")
	# 돌진: 5칸 거리 · 시야 — 경고(붉은 원 줄)와 방향 고정 → 달려 닿으면 물기 × 2
	mom.loco.place(c.pc.pos() + Vector2(5 * 32, 0))
	mom._chg_cd = 0.0
	mom._cool = 0.0
	var w0: int = c.ord.warns.size()
	c.pc.hp = c.pc.max_hp
	mom._charge_step(1.0 / 60.0, c.pc)
	t.eq(mom.charges, 1, "돌진 시작")
	t.ok(c.ord.warns.size() >= w0 + 4, "붉은 직선 경고(원 넷)")
	t.ok(mom._chg_dir.dot(Vector2.LEFT) > 0.9, "방향은 표적 쪽으로 고정")
	var hp1 := c.pc.hp
	for f in 120:
		mom._charge_step(1.0 / 60.0, c.pc)
		if c.pc.hp < hp1:
			break
	var dr_k := 1.0 - minf(c.pc.dr, CombatRules.DR_CAP) / 100.0
	t.ok(absf((hp1 - c.pc.hp) - mom.bite * Enemy.CHG_MUL * dr_k) < 0.6, "닿으면 물기 × 2 한 번(%.1f)" % (hp1 - c.pc.hp))
	t.ok(mom._chg_cd >= 7.0 and mom._chg_cd <= 8.0, "맞힌 뒤 다음 돌진 7~8초")
	# 벽: 돌진 줄 앞이 막히면 1.5초 비틀거림 · 다음 돌진은 길게
	var p := mom.loco.logical
	var wall := Vector2.INF
	for k in 40:
		var q := p + Vector2(-k * 16, 0)
		if m.circle_hits(q, mom.radius_px):
			wall = q
			break
	t.ok(wall != Vector2.INF, "왼쪽 벽 찾음")
	mom.loco.place(wall + Vector2(6.0, 0))                               # 한 걸음(8px) 앞이 벽
	mom._chg_dir = Vector2.LEFT
	mom._chg_left = 7.0 * 32.0
	mom._chg_hit = true
	mom._charge_step(1.0 / 60.0, c.pc)
	t.eq([mom.staggers, mom._stag > 1.4, mom._chg_cd >= 8.5], [1, true, true], "벽에 박아 1.5초 비틀거림 · 다음 돌진 8.5초 이상")
	m.free()


func _bite_rate(id: String, n: int, secs: float) -> Array:
	# 주인공은 제자리(피해는 매 프레임 채움) — 무리가 실제 AI로 문 수 · 토큰 없이 문 수 · 초당 물기(첫 물기부터)
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var es: Array = []
	for i in n:
		es.append(_spawn(c, m, st, id, h._at(o, 3 + i % 4, 1 + i / 4 * 4), {"lv": 2}))
	var prev := {}
	var bites := 0
	var free_bites := 0
	var first := -1.0
	for f in int(secs * 60.0):
		c.pc.hp = c.pc.max_hp
		c.tick(1.0 / 60.0, true, st)
		for e in es:
			var k: int = e.get_instance_id()
			var pv: Array = prev.get(k, [0.0, 0.0])
			var hit: bool = (e._cool > pv[0] + 0.2) if e.style != "swarm" else (e._leap > 0.0 and pv[1] <= 0.0)
			if hit:
				bites += 1
				free_bites += 0 if e.has_mtoken else 1
				if first < 0.0:
					first = f / 60.0
			prev[k] = [e._cool, e._leap]
	m.free()
	return [bites, free_bites, bites / maxf(1.0, secs - first)]


func test_balance_token_bite_rate(t) -> void:
	# D-402: 작은 들개가 예비 동작 문턱(멈출 때 걸음 컷만큼 되돌아감)을 오가며 물지 못하던 것 · 큰바퀴 도약이 토큰을 안 따르던 것 ·
	# 물고 빠진 개의 토큰이 쉬는 개로 넘어가도 토큰 자리당 물기가 한 주기 ×1.5 리듬에 가깝다(조율사 1-13h d)
	var want := 2.0 / (1.1 * Enemy.BITE_BACK)                         # 물기 15 이하(들개 Lv2) — 한 주기 1.1초 × 1.5
	var keep: Array = []
	for sh in [0, 1, 3, 6]:                                              # 지그재그 · 맴돌기 위상은 개체 번호를 따른다 — 번호를 밀어 가며(앞 시험에 따라 굳던 자리가 달랐다)
		for i in sh:
			keep.append(RefCounted.new())
		var dogs := _bite_rate("CR-104", 4, 20.0)
		t.ok(dogs[2] >= want * 0.8 and dogs[2] <= want * 1.2, "들개 넷 = 토큰 둘 × 한 주기 1.65초 리듬(번호 +%d: 초당 %.2f · 설계 %.2f)" % [sh, dogs[2], want])
		t.eq(dogs[1], 0, "토큰 없는 개는 물지 않는다")
	var roach := _bite_rate("CR-002", 6, 30.0)
	t.eq(roach[1], 0, "큰바퀴 여섯 — 토큰 없는 둘은 도약하지 않는다(떼 넷)")
	t.ok(roach[0] > 0, "토큰 쥔 바퀴는 도약해 문다(%d번)" % roach[0])


func _nade_taken(dodge: bool) -> float:
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var e := c.spawn("CR-423", h._at(o, 6, 3), m, st, {"lv": 2, "morale": true})   # 길 위 조우 적(수류탄을 쥔다)
	e.brain.state = AIBrain.S.IDLE
	var hp0 := c.pc.hp
	var at := c.pc.pos()
	e.throw_cb.call(e.loco.logical, at)
	for f in int(4.0 * 60.0):
		if dodge and f >= 18:                                            # 0.3초 늦게 알아채고 걸음(초당 3칸)으로 옆으로 비킨다
			var me: Actor = c.pc.actor
			var p: Vector2 = me.loco.logical + Vector2(0, -3.0 * 32.0 / 60.0)
			if p.y > (o.y + 0.5) * 32.0:
				me.loco.place(p)
		c.tick(1.0 / 60.0, true, st)
	var lost := hp0 - c.pc.hp
	m.free()
	return lost


func test_balance_nade_dodge(t) -> void:
	# D-415: 약탈자(근접) 파편 수류탄(폭발 100 · 안쪽 0.8칸 다 받음)은 '피할 수 있는 한 방' — 붉은 원 · 퓨즈 2.5초 · 걸어서 비키면 거의 안 맞는다
	var stay := _nade_taken(false)
	var moved := _nade_taken(true)
	t.ok(stay >= 60.0, "제자리면 크게 맞는다(%.0f)" % stay)
	t.ok(moved <= stay * 0.3, "0.3초 늦게 걸어서 비켜도 거의 안 맞는다(%.0f)" % moved)


func test_enemy_reload(t) -> void:
	# D-416(계획 1-13l · 조율사): 탄창이 비면 다시 겨눔 쉼 대신 재장전 — reload_s × (1.2 − 0.004 × 스킬). 파이프 산탄총(탄창 1)은 한 발마다 틈이 난다 ·
	# 파워 아머 · 감시포 · 보안요원 위협 사격은 끝없이
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var e := _spawn(c, m, st, "CR-421", h._at(o, 6, 3), {"lv": 4})
	e.weapon = c.weapons["W-025"].duplicate()
	e.has_token = true
	var fired := []
	for f in int(12.0 * 60.0):
		var n0 := e.shots_fired
		c.pc.hp = c.pc.max_hp
		e.reload_tick(1.0 / 60.0)                                         # think가 하는 몫(재장전 초)
		e._shoot(1.0 / 60.0, c.pc, c.shots)
		if e.shots_fired > n0:
			fired.append(f / 60.0)
	t.ok(fired.size() >= 2, "파이프 산탄총이 쏜다(%d발)" % fired.size())
	var gap: float = fired[1] - fired[0] if fired.size() >= 2 else 0.0
	var want := 1.0 / (0.6 * 0.6) + 3.0 * (1.2 - 0.004 * e.skill)
	t.ok(absf(gap - want) < 0.2, "한 발 뒤 쿨 + 재장전(%.2f초 · 설계 %.2f)" % [gap, want])
	var p := _spawn(c, m, st, "CR-405", h._at(o, 8, 3), {"lv": 4})
	t.ok(p._inf_ammo(), "파워 아머는 끝없이(못 이기는 적)")
	var g := _spawn(c, m, st, "CR-421", h._at(o, 9, 3), {"lv": 4})
	g.weapon = c.weapons["W-002"].duplicate()
	t.ok(not g._inf_ammo(), "약탈자 권총은 탄창을 쓴다")
	m.free()


func test_enemy_swing_windup(t) -> void:
	# D-417: 사람 근접은 예비 동작(한손 0.2 · 양손 0.3초) 뒤 내려친다 — 방향을 고정해 그 사이 호 밖으로 비키면 헛스윙
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	var e := _spawn(c, m, st, "CR-424", c.pc.pos() + Vector2(30, 0), {"lv": 4, "arm": "melee"})
	e.weapon = c.weapons["W-049"].duplicate()
	e.has_mtoken = true
	t.eq(e._swing_wind(), 0.3, "소방 도끼(양손) 0.3초")
	var hp0 := c.pc.hp
	e._swing(1.0 / 60.0, c.pc)
	t.ok(e._wind > 0.0 and c.pc.hp == hp0, "바로 치지 않는다 — 치켜든다")
	for f in 20:
		e._swing(1.0 / 60.0, c.pc)
	t.ok(c.pc.hp < hp0, "0.3초 뒤 내려친다")
	c.pc.hp = hp0
	e._cool = 0.0
	e._swing(1.0 / 60.0, c.pc)
	var me: Actor = c.pc.actor
	me.loco.place(e.loco.logical + Vector2(0, 40))                       # 치켜든 사이 옆으로 비킴(호 140° 밖 · 닿는 거리 안)
	for f in 20:
		e._swing(1.0 / 60.0, c.pc)
	t.eq(c.pc.hp, hp0, "읽고 비키면 헛스윙")
	e.weapon = c.weapons["W-040"].duplicate()
	t.eq(e._swing_wind(), 0.2, "쇠파이프(한손) 0.2초")
	e._cool = 0.0
	me.loco.place(e.loco.logical + Vector2(-30, 0))
	e._swing(1.0 / 60.0, c.pc)
	t.ok(e._wind > 0.0, "다시 치켜듦")
	e.alt_weapon = e.weapon
	e._main_weapon = c.weapons["W-002"].duplicate()
	e.on_alt = true
	e._arms_tactics(c.pc, 3.0, true)                                     # 표적이 2.6칸 넘게 빠져 총으로 바꿈(조율사 1-13l 구현 뒤 — 예비 동작이 남던 것)
	t.ok(e._wind == 0.0 and e.modulate == Color(1, 1, 1) and e._swing_dir == Vector2.ZERO, "총으로 바꾸면 예비 동작 · 붉은 몸빛이 풀린다")
	m.free()


func test_melee_raider_arms(t) -> void:
	# D-420: 근접 약탈자(CR-423 · 424)는 진행기가 월드에 세워도(morale 없이) 근접 무기 — 권총을 쏘던 것(SD-14 표). 총잡이는 진행기가 다듬은 권총 그대로
	var h = ARMS.new()
	var st: StoryState = h._state()
	var r: Array = h._setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var o: Vector2i = r[3]
	for i in 4:
		var e := c.spawn("CR-424", h._at(o, 2 + i, 1), m, st, {"lv": 4})
		t.ok(str(e.weapon.get("kind", "")) == "melee" and e.style == "melee", "진행기 CR-424 근접(%s)" % str(e.weapon.get("name", "")))
	var b := c.spawn("CR-423", h._at(o, 7, 1), m, st, {"lv": 4})
	t.ok(str(b.weapon.get("kind", "")) == "melee" and b.nades == 0, "진행기 CR-423 근접 · 수류탄은 길 위 조우만")
	var g := c.spawn("CR-420", h._at(o, 8, 1), m, st, {"lv": 4})
	t.eq(str(g.weapon.get("id", "")), "W-002", "진행기 총잡이는 다듬어 둔 권총 그대로")
	m.free()
