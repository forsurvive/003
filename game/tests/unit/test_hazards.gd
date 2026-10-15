## 단계 1-9c 함정 · 환경 폭발(SD-11 §9.2 · §9.3): 원자력 차량(누적 피해 50 → 불붙음 4초 → 폭발 · 방사능 지대 · 쏘면 앞당김 · XP 없음) ·
## 드럼(30 → 폭발 + 화상) · 인계철선(수류탄 셋 1초) · 압력판 → 연결된 함정 산탄총 · 덫(다리 · 2초 묶임) · 지향성 지뢰(발견 반경 · 부채꼴) ·
## 자판기(경보 1.5초 → 폭발 + 지뢰) · 택배함(2t) · 가스 누출(탄 → 점화 · 넘어짐) · 폭탄 단말기 · 해체(기술 · 회수) · 다시 열어도 그대로.
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


## traps: 맵 자료에 넣을 함정 줄 · props: [이름, dx, dy] 실행 중 소품(바닥 열린 자리 o 기준)
func _setup(st: StoryState, traps: Array = [], props: Array = []) -> Array:
	_inputs()
	var m := InteriorMap.new()
	m.load_map("D-02", st)
	var o := _open(m, 14, 7)
	for t in traps:
		t["x"] = int(t["x"]) + o.x
		t["y"] = int(t["y"]) + o.y
	m.data["traps"] = traps
	for p in props:
		m.add_runtime_prop(str(p[0]), o + Vector2i(int(p[1]), int(p[2])))
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	a.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), Vector2(o.x * 32 + 16, (o.y + 3) * 32 + 16), m)
	m.add_actor(a)
	c.on_map(m, a, st)
	for e in c.enemies.duplicate():
		c.drop_enemy(e)
	return [m, c, a, o]


func _dummy(c: InteriorCombat, m: InteriorMap, st: StoryState, at: Vector2) -> Enemy:
	var e := c.spawn("CR-420", at, m, st, {"lv": 3})
	e.cmb.hp = 1000.0
	e.cmb.max_hp = 1000.0
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


func _item(c: InteriorCombat, tp: String) -> Dictionary:
	for it in c.hazards.items:
		if it["type"] == tp:
			return it
	return {}


