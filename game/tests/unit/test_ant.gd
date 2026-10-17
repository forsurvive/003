## 단계 1-D5b 왕개미 군체 엔진(AntColony — SD-14 §3.5 · SD-11 §4.8 더듬이 · 1-D 계획 §11.10):
## 냄새 길(맵 지시어) · 일개미가 냄새 칸을 따라 걷기 · 지우면 헤맴 · 여왕 페로몬 위장(줄 위 · 줄 밖 · 내 발자국) · 더듬이 맞대기 판정 ·
## 병정 · 여왕은 알(M-394)을 본다 · 발자국 냄새 20초 · 물에 씻김 · 병정 분사(방어구 −) · 여왕 산성 침 · 알 무더기 줄 · 더듬이 광란(XP는 주인공 몫).
extends RefCounted


func _host(map_id := "KT-01", mark := "from_W") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	st.vars.set_v("KT_CALL", 1)                                           # 벨 연출은 빼고 군체만 본다
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  10:00"
	var c := Kt.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _ants(h: InteriorHost, id := "CR-080") -> Array:
	return h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == id)


func _tc(c: Vector2i) -> Vector2:
	return Vector2(c) * 32.0 + Vector2(16, 16)


func _away(h: InteriorHost) -> void:
	h.player.loco.logical = _tc(Vector2i(3, 20))                          # 개미 눈에 안 띄는 서남쪽 구석


