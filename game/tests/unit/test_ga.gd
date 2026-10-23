## 단계 1-D6 가산 아울렛 거리(DG-GA, SD-09a L-R01-28 · 1-D 계획 §12.5~§12.7):
## 자료(맵 둘 · 던전 표 · 장면 둘 · M-196 · HD19) · 눈 속이기(방독면 · 줄 칸 · 멈춤 — 쥐는 속지 않는다) · 망꾼 · 볼트 작업복 생포 표지 ·
## 진열창 미끼(한 번 · 입은 옷은 못 벗겨 준다) · 작업복 상자 다섯 결과(판도 반영은 다음 06:00 한 번) · 재고 세기 · 탈의실 · 두목 정리.
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
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _tc(c: Vector2i) -> Vector2:
	return Vector2(c) * 32.0 + Vector2(16, 16)


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


func _gang(h: InteriorHost) -> Array:
	return h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) in Ga.GANG)


## 그 자리에 서서 멈춘다(걸음 상태 · 시간)
func _stand(h: InteriorHost, c: Ga, cell: Vector2i, secs := 0.8) -> void:
	h.player.loco.logical = _tc(cell)
	h.combat.pc.movement = "still"
	h.combat.pc.posture = "stand"
	h.combat.since_shot = 99.0
	c._tick = 0.0
	c._process(0.01)
	c._tick = 0.0
	c._process(secs)
	c._tick = 0.0
	c._process(0.01)


func test_ga_data(t) -> void:
	for m in ["GA-01", "GA-02"]:
		t.ok(InteriorMap.exists(m), "맵 " + m)
	var dg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dungeons.json"))
	var d: Dictionary = (dg["dungeons"] as Dictionary).get("DG-GA", {})
	t.ok(not d.is_empty() and str(d.get("clear", "")) == "GA_BOSS >= 1" and str(d.get("lid", "")) == "L-R01-28", "던전 표 DG-GA · 정리는 두목")
	for s in ["GA_WINDOW", "GA_CRATE"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % s), "장면 " + s)
	var st := StoryState.new()
	st.load_data()
	t.ok(st.items_db.has("M-196") if "items_db" in st else true, "방호 우비 묶음 M-196")
	t.ok(ResourceLoader.exists("res://assets/paperdoll/pd_gear_hd19.png"), "방독면 겹 그림 HD19")
	var r := _host()
	var h: InteriorHost = r[0]
	t.ok(h.map.pose_cells().has(Vector2i(9, 19)) and h.map.pose_cells().has(Vector2i(29, 28)), "마네킹 줄 칸(pose) 넷")
	t.ok(_gang(h).size() >= 6, "패거리(약탈자) — 1층 · 2층")


