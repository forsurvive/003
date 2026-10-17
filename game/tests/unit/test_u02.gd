## 단계 1-D2 U02 남태령 지하(SD-09f U02 · L-UG-05 · 훅 UG-H01 · UG-H02 · 1-D 계획 §8): 맵 셋 · 조건부 어둠 · 던전 표 · 철망 문 · 반로아 안내(쥐 떼) ·
## 조명 회로 셋 · 지하 검문(지상과 같은 사실 · 정확한 벌금) · 할매 밀통로(교대 틈 · 흔적 → 다음 교대 발각, 남태령 지하에선 미룸 P4) ·
## 붙들린 할매의 하루 · 분류반 사흘 · 매듭(대납 · 위조 · 붕괴 · 보증 · 사진) · 환기구 → 막사 · 무전 대신 받기 · 죽은 사람 판.
extends RefCounted


func _host(map_id := "NT-03", mark := "from_W", clock := "10:00") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	st.vars.set_v("PC_CAPS", 500)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  " + clock
	st.vars.set_v("GAME_HOUR", int(clock.get_slice(":", 0)))
	var c := U02Paths.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: U02Paths, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "u02":
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


## 장면의 첫 선택지 글(명령은 진행기로)
func _opts(st: StoryState, c: U02Paths, id: String) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var g := 0
	while cur["type"] != "choices" and cur["type"] != "end" and g < 80:
		g += 1
		if cur["type"] == "cmd" and str(cur["name"]) == "u02":
			c._cmd(cur["args"], func() -> void: pass)
		cur = dr.advance()
	return (cur.get("opts", []) as Array).map(func(o): return str(o["text"]))


func _lines(st: StoryState, c: U02Paths, id: String, picks: Array = []) -> String:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var out := ""
	var g := 0
	while cur["type"] != "end" and g < 400:
		g += 1
		if cur["type"] == "line":
			out += str(cur.get("text", "")) + "\n"
			cur = dr.advance()
		elif cur["type"] == "cmd":
			if str(cur["name"]) == "u02":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])) and bool(cur["opts"][j]["enabled"]):
						i = j
				k += 1
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return out


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _clock(h: InteriorHost, c: U02Paths, hm: String) -> void:
	h.date_text = "2277. 11. 01.  " + hm
	h.st.vars.set_v("GAME_HOUR", int(hm.get_slice(":", 0)))
	c._t = 1.0
	c._process(0.0)


## 맵 셋 · 던전 표 · 조건부 어둠(회로를 끝까지 살리면 터널이 밝고, 초소 회로를 끊으면 초소가 어둡다)
func test_u02_maps_dark(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	for m in ["NT-01", "NT-02", "NT-03"]:
		t.ok(InteriorMap.exists(m), "맵 " + m)
		t.eq(str(Dungeon.of_map(m).get("id", "")), "DG-NT", m + "는 던전 DG-NT")
	t.eq(Dungeon.of_map("NT-03")["bosses"], ["kill:NT-03:34,9"], "우두머리 = 터널 쥐 떼 왕쥐")
	t.ok(h.dark_inside(), "회로 꺼짐: 터널은 어둠(핍-보이 조명)")
	st.vars.set_v("U02_LIGHT", 2)
	t.ok(not h.dark_inside(), "끝까지 켜면 터널이 밝다")
	h.enter("NT-01", "in")
	t.ok(not h.dark_inside(), "지하 초소는 작업등이 켜져 있다")
	st.vars.set_v("U02_LIGHT", 3)
	t.ok(h.dark_inside(), "초소 회로를 끊으면 초소가 어둡다")
	h.free()


## 철망 문(자물쇠 따기) · 반로아는 쥐 떼가 있으면 미루고, 정리되면 10캡(한 번만 빠진다)에 안내 · 분필 화살표
func test_u02_fence_guide(t) -> void:
	var r := _host("D-05", "from_D-02")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U02Paths = r[2]
	st.vars.set_v("PC_SKP_LOCKPICK", 60)
	t.eq(_play(st, c, "NT_FENCE", ["철사로", "그만둔다"]), [], "철망 문 따기")
	t.eq(_v(st, "U02_OPEN"), 1, "철망 문이 열렸다")
	var txt := _lines(st, c, "SD_BAN", ["남태령까지 안내해", "됐어"])
	t.ok(txt.contains("쥐 떼"), "쥐 떼가 있으면 안내를 미룬다")
	st.vars.set_v("DG_NT", 1)
	var caps0 := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "SD_BAN", ["남태령까지 안내해", "데려다줘"]), [], "쥐 떼 정리 뒤 안내")
	t.eq([_v(st, "U02_GUIDE"), caps0 - _v(st, "PC_CAPS")], [1, 10], "분필 화살표 · 10캡 한 번만")
	t.ok(_opts(st, c, "NT_HAL").any(func(o): return o.contains("반로아가 보냈어요")), "할매에게 '로아가 보냈다'")
	h.free()


