## 단계 1-11l SQ-S13 「제752차 개표」(SD-04a §5.6, 계획 docs/seoul-fallout/_plans/1-11l_SQ-S13_plan.md §4 · §6):
## 발동 · 2호 첫 만남(등록증) · 유인 · 임명 거절 · 2호 추천 · 도착 약속(시각 · 6시간 창 · 무산 · 다시 부탁) · 등록(기호 = 등록순) ·
## 투표(칸막이에서 확정) · 개표(동수 연장자 · 투표율 100% → 임기 4년) · 배급 명부 · NPC 당선 열쇠 · 당선자 사망 · 2호 이름(무효 · 유효표 0 → 전원) ·
## 부정(남을 위해서도 · 사흘 뒤 알려짐) · 위조 · 끄기(전/뒤) · 부숨 · 재공고 · 창고 억지로 · 투표한 날 대사 · 저장.
extends RefCounted


func _host(map_id := "SV-01", mark := "from_W") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	st.vars.set_v("GAME_HOUR", 12)
	st.vars.set_v("PC_SKP_SPEECH", 100)
	st.vars.set_v("PC_SKP_SCIENCE", 100)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	var c := SideS13.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: SideS13, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s13":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				i = -1
				for j in cur["opts"].size():
					var want := str(picks[k])
					var txt := str(cur["opts"][j]["text"])
					var hit := txt == want.substr(1) if want.begins_with("=") else txt.contains(want)
					if hit and bool(cur["opts"][j]["enabled"]):
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


func _said(r: Array) -> String:
	return str(r[r.size() - 1])


func _errs(r: Array) -> Array:
	return r.slice(0, r.size() - 1)


func _hour(st: StoryState, c: SideS13, abs_h: int) -> void:
	st.vars.set_v("GAME_DAY", abs_h / 24)
	st.vars.set_v("GAME_HOUR", abs_h % 24)
	c._arrivals()


## 유권자 다섯을 같은 창에 모은다(경상현 16 · 탁우빈 18 · 어하은 19 · 표강윤 19 · 노복희 20)
func _gather(st: StoryState, c: SideS13) -> void:
	c.met()
	c.lure()
	for kv in [["K", 16], ["T", 18], ["E", 19], ["P", 19], ["B", 20]]:
		c.ask(kv[0], kv[1])
	_hour(st, c, 10 * 24 + 20)


func _vote_all(c: SideS13) -> void:
	var guard := 0
	while c.q("VOTING") == 1 and guard < 200:
		guard += 1
		c._vote_tick(1.0)


func _count(st: StoryState, c: SideS13) -> Array:
	return _play(st, c, "SQS13_R4")


func test_s13_data(t) -> void:
	for s in ["SQS13_R2", "SQS13_R4", "SQS13_REG", "SQS13_BOOTH", "SQS13_COUNTER", "SQS13_VAULT", "SQS13_CRATE", "SQS13_MECH", "SQS13_LAW",
			"A13_ASK_B", "A13_ASK_K", "A13_ASK_E", "A13_ASK_T", "A13_ASK_W", "A13_ASK_I", "A13_ASK_P", "A13_HERE_K", "A13_DAY_W", "A13_SUSP_B"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % s), "장면 %s" % s)
	var r := _host()
	var h: InteriorHost = r[0]
	for id in ["M-416", "M-417", "M-014", "M-019", "M-002", "A-003"]:
		t.ok(h.items_db.has(id), "아이템 %s" % id)
	for m in ["SV-01", "SV-02", "SV-03", "SV-04"]:
		t.ok(FileAccess.file_exists("res://data/maps/%s.json" % m), "맵 %s" % m)
	var tm := FileAccess.get_file_as_string("res://data/terminals.json")
	t.ok(tm.contains("TM-SV04") and tm.contains("SQ_S13_RE"), "오버시어 단말(실험 규약 · 종료 조건)")
	t.ok(FileAccess.get_file_as_string("res://data/quests.json").contains("SQ-S13"), "퀘스트 표")
	var idx: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/_index.json"))["scenes"]
	t.ok(idx.find("A13_ASK_B") < idx.find("MQ-103_BOK"), "유권자 부탁 장면이 평소 장면보다 앞")
	t.ok(str(_scene("A13_ASK_B")).contains("chain"), "부탁 뒤 평소 이야기로(chain)")


