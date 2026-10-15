## 제작·조리(단계 1-8c, SD-13 §7.9): 레시피 자료 · 설계도 목록 · 품질(사본 수 × 수리 상한) · 폭발물 개수 · 재료·캡 소모 ·
## 퍽 잠금 · 불 · 맑은 물부터 · 물 변형 라드 · 작업대 서랍 지뢰 · 느린 재입고 자료.
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("PC_CAPS", 50)
	return st


func test_craft_data(t) -> void:
	Craft.load_data()
	t.eq(Craft.recipes.size(), 19, "레시피 11 + 조리 8(SD-13 §7.9.3 · §7.9.5)")
	t.eq(str(Craft.recipes["W-153"]["blueprint"]), "M-102", "압력 대못총 ← 설계도 M-102")
	t.eq(int(Craft.recipes["W-151"]["caps"]), 10, "병뚜껑 지뢰: 캡 10")
	t.eq(int(Craft.recipes["건설용 대못"]["count"]), 20, "대못 ×20")
	t.eq(str(Craft.recipes["I-082"]["perk"]), "PK-009", "상추 김치: 손맛")
	var w: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons_craft.json"))
	t.eq(int(w["W-153"]["dmg"]), 30, "W-153 피해 30")
	t.eq(str(w["W-153"]["ammo_id"]), "건설용 대못", "W-153 탄 = 건설용 대못")
	t.ok(bool(w["W-157"].get("ignore_dr", false)), "갈퀴 장갑: DR 무시")
	t.ok(not w.has("W-151"), "폭발물은 무기 표가 아니라 잡화(던지기 단계 전)")


func test_craft_listing_and_quality(t) -> void:
	var st := _state()
	var l := Craft.listing(st, false)
	t.ok(l.has("I-067") and l.has("건설용 대못") and not l.has("W-153"), "설계도 없으면 설계도 레시피는 안 보인다")
	st.items["M-102"] = 1
	t.ok(Craft.listing(st, false).has("W-153"), "설계도 1장이면 보인다")
	st.vars.set_v("PC_SKP_REPAIR", 0)
	var cap := Gear.repair_cap(st.skill("REPAIR"))
	t.eq(Craft.quality(st, "W-153"), mini(cap + 1, 3), "1장: 수리 상한보다 한 단계 낮게")
	st.items["M-102"] = 2
	t.eq(Craft.quality(st, "W-153"), cap, "2장: 수리 상한")
	st.items["M-102"] = 3
	t.eq(Craft.quality(st, "W-153"), maxi(cap - 1, 0), "3장: 한 단계 높게")
	st.items["M-100"] = 1
	t.eq(Craft.per_set(st, "W-151"), 1, "지뢰 설계도 1장: 세트당 1개")
	st.items["M-100"] = 5
	t.eq(Craft.per_set(st, "W-151"), 3, "4장째부터 효과 없음: 3개")


func test_craft_make_consumes(t) -> void:
	var st := _state()
	st.items["M-100"] = 2
	for id in ["M-045", "M-044", "M-017"]:
		st.items[id] = 1
	t.eq(Craft.max_sets(st, "W-151"), 1, "재료 1세트 · 캡 50 → 1번")
	var r := Craft.make(st, "W-151", 1)
	t.ok(bool(r["ok"]), "만들었다")
	t.eq(int(st.items.get("W-151", 0)), 2, "설계도 2장 → 2개")
	t.eq(int(st.vars.get_v("PC_CAPS")), 40, "캡 10 녹임")
	t.ok(not st.items.has("M-045") and int(st.items.get("M-100", 0)) == 2, "재료는 빠지고 설계도는 남는다")
	t.ok(not bool(Craft.make(st, "W-151", 1)["ok"]), "재료가 없으면 못 만든다(반쯤 된 상태 없음)")
	t.eq(int(st.vars.get_v("PC_CAPS")), 40, "실패하면 캡도 그대로")
	st.items["M-010"] = 3
	Craft.make(st, "건설용 대못", 2)
	t.eq(int(st.items.get("건설용 대못", 0)), 40, "고철 2 → 대못 40")
	t.eq(int(st.items.get("M-010", 0)), 1, "고철 1 남음")