## UG-H01 회로: 사당 측만(SA +5) → 남태령 측도(BJ +5, SA +5 더) · 회로 함 그림 · 아재 40캡
func test_u02_circuit(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U02Paths = r[2]
	st.vars.set_v("PC_SKP_REPAIR", 60)
	t.eq(_play(st, c, "NT_AJAE", ["등은 왜", "됐어요"]), [], "아재가 회로 일을 맡긴다")
	t.eq(_v(st, "U02_ASK"), 1, "맡김")
	var sa0 := _v(st, "AFF_JC_SA")
	var bj0 := _v(st, "AFF_BJ")
	var xp0 := _v(st, "PC_XP")
	t.eq(_play(st, c, "NT_CIRCUIT", ["사당 측 차단기만"]), [], "사당 측만")
	t.eq([_v(st, "U02_LIGHT"), _v(st, "AFF_JC_SA") - sa0, _v(st, "PC_XP") - xp0], [1, 5, 50], "회로 1 · SA +5 · 50 XP")
	var box: Array = h.map.props.filter(func(p): return str(p["name"]) == "w_circuit_box")
	var meta: Dictionary = h.map.prop_meta["w_circuit_box"]
	t.eq((box[0]["node"].texture as AtlasTexture).region, Rect2(meta["states"]["sadang"][0], meta["states"]["sadang"][1], meta["states"]["sadang"][2], meta["states"]["sadang"][3]), "회로 함 그림이 바로 '사당 측'으로")
	t.ok(h.dark_inside(), "사당 측만이면 터널은 아직 어둡다(손전등)")
	t.eq(_play(st, c, "NT_CIRCUIT", ["남태령 측도 올린다"]), [], "끝까지")
	t.eq([_v(st, "U02_LIGHT"), _v(st, "AFF_JC_SA") - sa0, _v(st, "AFF_BJ") - bj0, _v(st, "PC_XP") - xp0], [2, 10, 5, 50], "회로 2 · SA 합 +10 · BJ +5 · XP는 한 번")
	t.ok(not h.dark_inside(), "끝까지: 터널이 밝다")
	var caps0 := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "NT_AJAE", ["됐어요"]), [], "아재에게 돌아감")
	t.eq([_v(st, "PC_CAPS") - caps0, _v(st, "U02_ASK")], [40, 2], "약속한 40캡")
	t.eq(_play(st, c, "NT_AJAE", ["됐어요"]), [], "다시")
	t.eq(_v(st, "PC_CAPS") - caps0, 40, "40캡은 한 번만")
	h.free()


