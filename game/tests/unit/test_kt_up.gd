## 단계 1-D5b 여의도 금탑 위층(DG-KT — SD-09a L-R02-05 · SD-05 UQ-68 §3.19 · 1-D 계획 §11.9~11.10):
## 맵 여섯 · 던전 표 · 오르는 길 셋(흙벽 마주 파기 · 녹 자국 · 화물 칸 지붕 승강로 · 곤돌라 31/20층) · 육아방 위장 · 소화전으로 알 무더기 고리 끊기 ·
## 여왕 처치 = 정리 · 발전기를 먼저 고치면 개미가 위로(HEAT) · 망원경 점등(BJ +1 · 표시 넷) · UQ-68 단계는 사실로 셈 · 어하은 첫 얼굴 · 신발.
extends RefCounted


func _host(map_id := "KT-01", mark := "from_W") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	st.vars.set_v("KT_CALL", 1)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  10:00"
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
			else:
				for j in cur["opts"].size():                                # 고를 것을 다 골랐으면 '그만'류로 빠진다
					var tx := str(cur["opts"][j]["text"])
					if tx.contains("그만") or tx.contains("내려가 보겠다") or tx.contains("물러난다") or tx.contains("그대로"):
						i = j
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return dr.errors


func _ants(h: InteriorHost, id: String) -> Array:
	return h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == id)


func test_kt_up_data(t) -> void:
	for mid in ["KT-03", "KT-04", "KT-05", "KT-06", "KT-07", "KT-08"]:
		t.ok(FileAccess.file_exists("res://data/maps/%s.json" % mid), "맵 %s" % mid)
	var d := Dungeon.of_map("KT-04")
	t.ok(not d.is_empty() and str(d.get("name", "")) == "여의도 금탑", "22층 여왕방이 금탑 던전에 든다")
	t.ok(str(d.get("bosses", [])).contains("KT-04"), "여왕이 던전 우두머리(처치 기록)")
	var st := StoryState.new()
	st.load_data()
	t.eq(st.quests.stages_of("UQ-68"), [10, 20, 30, 40, 50, 100], "UQ-68 단계표(SD-05 §3.19)")
	t.ok(FileAccess.get_file_as_string("res://data/items_side.json").contains("M-393"), "아이 신발 한 짝(M-393 — SD-13 §7.10)")


