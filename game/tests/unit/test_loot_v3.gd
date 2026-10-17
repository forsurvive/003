## 파밍 v3(단계 1-L, 계획 `_plans/1-L_loot_stash_plan.md` §2 · §9.1): 장소 결이 표를 바꿔 끼운다 · 빈 상자율(결 · 위협 · 잠김) ·
## 줄 상한 · 캡은 드물다 · 사건 물건 · 시간 층 ② · 보이는 빔은 굴림과 같은 씨앗 · 빈 이유 글(내가 비운 상자엔 없다) · 볼트 시대 · 손 맵은 그대로.
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	return st


func _b(kind: String, pl: String, extra := {}) -> Dictionary:
	var b := {"x": 3, "y": 4, "w": 1, "h": 1, "kind": kind, "owner": "", "lock": 0, "name": "", "cond": "", "pl": pl, "th": 2}
	b.merge(extra, true)
	return b


func test_loot_v3_tables(t) -> void:
	t.eq(Loot.table_of("G-1-1", _b("pharmacy", "pharm")), "pharm_left", "약국 약장 → 털린 약장 표")
	t.eq(Loot.table_of("G-1-1", _b("pantry", "home")), "kitchen", "살림집 식료품 상자 → 쿠폰 없는 서울 찬장")
	t.eq(Loot.table_of("G-1-1", _b("pantry", "tea")), "tea", "다방 찻장 → 찻장 표")
	t.eq(Loot.table_of("G-1-1", _b("desk", "karaoke", {"name": "계산대 서랍"})), "karaoke", "노래방 계산대는 노래방 표")
	t.eq(Loot.table_of("G-1-1", _b("desk", "conv", {"name": "계산대 서랍"})), "till", "다른 가게 계산대는 계산대 표")
	t.eq(Loot.table_of("G-1-1", _b("apartment", "home", {"ev": "할머니 약"})), "granny", "할머니 약 사건 → 약봉지 서랍")
	t.eq(Loot.table_of("G-1-1", _b("desk", "home", {"ev": "할머니 약"})), "desk", "사건 물건은 정한 종류 용기에만")
	for r in (Loot.tables["kitchen"]["rows"] as Array):
		t.ok(str(r[0]) != "M-249", "서울 찬장에는 볼트 간식 쿠폰이 없다")
	var near := Loot.empty_p("G-1-1", _b("apartment", "home", {"th": 1}))
	var far := Loot.empty_p("G-1-1", _b("apartment", "home", {"th": 3}))
	t.ok(near > far, "정착지 둘레(위협 1)가 깊은 곳(위협 3)보다 더 털렸다")
	t.ok(Loot.empty_p("G-1-1", _b("apartment", "home", {"lock": 25})) < Loot.empty_p("G-1-1", _b("apartment", "home")), "잠긴 용기는 덜 털렸다")
	t.ok(Loot.empty_p("G-1-1", _b("pharmacy", "pharm")) > Loot.empty_p("G-1-1", _b("toolbox", "hw")), "약국이 철물점보다 먼저 털렸다")
	t.eq(Loot.empty_p("G-1-1", _b("stash", "conv")), 0.0, "쪽지로 찾은 숨겨 둔 상자는 비지 않는다")


func test_loot_v3_roll(t) -> void:
	var st := _state()
	t.ok(Loot.is_v3(st, "G-5-5", _b("apartment", "home")), "생성 실내 일반 용기는 v3")
	t.ok(Loot.is_v3(st, "W", _b("bag", "road")), "월드 길가 용기도 v3")
	t.ok(not Loot.is_v3(st, "J-02", _b("crate", "")), "손 맵 용기는 옛 굴림 그대로(설계된 보상)")
	t.ok(not Loot.is_v3(st, "G-5-5", _b("apartment", "home", {"owner": "N-X"})), "주인 있는 용기는 v3가 아니다")
	var vst := StoryState.new()
	vst.load_data()
	t.ok(not Loot.is_v3(vst, "G-5-5", _b("apartment", "home")), "볼트 시대는 v3가 아니다(0-9 결과 그대로)")
	var empty := 0
	var lines := 0
	var caps := 0
	var vis_ok := true
	var why_ok := true
	for i in 400:
		var b := _b("apartment", "home", {"x": i % 40, "y": 3 + i / 40})
		var k := Loot.key("G-9-9", b, 2277)
		var pre := Loot.visibly_empty(st, "G-9-9", b)
		var c := Loot.contents(st, "G-9-9", b, "R01")
		var items: Dictionary = c["items"]
		if pre and not items.is_empty():
			vis_ok = false                                               # 보이는 빔이면 열어 봐도 비었다
		if items.is_empty():
			empty += 1
			if str(c.get("why", "")) == "":
				why_ok = false
		lines = maxi(lines, items.size())
		caps += int(items.get("M-001", 0))
		if not st.boxes.has(k):
			why_ok = false
	t.ok(empty > 220 and empty < 360, "살림집 장롱은 대부분 비었다(%d/400)" % empty)
	t.ok(lines <= 2, "한 용기에서 나오는 줄은 둘까지")
	t.ok(caps < 400, "장롱에서 캡은 드물다(400곳 합 %d)" % caps)
	t.ok(vis_ok, "보이는 빔으로 보인 용기는 열어도 비었다(같은 씨앗)")
	t.ok(why_ok, "처음부터 빈 용기에는 빈 이유 글이 있다")
	var bx := _b("toolbox", "hw", {"x": 77, "y": 77})
	var c2 := Loot.contents(st, "G-9-9", bx, "R01")
	c2["items"] = {}
	c2["taken"] = 3
	t.eq(Loot.empty_line(c2), "", "내가 비운 상자에는 '누가 털었다' 글이 없다")
	var b3 := _b("pantry", "home", {"x": 5, "y": 50, "ly": ["l2"], "ev": ""})
	var food := 0
	for i in 200:
		b3["x"] = i
		var r := Loot.roll_v3("G-8-8", b3, "s%d" % i, 1, "", {})
		for id in r["items"]:
			if str(id) in ["I-026", "I-030"]:
				food += 1
	t.eq(food, 0, "시간 층 ②(200년 누가 살았다) 집 찬장에는 통조림 줄이 빠진다")
