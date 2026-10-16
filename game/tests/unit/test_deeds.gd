## 단계 1-10c 정보 전파(SD-06 §6): 공개도별 경로 · 지연(소문 12시간 + 인접 구역마다 12시간, 3구역까지 · 정보원 6시간 · 정시 방송) ·
## 도착 때 호감도 반영 · 시간 도약에도 순서대로 · 직접 목격 즉시 · 7일 소멸 · 저장 왕복 · MQ-106 걸어 들어감(정착 −3 · 봉천 의심 하루).
extends RefCounted

const T0 := 10 * 1440 + 9 * 60                    ## 게임 분(어느 날 09:00)


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	return st


func test_deeds_routes(t) -> void:
	t.eq(Deeds.dist("R01", "R01"), 0, "같은 구역")
	t.eq(Deeds.dist("R01", "R02"), 1, "관악 → 여의도 인접")
	t.eq(Deeds.dist("R01", "HR"), 2, "관악 → 한강(노들섬) 두 칸")
	t.ok(Deeds.dist("R01", "R09") > 2, "관악 → 북부 산악: 소문이 안 닿는다(3구역까지)")
	var st := _state()
	var dd := st.deeds
	var base_sb := int(st.vars.get_v("AFF_SB"))
	var d := dd.record(st, "도움", "R01", 2, {"SB": -5, "JC_BC": 0}, T0, {"what": "시험"})
	t.eq(dd.arrival(d, "JC_BC"), [T0 + 12 * 60, "소문"], "같은 구역(봉천): 12시간 소문")
	t.eq(dd.arrival(d, "SB"), [T0 + 24 * 60, "소문"], "새벽인력 본소(R02): 24시간")
	dd.tick(st, T0 + 1)
	t.eq(int(st.vars.get_v("AFF_SB")), base_sb, "아직 모른다: 호감도 그대로")
	dd.tick(st, T0 + 3 * 60 + 1)                                         # 12:00 정시: 공개도 2 한 건은 남산 뉴스가 먼저 퍼뜨린다
	t.eq(str(d.get("news_by", "")), "남산 방송", "공개도 2: 다음 정시 남산 소식")
	t.eq(int(st.vars.get_v("AFF_SB")), base_sb - 5, "도착하면 그때 반영(−5)")
	t.ok(dd.list.is_empty(), "모두 닿은 기록은 내린다")
	t.eq(str(dd.heard[0]["route"]), "남산 방송", "들은 소식: 경로가 남는다")
	var r2 := dd.record(st, "도움", "R01", 2, {"JC_BC": 0, "SB": -1}, T0 + 3 * 60 + 2, {"what": "둘째"})
	var hold := dd.record(st, "도움", "R07", 2, {"KD": 0}, T0 + 3 * 60 + 1, {"what": "먼저 온 공개도 2"})
	dd.tick(st, T0 + 9 * 60 + 1)                                         # 18:00: 공개도 2 한 건(먼저 온 것)만 방송
	t.ok(bool(hold["news"]) and not bool(r2["news"]), "정시마다 공개도 2는 한 건")
	dd.tick(st, T0 + 15 * 60 + 3)                                        # 12시간 뒤(00:00 정시 전): 소문
	t.ok((r2["known"] as Dictionary).has("JC_BC") and dd.heard[0]["route"] in ["소문", "남산 방송"], "봉천: 소문 12시간")
	var e := dd.record(st, "범죄", "R02", 1, {"JC_ND": -4}, T0 + 4 * 1440, {"place": "ND"})
	t.ok(dd.arrival(e, "JC_ND").is_empty(), "공개도 1(목격)은 소문으로 퍼지지 않는다")
	var f := dd.record(st, "범죄", "R01", 1, {"BJ": -6}, T0 + 4 * 1440, {"place": "BC"})
	t.eq(dd.arrival(f, "BJ"), [T0 + 4 * 1440 + 360, "정보원"], "봉천의 공개도 1 → 비상정부 정보원 6시간")
	dd.tick(st, T0 + 12 * 1440)
	t.ok(not dd.list.has(e), "아무에게도 닿지 않은 기록은 7일 뒤 사라진다")
	var bj0 := int(st.vars.get_v("AFF_BJ"))
	dd.record(st, "범죄", "R01", 1, {"BJ": -8}, T0 + 12 * 1440, {"seen_by": ["BJ"]})
	t.eq(int(st.vars.get_v("AFF_BJ")), bj0 - 8, "직접 목격: 즉시")


