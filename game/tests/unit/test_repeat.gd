## 반복 퀘스트 공통 엔진(1-12j, SD-05 §4.1 · D-238): 회차 곡선 · 주간 캡 연성 상한 1,200 · XP 누적 500 · 같은 날 +2/+1/0 · 일일 +6 ·
## 단골 5회 +3 + 공개도 2 행적(연동) · 단계 5/15/30 · 행동형 10회 판도 +2 · 주 바뀜 초기화 · 주기 · 주간 한도 · regular_every.
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 3)
	st.vars.set_v("PC_CAPS", 0)
	st.vars.set_v("PC_XP", 0)
	return st


func _rq(st: StoryState, id: String, fac: String, caps: int, xp: int, kind := "supply", opt := {}) -> Dictionary:
	return st.call_fn("rq", [id, fac, caps, xp, kind, opt])


func test_repeat_curve_and_caps(t) -> void:
	var st := _st()
	var got := []
	for i in 7:
		st.vars.set_v("GAME_DAY", 1 + i)                                   # 첫 주(1~7일) 날마다 한 번(같은 날 깎임이 끼지 않게)
		got.append(int(_rq(st, "RQ-06", "JH", 50, 10)["caps"]))
	t.eq(got, [50, 50, 50, 38, 38, 25, 25], "회차 곡선 1~3 100% · 4~5 75% · 6~ 50%(캡)")
	t.eq(int(st.vars.get_v("RQ06_T")), 7, "누적 7")
	t.eq(int(st.vars.get_v("RQ06_XP")), 10 + 10 + 10 + 8 + 8 + 5 + 5, "XP도 곡선")
	t.eq(int(st.vars.get_v("RQ_WKCAPS")), 50 + 50 + 50 + 38 + 38 + 25 + 25, "주간 캡 합")
	st.vars.set_v("GAME_DAY", 10)                                            # 둘째 주 — 주간 값 초기화
	var r := _rq(st, "RQ-06", "JH", 50, 10)
	t.eq(int(r["caps"]), 50, "주가 바뀌면 곡선 처음부터")
	t.eq(int(r["wk"]), 1, "이번 주 1회째")
	t.eq(int(st.vars.get_v("RQ_WKCAPS")), 50, "주간 캡 합도 처음부터")
	var f := _rq(st, "RQ-08", "JH", 100, 0, "fixed")
	t.eq(int(f["caps"]), 100, "fixed는 곡선 없음")


func test_repeat_week_cap_and_xp_cap(t) -> void:
	var st := _st()
	st.vars.set_v("RQ_WK", 1)
	st.vars.set_v("RQ_WKCAPS", 1201)                                         # 이미 1,200을 넘겼다
	var r := _rq(st, "RQ-30", "BC", 70, 30, "act")
	t.eq(int(r["caps"]), 35, "연성 상한 넘긴 뒤 캡 ×0.5")
	t.eq(int(r["lean"]), 1, "lean — 의뢰처 대사")
	t.eq(int(st.vars.get_v("RQ_LEAN")), 1, "RQ_LEAN 변수")
	st.vars.set_v("RQ47_XP", 495)
	var x := _rq(st, "RQ-47", "", 50, 15)
	t.eq(int(x["xp"]), 0, "XP 누적 500 상한 — 넘으면 XP 없음(캡은 준다)")
	t.ok(int(x["caps"]) > 0, "캡은 준다")


func test_repeat_aff_same_day_and_daily_cap(t) -> void:
	var st := _st()
	var a0 := int(st.vars.get_v("AFF_JC_BC"))
	var r1 := _rq(st, "RQ-15", "BC", 0, 0, "supply", {"aff": 2})
	var r2 := _rq(st, "RQ-15", "BC", 0, 0, "supply", {"aff": 2})
	var r3 := _rq(st, "RQ-15", "BC", 0, 0, "supply", {"aff": 2})
	t.eq([int(r1["aff"]), int(r2["aff"]), int(r3["aff"])], [2, 1, 0], "같은 날 +2 · +1 · 0(SD-06 §3.4)")
	t.eq(int(st.vars.get_v("AFF_JC_BC")) - a0, 3, "정착지 개별 호감도에 더함(AFF_JC_BC)")
	st.vars.set_v("GAME_DAY", 4)
	st.aff_day["AFF_JC_BC"] = [4, 5]
	var r4 := _rq(st, "RQ-19", "BC", 10, 5, "supply", {"aff": 2})
	t.eq(int(r4["aff"]), 1, "그날 호감 합 +6까지만(5 → 1만 더)")
	var b0 := int(st.vars.get_v("AFF_JC_BC"))
	st.call_fn("aff", ["BC", 3, "day"])
	t.eq(int(st.vars.get_v("AFF_JC_BC")), b0, "RQ로 다 찬 날엔 길 위 도움도 더 오르지 않는다(한 장부 — D-340)")
	st.call_fn("aff", ["BC", 3])
	t.eq(int(st.vars.get_v("AFF_JC_BC")), b0 + 3, "퀘스트 완료 · 인도는 상한 밖")
	st.vars.set_v("GAME_DAY", 5)
	st.call_fn("aff", ["BC", 9, "day"])
	t.eq(int(st.vars.get_v("AFF_JC_BC")), b0 + 9, "다음 날은 다시 +6까지")
	var sv := st.dump()
	var st2 := _st()
	st2.restore(sv)
	t.eq(st2.aff_room("BC"), 0, "그날 몫은 저장 · 불러오기를 건너간다(불러와서 다시 올리기 막음)")


