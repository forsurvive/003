## 단계 0-9 MQ-P4 개방의 날: 회의·개방식 단계, 거래(전언·덕트·동행), 탈출 장면(무기고·총기·설득·증거·단말·하도윤),
## 보안요원 기절·사살(카르마), 파워 아머 HP 하한, 탐지식의 자세·움직임·은신, 2277 맵 배치(회의·데크·순찰), 방폭문 22컷.
extends RefCounted


func _state(stage := 10) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	CharDocs.write_name(st, "윤", "서진")
	st.vars.set_v("P_REGNO", CharDocs.REGNO)
	for q in ["MQ-P1", "MQ-P2", "MQ-P3"]:
		st.quests.set_stage(q, 100)
	st.quests.set_stage("MQ-P4", stage)
	return st


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 끝까지(또는 선택지까지) 넘기며 연출 명령을 모은다
func _run(dr: DialogueRunner, cur: Dictionary, cmds: Array) -> Dictionary:
	var guard := 0
	while cur["type"] != "choices" and cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			cmds.append(str(cur["name"]) + " " + " ".join(cur["args"].map(func(x): return str(x))))
		cur = dr.advance()
	return cur


func _pick(cur: Dictionary, key: String) -> int:
	for i in cur.get("opts", []).size():
		if str(cur["opts"][i]["text"]).contains(key):
			return i
	return -1


