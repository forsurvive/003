## 단계 0-10 MQ-101·봉천(SD-03a MQ-101, SD-15 §3·§4, SD-09a 봉천): 매매가 공식(PriceOf)·호감도 단계 배수·거래 창 사고팔기
## (캡·상인 캡·취급 분류·퀘스트 물건·입은 옷), 상인 표, 바깥 맵 높이 규칙(계단으로만 오르내림·낭떠러지), 옷 입기·물 마시기.
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	return st


func test_price_formula(t) -> void:
	var one := [1.0, 1.0]
	t.eq(TradeScreen.price_of(25, true, 0, one, one), 39, "물물 0: 스팀팩(25) 사는 값 ×1.55")
	t.eq(TradeScreen.price_of(25, true, 100, one, one), 28, "물물 100: ×1.10")
	t.eq(TradeScreen.price_of(25, true, 100, [0.75, 1.15], [0.9, 1.0]), 25, "할인이 쌓여도 기준가 아래로는 못 산다(구매 하한)")
	t.eq(TradeScreen.price_of(25, false, 0, one, one), 11, "물물 0: 파는 값 ×0.45")
	t.eq(TradeScreen.price_of(25, false, 100, [0.75, 1.15], one), 23, "파는 값은 기준가의 95%를 넘지 못한다(판매 상한)")
	t.eq(TradeScreen.price_of(1, false, 0, one, one), 1, "가치 1 이상이면 최소 1캡")
	t.eq(TradeScreen.price_of(0, false, 50, one, one), -1, "가치 0은 팔 수 없다")
	t.eq(TradeScreen.price_of(1, true, 100, one, one), 1, "가치 1: 사는 값 1(하한) = 파는 값 1(최소) — 5% 차이는 반올림에 묻힌다")
	for v in [5, 25, 225]:
		for b in [0, 30, 60, 100]:
			t.ok(TradeScreen.price_of(v, true, b, one, one) > TradeScreen.price_of(v, false, b, one, one),
				"같은 상인에게는 언제나 사는 값 > 파는 값(가치 %d·물물 %d)" % [v, b])


func test_tier_f(t) -> void:
	t.eq(TradeScreen.tier_f(-60), [], "적대: 거래 불가")
	t.eq(TradeScreen.tier_f(-30), [1.25, 0.75], "경계")
	t.eq(TradeScreen.tier_f(0), [1.0, 1.0], "중립")
	t.eq(TradeScreen.tier_f(20), [0.90, 1.05], "우호")
	t.eq(TradeScreen.tier_f(50), [0.80, 1.10], "신뢰")
	t.eq(TradeScreen.tier_f(80), [0.75, 1.15], "동맹")


func test_merchant_table(t) -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	t.ok(m.has("V01") and m.has("V02"), "봉천 상인 V01 오봉수·V02 하숙자")
	t.eq(str(m["V01"]["settle"]), "BC", "봉천 정착지 호감도로 값을 정한다")
	t.eq([int(m["V01"]["caps_base"][0]), int(m["V01"]["caps_base"][1])], [300, 15], "고물상 = D등급(300 + 15 × 레벨)")
	var ids := []
	for r in m["V01"]["stock"]:
		ids.append(str(r[0]))
	t.ok("A-016" in ids and "W-002" in ids and "I-001" in ids, "V01 진열: 정착민 복장·10mm 권총·스팀팩")


func test_trade_deals(t) -> void:
	var st := _state()
	st.vars.set_v("PC_CAPS", 100)
	st.items["M-010"] = 3
	st.items["W-002"] = 1
	st.items["M-201"] = 1                                                # 퀘스트 물건(첫 배정 통지서)
	st.items["A-001"] = 1
	st.vars.set_v("PC_TORSO", "A-001")
	var host := InteriorHost.new()
	host.st = st
	host.combat = InteriorCombat.new()
	host._load_items()
	t.ok(host.items_db.has("10mm 탄") and int(host.items_db["10mm 탄"]["value"]) == 1, "탄약도 아이템 표에 있다(가치 1)")
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	var shop := {"items": {"I-001": 2}, "caps": 50}
	var one := [1.0, 1.0]
	var tr := TradeScreen.new().setup_trade(st, "V01", m["V01"], shop, host.items_db, 150.0, 0, one, one, "")
	t.ok(not tr.buys("M-201"), "퀘스트 물건은 사지 않는다")
	t.ok(not tr.buys("A-001"), "입고 있는 한 벌은 팔지 않는다")
	t.ok(tr.buys("M-010") and tr.buys("W-002"), "고물상은 다 산다")
	var p := tr.price("I-001", true)
	t.ok(tr.deal("I-001", true), "스팀팩 사기")
	t.eq(int(st.vars.get_v("PC_CAPS")), 100 - p, "캡이 준다")
	t.eq(int(shop["caps"]), 50 + p, "상인 캡이 는다")
	t.eq(int(st.items.get("I-001", 0)), 1, "내 소지품에 들어온다")
	var s := tr.price("W-002", false)
	t.ok(s > int(shop["caps"]), "10mm 권총 파는 값이 상인 캡보다 크다")
	t.ok(not tr.deal("W-002", false), "상인 캡이 모자라면 못 판다")
	var c0 := int(st.vars.get_v("PC_CAPS"))
	t.ok(tr.deal("M-010", false), "고철 팔기")
	t.eq(int(st.vars.get_v("PC_CAPS")), c0 + tr.price("M-010", false), "판 값만큼 캡이 는다")
	st.vars.set_v("PC_CAPS", 0)
	t.ok(not tr.deal("I-001", true), "캡이 모자라면 못 산다")
	t.ok(tr.total > 0, "오간 캡이 쌓인다(MQ101_TRADE 판정)")
	tr.free()
	var tr2 := TradeScreen.new().setup_trade(st, "V02", m["V02"], {"items": {}, "caps": 300}, host.items_db, 150.0, 0, one, one, "")
	t.ok(not tr2.buys("W-002") and not tr2.buys("M-010"), "약국은 무기·고철을 사지 않는다")
	t.ok(tr2.buys("I-001"), "약국은 의약을 산다")
	var w1 := tr2.price("I-057", true)
	tr2.item_k = {"I-057": 2.0}
	t.ok(tr2.price("I-057", true) >= 2 * w1 - 1, "마을을 판 다음 날 물값 2배")
	tr2.free()
	host.combat.free()
	host.free()


