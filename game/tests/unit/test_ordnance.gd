## 단계 1-9b 투척·설치(SD-11 §3.4 · §9.2 · SD-13 §3.8.4): 투척물 자료 · 수류탄 신관 2.5초 · 착지 산포 · 벽 튕김 · 화염병 불 지대 ·
## 연막(안에서 보이지 않음) · 최루(명중 −30%) · 지뢰 1초 활성 · 감지 1.2t · 경보(주인공 빠름 · 적 느림) · 설치자 편은 밟아도 안 터짐 ·
## 해체 1초 · 연쇄 폭발 0.2초 · 펄스 = 로봇 큰 피해 + 정지 · 주인공 던지기(누른 시간 → 거리 · 소지품에서 하나 줄어든다).
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	return st


func _inputs() -> void:
	if not InputMap.has_action("fire"):
		var setup: Node = load("res://systems/input/input_setup.gd").new()
		setup._ready()
		setup.free()


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


func _setup(st: StoryState, w := 12, h := 5) -> Array:
	_inputs()
	var m := InteriorMap.new()
	m.load_map("D-02", st)
	var o := _open(m, w, h)
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	a.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), Vector2(o.x * 32 + 16, (o.y + h / 2) * 32 + 16), m)
	m.add_actor(a)
	c.on_map(m, a, st)
	for e in c.enemies.duplicate():
		c.drop_enemy(e)
	return [m, c, a]


func _dummy(c: InteriorCombat, m: InteriorMap, st: StoryState, at: Vector2, hp := 1000.0) -> Enemy:
	var e := c.spawn("CR-420", at, m, st, {"lv": 3})
	e.cmb.hp = hp
	e.cmb.max_hp = hp
	e.cmb.dr = 0.0
	return e


func _run(c: InteriorCombat, st: StoryState, secs: float) -> void:
	for i in int(secs * 60.0):
		for e in c.enemies:
			if is_instance_valid(e):
				e._cool = 99.0
				e._t_tac = -99.0
				e._move = Vector2.ZERO
		c.tick(1.0 / 60.0, true, st)


func test_ord_data(t) -> void:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/throwables.json"))
	t.eq(d.size(), 8, "투척·설치 8종(W-057~W-064)")
	t.eq(str(d["W-060"]["kind"]), "thrown", "파편 수류탄 = 투척")
	t.eq(float(d["W-060"]["blast"]), 100.0, "폭발 100")
	t.eq(float(d["W-060"]["fuse"]), 2.5, "신관 2.5초")
	t.eq(str(d["W-063"]["kind"]), "mine", "파편 지뢰 = 설치")
	t.eq(float(d["W-063"]["arm_s"]), 1.0, "설치 1초 뒤 활성")
	t.eq(str(d["W-057"]["zone"]), "fire", "화염병 = 불 지대")
	t.eq([float(d["W-057"]["zone_r"]), float(d["W-057"]["zone_s"])], [2.0, 5.0], "불 지대 2t · 5초")
	t.eq([str(d["W-058"]["zone"]), float(d["W-058"]["zone_r"]), float(d["W-058"]["zone_s"])], ["gas", 3.0, 8.0], "최루 3t · 8초")
	t.eq([str(d["W-059"]["zone"]), float(d["W-059"]["zone_r"]), float(d["W-059"]["zone_s"])], ["smoke", 4.0, 10.0], "연막 4t · 10초")
	t.eq(str(d["W-061"]["blast_kind"]), "emp", "펄스 = EMP")
	var cr: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items_craft.json"))
	t.eq(float(cr["W-151"]["blast"]), 500.0, "병뚜껑 지뢰 폭발 500(제작)")
	t.eq(str(cr["W-151"]["kind"]), "mine", "병뚜껑 지뢰 = 설치")


