## 단계 1-D1 UQ-71 「원자력 버스」(SD-05 §3.17): 엿듣기(사흘 기한) · ① 봉인(과학 · 수리) · ② 꺼내서 상인회에 팖 · ③ 두고 떠남 → 분대가 끌어감 → 다음 날 신길 섬광 ·
## 지하차도 안 · 신길 곁이면 하루씩 미룸(P4) · ④ 배수관 처치 → 기한 없음 · 비표시(알림 없음 · 메모 한 줄) · 버스 그림과 Z2 지대가 노심을 따른다(P1).
extends RefCounted


func _host(map_id := "DB-01", mark := "from_S") -> Array:
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
	var c := Uq71.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: Uq71, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "uq71":
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


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _day(st: StoryState, c: Uq71, d: int) -> void:
	st.vars.set_v("GAME_DAY", d)
	c._on_day(d)


func _rate(h: InteriorHost, x: int, y: int) -> float:
	return h.combat.rad.dose_at(Vector2(x * 32 + 16, y * 32 + 16))


## 엿듣기: 단계 20 · 사흘 기한 · 알림 없음 · 메모 한 줄(제목 없이)
func test_uq71_hear_memo(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq71 = r[2]
	t.ok(h.combat.enemies.any(func(e): return str(e.who) == "N-R02-048"), "북쪽 경사로에 배수관")
	t.ok(_rate(h, 24, 15) > 0.0, "버스 둘레는 방사능 지대(Z2)")
	t.eq(_play(st, c, "UQ71_HEAR"), [], "엿듣기")
	t.eq([st.quests.stage("UQ-71"), _v(st, "UQ71_DUE")], [20, 13], "단계 20 · 기한 = 그날 + 사흘")
	h._drain_events()
	t.ok(not h.notes.any(func(n): return str(n[0]).contains("새 퀘스트")), "비표시: '새 퀘스트' 알림이 없다(SD-05 §2.6)")
	var pb := PipBoy.new()
	pb.st = st
	var rows: Array = pb._quest_rows()
	t.ok(rows.any(func(x): return str(x["text"]).contains("메모")) and rows.any(func(x): return str(x["text"]).contains("사흘 안에")), "기타 · 메모에 사실 한 줄")
	t.ok(not rows.any(func(x): return str(x["text"]).contains("원자력 버스")), "목록에 제목은 없다")
	pb.free()
	h.free()


## ① 봉인: 메모를 읽으면 과학 45(아니면 60) · 카르마 +25 · 100 XP · 버스가 식는다(지대 꺼짐 · 빈 받침 그림) · 분대가 사라진다
func test_uq71_seal(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq71 = r[2]
	st.vars.set_v("PC_SKP_SCIENCE", 70)                                  # 기술이 모자라면 판정 선택지는 숨는다 — 둘 다 보일 만큼
	var opts := func() -> Array:
		var dr := DialogueRunner.new(st)
		var cur := dr.start(_scene("UQ71_BUS"))
		var g := 0
		while cur["type"] != "choices" and cur["type"] != "end" and g < 50:
			g += 1
			if cur["type"] == "cmd" and str(cur["name"]) == "uq71":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		return (cur.get("opts", []) as Array).map(func(o): return str(o["text"]))
	t.ok((opts.call() as Array).any(func(o): return o.contains("더듬어 찾는다")), "메모 없이는 정지 장치를 더듬어 찾는다(과학 60)")
	t.eq(_play(st, c, "UQ71_DRIVER"), [], "운전기사 메모")
	t.eq(st.quests.stage("UQ-71"), 30, "단계 30 — 정지 레버는 운전석 밑")
	var after: Array = opts.call()
	t.ok(after.any(func(o): return o.contains("정지 레버를 당겨")) and not after.any(func(o): return o.contains("더듬어 찾는다")), "메모를 읽으면 과학 45(더듬는 판은 사라진다)")
	var k0 := _v(st, "V_KARMA")
	var xp0 := _v(st, "PC_XP")
	t.eq(_play(st, c, "UQ71_BUS", ["정지 레버를 당겨"]), [], "봉인")
	t.eq([_v(st, "UQ71_CORE"), _v(st, "UQ71_SOL"), st.quests.stage("UQ-71")], [1, 1, 100], "노심 봉인 · 해법 1 · 끝")
	t.eq([_v(st, "V_KARMA") - k0, _v(st, "PC_XP") - xp0], [25, 100], "카르마 +25 · 100 XP")
	t.eq(_rate(h, 24, 15), 0.0, "버스가 식는다(Z2 꺼짐)")
	h.enter("DB-01", "from_N")
	t.ok(not h.combat.enemies.any(func(e): return str(e.who) == "N-R02-048"), "봉인 뒤 분대는 경사로에 없다")
	t.ok(h.map.props.any(func(p): return str(p["name"]) == "bus_atomic_sunk"), "버스는 그대로(빈 받침 판)")
	_day(st, c, 30)
	t.eq(_v(st, "UQ71_CORE"), 1, "기한이 지나도 봉인한 노심은 그대로")
	h.free()


## ② 꺼내서 판다: M-392 · 단계 40 → 상인회장 노복희 250캡 · JH +2 · 100 XP
func test_uq71_take_sell(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq71 = r[2]
	st.vars.set_v("PC_SKP_SCIENCE", 50)
	t.eq(_play(st, c, "UQ71_BUS", ["노심을 받침에서 꺼낸다"]), [], "꺼내기(메모 없이 과학 45)")
	t.eq([_v(st, "UQ71_CORE"), st.count_of("M-392"), st.quests.stage("UQ-71")], [2, 1, 40], "노심을 들었다 · 단계 40")
	t.eq(_rate(h, 24, 15), 0.0, "꺼내면 버스가 식는다")
	var caps0 := _v(st, "PC_CAPS")
	var jh0 := _v(st, "AFF_JH")
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene("MQ-103_BOK"))
	var said := false
	var g := 0
	while cur["type"] != "end" and g < 80:
		g += 1
		said = said or str(cur.get("text", "")).contains("버스 통")
		if cur["type"] == "cmd":
			if str(cur["name"]) == "uq71":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var pick := 0
			for j in cur["opts"].size():
				if str(cur["opts"][j]["text"]) == "판다":
					pick = j
			cur = dr.choose(pick)
		else:
			cur = dr.advance()
	t.ok(said, "상인회장이 품의 노심을 알아본다")
	t.eq([_v(st, "UQ71_CORE"), st.count_of("M-392"), _v(st, "PC_CAPS") - caps0, _v(st, "AFF_JH") - jh0, st.quests.stage("UQ-71")], [3, 0, 250, 2, 100],
		"팔림 · 250캡 · JH +2 · 끝")
	h.free()


## ③ 두고 떠남: 하루 지나면 버스가 기운다(그림) → 기한 날 06시 분대가 끌어감(지하차도 안에 숨어 있으면 눈앞에서) → 다음 날 신길 섬광(신길 곁이면 미룸) ·
## 배수관 소식 사망 · 신길 Rad-1
func test_uq71_leave_blast(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq71 = r[2]
	t.eq(_play(st, c, "UQ71_HEAR"), [], "엿듣기")
	_day(st, c, 11)
	t.eq(_v(st, "UQ71_SQP"), 1, "하루 지나면 버스가 경사로 쪽으로 기운다")
	t.ok(_v(st, "UQ71_N") >= 2 and _v(st, "UQ71_N") <= 4, "그날 분대 인원 2~4")
	_day(st, c, 13)
	t.eq([_v(st, "UQ71_CORE"), _v(st, "UQ71_SQ")], [4, 1], "기한 날 지하차도 안 — 눈앞에서 끌어간다")
	t.ok(not h.combat.enemies.any(func(e): return is_instance_valid(e) and str(e.who) == "N-R02-048"), "분대가 경사로로 사라졌다")
	t.eq(_rate(h, 24, 15), 0.0, "버스 둘레 지대가 꺼졌다")
	h.enter("W", "@763,1190")
	_day(st, c, 14)
	t.eq(_v(st, "UQ71_CORE"), 4, "신길 빌라 곁에 있으면 섬광을 미룬다(P4 — 주인공 머리 위에서 터지지 않는다)")
	PlaceLog.load_db()
	h.enter("W", "L-R02-17>from_S")
	var xp0 := _v(st, "PC_XP")
	_day(st, c, 15)
	t.eq([_v(st, "UQ71_CORE"), _v(st, "UQ71_SOL"), st.quests.stage("UQ-71")], [5, 3, 100], "신길 섬광 · 해법 3 · 끝")
	t.ok(st.is_dead("N-R02-048"), "배수관 사망(소식)")
	t.eq(_v(st, "PC_XP") - xp0, 100, "100 XP")
	h.enter("W", "@763,1194")
	t.ok(_rate(h, 763, 1194) > 0.0 and _rate(h, 763, 1220) == 0.0, "신길 빌라 둘레 Rad-1(조건부 월드 지대)")
	h.free()


## 기한은 세계와 이어진다: 분대원을 쓰러뜨리면 하루 늦어지고, 큰집게(던전 우두머리)를 잡으면 다음 날로 당겨진다
func test_uq71_due_links(t) -> void:
	var r := _host("DB-01", "from_S")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq71 = r[2]
	t.eq(_play(st, c, "UQ71_HEAR"), [], "엿듣기")
	t.eq(_v(st, "UQ71_DUE"), 13, "기한 13일")
	c._on_kill("CR-420", 3)
	t.eq(_v(st, "UQ71_DUE"), 14, "분대원 하나 → 하루 늦어짐")
	st.vars.set_v("DG_DB", 1)
	c._t = 1.0
	c._process(0.0)
	t.eq([_v(st, "UQ71_DUE"), _v(st, "UQ71_QUICK")], [11, 1], "큰집게를 잡으면 분대가 물에 들어간다 — 다음 날로")
	h.free()


## ④ 배수관을 쓰러뜨리면 분대가 흩어지고 기한이 없다 — 노심은 버스에 남아 봉인 · 꺼내기가 열려 있다
func test_uq71_leader_down(t) -> void:
	var r := _host("DB-01", "from_N")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Uq71 = r[2]
	c._cmd(["seen"], func() -> void: pass)
	t.eq(_v(st, "UQ71_DUE"), 13, "버스를 먼저 봐도 같은 기한")
	st.kill("N-R02-048")
	c._t = 1.0
	c._process(0.0)
	t.eq([_v(st, "UQ71_SQ"), _v(st, "UQ71_DUE")], [9, 0], "분대 흩어짐 · 기한 없음")
	_day(st, c, 20)
	t.eq(_v(st, "UQ71_CORE"), 0, "노심은 버스에 그대로")
	h.enter("DB-01", "from_N")
	t.ok(not h.combat.enemies.any(func(e): return str(e.row.get("id", "")) in ["CR-420", "CR-423"]), "분대원도 경사로에 없다")
	t.ok(_rate(h, 24, 15) > 0.0, "버스는 여전히 샌다")
	h.free()
