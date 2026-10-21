## 단계 1-12e FQ-JH-03 「지상 배달」(SD-04d §8.5, 계획 docs/seoul-fallout/_plans/1-12c_FQ-JH-01-03_plan.md §5):
## 발동 문턱(JH +20 · MQ-103 고용 중 아님 · 동행 자리) · 계약(상자 · 동행 · 대기 끝) · 낮 지상 시계(겹친 분 · 두 시간이면 돌아감) ·
## 쉬기 막음(바깥 · 지상 건물 안 / 지하는 됨) · 이동 검문(주민증 줄 · 등록증 · 화술 · 수배 · 혼자 · 들킴) · 건넴(함께 +10 · 혼자 +8 · 모자람 −3 ·
## 붕대) · 의료반 일정(수산시장 대기 · 성공 뒤 지하시장 정류) · 팔기(−8 · 계약 파기) · 넘김(끌려감 → 굳음 · 다음 06시 −30 / 되찾음 −10) ·
## 박춘삼 사망(노복희 혼자) · 소윤희 사망(반수빈) · 노복희 사망(덮음 — 보상 없는 건넴) · 생포 틈(계약 끝) · 계약 끝 장면(주민증 돌려받음).
extends RefCounted


func _host(map_id := "J-01", mark := "from_W") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 5)
	st.vars.set_v("GAME_HOUR", 10)
	st.vars.set_v("AFF_JH", 25)
	st.vars.set_v("MQ103_JOB", 3)
	st.vars.set_v("MQ103_HIRE", 2)
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_CAPS", 200)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 28.  10:00"
	var c := FqJh3.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: FqJh3, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "jh03":
				c._cmd(cur["args"], func() -> void: pass)
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


func _says(st: StoryState, c: FqJh3, id: String, needle: String, picks: Array = []) -> bool:
	var r := _play(st, c, id, picks)
	return r.size() == 1 and str(r[0]).begins_with("말:") and str(r[0]).contains(needle)


func _has_opt(st: StoryState, id: String, needle: String, picks: Array = []) -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 200:
		guard += 1
		if cur["type"] == "choices":
			if k >= picks.size():
				for o in cur["opts"]:
					if str(o["text"]).contains(needle) and bool(o["enabled"]):
						return true
				return false
			var i := -1
			for j in cur["opts"].size():
				if str(cur["opts"][j]["text"]).contains(str(picks[k])):
					i = j
			k += 1
			if i < 0:
				return false
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return false


func _npc_here(h: InteriorHost, id: String) -> bool:
	for n in h.npcs:
		if str(n["id"]) == id:
			return true
	return false


func _take(st: StoryState, c: FqJh3) -> void:
	c.tick(0.5)                                                           # 동행 자리(ROOM)를 먼저 잰다
	_play(st, c, "MQ-103_PARK", ["계약한다"])
	var m := c.host.combat.mates.get_mate("C-018")
	if not m.is_empty():                                                  # 실제로는 그 앞에 서서 말을 건다 — 곁(6칸 안)에 둔다
		c.host.player.loco.place((m["actor"] as Actor).loco.logical + Vector2(32, 0))
	c.tick(0.5)