## 장면 하나를 picks(선택지 문장 조각) 차례로 고르며 끝까지. 반환 [명령들, 오류]
func _play(st: StoryState, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cmds: Array = []
	var cur := _run(dr, dr.start(_scene(id), label), cmds)
	for k in picks:
		if cur["type"] != "choices":
			break
		var i := _pick(cur, k)
		if i < 0:
			return [cmds, ["선택지 없음: " + k]]
		cur = _run(dr, dr.choose(i), cmds)
	return [cmds, dr.errors]


func test_p4_meeting_and_ceremony(t) -> void:
	var st := _state(10)
	var r := _play(st, "MQ-P4_S01", ["손을 든다"])
	t.eq(st.quests.stage("MQ-P4"), 20, "회의 → 20(개방식을 지켜본다)")
	t.eq(int(st.vars.get_v("PC_XP")), 20, "회의 XP 20")
	t.ok("pc p4_meet N" in r[0], "주인공을 회의 자리로")
	t.eq(r[1].size(), 0, "실행 오류 없음")
	r = _play(st, "MQ-P4_S02")
	t.eq(st.quests.stage("MQ-P4"), 30, "개방식 → 30(관리동 호출)")
	t.ok("gate open 90" in r[0], "방폭문이 9초에 걸쳐 굴러 열린다")
	t.ok(r[0].filter(func(c): return c.begins_with("show BJ")).size() == 6, "계엄군 보병 6이 걸어 들어온다")
	t.ok("show PA p4_in S en_cr405_loco" in r[0], "파워 아머 1")
	t.ok("wait go" in r[0], "분대가 다 설 때까지 기다린다")


func test_p4_trade_branches(t) -> void:
	var st := _state(30)
	var r := _play(st, "MQ-P4_S03", ["하도윤을 따라간다"])
	t.eq(int(st.vars.get_v("MQP4_FOLLOW")), 1, "은신이 모자라면 바로 전언 → 동행")
	t.ok("buddy C-002" in r[0] and "escape start" in r[0], "일시 동행 · 탈출 시작")
	st = _state(30)
	st.vars.set_v("PC_SKP_SNEAK", 20)
	r = _play(st, "MQ-P4_S03", ["덕트로"])
	t.eq(int(st.vars.get_v("MQP4_DUCT")), 1, "[은신 25] 덕트로 직접 엿듣기")
	t.ok(not ("escape start" in r[0]), "엿듣는 동안은 탈출이 아직 시작되지 않는다")
	r = _play(st, "MQ-P4_S03B")
	t.eq(r[1].size(), 0, "덕트 컷 실행 오류 없음")
	r = _play(st, "MQ-P4_S03", ["혼자"], "DUCT_BACK")
	t.ok("show C-002 p4_dy W" in r[0] and "escape start" in r[0], "A-07로 돌아와 호출까지")
	t.eq(int(st.vars.get_v("MQP4_FOLLOW")), 0, "혼자 간다(하도윤은 갱도 철문 앞에서 기다린다)")


func test_p4_escape_scenes(t) -> void:
	var st := _state(30)
	st.vars.set_v("PC_SKP_LOCKPICK", 20)
	var r := _play(st, "MQ-P4_ARMORY", ["머리핀"])
	t.eq(int(st.vars.get_v("MQP4_ARMORY")), 1, "[자물쇠 따기 25] 무기고")
	t.ok("unlock 22 13" in r[0], "무기고 문(22,13)을 연다")
	t.eq(st.quests.stage("MQ-P4"), 40, "볼트를 빠져나간다")
	_play(st, "MQ-P4_GUNS")
	t.eq([int(st.items.get("W-002", 0)), int(st.items.get("10mm 탄", 0))], [1, 36], "보안부 권총 + 10mm 탄 36")
	st = _state(30)
	st.vars.set_v("MQP4_KEY", 1)
	r = _play(st, "MQ-P4_ARMORY")
	t.eq(int(st.vars.get_v("MQP4_ARMORY")), 1, "열쇠가 있으면 판정 없이")
	# 설득: 증거 두 장이면 화술 없이도
	st = _state(30)
	st.call_fn("give", ["M-203"])
	st.call_fn("give", ["M-229"])
	r = _play(st, "MQ-P4_S04_TALK", ["통지서와 계보"])
	t.eq(int(st.vars.get_v("MQP4_TALK")), 1, "[증거: M-203][증거: M-229] → 설득 성공")
	t.ok("escape yun" in r[0], "설득 → 엄마와 비상 계단으로 정문 구역까지")
	st = _state(30)
	r = _play(st, "MQ-P4_S04_TALK", ["아무 말도"])
	t.eq(int(st.vars.get_v("MQP4_TALK")), 2, "말이 없으면 실패")
	t.ok("escape alarm" in r[0], "엄마가 도경철을 부른다(경보)")
	# 단말: [과학 25]
	st = _state(30)
	st.vars.set_v("PC_SKP_SCIENCE", 20)
	_play(st, "MQ-P4_S05", ["핍-보이를"])
	t.eq([int(st.items.get("M-204", 0)), int(st.items.get("M-229", 0)), int(st.items.get("M-203", 0)), int(st.vars.get_v("K_RALLY"))],
		[1, 1, 1, 1], "기록 사본 · LR-18 메모 · 지정 통지서 · K_RALLY")
	# 하도윤: 배신했던 경우의 대사, 보안 카드
	st = _state(40)
	st.vars.set_v("V_DY_P3", 3)
	r = _play(st, "MQ-P4_DOYUN")
	t.ok("escape doyun" in r[0] and "anim drain_hatch 4 9 16" in r[0], "원형 철문을 돌려 열고 배수 갱도로")
	r = _play(st, "MQ-P4_DECOY")
	t.eq([int(st.items.get("M-205", 0)), int(st.vars.get_v("MQP4_DECOY"))], [1, 1], "검역실: 정비 카드를 받고 하도윤이 미끼가 된다")
	t.ok(r[0].any(func(c): return c.begins_with("refresh")), "데크 분대가 빠진다(적 다시 보기)")
	# 엄마의 거짓 무전
	st = _state(40)
	st.vars.set_v("MQP4_TALK", 1)
	r = _play(st, "MQ-P4_YUN")
	t.eq(int(st.vars.get_v("MQP4_DECOY")), 2, "엄마가 분대를 농장으로 따돌린다")
	t.ok("escape gate" in r[0], "오버시어 열쇠로 방폭문을 연다")
	# 제어실 레버: 카드 · 서랍(소리가 나서 경보)
	st = _state(40)
	st.call_fn("give", ["M-205"])
	r = _play(st, "MQ-P4_LEVER", ["정비 카드"])
	t.ok("escape gate" in r[0] and not ("escape alarm" in r[0]), "정비 카드로 조용히 레버")
	st = _state(40)
	r = _play(st, "MQ-P4_LEVER", ["서랍"])
	t.ok("escape alarm" in r[0] and "escape gate" in r[0], "카드·판정이 없어도 막히지 않는다(서랍의 비상 열쇠, 대신 경보)")
	st = _state(40)
	st.vars.set_v("V_ESCAPE", 2)
	r = _play(st, "MQ-P4_GATEOPEN")
	t.ok("gate open 90" in r[0] and "escape alarm" in r[0], "레버 뒤 방폭문이 굴러 열리고, 은신·전투면 데크가 깨어난다")
	# 도경철 열쇠 슬쩍
	st = _state(30)
	st.vars.set_v("PC_SKP_SNEAK", 20)
	_play(st, "MQ-P4_DO", ["허리춤"])
	t.eq(int(st.vars.get_v("MQP4_KEY")), 1, "[은신 25] 도경철의 무기고 열쇠")


func test_p4_speech_hidden_without_evidence(t) -> void:
	var st := _state(30)
	var dr := DialogueRunner.new(st)
	var cur := _run(dr, dr.start(_scene("MQ-P4_S04_TALK")), [])
	var i := _pick(cur, "통지서와 계보")
	t.ok(i < 0 or not cur["opts"][i]["enabled"], "증거가 없으면 증거 선택지를 고를 수 없다")


## -s 실행에는 자동 로드(InputSetup)가 없다
func _inputs() -> void:
	if not InputMap.has_action("fire"):
		var setup: Node = load("res://systems/input/input_setup.gd").new()
		setup._ready()
		setup.free()


func _combat(map_id: String, st: StoryState, at: Vector2) -> Array:
	_inputs()
	var m := InteriorMap.new()
	m.load_map(map_id, st)
	var c := InteriorCombat.new()
	m.add_child(c)
	var a := Actor.new()
	a.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), at, m)
	m.add_actor(a)
	c.on_map(m, a, st)
	c._rng.seed = 7
	c.shots.rng.seed = 7
	return [m, c, a]


