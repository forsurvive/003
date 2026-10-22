## 단계 1-12i i5 R01 비표시 UQ-67 「보라매 마지막 비행」(SD-05 §3.32, 계획 docs/seoul-fallout/_plans/1-12i_UQ-62-67_plan.md §7 · §7b):
## 렌치 · 들창(실패 · 꺼냄) · 봉인 · 봉천 발전기 · 새벽인력 매점 · 기한 뒤 렌치가 쓰러짐 · 머리카락 얘기(테이프 · 쪽지 · 의학) · 반 몫(줌 · 떼먹음 · 묻음) · 지닌 채 라드 · 잃음.
extends RefCounted


func _host(map_id := "X-BC", mark := "from_X-S07") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("MQ101_STAGE", 100)
	st.vars.set_v("MQ101_RESULT", 1)
	st.vars.set_v("GAME_DAY", 5)
	st.vars.set_v("GAME_HOUR", 10)
	st.vars.set_v("PC_CAPS", 200)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 28.  10:00"
	var c := UqR01.new()
	c.setup(h)
	h.enter(map_id, mark)
	return [h, st, c]


func _v(st: StoryState, k: String) -> int:
	return int(st.vars.get_v(k))


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func _play(st: StoryState, c: UqR01, id: String, picks: Array = []) -> Array:
	var dr := DialogueRunner.new(st)
	var cur := dr.start(_scene(id))
	var k := 0
	var guard := 0
	var said := []
	while cur["type"] != "end" and guard < 400:
		guard += 1
		if cur["type"] == "cmd":
			if str(cur["name"]) == "uqr":
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


func _says(st: StoryState, c: UqR01, id: String, needle: String, picks: Array = []) -> bool:
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

func _put(st: StoryState, kv: Dictionary) -> void:
	for k in kv:
		st.vars.set_v(k, kv[k])


func test_uq67_take_power(t) -> void:
	var a := _host("X-BC", "from_X-S07")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_SKP_REPAIR": 60})
	t.ok(_says(st, c, "BM_WRENCH", "봉천 전체에 불이", ["됐다"]), "렌치 — 난로")
	t.eq([st.quests.stage("UQ-67"), _v(st, "UQ67_DUE")], [10, 8], "발동(10) · 렌치의 날 = +3")
	var r0 := _v(st, "PC_RADS")
	t.ok(_says(st, c, "UQ67_HATCH", "배낭이 따뜻하다", ["걸쇠를 풀고"]), "들창 — 꺼냄")
	t.eq([_v(st, "UQ67_CORE"), st.count_of("M-445"), st.quests.stage("UQ-67"), _v(st, "UQ67_DUE")], [2, 1, 20, 0], "지님(20) · 기한 사라짐")
	t.eq(_v(st, "PC_RADS") - r0, 20, "꺼낼 때 20라드")
	c._uq67_day(6)
	t.eq(_v(st, "PC_RADS") - r0, 30, "지닌 채 06:00 — 10라드")
	var bc := _v(st, "AFF_JC_BC")
	var pd := _v(st, "PD_R01")
	t.ok(_says(st, c, "BC_NAM", "죽은 가로등이 둘", ["활주로 공원 전투기 노심", "마을에 쓰세요", "돌아선다"]), "남무진 — ①")
	t.eq([_v(st, "UQ67_CORE"), st.count_of("M-445"), st.quests.stage("UQ-67"), _v(st, "AFF_JC_BC") - bc, _v(st, "PD_R01") - pd], [4, 0, 100, 5, 2], "봉천 발전기 — 100 · BC +5 · 판도 +2")
	t.eq(_v(st, "UQ67_XP"), 1, "90 XP 한 번")
	_put(st, {"SQH_BATT": 81, "UQ67_CORE": 2})
	st.call_fn("give", ["M-445", 1])
	t.ok(_says(st, c, "BC_NAM", "두 배로 밝겠네", ["활주로 공원 전투기 노심", "다시 생각"]), "전지가 이미 들어간 판 — 대사만 다르다")


func test_uq67_fail_seal_and_told(t) -> void:
	var a := _host("X-BC", "from_X-S07")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_SKP_REPAIR": 0, "PC_ST": 7})
	var r0 := _v(st, "PC_RADS")
	t.ok(not _has_opt(st, "UQ67_HATCH", "걸쇠를 풀고"), "수리 0 — [수리 35]는 안 보인다")
	t.ok(_says(st, c, "UQ67_HATCH", "쇠 맛", ["맨손으로"]), "들창 — 맨손(실패 판)")
	t.eq([_v(st, "UQ67_LEAK"), _v(st, "UQ67_CORE"), _v(st, "PC_RADS") - r0], [1, 0, 20], "들창 반쯤 · 20라드")
	t.ok(_says(st, c, "BM_WRENCH", "손 떨리지", ["됐다"]), "렌치 — 거 봐")
	t.ok(_says(st, c, "UQ67_TAPE", "72시간", ["테이프를 튼다"]), "조종사 테이프")
	t.ok(_says(st, c, "BM_WRENCH", "200년이면 좀 늦었네", ["노심 때문이야"]), "테이프를 들려줌 — 렌치가 잠자리를 옮김")
	t.eq([_v(st, "UQ67_TOLD"), _v(st, "UQ67_WRENCH"), _v(st, "UQ67_DUE")], [1, 2, 0], "TOLD · 옮김 · 기한 없음")
	t.ok(_says(st, c, "BM_WRENCH", "머리카락은 다시 안 나겠지", ["됐다"]), "렌치 — 고맙다 · 고철")
	var kr := _v(st, "V_KARMA")
	t.ok(_says(st, c, "UQ67_HATCH", "분필로 판 위에", ["콘크리트 판을 덮어", "통째로 들어 올려"]), "봉인 — [힘 7]")
	t.eq([_v(st, "UQ67_CORE"), st.quests.stage("UQ-67"), _v(st, "V_KARMA") - kr], [1, 100, 25], "봉인 — 100 · 카르마 +25")
	t.ok(_says(st, c, "UQ67_HATCH", "이제 차갑다"), "덮개는 차갑다")


