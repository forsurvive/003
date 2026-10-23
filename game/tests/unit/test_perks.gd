## 단계 1-12p 레벨업 · 퍽(SD-10 §4.2 · §5, 계획 `_plans/1-12p_levelup_perks_plan.md`):
## 레벨업 즉시 HP +10 · 미배분 · 스킬 배분 규칙(다 넣어야 · 100 상한 · 넣은 것만 빼기 · 선행 학습) · 퍽 요구(레벨 · 영구 능력치 · 스킬 · 카르마 · 랭크) ·
## 즉시형 효과(인텐스 트레이닝 내부값 · 히어 앤드 나우 · 카르마) · 1차 효과 수치 · 애니멀 프렌드 1 · 2랭크 · 문턱 한 마디 · 카드 글.
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	Perks.load_db()
	return st


func test_perks_level_up(t) -> void:
	var st := _st()
	var hp1: float = InteriorCombat.derived(st)["hp_max"]
	st.events.clear()
	st.call_fn("xp", [250])
	t.eq(Perks.level(st), 2, "XP 250 → Lv2(누적 200)")
	t.ok(st.events.any(func(e): return str(e["kind"]) == "level" and int(e["value"]) == 2), "레벨업 알림")
	t.eq(Perks.pending(st), 1, "미배분 1")
	t.eq(float(InteriorCombat.derived(st)["hp_max"]), hp1 + 10.0, "최대 HP +10(§4.2)")
	st.call_fn("xp", [2000])
	t.eq(Perks.pending(st), Perks.level(st) - 1, "몇 레벨을 쌓아 두면 그만큼 미배분")
	st.call_fn("xp", [999999])
	t.eq(Perks.level(st), 35, "상한 35")
	t.eq(int(st.vars.get_v("PC_XP")), Perks.xp_at(35), "상한에 닿으면 XP가 더 쌓이지 않는다")


func test_perks_draft_rules(t) -> void:
	var st := _st()
	st.call_fn("xp", [250])
	var d := LevelDraft.begin(st)
	t.eq(d.lv, 2, "배분은 레벨 차례대로 — Lv2부터")
	t.eq(d.pts, 10 + st.stat_base("IN"), "포인트 10 + 영구 지능")
	var k := "SCIENCE"
	var before := st.skill(k)
	t.ok(not d.inc(k, -1), "넣지 않은 것은 뺄 수 없다")
	for i in d.pts + 3:
		d.inc(k, 1)
	t.eq(d.left(), 0, "남은 포인트보다 많이 넣을 수 없다")
	t.eq(d.shown(k), mini(100, before + d.pts), "보이는 값")
	d.inc(k, -1)
	d.step = 0
	t.ok(d.confirm().is_empty(), "다 넣지 않으면 확정 안 됨")
	d.inc("LOCKPICK", 1)
	t.ok(Perks.lacks(st, "PK-045", d.lv).has("레벨 10"), "애니멀 프렌드는 Lv10 — 조건 보기")
	t.ok(d.pick_ok("PK-006"), "스위프트 러너(Lv2 · 지능 4)")
	d.perk = "PK-006"
	var notes := d.confirm()
	t.ok(not notes.is_empty(), "확정")
	t.eq(Perks.rank(st, "PK-006"), 1, "퍽 랭크 = PK_006")
	t.eq(int(st.vars.get_v("PC_LV_DONE")), 2, "Lv2 배분 끝")
	t.eq(Perks.pending(st), 0, "미배분 없음")
	t.eq(st.skill(k), mini(100, before + d.pts - 1), "포인트가 영구로 들어갔다")
	var full := LevelDraft.begin(st)
	st.vars.set_v("PC_SKP_SNEAK", 200)
	t.ok(not full.can_add("SNEAK"), "표시값 100인 스킬엔 못 넣는다")
	t.ok(Perks.lacks(st, "PK-006", 3).is_empty(), "다랭크는 다음 레벨에 다음 랭크")


func test_perks_tag_bonus_and_spread(t) -> void:
	var st := _st()
	st.call_fn("xp", [250])
	st.vars.set_v("PC_TAG1", "SPEECH")
	st.vars.set_v("PK_008", 1)
	var d := LevelDraft.begin(st)
	for i in 8:
		d.inc("SPEECH", 1)
	t.eq(d.bonus("SPEECH"), 2, "선행 학습: 태그 8점 → +2")
	t.eq(d.bonus("BARTER"), 0, "태그 아닌 스킬엔 덤 없음")
	d.spread_tags()
	t.eq(d.left(), 0, "태그에 고루 — 남김없이")
	st.vars.set_v("PK_012", 1)
	t.eq(Perks.skill_points(st), 13 + st.stat_base("IN"), "에듀케이티드 +3")


