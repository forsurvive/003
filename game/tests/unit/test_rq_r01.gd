## 1막 반복 의뢰 진행기(1-12j — RQ-19 · 15 · 06 · 08 · 30 · 22 · 03 · 43 · 46): 명령 단위 — 공고 · 증거 보상 · 배수구 의뢰 · 식량 80어치 · 장부 분기 · 배급 증명.
extends RefCounted


func _host() -> Array:
	var st := StoryState.new()
	st.load_data()
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 6)
	st.quests.set_stage("MQ-101", 100)
	st.vars.set_v("MQ101_RESULT", 1)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 28.  10:00"
	h.enter("B-01", "from_X-BC")
	var r := RqR01.new()
	r.setup(h, false)
	return [h, st, r]


func _cmd(r: RqR01, a: Array) -> void:
	r._cmd(a, func() -> void: pass)


func test_rq_bounty_post_claim(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var r: RqR01 = a[2]
	_cmd(r, ["03", "post", "B"])
	t.eq(int(st.vars.get_v("RQ03B_ST")), 0, "SQ-S01 · S02 전엔 봉천 대상이 없다(자리 겹침 — 공고 없음)")
	st.quests.set_stage("SQ-S01", 100)
	st.quests.set_stage("SQ-S02", 100)
	_cmd(r, ["03", "post", "B"])
	t.eq(int(st.vars.get_v("RQ03B_ST")), 1, "게시판을 읽으면 공고(1)")
	var tg := int(st.vars.get_v("RQ03B_T"))
	t.ok(tg >= 1 and tg <= 3, "대상 1~3")
	t.eq(int(st.vars.get_v("RQ03B_DAY")), 6, "공고 날")
	_cmd(r, ["03", "post", "B"])
	t.eq(int(st.vars.get_v("RQ03B_T")), tg, "다시 읽어도 같은 공고")
	st.vars.set_v("RQ03B_ST", 2)                                             # 진행기가 대상이 쓰러질 때 2로 올리고 증거를 준다
	var caps := int(st.vars.get_v("PC_CAPS"))
	var bc := int(st.vars.get_v("AFF_JC_BC"))
	_cmd(r, ["03", "claim", "B"])
	t.eq(int(st.vars.get_v("RQ03B_ST")), 3, "보상 뒤 3(이번 주 끝)")
	t.eq(int(st.vars.get_v("RQ03_T")), 1, "RQ-03 누적 1")
	t.eq(int(st.vars.get_v("PC_CAPS")) - caps, int(RqR01.BOUNTY["B"][tg - 1]["caps"]), "대상별 캡")
	t.eq(int(st.vars.get_v("AFF_JC_BC")) - bc, 3, "정착지 +3")
	_cmd(r, ["03", "post", "B"])
	t.eq(int(st.vars.get_v("RQ03B_ST")), 3, "이레 안엔 새 공고 없음")
	st.vars.set_v("GAME_DAY", 13)
	_cmd(r, ["03", "post", "B"])
	t.eq(int(st.vars.get_v("RQ03B_ST")), 1, "이레 뒤 새 공고")
	_cmd(r, ["03", "post", "S"])
	t.eq(int(st.vars.get_v("RQ03S_ST")), 1, "사당 게시판은 따로")
	t.ok(int(st.vars.get_v("RQ03S_T")) in [1, 2], "사당 대상 1~2")


func test_rq_drain_and_food(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var r: RqR01 = a[2]
	_cmd(r, ["22", "start"])
	t.eq(int(st.vars.get_v("RQ22_ON")), 1, "배수구 의뢰 받음")
	t.ok(int(st.vars.get_v("RQ22_SET")) in [1, 2, 3] and int(st.vars.get_v("RQ22_K")) in [1, 2], "자리 조합 · 둥지 수")
	st.vars.set_v("RQ22_ON", 2)
	var caps := int(st.vars.get_v("PC_CAPS"))
	_cmd(r, ["22", "done"])
	t.eq(int(st.vars.get_v("RQ22_ON")), 0, "보고 뒤 닫힘")
	t.eq(int(st.vars.get_v("PC_CAPS")) - caps, 60, "60캡")
	t.eq(st.count_of("I-059"), 3, "정수 셋")
	t.eq(int(st.call_fn("rq_wait", ["RQ-22", 7])), 7, "이레 뒤")
	st.call_fn("give", ["I-026", 2])                                        # 참치 통조림 둘 — 가치가 80에 못 미치면 받지 않는다
	_cmd(r, ["43", "food"])
	var have := int(st.vars.get_v("RQ43_HAVE"))
	var worth := int(a[0].items_db["I-026"]["value"]) * 2
	t.eq(have, 1 if worth >= 80 else 0, "식량 가치 80 판정(통조림 둘 = %d)" % worth)
	st.call_fn("give", ["I-031", 3])                                        # 전투식량 셋 — 넉넉히
	st.call_fn("give", ["I-040", 1])
	var k0 := int(st.vars.get_v("V_KARMA"))
	var n0 := int(st.vars.get_v("RQ43_T"))
	st.vars.set_v("GAME_DAY", 9)
	_cmd(r, ["43", "food"])
	t.eq(int(st.vars.get_v("RQ43_HAVE")), 1, "넉넉하면 받는다")
	t.eq(int(st.vars.get_v("RQ43_T")), n0 + 1, "RQ-43 누적")
	t.eq(int(st.vars.get_v("V_KARMA")) - k0, 10, "카르마 +10")
	t.ok(st.count_of("I-040") == 0, "비싼 것부터 꺼낸다(스테이크)")


func test_rq_refugee_ledger(t) -> void:
	var a := _host()
	var st: StoryState = a[1]
	var r: RqR01 = a[2]
	_cmd(r, ["46", "start"])
	t.eq(int(st.vars.get_v("RQ46_ON")), 1, "피난민 의뢰 받음")
	st.vars.set_v("RQ46_IN", 3)
	var jc := int(st.vars.get_v("AFF_JC"))
	var xp := int(st.vars.get_v("PC_XP"))
	_cmd(r, ["46", "cert"])
	t.eq(int(st.vars.get_v("RQ46_T")), 1, "배급 증명 1회")
	t.eq(int(st.vars.get_v("AFF_JC")) - jc, 2, "JC +2")
	t.eq(int(st.vars.get_v("PC_XP")) - xp, 20, "20 XP")
	t.eq(int(st.vars.get_v("RQ46_ON")), 0, "닫힘")
	var bj := int(st.vars.get_v("AFF_BJ"))
	var k := int(st.vars.get_v("V_KARMA"))
	_cmd(r, ["46", "ledger", "2"])
	t.eq(int(st.vars.get_v("RQ46_LEDGER")), 2, "장부를 태움")
	t.eq(int(st.vars.get_v("AFF_BJ")) - bj, -3, "BJ −3")
	t.eq(int(st.vars.get_v("V_KARMA")) - k, 25, "카르마 +25")
	var b := _host()
	var st2: StoryState = b[1]
	var r2: RqR01 = b[2]
	var bj2 := int(st2.vars.get_v("AFF_BJ"))
	_cmd(r2, ["46", "ledger", "3"])
	t.eq(int(st2.vars.get_v("AFF_BJ")) - bj2, 5, "넘기면 BJ +5")
	st2.vars.set_v("RQ46_ON", 1)
	st2.vars.set_v("RQ46_IN", 3)
	_cmd(r2, ["46", "cert"])
	t.eq(int(st2.vars.get_v("AFF_BJ")) - bj2, 6, "그 뒤 증명마다 BJ +1")
