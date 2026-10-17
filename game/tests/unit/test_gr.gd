## 단계 1-D4 구로 차량기지(DG-GR, SD-09a L-R02-25 · SD-14 CR-205 · 1-D 계획 §10 · §10.7):
## 자료(맵 일곱 · 던전 표 · 소품) · 입환(레버 순서 · 밀기 둘 · 되돌릴 수 없음 · 이미 된 길) · 출발 진행 = 정리 · 버스 노심(밀기 셋 · UQ71_CORE 6) ·
## 냉장 화차 · 분실물함 정기권 · 측량조(다음 날 · 소장 · 실장 둘 다 죽으면 없음) · 떠돌이(부탁 · 떠남) · 수송 열차 '안 간 사람들'(휴면 · 호루라기 기립).
extends RefCounted


func _host(map_id := "GR-02", mark := "from_X") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	st.vars.set_v("PC_CAPS", 100)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  10:00"
	st.vars.set_v("GAME_HOUR", 10)
	var c := Gr.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: Gr, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "gr":
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


func _opts(st: StoryState, id: String) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var g := 0
	while cur["type"] != "choices" and cur["type"] != "end" and g < 80:
		g += 1
		cur = dr.advance()
	return (cur.get("opts", []) as Array).map(func(o): return str(o["text"]))


func test_gr_data(t) -> void:
	for m in ["GR-01", "GR-02", "GR-03", "GR-04", "GR-05", "GR-06"]:
		t.ok(InteriorMap.exists(m), "맵 " + m)
	var dg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dungeons.json"))
	var d: Dictionary = (dg["dungeons"] as Dictionary).get("DG-GR", {})
	t.ok(not d.is_empty() and str(d.get("clear", "")) == "GR_STAFF >= 1" and str(d.get("lid", "")) == "L-R02-25", "던전 표 DG-GR · 정리 식 · 장소")
	var r := _host()
	var h: InteriorHost = r[0]
	t.ok(h.map.props.any(func(p): return str(p["name"]) == "loco_atomic"), "정비고 기관차 7703")
	t.ok(h.map.soil_at(Vector2i(31, 13)), "무너진 피트 흙(굴쥐)")


