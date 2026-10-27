## 단계 1-11d SQ-S03 「곰팡이의 근원」(SD-04a §4.3): 발동 셋(게시판 쪽지 · S02 우회 관로 · 저수조 벽) · 순서 파괴(측정지 먼저 → 50) ·
## 해법 A 소각(너구리 7일) · B 약품(과학 25/50) · C 수문 + 인터컴(14일 마름 · 4막 이월) · D 필터(30일 뒤 곰팡내) · A 뒤 C 덮어쓰기 ·
## 왕쥐 CR-097(울음 호출 · 대답이 없으면 물러섬) · E-01 갱도 쥐 · 꼭지 한 모금 · 조수안이 죽으면 칠판 · 정영수 기록 · 옛 저장 맞춤 · 저장 왕복.
extends RefCounted


func _host(date: String, map_id: String, mark: String) -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = date
	var c := SideS03.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


## 원고를 끝까지(또는 picks 차례로 고르며): s03 명령은 진행기로
func _play(st: StoryState, c: SideS03, id: String, picks: Array = [], label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s03":
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


## 장면을 picks대로 돌며 대사 한 줄이라도 needle을 담았나(명령은 진행기로)
func _says(st: StoryState, c: SideS03, id: String, needle: String, picks: Array = []) -> bool:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if str(cur.get("text", "")).contains(needle):
			return true
		if cur["type"] == "cmd":
			if str(cur["name"]) == "s03":
				c._cmd(cur["args"], func() -> void: pass)
			cur = dr.advance()
		elif cur["type"] == "choices":
			var i := 0
			if k < picks.size():
				for j in cur["opts"].size():
					if str(cur["opts"][j]["text"]).contains(str(picks[k])):
						i = j
				k += 1
			cur = dr.choose(i)
		else:
			cur = dr.advance()
	return false


## 선택지 글 목록(열린 것만) — 장면 START에서 첫 선택지까지
func _opts(st: StoryState, id: String, label := "START") -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id), label)
	var guard := 0
	while cur["type"] != "end" and cur["type"] != "choices" and guard < 100:
		guard += 1
		cur = dr.advance()
	var out := []
	if cur["type"] == "choices":
		for o in cur["opts"]:
			if bool(o["enabled"]):
				out.append(str(o["text"]))
	return out


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _day(st: StoryState, c: SideS03, d: int) -> void:
	st.vars.set_v("GAME_DAY", d)
	c._on_day(d)


## 소품의 지금 그림이 그 상태인가("" = 기본)
func _prop_is(h: InteriorHost, name: String, state: String) -> bool:
	for p in h.map.props:
		if p["name"] == name and p.has("node"):
			var e: Dictionary = h.map.prop_meta[name]
			var rect: Array = e["states"][state] if state != "" else e["rect"]
			return (p["node"].texture as AtlasTexture).region == Rect2(rect[0], rect[1], rect[2], rect[3])
	return false


func _count(h: InteriorHost, id: String) -> int:
	return h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == id).size()


func test_sq_s03_trigger_note(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "X-BC", "from_X-S07")
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	_day(st, c, 4)
	t.eq(_v(st, "SQ_S03_ARM"), 4, "MQ-101이 끝난 날을 적는다")
	_day(st, c, 6)
	t.eq(_v(st, "SQ_S03_POSTED"), 0, "이틀 뒤엔 아직")
	_day(st, c, 7)
	t.eq(_v(st, "SQ_S03_POSTED"), 1, "사흘 뒤 06시: 게시판 쪽지")
	t.eq(st.quests.stage("SQ-S03"), 0, "쪽지만 붙었다 — 읽어야 열린다")
	t.ok(_says(st, c, "X-BC_BOARD", "배수지 조수안"), "게시판: 조수안 쪽지")
	t.eq(_play(st, c, "X-BC_BOARD"), [], "게시판을 끝까지")
	t.eq(st.quests.stage("SQ-S03"), 10, "쪽지를 읽음 → 단계 10")
	t.eq(_play(st, c, "SQS03_WALL"), [], "저수조 이음 벽")
	t.eq(st.quests.stage("SQ-S03"), 20, "볼트 회의 기억(농장 2동 · 3동) → 단계 20")
	t.ok(not _says(st, c, "X-BC_BOARD", "배수지 저수조 이음 벽"), "20부터 게시판 쪽지는 내려간다")
	t.ok("저수조 벽의 검은 얼룩 말이야" in _opts(st, "SQS02_SUAN", "ASK"), "조수안 ASK: S03 한 줄")
	t.eq(_play(st, c, "SQS02_SUAN", ["얼룩"], "ASK"), [], "조수안: 옛 관로를 가리킨다")
	t.ok(not ("저수조 벽의 검은 얼룩 말이야" in _opts(st, "SQS02_SUAN", "ASK")), "한 번 들으면 내려간다")
	t.eq(_play(st, c, "SQS03_P1"), [], "조사 ① 옛 관 입구")
	t.eq(st.quests.stage("SQ-S03"), 20, "한 곳으로는 아직")
	c._cmd(["point", 2], func() -> void: pass)
	t.eq(st.quests.stage("SQ-S03"), 30, "두 곳 → 30")


