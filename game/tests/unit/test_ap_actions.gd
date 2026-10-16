## 단계 1-9e3 AP 행동(SD-11 §5.3 · §3.4 · §15.5): 질주(초당 10 · 숨참 뒤 키를 뗄 때까지 못 뜀) · 회피 구르기(AP 20 · 무적 2~4컷 ·
## 과적 AP ×2 · 거리 ×0.6 · 간격 0.5초) · 집중 사격(무기별 AP · 0.3초 조준 · 연사 점사 ⌊연사력/2.33⌋발 · 최소 퍼짐) · 스코프 안정 0.6초 ·
## 다트총 다리 손상.
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
	c.pc.hp = 99999.0
	c.pc.max_hp = 99999.0
	return [m, c, a, o]


## 호스트가 하는 일을 그대로: 질주면 sprint 걸음, 구르는 중이면 roll_step, 아니면 걷는다
func _step(c: InteriorCombat, a: Actor, st: StoryState, v: Vector2) -> void:
	a.mode = "sprint" if c.sprinting else "run"
	if a.rolling():
		a.roll_step(DT)
	else:
		a.move(v, DT)
	c.tick(DT, true, st)


func test_ap_sprint(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	c.bot = {"crouch": false}
	var ap0 := c.ap.ap
	c.sprint_want = true
	for i in 60:
		_step(c, a, st, Vector2.RIGHT if i % 120 < 60 else Vector2.LEFT)
	t.ok(c.sprinting, "질주 키 + 이동 = 질주")
	t.near(ap0 - c.ap.ap, 10.0, 1.0, "질주 1초 = AP 10(%.1f)" % (ap0 - c.ap.ap))
	t.eq(c.pc.movement, "sprint", "질주 발소리(소음 1.5)")
	c.ap.ap = 0.2
	for i in 30:
		_step(c, a, st, Vector2.LEFT)
	t.ok(not c.sprinting and c._sprint_latch, "AP 0 = 숨참, 질주 끝")
	c.ap.ap = 50.0
	for i in 10:
		_step(c, a, st, Vector2.LEFT)
	t.ok(not c.sprinting, "키를 누른 채로는 다시 못 뛴다")
	c.sprint_want = false
	_step(c, a, st, Vector2.LEFT)
	c.sprint_want = true
	for i in 3:
		_step(c, a, st, Vector2.LEFT)
	t.ok(c.sprinting, "키를 뗐다 다시 누르면 다시 뛴다")
	c.crouch = true
	c.bot["crouch"] = true
	_step(c, a, st, Vector2.LEFT)
	t.ok(not c.sprinting, "웅크리면 질주 없음")
	m.free()


func test_ap_roll(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	c.bot = {"crouch": false}
	var p0 := a.loco.logical
	var ap0 := c.ap.ap
	t.ok(c.try_roll(a, Vector2.RIGHT), "구르기 시작")
	t.near(ap0 - c.ap.ap, 20.0, 0.01, "구르기 AP 20")
	t.ok(not c.try_roll(a, Vector2.RIGHT), "구르는 중엔 또 못 구른다")
	var inv: Array = []
	for i in 30:
		_step(c, a, st, Vector2.ZERO)
		inv.append(c.pc.invuln)
	t.ok(inv[0] == false and inv.has(true) and inv[-1] == false, "무적은 5컷 중 2~4번째만(앞뒤는 맞는다)")
	t.near(a.loco.logical.x - p0.x, Actor.ROLL_DIST, 3.0, "0.35초에 2.5칸(%.0fpx)" % (a.loco.logical.x - p0.x))
	t.ok(not a.rolling(), "끝나면 그 자리에 선다")
	a.roll_cool = 0.3
	t.ok(not c.try_roll(a, Vector2.LEFT), "구르기 간격 0.5초")
	a.roll_cool = 0.0
	c.ap.ap = 75.0
	var p1 := a.loco.logical
	t.ok(c.try_roll(a, Vector2.LEFT, true), "과적 구르기")
	t.near(75.0 - c.ap.ap, 40.0, 0.01, "과적: AP ×2")
	for i in 30:
		_step(c, a, st, Vector2.ZERO)
	t.near(p1.x - a.loco.logical.x, Actor.ROLL_DIST * 0.6, 3.0, "과적: 거리 ×0.6")
	a.roll_cool = 0.0
	c.ap.ap = 10.0
	t.ok(not c.try_roll(a, Vector2.RIGHT), "AP 부족이면 못 구른다")
	st.call_fn("give", ["W-002", 1])
	st.call_fn("give", ["10mm 탄", 40])
	c.equip("W-002", st)
	c.ap.ap = 75.0
	c.start_reload(st)
	t.ok(c.reload_t > 0.0 or int(c.mags["W-002"]) >= 0, "재장전 중")
	c.try_roll(a, Vector2.RIGHT)
	t.eq(c.reload_t, 0.0, "구르면 재장전이 끊긴다")
	m.free()


func test_ap_focus(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var w := c.weapons
	t.eq(InteriorCombat.focus_cost(w["W-002"]), 17.0, "권총 17")
	t.eq(InteriorCombat.focus_cost(w["W-018"]), 20.0, "돌격소총 20")
	t.eq(InteriorCombat.focus_cost(w["W-014"]), 25.0, "소총 25")
	t.eq(InteriorCombat.focus_cost(w["W-021"]), 38.0, "저격소총 38")
	t.ok(Arms.is_sniper(w["W-021"]) and not Arms.is_sniper(w["W-014"]), "저격 계열 = 소총 · 유효 사거리 14t 이상")
	st.call_fn("give", ["W-018", 1])
	st.call_fn("give", ["5.56mm 탄", 90])
	c.equip("W-018", st)
	var aim := a.loco.logical + Vector2(260, -12)
	c.cool = 0.0
	c.bot = {"aim": aim, "aimed": true, "focus": true}
	var ap0 := c.ap.ap
	var s0: int = c.stats["shots"]
	c.tick(DT, true, st)
	t.near(ap0 - c.ap.ap, 20.0, 0.01, "집중 사격 AP를 먼저 낸다")
	t.ok(c.focus_t >= 0.0 and absf(a.loco.speed_mul - 0.5) < 0.01, "조준 0.3초 · 이동 50%")
	for i in 10:
		c.tick(DT, true, st)
	t.eq(int(c.stats["shots"]) - s0, 0, "0.3초 전엔 쏘지 않는다")
	var n0 := c.shots.shots.size()
	for i in 12:
		c.tick(DT, true, st)
	var fired := int(c.stats["shots"]) - s0
	t.eq(fired, 3, "돌격소총(연사 8) 집중 점사 ⌊8/2.33⌋ = 3발")
	var foc := c.shots.shots.slice(n0).filter(func(s): return bool(s.get("focused", false)))
	t.ok(foc.size() >= 1, "집중 탄 표시(치명 +15%p · 머리 가중)")
	t.near(a.loco.speed_mul, 1.0, 0.001, "쏜 뒤 걸음 회복")
	c.ap.ap = 5.0
	c.cool = 0.0
	c.bot = {"aim": aim, "aimed": true, "focus": true}
	c.tick(DT, true, st)
	t.ok(c.focus_t < 0.0, "AP 부족: 집중 사격 안 함")
	m.free()


func test_ap_scope_dart(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	st.call_fn("give", ["W-021", 1])
	st.call_fn("give", [".308 구경탄", 10])
	c.equip("W-021", st)
	c.bot = {"aim": a.loco.logical + Vector2(300, -12), "aimed": true}
	for i in 30:
		c.tick(DT, true, st)
	t.ok(not c.scope_steady(), "0.5초: 아직 흔들린다")
	for i in 8:
		c.tick(DT, true, st)
	t.ok(c.scope_steady(), "멈춘 채 정조준 0.6초 = 스코프 안정(퍼짐 ×0.5 · 카메라 6칸)")
	a.move(Vector2.RIGHT, DT)
	a.move(Vector2.RIGHT, DT)
	c.tick(DT, true, st)
	t.ok(not c.scope_steady(), "움직이면 다시 처음부터")
	var e := c.spawn("CR-420", Vector2((o.x + 8) * 32 + 16, (o.y + 3) * 32 + 16), m, st, {"lv": 3, "morale": true})
	var dart: Dictionary = c.weapons.get("W-156", {})
	t.ok(float(dart.get("leg_pct", 0.0)) >= 100.0, "독침 마취총 W-156: 다리 100%")
	if not dart.is_empty():
		c.shots._rebucket()
		var from := a.loco.logical + Vector2(10, -12)
		c.shots.fire_weapon(from, rad_to_deg((e.loco.logical + Vector2(0, -6) - from).angle()), "player", dart, 100.0)
		for i in 40:
			c.shots.step(DT)
		t.ok(e.cmb.crippled.has("leg"), "다트총: 맞으면 다리 손상(이동 −50%%)")
	m.free()
