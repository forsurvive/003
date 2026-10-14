## 단계 0-9 주민 폭행·살인(SD-10 §6.3): 실총으로 죽이면 카르마 −100·st.dead·S7_KILLS, 공기총·근접은 기절(8초 뒤 일어남, 카르마 0),
## 불사 4인은 HP 1에서 무릎, 맞으면 맵 방문마다 한 번 S7_ASSAULT. 적의 탄은 주민을 맞히지 않는다.
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3"]:
		st.quests.set_stage(q, 100)
	st.quests.set_stage("MQ-P4", 40)
	return st


func _world(st: StoryState) -> Array:
	if not InputMap.has_action("fire"):
		var setup: Node = load("res://systems/input/input_setup.gd").new()
		setup._ready()
		setup.free()
	var m := InteriorMap.new()
	m.load_map("V-04", st)
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	a.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), Vector2(31 * 32 + 16, 10 * 32 + 16), m)
	m.add_actor(a)
	c.on_map(m, a, st)
	var host := InteriorHost.new()
	host.st = st
	host.map = m
	host.combat = c
	host.player = a
	host.ev = EventRunner.new()
	c.resident_hit.connect(host._on_resident_hit)
	c.resident_down.connect(host._on_resident_down)
	var npcs: Array = []
	for i in 3:
		var id: String = ["N-R01-024", "N-R01-022", "C-001"][i]
		var na := Actor.new()
		na.setup("st_look_k1_s3_hr00_h1_t01_0_pf11_hd00_ey00", Vector2((26 + i * 2) * 32 + 16, 10 * 32 + 16), m)
		m.add_actor(na)
		m.blockers.append(na)
		npcs.append({"id": id, "actor": na, "routine": null, "bark": ""})
	host.npcs = npcs
	c.set_residents(npcs)
	return [m, c, host]


func test_karma_resident_kill_ko_kneel(t) -> void:
	var st := _state()
	var w := _world(st)
	var c: InteriorCombat = w[1]
	var host: InteriorHost = w[2]
	t.eq(c.residents.size(), 3, "맵 인물이 전투 대상으로 들어간다")
	c.resident("N-R01-024").take({"hp": 100.0}, Vector2.ZERO)                       # 실총
	t.eq(int(st.vars.get_v("V_KARMA")), -100, "악하지 않은 주민을 죽이면 카르마 −100")
	t.ok(st.dead.has("N-R01-024"), "죽은 주민은 기록된다(다시 서지 않는다)")
	t.eq(int(st.vars.get_v("S7_KILLS")), 1, "S7_KILLS")
	t.ok(host.npcs[0].get("dead", false) and not host.map.blockers.has(host.npcs[0]["actor"]), "쓰러진 자리는 막지 않는다")
	c.resident("N-R01-022").take({"hp": 10.0, "nonlethal": true}, Vector2.ZERO)
	t.eq(int(st.vars.get_v("S7_ASSAULT")), 1, "맞으면 폭행 +1(카르마는 그대로)")
	c.resident("N-R01-022").take({"hp": 10.0, "nonlethal": true}, Vector2.ZERO)
	t.eq(int(st.vars.get_v("S7_ASSAULT")), 1, "같은 사람은 방문마다 한 번만 센다")
	c.resident("N-R01-022").take({"hp": 100.0, "nonlethal": true}, Vector2.ZERO)  # 공기총·근접: 기절
	t.eq(int(st.vars.get_v("V_KARMA")), -100, "기절은 카르마 변화 없음")
	t.ok(float(host.npcs[1].get("down_t", 0.0)) > 0.0 and not st.dead.has("N-R01-022"), "기절해 누워 있다")
	host._down_tick(host.npcs[1], 9.0)
	t.ok(not c.resident("N-R01-022").dead and host.npcs[1]["actor"].pose == "stand", "8초 뒤 일어난다")
	c.resident("C-001").take({"hp": 500.0}, Vector2.ZERO)
	t.ok(not c.resident("C-001").dead and c.resident("C-001").hp == 1.0, "불사(윤정인)는 HP 1에서 멈춘다")
	t.eq(str(host.npcs[2].get("down_kind", "")), "kneel", "무릎을 꿇는다")
	t.eq(int(st.vars.get_v("V_KARMA")), -100, "불사는 죽지 않으니 살인 카르마도 없다")
	host.ev.free()
	host.free()
	w[0].free()


func test_karma_enemy_shots_skip_residents(t) -> void:
	var st := _state()
	var w := _world(st)
	var c: InteriorCombat = w[1]
	var host: InteriorHost = w[2]
	c.shots._rebucket()
	var a := Vector2(26 * 32 + 16, 6 * 32)
	var b := Vector2(26 * 32 + 16, 14 * 32)
	t.eq(c.shots._segment_hit(a, b, {"team": "enemy"}), null, "적의 탄은 주민을 지나간다")
	t.eq(c.shots._segment_hit(a, b, {"team": "player"}), c.resident("N-R01-024"), "주인공의 탄은 주민을 맞힌다")
	host.ev.free()
	host.free()
	w[0].free()