func test_sq_s03_trigger_wall_pipe(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "X-BS", "tanks")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	t.eq(_play(st, c, "SQS03_WALL"), [], "쪽지 없이 벽부터")
	t.eq(st.quests.stage("SQ-S03"), 20, "벽을 먼저 봄 → 10 → 바로 20")
	t.ok(_says(st, c, "SQS03_WALL", "물이 드나드는 이음 벽"), "두 번째는 짧게")
	var r2 := _host("2277. 10. 26.  08:00", "X-BC", "from_X-S07")
	var st2: StoryState = r2[1]
	var c2: SideS03 = r2[2]
	st2.vars.set_v("SQ_S03_PIPE", 1)
	c2._process(1.0)
	t.eq(st2.quests.stage("SQ-S03"), 10, "S02 우회 관로 → 다음 틀에 10")
	c2._process(1.0)
	t.eq(st2.quests.stage("SQ-S03"), 10, "한 번만")
	t.ok(_prop_is(h, "mold_patch", ""), "X-BS 얼룩은 그대로")


func test_sq_s03_order_break(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	t.eq(_count(h, "CR-095") >= 4 and _count(h, "CR-095") <= 10, true, "첫 방문: 시궁쥐 무리(맵 넷 + 진행기 4~6)")
	t.eq(_count(h, "CR-097"), 0, "퀘스트 전 첫 방문엔 왕쥐가 없다(3회째)")
	t.eq(_play(st, c, "K-08_TECH"), [], "정비공 유해 먼저")
	t.eq([st.count_of("M-302"), _v(st, "SQ_S03_TAGSEEN")], [1, 1], "측정지 M-302 · 인식표를 봄")
	t.eq(st.quests.stage("SQ-S03"), 0, "퀘스트 전 — 사실만 남는다")
	t.eq(_play(st, c, "SQS03_P2"), [], "조사 ② 줄무늬")
	t.eq(_play(st, c, "SQS03_BOX"), [], "측정 상자 분무기")
	t.eq(_v(st, "SQ_S03_SPRAY"), 1, "분무기")
	h.enter("E-01", "from_W")
	t.eq([_count(h, "CR-095"), _count(h, "CR-002")], [3, 2], "갱도: 시궁쥐 셋 · 큰바퀴 둘")
	t.eq(_play(st, c, "SQS03_BELT"), [], "측실 공구 벨트")
	t.eq(_v(st, "SQ_S03_NAME"), 1, "정영수")
	t.eq(_play(st, c, "SQS03_GATE", ["그냥"]), [], "수문만 살핌")
	t.eq(_v(st, "SQ_S03_GATE"), 1, "수문 살핌")
	t.eq(st.quests.stage("SQ-S03"), 0, "아직 퀘스트 전")
	h.enter("E-01", "from_W")
	t.ok(_count(h, "CR-095") <= 3, "갱도 쥐가 불어나지 않는다")
	h.enter("X-BS", "tanks")
	t.eq(_play(st, c, "SQS03_WALL"), [], "그다음 벽")
	t.eq(st.quests.stage("SQ-S03"), 60, "이미 한 일 따라 올림: 벽 20 · 조사 ②③ 아직 하나지만 측정지 50 · 수문 60")
	t.ok(st.quests.stage("SQ-S03") < 70, "해법 전")


func test_sq_s03_sol_a_raccoon_report(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	t.eq(_play(st, c, "SQS03_WALL"), [], "벽")
	st.call_fn("give", ["W-057", 3])
	t.ok(_prop_is(h, "w_mold_colony", ""), "군락: 살아 있음")
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(st, c, "SQS03_COLONY", ["화염병"]), [], "화염병 셋")
	t.eq([_v(st, "SQ_S03_SOL"), _v(st, "SQ_S03_CLEAN"), st.quests.stage("SQ-S03"), st.count_of("W-057")], [1, 1, 70, 0], "해법 A 소각 · 70 · 화염병 셋을 썼다")
	t.eq(_v(st, "V_KARMA") - k0, 0, "카르마 0")
	t.ok(_prop_is(h, "w_mold_colony", "burnt"), "군락: 그을음")
	t.eq(_v(st, "SQ_S03_RACC_UNTIL"), _v(st, "GAME_DAY") + 7, "이레 동안 너구리")
	var en := Encounters.new(st, 3)
	var racc := {"cat": "creature", "groups": [{"units": [["CR-136", 2]]}]}
	t.ok(absf(en.cat_mult(racc, "R01", Vector2i(892, 1362), true) - 1.3 * 1.3) < 0.01, "봉천 밤 옴 너구리 ×1.3(밤) ×1.3(A)")
	t.ok(absf(en.cat_mult(racc, "R01", Vector2i(892, 1362), false) - 1.0) < 0.01, "낮엔 그대로")
	st.vars.set_v("GAME_DAY", _v(st, "GAME_DAY") + 7)
	t.ok(absf(en.cat_mult(racc, "R01", Vector2i(892, 1362), true) - 1.3) < 0.01, "이레 뒤엔 밤 배수만")
	var caps := _v(st, "PC_CAPS")
	var bc := _v(st, "AFF_JC_BC")
	t.ok(_says(st, c, "SQS02_SUAN", "너구리"), "조수안: 너구리 조심")
	t.eq(_play(st, c, "SQS02_SUAN"), [], "조수안에게 보고")
	t.eq(st.quests.stage("SQ-S03"), 100, "보고 → 100")
	t.eq([_v(st, "PC_CAPS") - caps, _v(st, "AFF_JC_BC") - bc, _v(st, "SQ_S03_FILTER"), _v(st, "SQ_S03_REWARD")], [100, 6, 1, 1], "사례 100캡 · 봉천 +6 · 꼭지 필터")
	c._cmd(["report"], func() -> void: pass)
	t.eq(_v(st, "PC_CAPS") - caps, 100, "보고는 한 번만")
	h.enter("X-BS", "tanks")
	t.ok(_prop_is(h, "mold_patch", "scrubbed") and _prop_is(h, "intake_screen", "clean"), "배수지: 닦은 벽 · 빈 거름망")
	t.ok(_says(st, c, "SQS03_SIGN", "안 끓여도 됨"), "후일담: 안내판")
	var rads := _v(st, "PC_RADS")
	t.eq(_play(st, c, "SQS03_TAP", ["마신다"]), [], "꼭지 한 모금")
	t.eq(_v(st, "PC_RADS"), rads, "필터: 방사능 0")


func test_sq_s03_sol_b(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	st.call_fn("give", ["M-021", 2])
	st.call_fn("give", ["M-022", 1])
	t.ok(not _opts(st, "SQS03_COLONY").any(func(o): return str(o).contains("뿌린다")), "분무기 없이는 약품 판이 없다")
	t.eq(_play(st, c, "SQS03_BOX"), [], "분무기")
	st.vars.set_v("PC_SKP_SCIENCE", 30)
	t.ok(not _opts(st, "SQS03_COLONY").any(func(o): return str(o).contains("뿌린다")), "과학 30: 측정지 없이는 배합을 못 한다(과학 50)")
	st.vars.set_v("PC_SKP_SCIENCE", 60)
	t.ok(_opts(st, "SQS03_COLONY").any(func(o): return str(o).contains("배합을 계산해")), "측정지 없으면 과학 50")
	st.vars.set_v("PC_SKP_SCIENCE", 30)
	st.call_fn("give", ["M-302", 1])
	t.ok(_opts(st, "SQS03_COLONY").any(func(o): return str(o).contains("측정지 수치대로")) and not _opts(st, "SQS03_COLONY").any(func(o): return str(o).contains("배합을 계산해")), "측정지 있으면 과학 25")
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(st, c, "SQS03_COLONY", ["측정지 수치대로"]), [], "약품 배합")
	t.eq([_v(st, "SQ_S03_SOL"), _v(st, "SQ_S03_CLEAN"), st.count_of("M-021"), st.count_of("M-022")], [2, 1, 0, 0], "해법 B · 세제 둘 · 시너 하나")
	t.eq(_v(st, "V_KARMA") - k0, 25, "카르마 +25")
	t.eq(st.quests.stage("SQ-S03"), 70, "퀘스트 전에 처리해도 열리며 바로 70(P2)")
	t.ok(_prop_is(h, "w_mold_colony", "sprayed"), "군락: 바랜 반점")
	t.eq(_v(st, "SQ_S03_RACC_UNTIL"), 0, "B는 너구리 없음")
	t.ok(_says(st, c, "SQS03_COLONY", "하얗게 바랬다"), "다시 보면 바랜 천장")


func test_sq_s03_sol_c_dry(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "E-01", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	t.eq(_play(st, c, "SQS03_P3"), [], "조사 ③ 출구 물길")
	st.vars.set_v("PC_ST", 7)
	t.eq(_play(st, c, "SQS03_GATE", ["온몸으로"]), [], "수문을 온몸으로")
	t.eq(_v(st, "SQ_S03_GATE"), 2, "수문 닫힘")
	t.ok(_prop_is(h, "sluice_gate", "shut"), "수문 소품: 내려앉은 판")
	t.eq(_v(st, "SQ_S03_SOL"), 0, "볼트에 알리기 전엔 아직")
	st.call_fn("give", ["M-302", 1])
	h.enter("X-S07", "start")
	t.ok(_says(st, c, "SQS03_INTERCOM", "잡음", ["누른다"]), "호출 1: 잡음")
	var k0 := _v(st, "V_KARMA")
	t.ok(_says(st, c, "SQS03_INTERCOM", "역류", ["누른다"]), "둘째 호출(측정지가 있으면 받는다) — 수문을 먼저 닫았으면 방금례가 먼저 묻는다")
	t.eq(_play(st, c, "SQS03_INTERCOM", ["누른다", "수치를 읽어", "끊는다"]), [], "방금례 — 측정지 수치")
	t.eq([_v(st, "SQ_S03_VAULT"), _v(st, "SQ_S03_SOL"), _v(st, "SQR_S03")], [2, 3, 3], "해법 C · 4막 이월")
	t.eq(_v(st, "V_KARMA") - k0, 100, "카르마 +100")
	t.eq(st.quests.stage("SQ-S03"), 70, "70")
	t.eq(_v(st, "SQ_S03_CLEAN"), 0, "군락은 아직 — 두 주에 걸쳐 마른다")
	var d0 := _v(st, "SQ_S03_DRY_DAY")
	h.enter("X-BS", "tanks")
	_day(st, c, d0 + 7)
	t.eq(_play(st, c, "SQS03_TAP", ["마신다"]), [], "이레째 한 모금")
	t.ok(str(h.hints[-1][0]).contains("조금 남았다"), "냄새가 반쯤 빠졌다")
	h.enter("K-08", "from_W")
	t.ok(_prop_is(h, "w_mold_colony", "dry1"), "K-08 군락: 마르는 중")
	t.eq(_count(h, "CR-097"), 1, "퀘스트가 열려 있으면 첫 방문에 왕쥐")
	_day(st, c, d0 + 14)
	t.eq(_v(st, "SQ_S03_CLEAN"), 1, "14일: 다 말랐다")
	t.ok(_prop_is(h, "w_mold_colony", "dry2"), "군락: 다 마름(하루 판정에 바로)")
	t.ok(_says(st, c, "SQS02_SUAN", "2주면 마른대"), "조수안: C 보고")
	t.eq(_play(st, c, "SQS02_SUAN"), [], "조수안에게 보고")
	t.eq([st.quests.stage("SQ-S03"), _v(st, "AFF_JC_BC")], [100, 8], "100 · 봉천 +8")
	t.ok(_says(st, c, "SQS03_INTERCOM", "또 그쪽이네요", ["누른다"]), "인터컴은 다음부터 바로 받는다")


func test_sq_s03_a_then_c(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	st.call_fn("give", ["W-057", 3])
	t.eq(_play(st, c, "SQS03_COLONY", ["화염병"]), [], "A 소각")
	var k0 := _v(st, "V_KARMA")
	c._cmd(["shut"], func() -> void: pass)
	c._cmd(["vault"], func() -> void: pass)
	t.eq([_v(st, "SQ_S03_SOL"), _v(st, "SQR_S03"), _v(st, "SQ_S03_CLEAN")], [3, 3, 1], "C로 덮어쓴다 · 이미 맑음")
	t.eq(_v(st, "V_KARMA") - k0, 100, "카르마는 C 몫만")
	t.ok(_prop_is(h, "w_mold_colony", "dry2"), "태운 군락이 살아나 보이지 않는다 — 바로 다 마른 모습")
	t.ok(_says(st, c, "SQS03_SIGN", "안 끓여도 됨"), "안내판도 바로")


func test_sq_s03_sol_d_filter(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "X-BS", "tanks")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	t.eq(_play(st, c, "SQS03_WALL"), [], "벽")
	st.call_fn("give", ["M-013", 1])
	st.vars.set_v("PC_SKP_REPAIR", 40)
	var bc := _v(st, "AFF_JC_BC")
	t.eq(_play(st, c, "SQS02_SUAN", ["필터", "강판으로"], "ASK"), [], "조수안: 꼭지 필터")
	t.eq([_v(st, "SQ_S03_FILTER"), st.count_of("M-013"), _v(st, "AFF_JC_BC") - bc], [1, 0, 3], "D 필터 · 강판 · 봉천 +3")
	t.eq(st.quests.stage("SQ-S03"), 20, "D는 단계를 닫지 않는다")
	var d0 := _v(st, "SQ_S03_FILTER_DAY")
	var rads := _v(st, "PC_RADS")
	t.eq(_play(st, c, "SQS03_TAP", ["마신다"]), [], "필터 물")
	t.eq(_v(st, "PC_RADS"), rads, "방사능 0")
	_day(st, c, d0 + 10)
	t.ok(_says(st, c, "SQS03_CHALK", "필터 10일째"), "칠판이 날을 센다")
	_day(st, c, d0 + 26)
	t.ok(_says(st, c, "SQS03_CHALK", "필터가 검다"), "25일 넘으면 검다")
	_day(st, c, d0 + 30)
	t.eq(_v(st, "SQ_S03_SMELL"), 1, "30일: 곰팡내가 돌아온다")
	t.ok(_says(st, c, "SQS03_CHALK", "냄새 돌아옴"), "칠판: 근원은 그대로")
	rads = _v(st, "PC_RADS")
	t.eq(_play(st, c, "SQS03_TAP", ["마신다"]), [], "냄새 나는 물")
	t.eq(_v(st, "PC_RADS"), rads, "방사능 0은 그대로(벌이 아니라 냄새만)")
	h.enter("K-08", "from_W")
	var n1 := _count(h, "CR-095")
	t.ok(n1 >= 6, "첫 방문 무리 + 다시 열린 일 시궁쥐 둘")
	t.eq(_count(h, "CR-097"), 1, "왕쥐(퀘스트 열림)")
	t.eq(_v(st, "SQ_S03_RAT2"), 1, "곰팡내 뒤 쥐 둘")
	st.call_fn("give", ["W-057", 3])
	t.eq(_play(st, c, "SQS03_COLONY", ["화염병"]), [], "그때 처리해도")
	t.eq([_v(st, "SQ_S03_CLEAN"), st.quests.stage("SQ-S03")], [1, 70], "맑음 · 70")
	t.ok(_says(st, c, "SQS02_SUAN", "네가 단 필터는"), "조수안: 네가 단 필터")


func test_sq_s03_rat_king(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "K-08", "from_W")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	t.eq(_count(h, "CR-097"), 0, "첫 방문(퀘스트 전): 없음")
	h.enter("X-BS", "tanks")
	h.enter("K-08", "from_W")
	t.eq(_count(h, "CR-097"), 0, "둘째 방문: 없음")
	h.enter("X-BS", "tanks")
	h.enter("K-08", "from_W")
	t.eq(_count(h, "CR-097"), 1, "셋째 방문: 왕쥐(SD-09a)")
	var king: Enemy = null
	for e in h.combat.enemies:
		if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-097":
			king = e
	t.ok(king != null and king.call_cb.is_valid(), "울음 호출 연결")
	h.combat._rat_call(king)
	t.eq(int(h.combat.stats.get("rat_calls", 0)), 1, "찍찍 한 번")
	t.ok(king.brain.state != AIBrain.S.FLEE, "대답하는 쥐가 있으면 물러서지 않는다")
	for e in h.combat.enemies:
		if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-095":
			e.cmb.dead = true
	h.combat._rat_call(king)
	t.eq(king.brain.state, AIBrain.S.FLEE, "대답이 없다 — 왕쥐가 물러선다")
	king.cmb.hp = 60.0
	c._process(1.0)
	t.eq(_v(st, "SQ_S03_KING_HP"), 60, "깎인 체력을 적어 둔다")
	h.enter("X-BS", "tanks")
	h.enter("K-08", "from_W")
	t.eq(_count(h, "CR-097"), 1, "물러선 왕쥐는 둥지로 돌아와 있다")
	var k2: Enemy = null
	for e in h.combat.enemies:
		if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-097":
			k2 = e
	t.ok(k2 != null and absf(k2.cmb.hp - 60.0) < 0.5, "깎인 체력 그대로")
	t.ok(h.hints.any(func(x): return str(x[0]).contains("흉터가 하나 늘었다")), "흉터가 하나 늘었다")
	h.combat.enemy_killed.emit("CR-097", 0)
	t.eq(_v(st, "SQ_S03_KING"), 2, "쓰러뜨림")
	h.enter("X-BS", "tanks")
	h.enter("K-08", "from_W")
	t.eq(_count(h, "CR-097"), 0, "쓰러뜨린 왕쥐는 다시 서지 않는다")


func test_sq_s03_suan_dead_tag(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "X-BS", "tanks")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	st.kill("N-R01-032")
	st.vars.set_v("SQ_S03_POSTED", 1)
	t.ok(_says(st, c, "X-BC_BOARD", "본 사람은 반상회로"), "조수안이 죽었으면 쪽지는 반상회 서명")
	t.eq(_play(st, c, "X-BC_BOARD"), [], "게시판을 끝까지")
	t.eq(st.quests.stage("SQ-S03"), 10, "그 쪽지로도 10")
	st.vars.set_v("SQ_S03_NAME", 1)
	st.call_fn("give", ["M-302", 1])
	st.vars.set_v("SQ_S03_CALLS", 2)
	var k0 := _v(st, "V_KARMA")
	t.eq(_play(st, c, "SQS03_INTERCOM", ["누른다", "정영수", "기다렸음", "끊는다"]), [], "인터컴: 정영수 기록 고쳐 적기")
	t.eq([_v(st, "SQ_S03_TAG"), _v(st, "V_KARMA") - k0], [1, 25], "기록 · 카르마 +25")
	t.ok(not ("정영수라는 이름, 기록에 있어?" in _opts(st, "SQS03_INTERCOM", "MENU")), "한 번만")
	st.call_fn("give", ["W-057", 3])
	c._cmd(["burn"], func() -> void: pass)
	t.eq(st.quests.stage("SQ-S03"), 70, "A")
	var caps := _v(st, "PC_CAPS")
	t.ok(_says(st, c, "SQS03_CHALK", "근원 처리함"), "관리인 없는 칠판에 적는다")
	t.eq(_play(st, c, "SQS03_CHALK"), [], "칠판")
	t.eq([st.quests.stage("SQ-S03"), _v(st, "PC_CAPS") - caps, _v(st, "SQ_S03_FILTER")], [100, 100, 1], "100 · 반상회 궤짝 100캡 · 필터")


func test_sq_s03_fun_fixes(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "X-BS", "tanks")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	t.ok(_says(st, c, "SQS03_COLONY", "물이 들어오는 데를 막든가"), "맨손으로 와도 해법 셋의 실마리가 보인다")
	t.ok(_says(st, c, "SQS03_BOX", "세제 2 · 희석제 1"), "배합은 분무기를 처음 집을 때 보인다")
	st.kill("N-R01-032")
	t.eq(_play(st, c, "SQS03_WALL"), [], "벽")
	st.call_fn("give", ["M-013", 1])
	st.vars.set_v("PC_SKP_REPAIR", 40)
	t.eq(_play(st, c, "SQS03_TAP", ["필터 틀"]), [], "조수안이 없어도 꼭지에서 D")
	t.eq([_v(st, "SQ_S03_FILTER"), st.count_of("M-013")], [1, 0], "필터 · 강판")
	t.ok(not _says(st, c, "SQS03_CHALK", "조수안"), "칠판 글씨는 누구의 것인지 말하지 않는다(생사 무관)")
	t.ok(_says(st, c, "SQS03_P3", "검은 막이 물살"), "물길: 처리 전")
	st.vars.set_v("SQ_S03_SOL", 1)
	st.vars.set_v("SQ_S03_CLEAN", 1)
	t.ok(_says(st, c, "SQS03_P3", "여전히"), "A · B 뒤 물길: 근원은 그대로")
	st.vars.set_v("SQ_S03_SOL", 3)
	t.ok(_says(st, c, "SQS03_P3", "갈라졌다"), "C 뒤 물길: 말라 갈라짐")
	st.vars.set_v("SQ_S03_VAULT", 1)
	t.ok(_says(st, c, "SQS03_INTERCOM", "파종", ["누른다", "안은 어때"]), "인터컴 '안은 어때?' — C 뒤")
	st.vars.set_v("SQ_S03_SOL", 0)
	t.ok(_says(st, c, "SQS03_INTERCOM", "반감", ["누른다", "안은 어때"]), "C 전엔 배급표 '반감'")
	h.enter("K-08", "from_W")
	var n := 0
	for p in h.map.props:
		if str(p["name"]).begins_with("w_mold_streak"):
			n += 1
	t.eq(n, 7, "군락에서 갱도 쪽으로 이어지는 줄기 일곱")
	st.vars.set_v("SQ_S03_SOL", 1)
	c._looks()
	t.ok(_prop_is(h, "w_mold_streak3", "burnt"), "줄기도 함께 그을린다")


func test_sq_s03_noise2(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "X-S07", "start")
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	t.ok(_says(st, c, "SQS03_INTERCOM", "잡음", ["누른다"]), "첫 호출: 잡음")
	t.ok(_says(st, c, "SQS03_INTERCOM", "다시 끊긴다", ["누른다"]), "둘째 호출: 수화기 드는 소리 — 누군가 듣고 있다")
	t.ok(_says(st, c, "SQS03_INTERCOM", "등록 번호", ["누른다"]), "셋째 호출: 받는다")


func test_sq_s03_cold_vault(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "X-S07", "start")
	var st: StoryState = r[1]
	var c: SideS03 = r[2]
	st.vars.set_v("V_ESCAPE", 1)
	st.vars.set_v("SQ_S03_CALLS", 2)
	t.ok(_says(st, c, "SQS03_INTERCOM", "의무실", ["누른다"]), "폭력 탈출이면 차갑게 — 그래도 회선은 받는다")
	t.ok(_says(st, c, "SQS03_INTERCOM", "문은 못 열어요", ["누른다"]) or _v(st, "SQ_S03_VAULT") == 1, "문은 열리지 않는다(정문 하나 · 봉쇄)")


func test_sq_s03_migrate_save(t) -> void:
	var r := _host("2277. 10. 26.  08:00", "X-BC", "from_X-S07")
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	st.vars.set_v("PL_TECH", 1)
	var c2 := SideS03.new()
	c2.setup(h)
	t.eq([_v(st, "SQ_S03_TAGSEEN"), st.count_of("M-302")], [1, 1], "옛 저장: 유해를 봤으면 측정지 물건을 맞춘다")
	c2._migrate()                                                  # 다시 불러온 것처럼 맞추기만 한 번 더(신호는 한 번만 잇는다)
	t.eq(st.count_of("M-302"), 1, "두 번 주지 않는다")
	st.vars.set_v("SQ_S03_SOL", 3)
	st.vars.set_v("SQ_S03_DRY_DAY", 9)
	st.vars.set_v("SQ_S03_FILTER", 1)
	var js := JSON.stringify(GameSnapshot.story(st))
	var st2 := StoryState.new()
	st2.load_data()
	GameSnapshot.apply_story(st2, JSON.parse_string(js))
	t.eq([int(st2.vars.get_v("SQ_S03_SOL")), int(st2.vars.get_v("SQ_S03_DRY_DAY")), int(st2.vars.get_v("SQ_S03_FILTER")), st2.count_of("M-302")], [3, 9, 1, 1], "저장 왕복: 사실 변수 · 측정지")
	c2.free()
