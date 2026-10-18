## 단계 1-D8 여의도 대학병원(DG-HP · UQ-126 · RQ-47, SD-09a L-R02-09 · SD-05 §3.22 · 1-D 계획 §14.7):
## 자료(맵 셋 · 던전 표 · 장면 · M-397 · M-398 · 상인 VHP) · 병원 시각표 · 차임 대형(기상 누움 · 회진 행진 · 배식 섬 · 면회 앉음 · 소등 배회와 1층) ·
## 방송 덮어쓰기와 7층 회로(제때 아닌 차임의 대가 · 하루 한 번) · 병동 시계(흐림 → 잃음 · 1막 최대 셋 · 면회로 돌아옴 · 약길이면 멈춤) ·
## RQ-47 납품(주 한 번 · 회차 곡선) · 약길 셋(교역 · 들것 정류지 · 이주) · 작은 부탁 셋 · 영안실 정리.
extends RefCounted


func _host(map_id := "HP-03", mark := "from_HP01", hhmm := "10:00") -> Array:
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
	h.date_text = "2277. 11. 01.  %s" % hhmm
	st.vars.set_v("GAME_HOUR", int(hhmm.substr(0, 2)))
	var c := Hp.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: Hp, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "hp":
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


func _at(h: InteriorHost, st: StoryState, hhmm: String) -> void:
	h.date_text = "2277. 11. 01.  %s" % hhmm
	st.vars.set_v("GAME_HOUR", int(hhmm.substr(0, 2)))


func _who(c: Hp) -> Array:
	return c.ferals().map(func(e): return str(e.who))


func test_hp_data(t) -> void:
	for m in ["HP-01", "HP-02", "HP-03"]:
		t.ok(FileAccess.file_exists("res://data/maps/%s.json" % m), "맵 %s" % m)
	for s in ["HP_BAN", "HP_P1", "HP_P2", "HP_P3", "HP_P4", "HP_BED", "HP_BED13", "HP_BOARD", "HP_CUT", "HP_PA1", "HP_PA", "HP_GEN", "HP_DAD", "HP_TAG"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % s), "장면 %s" % s)
	var r := _host()
	var h: InteriorHost = r[0]
	var c: Hp = r[2]
	for id in ["M-397", "M-398"]:
		t.ok(h.items_db.has(id), "아이템 %s" % id)
	var mer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	t.ok(mer.has("VHP"), "상인 VHP(반수빈 — 치료 · 약 매입)")
	var dg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dungeons.json"))
	var found := false
	var dd = dg["dungeons"]
	for d in (dd.values() if typeof(dd) == TYPE_DICTIONARY else dd):
		if typeof(d) == TYPE_DICTIONARY and str(d.get("lid", "")) == "L-R02-09":
			found = true
	t.ok(found, "던전 표 @HP(L-R02-09)")
	var w := _who(c)
	t.ok(w.size() == 5 and not "N-HP-L1" in w, "지하 야생 구울 = 옛 직원 다섯(잃은 환자 없음) %s" % str(w))


func test_hp_phase(t) -> void:
	t.ok(Hp.phase_of(400) == 1 and Hp.phase_of(600) == 2 and Hp.phase_of(750) == 3 and Hp.phase_of(870) == 4, "기상 · 회진 · 배식 · 면회")
	t.ok(Hp.phase_of(1000) == 6 and Hp.phase_of(1330) == 5 and Hp.phase_of(100) == 5, "휴식 · 소등(자정 넘어 06:30까지)")
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Hp = r[2]
	t.ok(c.phase() == 2, "10시 = 회진")
	c.call_chime(3)
	t.ok(c.phase() == 3 and _v(st, "HP_OVR") == 3, "방재실에서 배식 차임 — 지금이 배식")
	h.advance_minutes(130)
	c._process(1.0)
	t.ok(c.phase() == phase_of_now(h) and _v(st, "HP_OVR") == 0, "두 시간 뒤 시계로 돌아간다")


func phase_of_now(h: InteriorHost) -> int:
	return Hp.phase_of(TimeOfDay.minute(h.date_text))