func test_deeds_broadcast(t) -> void:
	var st := _state()
	var dd := st.deeds
	dd.tick(st, T0)
	var g := dd.record(st, "처리", "R05", 3, {"YH": 4, "WP": -2}, T0 + 10, {"what": "방송급"})
	dd.tick(st, T0 + 3 * 60)                                            # 09:00 → 12:00 정시
	t.ok(bool(g["news"]) and str(g["news_by"]) == "남산 방송" and int(g["news_at"]) == 12 * 60 + 10 * 1440, "공개도 3: 다음 정시 남산 뉴스")
	t.ok((g["known"] as Dictionary).has("WP") and (g["known"] as Dictionary).has("YH"), "방송으로 모든 세력이 안다(원칙파는 소문이 안 닿는 곳)")
	var a := dd.record(st, "도움", "R02", 2, {"YH": 1}, T0 + 4 * 60, {"what": "첫째"})
	var b := dd.record(st, "도움", "R02", 2, {"YH": 1}, T0 + 4 * 60 + 5, {"what": "둘째"})
	dd.tick(st, T0 + 9 * 60 + 1)                                        # 18:00 정시 한 번
	t.ok(bool(a["news"]) and not bool(b["news"]), "공개도 2는 정시마다 한 건(오래된 순)")
	var c := dd.record(st, "인도", "R01", 2, {"JC": -3}, T0 + 10 * 60, {"about": ["BJ"]})
	dd.tick(st, T0 + 15 * 60 + 1)
	t.eq(str(c.get("news_by", "")), "공보방송", "비상정부가 관련된 공개도 2: 공보방송")
	var js := JSON.stringify(dd.to_dict())
	var d2 := Deeds.new()
	d2.from_dict(JSON.parse_string(js))
	t.eq(JSON.stringify(d2.to_dict()), js, "저장 → 불러오기 → 저장이 같다")


func test_deeds_mq106_walk(t) -> void:
	var st := _state()
	var dd := st.deeds
	var jc0 := int(st.vars.get_v("AFF_JC"))
	st.vars.set_v("GAME_DAY", 14)
	st.vars.set_v("MQ106_RESULT", 4)
	dd.tick(st, T0)
	dd.record(st, "인도", "R01", 2, {"JC": -3, "JC_BC": 0}, T0, {"tag": "MQ106_WALK", "about": ["BJ"], "what": "청계산 벙커에 제 발로 다녀왔다"})
	t.eq(int(st.vars.get_v("AFF_JC")), jc0, "돌아온 순간엔 아직 정착지가 모른다")
	t.ok(not StoryExpr.test("MQ106_RESULT == 4 and GAME_DAY <= BC_DOUBT_DAY", st), "의심 소문 조건 아직 거짓")
	dd.tick(st, T0 + 3 * 60 + 1)                                        # 12:00 공보 '출두 확인' 공고
	t.eq(int(st.vars.get_v("AFF_JC")), jc0 - 3, "정착 −3: 공보 공고가 다음 정시에 퍼뜨린다")
	t.eq(int(st.vars.get_v("BC_DOUBT_DAY")), 15, "봉천 의심: 오늘과 내일")
	t.ok(StoryExpr.test("MQ106_RESULT == 4 and GAME_DAY <= BC_DOUBT_DAY", st), "봉천 사람 소문 조건 참")
	var hits := 0
	for i in 8:
		var line := Rumors.pick(st, "R01", "N-R01-%03d" % (700 + i))
		if line.contains("청계산") or line.contains("출두") or line.contains("벙커"):
			hits += 1
	t.ok(hits >= 4, "봉천 주민 대부분이 수군거린다(%d/8)" % hits)
	st.vars.set_v("GAME_DAY", 16)
	t.ok(not StoryExpr.test("MQ106_RESULT == 4 and GAME_DAY <= BC_DOUBT_DAY", st), "하루 지나면 그친다")
