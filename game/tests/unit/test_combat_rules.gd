## SD-11 §4.1 참고표, §4.11 예시 A·C·D
extends RefCounted


func test_spread_skill_terms(t) -> void:
	for row in [[0, 12.0], [25, 9.0], [50, 6.0], [75, 3.0], [100, 1.0]]:      # 100 -> 0° but weapon min 1°
		t.near(CombatRules.spread(row[0]), row[1], 0.001, "스킬 %d 서기" % row[0])
	t.near(CombatRules.spread(0, "crouch_aim"), 4.2, 0.001, "웅크림+정조준")
	t.near(CombatRules.spread(15), 10.2, 0.001, "비태그 초기 15")
	t.near(CombatRules.spread(30, "aim"), 4.2, 0.001, "태그 30 정조준")
	t.near(CombatRules.spread(30, "stand", true), 10.5, 0.001, "이동 1.25")


func test_hit_table(t) -> void:
	# [스킬, 자세, 거리, 기대 명중률] — SD-11 §4.1 명중 기대치 참고표
	var rows := [[0, "stand", 4, 0.58], [0, "stand", 8, 0.32], [0, "aim", 8, 0.59], [0, "crouch_aim", 8, 0.76],
		[0, "aim", 12, 0.42], [15, "stand", 4, 0.66], [15, "aim", 12, 0.48], [30, "stand", 4, 0.76], [30, "stand", 8, 0.44],
		[30, "aim", 8, 0.76], [30, "crouch_aim", 8, 0.93], [30, "aim", 12, 0.56], [50, "stand", 4, 0.92],
		[50, "stand", 8, 0.59], [50, "aim", 12, 0.73], [75, "stand", 8, 0.92], [100, "stand", 8, 1.0]]
	for r in rows:
		var p := CombatRules.hit_probability(CombatRules.spread(r[0], r[1]), r[2])
		t.near(p, r[3], 0.015, "스킬 %d %s %dt" % [r[0], r[1], r[2]])


func test_triangular_distribution(t) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var s := CombatRules.spread(30, "aim")
	var a := rad_to_deg(atan(0.3 / 8.0))
	var hits := 0
	var n := 20000
	for i in n:
		if absf(CombatRules.shot_angle(0.0, s, rng)) < a:
			hits += 1
	t.near(float(hits) / n, CombatRules.hit_probability(s, 8.0), 0.012, "몬테카를로 = 해석해")


func test_example_a(t) -> void:
	var pistol := {"dmg": 9.0, "kind": "ranged", "condition": "good"}
	var dam := CombatRules.base_damage(pistol, 30)
	t.near(dam, 5.09, 0.005, "Dam")
	var r := CombatRules.resolve({"weapon": pistol, "skill": 30, "dr": 16})
	t.near(r["hp"], 4.28, 0.005, "DR 16")
	t.eq(int(ceil(25.0 / r["hp"])), 6, "몸통 처치 타수")
	t.near(CombatRules.hit_probability(CombatRules.spread(30, "aim"), 6.0), 0.88, 0.025, "정조준 6t")


func test_example_c(t) -> void:
	var sniper := {"dmg": 40.0, "kind": "ranged", "condition": "new", "crit_dmg": 40.0}
	var r := CombatRules.resolve({"weapon": sniper, "skill": 100, "sneak": true, "better_crits": true,
		"part": "head", "dr": 54})
	t.near(r["hp"], 184.0, 0.01, "기습 치명 헤드샷 DR 54")
	var r0 := CombatRules.resolve({"weapon": sniper, "skill": 100, "sneak": true, "better_crits": true, "part": "head"})
	t.near(r0["hp"], 400.0, 0.01, "DR 전")


func test_example_d(t) -> void:
	var knife := {"dmg": 7.0, "kind": "melee", "condition": "new", "crit_dmg": 13.0}
	t.near(CombatRules.base_damage(knife, 60, {"str": 5}), 8.6, 0.001, "Dam")
	var r := CombatRules.resolve({"weapon": knife, "skill": 60, "attacker": {"str": 5}, "sneak": true})
	t.near(r["hp"], 108.0, 0.001, "기습 ×5")
	var rb := CombatRules.resolve({"weapon": knife, "skill": 60, "attacker": {"str": 5}, "sneak": true, "boss": true})
	t.near(rb["hp"], 43.2, 0.001, "보스 상한 ×2")


func test_dr_cap_and_explosive(t) -> void:
	var w := {"dmg": 100.0, "kind": "ranged"}
	t.near(CombatRules.resolve({"weapon": w, "skill": 100, "dr": 95})["hp"], 15.0, 0.001, "DR 상한 85")
	t.near(CombatRules.resolve({"weapon": w, "skill": 100, "dr": 60, "explosive": true})["hp"], 70.0, 0.001, "폭발 DR 절반")


func test_crit_and_parts(t) -> void:
	t.near(CombatRules.crit_chance(5, 1.0, "good"), 3.25, 0.001, "행운 5 양호")
	t.near(CombatRules.crit_chance(5, 1.0, "new", 0, true), 20.0, 0.001, "집중 사격 +15")
	t.near(CombatRules.crit_chance(1, 1.0, "poor", 0, false, true), 100.0, 0.001, "기습 확정")
	var w := CombatRules.part_weights(CombatRules.HUMANOID_WEIGHTS, {"focused": true, "per": 5})
	var p_head: float = float(w["head"]) / (w["head"] + w["torso"] + w["arm"] + w["leg"] + w["weapon"])
	t.near(p_head, 0.19, 0.02, "집중 사격 인지력 5 -> 머리 약 20%")
	var low := CombatRules.part_weights(CombatRules.HUMANOID_WEIGHTS, {"target_low": true})
	t.eq(low["leg"], 0, "웅크린 표적 다리 0")
	t.eq(low["torso"], 68, "다리 가중치는 몸통으로")
	t.near(CombatRules.limb_hp(25, "head"), 6.25, 0.001, "부위 체력")
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var counts := {}
	for i in 10000:
		var k := CombatRules.pick_part(CombatRules.HUMANOID_WEIGHTS, rng)
		counts[k] = counts.get(k, 0) + 1
	t.near(counts["torso"] / 10000.0, 0.48, 0.02, "가중치 뽑기 몸통 48%")