func test_hp_formation(t) -> void:
	var r := _host("HP-03", "from_HP01", "07:00")
	var c: Hp = r[2]
	t.ok(c.ferals().all(func(e): return e.asleep and e.doze == "lie"), "기상 — 냉동 칸 앞에 누워 잔다")
	r = _host("HP-03", "from_HP01", "10:00")
	c = r[2]
	t.ok(c.ferals().all(func(e): return not e.asleep and e.route.size() >= 6), "회진 — 깨어 복도를 한 줄로 돈다")
	r = _host("HP-03", "from_HP01", "13:00")
	var h: InteriorHost = r[0]
	c = r[2]
	var kitchen := c.ferals().all(func(e): return e.asleep and e.doze == "stand" and e.loco.logical.y < 8 * 32)
	t.ok(kitchen, "배식 — 주방 배식차 앞에 서서 존다(약제부에서 먼 쪽)")
	r = _host("HP-03", "from_HP01", "14:30")
	c = r[2]
	t.ok(c.ferals().all(func(e): return e.asleep and e.doze == "sit"), "면회 — 조문 의자에 앉는다")
	r = _host("HP-03", "from_HP01", "23:00")
	var st: StoryState = r[1]
	c = r[2]
	var w := _who(c)
	t.ok(_v(st, "HP_NIGHT") == 1 and w.size() == 3 and not "N-HP-F4" in w, "소등 — 지하엔 셋만(둘은 1층) %s" % str(w))
	t.ok(c.ferals().all(func(e): return not e.asleep), "소등 — 깨어 배회")
	r = _host("HP-01", "from_W", "23:00")
	c = r[2]
	t.ok(_who(c).size() == 2, "소등 — 1층 응급실에 둘 %s" % str(_who(c)))
	r = _host("HP-01", "from_W", "10:00")
	c = r[2]
	t.ok(_who(c).is_empty(), "낮 1층엔 없다")


func test_hp_live_chime(t) -> void:
	var r := _host("HP-03", "from_HP01", "13:00")
	var h: InteriorHost = r[0]
	var c: Hp = r[2]
	c._phase = 3
	c.call_chime(4)
	c._formation(false)
	var e = c.ferals()[0]
	t.ok(not e.asleep and e.has_meta("hp_go") and e.route.size() == 1, "면회 차임 — 일어나 조문 의자로 걷는다")
	e.loco.place(e.route[0][0])
	c._settle()
	t.ok(e.asleep and e.doze == "sit", "자리에 닿으면 앉아 존다")
	c._group_wake(e)
	e.wake()
	t.ok(c.ferals().filter(func(x): return not x.asleep).size() >= 2, "하나가 깨면 가까운 무리가 한꺼번에")


func test_hp_clock(t) -> void:
	var r := _host("HP-02", "from_HP01", "10:00")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Hp = r[2]
	c._on_day(20)
	t.ok(_v(st, "HP_BLUR") == 0, "반수빈을 만나기 전엔 시계가 안 돈다(P2)")
	c._cmd(["met"], func() -> void: pass)
	t.ok(_v(st, "HP_DAY0") == 10 and c.days_left() == 14, "첫 대화 날부터 14일")
	c._on_day(23)
	t.ok(_v(st, "HP_BLUR") == 0, "13일째 — 아직")
	c._on_day(24)
	t.ok(_v(st, "HP_BLUR") == 1 and _v(st, "HP_BLUR_DAY") == 24, "14일 — 차트 1번 탁정오가 흐림")
	st.vars.set_v("GAME_DAY", 25)
	_at(h, st, "14:30")
	st.vars.set_v("HP_BED", 1)
	c.visit(0)
	t.ok(_v(st, "HP_BLUR") == 0 and _v(st, "HP_DAY0") == 25, "면회 시간에 곁에 앉으면 돌아온다 · 시계를 다시 잰다")
	c._on_day(39)
	c._on_day(46)
	t.ok(_v(st, "HP_LOST") == 1 and _v(st, "HP_BLUR") == 0, "흐림을 7일 넘기면 잃음(지하로)")
	for d in [60, 67, 81, 88]:
		c._on_day(d)
	t.ok(_v(st, "HP_LOST") == 3, "잃음 셋")
	for d in [102, 109, 130]:
		c._on_day(d)
	t.ok(_v(st, "HP_LOST") == 3 and _v(st, "HP_BLUR") == 4, "1막 최대 셋 — 넷째는 흐림에서 멈춘다")


