## 단계 1-D5a 여의도 금탑 로비 · 지하 수족관(DG-KT, SD-09a L-R02-05 · SD-05 UQ-68 · SD-07b N-R02-030 · 1-D 계획 §11.3~11.7):
## 자료(맵 둘 · 던전 표 · 개미 · 메기) · 발전기 연료 한 통(배수 · 승강기 · 들고 나감 — 하나만) · 물이 빠지면 바닥이 마르고 메기 새끼가 없다 ·
## 메기는 물 밖으로 안 나온다 · 수염(물에 선 사람은 은신 무효) · 어하은 인터폰(첫 통화 · 이미 앎 판 · 죽음 판 녹음) · 회전문 꾀기 · 유리 터널.
extends RefCounted


func _host(map_id := "KT-01", mark := "from_W") -> Array:
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
	var c := Kt.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: Kt, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 300:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "kt":
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


func _count(h: InteriorHost, id: String) -> int:
	var n := 0
	for e in h.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == id:
			n += 1
	return n


func test_kt_data(t) -> void:
	for m in ["KT-01", "KT-02"]:
		t.ok(InteriorMap.exists(m), "맵 " + m)
	var dg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dungeons.json"))
	var d: Dictionary = (dg["dungeons"] as Dictionary).get("DG-KT", {})
	t.ok(not d.is_empty() and str(d.get("clear", "")) == "KT_QUEEN >= 1" and str(d.get("lid", "")) == "L-R02-05", "던전 표 DG-KT · 정리는 22층 여왕(1-D5b)")
	var en: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	var rows: Dictionary = en.get("rows", en)
	for id in ["CR-080", "CR-081", "CR-082", "CR-130"]:
		t.ok(rows.has(id), "적 자료 " + id)
	for s in ["cr_cr080_loco", "cr_cr081_loco", "cr_cr082_loco", "cr_cr130_loco"]:
		t.ok(ResourceLoader.exists("res://assets/sprites/%s.tres" % s), "그림 " + s)
	var r := _host()
	var h: InteriorHost = r[0]
	t.eq(_count(h, "CR-080"), 2, "로비 개미 정찰 둘(승강기를 안 살렸으면)")