func test_shop_state_renew(t) -> void:
	var st := _state()
	var host := InteriorHost.new()
	host.st = st
	host.combat = InteriorCombat.new()
	host._load_items()
	st.vars.set_v("GAME_DAY", 1)
	var sh := host.shop_state("V01")
	t.eq(int(sh["caps"]), 315, "레벨 1 고물상 보유 캡 300 + 15")
	sh["items"].erase("I-001")
	sh["caps"] = 1000
	st.vars.set_v("GAME_DAY", 2)
	t.ok(not host.shop_state("V01")["items"].has("I-001"), "갱신 전(3일)에는 산 물건이 그대로 빠져 있다")
	st.vars.set_v("GAME_DAY", 4)
	var sh2 := host.shop_state("V01")
	t.ok(sh2["items"].has("I-001"), "3일 뒤 06시 갱신: 진열이 다시 찬다")
	t.eq(int(sh2["caps"]), 473, "갱신 캡 = min(기준×1.5, max(기준, 현재×0.5))")
	host.combat.free()
	host.free()


func test_ext_levels(t) -> void:
	var st := _state()
	var m := InteriorMap.new()
	m.load_map("X-S07", st)
	t.ok(m.ext, "관악산 비탈은 바깥 맵")
	t.ok(m.is_stair(Vector2i(13, 17)), "북쪽 턱의 돌계단")
	t.ok(m.level_link(Vector2i(13, 18), Vector2i(13, 17)) and m.level_link(Vector2i(13, 17), Vector2i(13, 16)), "계단으로 오르내린다")
	t.ok(not m.path(Vector2(13 * 32 + 16, 19 * 32 + 16), Vector2(13 * 32 + 16, 14 * 32 + 16)).is_empty(), "길찾기가 계단을 지난다")
	m.free()
	var b := InteriorMap.new()
	b.load_map("X-BC", st)
	t.ok(b.level_at(Vector2i(22, 5)) != b.level_at(Vector2i(22, 6)), "봉천 옥상 끝: 높이가 다른 이웃 칸")
	t.ok(not b.level_link(Vector2i(22, 5), Vector2i(22, 6)), "계단이 아니면 높이가 다른 칸으로 못 넘어간다(낭떠러지)")
	t.ok(b._blocked_from(Vector2i(22, 6), Vector2i(22, 5)), "충돌도 같은 규칙")
	t.ok(b.is_stair(Vector2i(34, 10)), "이장실 쇠계단")
	b.free()


func test_wear_and_drink(t) -> void:
	var st := _state()
	var host := InteriorHost.new()
	host.st = st
	host.combat = InteriorCombat.new()
	host._load_items()
	st.items["A-016"] = 1
	host.wear("A-016")
	t.eq(str(st.vars.get_v("PC_TORSO")), "A-016", "황무지 정착민 복장을 입는다")
	t.eq(int(host.items_db[host.worn()]["dr"]), 3, "입은 옷의 DR")
	st.items["I-054"] = 1
	var r0 := int(st.vars.get_v("PC_RADS"))
	t.ok(host.consume("I-054"), "한강 물 마시기")
	t.ok(int(st.vars.get_v("PC_RADS")) > r0, "방사능이 오른다(즉시)")
	t.eq(int(st.vars.get_v("MQ101_WATER")), 1, "MQ-101 '물'을 해 봤다")
	st.items["I-002"] = 1
	t.ok(host.consume("I-002"), "라드어웨이")
	t.eq(int(st.vars.get_v("PC_RADS")), maxi(0, int(st.vars.get_v("PC_RADS"))), "방사능은 0 아래로 내려가지 않는다")
	host.combat.free()
	host.free()