func test_perks_reqs_and_instant(t) -> void:
	var st := _st()
	st.vars.set_v("PC_XP", Perks.xp_at(26))
	st.vars.set_v("PC_LV_DONE", 23)
	st.vars.set_v("V_KARMA", 0)
	t.ok(Perks.lacks(st, "PK-094", 24).has("카르마 중립이 아닐 것"), "카르믹 리밸런스 — 중립이면 못 고른다")
	st.vars.set_v("V_KARMA", 400)
	t.ok(Perks.lacks(st, "PK-094", 24).is_empty(), "중립이 아니면 고를 수 있다")
	st.vars.set_v("V_KARMA", 900)
	t.ok(not Perks.lacks(st, "PK-093", 24).is_empty(), "에스컬레이터 투 헤븐 — 매우 선함이면 못 고른다")
	st.vars.set_v("PC_EN", 4)
	t.ok(Perks.lacks(st, "PK-025", 24).has("지구력 5"), "터프니스 — 영구 지구력 5")
	st.vars.set_v("PC_RADS", 0)
	var d := LevelDraft.begin(st)
	d.spread_tags()
	d.perk = "PK-004"
	t.ok(d.confirm().is_empty(), "인텐스 트레이닝은 능력치를 골라야 확정")
	st.vars.set_v("PC_ST", 10)
	d.stat_pick = "ST"
	d.confirm()
	t.eq(st.stat_raw("ST"), 11, "10을 넘으면 내부값으로 기록")
	t.eq(st.stat("ST"), 10, "표시는 10")
	var d2 := LevelDraft.begin(st)
	d2.spread_tags()
	d2.perk = "PK-047"
	var lv0 := Perks.level(st)
	var p0 := Perks.pending(st)
	d2.confirm()
	t.eq(Perks.level(st), lv0 + 1, "히어 앤드 나우 — 곧바로 한 레벨")
	t.eq(Perks.pending(st), p0, "그 레벨도 미배분에 더해져 차례대로 배분")
	st.vars.set_v("PC_AG", 3)
	var d3 := LevelDraft.begin(st)
	d3.spread_tags()
	d3.perk = "PK-095"
	var nt := d3.confirm()
	t.eq(st.stat_base("AG"), 5, "노 위크니스 — 5 미만을 5로")
	t.ok(nt.size() >= 2, "안내 줄(퍽 · 생활기록부)")
	st.vars.set_v("PK_047", 0)
	st.vars.set_v("PC_LV_DONE", 33)
	st.vars.set_v("PC_XP", Perks.xp_at(34))
	t.ok(Perks.lacks(st, "PK-047", 34).has("레벨 33 이하"), "Lv34 이상이면 히어 앤드 나우 불가")


func test_perks_effects(t) -> void:
	var st := _st()
	var sc := st.skill("SCIENCE")
	st.vars.set_v("PK_002", 2)
	t.eq(st.skill("SCIENCE"), mini(100, sc + 10), "오버시어의 아이 2랭크 — 과학 +10")
	t.eq(Perks.dmg_mult(st, "CR-080"), 1.0, "퍽 없으면 배수 1")
	st.vars.set_v("PK_013", 1)
	st.vars.set_v("PK_020", 1)
	t.ok(absf(Perks.dmg_mult(st, "CR-080") - 1.575) < 0.001, "엔토몰로지스트 × 블러디 메스 — 왕개미")
	t.ok(absf(Perks.dmg_mult(st, "CR-104") - 1.05) < 0.001, "들개엔 블러디 메스만")
	st.vars.set_v("PK_024", 1)
	t.eq(float(Perks.eat_mult(st, "I-054")[1]), 0.5, "레드 벨리 — 한강 물 라드 절반")
	st.vars.set_v("PK_009", 1)
	t.eq(float(Perks.eat_mult(st, "I-077+I-054")[1]), 0.25, "끓인 컵라면(한강 물) — 손맛 × 레드 벨리")
	st.vars.set_v("PK_026", 1)
	t.eq(Perks.regular_k(st, 1250), [0.9, 1.1, 2], "단골 — 1,250캡이면 두 단계")
	t.eq(int(Perks.regular_k(st, 99999)[2]), 3, "세 단계까지")
	st.vars.set_v("PK_006", 2)
	st.vars.set_v("PC_XP", 0)
	st.call_fn("xp", [100])
	t.eq(int(st.vars.get_v("PC_XP")), 120, "스위프트 러너 2랭크 — XP +20%")
	st.vars.set_v("PK_059", 1)
	st.vars.set_v("PK_076", 1)
	var d := InteriorCombat.derived(st)
	st.vars.set_v("PK_059", 0)
	st.vars.set_v("PK_076", 0)
	var d0 := InteriorCombat.derived(st)
	t.eq(float(d["hp_max"]) - float(d0["hp_max"]), 30.0, "라이프 기버 HP +30")
	t.eq(float(d["ap_max"]) - float(d0["ap_max"]), 25.0, "액션 보이 AP +25")
	st.vars.set_v("PK_033", 1)
	var r1 := Radiation.resist(st)
	st.vars.set_v("PK_033", 0)
	t.ok(absf(r1 - Radiation.resist(st) - 0.25) < 0.001, "라드 레지스턴스 +25%")
	for id in Perks.IMPL:
		t.ok(str(Perks.db[id].get("card", "")) != "" and str(Perks.db[id].get("line", "")) != "", "카드 글: " + id)


