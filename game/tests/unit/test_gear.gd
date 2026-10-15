## 장비 상태(단계 1-8a, SD-13 §8 · SD-15 §5.2): 열쇠 표기 · 열화(사용 카운터) · 부품·키트 수리 · 수리 상한 · 정비비 · 상태 굴림 · 가치·DR 배율.
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	return st


func test_gear_keys(t) -> void:
	t.eq([Gear.base("W-002@3"), Gear.cond("W-002@3"), Gear.cond("W-002"), Gear.key_of("W-002", 0), Gear.key_of("W-002", 2)],
		["W-002", 3, 0, "W-002", "W-002@2"], "열쇠: 기본 ID · 상태 번호 · 새것은 @ 없음")
	t.ok(Gear.is_gear_id("W-002") and Gear.is_gear_id("A-004"), "무기·DR 1 이상 방어구는 장비")
	t.ok(not Gear.is_gear_id("I-001"), "스팀팩은 장비가 아니다")
	t.eq([Gear.weapon_stage({"durability": "B"}), Gear.weapon_stage({"durability": "E"}), Gear.weapon_stage({"durability": "S"})], [150, 20, 500],
		"무기 단계당 사용 횟수 B 150 · E 20 · S 500(SD-13 §8.2)")
	t.eq([Gear.armor_stage({"durability": "C"}), Gear.armor_stage({"durability": "A", "slot": "PA"}), Gear.armor_stage({"durability": "A"})], [40, 120, 60],
		"방어구 단계당 피격 C 40 · 파워 아머 A 120 · A 60")
	t.eq([Gear.family("W-002"), Gear.family("W-003"), Gear.family("W-110"), Gear.family("W-099")], ["자동권총", "자동권총", "자동권총", "W-099"],
		"수리 계열: 같은 계열 · 고유는 기반 계열 · 표에 없으면 자기 자신")


func test_gear_wear(t) -> void:
	var st := _st()
	st.items["W-013"] = 1                                                   # 파이프 소총(E): 단계당 20회
	var k := "W-013"
	k = Gear.use(st, k, 19)
	t.eq([k, int(st.wear.get("W-013", 0))], ["W-013", 19], "19회까지는 새것 · 카운터 19")
	k = Gear.use(st, k, 1)
	t.eq(k, "W-013@1", "20회째 = 양호로 바꿔 낀다")
	t.ok(not st.items.has("W-013") and int(st.items.get("W-013@1", 0)) == 1, "소지품 열쇠도 바뀐다")
	k = Gear.use(st, k, 45)
	t.eq(k, "W-013@2", "넘친 횟수는 다음 단계로 이월하되 한 번에 한 단계만")
	for i in 5:
		k = Gear.use(st, k, 20)
	t.eq(k, "W-013@4", "파손에서 멈춘다")
	t.eq(Gear.use(st, k, 50), "W-013@4", "파손은 더 닳지 않는다")


func test_gear_repair(t) -> void:
	var st := _st()
	t.eq([Gear.repair_cap(0), Gear.repair_cap(17), Gear.repair_cap(18), Gear.repair_cap(59), Gear.repair_cap(60)], [2, 2, 1, 1, 0],
		"수리 상한: 0~17 낡음 · 18~59 양호 · 60+ 새것(SD-13 §8.3)")
	st.items["W-002@3"] = 1
	st.items["W-003@4"] = 1                                                   # 같은 계열(자동권총) 파손 = 부품
	st.vars.set_v("PC_SKP_REPAIR", 40)
	var r := Gear.self_repair(st, "W-002@3")
	t.ok(r["ok"] and r["key"] == "W-002@2" and r["used"] == "W-003@4", "부품 수리: 한 단계 오르고 부품은 사라진다 → %s" % str(r))
	r = Gear.self_repair(st, "W-002@2")
	t.ok(not r["ok"], "부품이 없으면 못 고친다: %s" % str(r.get("why", "")))
	st.items[Gear.KIT] = 1
	r = Gear.self_repair(st, "W-002@2", [], true)
	t.ok(r["ok"] and r["key"] == "W-002@1" and r["used"] == Gear.KIT, "장착 중이면 수리 키트로 양호까지")
	st.items[Gear.KIT] = 1
	r = Gear.self_repair(st, "W-002@1", [], true)
	t.ok(not r["ok"], "수리 키트는 양호 위로 못 올린다(스킬 40 상한도 양호)")
	st.items[Gear.MIL_KIT] = 1
	r = Gear.self_repair(st, "W-002@1", [], true)
	t.ok(r["ok"] and r["key"] == "W-002", "군용 정비 키트: 새것까지")
	st.items["W-001@2"] = 2
	t.eq(Gear.part_for(st, "W-001@2"), "W-001@2", "같은 무기 둘이면 다른 하나가 부품")
	t.eq(Gear.part_for(st, "W-001@2", ["W-001@2"]), "", "들고 있는 것은 부품으로 쓰지 않는다")


func test_gear_value_and_cost(t) -> void:
	var db := {"W-002": {"name": "10mm 권총", "cat": "weapon", "durability": "B", "value": 225},
		"A-004": {"name": "경비 아머", "cat": "apparel", "durability": "C", "dr": 12, "value": 70}}
	Gear.expand_items(db)
	t.eq([db["W-002@1"]["name"], int(db["W-002@1"]["value"]), int(db["W-002@2"]["value"]), int(db["W-002@4"]["value"])],
		["10mm 권총 (양호)", 113, 52, Gear.SCRAP_VALUE], "가치 배율 0.5 · 0.23, 파손 = 고철 가치")
	t.eq([int(db["A-004@1"]["dr"]), int(db["A-004@2"]["dr"]), int(db["A-004@3"]["dr"])], [10, 9, 8], "DR 배율 0.86 · 0.76 · 0.67(내림)")
	t.eq(Gear.fix_cost(225, 3, 1, 0, 1.0, 1.0), ceili(225 * (0.5 - 0.05) * 0.75 * 1.55 - 0.0001), "정비비: V × Δ × 0.75 × B × F × 요율")
	t.eq(Gear.fix_cost(10, 2, 1, 100, 1.0, 1.0), 5, "최소 5캡")
	t.eq(Gear.fix_cost(225, 1, 2, 0, 1.0, 1.0), 0, "나쁘게 하는 정비는 없다")


func test_gear_rolls(t) -> void:
	var shop := {}
	var loot := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 400:
		var a := Gear.roll("shop", rng)
		shop[a] = int(shop.get(a, 0)) + 1
		var b := Gear.roll("loot", rng)
		loot[b] = int(loot.get(b, 0)) + 1
	t.ok(not shop.has(2) and not shop.has(3), "상점 진열은 양호 이상(SD-15 §3.8)")
	t.ok(loot.has(0) and loot.has(3), "상자는 새것~위태가 섞인다")
	t.eq(Gear.rolled_key("W-002", "loot", "box:A"), Gear.rolled_key("W-002", "loot", "box:A"), "같은 씨앗 = 같은 상태(불러와도 같다)")
	t.eq(Gear.rolled_key("W-110", "loot", "box:A"), "W-110", "고유 장비는 늘 새것")
	t.eq(Gear.rolled_key("I-001", "loot", "box:A"), "I-001", "장비가 아니면 그대로")