func test_ant_data(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var col: AntColony = h.combat.colony
	t.ok(col.active, "냄새 길이 있는 맵에서 군체가 일한다")
	t.ok(col.cells.size() >= 30, "로비 냄새 칸 %d" % col.cells.size())
	t.ok(col.perm_at(Vector2i(33, 6)) and col.perm_at(Vector2i(25, 10)), "고리 칸이 영구 냄새")
	t.ok(not col.scent_at(Vector2i(22, 5)), "화물 승강기 줄은 전기를 넣어야(KT_POWER 2)")
	for k in col.cells:
		t.ok(not h.map.is_solid(k), "냄새 칸 %s가 바닥" % str(k))
	var st: StoryState = r[1]
	st.vars.set_v("KT_QUEEN", 1)
	h.enter("KT-01", "from_W")
	t.ok(h.combat.colony.cells.is_empty(), "여왕을 처리하면 로비 냄새 길이 없다")


## 일개미는 냄새 칸만 디디며 고리를 돈다(순찰 길이 아니라)
func test_ant_follow(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var col: AntColony = h.combat.colony
	_away(h)
	var e: Enemy = _ants(h)[0]
	var seen := {}
	for i in 40:
		col.tick(0.25)
		if i == 0:
			t.ok(not e.route.is_empty(), "냄새 칸을 고름")
		for p in e.route:
			if not col.scent_at(h.map.tile_of(p[0])):
				t.ok(false, "순찰 점 %s가 냄새 칸 밖" % str(h.map.tile_of(p[0])))
		if not e.route.is_empty():
			e.loco.logical = e.route[-1][0]                              # 다음 점까지 걸었다 치고
			seen[h.map.tile_of(e.loco.logical)] = true
	t.ok(seen.size() >= 4, "냄새 줄을 따라 여러 곳을 지남(%d곳)" % seen.size())


func test_ant_erase(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var col: AntColony = h.combat.colony
	_away(h)
	var e: Enemy = _ants(h)[0]
	col.tick(0.25)
	var at := e.loco.logical
	var n := col.erase_at(at, 1.5)
	t.ok(n >= 3 and not col.scent_at(h.map.tile_of(at)), "물 · 분말 · 불이 냄새 칸을 지운다(%d칸)" % n)
	t.ok(e.route.is_empty() and float(col._a(e)["lost"]) > 0.0, "그 위 일개미가 길을 잃고 헤맨다")
	col.tick(AntColony.LOST_S + 0.5)
	col.tick(0.25)
	col.tick(0.25)
	t.ok(not e.route.is_empty() and col.scent_at(h.map.tile_of(e.route[-1][0])), "헤매다 가까운 냄새 줄을 찾아간다")


## 여왕 페로몬: 줄 위 = 같은 무리(감지 0) · 내 발자국 위 = 정찰 개미(0.15) · 줄 밖 = 의심(0.6) · 병정은 알을 본다
func test_ant_disguise(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var col: AntColony = h.combat.colony
	var e: Enemy = _ants(h)[0]
	var sol := h.combat.spawn("CR-081", _tc(Vector2i(30, 12)), h.map, st, {})
	h.player.loco.logical = _tc(Vector2i(28, 6))
	col.tick(0.25)
	t.ok(e.det_mul >= 0.99, "페로몬 없이는 그대로 본다")
	col.smear()
	t.eq(col.smell(), AntColony.SMELL_MIN, "여왕 페로몬 3시간")
	col.tick(0.25)
	t.ok(e.det_mul == 0.0, "줄 위에 선 나를 같은 무리로 본다")
	t.ok(sol.det_mul >= 0.99, "병정은 냄새로 속지 않는다")
	st.call_fn("give", ["M-394", 1])
	col.tick(0.25)
	t.ok(sol.det_mul == 0.0, "알을 물고 줄 위 — 병정이 일하는 개미로 본다")
	h.player.loco.logical = _tc(Vector2i(10, 15))
	col.tick(0.25)
	t.ok(absf(e.det_mul - 0.15) < 0.01 or absf(e.det_mul - 0.6) < 0.01, "줄 밖은 의심(내 발자국 위면 정찰 개미 판)")
	h.player.loco.logical = _tc(Vector2i(12, 15))
	col.tick(0.25)
	col.tick(0.25)
	t.ok(col.scent_at(Vector2i(12, 15)) and not col.perm_at(Vector2i(12, 15)), "페로몬 바른 발이 냄새 칸을 남긴다")
	t.ok(absf(e.det_mul - 0.15) < 0.01, "내 발자국 위 = 정찰 개미")
	col.tick(AntColony.DRAW_S + 1.0)
	t.ok(not col.scent_at(Vector2i(10, 15)), "발자국 냄새는 20초면 날아간다")
	col.erase_at(h.player.loco.logical, 2.0, true)
	t.eq(col.smell(), 0, "물로 줄을 지우면 내 위장도 씻긴다")


## 더듬이를 맞댄다: 걸으면 그 개미가 돌아서 지나가고 · 뛰면 들킨다
func test_ant_touch(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var col: AntColony = h.combat.colony
	var e: Enemy = _ants(h)[0]
	col.smear()
	h.player.loco.logical = _tc(Vector2i(28, 6))
	e.loco.logical = _tc(Vector2i(29, 6))
	var notes: Array = []
	col.note.connect(func(s: String) -> void: notes.append(s))
	col.tick(0.25)
	t.ok(e.brain.gauge < 50.0 and notes.any(func(s): return s.contains("지나간다")), "걸으면 더듬이만 두드리고 지나간다")
	col._a(e)["touch"] = 0.0
	col._hint_t = 0.0
	h.combat.sprinting = true
	col.tick(0.25)
	h.combat.sprinting = false
	t.ok(e.brain.gauge >= 100.0, "뛰면 더듬이가 낯선 것을 안다")


## 병정 분사: 3칸 안 12 피해 + 방어구 내구도 − · 여왕 산성 침: 8칸 투사체(산)
func test_ant_spray_spit(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var col: AntColony = h.combat.colony
	var sol := h.combat.spawn("CR-081", _tc(Vector2i(20, 14)), h.map, st, {})
	h.player.loco.logical = _tc(Vector2i(22, 14))
	sol.brain.frenzy()
	sol.brain.state = AIBrain.S.COMBAT
	sol.focus = h.combat.pc
	var hits := [0]
	col.corrode.connect(func() -> void: hits[0] += 1)
	var hp0 := h.combat.pc.hp
	col._a(sol)["cd"] = 0.0
	col._cast_step(sol, col._a(sol), 0.1)
	t.ok(absf(hp0 - h.combat.pc.hp - AntColony.SPRAY_DMG) < 0.01, "개미산 분사 12")
	t.eq(hits[0], 1, "방어구 내구도 −(옷이 녹는다)")
	t.ok(sol.pose == "spray" and sol.cmb.held(), "서서 꽁무니를 말아 뿜는다")
	var q := h.combat.spawn("CR-082", _tc(Vector2i(16, 14)), h.map, st, {})
	h.player.loco.logical = _tc(Vector2i(22, 14))
	q.brain.state = AIBrain.S.COMBAT
	q.focus = h.combat.pc
	var n0 := h.combat.shots.shots.size()
	col._a(q)["cd"] = 0.0
	col._cast_step(q, col._a(q), 0.1)
	t.ok(h.combat.shots.shots.size() == n0 + 1 and str(h.combat.shots.shots[-1]["proj"]) == "acid", "여왕 산성 침(투사체)")
	t.eq(float(h.combat.shots.shots[-1]["weapon"]["dmg"]), AntColony.SPIT_DMG, "산성 침 40")


## 더듬이 손상 → 8초 광란(제 무리를 문다) · 광란 개미가 쓰러뜨린 개미의 XP는 주인공 몫
func test_ant_frenzy(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var col: AntColony = h.combat.colony
	var a: Array = _ants(h)
	var e: Enemy = a[0]
	t.ok(e.cmb.weights.has("antenna"), "왕개미 부위에 더듬이(가중치 10)")
	e.cmb._limb_hit("antenna", 1000.0)
	t.ok(e.cmb.crippled.has("antenna"), "더듬이 부위 손상")
	col.tick(0.1)
	t.ok(e.cmb.team == "frenzy" and "ants" in e.foes and e.brain.state == AIBrain.S.FRENZY, "광란 — 제 무리를 노린다")
	var xp0 := int(st.vars.get_v("PC_XP"))
	var o: Enemy = a[1]
	o.cmb.last_by = "frenzy"
	o.cmb.take({"hp": 999.0}, e.loco.logical)
	t.ok(int(st.vars.get_v("PC_XP")) > xp0, "광란 개미가 문 개미의 XP는 주인공 몫")
	col.tick(AntColony.FRENZY_S + 0.1)
	t.ok(e.cmb.team == "ants" and "player" in e.foes, "8초 뒤 광란이 풀린다")


func test_ant_lure(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var col: AntColony = h.combat.colony
	_away(h)
	var e: Enemy = _ants(h)[0]
	col.lure(e, _tc(Vector2i(15, 20)), 5.0)
	col.tick(0.25)
	t.ok(e.route.size() == 1 and h.map.tile_of(e.route[0][0]) == Vector2i(15, 20), "다른 동사가 데려가는 동안 냄새 길을 따르지 않는다")
	col.tick(5.5)
	col.tick(0.25)
	col.tick(0.25)
	t.ok(not e.route.is_empty() and col.scent_at(h.map.tile_of(e.route[-1][0])), "그 뒤 냄새 줄로 돌아간다")


## 낯선 냄새: 행렬이 사람 무리(관측조)와 붙으면 서로 적 — 끌고 가면 싸움이 붙는다
func test_ant_strangers(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var col: AntColony = h.combat.colony
	_away(h)
	var e: Enemy = _ants(h)[0]
	t.eq(e.cmb.team, "ants", "개미는 제 편")
	var g := h.combat.spawn("CR-401", e.loco.logical + Vector2(30, 0), h.map, st, {})
	col.tick(0.25)
	t.ok(g.cmb.team in e.foes and "ants" in g.foes, "군화 냄새 — 서로 노린다")