func test_p4_guard_ko_and_kill(t) -> void:
	var st := _state(40)
	var r := _combat("V-09", st, Vector2(12 * 32 + 16, 16 * 32 + 16))
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var g: Enemy = c.enemies.filter(func(e): return e.get_meta("enemy_id") == "CR-473")[0]
	t.eq([g.who, g.arm, g.style, g.route.size()], ["N-R01-018", "baton", "melee", 3], "권서준: 진압봉 · 순찰 3지점")
	t.eq(g.sheet, "en_cr473_baton_loco", "보안요원 진압봉 시트")
	# 기절: 근접(비살상)
	g.cmb.take({"hp": 999.0, "nonlethal": true}, c.pc.pos())
	t.ok(g.cmb.dead and g.cmb.ko, "비살상으로 HP 0 → 기절")
	t.eq(int(st.vars.get_v("V_KARMA")), 0, "기절은 카르마 0")
	t.eq(int(st.vars.get_v("MQP4_KEY")), 1, "권서준을 쓰러뜨리면 무기고 열쇠")
	t.eq(g.ko_t, Enemy.KO_SECS, "25초 누워 있다")
	var woke_at := -1.0
	for i in 30 * 10:
		g.think(0.1, c.pc, c.nav, c.shots)
		if not g.cmb.ko:
			woke_at = i * 0.1
			break
	t.ok(absf(woke_at - Enemy.KO_SECS) < 0.25, "25초 뒤 깨어난다(%.1f초)" % woke_at)
	t.ok(not g.cmb.dead and g.brain.state == AIBrain.S.SEARCH and g.cmb.hp == g.cmb.max_hp * 0.5, "깨어나 HP 절반으로 수색")
	# 사살: 실총
	g.cmb.take({"hp": 999.0}, c.pc.pos())
	t.ok(g.cmb.dead and not g.cmb.ko, "실총으로 HP 0 → 사살")
	t.eq([int(st.vars.get_v("V_KARMA")), int(st.vars.get_v("MQP4_SEC_KO"))], [-25, 1], "보안요원 사살 카르마 −25")
	m.free()