## 입환: 앞에서 꺾인 레버가 길을 정한다 · 대기 출력 두 번 · 되돌릴 수 없다 · 이미 된 길은 밀기를 쓰지 않는다 · C = 출발 진행(정리)
func test_gr_shunt(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Gr = r[2]
	t.ok(not _opts(st, "GR_LOCO").any(func(x): return str(x).contains("버스 노심")), "버스 노심이 없으면 꽂는 선택지가 없다")
	c._cmd(["wake"], func() -> void: pass)
	t.ok(_v(st, "GR_CORE") == 1 and _v(st, "GR_PUSH") == Gr.PUSHES and _v(st, "GR_CORE_DAY") == 10, "대기 출력 · 밀기 둘")
	c._push()
	t.eq(_v(st, "GR_PUSH"), 2, "레버가 다 곧으면 밀기를 쓰지 않는다")
	t.eq(_play(st, c, "GR_LEVER_B", ["넘긴다"]), [], "레버 B")
	t.eq(_play(st, c, "GR_LEVER_C", ["넘긴다"]), [], "레버 C")
	t.eq(c.route(), "B", "A가 곧으면 B가 먼저(전철기 표 순서)")
	c._push()
	t.ok(_v(st, "GR_B") == 1 and _v(st, "GR_C") == 0 and _v(st, "GR_PUSH") == 1, "B — 무개차를 밀어냄(관통 출구)")
	c._push()
	t.eq(_v(st, "GR_PUSH"), 1, "B는 이미 됐다 — 레버를 바꾸기 전엔 밀기를 쓰지 않는다")
	t.eq(_play(st, c, "GR_LEVER_B", ["되돌린다"]), [], "레버 B 되돌림")
	c._push()
	t.ok(_v(st, "GR_C") == 1 and _v(st, "GR_STAFF") == 2 and _v(st, "DG_GR") == 1, "C — 수송 열차에 연결 · 출발 진행 = 던전 정리")
	t.eq(_v(st, "GR_A"), 0, "셋 중 둘 — 냉장 화차는 그대로(A 못 함)")
	t.ok(_play(st, c, "GR_ORDER").is_empty(), "운행 지령 단말(이행)")


## 대기 출력 두 번 → 노심이 다시 잠든다(C가 아닌 길)
func test_gr_sleep(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Gr = r[2]
	c._cmd(["wake"], func() -> void: pass)
	c._cmd(["lever", "A"], func() -> void: pass)
	c._push()
	t.eq(_v(st, "GR_A"), 1, "A — 냉장 화차가 정비고 앞")
	c._cmd(["lever", "A"], func() -> void: pass)
	c._cmd(["lever", "B"], func() -> void: pass)
	c._push()
	t.ok(_v(st, "GR_B") == 1 and _v(st, "GR_PUSH") == 0 and _v(st, "GR_CORE") == 2, "두 번 밀면 노심이 다시 잠든다")
	c._cmd(["lever", "B"], func() -> void: pass)
	c._cmd(["lever", "C"], func() -> void: pass)
	c._push()
	t.ok(_v(st, "GR_C") == 0 and _v(st, "GR_STAFF") == 0, "잠든 뒤엔 C를 못 한다(되돌릴 수 없음)")
	t.eq(_play(st, c, "GR_REEFER"), [], "정비고 앞 화차 — 크레인 고리로 연다")
	t.ok(_v(st, "GR_REEFER") == 1 and int(st.items.get("I-004", 0)) == 3 and int(st.items.get("I-001", 0)) >= 2, "군 의무 보급(수혈 팩 · 스팀팩)")


## 대방 버스 노심(엉뚱한 짓): 판정 없이 깨고 밀기 셋 · UQ-71 노심의 행방 6
func test_gr_bus(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Gr = r[2]
	st.call_fn("give", ["M-392", 1])
	st.vars.set_v("UQ71_CORE", 2)
	t.eq(_play(st, c, "GR_LOCO", ["버스 노심"]), [], "버스 노심을 꽂는다")
	t.ok(_v(st, "GR_CORE") == 1 and _v(st, "GR_PUSH") == Gr.BUS_PUSHES and _v(st, "GR_BUS") == 1, "밀기 셋")
	t.ok(_v(st, "UQ71_CORE") == 6 and not bool(st.call_fn("has", ["M-392"])), "노심은 7703에 들어가 다 탐(상인회 판매 닫힘)")


## 열쇠꾸러미 · 분실물함 정기권 · 신호 초소 열쇠 → 호루라기
func test_gr_keys(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Gr = r[2]
	t.eq(_play(st, c, "GR_DRIVER", ["챙긴다"]), [], "기관사 유해")
	t.eq(_v(st, "GR_KEY"), 1, "열쇠꾸러미")
	t.eq(_play(st, c, "GR_LOST", ["열쇠꾸러미"]), [], "분실물함")
	t.ok(_v(st, "GR_LOST") == 1 and bool(st.call_fn("has", ["M-071"])), "정기권 M-071")
	t.ok(not _opts(st, "GR_LOCKER").any(func(x): return str(x).contains("신호 초소 열쇠")), "열쇠 없으면 열쇠 선택지가 없다")
	t.eq(_play(st, c, "GR_INSPECT", ["챙긴다"]), [], "검측원 책상")
	t.eq(_play(st, c, "GR_LOCKER", ["신호 초소 열쇠"]), [], "신호원 함")
	t.eq(_v(st, "GR_WHISTLE"), 1, "호루라기")


## 06:00: 측량조(깨운 다음 날) → 떠돌이 떠남(그다음 날) · 소장 · 실장 둘 다 죽었으면 측량조 없음
func test_gr_days(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Gr = r[2]
	c._cmd(["wake"], func() -> void: pass)
	c._on_day(10)
	t.eq(_v(st, "GR_SB"), 0, "깨운 날엔 아직")
	c._on_day(11)
	t.ok(_v(st, "GR_SB") == 1 and _v(st, "GR_SB_DAY") == 11, "다음 날 06:00 측량조")
	c._on_day(12)
	t.eq(_v(st, "GR_DRIFT"), 2, "그다음 날 떠돌이가 떠난다")
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: Gr = r2[2]
	st2.kill("C-013")
	st2.kill("C-049")
	c2._cmd(["wake"], func() -> void: pass)
	c2._on_day(11)
	t.eq(_v(st2, "GR_SB"), 0, "소장 · 실장 둘 다 죽었으면 장부쟁이가 오지 않는다")


## 떠돌이 부탁(재미 검수 뒤): 쥐가 물어 간 군번줄 찾기 — 쥐를 다 잡지 않아도 둥지에서 집을 수 있다 · 명부의 이름으로 이어진다
func test_gr_drift(t) -> void:
	var r := _host("GR-04", "from_X")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Gr = r[2]
	t.eq(_play(st, c, "GR_DRIFT", ["부탁"]), [], "떠돌이 부탁")
	t.eq(_v(st, "GR_DRIFT"), 1, "부탁 받음")
	for e in h.combat.enemies.duplicate():
		if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-095":
			e.cmb.dead = true
			h.combat.enemies.erase(e)
	h.combat.enemy_killed.emit("CR-095", 0)
	t.eq(_v(st, "GR_RATS"), 1, "쥐 둥지 비움")
	t.eq(_play(st, c, "GR_DRIFT"), [], "쥐만 잡고 오면 — 군번줄은?")
	t.eq(_v(st, "GR_DRIFT"), 1, "쥐만으로는 부탁이 끝나지 않는다")
	t.eq(_play(st, c, "GR_NEST", ["집는다"]), [], "둥지에서 군번줄")
	t.eq(_v(st, "GR_TAG"), 1, "군번줄 지님")
	t.eq(_play(st, c, "GR_DRIFT"), [], "보답")
	t.ok(_v(st, "GR_DRIFT") == 3 and _v(st, "GR_TAG") == 2 and int(st.items.get("I-006", 0)) >= 1, "통조림 · 부목 · 군번줄은 떠돌이에게")
	t.ok(_play(st, c, "GR_ROSTER").is_empty(), "출정 명부 — 군번줄의 이름(최병규)")
	var r2 := _host("GR-04", "from_X")
	var st2: StoryState = r2[1]
	var c2: Gr = r2[2]
	t.eq(_play(st2, c2, "GR_NEST", ["집는다"]), [], "부탁 전에 먼저 집어도")
	t.eq(_play(st2, c2, "GR_DRIFT", ["부탁"]), [], "부탁을 듣는 자리에서 바로 건넨다")
	t.eq(_v(st2, "GR_DRIFT"), 3, "부탁 끝")


## 우회의 대가(재미 검수 ③): 억지로 연 냉장 화차는 절반 · 손으로 민 무개차는 소리(역무원이 서쪽 끝으로) · 독산 수첩 복선
func test_gr_cost(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Gr = r[2]
	st.vars.set_v("GR_KEY", 1)
	t.eq(_play(st, c, "GR_REEFER", ["냉장 3"]), [], "제자리 화차를 열쇠로")
	t.ok(_v(st, "GR_REEFER") == 1 and int(st.items.get("I-004", 0)) == 1 and int(st.items.get("I-092", 0)) == 0, "밀봉이 터져 절반만")
	c._cmd(["flat"], func() -> void: pass)
	t.ok(_v(st, "GR_B") == 2 and c._alarm_at == Gr.FLAT_AT and c._alarm_until > c._now_s, "쿵 — 역무원이 서쪽 끝을 살피러 온다")
	t.eq(_play(st, c, "GR_TIP"), [], "독산 4호 사냥꾼 수첩")
	t.eq(_v(st, "GR_TIP"), 1, "읽은 사실이 남는다(냉장 화차 대사가 그걸 본다)")


## 박에게 정기권(엉뚱한 짓): 안내하는 사람이 박일 때만 · 정기권을 잃고 박은 퇴근 · 남은 김이 쓰러지면 정리 · 휴게실 자리는 산 사람만
func test_gr_park(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Gr = r[2]
	st.call_fn("give", ["M-071", 1])
	st.vars.set_v("GR_LOST", 1)
	st.vars.set_v("GR_GUIDE", 1)
	t.ok(not _opts(st, "GR_ESCORT").any(func(x): return str(x).contains("정기권")), "김에게는 내밀 수 없다(이름 칸 '박')")
	st.vars.set_v("GR_GUIDE", 2)
	t.eq(_play(st, c, "GR_ESCORT", ["정기권"]), [], "박에게 정기권을 내민다")
	t.ok(_v(st, "GR_PARK") == 10 and not bool(st.call_fn("has", ["M-071"])), "박이 퇴근 · 정기권을 잃는다")
	t.eq(_v(st, "GR_STAFF"), 0, "김이 남아 아직 정리 아님")
	c._on_kill("CR-205", 0)
	t.ok(_v(st, "GR_STAFF_K") == 1 and _v(st, "GR_STAFF") == 1 and _v(st, "DG_GR") == 1, "김이 쓰러지면 구내가 빈다 — 정리")
	var r2 := _host("GR-01", "from_a")
	var h2: InteriorHost = r2[0]
	var st2: StoryState = r2[1]
	st2.vars.set_v("GR_STAFF", 2)
	st2.vars.set_v("GR_STAFF_K", 2)
	h2.enter("GR-02", "from_X")
	var n := 0
	for e in h2.combat.enemies:
		if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-205":
			n += 1
	t.eq(n, 1, "박이 쓰러진 판 — 휴게실 의자엔 김 하나")


## 수송 열차 '안 간 사람들': 휴면으로 앉아 있다 · 호루라기 '기립' → 비적대로 문 쪽 · 집결
func test_gr_muster(t) -> void:
	var r := _host("GR-01", "from_a")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Gr = r[2]
	var n := 0
	for e in h.combat.enemies:
		if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-204" and e.asleep:
			n += 1
	t.eq(n, Gr.STAY, "앉아서 조는 다섯")
	st.vars.set_v("GR_WHISTLE", 1)
	t.eq(_play(st, c, "GR_TRAIN", ["호루라기"]), [], "호루라기 — 기립")
	t.eq(_v(st, "GR_MUSTER"), 1, "기립 · 집결")
	t.ok(c.stayers.all(func(e): return not is_instance_valid(e) or (not e.asleep and e.cmb.team == "calm_gr")), "일어나서 비적대")
	t.ok(_play(st, c, "GR_ROSTER").is_empty(), "출정 명부")


## 열차가 이미 움직인 뒤 호루라기: 내리지 않고 고개를 들고 다시 앉는다(GR_MUSTER 3) — 다시 들어가도 덤비지 않는다
func test_gr_aboard(t) -> void:
	var r := _host("GR-01", "from_a")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Gr = r[2]
	st.vars.set_v("GR_C", 1)
	st.vars.set_v("GR_WHISTLE", 1)
	t.eq(_play(st, c, "GR_TRAIN", ["호루라기"]), [], "호루라기 — 이미 출발한 열차")
	t.ok(_v(st, "GR_MUSTER") == 3 and _v(st, "GR_MUSTER_DAY") == 10, "다시 앉음")
	h.enter("GR-04", "from_X")
	h.enter("GR-01", "from_a")
	var calm := 0
	for e in h.combat.enemies:
		if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-204" and e.cmb.team == "calm_gr":
			calm += 1
	t.eq(calm, Gr.STAY, "다섯이 비적대로 앉아 있다")
