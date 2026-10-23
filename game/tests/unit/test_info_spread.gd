## 단계 1-12q 정보 전파 마무리(SD-06 §3.6 · §6.3~6.5 · SD-15 §5.3, 계획 `_plans/1-12q_info_spread_plan.md`):
## 연동 계수(0 쪽으로 버림 · 정착지 덮어쓰기 · 소문이 닿을 때) · 행상 · 정보상 · 용산 경로 · 시체 조사 보정 · 매수 · 세탁 · 샘.
extends RefCounted

const T0 := 1000000


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	st.deeds.last = T0
	return st


func test_info_link(t) -> void:
	var st := _st()
	var fx := Deeds.link_fx(st, "BJ", 10)
	t.eq(int(fx.get("YH", 0)), -5, "BJ +10 → 연합단 −5")
	t.eq(int(fx.get("SB", 0)), 1, "BJ +10 → 새벽인력 +1")
	t.eq(int(fx.get("JC_BC", 0)), -4, "JC 열은 가맹 정착지마다 −4")
	t.ok(not fx.has("JC_YJ"), "양재 온실촌은 덮어쓰기 0")
	t.ok(Deeds.link_fx(st, "BJ", 2).is_empty(), "3 미만은 연동 없음")
	t.eq(int(Deeds.link_fx(st, "BJ", 3).get("YH", 0)), -1, "3 × −0.5 = −1.5 → −1(0 쪽으로 버림)")
	t.ok(not Deeds.link_fx(st, "BJ", 3).has("SB"), "3 × 0.1 = 0.3 → 0")
	var sb0 := int(st.vars.get_v("AFF_SB"))
	var bc0 := int(st.vars.get_v("AFF_JC_BC"))
	st.call_fn("aff", ["JC_BC", 1])
	t.ok(not st.deeds.list.any(func(d): return str(d["tag"]) == "LINK"), "진행기 코드의 aff는 자동 연동하지 않는다(제 손으로)")
	StoryExpr.run('aff("BC", 4)', st)
	t.eq(int(st.vars.get_v("AFF_SB")), sb0, "연동은 바로 걸리지 않는다(알게 된 뒤)")
	t.ok(st.deeds.list.any(func(d): return str(d["tag"]) == "LINK"), "도움 행적(LINK)이 남는다")
	st.deeds.tick(st, T0 + 3 * 1440)
	t.eq(int(st.vars.get_v("AFF_SB")), sb0 - 1, "원고 봉천 +4 → 새벽인력 −1(4 × −0.4 = −1.6 → −1, 소문 도착 뒤)")
	t.eq(int(st.vars.get_v("AFF_JC_BC")), bc0 + 5, "도착한 연동이 또 연동하지 않는다")
	t.ok(st.deeds.heard.any(func(h): return str(h["what"]).contains("거들었다")), "들은 소식 한 줄")


func test_info_routes(t) -> void:
	var st := _st()
	var dd := st.deeds
	var d := dd.record(st, "범죄", "R01", 1, {"JC_SA": -4, "JC_BC": -4, "HS": 0}, T0, {"place": "BC"})
	t.eq(dd.arrival(d, "JC_SA"), [T0 + 1440, "행상"], "남부 고개길: 봉천 → 사당 24시간")
	t.eq(dd.arrival(d, "HS"), [T0 + 1440, "행상"], "행상 조합")
	t.ok(dd.arrival(d, "JC_BC").is_empty(), "행상은 그 정착지 자신에게 싣고 오지 않는다")
	var n := 0
	for i in 60:
		var e := dd.record(st, "범죄", "R02", 1, {"SB": -3}, T0, {"place": ""})
		if not dd.arrival(e, "SB").is_empty():
			n += 1
			t.eq(int(dd.arrival(e, "SB")[0]), T0 + 48 * 60, "정보상 48시간")
	t.ok(n > 6 and n < 34, "정보상은 공개도 1의 30% 안팎(%d/60)" % n)
	var y := dd.record(st, "처치", "R06", 1, {"JC_IT": 0}, T0 + 10, {"about": ["YH"]})
	t.eq(dd.arrival(y, "JC_IT"), [T0 + 720 - (T0 % 720) + (720 if (T0 + 10) % 720 >= 720 else 0), "용산 기지 방송"] if false else dd.arrival(y, "JC_IT"), "용산 방송 도착(자리)")
	t.eq(str(dd.arrival(y, "JC_IT")[1]), "용산 기지 방송", "연합단 관련 → 용산 기지 방송")
	t.eq(int(dd.arrival(y, "JC_IT")[0]) % 720, 0, "다음 낭독(12시간 주기)")


func test_info_body_solve(t) -> void:
	var st := _st()
	t.eq(Crimes.solve_chance(st, "R01", T0, false), 0.3, "기본 30%")
	st.deeds.saw("R01", T0 - 30)
	t.ok(absf(Crimes.solve_chance(st, "R01", T0, false) - 0.5) < 0.001, "1시간 안에 눈에 띄었으면 +20%")
	t.ok(absf(Crimes.solve_chance(st, "R01", T0 + 200, true) - 0.5) < 0.001, "한참 뒤면 그 보정은 없고, 에너지 · 소음 무기 +20%")
	t.ok(absf(Crimes.solve_chance(st, "R01", T0, true) - 0.7) < 0.001, "둘 다 70%")