func test_jh03_offer_gate(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	st.vars.set_v("AFF_JH", 10)
	t.ok(_says(st, c, "MQ-103_PARK", "회장님이 널 좀 더 믿으면"), "우호 미달(+20) — 귀띔 한 줄")
	t.eq(st.quests.stage("FQ-JH-03"), 0, "미달이면 발동 안 함")
	st.vars.set_v("AFF_JH", 25)
	st.vars.set_v("MQ103_HIRE", 1)
	st.vars.set_v("MQ103_JOB", 1)
	t.ok(not _says(st, c, "MQ-103_PARK", "지상 일이야"), "MQ-103 고용 중엔 계약서를 안 내민다")
	st.vars.set_v("MQ103_JOB", 2)
	t.ok(_says(st, c, "MQ-103_PARK", "둥지 값부터"), "둥지를 비웠어도 고용이 안 끝났으면 — 하나씩")
	st.vars.set_v("MQ103_JOB", 3)
	st.vars.set_v("MQ103_HIRE", 2)
	h.refresh_npcs()
	t.ok(_says(st, c, "MQ-103_PARK", "해 떠 있는 동안 두 시간", ["나중에"]), "원문 대사 — 계약서(나중에)")
	t.eq(st.quests.stage("FQ-JH-03"), 10, "'나중에'도 로그 10")
	t.eq(_v(st, "FQ_JH03_BOX"), 0, "나중에면 상자 없음")
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH03_ROOM"), 1, "동행 자리 있음")
	_take(st, c)
	t.eq(st.quests.stage("FQ-JH-03"), 20, "계약 = 20(두 시간 조항)")
	t.eq(_v(st, "FQ_JH03_BOX"), 1, "상자 받음")
	t.eq(int(st.items.get("M-426", 0)), 1, "M-426 의약품 상자")
	t.eq(_v(st, "FQ_JH03_PARK"), 1, "박춘삼 계약 동행")
	t.ok(not h.combat.mates.get_mate("C-018").is_empty(), "동행으로 곁에")
	t.ok(not _npc_here(h, "C-018"), "북쪽 출구 맵 인물에서 떼어 냄(A35)")
	var now := Clock.abs_min(h.date_text)
	t.eq(_v(st, "FQ_JH03_WAIT"), now - now % 1440 + 1440 + 1080, "소윤희 대기 끝 = 다음 날 18:00")
	t.ok(_says(st, c, "MQ-103_PARK", "시간 아깝다"), "계약 중엔 계약 이야기만(같은 사람 두 계약 없음)")
	t.ok(not _has_opt(st, "MQ-103_PARK", "같이 가자"), "계약 중엔 MQ-103 고용 선택지 없음")


func test_jh03_clock_and_part(t) -> void:
	t.eq(FqJh3.daylight_min(0, 1440), 720, "하루 중 낮 = 12시간")
	t.eq(FqJh3.daylight_min(17 * 60, 19 * 60), 60, "17~19시 중 낮 60분")
	t.eq(FqJh3.daylight_min(20 * 60, 30 * 60), 0, "밤(20~06시) 0분")
	t.eq(FqJh3.daylight_min(5 * 60, 7 * 60 + 1440), 720 + 60, "새벽 5시~다음 날 7시 = 낮 하루 + 한 시간")
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	_take(st, c)
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH03_OUT"), 0, "지하시장(지하) — 바깥 아님")
	var c0 := _v(st, "FQ_JH03_CLOCK")
	h.advance_minutes(30)
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH03_CLOCK"), c0, "지하에선 시계가 안 쌓인다")
	# 지상에 '기다려'로 두고 떠났다(그 자리 값 OUT 1이 남는다) — 그가 지상에 있는 한 쌓인다
	h.combat.mates.remove("C-018")
	h.combat.mates.away["C-018"] = {"map": "W", "pos": [0, 0], "hp": 120.0, "mode": "wait", "name": "박춘삼"}
	st.vars.set_v("FQ_JH03_OUT", 1)
	st.vars.set_v("FQ_JH03_LAST", Clock.abs_min(h.date_text))
	h.advance_minutes(119)
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH03_CLOCK"), 119, "지상 낮 119분")
	t.eq(_v(st, "FQ_JH03_PARK"), 1, "아직 계약 중")
	h.advance_minutes(5)
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH03_CLOCK"), 120, "두 시간에서 멈춘다")
	t.eq(_v(st, "FQ_JH03_END"), 1, "계약 끝 — 두 시간")
	t.eq(_v(st, "FQ_JH03_PARK"), 2, "곁에 없으면 혼자 지하로(돌아가는 중)")
	t.ok(not h.combat.mates.away.has("C-018"), "기다리던 자리에서도 빠짐(한 사람 한 곳)")
	st.vars.set_v("GAME_DAY", _v(st, "FQ_JH03_BACK"))
	c._on_day(0)
	t.eq(_v(st, "FQ_JH03_PARK"), 0, "다음 날 06시 — 북쪽 출구 일과로")
	h.enter("J-02", "from_J-01")
	h.enter("J-01", "from_J-02")
	t.ok(_npc_here(h, "C-018"), "북쪽 출구에 다시 선다")
	# 곁이면 장면으로 끝(주민증을 돌려준다)
	var b := _host()
	var st2: StoryState = b[1]
	var c2: FqJh3 = b[2]
	_take(st2, c2)
	st2.vars.set_v("FQ_JH03_ID", 1)
	st2.vars.set_v("FQ_JH03_END", 1)
	t.ok(_says(st2, c2, "JH03_PART", "여기까지야"), "계약 끝 장면 — 몸짓(계약할 때 원문 대사를 되풀이하지 않는다, 재미 검수 §5.5)")
	t.eq(int(st2.items.get("M-062", 0)), 1, "빌린 위조 주민증을 돌려받음")
	t.eq(_v(st2, "FQ_JH03_PARK"), 2, "장면 끝에 떠난다")


func test_jh03_rest_veto(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	_take(st, c)
	c.tick(0.5)
	t.ok(c.underground(), "지하시장 = 지하")
	t.eq(h.wait_block(), "", "지하에선 쉴 수 있다")
	h.enter("HP-01", "from_W")
	c.tick(0.5)
	t.ok(not c.underground(), "여의도 병원 1층 = 지상 건물 안")
	t.ok(h.wait_block().contains("유리창"), "지상 건물 안 — '판독기는 유리 너머도 봐'")
	h.enter("DB-01", "from_N")
	c.tick(0.5)
	t.ok(c.underground(), "대방 지하차도 = 지하")
	t.eq(h.wait_block(), "", "지하차도에선 쉴 수 있다(해 질 때까지 버티기)")


func test_jh03_checkpoint(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	_take(st, c)
	c.tick(0.5)
	st.call_fn("give", ["M-062", 1])
	var m0 := Clock.abs_min(h.date_text)
	t.ok(_says(st, c, "JH03_CHECK", "판독 불능", ["위조 주민증"]), "검문조장: 판독 불능 — 주민증 줄")
	t.eq(_v(st, "FQ_JH03_CHECK"), 2, "주민증 줄 통과")
	t.eq(_v(st, "FQ_JH03_ID"), 1, "주민증을 빌려줌")
	t.eq(int(st.items.get("M-062", 0)), 0, "주민증은 박춘삼 손에")
	t.eq(Clock.abs_min(h.date_text) - m0, 60, "줄 한 시간")
	# 등록증 보증 · 화술
	var b := _host()
	var st2: StoryState = b[1]
	var c2: FqJh3 = b[2]
	_take(st2, c2)
	c2.tick(0.5)
	st2.vars.set_v("AFF_BJ", 25)
	st2.call_fn("give", ["M-120", 1])
	t.ok(_has_opt(st2, "JH03_CHECK", "임시 등록증"), "BJ 우호 + 임시 등록증 — 보증")
	_play(st2, c2, "JH03_CHECK", ["수산시장 들것 의료반 약"])
	t.eq(_v(st2, "FQ_JH03_CHECK"), 4, "화술 — 서류(반 시간)")
	# 수배 30 이상: 주인공부터 · 서류 길 닫힘
	var d := _host()
	var st3: StoryState = d[1]
	var c3: FqJh3 = d[2]
	_take(st3, c3)
	c3.tick(0.5)
	st3.vars.set_v("V_WANTED", 40)
	st3.call_fn("give", ["M-062", 1])
	t.ok(_says(st3, c3, "JH03_CHECK", "너 때문에 걸리겠어", ["돌아가겠다"]), "수배 — 박춘삼 '너 때문에 걸리겠어'")
	t.eq(_v(st3, "FQ_JH03_CHECK"), 7, "회차")
	t.ok(not _has_opt(st3, "JH03_CHECK", "위조 주민증"), "수배면 주민증 길이 없다")
	t.ok(_has_opt(st3, "JH03_CHECK", "길 잃은 것뿐"), "회차 뒤 다시 오면 [화술 어려움]만")
	# 우회를 골랐다가 눈에 띔 — 도망친 판
	st3.vars.set_v("FQ_JH03_SPOT", 1)
	t.ok(_says(st3, c3, "JH03_CHECK", "숨어서 지나가면", ["돌아가겠다"]), "들킴 — 도망친 판")
	# 혼자(박춘삼 없음)
	var e := _host()
	var st4: StoryState = e[1]
	var c4: FqJh3 = e[2]
	st4.vars.set_v("FQ_JH03_BOX", 1)
	t.ok(_says(st4, c4, "JH03_CHECK", "약이군. 가시오"), "혼자 — 상자만 보고 통과")
	t.eq(_v(st4, "FQ_JH03_CHECK"), 9, "혼자 통과")


func test_jh03_deliver(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	_take(st, c)
	c.tick(0.5)
	t.eq(Caravans.medic_at(5, 0, false), 0, "성공 전 — 5일째는 강 건너")
	st.vars.set_v("MEDIC_AT", 4)
	var jh := _v(st, "AFF_JH")
	var caps := _v(st, "PC_CAPS")
	t.ok(_says(st, c, "TR_SO", "어디서 왔든 약은 약이죠", ["상자를 건넨다"]), "소윤희: 원문 대사")
	t.eq(_v(st, "FQ_JH03_SOL"), 1, "박춘삼과 배달")
	t.eq(st.quests.stage("FQ-JH-03"), 100, "100")
	t.eq(_v(st, "AFF_JH") - jh, 10, "JH +10")
	t.eq(_v(st, "PC_CAPS") - caps, 150, "150캡")
	t.eq(int(st.items.get("M-426", 0)), 0, "상자를 건넸다")
	t.eq(_v(st, "FQ_JH03_END"), 5, "계약은 배달까지")
	t.eq(_v(st, "FQ_JH03_PARK"), 2, "그는 제 길로 돌아간다")
	t.eq(_v(st, "FQ_JH03_NIGHT"), 2, "지하(북쪽 출구)에서 건넴 — 경매장 사람들은 못 봤다(공개도 1)")
	t.eq(Caravans.medic_at(5, 0, true), 5, "성공 뒤 — 5일째는 지하시장 진료소 앞")
	t.eq(Caravans.medic_at(4, 1, true), 3, "병원 정류(DG_STOP)와 따로 센다")
	t.ok(_says(st, c, "MQ-103_BOK", "정류지에서 조용히"), "노복희 다음 방문 한 줄(지하 정류지 판)")
	t.eq(_v(st, "FQ_JH03_TOLD"), 1, "한 번만")
	# 혼자 · 모자람 · 붕대
	var b := _host()
	var h2: InteriorHost = b[0]
	var st2: StoryState = b[1]
	var c2: FqJh3 = b[2]
	_take(st2, c2)
	c2.tick(0.5)
	t.ok(_says(st2, c2, "EXAMINE_M426", "스팀팩 둘", ["스팀팩 하나를 꺼낸다"]), "상자 살펴보기 — 목록")
	t.eq(_v(st2, "FQ_JH03_SHORT"), 1, "하나 뺐다")
	t.ok(not _has_opt(st2, "EXAMINE_M426", "스팀팩 하나를"), "두 번은 못 뺀다")
	var cmb: Combatant = h2.combat.mates.get_mate("C-018")["cmb"]
	cmb.hp = cmb.max_hp * 0.4
	c2.tick(0.5)
	t.ok(_has_opt(st2, "EXAMINE_M426", "붕대"), "박춘삼이 다쳤으면 붕대")
	_play(st2, c2, "EXAMINE_M426", ["붕대"])
	t.eq(_v(st2, "FQ_JH03_BAND"), 1, "붕대 감음(감점 없음)")
	t.ok(cmb.hp >= cmb.max_hp - 0.01, "팔이 나았다")
	_play(st2, c2, "MQ-103_PARK", ["계약 끝내자"])
	t.eq(_v(st2, "FQ_JH03_END"), 7, "주인공이 계약을 접었다")
	var jh2 := _v(st2, "AFF_JH")
	st2.vars.set_v("MEDIC_AT", 2)
	t.ok(_says(st2, c2, "TR_SO", "하나 모자라네요", ["상자를 건넨다"]), "하나 모자라네요")
	t.eq(_v(st2, "FQ_JH03_SOL"), 2, "혼자 배달")
	t.eq(_v(st2, "AFF_JH") - jh2, 5, "혼자 +8 − 모자람 3")


func test_jh03_sell_box(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	_take(st, c)
	c.tick(0.5)
	var jh := _v(st, "AFF_JH")
	var caps := _v(st, "PC_CAPS")
	t.ok(_says(st, c, "L25_SIM", "계약 파기다", ["경매에 붙이면", "판다"]), "곁에서 팔면 그 자리에서 계약 파기")
	t.eq(_v(st, "PC_CAPS") - caps, 300, "300캡")
	t.eq(_v(st, "AFF_JH") - jh, -8, "횡령 JH −8")
	t.eq(st.quests.stage("FQ-JH-03"), 200, "200")
	t.eq(_v(st, "FQ_JH03_SOL"), 3, "팖")
	t.eq(_v(st, "FQ_JH03_PARK"), 2, "그는 돌아간다")
	t.ok(not _has_opt(st, "TR_SO", "상자를 건넨다"), "상자가 없으니 건넬 것도 없다")


func test_jh03_sell_park(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	_take(st, c)
	c.tick(0.5)
	var caps := _v(st, "PC_CAPS")
	var karma := _v(st, "V_KARMA")
	_play(st, c, "JH03_REC", ["판독기 검사만이라고", "넘긴다"])
	t.eq(_v(st, "FQ_JH03_PARK"), 4, "넘김 — 끌려가는 중")
	t.eq(_v(st, "PC_CAPS") - caps, 120, "소개비 120캡")
	t.eq(_v(st, "V_KARMA") - karma, -100, "카르마 −100")
	t.ok(h.combat.mates.get_mate("C-018").is_empty(), "동행에서 빠짐")
	c.tick(0.5)
	t.eq(_v(st, "FQ_JH03_PARK"), 3, "끌고 가는 무리가 없으면(맵 밖 · 불러오기) 굳는다(P10)")
	var jh := _v(st, "AFF_JH")
	st.vars.set_v("GAME_DAY", 6)
	c._on_day(6)
	t.eq(_v(st, "FQ_JH03_KNOWN"), 1, "다음 06시 — 상가에 알려짐")
	t.eq(_v(st, "AFF_JH") - jh, -30, "JH −30")
	t.ok(_says(st, c, "MQ-103_KUK", "새벽인력 도장"), "국태윤이 출처(P7)")
	t.ok(_says(st, c, "MQ-103_BOK", "셔터는 반만"), "노복희 뒷말")
	h.refresh_npcs()
	t.ok(not _npc_here(h, "C-018"), "북쪽 출구에 박춘삼 없음")
	# 되찾음(끌고 가던 무리를 다 쓰러뜨렸다)
	var b := _host()
	var st2: StoryState = b[1]
	var c2: FqJh3 = b[2]
	_take(st2, c2)
	c2.tick(0.5)
	_play(st2, c2, "JH03_REC", ["판독기 검사만이라고", "넘긴다"])
	var jh2 := _v(st2, "AFF_JH")
	t.ok(_says(st2, c2, "JH03_RESCUE", "장사 못 하는구먼"), "되찾음 — 박춘삼 대사")
	t.eq(_v(st2, "FQ_JH03_RESCUED"), 1, "되찾음")
	t.eq(_v(st2, "AFF_JH") - jh2, -10, "그가 직접 말함 — JH −10(−30 아님)")
	t.eq(_v(st2, "FQ_JH03_PARK"), 2, "계약 끝 · 혼자 지하로")
	st2.vars.set_v("GAME_DAY", _v(st2, "FQ_JH03_BACK"))
	c2._on_day(0)
	t.eq(_v(st2, "FQ_JH03_KNOWN"), 0, "넘긴 일이 굳지 않았으니 −30 없음")
	t.ok(_says(st2, c2, "MQ-103_PARK", "너는 빼고"), "J-01: '계약서 새로 썼어. 너는 빼고'")


func test_jh03_alone_ban_close(t) -> void:
	# 박춘삼이 먼저 죽었다 — 노복희가 '혼자 갈 사람'에게
	var a := _host("J-03", "from_J-02")
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	t.ok(not _has_opt(st, "MQ-103_BOK", "지상 배달 말인데요"), "박춘삼이 살아 있으면 노복희 줄 없음(박춘삼이 내민다)")
	st.kill("C-018")
	t.ok(_has_opt(st, "MQ-103_BOK", "지상 배달 말인데요"), "박춘삼 죽음을 알면 노복희 메뉴 줄")
	c._cmd(["alone"], func() -> void: pass)
	t.eq(_v(st, "FQ_JH03_BOX"), 1, "혼자 맡음")
	t.eq(_v(st, "FQ_JH03_ALONE"), 1, "혼자 갈 사람")
	t.eq(st.quests.stage("FQ-JH-03"), 10, "로그 10(20 박춘삼 조항 없음)")
	# 소윤희도 죽었다 — 반수빈
	st.kill("C-067")
	var jh := _v(st, "AFF_JH")
	c._cmd(["deliver_ban"], func() -> void: pass)
	t.eq(_v(st, "FQ_JH03_SOL"), 4, "반수빈에게(다른 결과)")
	t.eq(_v(st, "AFF_JH") - jh, 8, "JH +8")
	t.eq(Caravans.medic_at(5, 0, _v(st, "FQ_JH03_SOL") == 1), 0, "의료반 정류는 늘지 않는다(소윤희 없음)")
	# 노복희가 죽었다 — 덮음 · 상자는 남고 보상 없는 건넴
	var b := _host("J-03", "from_J-02")
	var st2: StoryState = b[1]
	var c2: FqJh3 = b[2]
	_take_far(st2, c2)
	st2.kill("C-050")
	c2.tick(0.5)
	t.eq(st2.quests.stage("FQ-JH-03"), 200, "노복희 사망 — 덮음(200)")
	t.eq(_v(st2, "FQ_JH03_SOL"), 5, "덮음")
	t.eq(_v(st2, "FQ_JH03_PARK"), 2, "계약도 끝 — 박춘삼은 돌아간다")
	var caps := _v(st2, "PC_CAPS")
	st2.vars.set_v("MEDIC_AT", 2)
	t.ok(_says(st2, c2, "TR_SO", "봉투는 없지만", ["상자를 건넨다"]), "상인회가 없어도 약은 약 — 보상 없음")
	t.eq(_v(st2, "PC_CAPS"), caps, "캡 없음")
	t.eq(_v(st2, "FQ_JH03_BOX"), 2, "상자는 건넸다")


func _take_far(st: StoryState, c: FqJh3) -> void:
	c._cmd(["take"], func() -> void: pass)


func test_jh03_capture(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	_take(st, c)
	c.tick(0.5)
	c._on_map("H-03")
	t.eq(_v(st, "FQ_JH03_END"), 3, "생포 틈 — 계약 끝")
	t.eq(_v(st, "FQ_JH03_PARK"), 2, "박춘삼은 지하로(생포 무대에 따라가지 않음, A63)")
	t.ok(h.combat.mates.get_mate("C-018").is_empty(), "동행에서 빠짐")
	t.eq(_v(st, "FQ_JH03_BOX"), 1, "상자는 그대로(퀘스트 물건은 압수 안 됨)")


## 구현 뒤 재미 검수 반영(계획 §5.5): 줄 서기 · 엄도현 무전 · 싸운 뒤 차가움 · 소문 출처 · 시계 상수
func test_jh03_review(t) -> void:
	t.eq(FqJh3.RIVER_LEFT, 75, "강가 상은 75분 넘게 남겼을 때만(빨리 온 사람)")
	t.eq(int(FqJh3.SIGNS[0][0]), 30, "첫 신호는 쌓인 30분(남은 90분)")
	t.eq(FqJh3.BARKS.size(), 3, "길 위 바크 셋")
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	_take(st, c)
	c.tick(0.5)
	t.ok(_has_opt(st, "JH03_CHECK", "그냥 줄을 선다"), "주민증이 없어도 줄 서기가 보인다")
	var m0 := Clock.abs_min(h.date_text)
	t.ok(_says(st, c, "JH03_CHECK", "줄 설 자격이 없다", ["그냥 줄을 선다", "일단 물러선다"]), "판독기에서 회차")
	t.eq(_v(st, "FQ_JH03_CHECK"), 7, "회차(7)")
	t.eq(Clock.abs_min(h.date_text) - m0, 10, "줄 10분")
	# 엄도현 무전
	t.ok(_has_opt(st, "MQ-105_BJ_IDLE", "무전 좀"), "박춘삼 · 상자와 초소에 가면 '분대에 무전 좀'")
	t.ok(_says(st, c, "MQ-105_BJ_IDLE", "판독기 생략", ["무전 좀"]), "엄도현이 무전을 넣는다")
	t.eq(_v(st, "FQ_JH03_CHECK"), 10, "무전(10)")
	t.ok(not _has_opt(st, "MQ-105_BJ_IDLE", "무전 좀"), "두 번은 안 한다")
	t.ok(_says(st, c, "MQ-105_BJ_IDLE", "무전은 넣었습니다"), "넣은 뒤 다시 가면 '제 이름 대십시오'")
	var m1 := Clock.abs_min(h.date_text)
	t.ok(_says(st, c, "JH03_CHECK", "하사님 무전 받았다"), "분대: 무전 판")
	t.eq(_v(st, "FQ_JH03_CHECK"), 11, "무전으로 통과(11)")
	t.eq(Clock.abs_min(h.date_text) - m1, 5, "5분")
	t.ok(_says(st, c, "MQ-105_BJ_IDLE", "잘 받았답니다"), "통과 뒤 엄도현 — 이미 앎(P2)")
	# 막힘: BJ 비우호 · 수배 · 엄도현 사망(무전 판 무효)
	var b := _host()
	var st2: StoryState = b[1]
	var c2: FqJh3 = b[2]
	_take(st2, c2)
	c2.tick(0.5)
	st2.vars.set_v("AFF_BJ", -45)
	t.ok(_says(st2, c2, "MQ-105_BJ_IDLE", "제가 나설 일이 아닙니다", ["무전 좀"]), "BJ −40 이하(탈출 때 계엄병과 싸운 판 이하) — 거절")
	t.eq(_v(st2, "FQ_JH03_CHECK"), 0, "무전 없음")
	st2.vars.set_v("AFF_BJ", -30)
	st2.vars.set_v("V_WANTED", 40)
	t.ok(_says(st2, c2, "MQ-105_BJ_IDLE", "전단 얼굴로", ["무전 좀"]), "수배 — 거절")
	st2.vars.set_v("V_WANTED", 0)
	_play(st2, c2, "MQ-105_BJ_IDLE", ["무전 좀"])
	t.eq(_v(st2, "FQ_JH03_CHECK"), 10, "무전")
	st2.kill("N-R01-050")
	t.ok(_says(st2, c2, "JH03_CHECK", "판독 불능", ["돌아가겠다"]), "무전 준 하사가 죽었으면 보통 검문(무전 판 없음)")
	# 분대와 싸운 뒤 초소 — 차갑게
	var d := _host()
	var st3: StoryState = d[1]
	var c3: FqJh3 = d[2]
	_take(st3, c3)
	c3.tick(0.5)
	st3.vars.set_v("FQ_JH03_CHECK", 6)
	t.ok(_says(st3, c3, "MQ-105_BJ_IDLE", "분대원을 쏜 사람"), "싸운 뒤엔 '가십시오'가 아니다")
	t.ok(not _has_opt(st3, "MQ-105_BJ_IDLE", "무전 좀"), "무전 없음")
	# 소문 출처: 혼자 판은 '구울은 없었고'
	st3.vars.set_v("FQ_JH03_NIGHT", 0)
	st3.vars.set_v("FQ_JH03_SOL", 2)
	t.ok(_says(st3, c3, "L25_SIM", "구울은 없었고"), "심도겸 — 혼자 판 소문")
	st3.vars.set_v("FQ_JH03_GOSSIP", 0)
	st3.vars.set_v("FQ_JH03_SOL", 1)
	t.ok(_says(st3, c3, "L25_SIM", "지하시장 구울이 대낮에"), "심도겸 — 함께 판 소문")
	st3.vars.set_v("FQ_JH03_GOSSIP", 0)
	st3.vars.set_v("FQ_JH03_NIGHT", 2)
	t.ok(not _says(st3, c3, "L25_SIM", "들었어?"), "다른 정류지 · 지하에서 건넸으면 경매장 소문 없음")


## 재검수 반영: 하사 이름 대기(만났을 때만) · 부름을 무시하고 빠진 날은 강가 없음 · 잃은 상이 보임 · S06 다리목도 싸운 일을 앎
func test_jh03_review2(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c: FqJh3 = a[2]
	_take(st, c)
	c.tick(0.5)
	t.ok(not _has_opt(st, "JH03_CHECK", "엄도현 하사를 압니다"), "하사를 만난 적 없으면 이름을 못 댄다")
	st.book.meet("N-R01-050", h.date_text)
	t.ok(_has_opt(st, "JH03_CHECK", "엄도현 하사를 압니다"), "만났으면 이름 대기 — 검문 앞에서 무전(초소가 검문 뒤에 있어도)")
	var m0 := Clock.abs_min(h.date_text)
	t.ok(_says(st, c, "JH03_CHECK", "하사님이 보내라신다", ["엄도현 하사를 압니다"]), "조장이 초소에 무전")
	t.eq(_v(st, "FQ_JH03_CHECK"), 11, "무전으로 통과")
	t.eq(Clock.abs_min(h.date_text) - m0, 20, "무전 기다림 20분")
	st.vars.set_v("AFF_BJ", -45)
	st.vars.set_v("FQ_JH03_CHECK", 0)
	t.ok(not _has_opt(st, "JH03_CHECK", "엄도현 하사를 압니다"), "BJ −40 이하면 이름이 안 통한다")
	# 부름을 무시하고 빠진 날 — 강가 없음 · 박춘삼 한 줄 · 엄도현이 앎
	var b := _host()
	var h2: InteriorHost = b[0]
	var st2: StoryState = b[1]
	var c2: FqJh3 = b[2]
	_take(st2, c2)
	c2.tick(0.5)
	st2.vars.set_v("FQ_JH03_FLED", c2.day())
	st2.vars.set_v("FQ_JH03_NIGHT", 0)
	t.ok(_says(st2, c2, "MQ-105_BJ_IDLE", "얼굴 하나를 놓쳤다던데"), "엄도현 — 그날 검문조가 놓친 얼굴")
	st2.vars.set_v("MEDIC_AT", 4)
	t.ok(_has_opt(st2, "TR_SO", "상자를 건넨다"), "건넬 수 있다")
	# 잃은 상이 보이는 줄 · 도망친 날 줄은 원고 갈래로 본다(경매장 판 NIGHT 0은 월드에서만 서므로 변수로 맞춘다)
	var sc := _scene("TR_SO")
	t.ok(JSON.stringify(sc).contains("강 한번 보려 했는데"), "45~75분 남기면 잃은 상 한 줄")
	t.ok(JSON.stringify(sc).contains("분대가 네 얼굴 봤어"), "부름을 무시한 날 한 줄")
	# S06 다리목 — 검문조와 싸운 사람
	var d := _host()
	var st3: StoryState = d[1]
	var c3: FqJh3 = d[2]
	st3.vars.set_v("FQ_JH03_CHECK", 6)
	st3.vars.set_v("SQ_S06_CLOTH", 1)
	t.ok(_says(st3, c3, "SQS06_CHECK", "내 분대원을 쏜 사람"), "S06 검문 — 하사는 말도 돈도 안 받는다(A200)")
	t.ok(not _has_opt(st3, "SQS06_CHECK", "수고비"), "뇌물 길 없음")