func test_repeat_regular_bonus_and_stages(t) -> void:
	var st := _st()
	var regs := []
	var bonus := 0
	for i in 30:
		st.vars.set_v("GAME_DAY", 3 + i)
		var r := _rq(st, "RQ-06", "JH", 50, 10)
		if int(r["regular"]) > 0:
			regs.append(int(r["regular"]))
		bonus += int(r["bonus"])
	t.eq(regs, [5, 15, 30], "단골 단계 5 · 15 · 30을 넘는 호출에서 regular")
	t.eq(bonus, 6, "누적 5 · 10 · 15 · 20 · 25 · 30회째 보너스")
	t.eq(int(st.vars.get_v("RQF_JH_T")), 30, "세력별 누적")
	t.eq(int(st.call_fn("rq_stage", ["JH"])), 30, "rq_stage")
	var d: Dictionary = st.deeds.list.back()
	t.eq(str(d["tag"]), "RQ_REGULAR", "공개도 2 행적")
	t.eq(int(d["pub"]), 2, "공개도 2")
	t.eq(int(d["fx"].get("JH", 1)), 0, "오른 세력 자신은 0(보너스는 바로 줬다)")
	var st2 := _st()
	st2.vars.set_v("RQF_BC_T", 4)
	var r2 := _rq(st2, "RQ-30", "BC", 70, 30, "act")
	t.eq(int(r2["bonus"]), 1, "정착지(BC)도 단골")
	var d2: Dictionary = st2.deeds.list.back()
	t.eq(int(d2["fx"].get("SB", 0)), -1, "JC 행 연동: 새벽인력 −1(3 × −0.4 → −1)")
	t.ok(not d2["fx"].has("BJ"), "BJ는 3 × −0.3 = −0.9 → 0 쪽으로 버려 없음")


func test_repeat_act_zone_every_wait_left(t) -> void:
	var st := _st()
	var pd0 := int(st.vars.get_v("PD_BC"))
	for i in 10:
		st.vars.set_v("GAME_DAY", 3 + i)
		_rq(st, "RQ-30", "BC", 70, 30, "act", {"zone": "PD_BC"})
	t.eq(int(st.vars.get_v("PD_BC")) - pd0, 2, "행동형 누적 10회째 판도 +2")
	var st2 := _st()
	for i in 10:
		_rq(st2, "RQ-19", "BC", 10, 5, "supply", {"aff": 0, "regular_every": 5})
	t.eq(int(st2.vars.get_v("RQ19_T")), 10, "납품은 다 센다")
	t.eq(int(st2.vars.get_v("RQF_BC_T")), 2, "단골 횟수는 5개마다 한 번")
	st2.vars.set_v("GAME_DAY", 3)
	t.eq(int(st2.call_fn("rq_wait", ["RQ-19", 3])), 3, "주기 3일 — 오늘 했으면 사흘")
	st2.vars.set_v("GAME_DAY", 6)
	t.eq(int(st2.call_fn("rq_wait", ["RQ-19", 3])), 0, "사흘 지나면 0")
	t.eq(int(st2.call_fn("rq_left", ["RQ-19", 30])), 20, "주간 한도 30 중 20 남음")
	st2.vars.set_v("GAME_DAY", 10)
	t.eq(int(st2.call_fn("rq_left", ["RQ-19", 30])), 30, "주가 바뀌면 한도 그대로")
	t.eq(int(st.call_fn("rq_wait", ["RQ-06", 3])), 0, "한 번도 안 했으면 0")
