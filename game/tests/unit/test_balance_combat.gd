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