func _at(o: Vector2i, dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func test_hz_car(t) -> void:
	var st := _state()
	var r := _setup(st, [], [["car_wreck", 6, 2], ["drum", 9, 4]])
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var car := _item(c, "car")
	t.ok(not car.is_empty(), "차량 잔해 = 원자력 차량 위험물")
	var e := _dummy(c, m, st, _at(o, 5, 4))
	var xp0 := int(st.vars.get_v("PC_XP"))
	c.shots._rebucket()
	var hp0 := float(car["hp"])
	c.shots.fire_weapon(a.loco.logical + Vector2(10, -12), rad_to_deg(((car["p"] as Vector2) - a.loco.logical).angle()), "player", c.weapons["W-002"], 50.0)
	_run(c, st, 0.3)
	t.ok(float(car["hp"]) < hp0, "쏘면 누적 피해(%.0f → %.0f)" % [hp0, float(car["hp"])])
	c.hazards._damage(car, 60.0, "player")
	t.eq(car["state"], "burning", "50을 넘으면 불붙는다")
	c.hazards._damage(car, 5.0, "player")
	t.near(float(car["burn"]), 3.0, 0.01, "불붙은 차를 쏘면 1초 앞당긴다")
	_run(c, st, 3.1)
	t.eq(car["state"], "done", "폭발")
	t.ok(e.cmb.dead or e.cmb.hp < 1000.0, "옆의 적이 휘말린다")
	t.eq(int(st.vars.get_v("PC_XP")), xp0, "차량 폭발로 죽은 적은 XP가 없다")
	t.ok(c.ord.zones.any(func(z): return z["kind"] == "rad"), "방사능 지대 15초(1-9d가 읽는다)")
	t.eq(str(st.hazards.get(car["key"], "")), "done", "터진 자리를 기억한다")
	var drum: Dictionary = c.hazards.items.filter(func(it): return it["cell"] == o + Vector2i(9, 4))[0]
	t.eq(drum["state"], "done", "연쇄: 외부 반경 4t 안 드럼도 터졌다")
	m.free()
	var r2 := _setup(st, [], [["car_wreck", 6, 2]])
	t.eq(_item(r2[1], "car")["state"], "done", "다시 열어도 터진 차는 그대로")
	(r2[0] as InteriorMap).free()


func test_hz_wire_plate_bear(t) -> void:
	var st := _state()
	var r := _setup(st, [{"type": "wire", "x": 4, "y": 1, "dir": "S", "len": 3, "id": "", "link": "", "cond": ""},
		{"type": "plate", "x": 4, "y": 5, "dir": "E", "len": 1, "id": "", "link": "sg", "cond": ""},
		{"type": "shotgun", "x": 9, "y": 5, "dir": "W", "len": 1, "id": "sg", "link": "", "cond": ""},
		{"type": "bear", "x": 2, "y": 3, "dir": "E", "len": 1, "id": "", "link": "", "cond": ""}])
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var wire := _item(c, "wire")
	t.eq((wire["cells"] as Array).size(), 3, "철선 3칸")
	a.loco.place(_at(o, 4, 2))
	_run(c, st, 1.0 / 60.0)
	t.eq(c.ord.nades.size(), 3, "철선을 건드리면 수류탄 다발 셋")
	_run(c, st, 1.5)
	t.ok(c.ord.nades.is_empty() and c.shots.blasts_total >= 3, "1초 뒤 터진다")
	c.pc.hp = c.pc.max_hp
	var s0 := c.shots.spawned_total
	a.loco.place(_at(o, 4, 5))
	_run(c, st, 1.0 / 60.0)
	t.ok(c.shots.spawned_total - s0 >= 9, "압력판 → 연결된 함정 산탄총 발사(펠릿 %d)" % (c.shots.spawned_total - s0))
	_run(c, st, 0.5)
	c.pc.hp = c.pc.max_hp
	c.pc.holds.clear()
	a.loco.place(_at(o, 2, 3))
	var hp := c.pc.hp
	_run(c, st, 1.0 / 60.0)
	t.ok(c.pc.held_by("root") and c.pc.hp < hp, "덫: 피해 + 2초 묶임")
	t.ok(c.pc.has_meta("leg_hurt"), "다리 부위 손상")
	m.free()


func test_hz_detect_disarm(t) -> void:
	var st := _state()
	var r := _setup(st, [{"type": "claymore", "x": 10, "y": 3, "dir": "W", "len": 2, "id": "", "link": "", "cond": ""},
		{"type": "wire", "x": 1, "y": 5, "dir": "E", "len": 3, "id": "", "link": "", "cond": ""}])
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var cm := _item(c, "claymore")
	_run(c, st, 0.1)
	t.ok(not cm["seen"], "멀리선 지향성 지뢰가 안 보인다")
	a.loco.place(_at(o, 4, 3))                                          # 가장 가까운 철선 칸까지 4t: 인지력 5면 못 보고 7이면 본다
	_run(c, st, 0.1)
	t.ok(not cm["seen"], "4t: 인지력 5로는 못 본다")
	st.vars.set_v("PC_PE", 7)
	_run(c, st, 0.1)
	t.ok(cm["seen"], "인지력 7 이상이면 발견 반경 +1t")
	var wire := _item(c, "wire")
	a.loco.place(_at(o, 1, 4))
	_run(c, st, 0.1)
	c.crouch = true
	t.ok(c.can_disarm_here(), "웅크려 1t 안: 해체할 수 있다")
	st.vars.set_v("PC_SKP_REPAIR", -40)
	st.vars.set_v("PC_SKP_EXPLOSIVES", -40)
	t.eq(c.disarm_tick(0.1, st), "skill", "수리·폭발물 25 미만이면 못 한다")
	st.vars.set_v("PC_SKP_REPAIR", 30)
	for i in 70:
		c.disarm_tick(1.0 / 60.0, st)
	t.eq(wire["state"], "done", "1초에 해체")
	t.eq(int(st.items.get("W-060", 0)), 2, "수류탄 둘 회수")
	t.eq(str(st.hazards.get(wire["key"], "")), "off", "해체한 자리를 기억한다")
	m.free()


func test_hz_props(t) -> void:
	var st := _state()
	var r := _setup(st, [], [["trap_vending", 10, 1], ["trap_parcel", 10, 3], ["gas_pipe", 2, 1]])
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var vd := _item(c, "vending")
	a.loco.place(_at(o, 9, 2))
	_run(c, st, 0.1)
	t.ok(float(vd["beep"]) >= 0.0, "자판기에 다가가면 경보음")
	_run(c, st, 1.6)
	t.eq(vd["state"], "done", "1.5초 뒤 폭발")
	t.ok(not c.ord.mines.is_empty(), "파편 지뢰를 남긴다")
	c.ord.mines.clear()
	c.pc.hp = c.pc.max_hp
	var pr := _item(c, "parcel")
	t.eq(pr["state"], "done", "옆 택배함도 연쇄로 터졌다")
	var gas := _item(c, "gas")
	var e := _dummy(c, m, st, _at(o, 3, 2))
	a.loco.place(_at(o, 2, 5))
	c.shots.fire_weapon(a.loco.logical, -90.0, "player", c.weapons["W-002"], 50.0)
	_run(c, st, 0.3)
	t.eq(gas["state"], "done", "가스 누출 사이로 탄이 지나가면 점화")
	t.ok(e.cmb.held_by("down") or e.cmb.dead, "점화: 넘어짐 2초")
	m.free()


func test_hz_terminal(t) -> void:
	var st := _state()
	var r := _setup(st, [{"type": "terminal", "x": 5, "y": 2, "dir": "E", "len": 1, "id": "", "link": "", "cond": ""}])
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	a.loco.place(_at(o, 5, 3))
	c.shots._rebucket()
	var b0 := c.shots.blasts_total
	t.ok(c.hazards.on_use(Vector2i(o.x + 5, o.y + 2)), "폭탄 단말기: 켜면 터진다")
	t.ok(c.shots.blasts_total > b0 and c.pc.held_by("stun"), "감전 + 폭발")
	t.ok(not c.hazards.on_use(Vector2i(o.x + 5, o.y + 2)), "한 번뿐")
	m.free()
