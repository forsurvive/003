## 단계 1-D7 구로 공단 지식산업센터 · 문래 철공소 골목(DG-KS · UQ-69, SD-09a L-R02-21 · L-R02-14 · SD-05 §3.21 · 1-D 계획 §13.5):
## 자료(맵 일곱 · 던전 표 · 장면 · M-395~M-396 · M-197 · M-198 · 상인 셋) · 라인 박자(경고 셋 → 적대 · 숙련자 재량 · 감시포 사각) ·
## 11월 서류 다섯 갈래(이관 · 110% · 퇴근 · 오타 → 비상정지 · 진짜 서류) · 금형(크레인 → 하역장 → 다음 06:00 수레 · 손으로 · 버림) ·
## 강탈 · 하루 일하기 · 무기 값 −5% · 공구 사물함.
extends RefCounted


func _host(map_id := "KS-02", mark := "from_KS01") -> Array:
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
	var c := Ks.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _tc(c: Vector2i) -> Vector2:
	return Vector2(c) * 32.0 + Vector2(16, 16)


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: Ks, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "ks":
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


func _sci(st: StoryState, n: int) -> void:
	st.vars.set_v("PC_SKP_" + st.skill_key("과학"), n)


func _units(c: Ks) -> Array:
	return c.units()


func test_ks_data(t) -> void:
	for m in ["KS-01", "KS-02", "KS-03", "X-MR", "MR-01", "MR-02", "MR-03"]:
		t.ok(FileAccess.file_exists("res://data/maps/%s.json" % m), "맵 %s" % m)
	for s in ["KS_CARD", "KS_MONITOR", "KS_CHIMNEY", "KS_FAX", "KS_PRESS", "KS_BOARD", "KS_BENCH", "KS_SLOT", "KS_ESTOP", "KS_CRANE", "KS_DROP",
			"KS_MO", "KS_TYPE", "MR_SEONG", "MR_YEON", "MR_YONG", "MR_BOARD", "MR_LOCKER"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % s), "장면 %s" % s)
	var r := _host()
	var h: InteriorHost = r[0]
	for id in ["M-395", "M-396", "M-197", "M-198"]:
		t.ok(h.items_db.has(id), "아이템 %s" % id)
	var mer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	for vid in ["VMR1", "VMR1N", "VMR2"]:
		t.ok(mer.has(vid), "상인 %s" % vid)
	t.ok(int((mer["VMR1N"]["fix"] as Dictionary)["cap"]) < int((mer["VMR1"]["fix"] as Dictionary)["cap"]), "금형 뒤 총열째 새로(정비 상한이 한 단 위)")
	var dg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dungeons.json"))
	var found := false
	var dd = dg["dungeons"]
	for d in (dd.values() if typeof(dd) == TYPE_DICTIONARY else dd):
		if typeof(d) == TYPE_DICTIONARY and str(d.get("lid", "")) == "L-R02-21":
			found = true
	t.ok(found, "던전 표 @KS(L-R02-21)")
	var ids := []
	for e in h.combat.enemies:
		ids.append(str(e.row["id"]))
	t.ok(ids.count("CR-326") == 2 and ids.count("CR-320") == 2, "공장층 성형-4 둘 · 감시포 둘 %s" % str(ids))


