## 단계 1-12n 가산 묶음(D-231 · D-232 · D-233, 계획 _plans/1-12n_gasan_plan.md §8 확정안):
## 인부 변장('말로 버티는 변장' — 올 날만 감지 0 · '번호?' · 뛰기/무기/두목 책상에 깨짐) · 셈꾼 거래 대화(장물상 · 볼트 작업복 300캡 · 패거리 편) ·
## 거래 쪽지(셈꾼 눈 · 몸수색) · 인솔조 부탁(새벽 편) · 편은 한 값 · 가로챔(GA_BOX 6) · 하역장 뒷문 · 6벌 상자 · 본소 '오늘의 인력' 옷 · 바깥 진열창.
extends RefCounted


func _host(map_id := "GA-01", mark := "from_W") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  10:00"
	st.vars.set_v("GAME_HOUR", 10)
	var c := Ga.new()
	c.setup(h)
	h.enter(map_id, mark)
	h.combat.holstered = true
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: Ga, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "ga":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := -1
			if k < picks.size():
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
				k += 1
			else:
				i = cur["opts"].size() - 1
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return dr.errors


## 처음 나오는 선택지 묶음(보이는 것만)
func _opts(st: StoryState, id: String) -> String:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var g := 0
	while cur["type"] != "end" and g < 200:
		g += 1
		if cur["type"] == "choices":
			var s := ""
			for o in cur["opts"]:
				if bool(o["enabled"]):
					s += str(o["text"]) + "\n"
			return s
		cur = dr.advance()
	return ""


## 장면에서 나오는 SYS · 대사 줄을 모은다(선택지는 마지막 것)
func _lines(st: StoryState, id: String) -> String:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var s := ""
	var g := 0
	while cur["type"] != "end" and g < 200:
		g += 1
		if cur["type"] == "line":
			s += str(cur.get("text", "")) + "\n"
		if cur["type"] == "choices":
			break
		cur = dr.advance()
	return s


func _gang(h: InteriorHost) -> Array:
	return h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) in Ga.GANG)


func _tick(c: Ga, dt := 0.1) -> void:
	c._tick = 0.0
	c._process(dt)


func _far(h: InteriorHost) -> Vector2:
	return Vector2(Ga.WINDOW_MARK) * 32.0 + Vector2(16, 16)


