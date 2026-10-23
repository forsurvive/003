## 추적대 빈도 시뮬(단계 1-13d, SD-05 §6.4 정본 표 ±10%): 수배 등급마다 1,000게임일 동안 하루 n번 '성공한 인카운터 판정'에
## 추적대(RE-087)를 끼워 넣어 본다. 기대값 = 하루 E[min(이항(n, p), 상한)] — 상한에 닿으면 그날은 더 끼지 않으니까.
## 하루 상한은 절대 넘지 않아야 하고(하드), 판정당 끼워 넣기 비율(상한 전)은 등급 확률 ±10%.
extends RefCounted

const DAYS := 1000
const PER_DAY := 6                                       ## 하루 성공 판정 수(SD-05 §6.2 밀도로 하루 걸어 다니면 4~8번)


func _st(act: int) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", act)
	st.vars.set_v("GAME_DAY", 1)
	return st


## 이항 분포에서 min(X, cap)의 기대값
func _expect(n: int, p: float, cap: int) -> float:
	var s := 0.0
	var c := 1.0                                          # nCk
	for k in range(n + 1):
		if k > 0:
			c = c * float(n - k + 1) / float(k)
		s += float(mini(k, cap)) * c * pow(p, k) * pow(1.0 - p, n - k)
	return s


## 하루하루 PER_DAY번 끼워 넣기 판정 → {"days": 하루 평균, "over": 상한 넘은 날 수, "tries": 상한 전 판정 수, "hits": 끼운 수}
func _sim(st: StoryState, seed_v: int) -> Dictionary:
	var en := Encounters.new(st, seed_v)
	var cap: int = Encounters.TRACKER_DAY_CAP[maxi(Wanted.grade(st), 1)]
	var total := 0
	var over := 0
	var tries := 0
	for d in range(DAYS):
		st.vars.set_v("GAME_DAY", d + 1)
		var n := 0
		for i in range(PER_DAY):
			var p := en._tracker_p()
			if p > 0.0:
				tries += 1
			if en._tracker(p) == "RE-087":
				n += 1
		total += n
		if n > cap:
			over += 1
	return {"days": float(total) / DAYS, "over": over, "tries": tries, "hits": total}


func test_tracker_freq_by_grade(t) -> void:
	# [막, 수배 값] — 1막은 등급 1(하한 값 1), 2막은 하한이 등급 2(30)
	for row in [[1, 1], [2, 35], [2, 65], [2, 85]]:
		var st := _st(int(row[0]))
		Wanted.set_value(st, int(row[1]))
		var g := Wanted.grade(st)
		var p: float = Encounters.TRACKER_P[g]
		var cap: int = Encounters.TRACKER_DAY_CAP[g]
		var r := _sim(st, 1301 + g)
		var want := _expect(PER_DAY, p, cap)
		t.eq(int(r["over"]), 0, "등급 %d: 하루 상한 %d을 넘은 날 없음" % [g, cap])
		t.ok(absf(float(r["days"]) - want) <= want * 0.1,
			"등급 %d: 하루 평균 %.3f ≈ 기대 %.3f(±10%%)" % [g, float(r["days"]), want])
		var rate := float(r["hits"]) / maxf(1.0, float(r["tries"]))
		if OS.get_environment("TEST_VERBOSE") != "":
			print("  추적대 시뮬 등급 %d: 하루 %.3f(기대 %.3f) · 판정당 %.3f(정본 %.2f) · 상한 %d" % [g, float(r["days"]), want, rate, p, cap])
		t.ok(absf(rate - p) <= p * 0.1, "등급 %d: 판정당 끼워 넣기 %.3f ≈ %.2f(±10%%)" % [g, rate, p])


func test_tracker_off_cases(t) -> void:
	var st := _st(2)
	st.vars.set_v("AFF_BJ", 50)                            # 비상정부 신뢰 = 공고 철회(등급 0)
	Wanted.set_value(st, 0)
	t.eq(Wanted.grade(st), 0, "공고 철회면 등급 0")
	t.eq(int(_sim(st, 7)["hits"]), 0, "2막 등급 0 = 1,000일 동안 추적대 0(SD-05 §6.4 0%)")
	var st1 := _st(1)
	Wanted.set_value(st1, 1)
	st1.vars.set_v("HO_LEDGER", 1)
	t.eq(int(_sim(st1, 7)["hits"]), 0, "1막 MQ-105 장부 처리 = 해제")
	var st2 := _st(2)
	Wanted.set_value(st2, 85)
	var en := Encounters.new(st2, 11)
	en.enc()["truce_until"] = 400
	var n := 0
	for d in range(DAYS):
		st2.vars.set_v("GAME_DAY", d + 1)
		for i in range(PER_DAY):
			if en._tracker(en._tracker_p()) == "RE-087" and d + 1 <= 400:
				n += 1
	t.eq(n, 0, "합의금 휴전 기간(truce_until)에는 하루도 안 나온다")


## 빠른 이동 도착은 추적대가 오늘 남았으면 첫 출현 후보(p = 1) — 그래도 하루 상한은 같이 센다
func test_tracker_arrive_cap(t) -> void:
	var st := _st(2)
	Wanted.set_value(st, 85)                                 # 등급 4 · 상한 3
	var en := Encounters.new(st, 5)
	var far := Vector2i(1100, 1500)                         # 정착지 밖
	var got := 0
	for i in range(6):
		if str(en.on_arrive(far, false, "R01").get("re", "")) == "RE-087":
			got += 1
	t.eq(got, 3, "등급 4: 같은 날 빠른 이동 6번 → 추적대 3번(상한)")
	st.vars.set_v("GAME_DAY", 2)
	t.eq(str(en.on_arrive(far, false, "R01").get("re", "")), "RE-087", "다음 날 다시 센다")