## 지하 검문: 지상과 같은 사실 · 벌금 계산이 정확하다(낮 미등록 20 → 밤 · 수배 · 거부 기록 70) · 등록증이면 공짜 · 들어가는 건 자유
func test_u02_checkpoint(t) -> void:
	var r := _host("NT-01", "in")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U02Paths = r[2]
	var caps0 := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "NT_EOM", ["낸다"]), [], "낮 · 미등록")
	t.eq([_v(st, "U02_FEE"), caps0 - _v(st, "PC_CAPS"), _v(st, "U02_PASSED")], [20, 20, 1], "벌금 20 · 통과 1")
	t.ok(h.map.tile_of(h.player.loco.logical).y < 12, "차단봉 건너편(바깥 쪽)에 섰다")
	caps0 = _v(st, "PC_CAPS")
	t.ok(_lines(st, c, "NT_EOM", ["볼일이 있어서요", "됐습니다"]) != "" and h.map.tile_of(h.player.loco.logical).y < 12, "바깥 쪽에서 말만 걸면 넘겨지지 않는다(재미 검수 ①)")
	t.eq(_play(st, c, "NT_EOM", ["내려가겠습니다"]), [], "바깥 쪽에서 — 들어가는 건 자유")
	t.eq([caps0 - _v(st, "PC_CAPS"), h.map.tile_of(h.player.loco.logical).y >= 13], [0, true], "공짜로 안쪽에")
	_clock(h, c, "21:00")
	st.vars.set_v("V_WANTED", 1)
	st.vars.set_v("SG_REFUSED", 1)
	caps0 = _v(st, "PC_CAPS")
	var txt := _lines(st, c, "NT_EOM", ["낸다"])
	t.ok(txt.contains("야간 할증 10") and txt.contains("수배") and txt.contains("동행 거부"), "벌금 항목을 하나씩 부른다")
	t.eq([_v(st, "U02_FEE"), caps0 - _v(st, "PC_CAPS")], [70, 70], "20 + 야간 10 + 수배 30 + 거부 10 = 70")
	h.enter("NT-01", "in")
	txt = _lines(st, c, "NT_EOM", ["낸다"])
	t.ok(txt.contains("지난번과 같은 계산") and not txt.contains("야간 할증 10"), "같은 벌금은 두 번째부터 한 줄")
	h.enter("NT-01", "in")
	st.vars.set_v("AFF_BJ", 25)
	st.call_fn("give", ["M-120", 1])
	caps0 = _v(st, "PC_CAPS")
	t.eq(_play(st, c, "NT_EOM"), [], "등록증")
	t.eq([caps0 - _v(st, "PC_CAPS"), h.map.tile_of(h.player.loco.logical).y < 12], [0, true], "우호 + 임시 등록증 = 지상처럼 통과")
	h.free()


## 할매 밀통로: 30캡(로아 손님 25) · 교대 틈에만 · 기다리기 · 덮개를 안 덮으면 흔적 → 다음 교대 발각(남태령 지하에 있으면 미룸) · 대납
func test_u02_path_discovery(t) -> void:
	var r := _host("NT-03", "from_W", "05:50")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U02Paths = r[2]
	var caps0 := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "NT_HAL", ["길이 있다던데요", "길값을 낸다", "됐어요"]), [], "길값")
	t.eq([_v(st, "U02_PATH"), caps0 - _v(st, "PC_CAPS")], [1, 30], "밀통로 · 30캡")
	t.eq(_v(st, "U02_SHIFT"), 0, "05:50 — 아직 교대 전")
	t.ok(_opts(st, c, "NT_SHAFT").any(func(o): return o.contains("교대까지 기다린다")), "틈이 아니면 기다리거나 무릅쓴다")
	t.eq(_play(st, c, "NT_SHAFT", ["교대까지 기다린다", "올라간다", "서둘러 그냥 간다"]), [], "기다렸다 오른다 — 덮개를 안 덮는다")
	t.eq([Clock.abs_min(h.date_text) % 1440, _v(st, "U02_USED"), _v(st, "U02_TRACE")], [360, 1, 1], "06:00 교대 틈 · 한 번 · 흔적")
	_clock(h, c, "06:20")
	_clock(h, c, "18:00")
	t.eq(_v(st, "U02_PATH"), 1, "남태령 지하에 있으면 발각은 다음 교대로(P4)")
	h.enter("D-05", "from_D-02")
	_clock(h, c, "18:20")
	_clock(h, c, "06:00")
	t.eq([_v(st, "U02_PATH"), _v(st, "U02_HAL"), _v(st, "U02_HFEE")], [3, 1, 50], "다음 교대: 봉인 · 할매 붙들림 · 할매 벌금 50")
	h.enter("NT-01", "out")
	t.ok(h.npcs.any(func(n): return str(n["id"]) == "N-UG-007"), "할매가 초소 책상 옆 의자에")
	var bj0 := _v(st, "AFF_BJ")
	caps0 = _v(st, "PC_CAPS")
	t.eq(_play(st, c, "NT_EOM", ["할매 벌금을 대신 낸다"]), [], "대납")
	t.eq([_v(st, "U02_SOL"), _v(st, "U02_HAL"), _v(st, "U02_PATH"), _v(st, "U02_TRACE"), caps0 - _v(st, "PC_CAPS"), _v(st, "AFF_BJ") - bj0], [1, 0, 1, 0, 50, -5],
		"① 대납: 할매 귀가 · 길은 '배수 정비'로 다시 열림 · BJ −5")
	h.free()


