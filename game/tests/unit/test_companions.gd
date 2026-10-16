## 단계 1-10a 일시 동행 v2(SD-11 §8.2 · §8.4 · SD-12 §11.4): HP 레벨 비례 · 따라오기 · 엄호 표적 순서 · 기절(표적에서 빠짐) · 전투 뒤 일어남 ·
## 일으키기(2초 + 스팀팩) · 자기 스팀팩 1회 · 동행이 쓰러뜨린 적의 XP(주인공 30%) · 주인공 폭발 ×0.5 · 대기 모드 · 맵 넘김(기다리는 동행은 남음) · 백구 노려보기.
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
	c._st_ref = st
	for e in c.enemies.duplicate():
		c.drop_enemy(e)
	c.pc.hp = 9999.0
	c.pc.max_hp = 9999.0
	return [m, c, a, o]


func _at(o: Vector2i, dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _mate(c: InteriorCombat, m: InteriorMap, id: String, sheet: String, at: Vector2) -> Dictionary:
	var b := Actor.new()
	b.setup(sheet, at, m)
	m.add_actor(b)
	return c.mates.add(id, b, id)


func _foe(c: InteriorCombat, m: InteriorMap, st: StoryState, id: String, at: Vector2) -> Enemy:
	var e := c.spawn(id, at, m, st, {"lv": 3})
	e.brain.state = AIBrain.S.COMBAT
	e.brain.gauge = 100.0
	e._cool = 999.0
	return e


func _run(c: InteriorCombat, st: StoryState, secs: float, hold: Array = []) -> void:
	for i in int(secs * 60.0):
		for e in hold:
			if is_instance_valid(e):
				e._cool = 999.0
				e._t_tac = -99.0
				e._move = Vector2.ZERO
				e._path = PackedVector2Array()
		c.tick(DT, true, st)


func test_mate_follow_scale(t) -> void:
	var st := _state()
	st.vars.set_v("PC_XP", 1700)                                         # 레벨 5
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var mt := _mate(c, m, "C-018", "en_cr457_loco", _at(o, 1, 3))
	t.near((mt["cmb"] as Combatant).max_hp, roundf(120.0 * 1.24), 0.5, "HP = 기본 120 × (1 + 0.06 × 4) — 레벨 5")
	t.eq(str(mt["w"].get("id", "")), "W-049", "박춘삼: 소방 도끼(퀘스트 자료 고정)")
	t.ok(c.buddy == mt["actor"], "옛 이름 buddy = 첫 동행")
	t.ok(c.shots.combatants.has(mt["cmb"]), "탄 판정 목록에 든다")
	a.loco.place(_at(o, 11, 3))
	_run(c, st, 3.0)
	var d: float = (mt["actor"] as Actor).loco.logical.distance_to(a.loco.logical)
	t.ok(d <= Companions.FOLLOW_FAR + 8.0, "따라온다(%.0fpx)" % d)
	c.mates.set_mode("C-018", "wait")
	var home: Vector2 = mt["home"]
	a.loco.place(_at(o, 1, 3))
	_run(c, st, 2.0)
	t.ok((mt["actor"] as Actor).loco.logical.distance_to(home) <= 12.0, "기다려: 그 자리에 선다")
	var b2 := _mate(c, m, "C-002", "np_c_002_loco" if ResourceLoader.exists("res://assets/sprites/np_c_002_loco.tres") else "en_cr457_loco", _at(o, 2, 4))
	t.eq(c.mates.list.size(), 2, "동행 둘")
	var b3 := _mate(c, m, "C-015", "cr_baekgu_loco", _at(o, 3, 4))
	t.ok(b3.is_empty() and c.mates.list.size() == 2, "동시 동행 상한 2명")
	var go := c.mates.leaving("D-02")
	t.ok(go.size() == 1 and str(go[0]["id"]) == "C-002", "맵을 넘을 때 따라오는 동행만 데려간다")
	t.ok(c.mates.away.has("C-018") and str(c.mates.away["C-018"]["map"]) == "D-02", "기다리는 동행은 그 맵에 남는다")
	m.free()


func test_mate_fight_ko(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var mt := _mate(c, m, "C-018", "en_cr457_loco", _at(o, 2, 3))
	var e1 := _foe(c, m, st, "CR-420", _at(o, 6, 1))
	var e2 := _foe(c, m, st, "CR-420", _at(o, 6, 5))
	e1.cmb.hp = 999.0
	e2.cmb.hp = 999.0
	e2.cmb.last_by = "player"
	e2.cmb.take({"hp": 1.0}, a.loco.logical)
	t.ok(c.pc_target == e2, "주인공이 공격한 적 = 엄호 첫 표적")
	t.ok(c.mates._target(mt) == e2, "동행도 그 적을 노린다")
	var h0 := e2.cmb.hp
	_run(c, st, 3.0, [e1, e2])
	t.ok(e2.cmb.hp < h0 and e2.cmb.last_by == "mate", "붙어서 친다(%.0f → %.0f)" % [h0, e2.cmb.hp])
	var cmb: Combatant = mt["cmb"]
	cmb.last_by = "enemy"
	cmb.take({"hp": 9999.0}, e1.loco.logical)
	t.ok(mt["down"] and cmb.hp >= 1.0 and not cmb.dead, "HP 0 → 기절(죽지 않는다)")
	t.ok(not c.mates.bodies().has(cmb) and not c.shots.combatants.has(cmb), "쓰러진 동행은 표적에서 빠진다")
	t.ok(c._target_for(e1) == c.pc, "적은 주인공을 노린다")
	a.loco.place((mt["actor"] as Actor).loco.logical + Vector2(-20, 0))
	t.eq(c.mates.revive_tick(a.loco.logical, 0.1, st), "no_stim", "스팀팩이 없으면 못 일으킨다")
	st.call_fn("give", [InteriorCombat.STIMPAK, 2])
	var res := ""
	for i in 130:
		res = c.mates.revive_tick(a.loco.logical, DT, st)
		if res == "done":
			break
	t.eq(res, "done", "2초 누르면 일어난다")
	t.ok(not mt["down"] and absf(cmb.hp - roundf(cmb.max_hp * 0.3)) <= 1.0, "HP 30%로")
	t.eq(int(st.items.get(InteriorCombat.STIMPAK, 0)), 1, "스팀팩 1개 소모")
	c.mates.fight = true
	cmb.hp = cmb.max_hp * 0.3
	_run(c, st, 0.1, [e1, e2])
	t.ok(mt["stim"] and cmb.hp > cmb.max_hp * 0.6, "HP 35%% 이하 → 자기 스팀팩(%.0f)" % cmb.hp)
	var h1 := cmb.hp
	cmb.hp = cmb.max_hp * 0.2
	_run(c, st, 0.6, [e1, e2])
	t.ok(cmb.hp < cmb.max_hp * 0.35, "스팀팩은 전투마다 한 번")
	cmb.take({"hp": 9999.0}, e1.loco.logical)
	c.drop_enemy(e1)
	c.drop_enemy(e2)
	_run(c, st, 2.5)
	t.ok(not mt["down"] and cmb.hp >= roundf(cmb.max_hp * 0.3) - 1.0, "전투가 끝나면 HP 30%로 일어난다")
	t.ok(not mt["stim"], "다음 전투엔 스팀팩 다시")
	m.free()


func test_mate_xp_blast(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var mt := _mate(c, m, "C-018", "en_cr457_loco", _at(o, 6, 3))
	var e := _foe(c, m, st, "CR-420", _at(o, 9, 3))
	var xp0 := int(st.vars.get_v("PC_XP"))
	e.cmb.last_by = "mate"
	e.cmb.take({"hp": 9999.0}, a.loco.logical)
	t.eq(int(st.vars.get_v("PC_XP")), xp0, "동행 혼자 쓰러뜨린 적: XP 없음")
	var e2 := _foe(c, m, st, "CR-420", _at(o, 9, 5))
	e2.cmb.last_by = "player"
	e2.cmb.take({"hp": e2.cmb.max_hp * 0.35}, a.loco.logical)
	e2.cmb.last_by = "mate"
	e2.cmb.take({"hp": 9999.0}, a.loco.logical)
	t.ok(int(st.vars.get_v("PC_XP")) > xp0, "주인공이 30%% 넘게 깎았으면 XP(%d)" % (int(st.vars.get_v("PC_XP")) - xp0))
	var cmb: Combatant = mt["cmb"]
	var dummy := _foe(c, m, st, "CR-420", (mt["actor"] as Actor).loco.logical + Vector2(0, 64))
	dummy.cmb.hp = 9999.0
	dummy.cmb.dr = 0.0
	var h0 := cmb.hp
	var d0 := dummy.cmb.hp
	c.shots._rebucket()
	c.shots.explode((mt["actor"] as Actor).loco.logical + Vector2(0, 20), c.weapons["W-060"] if c.weapons.has("W-060") else {"blast": 40.0, "proj": "grenade"}, 30.0, "player")
	var hurt_mate := h0 - cmb.hp
	var hurt_foe := d0 - dummy.cmb.hp
	t.ok(hurt_mate > 0.0 and hurt_mate < hurt_foe, "주인공 폭발: 동행은 절반만(%.0f / 적 %.0f)" % [hurt_mate, hurt_foe])
	m.free()


func test_mate_dog_glare(t) -> void:
	var st := _state()
	var r := _setup(st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var o: Vector2i = r[3]
	var mt := _mate(c, m, "C-015", "cr_baekgu_loco", _at(o, 2, 3))
	t.eq(str(mt["style"]), "dog", "백구: 개(물기)")
	var e := c.spawn("CR-420", _at(o, 4, 3), m, st, {"lv": 3})
	e.brain.state = AIBrain.S.IDLE
	c.crouch = true
	c.bot = {"crouch": true}
	_run(c, st, 0.2, [e])
	t.ok(c.mates.glare == e, "은신 동조: 3t 안 숨은 적을 노려본다(위치 표시)")
	t.ok(e.cmb.hp == e.cmb.max_hp, "먼저 물지 않는다")
	m.free()
