## 단계 1-9a 무기 계열(SD-11 §3 · §9.2 · §9.6 · SD-13 §3): 계열 → 손 무기 그림·총구 효과·스킬 · 산탄 펠릿 · 레이저 히트스캔 ·
## 화염 입자(대상마다 한 틱 + 화상) · 미사일 폭발(거리 비율 · 엄폐) · 핵 최소 사거리 · 상태 이상(중첩·면역) ·
## 근접 파워 공격(×2 · AP · 넉백) · 프롤로그 근접은 기절, 1막부터 실제 피해 · 맨주먹 · 회전 기관포 예열 · 쌍열 2발.
extends RefCounted


func _state(act1 := true) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	if act1:
		for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
			st.quests.set_stage(q, 100)
		st.vars.set_v("V_ACT", 1)
	else:
		st.quests.set_stage("MQ-P1", 100)
		st.quests.set_stage("MQ-P2", 50)
	return st


func _inputs() -> void:
	if not InputMap.has_action("fire"):
		var setup: Node = load("res://systems/input/input_setup.gd").new()
		setup._ready()
		setup.free()


## 엄폐 없는 빈 바닥 w×h 칸의 왼쪽 위
func _open(m: InteriorMap, w: int, h: int) -> Vector2i:
	for y in range(1, 60):
		for x in range(1, 80):
			var ok := true
			for dy in h:
				for dx in w:
					var t := Vector2i(x + dx, y + dy)
					if m.is_solid(t) or m.cover_at(t) != 0:
						ok = false
						break
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _setup(map_id: String, st: StoryState, w := 10, h := 3) -> Array:
	_inputs()
	var m := InteriorMap.new()
	m.load_map(map_id, st)
	var o := _open(m, w, h)
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	var lk := CharDocs.paperdoll_look(CharDocs.look_of(st))
	a.setup_doll(lk, Vector2(o.x * 32 + 16, (o.y + h / 2) * 32 + 16), m)
	m.add_actor(a)
	c.on_map(m, a, st)
	for e in c.enemies:
		c.drop_enemy(e)
	return [m, c, a, o]


func _dummy(c: InteriorCombat, m: InteriorMap, st: StoryState, at: Vector2, hp := 1000.0) -> Enemy:
	var e := c.spawn("CR-420", at, m, st, {"lv": 3})
	e.cmb.hp = hp
	e.cmb.max_hp = hp
	e.cmb.dr = 0.0
	e.cmb.unaware = Callable()
	return e


func test_arms_family_map(t) -> void:
	var w: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	var want := {"W-001": "pistol", "W-015": "smg", "W-023": "laser", "W-025": "shotgun", "W-030": "flamer", "W-031": "launcher",
		"W-032": "minigun", "W-033": "launcher", "W-034": "minigun", "W-037": "knife", "W-041": "baton", "W-045": "knife",
		"W-047": "bat", "W-049": "sledge", "W-050": "sledge", "W-052": "", "W-056": ""}
	for id in want:
		t.eq(Arms.doll(w[id]), want[id], "%s %s → 손 무기 '%s'" % [id, w[id]["name"], want[id]])
	var pd: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/paperdoll/paperdoll.json"))
	var st := _state()
	var missing: Array = []
	for id in w:
		var d := Arms.doll(w[id])
		if d != "" and not pd["weapons"].has(d):
			missing.append(id)
		if st.skill_key(Arms.skill_name(w[id])) == "":
			missing.append(id + " 스킬")
		var fs := CombatFx.flash_for(w[id])
		if w[id]["kind"] == "ranged" and not CombatFx.has_set(fs):
			missing.append(id + " 총구")
		if w[id]["kind"] == "ranged" and not CombatFx.meta()["sets"].has(Arms.sprite(Arms.proj(w[id]))):
			missing.append(id + " 투사체")
	t.ok(missing.is_empty(), "무기 59종 모두 손 무기 그림 · 스킬 · 총구 효과 · 투사체 그림이 있다 %s" % str(missing))
	t.eq(Arms.pellets(w["W-025"]), 8, "파이프 산탄총 '40 (5×8)' = 펠릿 8")
	t.eq(Arms.pellets(w["W-029"]), 9, "전투 산탄총 펠릿 9")
	t.eq(float(w["W-029"]["falloff_min"]), 0.4, "산탄은 최대 사거리에서 40%")
	t.eq(float(w["W-033"]["blast"]), 150.0, "미사일 폭발 150")
	t.eq(float(w["W-032"]["spinup"]), 0.5, "미니건 예열 0.5초(SD-13)")
	t.eq(int(w["W-027"]["ammo_per_shot"]), 2, "쌍열: 한 번에 2발")
	t.ok(bool(w["W-026"]["no_crit"]), "소드오프: 치명타 불가")
	t.eq(Arms.aim_stance(w["W-032"], true, false), "heavy_aim", "중화기 정조준 = 허리 거치(×0.75)")