## 발각의 까닭은 내가 한 일: 덮개를 덮으면 흔적이 없다 · 터널이 밝으면(회로 끝까지) 덮어도 초소가 본다 · 틈 밖에 오르면 들킨다
func test_u02_trace_causes(t) -> void:
	var r := _host("NT-03", "from_W", "06:02")
	var st: StoryState = r[1]
	var c: U02Paths = r[2]
	_clock(r[0], c, "06:02")
	st.vars.set_v("U02_PATH", 1)
	t.eq(_v(st, "U02_SHIFT"), 1, "06:02 — 교대 틈")
	t.eq(_play(st, c, "NT_SHAFT", ["올라간다", "제자리에 덮고"]), [], "덮고 간다")
	t.eq(_v(st, "U02_TRACE"), 0, "흔적 없음")
	st.vars.set_v("U02_LIGHT", 2)
	t.eq(_play(st, c, "NT_SHAFT", ["올라간다", "제자리에 덮고"]), [], "밝은 터널")
	t.eq(_v(st, "U02_TRACE"), 3, "터널이 밝으면 덮어도 흔적(까닭 3 불빛 — 초소가 본다)")
	st.vars.set_v("U02_TRACE", 0)
	var r2 := _host("NT-03", "from_W", "10:00")
	var st2: StoryState = r2[1]
	var c2: U02Paths = r2[2]
	st2.vars.set_v("U02_PATH", 1)
	var bj0 := _v(st2, "AFF_BJ")
	t.eq(_play(st2, c2, "NT_SHAFT", ["그래도 올라간다"]), [], "틈 밖에 오른다")
	t.eq([_v(st2, "U02_TRACE"), _v(st2, "AFF_BJ") - bj0, _v(st2, "U02_USED")], [2, -5, 0], "정지 명령 · 흔적(까닭 2 들킴) · BJ −5 · 지나가지 못함")
	st2.vars.set_v("U02_HAL", 1)
	st2.vars.set_v("U02_HFEE", 50)
	r2[0].enter("NT-01", "out")
	t.ok(_lines(st2, c2, "NT_EOM", ["알겠습니다"]).contains("머리가 올라왔다"), "엄태하가 발각의 까닭(들킴)을 말한다")
	st2.vars.set_v("U02_TRACE", 3)
	t.ok(_lines(st2, c2, "NT_EOM", ["알겠습니다"]).contains("터널이 밝아서"), "불을 끝까지 켠 내가 할매를 잡히게 했다")
	r[0].free()
	r2[0].free()


