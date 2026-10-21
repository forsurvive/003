## 단계 1-12c FQ-JH-01 「B구역 셔터」(SD-04d §8.3, 계획 docs/seoul-fallout/_plans/1-12c_FQ-JH-01-03_plan.md §2 · §4):
## 게시판 발동 · 문턱 · 노복희 사슬 열쇠 · 들어가면 20 · 굴 셋 물결 · 철판(쥐가 앞에 있으면 못 댐) · 독 미끼(한 시간 뒤) · 왕쥐는 독을 안 먹음 ·
## 둥지 영수증(JH-02 훅) · 둥지에 왕쥐가 있으면 철판 밀림 · 왕쥐가 비운 틈 막기 → 가두기 · 구동부 먼저 = J-11로 샘 · 셔터로 깔기 = 휨 ·
## 수리공 [캡 40] · 다 됨 → 보고 · 다음 날 재개장(살아 있는 사람만) · 폭파 = 영구 적대 · 노복희 사망 = 실패.
extends RefCounted


func _host(map_id := "J-03", mark := "from_J-02") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 5)
	st.vars.set_v("GAME_HOUR", 10)
	st.vars.set_v("AFF_JH", 10)
	st.vars.set_v("PC_SKP_REPAIR", 100)
	st.vars.set_v("PC_SKP_MEDICINE", 100)
	st.vars.set_v("PC_CAPS", 200)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 28.  10:00"
	var c := FqJh.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: FqJh, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "jh01":
				c._cmd1(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				i = -1
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
						break
				k += 1
			else:
				i = cur["opts"].size() - 1
			if i < 0:
				return dr.errors + ["선택지 없음: %s" % str(picks[k - 1])]
			cur = dr.choose(i)
		else:
			if cur.has("text"):
				said.append(str(cur["text"]))
			cur = dr.advance()
	return dr.errors + ["말:" + " / ".join(said)]


func _says(st: StoryState, c: FqJh, id: String, needle: String, picks: Array = []) -> bool:
	var r := _play(st, c, id, picks)
	return r.size() == 1 and str(r[0]).begins_with("말:") and str(r[0]).contains(needle)


func _kill_all(c: FqJh) -> void:
	for k in c._live:
		for e in c._live[k]:
			if is_instance_valid(e) and not e.cmb.dead:
				e.cmb.take({"hp": 999.0}, e.loco.logical)


## 열린 굴의 물결을 다 잡을 때까지 틱을 돌린다(최대 n번)
func _clear_waves(c: FqJh, n := 12) -> void:
	for i in n:
		c.tick(8.0)
		_kill_all(c)
	c.tick(0.5)


func _into_b(h: InteriorHost, st: StoryState, c: FqJh) -> void:
	_play(st, c, "MQ-103_BOARD")
	_play(st, c, "MQ-103_BOK", ["B구역 셔터 일"])
	h.enter("J-08", "from_J-03")


func test_jh01_board_and_key(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh = a[2]
	t.ok(_says(st, c, "MQ-103_BOARD", "B구역 쥐"), "게시판 쪽지")
	t.eq(st.quests.stage("FQ-JH-01"), 10, "게시판 = 단계 10")
	t.ok(_says(st, c, "MQ-103_BOK", "사슬 열쇠", ["B구역 셔터 일"]), "노복희: 사슬 열쇠")
	t.eq(_v(st, "FQ_JH01_OPEN"), 1, "사슬 풀림")
	t.ok(_says(st, c, "FQJH01_SHUTTER", "사람 하나 지나갈", ["그냥 둔다"]), "셔터가 들려 있다")
	h.enter("J-08", "from_J-03")
	t.eq(st.quests.stage("FQ-JH-01"), 20, "들어가면 20(굴 셋)")
	c.tick(7.0)
	t.ok(c._out["a"] and c._out["b"] and c._out["c"], "굴 셋에서 물결")
	var king := false
	for e in c._live["c"]:
		king = king or str(e.get_meta("enemy_id", "")) == "CR-097"
	t.ok(king, "굴 C 첫 물결에 왕쥐")
	var b := _host()
	var st2: StoryState = b[1]
	st2.vars.set_v("AFF_JH", -30)
	t.ok(not _says(st2, b[2], "MQ-103_BOARD", "B구역 쥐"), "지하시장 경계(−20 아래): 쪽지가 없다")
	t.eq(st2.quests.stage("FQ-JH-01"), 0, "발동 안 함")


func test_jh01_plate_bait_king(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh = a[2]
	st.call_fn("give", ["M-010", 3])
	st.call_fn("give", ["M-026", 2])
	_into_b(h, st, c)
	c.tick(7.0)
	c._plate("a")
	t.eq(_v(st, "FQ_JH01_HA"), 0, "쥐가 굴 앞에 있으면 철판을 못 댄다")
	t.eq(int(st.items.get("M-010", 0)), 3, "고철은 그대로")
	for e in c._live["a"]:
		e.cmb.take({"hp": 999.0}, e.loco.logical)
	c.tick(0.5)
	t.ok(_says(st, c, "FQJH01_HOLE_A", "철사로 감는다", ["고철을 펴"]) or _v(st, "FQ_JH01_HA") == 1, "굴 A 철판")
	t.eq(_v(st, "FQ_JH01_HA"), 1, "굴 A = 철판")
	t.eq(int(st.items.get("M-010", 0)), 2, "고철 하나")
	t.eq(st.quests.stage("FQ-JH-01"), 30, "굴 하나 막힘 = 30")
	_play(st, c, "FQJH01_HOLE_B", ["흙 위에 말벌"])
	t.eq(_v(st, "FQ_JH01_HB"), 2, "굴 B 독 미끼")
	h.advance_minutes(61)
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH01_HB"), 3, "한 시간 뒤 굴 B 조용")
	_play(st, c, "FQJH01_HOLE_C", ["둥지 앞에 말벌"])
	h.advance_minutes(61)
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH01_HC"), 0, "왕쥐는 독을 안 먹는다 — 굴 C는 다시 열림")
	t.eq(_v(st, "FQ_JH01_WC"), 1, "시궁쥐 한 물결만 줄었다")
	c._plate("c")
	t.eq(_v(st, "FQ_JH01_HC"), 0, "왕쥐가 둥지에 있으면 철판이 밀린다")
	_clear_waves(c)
	t.eq(_v(st, "FQ_JH01_KING"), 1, "왕쥐 죽음")
	t.eq(_v(st, "FQ_JH01_HC"), 4, "굴 C 비움")
	t.ok(_says(st, c, "FQJH01_HOLE_C", "외상 — 탁", ["종이 뭉치를 편다"]), "둥지 영수증")
	t.eq(_v(st, "FQ_JH02_SEEN"), 1, "JH-02 훅(이미 앎)")
	t.eq(_v(st, "FQ_JH01_CLEAR"), 1, "굴 셋 닫힘 · 쥐 없음 = 조용")
	t.eq(st.quests.stage("FQ-JH-01"), 40, "단계 40")
	h.enter("J-03", "from_J-08")
	var caps := _v(st, "PC_CAPS")
	var jh := _v(st, "AFF_JH")
	t.ok(_says(st, c, "MQ-103_BOK", "쥐가 내리게 할 순 없지", ["B구역 셔터 일"]), "노복희 보고(원문 대사)")
	t.eq(st.quests.stage("FQ-JH-01"), 100, "끝")
	t.eq(_v(st, "AFF_JH") - jh, 8, "JH +8")
	t.eq(_v(st, "PC_CAPS") - caps, 100, "100캡")
	t.eq(_v(st, "FQ_JH01_SHOP_M"), 0, "가게는 내일부터")
	st.vars.set_v("GAME_DAY", 6)
	c._on_day(6)
	t.eq([_v(st, "FQ_JH01_SHOP_M"), _v(st, "FQ_JH01_SHOP_S")], [1, 1], "다음 날 수리공 · 사공 수선 재개장")


func test_jh01_trap_and_leak(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh = a[2]
	st.call_fn("give", ["M-010", 3])
	_into_b(h, st, c)
	t.ok(_says(st, c, "SQS08_B", "냉장 창고까지", ["구동부를 맡긴다"]), "수리공: 순서 예고 · [캡 40]")
	t.eq([_v(st, "FQ_JH01_MOTOR"), _v(st, "FQ_JH01_WARN"), _v(st, "FQ_JH01_MINSU")], [1, 1, 1], "구동부 고침(수리공)")
	t.eq(_v(st, "PC_CAPS"), 160, "40캡")
	t.ok(_says(st, c, "FQJH01_MOTOR", "수리공 말이 떠오른다", ["그래도 레버를 내린다"]), "예고를 들었으면 레버 앞에서 떠오른다")
	t.eq(_v(st, "FQ_JH01_LEAK"), 1, "안쪽 굴이 열린 채 내림 = J-11로 샘")
	t.ok(_says(st, c, "JM_SEOL", "쥐!"), "설태호가 안다")
	h.enter("J-11", "from_J-03")
	t.eq(c._leak.size(), 4, "J-11 버섯 선반 사이 쥐 넷")
	for e in c._leak:
		e.cmb.take({"hp": 999.0}, e.loco.logical)
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH01_LEAK"), 2, "샌 쥐를 잡음")
	# 가두기: 굴 A · B 철판, 왕쥐가 둥지를 비운 틈에 C — 왕쥐는 밖(안쪽)에 남고 셔터로 가둔다
	h.enter("J-08", "from_J-03")
	_play(st, c, "FQJH01_MOTOR", ["레버를 올린다"])
	t.eq(_v(st, "FQ_JH01_MOTOR"), 1, "레버 올림")
	st.vars.set_v("FQ_JH01_HA", 1)
	st.vars.set_v("FQ_JH01_HB", 1)
	c._out["c"] = false
	c._live["c"] = []
	c._rat("CR-097", Vector2i(30, 10), "c")                                  # 둥지를 비운 왕쥐(안쪽 먼 곳)
	c._out["c"] = true
	c._plate("c")
	t.eq([_v(st, "FQ_JH01_HC"), _v(st, "FQ_JH01_KOUT")], [1, 1], "둥지를 비운 틈에 막음 — 왕쥐는 밖")
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH01_CLEAR"), 0, "안쪽에 왕쥐가 떠돌면 아직")
	c._down()
	t.eq(_v(st, "FQ_JH01_MOTOR"), 2, "셔터 내림")
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH01_CLEAR"), 1, "가뒀다 = 조용")
	h.enter("J-03", "from_J-08")
	var jh := _v(st, "AFF_JH")
	t.ok(_says(st, c, "MQ-103_BOK", "선반 반이 갉혔어", ["B구역 셔터 일"]), "노복희가 샌 쥐를 안다")
	t.eq(_v(st, "AFF_JH") - jh, 5, "샌 쥐 −3 → JH +5")


func test_jh01_crush_blow_dead(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh = a[2]
	_into_b(h, st, c)
	st.vars.set_v("FQ_JH01_MOTOR", 1)
	c._rat("CR-095", Vector2i(23, 10), "x")
	c._down()
	t.eq([_v(st, "FQ_JH01_MOTOR"), _v(st, "FQ_JH01_CRUSH")], [3, 1], "셔터 칸에 선 쥐를 깔았다 — 날이 휨")
	t.ok(_says(st, c, "FQJH01_MOTOR", "기어가 맞물린다", ["휜 날을 펴고"]), "다시 고침")
	t.eq(_v(st, "FQ_JH01_MOTOR"), 1, "고친 구동부")
	# 폭파
	var b := _host()
	var h2: InteriorHost = b[0]
	var st2: StoryState = b[1]
	var c2: FqJh = b[2]
	_play(st2, c2, "MQ-103_BOARD")
	c2._on_blast(Vector2(36 * 32 + 16, 3 * 32), 64.0, "player")
	t.eq(_v(st2, "FQ_JH01_OPEN"), 3, "셔터 폭파")
	t.eq(st2.quests.stage("FQ-JH-01"), 200, "폭파 = 닫힘")
	t.eq(int(st2.deeds.grudge.get("JH", 0)), 2, "영구 적대")
	t.eq(_v(st2, "AFF_JH"), -100, "JH −100")
	t.ok(_says(st2, c2, "FQJH01_SHUTTER", "찢겨 나간 셔터", ["그냥 둔다"]), "찢긴 셔터 판")
	# 노복희 사망
	var d := _host()
	var st3: StoryState = d[1]
	var c3: FqJh = d[2]
	_play(st3, c3, "MQ-103_BOARD")
	st3.vars.set_v("AFF_JH", -60)
	c3.tick(0.5)
	t.eq(st3.quests.stage("FQ-JH-01"), 200, "적대(−60)면 닫힘")