func test_hp_push(t) -> void:
	var r := _host("HP-03", "from_HP01", "10:00")
	var st: StoryState = r[1]
	var c: Hp = r[2]
	c._cmd(["met"], func() -> void: pass)
	c.call_chime(2)
	t.ok(_v(st, "HP_BLUR") == 0, "제때 차임(회진에 회진)은 대가 없음")
	c.call_chime(5)
	t.ok(_v(st, "HP_BLUR") == 1 and _v(st, "HP_PUSH_DAY") == 10, "제때 아닌 차임 — 7층이 흐려진다")
	var bd := _v(st, "HP_BLUR_DAY")
	c.call_chime(3)
	t.ok(_v(st, "HP_BLUR_DAY") == bd, "같은 날 두 번째는 더 밀지 않는다")
	st.vars.set_v("HP_BLUR", 0)
	st.vars.set_v("HP_PUSH_DAY", 0)
	st.vars.set_v("HP_TRUST", 1)
	c.cut(1)
	c.call_chime(5)
	t.ok(_v(st, "HP_BLUR") == 0, "반수빈이 7층 회로를 끊어 주면 대가 없음")
	st.vars.set_v("HP_TRUST", 0)
	c.cut(0)
	c.cut(1)
	t.ok(_v(st, "HP_CUT") == 0, "믿음 없이는 끊어 주지 않는다")
	c.cut(2)
	c._phase = 1
	c._chime(2)
	t.ok(_v(st, "HP_BLUR") == 1 and _v(st, "HP_TRUST") == 0, "몰래 끊으면 다음 차임에 들킨다 · 흐림")


func test_hp_supply(t) -> void:
	var r := _host("HP-02", "from_HP01", "10:00")
	var st: StoryState = r[1]
	var c: Hp = r[2]
	c._cmd(["met"], func() -> void: pass)
	var caps := _v(st, "PC_CAPS")
	c.supply()
	t.ok(_v(st, "RQ47_N") == 0, "물건이 없으면 받지 않는다")
	st.call_fn("give", ["I-002", 6])
	st.call_fn("give", ["I-004", 4])
	c.supply()
	t.ok(_v(st, "RQ47_N") == 1 and _v(st, "PC_CAPS") == caps + 50 and int(st.call_fn("has", ["I-002", 3])) == 1, "납품 — 50캡 · 라드어웨이 셋 · 수혈 팩 둘")
	c.supply()
	t.ok(_v(st, "RQ47_N") == 1, "주 한 번")
	st.vars.set_v("RQ47_N", 3)
	st.vars.set_v("GAME_DAY", 17)
	var c2 := _v(st, "PC_CAPS")
	c.supply()
	t.ok(_v(st, "PC_CAPS") == c2 + 38, "넷째부터 75%%(곡선)")
	t.ok(_v(st, "HP_DAY0") == 17, "약이 들어오면 시계를 다시 잰다")


func test_hp_ways(t) -> void:
	var r := _host("HP-02", "from_HP01", "10:00")
	var st: StoryState = r[1]
	var c: Hp = r[2]
	c._cmd(["met"], func() -> void: pass)
	c._cmd(["told"], func() -> void: pass)
	t.ok(st.quests.stage("UQ-126") == 20, "단계 20")
	var jh := _v(st, "AFF_JH")
	c.set_way(1)
	t.ok(_v(st, "HP_WAY") == 1 and _v(st, "AFF_JH") == jh + 2 and not c.clock_on(), "① 교역 — JH +2 · 시계 멈춤")
	t.ok(st.quests.stage("UQ-126") == 100, "약길이 정해지면 끝")
	st.kill("C-051")
	t.ok(c.clock_on(), "금하람이 죽으면 그 길이 끊긴다 — 시계가 다시 돈다")
	r = _host("HP-02", "from_HP01", "10:00")
	st = r[1]
	c = r[2]
	c._cmd(["met"], func() -> void: pass)
	c.set_way(2)
	t.ok(_v(st, "DG_STOP") == 1 and Caravans.medic_at(4, 1) == 3 and Caravans.medic_at(4, 0) == 0, "② 들것 — 정류지 여의도 · 4일째 병원")
	r = _host("HP-02", "from_HP01", "10:00")
	st = r[1]
	c = r[2]
	c._cmd(["met"], func() -> void: pass)
	c._cmd(["move"], func() -> void: pass)
	t.ok(_v(st, "HP_WAY") == 0, "이주는 다음 06:00(P6)")
	jh = _v(st, "AFF_JH")
	c._on_day(11)
	t.ok(_v(st, "HP_WAY") == 3 and _v(st, "AFF_JH") == jh + 4 and st.quests.stage("UQ-126") == 100, "③ 이주 — JH +4")
	st.kill("N-R02-031")
	t.ok(c.days_left() == -1, "이주 뒤엔 시계 없음")


