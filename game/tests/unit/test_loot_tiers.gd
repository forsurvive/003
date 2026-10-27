## 파밍 v2 등급(단계 1-4e, SD-13 §9.2·§9.3): 권역 기본 등급 + 레벨 7·13·19·25마다 한 단계, 권역 상한에서 멈춤 ·
## 줄의 처음 나오는 등급 · '@묶음'은 지금 등급 이하에서만 · 적 소지품 표는 결정적.
extends RefCounted


func test_loot_tiers(t) -> void:
	t.eq([Loot.tier("R01", 1), Loot.tier("R01", 7), Loot.tier("R01", 30)], [1, 2, 2], "관악 R01: T1에서 시작, 레벨 7에 T2, 상한 T2")
	t.eq([Loot.tier("R02", 1), Loot.tier("R02", 13), Loot.tier("R02", 25)], [1, 3, 3], "영등포 R02: 레벨 13에 T3, 상한 T3")
	t.eq(Loot.tier("R05", 1), 4, "도심 R05는 T4에서 시작")
	t.eq(Loot.tier("??", 1), 1, "모르는 권역은 T1")
	t.eq(Loot.level_of(0), 1, "XP 0 = 레벨 1")
	t.eq(Loot.level_of(200), 2, "XP 200 = 레벨 2(SD-10 §4.2 (L−1)(50+75L))")
	var rows := [["M-001", 1.0, 1, 1, 3]]
	t.ok(Loot.roll_rows(rows, "k", 2).is_empty(), "처음 나오는 등급 T3 줄은 T2에서 안 나온다")
	t.eq(int(Loot.roll_rows(rows, "k", 3).get("M-001", 0)), 1, "T3이면 나온다")
	var rng := RandomNumberGenerator.new()
	var low := {}
	for i in 200:
		rng.seed = i
		low[Loot.pick("ammo", 1, rng)] = true
	t.ok(not low.has("마이크로퓨전 전지") and not low.has("미사일"), "T1 탄 묶음에는 T3·T4 탄이 없다")
	var hi := {}
	for i in 400:
		rng.seed = i
		hi[Loot.pick("ammo", 4, rng)] = true
	t.ok(hi.has("미사일") and hi.has("10mm 탄"), "T4는 아래 등급 탄도 함께 나온다")
	t.eq(Loot.drop("CR-436", "W:10,10@2277", 1), Loot.drop("CR-436", "W:10,10@2277", 1), "적 소지품은 같은 씨앗이면 같다")
	var any := false
	for i in 20:
		if not Loot.drop("CR-436", "W:%d,1@2277" % i, 1).is_empty():
			any = true
	t.ok(any, "추심원(CR-436)은 소지품을 남긴다(§9.3)")
	var lv_ok := false
	for i in 40:                                                         # SD-15 §9.2 적 소지 캡 × (1 + 0.03 × 레벨) — 같은 씨앗이면 물건은 같고 캡만 는다
		var a := Loot.drop("CR-436", "W:%d,2@2277" % i, 1)
		if int(a.get("M-001", 0)) >= 10:
			var b := Loot.drop("CR-436", "W:%d,2@2277" % i, 1, "enemy", 10)
			t.eq(int(b["M-001"]), roundi(float(a["M-001"]) * 1.3), "Lv10 = 소지 캡 ×1.3")
			b.erase("M-001")
			a.erase("M-001")
			t.eq(b, a, "레벨 계수는 캡만 바꾼다")
			lv_ok = true
			break
	t.ok(lv_ok, "캡 10 넘게 든 추심원 표본이 있다")
	for k in ["civil", "bag", "car", "trash", "corpse_scav", "crate"]:
		var n := 0
		for i in 30:
			n += Loot.roll(k, "%s:%d@2277" % [k, i], 1).size()
		t.ok(n > 0, "길가 용기 '%s'에서 무언가 나온다" % k)