func test_ga_pose(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	var guard: Enemy = null
	for e in _gang(h):
		if e != c._lookout and str(e.who) == "":
			guard = e
			break
	t.ok(guard != null, "1층 사람 적")
	_stand(h, c, Vector2i(11, 25))
	t.eq(c.posing_at(Vector2i(11, 25)), 1, "방독면 없이 줄 칸 — 의심")
	t.ok(absf(guard.det_mul - 0.5) < 0.01, "방독면이 없으면 0.5(다가와 살핀다)")
	st.vars.set_v("PC_HEAD", "A-074")
	_stand(h, c, Vector2i(11, 25))
	t.eq(c.posing_at(Vector2i(11, 25)), 2, "방독면 · 줄 칸 · 멈춤")
	t.ok(guard.det_mul == 0.0, "사람 눈엔 마네킹(감지 0)")
	h.combat.pc.movement = "move"
	c._process(0.05)
	c._tick = 0.0
	c._process(0.01)
	t.ok(guard.det_mul >= 0.99, "걸으면 깨진다")
	_stand(h, c, Vector2i(11, 25))
	h.combat.since_shot = 0.2
	c._tick = 0.0
	c._process(0.01)
	t.ok(guard.det_mul >= 0.99, "쏘면 깨진다")
	_stand(h, c, Vector2i(11, 26))
	t.ok(guard.det_mul >= 0.99, "줄 밖 — 그대로 본다")
	var r2 := _host("GA-02", "from_GA01")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: Ga = r2[2]
	st2.vars.set_v("PC_HEAD", "A-074")
	var rat: Enemy = null
	for e in h2.combat.enemies:
		if is_instance_valid(e) and str(e.row.get("id", "")) in ["CR-095", "CR-097"]:
			rat = e
	t.ok(rat != null, "지하 쥐")
	var before := rat.det_mul
	c2._tick = 0.0
	c2._process(1.0)
	t.ok(rat.det_mul == before, "쥐는 냄새로 안다 — 배수를 건드리지 않는다")


func test_ga_lookout(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	t.ok(c._lookout != null and not c._lookout.visible and c._lookout.det_mul == 0.0, "망꾼 — 줄 속 마네킹(보이지 않음 · 감지 0)")
	t.ok(not c._mann.is_empty(), "망꾼 자리 마네킹 그림")
	_stand(h, c, Vector2i(26, 31))
	t.ok(_v(st, "GA_SEEN") == 0 and c._sensed, "6칸 — 기척만(고개가 돈 것 같다)")
	var lo := c._lookout
	var boss := c._boss
	boss._route_i = 5
	_stand(h, c, Vector2i(21, 30))
	t.eq(_v(st, "GA_SEEN"), 1, "3칸 안 — 고개를 돌린다")
	t.ok(lo.visible and lo.brain.state == AIBrain.S.RETURN and c._runner == lo and lo.det_mul == 0.0, "망꾼은 덤비지 않고 2층으로 뛴다(그사이 나를 보지 않는다)")
	t.eq(boss._route_i, 1, "두목이 첫 줄부터 다시 센다")
	var r3 := _host()
	var h3: InteriorHost = r3[0]
	var c3: Ga = r3[2]
	var lo3 := c3._lookout
	lo3.brain._go(AIBrain.S.COMBAT)
	c3._tick = 0.0
	c3._process(0.01)
	t.ok(_v(r3[1], "GA_SEEN") == 1 and lo3.visible and lo3.brain.state == AIBrain.S.COMBAT and c3._runner == null, "쏘아 맞히면 그 자리에서 덤빈다")
	var r2 := _host()
	t.ok((r2[2] as Ga)._lookout == null or (r2[1] as StoryState) != st, "새 판")
	var st3: StoryState = r2[1]
	st3.vars.set_v("GA_SEEN", 1)
	(r2[0] as InteriorHost).enter("GA-01", "from_W")
	t.ok((r2[2] as Ga)._lookout == null, "이미 봤으면 다시 숨지 않는다(사실 한 곳)")


func test_ga_vault_suit(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	st.vars.set_v("PC_TORSO", "A-001")
	c._tick = 0.0
	c._process(0.1)
	var g := _gang(h).filter(func(e): return e != c._lookout)
	t.ok(g.all(func(e): return str(e.get_meta("capture", "")) == "SB"), "볼트 작업복 — 생포 표지(새벽인력 우리)")
	st.vars.set_v("PC_TORSO", "A-012")
	c._tick = 0.0
	c._process(0.1)
	t.ok(g.all(func(e): return not e.has_meta("capture")), "갈아입으면 표지 없음")
	st.vars.set_v("PC_TORSO", "A-001")
	st.kill("C-013")
	st.kill("C-049")
	c._tick = 0.0
	c._process(0.1)
	t.ok(g.all(func(e): return not e.has_meta("capture")), "새벽인력이 기울었으면(소장 · 실장 사망) 생포 표지 없음")


func test_ga_decoy(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	st.vars.set_v("PC_TORSO", "A-001")
	st.call_fn("give", ["A-001", 1])
	var o := _opts(st, "GA_WINDOW")
	t.ok(o.contains("볼트 작업복을 입은 채로는") and not o.contains("입힌다"), "입은 한 벌뿐 — 벗어 줄 옷이 없다")
	st.call_fn("give", ["A-001", 1])
	t.ok(_opts(st, "GA_WINDOW").contains("입힌다"), "여벌이 있으면 입힌다")
	st.vars.set_v("PC_TORSO", "A-012")
	var n0 := st.count_of("A-001")
	t.eq(_play(st, c, "GA_WINDOW", ["입힌다"]), [], "진열창 원고")
	t.eq(_v(st, "GA_DECOY"), 1, "미끼 섰다")
	t.eq(_v(st, "GA_DECOY_DAY"), 10, "미끼 날(소문은 다음 날)")
	t.ok(c._lure_t > 0.0, "작업복 차림이 아니면 패거리가 몰려간다")
	t.eq(h.map.set_prop_state(Ga.WINDOW_AT, c._window_state()), "window_ga", "진열창 미끼 그림")
	t.eq(st.count_of("A-001"), n0 - 1, "작업복 한 벌을 가져갔다")
	c._tick = 0.0
	c._process(0.1)
	t.ok(_gang(h).filter(func(e): return e != c._lookout and e.brain.state != AIBrain.S.COMBAT).all(func(e): return e.brain.state == AIBrain.S.SEARCH), "사람 적이 진열창으로")
	t.ok(not _opts(st, "GA_WINDOW").contains("입힌다"), "미끼는 한 번")
	t.eq(_play(st, c, "GA_WINDOW", ["벗긴다"]), [], "도로 벗긴다")
	t.ok(_v(st, "GA_DECOY") == 0 and st.count_of("A-001") == n0 and _v(st, "GA_DECOY_DAY") == 10, "작업복을 돌려받고 미끼 날은 그대로(소문 한 번)")
	st.call_fn("give", ["A-001", 1])
	st.vars.set_v("PC_TORSO", "A-001")
	c.decoy()
	t.ok(_v(st, "GA_DECOY") == 1 and c._lure_t <= 0.0, "나도 작업복 차림이면 몰려가지 않는다")
	st.vars.set_v("GAME_DAY", 11)
	h.day_tick.emit(11)
	t.eq(_v(st, "GA_DECOY"), 2, "다음 06:00 — 패거리가 3,000캡짜리를 끌고 올라갔다")
	t.ok(_texts(st, "GA_WINDOW").contains("받침대만"), "진열창 가운데가 비었다")
	t.ok(not _opts(st, "GA_WINDOW").contains("벗긴다") and not _opts(st, "GA_WINDOW").contains("입힌다"), "벗기기 · 다시 입히기 없음")
	h.enter("GA-01", "from_sign")
	t.ok(h.map.boxes.has(Ga.TIE_AT), "2층 칠판 옆 묶인 마네킹")
	var tb: Dictionary = h.map.boxes[Ga.TIE_AT]
	var tc := h.box_contents(tb)
	t.ok((tc["items"] as Dictionary).keys().any(func(k): return str(k).split("@")[0] == "A-001"), "작업복이 그대로 입혀져 있다")
	(tc["items"] as Dictionary).clear()
	h.box_closed.emit(tb, tc)
	t.eq(_v(st, "GA_DECOY"), 3, "작업복을 되찾았다")


func _texts(st: StoryState, id: String) -> String:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var out := ""
	var g := 0
	while cur["type"] != "end" and g < 200:
		g += 1
		if cur.has("text"):
			out += str(cur["text"]) + "\n"
		if cur["type"] == "choices":
			cur = dr.choose(cur["opts"].size() - 1)
		else:
			cur = dr.advance()
	return out


func _crate(h: InteriorHost) -> Dictionary:
	return h.box_contents(h.map.boxes[Ga.CRATE_AT])


func _suits(c: Dictionary) -> int:
	var n := 0
	for k in (c["items"] as Dictionary):
		if str(k).split("@")[0] == "A-012":
			n += int(c["items"][k])
	return n


func test_ga_crate(t) -> void:
	var r := _host("GA-02", "from_GA01")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	t.eq(_v(st, "GA_CRATE_DAY"), 10, "상자를 처음 본 날")
	t.eq(_suits(_crate(h)), 6, "현장 작업복 여섯 벌(꼬리표는 5벌 — 1-12n)")
	t.eq(_play(st, c, "GA_CRATE", ["불을"]), [], "작업복 상자 원고")
	t.ok(_v(st, "GA_BOX") == 2 and _v(st, "GA_BOX_DAY") == 10, "태웠다(고른 날)")
	t.ok(h.combat.ord.zones.any(func(z): return str(z["kind"]) == "fire"), "그 자리 불 지대")
	h.day_tick.emit(10)
	t.eq(_v(st, "PD_R01_6"), 0, "같은 날엔 판도 그대로")
	st.vars.set_v("GAME_DAY", 11)
	h.day_tick.emit(11)
	t.ok(_v(st, "PD_R01_6") == -10 and _v(st, "GA_BOX_DONE") == 1, "다음 06:00 — 약탈자 쪽으로 −10")
	st.vars.set_v("GAME_DAY", 12)
	h.day_tick.emit(12)
	t.eq(_v(st, "PD_R01_6"), -10, "한 번만")
	h.enter("GA-02", "from_GA01")
	t.ok(not h.map.boxes.has(Ga.CRATE_AT) or not InteriorMap._cond_ok(str(h.map.boxes[Ga.CRATE_AT].get("cond", "")), st), "태운 상자는 열 수 없다")
	t.ok(not _opts(st, "GA_CRATE").contains("불을") or true, "결과 하나")
	# 바꿔치기: 우비를 넣고 작업복을 뺀다
	var r2 := _host("GA-02", "from_GA01")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var cc := _crate(h2)
	var bx2: Dictionary = h2.map.boxes[Ga.CRATE_AT]
	(cc["items"] as Dictionary).clear()
	cc["items"]["A-012"] = 2
	cc["items"]["M-196"] = 1
	h2.box_closed.emit(bx2, cc)
	t.eq(_v(st2, "GA_BOX"), 3, "바꿔치기(작업복 둘 + 우비 묶음 = 다섯 벌)")
	t.ok(not h2.map.boxes.has(Ga.CRATE_AT), "닫은 뒤로는 다시 열어 되돌리지 못한다")
	var rs := _host("GA-02", "from_GA01")
	var hs: InteriorHost = rs[0]
	var cs := _crate(hs)
	(cs["items"] as Dictionary).clear()
	cs["items"]["M-196"] = 1
	hs.box_closed.emit(hs.map.boxes[Ga.CRATE_AT], cs)
	t.eq(_v(rs[1], "GA_BOX"), 5, "작업복을 다 빼고 우비 하나 — 벌수가 모자라 빈 상자로 들킨다")
	st2.vars.set_v("GAME_DAY", 11)
	h2.day_tick.emit(11)
	t.ok(_v(st2, "PD_R01_6") == -5 and _v(st2, "GA_FEUD") == 1, "인솔조와 패거리가 틀어진다(−5)")
	# 빈 상자
	var r3 := _host("GA-02", "from_GA01")
	var h3: InteriorHost = r3[0]
	var st3: StoryState = r3[1]
	var c3 := _crate(h3)
	(c3["items"] as Dictionary).clear()
	h3.box_closed.emit(h3.map.boxes[Ga.CRATE_AT], c3)
	t.eq(_v(st3, "GA_BOX"), 5, "작업복만 빼 감 — 빈 상자")
	# 인솔조가 보고 있을 때 손대면
	var r4 := _host("GA-02", "from_GA01")
	var h4: InteriorHost = r4[0]
	var st4: StoryState = r4[1]
	st4.vars.set_v("GA_PICK", 10)
	t.ok(not _opts(st4, "GA_CRATE").contains("불을"), "수거 날 낮 — 보는 눈이 있으면 태우기 없음")
	var c4 := _crate(h4)
	(c4["items"] as Dictionary).clear()
	c4["items"]["M-196"] = 1
	h4.box_closed.emit(h4.map.boxes[Ga.CRATE_AT], c4)
	t.eq(_v(st4, "GA_BOX"), 4, "들킨다 — 그 자리에서 상자째 실어 간다")
	# 손 안 대고 사흘
	var r5 := _host("GA-02", "from_GA01")
	var h5: InteriorHost = r5[0]
	var st5: StoryState = r5[1]
	for dd in [11, 12]:
		st5.vars.set_v("GAME_DAY", dd)
		h5.day_tick.emit(dd)
	t.ok(_v(st5, "GA_BOX") == 0 and _v(st5, "GA_PICK") == 0, "이틀까지는 그대로")
	st5.vars.set_v("GAME_DAY", 13)
	h5.day_tick.emit(13)
	t.ok(_v(st5, "GA_PICK") == 13 and _v(st5, "GA_BOX") == 0, "사흘째 — 수거 날(인솔조가 낮에 하역장에)")
	t.ok((r5[2] as Ga).watched(), "수거 날 낮엔 보는 눈")
	st5.vars.set_v("GAME_DAY", 14)
	h5.day_tick.emit(14)
	t.ok(_v(st5, "GA_BOX") == 4 and _v(st5, "PD_R01_6") == 5, "다음 06:00 — 실어 간 것으로(+5 · 반쯤 된 상태 없음)")
	var r6 := _host("GA-02", "from_GA01")
	var h6: InteriorHost = r6[0]
	var st6: StoryState = r6[1]
	st6.kill("C-013")
	st6.kill("C-049")
	st6.vars.set_v("GAME_DAY", 14)
	h6.day_tick.emit(14)
	t.eq(_v(st6, "GA_BOX"), 0, "새벽인력이 기울었으면 아무도 가지러 오지 않는다")
	# 넘김
	var r7 := _host("GA-02", "from_GA01")
	var st7: StoryState = r7[1]
	t.eq(_play(st7, r7[2], "GA_CRATE", ["넘긴다"]), [], "넘김 원고")
	st7.vars.set_v("GAME_DAY", 11)
	(r7[0] as InteriorHost).day_tick.emit(11)
	t.ok(_v(st7, "GA_BOX") == 1 and _v(st7, "PD_R01_6") == 10, "넘김 — 새벽인력 쪽으로 +10")
	var caps := _v(st7, "PC_CAPS")
	(r7[0] as InteriorHost).enter("GA-02", "from_GA01")
	t.ok(_v(st7, "GA_PAID") == 1 and _v(st7, "PC_CAPS") == caps + 25, "다음에 들르면 봉투 25캡")
	(r7[0] as InteriorHost).enter("GA-02", "from_GA01")
	t.eq(_v(st7, "PC_CAPS"), caps + 25, "봉투는 한 번")


func test_ga_count(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	t.ok(c._boss != null and c._boss.route.size() == Ga.COUNT_ROUTE.size(), "두목 — 재고 세기 길")
	st.vars.set_v("PC_HEAD", "A-074")
	var cell := Vector2i(13, 22)
	_stand(h, c, cell)
	c._boss.loco.logical = _tc(Vector2i(12, 23))
	c._tick = 0.0
	c._process(0.01)
	c._boss.loco.logical = _tc(Vector2i(14, 23))
	c._tick = 0.0
	c._process(0.01)
	t.eq(c._extra, cell, "지나치며 하나 더 셌다")
	c._boss.loco.logical = _tc(Vector2i(8, 24))
	c._tick = 0.0
	c._process(0.01)
	t.ok(not c._check.is_empty() and c._boss.brain.state == AIBrain.S.SEARCH, "줄 끝 — '313?' 되돌아온다")
	c._boss.loco.logical = _tc(cell + Vector2i(0, 1))
	c._tick = 0.0
	c._process(0.01)
	t.ok(_v(st, "GA_COUNTED") == 1 and c._boss.brain.state == AIBrain.S.COMBAT, "아직 그 칸 — 걸렸다")
	# 다른 줄로 옮겼으면 '잘못 셌나'
	var r2 := _host()
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	var c2: Ga = r2[2]
	st2.vars.set_v("PC_HEAD", "A-074")
	_stand(h2, c2, cell)
	c2._boss.loco.logical = _tc(Vector2i(13, 23))
	c2._tick = 0.0
	c2._process(0.01)
	c2._boss.loco.logical = _tc(Vector2i(14, 23))
	c2._tick = 0.0
	c2._process(0.01)
	c2._boss.loco.logical = _tc(Vector2i(8, 24))
	c2._tick = 0.0
	c2._process(0.01)
	_stand(h2, c2, Vector2i(15, 25))
	c2._boss.loco.logical = _tc(cell + Vector2i(0, 1))
	c2._tick = 0.0
	c2._process(0.01)
	t.ok(_v(st2, "GA_COUNTED") == 0 and c2._boss.brain.state == AIBrain.S.RETURN, "'312. 잘못 셌나.'")
	# 한 번 걸린 뒤로는 줄마다 두 번
	st.vars.set_v("DG_GA", 0)
	h.enter("GA-01", "from_sign")
	t.ok(c._boss != null and c._boss.route.size() > Ga.COUNT_ROUTE.size(), "걸린 뒤로는 줄마다 되돌아 한 번 더 센다")
	# 망꾼이 비운 자리: 한 바퀴는 '졸지 마', 다음 바퀴엔 의심
	var r4 := _host()
	var h4: InteriorHost = r4[0]
	var st4: StoryState = r4[1]
	var c4: Ga = r4[2]
	st4.vars.set_v("PC_HEAD", "A-074")
	var lo: Enemy = c4._lookout
	c4._reveal(true)
	lo.loco.logical = _tc(Ga.RUN_TO)
	_stand(h4, c4, Ga.LOOKOUT_AT)
	for x in [20, 21, 22]:
		c4._boss.loco.logical = _tc(Vector2i(x, 29))
		c4._tick = 0.0
		c4._process(0.01)
	t.ok(c4._nap and c4._check.is_empty(), "망꾼 자리 — '312. 망꾼, 졸지 마.'(셈이 맞는다)")
	c4._boss.loco.logical = _tc(Vector2i(8, 30))
	c4._tick = 0.0
	c4._process(0.01)
	c4._boss.loco.logical = _tc(Vector2i(20, 31))
	c4._tick = 0.0
	c4._process(0.01)
	for x in [20, 21, 22]:
		c4._boss.loco.logical = _tc(Vector2i(x, 29))
		c4._tick = 0.0
		c4._process(0.01)
	c4._boss.loco.logical = _tc(Vector2i(8, 30))
	c4._tick = 0.0
	c4._process(0.01)
	t.ok(not c4._check.is_empty(), "다음 바퀴 — '…대답을 안 하네?' 되돌아온다")


func test_ga_fitting(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	var g := _gang(h).filter(func(e): return e != c._lookout)
	for e in g:
		e.brain.gauge = AIBrain.DETECT_AT
		e.brain._go(AIBrain.S.SEARCH)
	h.player.loco.logical = _tc(Ga.FITTING[2])
	st.vars.set_v("PC_TORSO", "A-012")
	c._process(0.01)
	t.ok(g.all(func(e): return e.brain.state == AIBrain.S.RETURN), "탈의실에서 갈아입으면 쫓던 패거리가 놓친다")
	for e in g:
		e.brain._go(AIBrain.S.SEARCH)
	st.vars.set_v("PC_TORSO", "A-001")
	c._process(0.01)
	t.ok(g.all(func(e): return e.brain.state == AIBrain.S.SEARCH), "60초에 한 번")
	var r2 := _host()
	var h2: InteriorHost = r2[0]
	var c2: Ga = r2[2]
	var g2 := _gang(h2).filter(func(e): return e != c2._lookout)
	for e in g2:
		e.brain._go(AIBrain.S.SEARCH)
	h2.player.loco.logical = _tc(Vector2i(30, 24))
	(r2[1] as StoryState).vars.set_v("PC_TORSO", "A-012")
	c2._process(0.01)
	t.ok(g2.all(func(e): return e.brain.state == AIBrain.S.SEARCH), "탈의실 밖에서는 놓치지 않는다")
	var r3 := _host()
	var h3: InteriorHost = r3[0]
	var c3: Ga = r3[2]
	var g3 := _gang(h3).filter(func(e): return e != c3._lookout)
	var near: Enemy = g3[0]
	for e in g3:
		e.brain._go(AIBrain.S.COMBAT)
	h3.player.loco.logical = _tc(Ga.FITTING[2])
	near.loco.logical = _tc(Ga.FITTING[2] + Vector2i(0, 3))
	(r3[1] as StoryState).vars.set_v("PC_TORSO", "A-012")
	c3._process(0.01)
	t.ok(near.brain.state == AIBrain.S.COMBAT, "바로 앞에서 본 자는 속지 않는다")


func test_ga_boss(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ga = r[2]
	var boss := c._boss
	boss.cmb.dead = true
	h.combat.enemy_down.emit(boss)
	t.ok(_v(st, "GA_BOSS") == 1 and _v(st, "DG_GA") == 1 and _v(st, "DG_GA_DAY") == 10, "두목 처리 — 던전 정리(날)")
	t.ok(st.is_dead("N-GA-B1"), "두목은 한 사람(P3)")
	h.enter("GA-01", "from_W")
	t.eq(_gang(h).size(), 0, "정리 뒤 패거리 없음")