func test_ga_labor_disguise(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	h.player.loco.logical = _far(h)
	t.eq(c.disguise(), 0, "평상복 — 변장 아님")
	st.vars.set_v("PC_TORSO", "A-012")
	t.eq(c.disguise(), 1, "현장 작업복이지만 인솔조가 올 날이 아니다 — 0.5('넌 왜 벌써 왔어?')")
	st.vars.set_v("PDO_R01_6", "SB")
	st.vars.set_v("PDS_R01_6", 2)
	t.eq(c.disguise(), 2, "새벽 우세 · 낮 — 실어 갈 인부(감지 0)")
	st.vars.set_v("GAME_HOUR", 20)
	t.eq(c.disguise(), 1, "밤엔 인솔조가 없다")
	st.vars.set_v("GAME_HOUR", 10)
	st.vars.set_v("PDO_R01_6", "YT")
	st.vars.set_v("GA_CRATE_DAY", 7)
	t.eq(c.disguise(), 2, "약탈자 우세라도 수거 날(상자 본 날 + 3)이면 온다")
	_tick(c)
	var g := _gang(h).filter(func(e): return e != c._lookout and e.brain.state != AIBrain.S.COMBAT)
	t.ok(g.size() > 0 and g.all(func(e): return e.det_mul == 0.0), "변장 — 패거리 감지 0")
	st.vars.set_v("PC_TORSO", "A-001")
	t.eq(c.disguise(), 0, "볼트 작업복은 변장이 아니다")
	st.vars.set_v("PC_TORSO", "A-012")
	st.kill("C-013")
	st.kill("C-049")
	t.eq(c.disguise(), 1, "새벽인력이 무너졌으면 올 인솔조가 없다")
	var r2 := _host()
	var st2: StoryState = r2[1]
	st2.vars.set_v("PC_TORSO", "A-012")
	st2.vars.set_v("GA_SIDE", 1)
	t.eq((r2[2] as Ga).disguise(), 1, "새벽 편을 든 그날 — 셈꾼은 아직 모른다(다음 06:00에 안다)")
	st2.vars.set_v("GA_SIDE", 0)
	st2.vars.set_v("GA_NOTE", 2)
	t.eq((r2[2] as Ga).disguise(), 0, "쪽지가 빈 것을 안 뒤 — 변장 무효")
	st2.vars.set_v("PC_TORSO", "")
	st2.vars.set_v("GA_NOTE", 0)
	st2.vars.set_v("GA_SIDE", 2)
	t.eq((r2[2] as Ga).disguise(), 2, "패거리 편 — 옷과 상관없이 '우리 쪽 사람'")
	st2.vars.set_v("DG_GA", 1)
	t.eq((r2[2] as Ga).disguise(), 0, "정리 뒤엔 의미 없음")


func test_ga_labor_ask(t) -> void:
	for tag in ["", "M-452", "M-129"]:
		var r := _host()
		var h: InteriorHost = r[0]
		var st: StoryState = r[1]
		var c: Ga = r[2]
		st.vars.set_v("PC_TORSO", "A-012")
		st.vars.set_v("PDO_R01_6", "SB")
		st.vars.set_v("PDS_R01_6", 2)
		if tag != "":
			st.items[tag] = 1
		var e: Enemy = c._who(Ga.TRADER)
		t.ok(e != null, "셈꾼(이름표)이 2층 거래 자리에")
		h.player.loco.logical = e.loco.logical + Vector2(64, 0)
		h.combat.pc.movement = "still"
		_tick(c)
		if tag == "":
			t.ok(c._blown and e.brain.state == AIBrain.S.COMBAT, "번호표 없이 '번호?' — 그 자리에서 들킴")
		else:
			t.ok(c._asked and not c._blown, "번호표(%s) — '됐어, 줄은 지하'" % tag)
			_tick(c)
			t.ok(not c._blown, "그 맵에서 다시 묻지 않는다")
			h.combat.pc.movement = "sprint"
			_tick(c)
			t.ok(c._blown, "인부가 뛰면 들킨다")


func test_ga_labor_break(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	st.vars.set_v("PC_TORSO", "A-012")
	st.vars.set_v("PDO_R01_6", "SB")
	st.vars.set_v("PDS_R01_6", 2)
	h.player.loco.logical = _far(h)
	h.combat.since_shot = 0.2
	_tick(c)
	t.ok(not c._blown and c.disguise() == 0, "받아들여지기 전 — 쏘면 변장이 꺼질 뿐(평소 눈)")
	h.combat.since_shot = 99.0
	h.combat.holstered = false
	h.combat.weapon_id = "W-001"
	t.eq(c.disguise(), 0, "총을 든 사람은 인부로 보이지 않는다")
	h.combat.holstered = true
	st.items["M-129"] = 1
	var e: Enemy = c._who(Ga.TRADER)
	h.player.loco.logical = e.loco.logical + Vector2(64, 0)
	h.combat.pc.movement = "still"
	_tick(c)
	t.ok(c._asked and not c._blown, "번호표 — 받아들여짐")
	h.combat.holstered = false
	_tick(c)
	t.ok(c._blown, "받아들여진 뒤 총을 꺼내면 들킨다")
	# 두목 책상: 한 번 경고 · 4초 버티면 들킴
	var r2 := _host()
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: Ga = r2[2]
	st2.vars.set_v("PC_TORSO", "A-012")
	st2.vars.set_v("PDO_R01_6", "SB")
	st2.vars.set_v("PDS_R01_6", 2)
	st2.items["M-452"] = 1
	t.ok(c2._boss != null, "두목")
	c2._boss.loco.logical = Vector2(Ga.DESK) * 32.0 + Vector2(16, 16)
	h2.player.loco.logical = Vector2(Ga.DESK + Vector2i(0, 2)) * 32.0 + Vector2(16, 16)
	h2.combat.pc.movement = "still"
	_tick(c2)
	t.ok(c2._desk_t >= 0.0 and not c2._blown, "'세는 중이야. 꺼져.' — 한 번 경고")
	for i in 45:
		_tick(c2)
	t.ok(c2._blown, "버티면 '너 인부 맞아?' — 들킴")


func test_ga_trade_side2(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	st.vars.set_v("PC_TORSO", "A-012")
	t.ok(not _opts(st, "GA_TRADE").contains("인솔조가 언제"), "상자를 아직 못 봤으면 수거 날을 일러 줄 수 없다")
	st.vars.set_v("GA_CRATE_DAY", 9)
	var o := _opts(st, "GA_TRADE")
	t.ok(o.contains("옷을 팔러") and o.contains("인솔조가 언제"), "거래 대화 — 장물상 · 편 들기")
	t.ok(not o.contains("볼트 놈"), "여분 볼트 작업복이 없으면 300캡 선택지 없음")
	var caps := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "GA_TRADE", ["인솔조가 언제"]), [], "패거리 편 원고")
	t.ok(_v(st, "GA_SIDE") == 2 and _v(st, "PC_CAPS") == caps + 40, "패거리 편 — 40캡")
	t.ok(not _opts(st, "GA_TRADE").contains("인솔조가 언제"), "편은 한 번")
	t.ok(_lines(st, "GA_TRADE").contains("우리 쪽 사람"), "다음부터 '우리 쪽 사람'")
	# 인솔조 부탁은 닫힌다
	t.ok(not _lines(st, "GA_DOCKDOOR").contains("끄나풀"), "가로챔 전엔 인솔조가 모른다 — 셔터는 평소대로")
	# 수거 날 → 다음 06:00 가로챔
	st.vars.set_v("GAME_DAY", 12)
	h.day_tick.emit(12)
	t.ok(_v(st, "GA_PICK") == 12 and _v(st, "GA_BOX") == 0, "수거 날(9 + 3) — 당일엔 결과 없음(반쯤 된 상태 없음)")
	st.vars.set_v("GAME_DAY", 13)
	h.day_tick.emit(13)
	t.eq(_v(st, "GA_BOX"), 6, "다음 06:00 — 패거리가 가로챘다")
	t.ok(st.deeds.list.any(func(x): return str(x.get("tag", "")) == "GA_SIDE2"), "행적 — 새벽인력이 셈꾼 옆 인부를 봤다")
	st.vars.set_v("GAME_DAY", 14)
	h.day_tick.emit(14)
	t.eq(_v(st, "PD_R01_6"), -10, "판도 −10(태움과 같은 쪽)")
	var dd := _lines(st, "GA_DOCKDOOR")
	t.ok(dd.contains("총알구멍") and dd.contains("끄나풀"), "셔터에 총알구멍 · 패거리 끄나풀은 저리 가")


func test_ga_side2_preempt(t) -> void:
	var r := _host("GA-02", "from_GA01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	st.vars.set_v("PC_TORSO", "A-012")
	c.side(2)
	t.eq(_play(st, c, "GA_CRATE", ["불을"]), [], "패거리 편 뒤 상자를 직접 태운다")
	st.vars.set_v("GAME_DAY", 13)
	h.day_tick.emit(13)
	st.vars.set_v("GAME_DAY", 14)
	h.day_tick.emit(14)
	t.eq(_v(st, "GA_BOX"), 2, "먼저 손댄 결과가 남는다(가로채기 없음 — GA_BOX 하나)")
	c.side(1)
	t.eq(_v(st, "GA_SIDE"), 2, "편은 한 값")


func test_ga_note_side1(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	st.vars.set_v("PC_TORSO", "A-012")
	st.vars.set_v("GA_EYE", 1)
	t.ok(not _opts(st, "GA_NOTE").contains("견본을 고르는 척"), "은신 40 미만 — 그냥 집거나 그만두기만")
	st.vars.set_v("PC_SKP_" + st.skill_key("은신"), 60)
	var o := _opts(st, "GA_NOTE")
	t.ok(o.contains("견본을 고르는 척") and o.contains("그냥 집는다"), "셈꾼 눈앞 — 은신 또는 그냥")
	st.vars.set_v("GA_EYE", 0)
	t.eq(_play(st, c, "GA_NOTE", ["쪽지를 집는다"]), [], "쪽지 원고")
	t.ok(int(st.items.get("M-453", 0)) == 1 and _v(st, "GA_NOTE") == 1, "거래 쪽지")
	t.ok(_lines(st, "GA_NOTE").contains("견본만"), "빈자리")
	# 쪽지를 든 채 셈꾼에게 — 몸수색
	var r3 := _host()
	var st3: StoryState = r3[1]
	var c3: Ga = r3[2]
	st3.items["M-453"] = 1
	t.eq(_play(st3, c3, "GA_TRADE"), [], "몸수색 원고")
	t.ok(c3._blown, "소매 안 쪽지 — 들킴")
	# 인솔조에게
	h.enter("GA-02", "from_GA01")
	st.vars.set_v("GAME_HOUR", 10)
	var caps := _v(st, "PC_CAPS")
	var pd := _v(st, "PD_R01_6")
	t.eq(_play(st, c, "GA_DOCK"), [], "인솔조 원고")
	t.ok(_v(st, "GA_SIDE") == 1 and _v(st, "PC_CAPS") == caps + 15 and int(st.items.get("M-453", 0)) == 0, "새벽 편 — 15캡 · 쪽지를 넘김")
	t.eq(_v(st, "PD_R01_6"), pd + 5, "판도 +5")
	t.ok(st.deeds.list.any(func(x): return str(x.get("tag", "")) == "GA_SIDE1"), "행적")
	st.vars.set_v("GAME_DAY", 11)
	h.day_tick.emit(11)
	t.eq(_v(st, "GA_NOTE"), 2, "다음 06:00 — 셈꾼이 빈 쪽지를 안다")
	t.ok(not _opts(st, "GA_TRADE").contains("인솔조가 언제"), "새벽 편 뒤 패거리 편 없음")
	# 새벽 편: 변장 없이도 인솔조가 오는 날엔 뒷문
	st.vars.set_v("PC_TORSO", "")
	st.vars.set_v("PDO_R01_6", "SB")
	st.vars.set_v("PDS_R01_6", 2)
	t.ok(_opts(st, "GA_DOCKDOOR").contains("셔터 밑으로"), "새벽 편 — 뒷문을 올려 준다")
	st.vars.set_v("GAME_HOUR", 20)
	t.ok(not _opts(st, "GA_DOCKDOOR").contains("셔터 밑으로"), "밤엔 올려 줄 사람이 없다")


func test_ga_note_kept(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	c.side(2)
	t.eq(_play(st, c, "GA_NOTE", ["쪽지를 집는다"]), [], "패거리 편인데 쪽지를 뺀다")
	st.vars.set_v("GAME_DAY", 11)
	h.day_tick.emit(11)
	t.ok(_v(st, "GA_NOTE") == 2 and _v(st, "GA_SIDE") == 0, "우리 쪽인 줄 알았던 사람이 쪽지를 빼 갔다 — 편이 풀린다")
	st.vars.set_v("PC_TORSO", "A-012")
	t.eq(c.disguise(), 0, "변장도 통하지 않는다")


func test_ga_dock_door(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	t.ok(_lines(st, "GA_DOCKDOOR").contains("걸쇠가 걸렸다"), "평소 — 닫힘")
	st.vars.set_v("PDO_R01_6", "SB")
	st.vars.set_v("PDS_R01_6", 2)
	t.ok(_lines(st, "GA_DOCKDOOR").contains("옷부터"), "인솔조는 있지만 인부 옷이 아니다")
	st.vars.set_v("PC_TORSO", "A-012")
	t.ok(_opts(st, "GA_DOCKDOOR").contains("셔터 밑으로"), "작업복 — 올려 준다")
	h.enter("GA-02", "from_dock")
	t.eq(h.map.id, "GA-02", "하역장 안쪽 표식")
	t.ok(_opts(st, "GA_DOCKIN").contains("셔터 밑으로 나간다"), "안에서 — 인솔조가 셔터를 잡아 준다")
	st.vars.set_v("GAME_HOUR", 19)
	t.ok(_lines(st, "GA_DOCKIN").contains("혼자서는"), "저녁엔 혼자 못 연다")


func test_ga_crate_six(t) -> void:
	var r := _host("GA-02", "from_GA01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var cc := h.box_contents(h.map.boxes[Ga.CRATE_AT])
	t.eq(int(cc["items"].get("A-012", 0)), 6, "상자엔 6벌(꼬리표는 5벌)")
	cc["items"]["A-012"] = 5
	h.box_closed.emit(h.map.boxes[Ga.CRATE_AT], cc)
	t.eq(_v(st, "GA_BOX"), 0, "한 벌 빼 입어도 벌수 5 — 그대로")
	cc["items"]["A-012"] = 4
	h.box_closed.emit(h.map.boxes[Ga.CRATE_AT], cc)
	t.eq(_v(st, "GA_BOX"), 5, "둘 빼면 빈 상자")


func test_ga_suitsell(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Ga = r[2]
	st.call_fn("give", ["A-001", 1])
	st.vars.set_v("PC_TORSO", "A-012")
	t.ok(_opts(st, "GA_TRADE").contains("볼트 놈"), "입지 않은 볼트 작업복 — 선택지")
	var caps := _v(st, "PC_CAPS")
	c._cmd(["suitsell"], func() -> void: pass)
	t.ok(_v(st, "GA_SUITSOLD") == 1 and _v(st, "PC_CAPS") == caps + 300 and _v(st, "GA_HUNT_DAY") == 11, "300캡 · 다음 날부터 수색")
	c._cmd(["suitsell"], func() -> void: pass)
	t.eq(_v(st, "PC_CAPS"), caps + 300, "한 번")
	st.vars.set_v("GAME_DAY", 12)
	t.ok(_lines(st, "GA_TRADE").contains("봉천"), "수색 중 — '둘은 봉천 갔어'")
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/GA-01.json"))
	var hunt := (m["enemies"] as Array).filter(func(e): return str(e.get("cond", "")).contains("GA_HUNT_DAY"))
	t.eq(hunt.size(), 2, "수색 사흘 — 자리 둘 빔")
	t.ok(hunt.all(func(e): return not InteriorMap._cond_ok(str(e["cond"]), st)), "그 사흘엔 없다")
	st.vars.set_v("GAME_DAY", 14)
	t.ok(hunt.all(func(e): return InteriorMap._cond_ok(str(e["cond"]), st)), "돌아왔다")


func test_ga_tag(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Ga = r[2]
	c._cmd(["tag"], func() -> void: pass)
	c._cmd(["tag"], func() -> void: pass)
	t.ok(int(st.items.get("M-452", 0)) == 1 and c.has_tag(), "진열창 번호표 한 장(한 번)")


func test_sb_labor_line(t) -> void:
	var st := StoryState.new()
	st.load_data()
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/X-SB.json"))
	var rows := (m["npcs"] as Array).filter(func(n): return str(n["id"]).begins_with("N-SB-W"))
	t.eq(rows.size(), 15, "오늘의 인력 셋 × 옷 넷(+ 넝마 판 상자 결과별 · 새벽 편 바크)")
	var cases := [[0, 0, "T03"], [1, 1, "T12"], [4, 1, "T12"], [3, 1, "T10"], [2, 1, "T16"], [5, 1, "T16"], [6, 1, "T16"], [3, 0, "T03"]]
	st.vars.set_v("GA_SIDE", 1)
	st.vars.set_v("GA_BOX", 1)
	st.vars.set_v("GA_BOX_DONE", 1)
	st.vars.set_v("GAME_HOUR", 5)
	var bk := rows.filter(func(n): return InteriorMap._cond_ok(str(n["cond"]), st)).map(func(n): return str(n.get("bark", "")))
	t.ok(bk.size() == 3 and bk.any(func(b): return b.contains("쪽지")), "새벽 편 — 본소 줄이 쪽지 일을 말한다")
	st.vars.set_v("GA_SIDE", 0)
	st.vars.set_v("GA_BOX", 6)
	bk = rows.filter(func(n): return InteriorMap._cond_ok(str(n["cond"]), st)).map(func(n): return str(n.get("bark", "")))
	t.ok(bk.any(func(b): return b.contains("털렸대")), "가로챔 — '하역장이 털렸대'")
	for cs in cases:
		st.vars.set_v("GA_BOX", cs[0])
		st.vars.set_v("GA_BOX_DONE", cs[1])
		st.vars.set_v("GAME_HOUR", 5)
		var on := rows.filter(func(n): return InteriorMap._cond_ok(str(n["cond"]), st))
		t.ok(on.size() == 3 and on.all(func(n): return str(n["look"]).contains("-" + str(cs[2]) + "-")), "상자 %d(반영 %d) — 옷 %s" % [cs[0], cs[1], cs[2]])
	st.vars.set_v("GAME_HOUR", 7)
	t.eq(rows.filter(func(n): return InteriorMap._cond_ok(str(n["cond"]), st)).size(), 0, "새벽 04~06시에만")
	st.vars.set_v("GAME_HOUR", 5)
	st.vars.set_v("SB_RAID", 1)
	t.eq(rows.filter(func(n): return InteriorMap._cond_ok(str(n["cond"]), st)).size(), 0, "본소가 습격당했으면 줄이 없다")


func test_ga_window_out(t) -> void:
	var src: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/spots_src.json"))
	var found := false
	var txt := JSON.stringify(src)
	found = txt.contains("w_window_ga_out") and txt.contains("GA_DOCKDOOR") and txt.contains("ga_dock")
	t.ok(found, "바깥 진열창 · 하역장 셔터 · 표식 — 월드 스팟")


func test_ga_dayno(t) -> void:
	var r := _host("GA-02", "from_GA01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	st.vars.set_v("PC_TORSO", "A-012")
	t.ok(not c.has_tag(), "번호표 없음")
	t.eq(_play(st, c, "GA_DOCK"), [], "인솔조 첫 부탁")
	t.ok(c.has_tag() and _v(st, "GA_DAYNO") == 10 and _v(st, "GA_DOCKASK") == 1, "'오늘 번호 44' — 그날 번호 · 부탁")
	st.vars.set_v("GAME_DAY", 11)
	t.ok(not c.has_tag(), "다음 날엔 소용없다")
	t.eq(_play(st, c, "GA_DOCK"), [], "다시 말 걸기")
	t.ok(c.has_tag(), "다시 가면 그날 번호를 또 불러 준다")
	st.vars.set_v("GA_BOX", 1)
	st.vars.set_v("GA_DOCKASK", 0)
	t.ok(_lines(st, "GA_DOCK").contains("지난번 상자"), "상자 결과 뒤엔 '지난번 상자'")


func test_ga_goods_and_unmask(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	c.side(2)
	h.player.loco.logical = Vector2(Ga.GOODS + Vector2i(0, 1)) * 32.0 + Vector2(16, 16)
	h.player.loco.facing = Locomotion.snap8(Vector2(0, -1), 0.0)
	t.ok(c._pre(), "패거리 편이 보는 앞에서 거래 물건을 연다")
	t.ok(c._blown and _v(st, "GA_SIDE") == 0, "'우리 쪽이어도 그건 두목 거야' — 편이 풀리고 싸움")
	var r2 := _host()
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: Ga = r2[2]
	c2.side(2)
	st2.vars.set_v("GA_SUITSOLD", 1)
	st2.vars.set_v("PC_TORSO", "A-001")
	for e in _gang(h2):
		if e != c2._lookout:
			e.brain._go(AIBrain.S.SUSPICIOUS)
	h2.player.loco.logical = c2._who(Ga.TRADER).loco.logical + Vector2(64, 0)
	_tick(c2)
	t.ok(_v(st2, "GA_SIDE") == 0 and _v(st2, "GA_UNMASK") == 10, "우리 쪽 사람이 3,000짜리 — 편이 풀린다(소문 날)")


func test_ga_thief_and_crew(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	st.vars.set_v("PC_TORSO", "A-012")
	st.vars.set_v("GA_NOTE", 2)
	for e in _gang(h):
		if e != c._lookout:
			e.brain._go(AIBrain.S.SUSPICIOUS)
	h.player.loco.logical = c._who(Ga.TRADER).loco.logical + Vector2(64, 0)
	_tick(c)
	t.ok(c._thief_said, "'카키 작업복 — 쪽지 빼 간 인부다!'")
	var r2 := _host("GA-02", "from_GA01")
	var st2: StoryState = r2[1]
	var c2: Ga = r2[2]
	st2.vars.set_v("PDO_R01_6", "SB")
	st2.vars.set_v("PDS_R01_6", 2)
	st2.vars.set_v("PC_TORSO", "A-012")
	t.ok(c2.watched() and _opts(st2, "GA_DOCKDOOR").contains("셔터 밑으로"), "인솔조가 있다")
	st2.kill("N-GA-S1")
	st2.kill("N-GA-S2")
	t.ok(not c2.watched() and not _opts(st2, "GA_DOCKDOOR").contains("셔터 밑으로") and not _lines(st2, "GA_CRATE").contains("보는 눈"), "인솔조 둘이 쓰러졌으면 보는 눈도 · 셔터 올려 줄 사람도 없다")