## 붙들린 할매의 하루: 다음 날 06시 분류반(초소에 있으면 미룸) · 권은서 보증(50캡) · 아니면 사흘 뒤 청계산
func test_u02_hal_days(t) -> void:
	var r := _host("NT-01", "out")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U02Paths = r[2]
	st.vars.set_v("U02_PATH", 3)
	st.vars.set_v("U02_HAL", 1)
	st.vars.set_v("U02_HAL_DAY", 10)
	c._on_day(11)
	t.eq(_v(st, "U02_HAL"), 1, "초소에 있으면 눈앞에서 끌고 가지 않는다(P4)")
	h.enter("D-05", "from_D-02")
	c._on_day(12)
	t.eq([_v(st, "U02_HAL"), _v(st, "U02_SOL")], [2, 4], "분류반 천막으로 · 매듭 4(둠)")
	h.enter("Q-02", "from_X")
	t.ok(h.npcs.any(func(n): return str(n["id"]) == "N-UG-007"), "할매가 분류반 대기 의자에")
	var caps0 := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "SG_KWON", ["보증금을 내겠습니다"]), [], "권은서 보증")
	t.eq([_v(st, "U02_SOL"), _v(st, "U02_HAL"), caps0 - _v(st, "PC_CAPS")], [5, 0, 50], "⑤ 보증: 할매 귀가 · 50캡")
	st.vars.set_v("U02_HAL", 2)
	st.vars.set_v("U02_HAL_DAY", 20)
	h.enter("D-05", "from_D-02")
	c._on_day(22)
	t.eq(_v(st, "U02_HAL"), 2, "사흘이 안 됐다")
	c._on_day(23)
	t.eq(_v(st, "U02_HAL"), 4, "사흘 뒤 청계산으로(빈 집)")
	h.free()


## 다른 매듭: 근무표 위조(교대 틈 · 과학 45) · 갱 붕괴(카르마 +) · 돌 사진(화술 — 성공이면 귀가, 실패면 그대로)
func test_u02_other_knots(t) -> void:
	var r := _host("NT-01", "out", "06:03")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U02Paths = r[2]
	_clock(h, c, "06:03")
	st.vars.set_v("PC_SKP_SCIENCE", 70)
	st.vars.set_v("U02_PATH", 3)
	st.vars.set_v("U02_HAL", 1)
	t.eq(_play(st, c, "NT_DESK", ["근무표에"]), [], "근무표 위조(엄태하가 교대 보고 간 틈)")
	t.eq([_v(st, "U02_SOL"), _v(st, "U02_HAL"), _v(st, "U02_PATH")], [2, 0, 1], "② 위조: 할매 귀가 · 길 다시 열림")
	st.vars.set_v("U02_PATH", 3)
	st.vars.set_v("U02_HAL", 1)
	h.enter("NT-03", "from_shaft")
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(st, c, "NT_SHAFT", ["버팀목을 쳐서"]), [], "갱 붕괴")
	t.eq([_v(st, "U02_SOL"), _v(st, "U02_HAL"), _v(st, "U02_PATH"), _v(st, "V_KARMA") - k0], [3, 0, 2, 5], "③ 붕괴: 할매 귀가 · 길 없음 · 카르마 +5")
	st.vars.set_v("U02_PATH", 3)
	st.vars.set_v("U02_HAL", 1)
	t.eq(_play(st, c, "NT_HM_SHELF"), [], "선반 사진")
	t.eq(_v(st, "U02_PHOTO"), 1, "돌 사진을 봤다")
	h.enter("NT-01", "out")
	_clock(h, c, "10:00")
	t.eq(_play(st, c, "NT_EOM", ["돌 사진"]), [], "사진 이야기")
	t.ok((_v(st, "U02_SOL") == 7 and _v(st, "U02_HAL") == 0) or (_v(st, "U02_PHOTO_TRY") == 1 and _v(st, "U02_HAL") == 1), "⑦ 사진: 화술 성공이면 귀가, 실패면 그대로(다시 못 꺼냄)")
	h.free()