func test_ord_grenade(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var e := _dummy(c, m, st, a.loco.logical + Vector2(5 * 32, 0))
	var w: Dictionary = c.weapons["W-060"]
	var n := c.ord.throw(a.loco.logical, e.loco.logical, w, "player", 50.0, 6.0)
	t.ok((n["to"] as Vector2).distance_to(e.loco.logical) <= 1.0 * 32.0 + 1.0, "착지 산포 반경 1.5 − 50/100 = 1.0t 안")
	_run(c, st, 2.3)
	t.eq(e.cmb.hp, 1000.0, "신관 2.5초 전에는 터지지 않는다")
	_run(c, st, 0.4)
	t.ok(e.cmb.hp < 1000.0, "2.5초에 터진다(피해 %.0f)" % (1000.0 - e.cmb.hp))
	t.ok(c.ord.nades.is_empty(), "터진 수류탄은 사라진다")
	m.free()


func test_ord_bounce(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var wall := Vector2i(-1, -1)                                          # 오른쪽으로 가장 가까운 벽
	var tp := m.tile_of(a.loco.logical)
	for dx in range(1, 40):
		if m.is_solid(tp + Vector2i(dx, 0)):
			wall = tp + Vector2i(dx, 0)
			break
	t.ok(wall.x > 0, "오른쪽에 벽이 있다")
	var aim := Vector2(wall.x * 32 + 16 + 64, a.loco.logical.y)
	var path: Array = c.ord._bounce(a.loco.logical, aim)
	t.ok((path[0] as Vector2).x < wall.x * 32, "벽 앞에서 멈춘다")
	t.ok((path[1] as Vector2).x <= (path[0] as Vector2).x, "벽에 한 번 튕겨 되돌아온다")
	m.free()


func test_ord_zones(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var e := _dummy(c, m, st, a.loco.logical + Vector2(4 * 32, 0))
	c.ord.throw(a.loco.logical, e.loco.logical, c.weapons["W-057"], "player", 100.0, 6.0)
	_run(c, st, 1.5)
	t.eq(c.ord.zones.size(), 1, "화염병 → 불 지대")
	t.ok(e.cmb.hp < 1000.0 and e.cmb.dots.has("burn"), "불 위의 대상은 탄다(%.0f)" % (1000.0 - e.cmb.hp))
	_run(c, st, 4.2)
	t.ok(c.ord.zones.is_empty(), "착탄 5초 뒤 꺼진다")
	c.ord.throw(a.loco.logical, e.loco.logical, c.weapons["W-059"], "player", 100.0, 6.0)
	_run(c, st, 0.7)
	t.ok(c.ord.in_zone(e.loco.logical, "smoke"), "연막 안")
	t.eq(e.sight_of(c.pc), 0.0, "연막 안의 대상은 밖을 보지 못한다")
	m.free()


func test_ord_mines(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var mn := c.ord.place(a.loco.logical, Vector2.RIGHT, c.weapons["W-063"], "player", 40.0)
	t.near((mn["p"] as Vector2).distance_to(a.loco.logical), 0.8 * 32.0, 0.5, "발밑 0.8t 앞에 놓는다")
	_run(c, st, 1.5)
	t.eq(c.ord.mines.size(), 1, "설치자는 밟아도 터지지 않는다")
	var e := _dummy(c, m, st, (mn["p"] as Vector2) + Vector2(3 * 32, 0))
	_run(c, st, 0.2)
	t.ok(float(c.ord.mines[0]["alarm"]) < 0.0, "1.2t 밖은 조용")
	e.loco.place((mn["p"] as Vector2) + Vector2(20, 0))
	_run(c, st, 1.0 / 60.0)
	t.near(float(c.ord.mines[0]["alarm"]) + 1.0 / 60.0, 0.8 * (1.0 - 40.0 / 200.0), 0.02, "주인공 지뢰 경보 0.8 × (1 − 폭발물/200)")
	_run(c, st, 0.8)
	t.ok(c.ord.mines.is_empty() and e.cmb.hp < 1000.0, "경보 뒤 폭발(피해 %.0f)" % (1000.0 - e.cmb.hp))
	var m1 := c.ord.lay(a.loco.logical + Vector2(6 * 32, 64), c.weapons["W-063"])
	var m2 := c.ord.lay(a.loco.logical + Vector2(7 * 32, 64), c.weapons["W-063"])
	c.ord._boom(m1["p"], c.weapons["W-063"], 30.0, "enemy")
	c.ord.mines.erase(m1)
	t.near(float(m2["chain"]), 0.2, 0.001, "외부 반경 안 지뢰는 0.2초 뒤 유폭")
	_run(c, st, 0.3)
	t.ok(c.ord.mines.is_empty(), "연쇄 폭발")
	var m3 := c.ord.lay(a.loco.logical + Vector2(20, 0), c.weapons["W-063"])
	m3["alarm"] = -1.0
	t.eq(c.ord.disarm_step(m3, 0.5, 10.0), "skill", "폭발물 15 미만이면 해체 못 한다")
	t.eq(c.ord.disarm_step(m3, 0.5, 20.0), "busy", "해체 중")
	t.eq(c.ord.disarm_step(m3, 0.6, 20.0), "done", "1초에 해체")
	m.free()


func test_ord_pulse(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var e := _dummy(c, m, st, a.loco.logical + Vector2(4 * 32, 0))
	var bot := _dummy(c, m, st, a.loco.logical + Vector2(4 * 32, 40))
	bot.cmb.robot = true
	c.shots._rebucket()
	c.ord._boom(e.loco.logical, c.weapons["W-061"], 50.0, "player")
	t.ok(1000.0 - bot.cmb.hp > (1000.0 - e.cmb.hp) * 10.0, "펄스: 로봇 피해 %.0f ≫ 사람 %.0f" % [1000.0 - bot.cmb.hp, 1000.0 - e.cmb.hp])
	t.ok(bot.cmb.held_by("stun"), "로봇 정지")
	m.free()


func test_ord_player_throw(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	st.call_fn("give", ["W-060", 2])
	c.equip("W-060", st)
	t.ok(c.armed() and Arms.fam(c.weapon()) == "thrown", "수류탄을 손에 든다")
	t.eq(a.doll.look["weapon"], "grenade", "투척 손 그림")
	c.bot = {"aim": a.loco.logical + Vector2(4 * 32, 0), "throw": 1.2}
	c.tick(1.0 / 60.0, true, st)
	t.eq(c.ord.nades.size(), 1, "던졌다")
	t.eq(int(st.items.get("W-060", 0)), 1, "소지품에서 하나 줄었다")
	t.eq(c.ord.thrown_total, 1, "투척 1")
	st.call_fn("give", ["W-063", 1])
	c.equip("W-063", st)
	c.bot = {"aim": a.loco.logical + Vector2(64, 0), "fire": true}
	c.cool = 0.0
	c.tick(1.0 / 60.0, true, st)
	t.eq(c.ord.mines.size(), 1, "지뢰를 놓았다")
	t.eq(c.weapon_id, "", "마지막 하나를 쓰면 빈손")
	m.free()