func test_ks_rhythm(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ks = r[2]
	for e in _units(c):
		t.ok(e.cmb.team == "calm_ks" and not ("player" in e.foes), "라인 설비는 처음엔 작업자를 노리지 않는다")
	var robot = _units(c).filter(func(e): return str(e.row["id"]) == "CR-326")[0]
	c._t = 10.0
	c._warn_step(robot, Vector2i(22, 15))
	t.ok(c._warn == 1 and not c._hot, "경고 하나")
	c._warn_step(robot, Vector2i(22, 15))
	c._warn_step(robot, Vector2i(22, 15))
	t.ok(c._hot, "경고 셋 → 라인 적대")
	for e in _units(c):
		t.ok("player" in e.foes, "적대 뒤엔 노린다")
	h.enter("KS-01", "from_KS02")
	h.enter("KS-02", "from_KS01")
	t.ok(not c._hot and _units(c).all(func(e): return e.cmb.team == "calm_ks"), "나갔다 오면 공장장이 다시 돌린다(방문 한정)")
	t.ok(c._warn == 1, "같은 날 다시 오면 경고 하나를 안고 시작")
	st.vars.set_v("KS_WARN", 0)
	st.vars.set_v("KS_WORK_N", 1)
	h.enter("KS-01", "from_KS02")
	h.enter("KS-02", "from_KS01")
	robot = _units(c).filter(func(e): return str(e.row["id"]) == "CR-326")[0]
	c._warn_step(robot, Vector2i(22, 15))
	t.ok(c._warn == 0, "하루 일한 사람 — 첫 경고는 숙련자 재량")
	st.vars.set_v("KS_CARD", 1)
	st.vars.set_v("KS_CARD_N", 2)
	t.ok(c.card_name() == "이동철", "출근 카드 이름으로 부른다")


func test_ks_idle(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var c: Ks = r[2]
	var tur = _units(c).filter(func(e): return str(e.row["id"]) == "CR-320")[0]
	tur.loco.facing = 4
	var tt := h.map.tile_of(tur.loco.logical)
	h.player.loco.logical = _tc(tt + Vector2i(-4, 0))
	c._t = 10.0
	c._warn_t = -99.0
	for i in 8:
		c._floor(0.2)
	t.ok(c._warn >= 1, "노란 테 밖 감시포 앞에 서 있으면 '무단 정지' 경고")
	var w := c._warn
	h.player.loco.logical = _tc(Vector2i(20, 15))
	c._warn_t = -99.0
	for i in 8:
		c._floor(0.2)
	t.ok(c._warn == w, "노란 테 안은 작업자")


func test_ks_turret_blind(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var c: Ks = r[2]
	var tur = _units(c).filter(func(e): return str(e.row["id"]) == "CR-320")[0]
	tur.loco.facing = 4                                                   # 서쪽
	var tt := h.map.tile_of(tur.loco.logical)
	h.player.loco.logical = _tc(tt + Vector2i(-4, 0))
	t.ok(c._seen_by(tt + Vector2i(-4, 0)) == tur, "감시포 앞 4칸은 보인다")
	h.player.loco.logical = _tc(tt + Vector2i(-1, 0))
	t.ok(c._seen_by(tt + Vector2i(-1, 0)) == null, "바로 아래(1칸)는 사각")
	h.player.loco.logical = _tc(tt + Vector2i(4, 0))
	t.ok(c._seen_by(tt + Vector2i(4, 0)) == null, "등 뒤는 못 본다")


func test_ks_paper_transfer(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ks = r[2]
	t.ok(_play(st, c, "KS_MO", ["그만 가"]).is_empty(), "모준서 첫 대면")
	t.ok(_v(st, "UQ69_MET") == 1 and st.quests.stage("UQ-69") == 20, "만남 → 20단계")
	_sci(st, 90)
	t.ok(_play(st, c, "KS_TYPE", ["본사 서식", "이관"]).is_empty(), "타자기 — 이관")
	t.ok(_v(st, "UQ69_PAPER") == 1 and _v(st, "KS_LINE") == -1, "이관 → 라인 멈춤")
	t.ok(st.quests.stage("UQ-69") == 30, "30단계")
	t.ok(_play(st, c, "KS_PRESS", ["금형을 뺀다"]).is_empty(), "프레스에서 금형을 뺀다")
	t.ok(int(st.call_fn("has", ["M-395"])) == 1 and _v(st, "UQ69_DIE") == 1, "금형을 들었다")
	t.ok(is_equal_approx(h.carry_mul, 0.6), "과적 — 걸음 0.6")
	t.ok(_opts(st, "KS_DROP").contains("성씨 선반"), "이관 통보서면 성씨가 몰라도 리어카")
	c.crane()
	t.ok(_v(st, "UQ69_DIE") == 6 and int(st.call_fn("has", ["M-395"])) == 0, "크레인 → 하역장")
	t.ok(_v(st, "UQ69_DEST") == 2, "이관 통보서 — 리어카가 알아서")
	st.vars.set_v("UQ69_DEST", 0)
	t.ok(_play(st, c, "MR_SEONG", ["그만 간다"]).is_empty(), "성태경 — 금형 얘기")
	t.ok(_v(st, "UQ69_HEARD") == 1, "들음")
	t.ok(_play(st, c, "KS_DROP", ["성씨 선반"]).is_empty(), "분필 '성씨 선반'")
	t.ok(_v(st, "UQ69_DEST") == 2, "행선지 문래")
	c._on_day(10)
	t.ok(_v(st, "UQ69_DIE") == 6, "같은 날엔 안 온다(P6)")
	var jc := _v(st, "AFF_JC")
	c._on_day(11)
	t.ok(_v(st, "UQ69_DIE") == 2 and st.quests.stage("UQ-69") == 100, "다음 06:00 리어카 → 문래 · 끝")
	t.ok(_v(st, "AFF_JC") == jc + 3, "JC +3")
	t.ok(_opts(st, "MR_SEONG").contains("총을 손본다"), "금형 뒤 성태경 정비")


func test_ks_typo_estop(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Ks = r[2]
	_play(st, c, "KS_MO", ["그만 가"])
	_sci(st, -90)
	t.ok(_play(st, c, "KS_TYPE", ["어림짐작"]).is_empty(), "타자기 — 어림짐작 → 오타")
	t.ok(_v(st, "UQ69_PAPER") == 4 and _v(st, "KS_LINE") == 1, "1030% — 두 배 박자")
	t.ok(not _opts(st, "KS_PRESS").contains("금형을 뺀다"), "가동 중 — 금형은 못 뺀다")
	t.ok(_play(st, c, "KS_ESTOP", ["누른다"]).is_empty(), "비상정지")
	t.ok(_v(st, "KS_LINE") == -1 and _v(st, "KS_ESTOP") == 1, "라인 멈춤")
	t.ok(_opts(st, "KS_PRESS").contains("금형을 뺀다"), "이제 금형을 뺄 수 있다")
	c.take_die()
	c.crane()
	t.ok(_v(st, "UQ69_DEST") == 0 and not _opts(st, "KS_DROP").contains("성씨 선반"), "오타 판 · 성씨가 모르면 리어카를 못 부른다")


func test_ks_rerun_and_home(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Ks = r[2]
	_play(st, c, "KS_MO", ["그만 가"])
	_sci(st, 90)
	_play(st, c, "KS_TYPE", ["본사 서식", "110%"])
	t.ok(_v(st, "UQ69_DIE") == 4 and _v(st, "KS_LINE") == 2 and st.quests.stage("UQ-69") == 100, "110% → 재가동 · 끝")
	t.ok(not _opts(st, "KS_PRESS").contains("금형을 뺀다"), "재가동 금형은 빠지지 않는다")
	c._on_day(10 + 7)
	t.ok(_v(st, "UQ69_HALF") == 1, "주마다 반제품 하나")
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: Ks = r2[2]
	_play(st2, c2, "KS_MO", ["그만 가"])
	c2.paper(3)
	t.ok(_v(st2, "UQ69_PAPER") == 3 and _v(st2, "KS_LINE") == -1 and _v(st2, "KS_STAMP") >= 1, "전원 퇴근 — 라인 정지 · 퇴근 도장")
	c2.paper(1)
	t.ok(_v(st2, "UQ69_PAPER") == 3, "서류는 한 번(P1)")
	st2.vars.set_v("KS_CARD", 1)
	t.ok(_play(st2, c2, "KS_CARD", ["퇴근 칸"]).is_empty(), "전원 퇴근 뒤 내 카드를 퇴근 칸에")
	var h2: InteriorHost = r2[0]
	st2.vars.set_v("GAME_DAY", _v(st2, "KS_STAMP") + 1)
	h2.enter("KS-01", "from_KS02")
	h2.enter("KS-02", "from_KS01")
	t.ok(not h2.npcs.any(func(n): return str(n["id"]) == "N-R02-049" and is_instance_valid(n["actor"]) and n["actor"].visible), "다음 날 공장장은 퇴근했다(빈 의자)")
	t.ok(_opts(st2, "KS_TYPE") == "", "결재할 사람이 없다")


func test_ks_sb_by_hand(t) -> void:
	var r := _host("MR-03", "from_X")
	var st: StoryState = r[1]
	var c: Ks = r[2]
	st.call_fn("give", ["M-395", 1])
	st.vars.set_v("UQ69_DIE", 1)
	var caps := _v(st, "PC_CAPS")
	var sb := _v(st, "AFF_SB")
	t.ok(_play(st, c, "MR_YONG", ["넘긴다"]).is_empty(), "용두식에게 넘긴다")
	t.ok(_v(st, "UQ69_DIE") == 3 and _v(st, "PC_CAPS") == caps + 400 and _v(st, "AFF_SB") == sb + 4, "② 400캡 · SB +4")
	t.ok(st.quests.stage("UQ-69") == 100, "끝")
	t.ok(not _opts(st, "MR_SEONG").contains("총을 손본다"), "② 뒤 성태경 개조 끊김")
	var r2 := _host("MR-03", "from_X")
	var st2: StoryState = r2[1]
	st2.call_fn("give", ["M-395", 1])
	st2.kill("C-013")
	st2.kill("C-049")
	t.ok(not _opts(st2, "MR_YONG").contains("넘긴다"), "새벽인력 소장 · 실장이 죽었으면 ② 없음")


func test_ks_mo_lines(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Ks = r[2]
	c._stop_line("설비 파손")
	t.ok(_play(st, c, "KS_MO", []).is_empty() and _v(st, "UQ69_MET") == 1, "설비를 부숴 세웠다 — 모준서 '설비 파손' 판")
	st.vars.set_v("UQ69_PAPER", 1)
	st.vars.set_v("UQ69_DIE", 3)
	st.vars.set_v("UQ69_DONE_DAY", 9)
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene("KS_MO"))
	var txt := ""
	var g := 0
	while cur["type"] != "end" and g < 20:
		g += 1
		txt += str(cur.get("text", ""))
		cur = dr.advance()
	t.ok(txt.contains("문래"), "이관이라 쳐 놓고 새벽인력에 — 모준서가 안다(하루 뒤)")


func test_ks_robbed(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ks = r[2]
	st.kill("N-R02-049")
	c._tick = 0.0
	c._process(0.3)
	t.ok(_v(st, "KS_ALARM") == 1 and c._hot, "모준서를 해쳤다 → 강탈(라인 적대)")
	t.ok(_opts(st, "KS_PRESS").contains("금형을 뺀다"), "강탈 — 금형은 자유")
	h.enter("KS-01", "from_KS02")
	h.enter("KS-02", "from_KS01")
	t.ok(_units(c).all(func(e): return "player" in e.foes), "다시 와도 적대(영구)")
	t.ok(_opts(st, "KS_TYPE") == "", "결재할 사람이 없다")


func test_ks_telegram(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Ks = r[2]
	_play(st, c, "KS_MO", ["그만 가"])
	_play(st, c, "KS_MONITOR", ["빼낸다"])
	_play(st, c, "KS_CHIMNEY", ["뽑는다"])
	_play(st, c, "KS_FAX", [])
	t.ok(int(st.call_fn("has", ["M-396", 3])) == 1, "전보 조각 셋")
	_play(st, c, "KS_MONITOR", [])
	t.ok(st.count_of("M-396") == 3, "같은 조각은 한 번")
	_sci(st, -90)
	t.ok(_play(st, c, "KS_TYPE", ["전보 세 토막", "전원 퇴근"]).is_empty(), "진짜 서류 — 판정 없이")
	t.ok(_v(st, "UQ69_PAPER") == 3, "전원 퇴근")


func test_ks_workday(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Ks = r[2]
	t.ok(c.can_work() != "", "카드 없이는 못 일한다")
	c.card()
	t.ok(_v(st, "KS_CARD") == 1, "출근 카드")
	t.ok(c.can_work() == "", "일할 수 있다")
	var d0 := _v(st, "GAME_DAY")
	h.advance_minutes(8 * 60)
	st.vars.set_v("KS_WORK_N", 1)
	st.vars.set_v("KS_WORK_DAY", d0)
	t.ok(c.can_work() != "", "주에 한 번")
	c._on_day(d0 + 1)
	t.ok(_v(st, "KS_AWARD") == 1, "다음 날 게시판 — 카드 주인 이름")


func test_ks_drop_die(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Ks = r[2]
	st.call_fn("give", ["M-395", 1])
	st.vars.set_v("UQ69_DIE", 1)
	st.call_fn("take", ["M-395", 1])
	c._die_where()
	t.ok(_v(st, "UQ69_DIE") == 5, "버렸다 — 그 자리가 금형 자리")
	st.call_fn("give", ["M-395", 1])
	c._die_where()
	t.ok(_v(st, "UQ69_DIE") == 1, "다시 쥐면 1")


func test_ks_price_locker(t) -> void:
	var r := _host("MR-01", "from_X")
	var st: StoryState = r[1]
	var c: Ks = r[2]
	var ts := TradeScreen.new()
	var mer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	ts.setup_trade(st, "VMR1", mer["VMR1"], {"items": {}, "caps": 300}, (r[0] as InteriorHost).items_db, 100.0, 30, [1.0, 1.0], [1.0, 1.0], "")
	var p0 := ts.price("W-001", true)
	st.vars.set_v("UQ69_DIE", 2)
	var p1 := ts.price("W-001", true)
	t.ok(p1 < p0 and p1 == maxi(1, roundi(p0 * 0.95)), "문래 금형 뒤 무기 값 −5%% (%d → %d)" % [p0, p1])
	ts.free()
	c.rent()
	t.ok(_v(st, "MR_LOCKER") == 1 and _v(st, "MR_LOCKER_DAY") == _v(st, "GAME_DAY") + 7, "공구 사물함 7일")
	c._on_day(_v(st, "GAME_DAY") + 7)
	t.ok(_v(st, "MR_LOCKER") == 2, "기한이 지나면 성태경이 맡아 둔다")