func test_uq67_wrench_due_and_pick(t) -> void:
	var a := _host("X-BC", "from_X-S07")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_play(st, c, "BM_WRENCH", ["됐다"])
	c._uq67_day(7)
	t.eq(_v(st, "UQ67_WRENCH"), 0, "기한 전")
	c._uq67_day(8)
	t.eq([_v(st, "UQ67_CORE"), _v(st, "UQ67_WRENCH")], [5, 3], "렌치가 노심을 안고 봉천 아랫문 밖에 쓰러짐")
	t.ok(st.is_dead("N-R01-063"), "렌치 사망")
	t.ok(_says(st, c, "UQ67_FALLEN", "아직 따뜻하다", ["노심을 거둔다"]), "품에서 거둠")
	t.eq([_v(st, "UQ67_CORE"), st.count_of("M-445"), st.quests.stage("UQ-67")], [2, 1, 20], "지님(20)")
	c._uq67_day(9)
	t.eq(_v(st, "UQ67_WRENCH"), 4, "다음 날 남무진이 묻어 줌")
	st.vars.set_v("PN_NAM", 1)
	t.ok(_says(st, c, "BC_NAM", "내가 묻어 줬어", ["돌아선다"]), "남무진 — 렌치 한 줄(출처: 직접 봄)")
	t.ok(_says(st, c, "UQ67_FALLEN", "쇠지레 하나"), "돌무덤")
	st.call_fn("take", ["M-445", 1])
	c._uq67_day(10)
	t.eq([_v(st, "UQ67_LOST"), st.quests.stage("UQ-67")], [1, 90], "잃음 — 90")


func test_uq67_half_sell_pay_cheat(t) -> void:
	var a := _host("X-BC", "from_X-S07")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_ST": 6, "AFF_SB": 0})
	t.ok(_says(st, c, "BM_WRENCH", "반은 내 몫", ["쇠지레 좀", "같이 꺼내자"]), "렌치와 같이 꺼냄")
	t.eq([_v(st, "UQ67_HALF"), _v(st, "UQ67_CORE"), st.count_of("M-445")], [1, 2, 1], "HALF · 지님")
	var caps := _v(st, "PC_CAPS")
	var sb := _v(st, "AFF_SB")
	t.ok(_says(st, c, "SB_SOGAEBI", "본소가 좋아하지", ["뜨거운 쇠를"]), "소개비 — ③")
	t.eq([_v(st, "UQ67_CORE"), _v(st, "PC_CAPS") - caps, _v(st, "AFF_SB") - sb, st.quests.stage("UQ-67")], [3, 300, 3, 100], "300캡 · SB +3 · 100")
	c._uq67_day(6)
	t.eq(_v(st, "UQ67_ASK"), 6, "다음 06:00 렌치가 아랫문 밖에서 기다림")
	t.ok(_says(st, c, "UQ67_WAIT", "모자 사야겠다", ["여기 네 몫"]), "반 몫 150캡")
	t.eq([_v(st, "UQ67_WRENCH"), _v(st, "PC_CAPS") - caps], [1, 150], "렌치 떠남 · 캡 150")
	var b := _host("X-BC", "from_X-S07")
	var st2: StoryState = b[1]
	var c2: UqR01 = b[2]
	_put(st2, {"UQ67_HALF": 1, "UQ67_CORE": 3, "UQ67_ASK": 6})
	var bc := _v(st2, "AFF_JC_BC")
	t.ok(_says(st2, c2, "UQ67_WAIT", "노심 들고 튄 놈", ["네가 꺼냈어"]), "떼먹음")
	t.eq([_v(st2, "UQ67_WRENCH"), _v(st2, "AFF_JC_BC") - bc], [6, -2], "BC −2 · 소문")
	t.ok(_says(st2, c2, "UQ67_WAIT", "말 걸지 마"), "그 뒤로")