func test_arms_pellets(t) -> void:
	var st := _state()
	var r := _setup("D-02", st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var e := _dummy(c, m, st, a.loco.logical + Vector2(64, 0))
	var w: Dictionary = c.weapons["W-029"]
	var n := c.shots.fire_weapon(a.loco.logical + Vector2(10, -12), 0.0, "player", w, 50.0)
	t.eq(n, 9, "전투 산탄총 한 발 = 펠릿 9")
	var dm := float(c.shots.shots[0]["weapon"]["dmg"])
	t.near(dm, 55.0 / 9.0, 0.01, "펠릿 하나 피해 = 합계 55 ÷ 9")
	var spread := 0.0
	for s in c.shots.shots:
		spread = maxf(spread, absf(float(s["ang"])))
	t.ok(spread <= Arms.cone(w) + 1.0, "펠릿은 원뿔 ±%.0f° 안(최대 %.1f°)" % [Arms.cone(w), spread])
	var hp0 := e.cmb.hp
	var p0 := e.loco.logical
	for i in 30:
		c.shots.step(1.0 / 60.0)
		c._status(1.0 / 60.0)
	t.ok(c.shots.hits_total >= 6, "2t 거리에서 펠릿 대부분이 맞는다(%d/9)" % c.shots.hits_total)
	t.ok(hp0 - e.cmb.hp > 20.0, "합계 피해 %.1f" % (hp0 - e.cmb.hp))
	t.ok(e.loco.logical.x > p0.x + 4.0, "3t 안 6발 이상 → 넉백(%.1fpx)" % (e.loco.logical.x - p0.x))
	m.free()


func test_arms_laser(t) -> void:
	var st := _state()
	var r := _setup("D-02", st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var e := _dummy(c, m, st, a.loco.logical + Vector2(6 * 32, 0))
	c.shots._rebucket()
	var hp0 := e.cmb.hp
	var n := c.shots.fire_weapon(a.loco.logical + Vector2(10, -12), 0.0, "player", c.weapons["W-023"], 50.0)
	t.eq(n, 1, "레이저 1발")
	t.ok(e.cmb.hp < hp0, "히트스캔: 쏜 프레임에 맞는다(%.1f)" % (hp0 - e.cmb.hp))
	t.ok(c.shots.shots.is_empty(), "날아가는 탄이 없다")
	t.eq(c.shots.beams.size(), 1, "빔 그림 하나")
	for i in 16:
		c.shots.step(1.0 / 60.0)
	t.ok(c.shots.beams.is_empty(), "빔은 0.1초 + 4컷 뒤 사라진다")
	m.free()


func test_arms_flame(t) -> void:
	var st := _state()
	var r := _setup("D-02", st)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var e1 := _dummy(c, m, st, a.loco.logical + Vector2(48, 0))
	var e2 := _dummy(c, m, st, a.loco.logical + Vector2(88, 0))
	var w: Dictionary = c.weapons["W-030"].duplicate()
	w["cone"] = 0.5                                                      # 시험: 한 줄로
	for k in 4:
		c.shots.fire_weapon(a.loco.logical + Vector2(10, -12), 0.0, "player", w, 50.0)
		for i in 8:
			c.shots.step(1.0 / 60.0)
	for i in 60:
		c.shots.step(1.0 / 60.0)
	t.ok(e1.cmb.hp < 1000.0 and e2.cmb.hp < 1000.0, "화염 입자는 꿰뚫는다 — 앞뒤 둘 다 탄다(%.0f · %.0f)" % [1000.0 - e1.cmb.hp, 1000.0 - e2.cmb.hp])
	t.ok(e1.cmb.dots.has("burn"), "화상 2/초(5초)")
	var per := (1000.0 - e1.cmb.hp) / 4.0
	t.ok(per < 30.0, "입자 하나는 대상마다 한 틱만(입자당 %.1f)" % per)
	var hp := e1.cmb.hp
	for i in 60:
		e1.cmb.tick_status(1.0 / 60.0)
	t.near(hp - e1.cmb.hp, 2.0, 0.01, "화상 1초 = 2")
	m.free()


func test_arms_blast(t) -> void:
	var st := _state()
	var r := _setup("D-02", st, 12, 5)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	var at := a.loco.logical + Vector2(8 * 32, 0)
	var e1 := _dummy(c, m, st, at)
	var e2 := _dummy(c, m, st, at + Vector2(0, 2 * 32))
	var e3 := _dummy(c, m, st, at + Vector2(-6 * 32, 64))
	c.shots._rebucket()
	c.shots.explode(at + Vector2(0, -12), c.weapons["W-033"], 50.0, "player")
	var d1 := 1000.0 - e1.cmb.hp
	var d2 := 1000.0 - e2.cmb.hp
	t.near(d1, 150.0 * 150.0 / 200.0, 1.0, "폭심(내부 반경) = 150 × (100 + 50)/200")
	t.ok(d2 > 10.0 and d2 < d1 * 0.8, "2t 옆은 거리 비율로 준다(%.1f)" % d2)
	t.eq(e3.cmb.hp, 1000.0, "외부 반경 3t 밖은 맞지 않는다")
	t.ok(e1.cmb.held_by("down"), "내부 반경 안은 넘어진다")
	t.eq(c.shots.booms.size(), 1, "폭발 그림 하나")
	t.eq(c.shots.fire_weapon(a.loco.logical, 0.0, "player", c.weapons["W-036"], 50.0, {"target": a.loco.logical + Vector2(3 * 32, 0)}), 0,
		"핵 투사기: 6t 안은 쏘지 않는다")
	var n := c.shots.fire_weapon(a.loco.logical, 0.0, "player", c.weapons["W-033"], 50.0)
	t.eq(n, 1, "미사일 1발")
	var v0 := (c.shots.shots[-1]["v"] as Vector2).length()
	c.shots.step(0.5)
	t.ok((c.shots.shots[-1]["v"] as Vector2).length() > v0 if not c.shots.shots.is_empty() else true, "미사일은 10t/초에서 빨라진다")
	m.free()


func test_arms_status(t) -> void:
	var c := Combatant.new()
	c.hp = 100.0
	c.max_hp = 100.0
	c.add_dot("burn", 2.0, 5.0)
	c.add_dot("burn", 1.0, 3.0)
	t.eq(c.dots["burn"], [2.0, 5.0], "같은 종류는 중첩 없이 큰 세기 · 긴 시간")
	for i in 600:
		c.tick_status(1.0 / 60.0)
	t.near(c.hp, 90.0, 0.01, "화상 2/초 × 5초 = 10")
	t.ok(c.dots.is_empty(), "끝나면 지운다")
	t.ok(c.hold("stun", 1.0), "기절 1초")
	for i in 61:
		c.tick_status(1.0 / 60.0)
	t.ok(not c.held(), "1초 뒤 풀린다")
	t.ok(not c.hold("stun", 1.0), "끝난 뒤 1초는 같은 종류 면역")
	for i in 61:
		c.tick_status(1.0 / 60.0)
	t.ok(c.hold("stun", 1.0), "면역이 끝나면 다시 걸린다")
	c.big = true
	t.ok(not c.hold("down", 1.0), "대형은 넘어지지 않는다")


func _swing(c: InteriorCombat, st: StoryState, e: Enemy, opts: Dictionary) -> float:
	var hp0 := e.cmb.hp
	c.bot = opts.merged({"aim": e.loco.logical + Vector2(0, -6)})
	c.cool = 0.0
	c.tick(1.0 / 60.0, true, st)
	c.bot = {"aim": e.loco.logical + Vector2(0, -6)}
	return hp0 - e.cmb.hp


func test_arms_melee_power(t) -> void:
	var st := _state()
	var r := _setup("D-02", st, 10, 3)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	st.call_fn("give", ["W-047", 1])
	c.equip("W-047", st)
	t.eq(Arms.fam(c.weapon()), "melee2", "야구 방망이 = 양손 근접")
	var e := _dummy(c, m, st, a.loco.logical + Vector2(30, 0))
	c.shots.rng.seed = 7
	var d1 := _swing(c, st, e, {"fire": true})
	t.ok(d1 > 0.0, "일반 휘두르기 %.1f" % d1)
	t.ok(e.cmb.push.length() > 0.0 or e.loco.logical.x > a.loco.logical.x + 30.0, "양손 일반 공격도 0.3t 밀어낸다")
	for i in 20:
		c._status(1.0 / 60.0)
	e.loco.place(a.loco.logical + Vector2(30, 0))
	var ap0 := c.ap.ap
	var d2 := _swing(c, st, e, {"power": true})
	t.ok(d2 > d1 * 1.5, "파워 공격 ≈ ×2 (%.1f → %.1f)" % [d1, d2])
	t.near(ap0 - c.ap.ap, 10.0, 0.01, "AP = 무기 AP ÷ 2, 최소 10")
	t.eq(c.power_hits, 1, "파워 공격 1회")
	t.ok(e.cmb.held_by("stun"), "양손 파워 공격 = 경직")
	e.cmb.hp = 1.0
	e.cmb.holds.clear()
	e.loco.place(a.loco.logical + Vector2(30, 0))
	_swing(c, st, e, {"fire": true})
	t.ok(e.cmb.dead and not e.cmb.ko, "1막부터 근접은 실제 피해(기절이 아니다)")
	m.free()


func test_arms_prologue_melee_stuns(t) -> void:
	var st := _state(false)
	var r := _setup("V-11", st, 6, 3)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	st.call_fn("give", ["W-067", 1])
	c.equip("W-067", st)
	var e := c.spawn("CR-473", a.loco.logical + Vector2(30, 0), m, st, {"arm": "baton"})
	e.cmb.hp = 1.0
	e.cmb.unaware = Callable()
	_swing(c, st, e, {"fire": true})
	t.ok(e.cmb.dead and e.cmb.ko, "프롤로그(볼트 평시) 근접 = 기절(볼트원을 죽이지 않는다)")
	m.free()


func test_arms_fists_and_spin(t) -> void:
	var st := _state()
	var r := _setup("D-02", st, 10, 3)
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var a: Actor = r[2]
	c.equip(Arms.FIST, st)
	t.ok(c.armed() and c.weapon()["kind"] == "unarmed", "빈손 → 주먹(맨주먹 W-052)")
	var e := _dummy(c, m, st, a.loco.logical + Vector2(24, 0))
	t.ok(_swing(c, st, e, {"fire": true}) > 0.0, "주먹이 닿는다")
	c.drop_enemy(e)
	st.call_fn("give", ["W-032", 1])
	st.call_fn("give", ["5mm 탄", 300])
	c.equip("W-032", st)
	c.bot = {"aim": a.loco.logical + Vector2(200, -12), "fire": true}
	var shots0: int = c.stats["shots"]
	for i in 24:                                                       # 0.4초
		c.tick(1.0 / 60.0, true, st)
	t.eq(int(c.stats["shots"]) - shots0, 0, "미니건: 0.5초 예열 전에는 쏘지 않는다")
	for i in 30:
		c.tick(1.0 / 60.0, true, st)
	t.ok(int(c.stats["shots"]) - shots0 >= 5, "예열 뒤 연사(%d발)" % (int(c.stats["shots"]) - shots0))
	t.ok(c.heavy_slow(), "중화기 사격 중엔 정조준 걸음")
	st.call_fn("give", ["W-027", 1])
	st.call_fn("give", ["12게이지 산탄", 10])
	c.equip("W-027", st)
	c.bot = {"aim": a.loco.logical + Vector2(200, -12), "fire": true}
	c.cool = 0.0
	var mag0 := int(c.mags["W-027"])
	c.tick(1.0 / 60.0, true, st)
	t.eq(mag0 - int(c.mags["W-027"]), 2, "쌍열 산탄총은 한 번에 2발")
	m.free()
