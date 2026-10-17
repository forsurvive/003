## 거래처를 후하게(단계 1-L, 계획 `_plans/1-L_loot_stash_plan.md` §4 · §9.2): 다시 문 연 가게(가게마다 따로 재고 · 캡) · 결 물건 ×1.2 /
## 결 밖 ×0.8 · 요즘 찾는 것 ×1.5 · 장사꾼 죽음은 그 가게 한 사람 · 바꿈 상자(더 가져가면 표시 · 셋이면 '도둑 사절' — 다시 차지 않는다).
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("GAME_DAY", 4)
	return st


func test_traders_data(t) -> void:
	var tr: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/traders.json"))
	var per := {}
	for mid in tr:
		var r := str(tr[mid]["region"])
		per[r] = int(per.get(r, 0)) + 1
	t.ok(int(per.get("R01", 0)) >= 8 and int(per.get("R02", 0)) >= 8, "1막 권역마다 다시 문 연 가게가 여럿(R01 %d · R02 %d)" % [per.get("R01", 0), per.get("R02", 0)])
	var host := InteriorHost.new()
	host.st = _state()
	for k in ["VG_SCRAP", "VG_HERB", "VG_PARTS", "VG_CLOTH", "VG_FOOD", "VG_DRIFT"]:
		t.ok(bool(host.merchant_def(k).get("inst", false)), "%s는 가게마다 따로 쓰는 틀" % k)
	var a := host.shop_state("VG_SCRAP@G-1-1")
	var b := host.shop_state("VG_SCRAP@G-2-2")
	a["caps"] = 3
	t.ok(int(host.shop_state("VG_SCRAP@G-2-2")["caps"]) != 3, "두 고물상의 캡은 따로")
	t.ok(str(a.get("want", "")) in (host.merchant_def("VG_SCRAP")["want"] as Array), "요즘 찾는 것은 그 결의 목록에서")
	t.eq(host.merchant_def("VG_SCRAP@G-9-9")["name"], "고물상", "'틀@맵' 열쇠도 틀을 읽는다")
	var ts := TradeScreen.new()
	ts.mdef = host.merchant_def("VG_SCRAP")
	ts.state = b
	ts.state["want"] = "M-083"
	t.eq(ts.sell_k("M-010"), 1.2, "고물상은 고철을 ×1.2로 산다")
	t.eq(ts.sell_k("I-001"), 0.8, "결 밖 물건은 ×0.8")
	t.eq(ts.sell_k("M-083"), 0.8 * 1.5, "요즘 찾는 것은 ×1.5(결 밖이라도)")
	host.free()


func test_swap_box(t) -> void:
	var st := _state()
	var host := InteriorHost.new()
	host.st = st
	host.items_db = {"I-030": {"value": 4}, "M-083": {"value": 25}, "M-010": {"value": 5}}
	var c := {"items": {"M-083": 1}, "opened": 0, "taken": 0}
	var k0 := int(st.vars.get_v("PC_KARMA")) if st.vars.has("PC_KARMA") else 0
	c["items"] = {}
	host._swap_after(c, 25)
	t.eq(int(c.get("bad", 0)), 1, "라디오(25)를 가져가고 아무것도 안 두면 표시 하나")
	c["items"] = {"I-030": 1, "M-010": 4}
	host._swap_after(c, 0)
	t.eq(int(c.get("bad", 0)), 1, "더 많이 두고 가면 표시가 늘지 않는다")
	c["items"] = {}
	host._swap_after(c, 24)
	host._swap_after(c, 24)
	t.ok(bool(c.get("shut", false)), "표시 셋 — '도둑 사절'")
	var b := {"x": 5, "y": 5, "kind": "swap", "owner": "", "lock": 0, "name": "바꿈 상자"}
	var k := Loot.key("W", b, 2277)
	st.boxes[k] = c
	st.vars.set_v("GAME_DAY", 20)
	Loot.contents(st, "W", b, "R01")
	Loot.contents(st, "W", b, "R01")
	t.ok((st.boxes[k]["items"] as Dictionary).is_empty(), "'도둑 사절' 바꿈 상자는 다시 차지 않는다")
	if st.vars.has("PC_KARMA"):
		t.ok(int(st.vars.get_v("PC_KARMA")) < k0, "더 가져가면 카르마가 준다")
	host.free()