func test_craft_perk_and_heat(t) -> void:
	var st := _state()
	st.items["M-010"] = 2
	st.items["M-029"] = 1
	st.items["M-087"] = 1
	t.eq(Craft.max_sets(st, "M-074"), 0, "휴대 정수 키트: PK-111 없으면 0")
	t.ok(str(Craft.make(st, "M-074")["why"]).contains("퍽"), "퍽 필요 사유")
	st.items["I-023"] = 1
	st.items["I-057"] = 1
	t.eq(Craft.max_sets(st, "I-077", false), 0, "불 없이(작업대·화덕·버너 없음) 조리 0")
	t.eq(Craft.max_sets(st, "I-077", true), 1, "작업대·화덕 앞이면 1")
	st.items["M-047"] = 1
	t.eq(Craft.max_sets(st, "I-077", false), 1, "휴대용 버너가 있으면 어디서나")
	Craft.make(st, "I-077", 1, false)
	t.eq(int(st.items.get("M-047", 0)), 1, "버너는 소모되지 않는다")


func test_craft_water_variants(t) -> void:
	var st := _state()
	st.items["I-023"] = 3
	st.items["I-054"] = 1
	st.items["I-055"] = 1
	st.items["I-058"] = 1
	t.eq(Craft.out_key(st, "I-077"), "I-077", "생수(라드 0)가 있으면 기본")
	Craft.make(st, "I-077", 3)
	t.eq(int(st.items.get("I-077", 0)), 1, "1번째: 생수")
	t.eq(int(st.items.get("I-077+I-055", 0)), 1, "2번째: 빗물(라드 4) 변형")
	t.eq(int(st.items.get("I-077+I-054", 0)), 1, "3번째: 한강 물(라드 8) 변형")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items_craft.json"))
	t.eq(int(d["I-077"]["rads"]), 2, "끓인 컵라면 = 컵라면 2 + 물 0")
	t.eq(int(d["I-077+I-054"]["rads"]), 10, "한강 물 = 2 + 8")
	t.eq(int(d["I-084"]["rads"]), -8, "말린 버섯 나물은 라드를 줄인다")


func test_craft_bench_drawer_mine(t) -> void:
	var st := _state()
	st.vars.set_v("V_ACT", 1)
	var b := {"x": 3, "y": 9, "w": 2, "h": 1, "kind": "toolbox", "owner": "", "lock": 0, "name": "작업대", "cond": ""}
	if st.year() >= 2277:
		var c := Loot.contents(st, "G-0001", b, "R01")
		t.eq(int(c["items"].get("W-151", 0)), 1, "시설 작업대 서랍: 완성 병뚜껑 지뢰 1개")
		c["items"].erase("W-151")
		t.eq(int(Loot.contents(st, "G-0001", b, "R01")["items"].get("W-151", 0)), 0, "가져가면 다시 생기지 않는다")
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	var v01: Array = m["V01"]["stock"].filter(func(r): return str(r[0]) == "M-100")
	t.ok(v01.size() == 1 and int(v01[0][1]) == 1 and int(v01[0][2]) == 30, "봉천 고물상: 설계도 M-100 1장 · 30일 재입고")


func test_craft_blueprint_restock(t) -> void:
	var st := _state()
	st.vars.set_v("GAME_DAY", 1)
	var host := InteriorHost.new()
	host.st = st
	var sh := host.shop_state("V01")
	t.eq(int(sh["items"].get("M-100", 0)), 1, "첫날 설계도 1장 진열")
	sh["items"]["M-100"] = 0                                             # 샀다
	st.vars.set_v("GAME_DAY", 4)
	t.eq(int(host.shop_state("V01")["items"].get("M-100", 0)), 0, "사흘 갱신에도 설계도는 다시 안 놓는다")
	st.vars.set_v("GAME_DAY", 31)
	t.eq(int(host.shop_state("V01")["items"].get("M-100", 0)), 1, "30일 지나면 1장 다시")
	host.free()