func test_hp_ban_dead(t) -> void:
	var r := _host("HP-02", "from_HP01", "10:00")
	var st: StoryState = r[1]
	var c: Hp = r[2]
	c._cmd(["met"], func() -> void: pass)
	st.kill("N-R02-031")
	t.ok(c.days_left() == 7, "반수빈이 없으면 7일")
	c.set_way(1)
	t.ok(_v(st, "HP_WAY") == 0, "반수빈 없이 약길 없음")


func test_hp_scenes(t) -> void:
	var r := _host("HP-02", "from_HP01", "10:00")
	var st: StoryState = r[1]
	var c: Hp = r[2]
	var e := _play(st, c, "HP_BAN", ["사정"])
	t.ok(e.is_empty(), "반수빈 장면 %s" % str(e))
	t.ok(_v(st, "HP_MET") == 1 and _v(st, "HP_TOLD") == 1 and st.quests.stage("UQ-126") == 20, "첫 대화 · 사정 → 단계 20")
	e = _play(st, c, "HP_BAN", ["약길", "지하시장"])
	t.ok(e.is_empty() and _v(st, "HP_LETTER") == 1, "편지 %s" % str(e))
	e = _play(st, c, "HP_PA", ["배식"])
	t.ok(e.is_empty() and _v(st, "HP_OVR") == 3, "방재실 단말 — 배식 차임 %s" % str(e))
	e = _play(st, c, "HP_BAN", ["스피커"])
	t.ok(e.is_empty() and _v(st, "HP_CUT") == 0, "믿음 전엔 '손대지 마요'")


func test_hp_asks(t) -> void:
	var r := _host("HP-01", "from_W", "10:00")
	var st: StoryState = r[1]
	var c: Hp = r[2]
	var e := _play(st, c, "HP_DAD", ["쪽지"])
	t.ok(e.is_empty() and int(st.call_fn("has", ["M-398"])) == 1, "로비 유해 — 면회 쪽지 %s" % str(e))
	e = _play(st, c, "HP_P3")
	t.ok(e.is_empty() and _v(st, "HP_ASK3") == 2 and int(st.call_fn("has", ["M-398"])) == 0, "기도윤에게 쪽지(이미 앎 판 — 부탁을 듣기 전에도)")
	e = _play(st, c, "HP_TAG", ["사원증"])
	e += _play(st, c, "HP_P1")
	t.ok(e.is_empty() and _v(st, "HP_ASK1") == 2, "변미숙에게 사원증 %s" % str(e))
	e = _play(st, c, "HP_P2")
	t.ok(_v(st, "HP_ASK2") == 1, "남궁호 — 오재석 이야기를 묻는다")
	st.vars.set_v("HP_OJ", 1)
	e = _play(st, c, "HP_P2", ["수첩"])
	t.ok(e.is_empty() and _v(st, "HP_ASK2") == 2, "구로 수첩을 읽었으면 전한다 %s" % str(e))


func test_hp_morgue(t) -> void:
	var r := _host("HP-03", "from_HP01", "10:00")
	var st: StoryState = r[1]
	var c: Hp = r[2]
	for w in ["N-HP-F1", "N-HP-F2", "N-HP-F3", "N-HP-F4", "N-HP-F5"]:
		st.kill(w)
	c._tick = 0.0
	c._process(1.0)
	t.ok(_v(st, "HP_MORGUE") == 1, "옛 직원 다섯 — 영안실 정리")
	r = _host("HP-03", "from_HP01", "10:00")
	st = r[1]
	c = r[2]
	st.vars.set_v("HP_LOST", 2)
	r[0].enter("HP-01", "from_HP03")
	r[0].enter("HP-03", "from_HP01")
	var w := _who(c)
	t.ok("N-HP-L1" in w and "N-HP-L2" in w and not "N-HP-L3" in w, "잃은 환자 둘 — 이름표 구울 %s" % str(w))
	c._cmd(["gen"], func() -> void: pass)
	c._formation(false)
	t.ok(_v(st, "HP_GEN") == 1 and _v(st, "PHASE_X") == 0, "냉동 칸 재가동")