## §7c 재미 검수 · 서사 대조 반영: 들창에서 먼저 만남(MET 2 → AGAIN0 · 기한은 말을 섞은 뒤) · 수레 쇠지레 [힘 6](렌치 옆이면 '내 쇠지레') · 혼자 꺼낸 뒤 렌치 SOLO(옮김) ·
## 남무진이 쳐 준 반 몫은 다음 06:00 떠남(HALFPAY) · 보관함에 둔 노심은 라드 없음 · 남무진이 죽으면 묻지 않음 · 묻힌 뒤에도 노심은 그 옆
func test_uq67_bar_solo_halfpay(t) -> void:
	var a := _host("X-BC", "from_X-S07")
	var st: StoryState = a[1]
	var c: UqR01 = a[2]
	_put(st, {"PC_SKP_REPAIR": 0, "PC_ST": 6})
	t.ok(_says(st, c, "UQ67_HATCH", "그건 내 쇠지레야", ["수레의 쇠지레"]), "렌치가 옆에 있으면 쇠지레는 같이")
	t.eq([_v(st, "UQ67_MET"), _v(st, "UQ67_DUE"), _v(st, "UQ67_CORE")], [2, 0, 0], "들창에서 먼저 — 뒤통수만(MET 2) · 기한 없음")
	t.ok(_says(st, c, "BM_WRENCH", "아까 들창 만지던 손님", ["됐다"]), "렌치 AGAIN0")
	t.ok(_says(st, c, "BM_WRENCH", "또 왔네", ["됐다"]), "그 뒤로는 AGAIN")
	t.ok(_says(st, c, "BM_WRENCH", "사흘만 봐", ["됐다"]) == false, "사흘 예고는 첫 만남 때만")
	t.eq([_v(st, "UQ67_MET"), _v(st, "UQ67_DUE")], [1, 8], "말을 섞은 뒤 기한 +3")
	st.kill("N-R01-063")
	t.ok(_says(st, c, "UQ67_HATCH", "걸쇠가 튕겨 나간다", ["수레의 쇠지레"]), "렌치가 없으면 쇠지레로 꺼냄")
	t.eq([_v(st, "UQ67_CORE"), st.count_of("M-445")], [2, 1], "지님")
	var b := _host("X-BC", "from_X-S07")
	var st2: StoryState = b[1]
	var c2: UqR01 = b[2]
	_put(st2, {"PC_SKP_REPAIR": 60})
	_play(st2, c2, "BM_WRENCH", ["됐다"])
	_play(st2, c2, "UQ67_HATCH", ["걸쇠를 풀고"])
	t.ok(_says(st2, c2, "BM_WRENCH", "식었네", ["됐다"]), "혼자 꺼낸 뒤 렌치 — 난로가 식음")
	t.eq([_v(st2, "UQ67_SSAID"), _v(st2, "UQ67_WRENCH")], [1, 2], "SOLO 한 줄 · 잠자리 옮김")
	t.ok(_says(st2, c2, "BM_WRENCH", "심장 없는 쇠 둘", ["저 전투기는", "됐다"]), "JET_GONE")
	var r0 := _v(st2, "PC_RADS")
	st2.call_fn("take", ["M-445", 1])
	st2.boxes["X-BC:1,1@0"] = {"items": {"M-445": 1}, "opened": 1, "taken": 0}
	c2._uq67_day(6)
	t.eq([_v(st2, "PC_RADS") - r0, _v(st2, "UQ67_LOST")], [0, 0], "보관함에 둔 노심 — 라드 없음 · 잃음 아님")
	var d := _host("X-BC", "from_X-S07")
	var st3: StoryState = d[1]
	var c3: UqR01 = d[2]
	_put(st3, {"PC_ST": 6, "PN_NAM": 1})
	_play(st3, c3, "BM_WRENCH", ["쇠지레 좀", "같이 꺼내자"])
	t.ok(_says(st3, c3, "BC_NAM", "가서 받아 가라고 해", ["활주로 공원 전투기 노심", "마을에 쓰세요", "돌아선다"]), "남무진 — 반 몫 150캡")
	t.eq([_v(st3, "UQ67_HALFPAY"), _v(st3, "UQ67_WRENCH")], [5, 0], "그날은 렌치가 아직 활주로 공원")
	t.ok(_says(st3, c3, "BM_WRENCH", "내일 아침에 봉천 간다", ["됐다"]), "렌치 HALF_PAID")
	c3._uq67_day(6)
	t.eq(_v(st3, "UQ67_WRENCH"), 1, "다음 06:00 받으러 떠남")
	var e := _host("X-BC", "from_X-S07")
	var st4: StoryState = e[1]
	var c4: UqR01 = e[2]
	_play(st4, c4, "BM_WRENCH", ["됐다"])
	st4.kill("N-R01-030")
	c4._uq67_day(8)
	c4._uq67_day(9)
	t.eq([_v(st4, "UQ67_CORE"), _v(st4, "UQ67_WRENCH")], [5, 3], "남무진이 죽었으면 묻지 않음")
	_put(st4, {"UQ67_WRENCH": 4})
	t.ok(_says(st4, c4, "UQ67_FALLEN", "돌무덤 옆에 원통", ["노심을 거둔다"]), "묻힌 뒤에도 노심은 그 옆")
	t.eq([_v(st4, "UQ67_CORE"), st4.count_of("M-445")], [2, 1], "거둠")