## 오르는 길 ① 계단: 흙벽을 파면 20초 뒤 반대편 일개미 둘이 마주 파고 나온다 · 맵을 떠나면 반쯤 판 흙벽은 없다(P10) · 녹 자국은 조용히
func test_kt_up_dig(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	t.ok(_texts(st, "KT_DIG").contains("사각사각"), "흙벽 — 흙 너머 긁는 소리")
	c._dig()
	t.ok(c._dig_t > 0.0 and _v(st, "KT_DIG") == 0, "파기 시작 — 아직 안 뚫림")
	h.enter("KT-01", "from_W")
	t.ok(c._dig_t == 0.0 and _v(st, "KT_DIG") == 0, "떠났다 오면 반쯤 판 흙벽은 없다")
	c._dig()
	var n0 := _ants(h, "CR-080").size()
	c._dig_t = 0.01
	c._process(0.1)
	t.ok(_v(st, "KT_DIG") == 1 and _ants(h, "CR-080").size() == n0 + 2, "20초 뒤 뚫림 — 마주 파던 일개미 둘")
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: Kt = r2[2]
	st2.vars.set_v("KT_DIG", 2)
	t.ok(_texts(st2, "KT_DIG").contains("뚫린 굴"), "녹 자국으로 지난 판도 굴(KT_DIG 2)")


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


## 오르는 길 ② 승강로: 화물 칸 지붕 해치 → 22층 알방 바닥(사무층을 통째로 건너뜀)
func test_kt_up_shaft(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	st.vars.set_v("KT_POWER", 2)
	t.eq(_play(st, c, "KT_CARGO", ["해치", "끝까지"]), [], "칸 지붕 해치 — 승강로")
	h.enter("KT-04", "from_shaft")
	t.eq(h.map.id, "KT-04", "22층 여왕방(승강로 구멍)")
	var m := h.combat.colony.egg_mound()
	t.ok(Vector2(m).distance_to(Vector2(23, 3)) <= 7.0, "알 무더기 바로 옆에 나온다")


## 위성 육아방: 점액을 바르면 위장(PC_SMELL) · 알 하나(M-394) — 병정이 일하는 개미로 본다
func test_kt_up_nursery(t) -> void:
	var r := _host("KT-03", "from_stair")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	t.ok(h.combat.colony.cells.size() > 40, "사무층 냄새 길")
	t.eq(_play(st, c, "KT_NURSE", ["점액", "알 하나"]), [], "육아방 알 무더기")
	t.ok(_v(st, "PC_SMELL") == AntColony.SMELL_MIN and st.items.has("M-394"), "위장 3시간 + 알")
	t.ok(_ants(h, "CR-081").size() == 1, "육아방 문지기 병정")


## 22층: 소화전 호스로 알 무더기 둘레 고리를 쓸면 생성이 멎는다 · 여왕을 쓰러뜨리면 KT_QUEEN · 던전 정리 · 페로몬 드롭
func test_kt_up_queen(t) -> void:
	var r := _host("KT-04", "from_stair")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	var col: AntColony = h.combat.colony
	var m := col.egg_mound()
	t.ok(m.x > 0 and col.ring_ok(m), "알 무더기 둘레 냄새 고리")
	t.eq(_ants(h, "CR-082").size(), 1, "여왕")
	t.eq(_ants(h, "CR-081").size(), 4, "병정 넷(SD-09a)")
	c._hose("ring")
	t.ok(not col.ring_ok(m), "호스로 고리를 쓸면 생성이 멎는다")
	var q: Enemy = _ants(h, "CR-082")[0]
	q.cmb.last_by = "player"
	q.cmb.take({"hp": 9999.0}, h.player.loco.logical)
	t.eq(_v(st, "KT_QUEEN"), 1, "여왕 처리")
	t.eq(Dungeon.state(st, Dungeon.of_map("KT-04")), 1, "던전 정리")
	t.ok(st.items.has("M-155"), "여왕 페로몬 드롭(SD-14)")
	h.enter("KT-01", "from_W")
	t.ok(_ants(h, "CR-080").is_empty() and h.combat.colony.cells.is_empty(), "로비 정찰 · 냄새 길이 사라진다")


## 순서 자유: 여왕보다 먼저 불을 켜면 개미가 위로(HEAT) · 어하은은 매표소 뒤로 · 퀘스트는 여왕 처리로 끝난다
func test_kt_up_order(t) -> void:
	var r := _host("KT-07", "from_ladder")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	st.vars.set_v("KT_HOOK", 1)
	c._quest()
	t.eq(st.quests.stage("UQ-68"), 20, "부탁을 들었다 — 여왕이 먼저 목표")
	c._gen()
	t.ok(_v(st, "KT_TOP") == 1 and _v(st, "KT_HEAT") == 1, "여왕 전에 발전기 — 개미가 열을 따라 위로")
	t.eq(st.quests.stage("UQ-68"), 40, "단계 40")
	h.enter("KT-06", "from_roof")
	var bj0 := _v(st, "PD_R02_BJ")
	c._scope()
	t.ok(_v(st, "KT_TOP") == 2 and _v(st, "PD_R02_BJ") == bj0 + 1, "망원경 점등 · 관측조도 그 불을 쓴다(BJ +1)")
	t.eq(st.quests.stage("UQ-68"), 50, "불은 켜졌고 여왕이 남았다(단계 50)")
	t.ok(_ants(h, "CR-080").size() >= 1, "60층까지 올라온 일개미")
	var npcs: Array = (h.map.data.get("npcs", []) as Array).filter(func(n): return str(n["id"]) == "N-R02-030" and InteriorMap._cond_ok(str(n.get("cond", "")), st))
	t.ok(npcs.size() == 1 and int(npcs[0]["x"]) == 4, "어하은은 매표소 뒤로 피했다")
	var xp0 := _v(st, "PC_XP")
	st.vars.set_v("KT_QUEEN", 1)
	c._quest()
	t.ok(st.quests.stage("UQ-68") == 100 and _v(st, "PC_XP") == xp0 + Kt.XP, "여왕 처리로 끝 — 130 XP")


## 어하은 첫 얼굴: 통화했으면 '그 숨소리' · 신발을 건네면 4번 문 앞(KT_SHOE) · 이미 한 일은 따라 올림(P2)
func test_kt_up_haeun(t) -> void:
	var r := _host("KT-06", "from_stair")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	t.ok(_texts(st, "KT_HAEUN").contains("숨소리"), "통화한 손님 — 그 숨소리")
	st.vars.set_v("KT_CALL", 0)
	st.vars.set_v("KT_MEET", 0)
	t.ok(_texts(st, "KT_HAEUN").contains("점검 중입니다"), "통화한 적 없으면 녹음 멘트를 입으로 하다 멈춘다")
	st.vars.set_v("KT_MEET", 0)
	st.vars.set_v("KT_QUEEN", 1)
	st.call_fn("give", ["M-393", 1])
	t.eq(_play(st, c, "KT_HAEUN", ["신발", "4번 문 앞"]), [], "신발을 건넨다")
	t.ok(_v(st, "KT_SHOE") == 1 and not st.items.has("M-393"), "4번 문 앞에 놓였다")
	t.eq(st.quests.stage("UQ-68"), 30, "만나기 전에 여왕을 처리했다 — 바로 발전기 단계(이미 섬)")
	t.eq(h.map.id, "KT-06", "60층")


## 오르는 길 ③ 곤돌라: 줄을 안 매면 20층에서 기울어 멈춤(사무층 창) · 매면 31층 연회장 · 손 크랭크로 내려옴 · 옥상 권양기
func test_kt_up_gondola(t) -> void:
	var r := _host("KT-08", "from_base")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: Kt = r[2]
	t.eq(_play(st, c, "KT_GOND8", ["그대로 타고"]), [], "녹슨 줄 그대로")
	t.ok(_v(st, "KT_GOND") == 2 and _v(st, "KT_GLASS20") == 1, "20층에서 기울어 멈춤 — 통유리를 깸")
	c._gond("down")
	t.eq(_v(st, "KT_GOND"), 0, "손 크랭크로 기단")
	st.vars.set_v("KT_GOND", 0)
	st.vars.set_v("KT_ROPE", 1)
	t.eq(_play(st, c, "KT_GOND8", ["타고"]), [], "잡아맨 줄로 탄다")
	t.ok(_v(st, "KT_GOND") == 1 and _v(st, "KT_GLASS31") == 1, "31층 연회장 창")
	c._gond("up")
	t.eq(_v(st, "KT_GOND"), 3, "옥상 권양기로 올림")
	t.eq(h.map.id, "KT-08", "기단(시험에선 나무 밖이라 맵을 바꾸지 않는다)")


## 불을 먼저 켜고 60층을 처음 오면: 매표소 뒤 피신 판도 첫 대면(부탁 · 퀘스트) · 여왕 뒤 '돌아왔어요'
func test_kt_up_hide(t) -> void:
	var r := _host("KT-06", "from_stair")
	var st: StoryState = r[1]
	var c: Kt = r[2]
	st.vars.set_v("KT_CALL", 0)
	st.vars.set_v("KT_HEAT", 1)
	st.vars.set_v("KT_TOP", 2)
	t.eq(_play(st, c, "KT_HAEUN", []), [], "피신 판 첫 대면")
	t.ok(_v(st, "KT_MEET") == 1 and _v(st, "KT_HOOK") == 1, "숨어 있어도 첫 얼굴 · 부탁")
	t.eq(st.quests.stage("UQ-68"), 50, "불은 켰고 여왕이 남았다")
	st.vars.set_v("KT_QUEEN", 1)
	t.ok(_texts(st, "KT_HAEUN").contains("돌아왔어요"), "여왕 뒤 줄로 돌아온다")