## 환기구 → 막사(수리 35) · 막사 점검구 · 빈 낮 무전 대신 받기: 거짓 보고면 교대 틈 20분 · 들키면 사흘 순찰(틈 닫힘)
func test_u02_vent_radio(t) -> void:
	var r := _host("NT-01", "in")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U02Paths = r[2]
	st.vars.set_v("PC_SKP_REPAIR", 60)
	t.eq(_play(st, c, "NT_VENT", ["나사를 하나씩", "그만둔다"]), [], "환기구 나사")
	t.eq(_v(st, "U02_VENT"), 1, "환기구 열림")
	t.ok(_opts(st, c, "Q01_HATCH").any(func(o): return o.contains("내려간다")), "막사 점검구로 내려갈 수 있다")
	st.vars.set_v("U02_RADIO", 2)
	st.vars.set_v("U02_GAP_DAY", 10)
	_clock(h, c, "06:15")
	t.eq(_v(st, "U02_SHIFT"), 1, "거짓 보고 날: 교대 틈 20분")
	_clock(h, c, "06:25")
	t.eq(_v(st, "U02_SHIFT"), 0, "20분 뒤 닫힘")
	st.vars.set_v("U02_RADIO", 3)
	st.vars.set_v("U02_PATROL_DAY", 10)
	_clock(h, c, "18:02")
	t.eq([_v(st, "U02_SHIFT"), _v(st, "U02_PATROL")], [0, 1], "무전에서 들킨 사흘: 순찰이 늘어 틈이 닫힌다")
	st.vars.set_v("U02_PATH", 1)
	h.enter("NT-03", "from_shaft")
	_clock(h, c, "17:40")
	t.ok(_lines(st, c, "NT_SHAFT", ["교대까지 기다린다"]).contains("순찰이 늘었다") and _v(st, "U02_USED") == 0, "순찰 날엔 기다려도 틈이 안 열린다(재미 검수 ②)")
	t.ok(_lines(st, c, "NT_HAL", ["교대까지 여기서", "됐어요"]).contains("순찰이 늘었어"), "할매도 안다")
	h.enter("NT-01", "in")
	st.vars.set_v("U02_VENT", 1)
	_clock(h, c, "22:10")
	t.eq(_play(st, c, "NT_VENT", ["덕트로 올라간다", "그냥 밀고 올라간다"]), [], "밤 막사로 그냥 올라간다")
	t.eq(_v(st, "U02_VENT"), 3, "황보서현과 눈이 마주친다(경계) — 용접 봉인")
	t.ok(_lines(st, c, "NT_VENT").contains("용접"), "용접된 환기구")
	st.vars.set_v("U02_RADIO", 0)
	st.vars.set_v("GAME_HOUR", 10)
	var txt := _lines(st, c, "SG_RADIO", ["수화기를 든다"])
	t.ok(_v(st, "U02_RADIO") in [1, 3], "빈 낮 막사 무전 대신 받기(화술)")
	t.ok(txt.contains("아무도 없다"), "낮엔 막사가 빈다")
	h.free()


## 죽은 사람 판: 엄태하가 없으면 보초가 규정대로 벌금 · 할매가 없으면 발각도 없다 · 월드 맨홀은 봉인 · 무너지면 닫힌다
func test_u02_dead_and_doors(t) -> void:
	var r := _host("NT-01", "in")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: U02Paths = r[2]
	st.kill("N-UG-006")
	var caps0 := _v(st, "PC_CAPS")
	t.eq(_play(st, c, "NT_BOOM", ["낸다"]), [], "초소장 없는 차단봉")
	t.eq([caps0 - _v(st, "PC_CAPS"), h.map.tile_of(h.player.loco.logical).y < 12], [20, true], "보초가 같은 규정으로 받고 올린다")
	st.kill("N-UG-007")
	st.vars.set_v("U02_PATH", 1)
	st.vars.set_v("U02_TRACE", 1)
	h.enter("D-05", "from_D-02")
	_clock(h, c, "17:50")
	_clock(h, c, "18:00")
	t.eq([_v(st, "U02_PATH"), _v(st, "U02_HAL")], [1, 0], "할매가 없으면 붙들 사람도 없다")
	var geo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/place_geo.json"))
	var ds: Array = (geo["_doors"] as Array).filter(func(d): return str(d["lid"]) == "L-UG-05")
	t.eq(ds.map(func(d): return str(d["to"])), ["NT-03", "NT-01"], "남태령 월드 문 둘: 맨홀 · 지하 초소 계단")
	t.eq(str(ds[0].get("open", "")), "U02_PATH <= 1", "맨홀은 봉인 · 무너지면 닫힌다")
	h.free()