## 아트리움 진입 → 10 · 2호 첫 만남 → 등록증 · 구울이 남아 있으면 30은 아직
func test_s13_meet(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	t.eq(c.stage(), 10, "아트리움 진입 → 10")
	var p := _play(st, c, "SQS13_R2", ["물러난다"])
	t.eq(_errs(p), [], "2호 오류 없음")
	t.ok(_said(p).contains("제752차 선거가 다가옵니다"), "원문 방송")
	t.eq(c.q("MET2"), 1, "만남")
	t.eq(int(st.call_fn("has", ["M-416"])), 1, "유권자 등록증")
	t.eq(c.stage(), 10, "구울 여섯이 남아 — 30 아직")
	c._check_safe()
	t.eq(c.q("SAFE"), 0, "살아 있는 야생 구울")


## [과학 25] 방송 유인 — 구울은 거주 구역으로(아트리움 0 · SV-03 여섯) → 30
func test_s13_lure(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_play(st, c, "SQS13_R2", ["물러난다"])
	var p := _play(st, c, "SQS13_R2", ["볼트 방송", "물러난다"])
	t.eq(c.q("LURE"), 1, "유인")
	t.eq(c.stage(), 30, "30")
	h.enter("SV-03", "from_SV01")
	var n := 0
	for e in h.combat.enemies:
		if str(e.row.get("id", "")) == "CR-200":
			n += 1
	t.eq(n, 6, "거주 구역에 야생 구울 여섯")
	h.enter("SV-01", "from_SV03")
	t.eq(h.combat.enemies.filter(func(e): return str(e.row.get("id", "")) == "CR-200").size(), 0, "아트리움엔 없음")
	t.ok(_said(p).contains("투표소는 위층"), "2호의 엉뚱한 안내")


## [관리자 인증] 임명은 위반(수배 +3) · 2호를 후보로 — '처음 받아 보는 추천'
func test_s13_auth_nom(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_play(st, c, "SQS13_R2", ["물러난다"])
	st.vars.set_v("V_REGCARD", 4)                                       # 관리자 인증은 등록 카드 4단계부터 보인다(MQ-104)
	var p := _play(st, c, "SQS13_R2", ["임명하라", "후보로", "물러난다"])
	t.ok(_said(p).contains("임명은 선거법 위반입니다. 관리자님도 한 표입니다"), "원문 거절")
	t.eq(c.q("AUTH"), 1, "인증 한 번")
	t.ok(_said(p).contains("처음 받아 보는 추천"), "2호 추천")
	p = _play(st, c, "SQS13_REG", ["투표함지기 2호"])
	t.ok(_said(p).contains("피선거권이 없습니다"), "등록부에 2호 — 거절")
	t.eq(c.q("C1"), 0, "칸은 비어 있음")


## 약속 시각 · 도착 · 6시간 창 · 무산(칠판) · 다시 부탁은 쉬움
func test_s13_window(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	c.met()
	c.ask("B", 22)
	t.eq(c.q("V_B"), 1, "약속")
	t.eq(c.q("T_B"), 10 * 24 + 22, "오늘 밤 열 시(절대 시각)")
	c.ask("T", 9)
	t.eq(c.q("T_T"), 11 * 24 + 9, "이미 지난 시각이면 내일")
	_hour(st, c, 10 * 24 + 22)
	t.eq(c.q("V_B"), 2, "도착")
	t.eq(c.q("OPEN"), 10 * 24 + 22, "창이 열림")
	t.eq(c.q("HERE"), 1, "아트리움 한 명")
	_hour(st, c, 11 * 24 + 5)
	t.eq(c.q("V_B"), 9, "6시간 지나 돌아감")
	t.eq(c.q("EASY_B"), 1, "다시 부탁은 쉬움")
	t.eq(c.q("BOARD"), 1, "칠판 '무산. 재공고'")
	t.eq(c.q("FAILS"), 1, "무산 한 번")
	t.eq(c.q("V_T"), 1, "창이 닫힌 뒤 약속은 그대로(아직 안 옴)")
	var p := _play(st, c, "A13_ASK_B", ["투표하러"])
	t.ok(_said(p).contains("시간 맞춰"), "다시 부탁 — 한 마디 투정")
	t.eq(c.q("V_B"), 1, "다시 약속(판정 없이)")


## 사정을 알면 시각이 당겨진다 — 노복희 상인회 단골 20시 · 경상현 장 마감 전엔 '반등' 거짓말로 18시 · 장 끝났으면 16시
func test_s13_ask_scenes(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	c.met()
	st.vars.set_v("JM_REG", 1)
	var p := _play(st, c, "A13_ASK_B", ["투표하러"])
	t.eq(_errs(p), [], "노복희 부탁 오류 없음")
	t.eq(c.q("T_B"), 10 * 24 + 20, "단골이면 여덟 시")
	p = _play(st, c, "A13_ASK_K", ["투표하러", "반등"])
	t.ok(_said(p).contains("마감 전엔 못 나가요"), "장 마감 전 — 객장 독점")
	t.eq(c.q("LIE"), 1, "거짓말 '1번이 반등'")
	t.eq(c.q("T_K"), 10 * 24 + 18, "여섯 시")
	st.vars.set_v("SQ_S13_V_K", 0)
	st.vars.set_v("UQ06_RESULT", 1)
	p = _play(st, c, "A13_ASK_K", ["투표하러"])
	t.eq(c.q("T_K"), 10 * 24 + 16, "장 끝났으면 네 시")
	p = _play(st, c, "A13_ASK_E", ["같이 가요", "끝까지"])
	t.eq(c.q("HEARD_E"), 1, "안내를 끝까지 들음")
	t.eq(c.q("T_E"), 10 * 24 + 19, "어하은 일곱 시")
	p = _play(st, c, "A13_ASK_T", ["투표하러", "해 질 무렵"])
	t.eq(c.q("T_T"), 10 * 24 + 18, "탁우빈 [화술 보통] 저녁 여섯 시")
	p = _play(st, c, "A13_ASK_W", ["투표하러", "아무도 빼지"])
	t.eq(c.q("PROMISE"), 1, "위서하 약속")
	st.vars.set_v("SQ_S11_READ", 1)
	p = _play(st, c, "A13_ASK_I", ["투표하러"])
	t.eq(c.q("T_I"), 10 * 24 + 20, "토요일에 이름을 같이 읽었으면 인지영 여덟 시")


## 죽은 유권자는 약속하지 않는다 · 약속한 뒤 죽으면 오지 않는다(9)
func test_s13_dead_voter(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	c.met()
	c.ask("B", 22)
	st.kill("C-050")
	_hour(st, c, 10 * 24 + 23)
	t.eq(c.q("V_B"), 9, "죽었으면 못 옴")
	st.kill("N-R02-019")
	c.ask("T", 14)
	t.eq(c.q("V_T"), 0, "죽은 사람에게는 약속 없음")
	# 아트리움에 도착한 뒤 죽으면 유권자 수에서 빠진다 — 죽은 사람이 투표하지 않는다(1-12d 교차 점검)
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: SideS13 = r2[2]
	_gather(st2, c2)
	t.eq(c2.q("V_K"), 2, "경상현 도착")
	var here := c2.present()
	st2.kill("N-R02-032")
	_hour(st2, c2, 10 * 24 + 21)
	t.eq(c2.q("V_K"), 9, "도착 뒤 사망 — 빠짐")
	t.eq(c2.present(), here - 1, "유권자 수 하나 줆")
	t.eq(c2.q("HERE"), here - 1, "원고가 읽는 수도 같이")


## 다섯이 겹치게 — 50 · 등록(기호 = 등록순) · 투표 시작 · 칸막이 · 개표(투표율 100% → 임기 4년)
func test_s13_full_vote(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	t.eq(c.q("HERE"), 5, "다섯")
	t.eq(c.stage(), 50, "50")
	h.refresh_npcs()
	t.ok(h.npcs.any(func(n): return str(n["id"]) == "C-050"), "노복희가 아트리움에 줄 섬")
	var p := _play(st, c, "SQS13_REG", ["내 이름"])
	t.eq(_errs(p), [], "등록 오류 없음")
	_play(st, c, "SQS13_REG", ["노복희"])
	t.eq(c.q("C1"), 1, "기호 1 = 주인공")
	t.eq(c.q("C2"), 2, "기호 2 = 노복희")
	t.eq(c.stage(), 40 if c.stage() < 50 else 50, "단계는 내려가지 않음")
	_play(st, c, "SQS13_R2", ["투표를 시작하자"])
	t.eq(c.q("VOTING"), 1, "투표 시작")
	p = _play(st, c, "SQS13_REG", [])
	t.ok(_said(p).contains("등록 마감"), "투표 중엔 등록 마감")
	_play(st, c, "SQS13_BOOTH", ["기호 1번"])
	t.eq(c.q("PCV"), 101, "주인공 기호 1")
	_vote_all(c)
	t.eq(c.q("VOTING"), 2, "다섯 다 찍음 — 마감")
	t.eq(c.q("BL_K"), 1, "경상현 = 기호 1번")
	t.eq(c.q("BL_B"), 2, "노복희 = 자기(상인회)")
	t.eq(c.q("BL_T"), 0, "탁우빈 = 시장 사람 없으면 백지")
	t.eq(c.q("BL_E"), 0, "어하은 — 안내를 안 들었으면 백지(후보 아님)")
	var bl := c.q("BL_K")
	st.vars.set_v("SQ_S13_LIE", 2)
	t.eq(c.q("BL_K"), bl, "칸막이에서 나온 표는 그대로(P10)")
	p = _count(st, c)
	t.eq(_errs(p), [], "개표 오류 없음")
	t.eq(c.q("WIN"), 1, "기호 1(2표) 대 기호 2(1표) — 주인공")
	t.eq(c.q("N1"), 2, "기호 1 두 표")
	t.eq(c.q("NB"), 3, "백지 셋")
	t.eq(c.q("TURN"), 1, "투표율 100%")
	t.eq(c.q("BOARD"), 2, "칠판 임기 4년")
	t.eq(c.stage(), 60, "60")
	t.ok(_said(p).contains("투표율 100%. 당선자 있음"), "4호 원문")


## 배급 명부 — 노복희 몫 0 · 볼트 방송 낭독 · 몫이 늘고 카르마 · JH −2 · 열쇠 · 끝(450 XP)
func test_s13_roll_cut(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(1)
	c.reg(2)
	c.begin()
	c.pc_vote(1)
	_vote_all(c)
	c.count()
	var k0 := _v(st, "V_KARMA")
	var jh0 := _v(st, "AFF_JH")
	var xp0 := _v(st, "PC_XP")
	var p := _play(st, c, "SQS13_R2", ["=0", "그대로", "그대로", "그대로", "그대로"])
	t.eq(_errs(p), [], "명부 오류 없음")
	t.eq(c.q("CUT_B"), 2, "노복희 0")
	t.eq(c.q("CUTS"), 1, "깎은 사람 하나")
	t.ok(_said(p).contains("노복희 — 배급 0"), "2호가 소리 내 읽음")
	t.eq(int(st.call_fn("has", ["M-417"])), 1, "당선 오버시어 열쇠")
	t.eq(st.count_of("M-014"), 6, "진공관 10 × 0.6")
	t.eq(st.count_of("M-002"), 30, "지폐 50 × 0.6")
	t.eq(_v(st, "V_KARMA") - k0, 60, "카르마 75 − 15")
	t.eq(_v(st, "AFF_JH") - jh0, -2, "구울 유권자 몫을 깎음 JH −2")
	t.eq(_v(st, "PC_XP") - xp0, 450, "XP 450")
	t.eq(c.stage(), 100, "100")
	t.eq(c.q("V_B"), 4, "각자 집으로")
	p = _play(st, c, "A13_DAY_B")
	t.ok(_said(p).contains("깎더구먼"), "투표한 날 — 깎인 사람 대사")
	t.eq(c.q("SAID_B"), 1, "한 번만")


## 아무도 안 깎음 — 공약 벽보 · +75 · 절반 · 위서하 약속 지킴
func test_s13_roll_fair(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(1)
	c.begin()
	c.pc_vote(1)
	_vote_all(c)
	c.count()
	var k0 := _v(st, "V_KARMA")
	var p := _play(st, c, "SQS13_R2", ["그대로", "그대로", "그대로", "그대로", "그대로"])
	t.eq(c.q("PLEDGE"), 1, "기호 1 벽보에 공약")
	t.eq(_v(st, "V_KARMA") - k0, 75, "+75")
	t.eq(st.count_of("M-014"), 5, "절반")
	t.ok(_said(p).contains("2096년 제217차"), "임기 4년 — 2096 공약을 이제 시행")


## 동수 → 연장자(2104 개정) — 1:1이면 2026년생 노복희
func test_s13_tie(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(1)
	c.reg(2)
	st.vars.set_v("SQ_S13_PCV", 101)
	for k in ["B", "K", "E", "T", "P"]:
		st.vars.set_v("SQ_S13_V_" + k, 3)
		st.vars.set_v("SQ_S13_BL_" + k, 0)
	st.vars.set_v("SQ_S13_BL_B", 2)
	t.eq(c.tally(), 2, "1:1 — 연장자 노복희")


## 2호 이름 — 주인공 하나면 무효 1 · 다섯 모두 + 주인공이면 유효표 0 → 유권자 전원(해법 D)
func test_s13_two(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(1)
	for k in ["B", "K", "E", "T", "P"]:
		st.vars.set_v("SQ_S13_TWO_" + k, 1)
	c.begin()
	_play(st, c, "SQS13_BOOTH", ["투표함지기 2호"])
	t.eq(c.q("INVALID"), 1, "주인공 무효 1")
	_vote_all(c)
	t.eq(c.q("INVALID"), 6, "무효 여섯")
	var p := _count(st, c)
	t.eq(c.q("WIN"), 10, "유권자 전원")
	t.ok(_said(p).contains("재검표하지 않습니다"), "4호가 처음 멈춤")
	var k0 := _v(st, "V_KARMA")
	_play(st, c, "SQS13_R2")
	t.eq(_v(st, "V_KARMA") - k0, 50, "+50")
	t.eq(st.count_of("M-014"), 2, "몫 1/6")
	t.eq(c.stage(), 100, "끝")


## NPC 당선 — 열쇠는 그 사람 · 절반 사례 · JH +6 · 공약은 그 기호 · 당선자가 열쇠 전에 죽으면 공동 관리
func test_s13_npc_win(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(2)
	c.begin()
	c.pc_vote(2)
	_vote_all(c)
	c.count()
	t.eq(c.q("WIN"), 2, "노복희 당선(자기 표 + 주인공)")
	var jh0 := _v(st, "AFF_JH")
	var p := _play(st, c, "SQS13_R2")
	t.ok(_said(p).contains("지하시장 분점"), "노복희 열쇠 대사")
	t.eq(_v(st, "AFF_JH") - jh0, 6, "JH +6")
	t.eq(c.q("PLEDGE"), 1, "기호 1 공약")
	t.eq(st.count_of("M-014"), 5, "절반 사례")
	t.eq(int(st.call_fn("has", ["M-417"])), 0, "열쇠는 내 손에 없다")
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: SideS13 = r2[2]
	_gather(st2, c2)
	c2.reg(2)
	c2.begin()
	c2.pc_vote(2)
	_vote_all(c2)
	c2.count()
	st2.kill("C-050")
	p = _play(st2, c2, "SQS13_R2")
	t.ok(_said(p).contains("사망 확인"), "당선자 사망 — 2호 판")
	t.ok(not _said(p).contains("지하시장 분점"), "죽은 사람은 말하지 않음")
	t.eq(c2.q("LOOT"), 1, "창고 공동 관리")


## 부정 — 개표기 [과학 50]로 기호 2(남을 위해서도) · 4호 '재검표 요구 — 기각' · 날마다 출력지 · 사흘 뒤 알려짐 JH −3
func test_s13_fraud(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(1)
	c.reg(3)
	c.begin()
	c.pc_vote(1)
	_vote_all(c)
	var k0 := _v(st, "V_KARMA")
	var p := _play(st, c, "SQS13_COUNTER", ["기호 2번"])
	t.eq(_errs(p), [], "개표기 오류 없음")
	t.eq(c.q("FRAUD"), 1, "부정")
	t.eq(c.q("WIN"), 3, "기호 2 = 경상현")
	t.eq(_v(st, "V_KARMA") - k0, -50, "−50")
	p = _count(st, c)
	t.ok(_said(p).contains("재검표 요구 — 기각"), "원문 출력")
	t.eq(c.q("WIN"), 3, "개표가 숫자 창을 따름")
	t.eq(c.q("BOARD"), 3, "실험 계속(제753차)")
	var jh0 := _v(st, "AFF_JH")
	for d in [11, 12, 13]:
		st.vars.set_v("GAME_DAY", d)
		h.day_tick.emit(d)
	t.eq(c.q("KNOWN"), 1, "사흘 뒤 알려짐")
	t.eq(_v(st, "AFF_JH") - jh0, -3, "JH −3")
	t.eq(c.q("PILE"), 3, "출력지 더미 셋")


## 위조 — 유권자 없이 [과학 75] · 주인공 당선 · 실험 계속 · 명부엔 카르마 없음
func test_s13_forge(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	c.met()
	var k0 := _v(st, "V_KARMA")
	var p := _play(st, c, "SQS13_REG", ["통째로"])
	t.eq(_errs(p), [], "위조 오류 없음")
	t.eq(c.q("WIN"), 1, "주인공 당선")
	t.eq(c.q("FRAUD"), 2, "위조")
	t.eq(c.q("TURN"), 0, "투표율 100% 아님")
	t.ok(_said(p).contains("제753차"), "다음 달")
	_play(st, c, "SQS13_R2")
	t.eq(_v(st, "V_KARMA") - k0, -50, "명부 카르마 없음 — −50만")
	t.eq(st.count_of("M-014"), 10, "위조 당선 — 창고 전부(원문 B)")


## 끄기 — 선거 전(창고 잠김 · 진공관 8 · XP 1/3) · 선거 뒤(4호가 허가 · 스스로 내줌) · 부숨 = 끔
func test_s13_off(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	c.met()
	var xp0 := _v(st, "PC_XP")
	_play(st, c, "SQS13_R2", ["전원 스위치", "내린다"])
	t.eq(c.q("OFF"), 1, "선거 전에 끔")
	t.eq(st.count_of("M-014"), 8, "진공관 여덟")
	t.eq(c.q("LOOT"), 0, "창고는 잠김")
	t.eq(_v(st, "PC_XP") - xp0, 150, "XP 1/3")
	t.eq(c.stage(), 100, "끝")
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: SideS13 = r2[2]
	_gather(st2, c2)
	c2.reg(1)
	c2.begin()
	c2.pc_vote(1)
	_vote_all(c2)
	c2.count()
	var p := _play(st2, c2, "SQS13_R4", ["전원을 내린다"])
	t.ok(_said(p).contains("처음으로 다 셌습니다"), "4호가 스스로")
	t.eq(c2.q("OFF"), 2, "선거 뒤 끔")
	var r3 := _host()
	var st3: StoryState = r3[1]
	var c3: SideS13 = r3[2]
	c3.met()
	st3.kill("N-R02-028")
	c3._t = 1.0
	c3._process(0.0)
	t.eq(c3.q("OFF"), 1, "부순 로봇 = 끈 것")


## 당선자 없음(모두 백지) — 재공고 · 칸이 다 비워짐(P10) · 모였던 사람은 다시 부탁이 쉬움
func test_s13_again(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(6)
	st.vars.set_v("SQ_S13_LIE", 2)
	c.begin()
	c.pc_vote(0)
	_vote_all(c)
	c.count()
	t.eq(c.q("WIN"), -1, "당선자 없음")
	_play(st, c, "SQS13_R2")
	t.eq(c.q("C1"), 0, "등록부 비움")
	t.eq(c.q("VOTING"), 0, "투표 처음부터")
	t.eq(c.q("V_K"), 9, "돌아감")
	t.eq(c.q("EASY_K"), 1, "다시 부탁은 쉬움")
	t.eq(c.q("BL_K"), 0, "표 칸 비움")
	t.eq(c.q("BOARD"), 1, "칠판 재공고")


## 경상현에게 '1번은 반등이 아니에요' — 원문 대사 · 백지
func test_s13_honest_k(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(1)
	var p := _play(st, c, "A13_HERE_K", ["아니요", "물러난다"])
	t.ok(_said(p).contains("기호 1번 '반등'은 없어요? 그럼… 백지로 할게요. 내일은 반등합니다."), "원문 대사")
	t.eq(c.ballot("K"), 0, "백지")


## 창고를 억지로(선거 없이 [과학 75]) — 전부 · '공금 횡령' 방송 · 카르마 −25 · XP 1/3
func test_s13_break(t) -> void:
	var r := _host("SV-04", "from_SV01")
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	var k0 := _v(st, "V_KARMA")
	var p := _play(st, c, "SQS13_VAULT", ["패널"])
	t.ok(_said(p).contains("공금 횡령"), "2호 방송")
	t.eq(c.q("LOOT"), 2, "억지로")
	t.eq(st.count_of("M-014"), 10, "전부")
	t.eq(_v(st, "V_KARMA") - k0, -25, "−25")
	t.ok(bool(st.boxes.get("door:SV-04:14,13", {}).get("open", false)), "창고 문 열림")


## 저장/불러오기 — 표 · 약속 시각은 변수 한 곳
func test_s13_save(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(1)
	c.begin()
	c.pc_vote(1)
	_vote_all(c)
	var js := JSON.stringify(GameSnapshot.story(st))
	var st2 := StoryState.new()
	st2.load_data()
	GameSnapshot.apply_story(st2, JSON.parse_string(js))
	for k in ["B", "K", "E", "T", "P"]:
		t.eq(int(st2.vars.get_v("SQ_S13_BL_" + k)), c.q("BL_" + k), "불러온 뒤 표 %s 그대로" % k)
	t.eq(int(st2.vars.get_v("SQ_S13_VOTING")), 2, "마감 그대로")
	t.eq(st2.quests.stage("SQ-S13"), c.stage(), "단계 그대로")


## 재미 검수 반영(구현 뒤 3.5): 표강윤 당선 — 열쇠 대사 뒤 KEY_END(사망 판으로 흐르지 않음) · 경상현 당선은 JH 아님(MS)
func test_s13_win_p_and_faction(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(8)
	c.begin()
	c.pc_vote(8)
	_vote_all(c)
	c.count()
	t.eq(c.q("WIN"), 8, "표강윤 당선")
	var p := _play(st, c, "SQS13_R2")
	t.ok(_said(p).contains("탄약 창고로는 안 써"), "표강윤 열쇠 대사")
	t.ok(not _said(p).contains("사망 확인"), "사망 판으로 흐르지 않음")
	t.eq(st.count_of("M-014"), 5, "절반 사례(1/6 아님)")
	var r2 := _host()
	var st2: StoryState = r2[1]
	var c2: SideS13 = r2[2]
	_gather(st2, c2)
	c2.reg(3)
	c2.begin()
	c2.pc_vote(3)
	_vote_all(c2)
	c2.count()
	var jh0 := _v(st2, "AFF_JH")
	_play(st2, c2, "SQS13_R2")
	t.eq(c2.q("WIN"), 3, "경상현 당선")
	t.eq(_v(st2, "AFF_JH") - jh0, 0, "경상현은 MS — JH 그대로")


## 투표를 열어 놓고 기표소에 안 들어가면 6시간 뒤 무산(제15조) · 다시 부탁이 쉬워지지 않음
func test_s13_snub(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(1)
	c.begin()
	t.eq(c.q("VOTING"), 1, "투표 시작")
	h.hints.clear()
	_hour(st, c, 11 * 24 + 1)
	t.eq(c.q("VOTING"), 0, "무산")
	t.eq(c.q("V_K"), 9, "돌아감")
	t.eq(c.q("EASY_K"), 0, "볼트 양반이 안 찍었으니 쉬워지지 않음")
	t.ok(" / ".join(h.hints.map(func(x): return str(x[0]))).contains("기표 대기 6시간"), "2호 방송")


## 2호 사전 등록 명부 — 약속 날 · 시각 · 도착 · 마감까지
func test_s13_roster(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	c.met()
	c.ask("B", 22)
	c.ask("K", 18)
	_hour(st, c, 10 * 24 + 18)
	h.hints.clear()
	_play(st, c, "SQS13_R2", ["사전 등록", "물러난다"])
	var hs := " / ".join(h.hints.map(func(x): return str(x[0])))
	t.ok(hs.contains("노복희 10일 22시"), "약속 시각")
	t.ok(hs.contains("경상현(도착)"), "도착")
	t.ok(hs.contains("마감까지 6시간"), "창 남은 시간")


## 나를 찍은 사람을 깎으면 '당신 찍었는데' · 당선 오버시어 금고는 빈 채로(보관 자리 후보)
func test_s13_betray_safe(t) -> void:
	var r := _host()
	var st: StoryState = r[1]
	var c: SideS13 = r[2]
	_gather(st, c)
	c.reg(1)
	st.vars.set_v("SQ_S13_ASK_B", 1)
	c.begin()
	c.pc_vote(1)
	_vote_all(c)
	c.count()
	t.eq(c.q("BL_B"), 1, "노복희가 나를 찍음")
	_play(st, c, "SQS13_R2", ["=0", "그대로", "그대로", "그대로", "그대로"])
	var p := _play(st, c, "A13_DAY_B")
	t.ok(_said(p).contains("나 당신 찍었어"), "배신 대사")
	var sk := "SV-04:24,16@%d" % st.year()
	t.ok(st.boxes.has(sk) and (st.boxes[sk]["items"] as Dictionary).is_empty(), "오버시어 금고 — 빈 채로")