func test_p4_gate_deck(t) -> void:
	var st := _state(40)
	var r := _combat("V-00", st, Vector2(19 * 32 + 16, 26 * 32 + 16))
	var m: InteriorMap = r[0]
	var c: InteriorCombat = r[1]
	var ids := c.enemies.map(func(e): return e.get_meta("enemy_id"))
	t.eq([ids.count("CR-401"), ids.count("CR-405"), ids.count("CR-473")], [6, 1, 1], "데크: 계엄군 6 · 파워 아머 1 · 검역실 최보미")
	var pa: Enemy = c.enemies[ids.find("CR-405")]
	t.eq(pa.sheet, "en_cr405_loco", "파워 아머 시트(48×56)")
	pa.cmb.take({"hp": 9999.0}, c.pc.pos())
	t.ok(not pa.cmb.dead and pa.cmb.hp == 1.0 and pa.hide_bar, "파워 아머: HP 하한 1 · 체력 막대 없음")
	t.eq(c.enemies.filter(func(e): return e.stance == "hold").size(), 7, "데크의 계엄군은 제자리 경계")
	m.set_gate(1.0)
	t.eq(m.gate_k, 1.0, "방폭문 열림")
	t.eq(InteriorMap.prop_meta["gear_door"]["frames"].size(), 22, "방폭문 22컷(컷마다 10px)")
	m.free()
	m = InteriorMap.new()
	m.load_map("V-11", st)
	t.eq(InteriorMap.prop_meta["drain_hatch"]["frames"].size(), 10, "원형 철문 10컷(바퀴 4 + 젖힘 6)")
	t.ok(m.set_prop_frame("drain_hatch", 9), "원형 철문 컷 넘기기(anim)")
	var hp: Dictionary = m.props.filter(func(p): return p["name"] == "drain_hatch")[0]
	t.eq((hp["node"].texture as AtlasTexture).region, Rect2(InteriorMap.prop_meta["drain_hatch"]["frames"][9][0],
		InteriorMap.prop_meta["drain_hatch"]["frames"][9][1], InteriorMap.prop_meta["drain_hatch"]["frames"][9][2],
		InteriorMap.prop_meta["drain_hatch"]["frames"][9][3]), "열린 컷 그림으로 바뀐다")
	m.free()


func test_p4_detect_posture(t) -> void:
	var stand := Perception.detect_rate(6.0, 5.0, {"movement": "move", "posture": "stand"})
	var crouch := Perception.detect_rate(6.0, 5.0, {"movement": "sneak", "posture": "crouch", "sneak_skill": 40.0})
	var still := Perception.detect_rate(6.0, 5.0, {"movement": "still", "posture": "crouch", "sneak_skill": 40.0})
	t.ok(stand > crouch * 2.0 and crouch > still, "웅크려 걷기·멈춤이 서서 걷기보다 훨씬 덜 들킨다(%.0f · %.0f · %.0f)" % [stand, crouch, still])
	var st := _state(40)
	var r := _combat("V-02", st, Vector2(10 * 32 + 16, 17 * 32 + 16))
	var c: InteriorCombat = r[1]
	c.crouch = true
	c.tick(1.0 / 60.0, true, st)
	t.eq([c.pc.posture, c.pc.movement], ["crouch", "still"], "주인공 자세·움직임이 탐지식 입력으로")
	(r[0] as InteriorMap).free()


func test_p4_maps_2277(t) -> void:
	var st := _state(10)
	var m := InteriorMap.new()
	m.load_map("V-01", st)
	var ids: Array = m.data["npcs"].filter(func(n): return StoryExpr.test(str(n.get("cond", "")), st)).map(func(n): return n["id"])
	t.ok("C-001" in ids and "C-022" in ids and "C-002" in ids and "N-R01-023" in ids, "회의: 윤정인·도경철·하도윤·조안민")
	t.eq(ids.count("N-R01-023"), 1, "조안민은 한 명(일과 쪽은 회의 뒤에)")
	m.free()
	st.quests.set_stage("MQ-P4", 40)
	m = InteriorMap.new()
	m.load_map("V-02", st)
	var talk: Array = m.data["npcs"].filter(func(n): return n["id"] == "C-001" and StoryExpr.test(str(n.get("cond", "")), st))
	t.eq(talk.size(), 1, "탈출 중 오버시어실의 엄마는 한 명")
	var host := InteriorHost.new()
	host.st = st
	host._index_scenes()
	t.eq(host.scene_for("C-001").get("id", ""), "MQ-P4_S04_TALK", "탈출 중 엄마에게 말 걸면 설득 장면(옛 시대 장면이 열리지 않는다)")
	host.st = _state(20)
	t.eq(host.scene_for("C-001").get("id", ""), "", "개방식 무대의 엄마는 장면 없이 바크만")
	host.free()
	m.free()