## 발전기 연료 한 통: 배수 → 물이 빠지고 메기 새끼가 쓸려 나감 · 다른 쪽은 고를 수 없다
func test_kt_drain(t) -> void:
	var r := _host("KT-02", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	t.eq(_count(h, "CR-130"), 3, "메기 새끼 셋(물속 매복)")
	t.ok(h.map.wet_at(Vector2i(33, 17)) == 2, "남동쪽 허리 물")
	t.eq(_play(st, c, "KT_PUMP", ["A — 배수"]), [], "배수 펌프")
	t.ok(_v(st, "KT_POWER") == 1 and _v(st, "KT_POWER_DAY") == 10, "연료 한 통 — 배수(고른 날)")
	t.eq(_count(h, "CR-130"), 0, "메기 새끼가 배수구로 쓸려 나감")
	h.enter("KT-02", "pump")
	t.ok(h.map.wet_at(Vector2i(33, 17)) == 0 and h.map.wet_at(Vector2i(39, 6)) == 0, "다시 들어서면 바닥이 말랐다(승강로 바닥까지)")
	t.eq(_count(h, "CR-130"), 0, "마른 수족관엔 메기가 없다")
	t.ok(_texts(st, "KT_PUMP").contains("배수관"), "펌프는 돌고 있다")
	c._power(2)
	t.eq(_v(st, "KT_POWER"), 1, "되돌릴 수 없다(한쪽만)")
	t.eq(_play(st, c, "KT_CAR", ["그만"]), [], "물이 빠진 꺼진 칸")
	t.eq(_v(st, "KT_CAR"), 1, "꺼진 칸에 닿음")


## 승강기 · 들고 나감
func test_kt_lift_take(t) -> void:
	var r := _host("KT-02", "from_W")
	var st: StoryState = r[1]
	var c: Kt = r[2]
	t.eq(_play(st, c, "KT_PUMP", ["B — 화물"]), [], "화물 승강기")
	t.eq(_v(st, "KT_POWER"), 2, "승강기")
	var h: InteriorHost = r[0]
	h.enter("KT-01", "from_W")
	t.eq(_count(h, "CR-080"), 3, "승강로를 타고 내려온 정찰이 로비에 하나 더")
	t.ok(_texts(st, "KT_CARGO").contains("초록 등"), "화물 승강기 등")
	var r2 := _host("KT-02", "from_W")
	var st2: StoryState = r2[1]
	var c2: Kt = r2[2]
	t.eq(_play(st2, c2, "KT_PUMP", ["챙긴다"]), [], "연료 통을 챙긴다")
	t.ok(_v(st2, "KT_POWER") == 3 and int(st2.items.get("화염방사기 연료", 0)) >= 30, "휘발유(화염방사기 연료)")


## 메기: 물 밖으로 안 나온다 · 물에 선 사람은 수염으로 안다(은신 무효)
func test_kt_catfish(t) -> void:
	var r := _host("KT-02", "from_W")
	var h: InteriorHost = r[0]
	var fish: Enemy = null
	for e in h.combat.enemies:
		if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-130":
			fish = e
	t.ok(fish != null and fish.aqua and fish.lurk, "메기 새끼 — 물 칸 · 매복")
	t.ok(fish.cmb.max_hp < 180.0, "새끼(lv 4 — 다 큰 메기 180보다 약하다)")
	var wet := 0
	for y in h.map.size.y:
		for x in h.map.size.x:
			if h.map.wet_at(Vector2i(x, y)) > 0:
				wet += 1
	t.ok(wet > 60, "수족관 물 칸")


## 어하은 인터폰: 첫 통화(녹음 → 목소리) · 이미 앎 판 · 둘째부터 짧게 · 승강기 4번 기억 · 죽음 판은 녹음만
func test_kt_phone(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: Kt = r[2]
	var first := _texts(st, "KT_PHONE")
	t.ok(first.contains("잠시 점검 중") and first.contains("어하은입니다"), "첫 통화 — 녹음 다음 목소리")
	t.ok(not first.contains("북방"), "'북방'은 60층에 남긴다")
	t.eq(_play(st, c, "KT_PHONE", ["승강기 4번", "전망대에서", "끊는다"]), [], "통화 — 승강기 4번 · 망원경")
	t.ok(_v(st, "KT_MEM") == 1 and _v(st, "KT_HOOK") == 1 and _v(st, "KT_CALL") >= 1, "기억 · 훅")
	t.ok(not _texts(st, "KT_PHONE").contains("잠시 점검 중"), "둘째부터 녹음 멘트를 되풀이하지 않는다")
	var r2 := _host()
	var st2: StoryState = r2[1]
	st2.vars.set_v("KT_POWER", 2)
	t.ok(_texts(st2, "KT_PHONE").contains("15명 정원"), "이미 앎 — 첫 통화가 선택 뒤면 결과를 먼저 말한다")
	st2.vars.set_v("V_ACT", 2)
	t.ok(_texts(st2, "KT_PHONE").contains("군복 입은 손님"), "1막 뒤 — 관측조 예고")
	st2.kill("N-R02-030")
	var tape := _texts(st2, "KT_PHONE")
	t.ok(tape.contains("받는 사람이 없다") and not tape.contains("어하은입니다"), "죽음 판 — 녹음만")


## 로비 벨: 통화한 적 없으면 들어설 때 세 번 울리고 그친다
func test_kt_ring(t) -> void:
	var r := _host()
	var c: Kt = r[2]
	t.eq(c._ring_n, Kt.RINGS, "로비에 들어서면 벨")
	var st: StoryState = r[1]
	st.vars.set_v("KT_CALL", 1)
	var h: InteriorHost = r[0]
	h.enter("KT-01", "from_W")
	t.eq(c._ring_n, 0, "통화했으면 벨이 없다")


## 회전문 꾀기: 곁의 일개미가 갇힘 → 깨고 나옴(깨짐 판) · 남은 정찰은 길을 잃는다
func test_kt_revolve(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	var ants: Array = h.combat.enemies.filter(func(e): return is_instance_valid(e) and str(e.row.get("id", "")) == "CR-080")
	var a0: Enemy = ants[0]
	a0.loco.logical = c._tc(Kt.DOOR_AT)
	c._spin()
	t.ok(_v(st, "KT_REVOLVE") == 1 and _count(h, "CR-080") == 1, "곁의 일개미가 회전문 칸에 갇힘")
	var other: Enemy = h.combat.enemies.filter(func(e): return is_instance_valid(e) and str(e.row.get("id", "")) == "CR-080")[0]
	t.ok(other.route.is_empty(), "냄새 길이 끊겨 남은 정찰이 길을 잃음")
	c._trap_t = 0.0
	c._process(0.1)
	t.ok(_v(st, "KT_REVOLVE") == 2 and _count(h, "CR-080") == 2, "유리를 깨고 나옴 — 회전문 깨짐 판")


## 유리 터널을 깨면: 넘어짐 · 피해 · 다시 들어서면 터널이 허리 물
func test_kt_tunnel(t) -> void:
	var r := _host("KT-02", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	t.eq(h.map.wet_at(Vector2i(16, 12)), 0, "터널 서쪽은 마른 길")
	t.eq(_play(st, c, "KT_TUNNEL", ["개머리판"]), [], "금 간 유리를 친다")
	t.eq(_v(st, "KT_TUNNEL"), 1, "터널이 깨짐")
	h.enter("KT-02", "tunnel_w")
	t.eq(h.map.wet_at(Vector2i(16, 12)), 2, "다시 들어서면 터널이 허리 물")
