## 단계 1-11a SQ-S01 「외눈의 인식표」(SD-04a §4.1): 시간대 무리 · 엿보기형 발동 · 해법 A~E · 인도처 셋 · 7일 자동 종료 · 판매 ·
## 백구 동행(물러남 · 때리면 해제) · 봉천 호감은 돌아와서(공개도 1) · 소탕 뒤 시궁쥐 · 크리처 인카운터 −30% · 살펴보기 · 저장 왕복.
extends RefCounted


func _host(date: String, map_id: String, mark: String) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = date
	var c := SideR01.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 원고를 끝까지(또는 picks 차례로 고르며): s01 명령은 진행기로
func _play(st: StoryState, c: SideR01, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s01":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				i = -1
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
				k += 1
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return dr.errors


func _dogs(c: SideR01) -> int:
	return c.pack.filter(func(e): return is_instance_valid(e) and e != c.one and not e.cmb.dead).size()


func test_sq_s01_bands(t) -> void:
	t.eq([SideR01.band_of(12), SideR01.band_of(17), SideR01.band_of(21), SideR01.band_of(3), SideR01.band_of(7)], ["nap", "dusk", "night", "night", "morn"],
		"외눈의 하루: 10~16 낮잠 · 17~19 해 질 녘 · 20~05 밤 · 06~09 아침")
	var r := _host("2277. 10. 27.  18:10", "X-BW", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideR01 = r[2]
	c.tick()
	t.ok(c.pack_on and is_instance_valid(c.one), "해 질 녘: 바위굴에 들어서면 무리와 외눈이 마당에 있다")
	t.eq(c.one.level, 6, "외눈 Lv 6 고정")
	var dusk := _dogs(c)
	t.ok(dusk >= 6 and dusk <= 7, "변이 들개 4 + 사나운 들개 2~3(%d)" % dusk)
	t.eq(st.quests.stage("SQ-S01"), 20, "엿보기형: 엄태경보다 외눈을 먼저 봤다 → 단계 20부터")
	c._clear_pack()
	h.date_text = "2277. 10. 27.  22:40"
	c.tick()
	t.eq(_dogs(c), dusk + 2 if dusk + 2 <= 9 else _dogs(c), "밤(20~05시): 무리 +2")
	t.ok(c.pack.all(func(e): return e.det_mul >= 1.3), "밤 무리는 더 잘 본다")
	c._clear_pack()
	h.date_text = "2277. 10. 28.  12:00"
	c.tick()
	t.ok(c.one == null and _dogs(c) >= 6, "한낮: 외눈은 별관 2층에서 자고, 무리만 마당에서 쉰다")
	t.ok(c.pack.any(func(e): return e.asleep), "한낮 무리 몇은 졸고 있다")
	h.date_text = "2277. 10. 28.  17:00"
	c.tick()
	t.ok(is_instance_valid(c.one), "해 질 녘이 되면 외눈이 북쪽 암굴로 내려온다(보는 앞에서)")
	h.free()


func test_sq_s01_kill(t) -> void:
	var r := _host("2277. 10. 27.  07:30", "X-BW", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideR01 = r[2]
	var k0 := int(st.vars.get_v("V_KARMA"))
	var bc0 := int(st.vars.get_v("AFF_JC_BC"))
	c.tick()
	var loot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/loot.json"))
	t.ok(str(loot["drops"]["CR-500"]).contains("M-158"), "외눈 드롭: 인식표 M-158")
	var d: Enemy = c.pack.filter(func(e): return e != c.one)[0]
	d.cmb.dead = true
	c._on_killed("CR-104", 5)
	t.eq(int(st.vars.get_v("SQ_S01_KILLS")), 1, "쓰러뜨린 들개 수가 남는다(72시간 뒤 다시 채움)")
	c.one.cmb.dead = true
	c._on_killed("CR-500", 4)
	t.eq(int(st.vars.get_v("SQ_S01_SOL")), 1, "해법 A 소탕")
	t.eq(int(st.vars.get_v("V_KARMA")), k0, "카르마 0")
	t.eq(int(st.vars.get_v("AFF_JC_BC")), bc0, "봉천은 아직 모른다(공개도 1 — 마을 안 소문)")
	t.eq(int(st.vars.get_v("SQ_S01_BC")), 3, "봉천 +3 대기")
	var en := Encounters.new(st, 3)
	var cre := {"cat": "creature"}
	t.ok(absf(en.cat_mult(cre, "R01", Vector2i(930, 1520), false) - 0.7) < 0.001, "PD-R01-1 크리처 인카운터 −30%")
	t.ok(absf(en.cat_mult(cre, "R01", Vector2i(901, 1538), false) - 0.7) < 0.001, "바위굴 둘레")
	t.ok(absf(en.cat_mult(cre, "R01", Vector2i(892, 1362), false) - 1.0) < 0.001, "봉천(판도 구역 밖)은 그대로")
	t.ok(absf(en.cat_mult(cre, "R02", Vector2i(640, 1300), false) - 1.0) < 0.001, "다른 구역은 그대로")
	c._clear_pack()
	c.tick()
	t.ok(c.pack.is_empty() and c.rats.is_empty(), "소탕한 날: 굴이 비었다")
	st.vars.set_v("GAME_DAY", 7)
	c._clear_pack()
	c.tick()
	t.ok(c.rats.size() >= 3 and c.rats.size() <= 4, "사흘 뒤: 변이 시궁쥐가 든다(%d)" % c.rats.size())
	h.enter("X-BC", "from_X-S07")
	t.eq(int(st.vars.get_v("AFF_JC_BC")), bc0 + 3, "봉천에 돌아오면 반영(+3, 마을 길이 안전해짐)")
	t.eq(int(st.vars.get_v("SQ_S01_BC")), 0, "대기 몫은 비운다")
	t.eq(_play(st, c, "TR_EOM", ["쓰러뜨렸어", "됐다"]), [], "엄태경: '산이 조용해지겠네'")
	t.eq(int(st.vars.get_v("SQ_S01_EOM")), 1, "소탕을 알렸다")
	h.free()


func test_sq_s01_standoff(t) -> void:
	var r := _host("2277. 10. 27.  17:20", "X-BW", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideR01 = r[2]
	st.quests.set_stage("SQ-S01", 10)
	st.vars.set_v("SQ_S01_DOG", 1)
	c.tick()
	h.player.loco.place(h.map.mark_pos("X-BW:baek_face") + Vector2(32, 0))
	h._bring_buddy("C-015")
	t.ok(not c._dog_mate().is_empty(), "백구가 함께 왔다")
	var k0 := int(st.vars.get_v("V_KARMA"))
	c.tick()
	t.ok(c.stand_t > 9.0, "해 질 녘 + 백구 동행 + 외눈 8칸 안: 10초 대치")
	t.eq(str(c._dog_mate()["mode"]), "wait", "백구는 외눈 앞에 마주 선다")
	t.ok(c.pack.all(func(e): return e.cmb.team.begins_with("calm")), "대치 중엔 무리가 먼저 덤비지 않는다")
	var dogs: Array = c.pack.filter(func(e): return e != c.one)
	dogs[0].cmb.hp = dogs[0].cmb.max_hp * 0.6
	c._stand_tick(0.5)
	t.ok(c.stand_t > 0.0, "한 마리로는 모자라다")
	dogs[1].cmb.hp = dogs[1].cmb.max_hp * 0.69
	c._stand_tick(0.5)
	t.eq(int(st.vars.get_v("SQ_S01_SOL")), 0, "둘을 일찍 쫓아도 대치는 6초까지 선다(1-12l D-088)")
	t.ok(c.stand_t > 0.0 and c._stand_beat == 3, "무리는 물러섰다 — 외눈은 아직 백구를 본다")
	c._stand_tick(4.5)
	t.ok(c._beat4 and c._beat5, "박자: 한 발 물러섬 · 먼저 눈을 내림")
	c._stand_tick(0.6)
	t.eq(int(st.vars.get_v("SQ_S01_SOL")), 2, "들개 둘을 30% 깎아 쫓았다 → 6초 뒤 해법 B")
	t.eq(int(st.vars.get_v("SQ_S01_LEFT")), 1, "무리가 남쪽 능선으로")
	t.eq(st.quests.stage("SQ-S01"), 31, "단계 31")
	t.eq(int(st.vars.get_v("V_KARMA")), k0 + 50, "카르마 +50")
	t.eq(int(st.vars.get_v("SQ_S01_DROP")), 1, "인식표가 뼈 마당에 떨어졌다")
	t.ok(not c.tag_prop.is_empty(), "바닥에 인식표 그림")
	t.ok(dogs[2].released and c.pack.is_empty(), "남은 무리도 흩어진다(쓰러뜨리지 않았다)")
	var dc := c._drop_cell()
	h.player.loco.place(Vector2(dc.x * 32 + 16, dc.y * 32 + 16))
	c.tick()
	t.eq(st.count_of("M-158"), 1, "떨어진 인식표를 줍는다")
	t.ok(int(st.vars.get_v("SQ_S01_DROP")) == 0 and c.tag_prop.is_empty(), "바닥에서 사라진다")
	t.eq(st.quests.stage("SQ-S01"), 31, "30과 31은 같은 순간: 단계는 31, 입수는 소지가 사실")
	t.eq(int(st.vars.get_v("SQ_S01_TAG_DAY")), 4, "처음 쥔 날")
	# 대치가 깨지는 판: 10초 안에 둘을 못 쫓았다
	var r2 := _host("2277. 10. 27.  18:00", "X-BW", "arrive")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: SideR01 = r2[2]
	st2.vars.set_v("SQ_S01_DOG", 1)
	c2.tick()
	h2.player.loco.place(h2.map.mark_pos("X-BW:baek_face") + Vector2(32, 0))
	h2._bring_buddy("C-015")
	c2.tick()
	c2._stand_tick(10.1)
	t.ok(c2.stand_t < 0.0 and c2.pack.all(func(e): return e.cmb.team == "enemy" and "player" in e.foes), "10초가 지나면 대치가 깨져 무리가 덤빈다(A로)")
	t.eq(int(st2.vars.get_v("SQ_S01_SOL")), 0, "아직 해법 없음")
	t.eq(str(c2._dog_mate()["mode"]), "follow", "백구는 다시 곁에서 싸운다")
	h.free()
	h2.free()


func test_sq_s01_dog(t) -> void:
	var r := _host("2277. 10. 27.  09:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideR01 = r[2]
	st.quests.set_stage("SQ-S01", 10)
	var g := h.scene_for("C-015")
	t.eq(str(g.get("id", "")), "SQS01_BAEK", "퀘스트 중 백구에게 말을 걸면 동행 장면")
	t.eq(_play(st, c, "SQS01_BAEK"), [], "조건 없음: 낯설어한다")
	t.eq(int(st.vars.get_v("SQ_S01_DOG")), 0, "아직 따라오지 않는다")
	st.items["I-038"] = 1
	t.eq(_play(st, c, "SQS01_NAMSOL", ["그릇"]), [], "남솔의 밥 당번: 고기 한 덩이")
	t.ok(int(st.vars.get_v("SQ_S01_FEED")) == 1 and st.count_of("I-038") == 0, "밥 당번 1회(조건 ②)")
	t.eq(_play(st, c, "SQS01_BAEK"), [], "이제 따라나선다")
	t.eq(int(st.vars.get_v("SQ_S01_DOG")), 1, "백구 동행")
	t.ok(not c._dog_mate().is_empty(), "동행 목록에 백구")
	t.ok(not h.npcs.any(func(n): return str(n["id"]) == "C-015"), "맵 인물에서 떼어 냈다(맵 조건이 바뀌어도 몸을 치우지 않는다)")
	h.refresh_npcs()
	t.ok(is_instance_valid(c._dog_mate()["actor"]), "다시 세우기에도 백구 몸은 그대로")
	var m := c._dog_mate()
	(m["cmb"] as Combatant).hp = (m["cmb"] as Combatant).max_hp * 0.15
	c.tick()
	t.eq(int(st.vars.get_v("SQ_S01_DOG")), 2, "HP 20% 이하: 짖으며 마을로 돌아간다(죽지 않는다)")
	t.ok(c._dog_mate().is_empty(), "동행에서 빠졌다")
	t.ok(h.npcs.any(func(n): return str(n["id"]) == "C-015"), "봉천 개집 자리에 다시 선다")
	t.eq(str(h.scene_for("C-015").get("id", "")), "SQS01_BAEK", "다시 데려갈 수 있다")
	_play(st, c, "SQS01_BAEK")
	var bc0 := int(st.vars.get_v("AFF_JC_BC"))
	var k0 := int(st.vars.get_v("V_KARMA"))
	m = c._dog_mate()
	c.tick()
	(m["cmb"] as Combatant).last_by = "player"
	(m["cmb"] as Combatant).hit.emit()
	t.eq(int(st.vars.get_v("SQ_S01_BETRAY")), 1, "백구를 때렸다")
	t.eq([int(st.vars.get_v("AFF_JC_BC")) - bc0, int(st.vars.get_v("V_KARMA")) - k0], [-10, -25], "동행 해제 · 봉천 −10 · 카르마 −25")
	t.ok(h.scene_for("C-015").is_empty() or str(h.scene_for("C-015").get("id", "")) != "SQS01_BAEK", "다시는 따라오지 않는다")
	h.free()


func test_sq_s01_bait_report(t) -> void:
	var r := _host("2277. 10. 27.  09:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideR01 = r[2]
	t.eq(_play(st, c, "TR_EOM", ["쇠붙이", "됐다"]), [], "엄태경이 먼저 꺼낸다")
	t.eq(st.quests.stage("SQ-S01"), 10, "단계 10")
	t.eq(_play(st, c, "TR_EOM", ["쇠붙이", "떼어 낼", "됐다"]), [], "미끼 이야기")
	st.items["I-038"] = 3
	t.eq(_play(st, c, "SQS01_BAIT", ["늘어놓는다"]), [], "남쪽 빈터에 멧돼지 고기 3")
	t.ok(st.count_of("I-038") == 0 and int(st.vars.get_v("SQ_S01_BAIT")) > 0, "고기를 두고 시각을 적는다")
	h.advance_minutes(30)
	c.tick()
	t.eq(int(st.vars.get_v("SQ_S01_LEFT")), 0, "30분: 아직")
	h.advance_minutes(40)
	c.tick()
	t.eq(int(st.vars.get_v("SQ_S01_SOL")), 5, "한 시간 뒤(멀리 있었다): 무리가 사냥터를 옮겼다 — 해법 E")
	t.eq(st.quests.stage("SQ-S01"), 31, "단계 31만")
	t.eq(st.count_of("M-158"), 0, "인식표는 외눈 목에 남는다")
	h.enter("X-BC", "from_X-S07")
	var bc := int(st.vars.get_v("AFF_JC_BC"))
	t.eq(int(st.vars.get_v("SQ_S01_BC")), 0, "봉천 +2는 돌아오며 반영")
	var xp0 := int(st.vars.get_v("PC_XP"))
	t.eq(_play(st, c, "TR_EOM", ["옮겼어", "됐다"]), [], "인식표 없이 엄태경에게 알린다")
	t.eq(st.quests.stage("SQ-S01"), 100, "종료(다른 결과)")
	t.eq([int(st.vars.get_v("SQS01_RESULT")), int(st.vars.get_v("SQH_TAG"))], [5, -1], "결과 5 · 인식표는 아무 손에도")
	t.eq(int(st.vars.get_v("PC_XP")) - xp0, 300, "XP 300")
	t.eq(int(st.vars.get_v("AFF_JC_BC")), bc, "보고는 호감을 더 바꾸지 않는다")
	h.free()


func test_sq_s01_nap(t) -> void:
	var r := _host("2277. 10. 27.  12:00", "K-31", "from_K-30")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideR01 = r[2]
	t.ok(is_instance_valid(c.one) and c.one.asleep, "한낮 관람석: 외눈이 둥지에서 잔다")
	t.eq(int(st.vars.get_v("SQ_S01_NAP")), 1, "낮잠 중")
	t.eq(st.quests.stage("SQ-S01"), 20, "별관에서 먼저 봐도 20")
	h.player.loco.place(h.map.mark_pos("noise3"))
	c.tick()
	t.ok(not c.one.asleep and int(st.vars.get_v("SQ_S01_NAP")) == 0, "소음 칸(무너진 마루)을 밟으면 깬다")
	t.eq(c.pack.size(), 3, "아래층에서 들개 둘이 올라온다(해법 A로)")
	t.ok(c.pack.all(func(e): return e.cmb.team == "enemy"), "덤빈다")
	# 날붙이 + 민첩성 6: 목줄을 끊는다
	var r2 := _host("2277. 10. 27.  13:30", "K-31", "from_K-30")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: SideR01 = r2[2]
	t.ok(not StoryExpr.test("blade() == 1", st2), "맨손: 날붙이 없음")
	st2.items["W-037"] = 1
	h2.combat.equip("W-037", st2)
	t.ok(StoryExpr.test("blade() == 1", st2), "주방 식칼 W-037 = 날붙이(W-037~W-045)")
	st2.vars.set_v("PC_AG", 6)
	var k0 := int(st2.vars.get_v("V_KARMA"))
	h2.player.loco.place(h2.map.mark_pos("nap_side"))
	c2.tick()
	t.eq(_play(st2, c2, "SQS01_NAP", ["끊는다"]), [], "[민첩성 6] 날붙이로 목줄을 끊는다")
	t.eq(st2.count_of("M-158"), 1, "인식표가 손에")
	t.eq([int(st2.vars.get_v("SQ_S01_SOL")), int(st2.vars.get_v("SQ_S01_LEFT")), int(st2.vars.get_v("V_KARMA")) - k0], [4, 1, 25], "해법 D · 외눈은 깨어 무리를 이끌고 옮긴다 · 카르마 +25")
	c2.tick()
	t.eq(st2.quests.stage("SQ-S01"), 31, "단계 31(입수와 같은 순간)")
	st2.vars.set_v("PC_AG", 5)
	var dr := DialogueRunner.new(st2)
	var cur := dr.start(_scene("SQS01_NAP"))
	while cur["type"] != "choices":
		cur = dr.advance()
	t.ok(not cur["opts"].any(func(o): return str(o["text"]).contains("끊는다")), "민첩성 5면 끊는 선택지가 숨는다")
	h.free()
	h2.free()


func test_sq_s01_handoff(t) -> void:
	var r := _host("2277. 10. 27.  09:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideR01 = r[2]
	st.quests.set_stage("SQ-S01", 20)
	st.vars.set_v("SQ_S01_SOL", 2)
	st.vars.set_v("SQ_S01_LEFT", 1)
	st.call_fn("give", ["M-158", 1])
	c.tick()
	t.eq(st.quests.stage("SQ-S01"), 30, "인식표를 쥐면 30")
	t.ok(PipBoy.examinable("M-158") and not PipBoy.examinable("M-159"), "핍-보이 잡화: 인식표는 '살펴보기'")
	t.eq(_play(st, c, "EXAMINE_M158"), [], "살펴보기")
	t.eq(st.quests.stage("SQ-S01"), 40, "주소는 봉천 106동(40)")
	t.eq(str(h.scene_for("N-R01-029").get("id", "")), "SQS01_JO", "조담희에게 말을 걸면")
	var bc0 := int(st.vars.get_v("AFF_JC_BC"))
	var k0 := int(st.vars.get_v("V_KARMA"))
	var xp0 := int(st.vars.get_v("PC_XP"))
	var w0 := st.count_of("I-056")
	t.eq(_play(st, c, "SQS01_JO", ["드릴게요"]), [], "조담희에게 건넨다")
	t.eq(int(st.vars.get_v("SQH_TAG")), 81, "인도처 81")
	t.eq([int(st.vars.get_v("AFF_JC_BC")) - bc0, int(st.vars.get_v("V_KARMA")) - k0], [3, 25], "그 자리에서 봉천 +3 · 카르마 +25")
	t.ok(st.count_of("M-189") == 1 and st.count_of("I-056") == w0 + 3 and st.count_of("M-158") == 0, "백설이 사진 + 관악산 약수 3")
	t.eq(st.quests.stage("SQ-S01"), 100, "종료")
	t.eq(int(st.vars.get_v("SQS01_RESULT")), 2, "결과 = 해법(B)")
	t.eq(int(st.vars.get_v("PC_XP")) - xp0, 300, "XP 300")
	c.tick()
	t.eq(int(st.vars.get_v("SQH_TAG")), 81, "건넨 인식표는 '팜'으로 잡히지 않는다")
	t.eq(str(h.scene_for("N-R01-034").get("id", "")), "SQS01_NAMSOL", "남솔: 당번표 맨 위 '백설'")
	t.eq(str(h.scene_for("C-015").get("id", "")), "SQS01_BAEK_WAG", "백구가 꼬리를 흔든다")
	var heard := {"친구": 0, "106동": 0}
	for i in 48:                                                           # 소문 풀이 퀘스트마다 늘어나므로 넉넉히 듣는다(1-11f S06 소문이 더해짐)
		if i == 24:
			st.vars.set_v("SQ_S01_SOL", 4)                                  # 낮잠 해법이었다면 '백구 친구'는 없다
		var line := Rumors.pick(st, "R01", "N-R01-%03d" % (700 + i))
		for k in heard:
			if line.contains(k):
				heard[k] += 1
	t.ok(heard["친구"] >= 4 and heard["106동"] >= 1, "봉천 사람들: '백구 친구'(B·C) · 반상회관 인식표(%s)" % str(heard))
	# 엄태경 갈래
	var r2 := _host("2277. 10. 27.  09:00", "X-BC", "from_X-S07")
	var st2: StoryState = r2[1]
	var c2: SideR01 = r2[2]
	st2.quests.set_stage("SQ-S01", 20)
	st2.vars.set_v("SQ_S01_SOL", 1)
	st2.call_fn("give", ["M-158", 1])
	c2.tick()
	t.eq(_play(st2, c2, "TR_EOM", ["보여 준다", "걸어 두세요", "됐다"]), [], "엄태경: 오두막에 걸어 둔다")
	t.eq([int(st2.vars.get_v("SQH_TAG")), st2.quests.stage("SQ-S01")], [20, 100], "인도처 20 · 종료")
	# 7일 소지 · 판매
	var r3 := _host("2277. 10. 27.  09:00", "X-BC", "from_X-S07")
	var st3: StoryState = r3[1]
	var c3: SideR01 = r3[2]
	st3.call_fn("give", ["M-158", 1])
	c3.tick()
	t.eq(st3.quests.stage("SQ-S01"), 30, "발동 전에 주워도(순서 파괴) 30")
	st3.vars.set_v("GAME_DAY", 10)
	c3.tick()
	t.eq(st3.quests.stage("SQ-S01"), 30, "6일째: 아직")
	st3.vars.set_v("GAME_DAY", 11)
	c3.tick()
	t.eq([int(st3.vars.get_v("SQH_TAG")), st3.quests.stage("SQ-S01")], [0, 100], "7일 소지 뒤 자동 종료(SQH_TAG 0)")
	var r4 := _host("2277. 10. 27.  09:00", "X-BC", "from_X-S07")
	var st4: StoryState = r4[1]
	var c4: SideR01 = r4[2]
	st4.call_fn("give", ["M-158", 1])
	c4.tick()
	st4.call_fn("take", ["M-158", 1])
	c4.tick()
	t.eq([int(st4.vars.get_v("SQH_TAG")), st4.quests.stage("SQ-S01")], [97, 100], "건네지 않고 손을 떠남(판매) = 97")
	h.free()
	r2[0].free()
	r3[0].free()
	r4[0].free()


func test_sq_s01_perk_save(t) -> void:
	var r := _host("2277. 10. 27.  08:00", "X-BW", "arrive")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideR01 = r[2]
	st.vars.set_v("PK_045", 1)
	c._clear_pack()
	c.tick()
	t.ok(c.pack.all(func(e): return e.cmb.team.begins_with("calm") and not "player" in e.foes), "애니멀 프렌드: 무리가 먼저 덤비지 않는다")
	st.vars.set_v("PC_AG", 5)
	t.eq(_play(st, c, "SQS01_PERK", ["푼다"]), [], "[민첩성 5] 목줄을 푼다")
	t.eq([int(st.vars.get_v("SQ_S01_SOL")), st.count_of("M-158")], [3, 1], "해법 C · 인식표")
	t.ok(c.pack.is_empty(), "무리는 떠난다")
	var js := JSON.stringify(GameSnapshot.story(st))
	var st2 := StoryState.new()
	st2.load_data()
	GameSnapshot.apply_story(st2, JSON.parse_string(js))
	t.eq([int(st2.vars.get_v("SQ_S01_SOL")), int(st2.vars.get_v("SQ_S01_LEFT")), int(st2.vars.get_v("SQH_TAG")), st2.count_of("M-158")], [3, 1, -1, 1], "저장 왕복: 사실 변수 · 소지")
	t.eq(JSON.stringify(GameSnapshot.story(st2)), js, "저장 → 불러오기 → 저장이 같다")
	h.free()