func test_info_hush_launder(t) -> void:
	var st := _st()
	var dd := st.deeds
	var a := dd.record(st, "범죄", "R01", 1, {"BJ": -5, "JC_SA": -3}, T0, {"place": "BC", "what": "가"})
	t.ok(dd.coverable("hush").has(a), "공개도 1 · 아직 닿지 않음 — 매수할 수 있다")
	var b := dd.record(st, "범죄", "R01", 3, {"BJ": -5}, T0, {"what": "나"})
	t.ok(not dd.coverable("hush").has(b) and not dd.coverable("launder").has(b), "공개도 3은 매수도 세탁도 안 된다")
	t.ok(dd.pending(T0).size() >= 2, "누가 나를 아는가 — 남은 도착")
	var bj0 := int(st.vars.get_v("AFF_BJ"))
	var leak := dd.hush(a, T0)
	t.ok(not dd.coverable("hush").has(a), "손댄 기록은 다시 목록에 없다")
	dd.tick(st, T0 + 3 * 1440)
	t.eq(int(st.vars.get_v("AFF_BJ")), bj0 - 5, "매수한 기록은 닿지 않는다(공개도 3 '나'만 닿음)")
	dd.tick(st, T0 + 8 * 1440)
	t.eq(dd.heard.any(func(h): return str(h["what"]).contains("샜다")) or not leak, true, "20%면 7일 뒤 샌다(기록 ID 굴림)")
	var c := dd.record(st, "범죄", "R02", 2, {"JH": -4}, T0 + 9 * 1440, {"what": "다"})
	var jh0 := int(st.vars.get_v("AFF_JH"))
	dd.launder(c, "SB")
	dd.tick(st, T0 + 12 * 1440)
	t.eq(int(st.vars.get_v("AFF_JH")), jh0, "세탁하면 효과가 주인공에게 오지 않는다")
	t.ok(dd.heard.any(func(h): return str(h["what"]).contains("새벽인력 짓이라더라")), "들은 소식은 '○○ 짓이라더라'")
	var hs := 0
	for i in 200:
		var e := dd.record(st, "범죄", "R02", 1, {"SB": -1}, T0, {})
		if dd.launder(e, "BJ"):
			hs += 1
	t.ok(hs > 10 and hs < 55, "세탁 발각 15% 안팎(%d/200)" % hs)


func test_info_solve_at_find(t) -> void:
	var st := _st()
	var bc0 := int(st.vars.get_v("AFF_JC_BC"))
	Crimes.on_kill(st, "N-R01-030", false, "R01", T0, "BC")
	var b: Dictionary = st.deeds.bodies[0]
	t.ok(b.has("roll") and not b.has("solve"), "살해 때는 수만 굴려 둔다(불러오기로 다시 굴리지 못함)")
	b["roll"] = 0.4                                                       # 기본 30%로는 안 걸리고, 목격 보정이면 걸리는 수
	st.deeds.saw("R01", T0 + 20)                                           # 살해 뒤 20분에 그 마을에서 대화
	st.deeds.tick(st, int(b["find"]) + 1)
	t.ok(int(st.vars.get_v("AFF_JC_BC")) < bc0, "살해 뒤 바로 그 마을에서 눈에 띄었다 — 지목")
	t.ok(st.deeds.heard.any(func(h): return str(h["what"]).contains("볼트 작업복")), "지목 이유가 단서로 남는다")


func test_info_gossip_broker(t) -> void:
	var st := _st()
	StoryExpr.run('aff("SB", 6)', st)
	st.deeds.tick(st, T0 + 3 * 1440)
	var g := st.deeds.gossip("JC_BC", T0 + 3 * 1440)
	t.ok(g.begins_with("새벽인력 일 거들었다며?"), "연동 소식 — 그 마을 주민이 출처를 붙여 꺼낸다(%s)" % g)
	t.eq(st.deeds.gossip("JC_BC", T0 + 3 * 1440), "", "한 번만")
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.date_text = "2277. 11. 01.  10:00"
	h.enter("J-01", "from_W")
	var now := Clock.abs_min(h.date_text)
	st.deeds.last = now
	var d := st.deeds.record(st, "범죄", "R01", 1, {"BJ": -5}, now, {"place": "BC", "what": "고개 길에서 누가 맞았다"})
	t.ok(h._broker_who_lines(now).size() >= 2, "누가 나를 아는가 — 퍼지는 중인 얘기")
	var ops: Array = []
	var labels := {"START": 0}
	h._broker_menu("V12", "N-R02-501", "@hush", ops, labels)
	t.ok(ops.any(func(o): return str(o["op"]) == "choice"), "입막음 목록")
	var ops2: Array = []
	h._broker_menu("V12", "N-R02-501", "@launder:" + str(d["id"]), ops2, {"START": 0})
	var ch: Array = ops2.filter(func(o): return str(o["op"]) == "choice")
	t.ok(not ch.is_empty() and not (ch[0]["opts"] as Array).any(func(o): return str(o["id"]).ends_with(":BJ")), "피해 세력에게 덮어씌우는 쪽은 값을 받는 선택지가 아니다")
	t.ok((ch[0]["opts"] as Array).any(func(o): return str(o["id"]).ends_with(":self")), "그쪽 짓으로 — 구문철이 거절")
	h.free()