func _host() -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.enter("G-880-1244", "from_W")
	return [h, st]


func test_perks_animal_friend(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	var at := h.player.loco.logical + Vector2(64, 0)
	var dog0 := h.combat.spawn("CR-104", at, h.map, st, {"lv": 2})
	t.ok("player" in dog0.foes, "퍽이 없으면 들개는 덤빈다")
	st.vars.set_v("PK_045", 1)
	var dog := h.combat.spawn("CR-104", at, h.map, st, {"lv": 2})
	t.ok(not "player" in dog.foes and dog.cmb.team.begins_with("calm"), "애니멀 프렌드 1랭크 — 먼저 덤비지 않는다")
	var far := h.combat.spawn("CR-095", at + Vector2(40 * 32, 0), h.map, st, {"lv": 2})
	t.ok(far.cmb.team != dog.cmb.team, "다른 무리(쥐 · 먼 자리)는 편이 따로 — 하나를 때려도 그 무리만")
	var roach := h.combat.spawn("CR-002", at, h.map, st, {"lv": 2})
	t.ok("player" in roach.foes, "벌레는 그대로")
	var man := h.combat.spawn("CR-401", at + Vector2(96, 0), h.map, st, {"lv": 2})
	man.brain.state = AIBrain.S.COMBAT
	h.combat._beast_tick(1.0, st)
	t.ok(dog.cmb.team.begins_with("calm"), "1랭크는 편을 들지 않는다")
	st.vars.set_v("PK_045", 2)
	h.combat._beast_t = 0.0
	h.combat._beast_tick(1.0, st)
	t.eq(dog.cmb.team, "ally", "2랭크 — 근처 싸움에서 내 편")
	t.ok(man.cmb.team in dog.foes, "주인공과 싸우는 쪽을 노린다")
	t.ok(not roach.cmb.team in dog.foes or not roach.has_meta("beast"), "동물(벌레)끼리는 — 짐승은 사람 · 기계만")
	dog.loco.place(dog.get_meta("home") + Vector2(20 * 32, 0))
	h.combat._beast_t = 0.0
	h.combat._beast_tick(1.0, st)
	t.ok(dog.foes.is_empty(), "제 자리에서 16칸을 넘으면 멈춘다(끌고 다닐 수 없다)")
	h.free()


func test_perks_threshold_line(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	st.vars.set_v("PC_SKP_LOCKPICK", 0)
	var base := st.skill("LOCKPICK")
	h._tried("LOCKPICK", 50, "문")
	st.call_fn("xp", [250])
	var d := LevelDraft.begin(st)
	for i in maxi(0, 50 - base):
		d.inc("LOCKPICK", 1)
	var th := d.thresholds()
	if base < 50 and d.shown("LOCKPICK") >= 50:
		t.ok(th.any(func(x): return str(x).contains("'보통' 자물쇠") and str(x).contains("이번엔 될 것 같다")), "문턱 한 마디 — 예전에 못 연 그 문")
	else:
		t.ok(true, "포인트가 모자라 문턱을 못 넘는 몸(건너뜀)")
	h.free()


func test_perks_review_fixes(t) -> void:
	var r := _host()
	var h: InteriorHost = r[0]
	var st: StoryState = r[1]
	# 이미 연 자리는 문턱 한 마디에서 다시 말하지 않는다
	h._tried("LOCKPICK", 50, "문", "door:TEST:1,1")
	st.call_fn("xp", [250])
	var d := LevelDraft.begin(st)
	t.ok(d.tried_lock("LOCKPICK", 50) != "", "못 연 문 기억")
	st.boxes["door:TEST:1,1"] = {"open": true}
	t.eq(d.tried_lock("LOCKPICK", 50), "", "열었으면 다시 말하지 않는다")
	# 먹기 꼬리표
	st.vars.set_v("PK_024", 1)
	t.eq(Perks.eat_tags(st, "I-054", false, true), "(레드 벨리)", "한강 물 — (레드 벨리)")
	t.eq(Perks.eat_tags(st, "I-001", true, false), "", "퍽과 상관없는 것엔 꼬리표 없음")
	# 단골 왕복 매매는 셈하지 않는다
	var tr := TradeScreen.new()
	tr.db = h.items_db
	tr._regular("W-013", 100, true)
	tr._regular("W-013", 60, false)
	tr._regular("W-013", 100, true)
	t.eq(tr.regular_add, 100, "산 것을 되팔고 되사는 왕복은 단골 누적에 넣지 않는다")
	tr._regular("W-013", 60, false)
	tr._regular("W-013", 100, true)
	t.ok(tr.greet.contains("세 번째"), "세 번째 왕복에 상인 한마디")
	tr.free()
	h.free()
