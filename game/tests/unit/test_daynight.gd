## 낮밤(단계 1-T1~T3): 시각 → 색조·시간대(SD-16 §4.7), 시간대별 크리처 인카운터(SD-14 §11.2 주·황·야),
##   밤 짐승(너구리 CR-136) 자료·성향, 실내 색조 없음 · 불 꺼진 암거만 정전 필터.
extends RefCounted


func _st() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 2)
	return st


func test_time_of_day_tones(t) -> void:
	t.eq(TimeOfDay.minute("2277. 10. 24.  21:30"), 21 * 60 + 30, "날짜 글자 → 하루 안의 분")
	t.eq(TimeOfDay.tone(12 * 60), Vector4.ZERO, "한낮 = 색조 없음")
	t.eq(TimeOfDay.tone(2 * 60), TimeOfDay.TONES["깊은 밤"], "02시 = 깊은 밤 필터 그대로")
	t.eq(TimeOfDay.tone(18 * 60 + 30), TimeOfDay.TONES["노을"], "18:30 = 노을 필터")
	t.eq(TimeOfDay.tone(22 * 60), TimeOfDay.TONES["밤"], "22시 = 밤 필터")
	t.eq(TimeOfDay.tone(5 * 60 + 30), TimeOfDay.TONES["새벽"], "05:30 = 새벽 필터")
	var mid := TimeOfDay.tone(17 * 60 + 30)
	t.ok(mid.x > 0.0 and mid.x < TimeOfDay.TONES["노을"].x, "17:30 = 낮과 노을 사이(1시간에 걸쳐 섞임): %s" % str(mid))
	t.eq(TimeOfDay.tone(0), TimeOfDay.tone(1440), "자정 앞뒤가 이어진다")
	var jumps := 0.0
	for m in 1440:
		jumps = maxf(jumps, (TimeOfDay.tone(m + 1) - TimeOfDay.tone(m)).length())
	t.ok(jumps < 3.0, "1분 사이 색조가 튀지 않는다(최대 %.2f)" % jumps)
	t.eq([TimeOfDay.band(330), TimeOfDay.band(720), TimeOfDay.band(1110), TimeOfDay.band(1290), TimeOfDay.band(150)],
		["새벽", "낮", "노을", "밤", "깊은 밤"], "시간대 이름")
	t.eq(TimeOfDay.light_k(12 * 60), 0.0, "낮엔 불빛 원판 없음")
	t.eq(TimeOfDay.light_k(22 * 60), 1.0, "밤엔 불빛 원판 다 켜짐")
	t.eq(TimeOfDay.pip_k(22 * 60), 0.0, "그냥 밤엔 핍-보이 조명 꺼짐")
	t.eq(TimeOfDay.pip_k(2 * 60), 1.0, "깊은 밤엔 핍-보이 조명(SD-16 §4.7 반경 96px)")
	t.eq([TimeOfDay.fog_k(3 * 60), TimeOfDay.fog_k(270), TimeOfDay.fog_k(330), TimeOfDay.fog_k(390), TimeOfDay.fog_k(12 * 60)],
		[0.0, 0.5, 1.0, 0.5, 0.0], "새벽 지면 안개: 04~05 차오름 · 05~06 가득 · 06~07 걷힘")
	t.ok(not TimeOfDay.is_dark(Vector4.ZERO) and TimeOfDay.is_dark(TimeOfDay.TONES["새벽"]), "색조 유무")


## 같은 자리 · 같은 씨앗으로 낮과 밤에 크리처 RE를 여러 번 뽑아 무엇이 나오는지 센다
func _creatures(hour: int, night: bool, n := 600) -> Dictionary:
	var en := Encounters.new(_st(), 33)
	en.ctx = {"hour": hour, "level": 3, "tags": []}
	var seen := {}
	for i in n:
		var id := en._pick("R01", night, Vector2i(-1, -1))
		if id != "" and str(Encounters.re_def(id).get("cat", "")) == "creature":
			seen[id] = int(seen.get(id, 0)) + 1
	return seen


func test_time_band_creatures(t) -> void:
	var day := _creatures(12, false)
	var night := _creatures(23, true)
	t.ok(day.has("RE-001") or day.has("RE-X01"), "낮: 들개 무리가 나온다 %s" % str(day))
	for id in ["RE-X05", "RE-X06", "RE-X07", "RE-004"]:
		t.ok(not day.has(id), "낮에는 %s 없음" % id)
	t.ok(not night.has("RE-001") and not night.has("RE-X01"), "밤: 낮 들개(RE-001 · X01)는 잠든다 %s" % str(night))
	t.ok(night.has("RE-X05"), "밤: 밤 사냥 들개(R01 야간 교체 +2, SD-14 §11.2)")
	t.ok(night.has("RE-X06") or night.has("RE-X07"), "밤: 시궁쥐 · 너구리가 거리에 나온다")
	var dusk := _creatures(19, false)
	t.ok(dusk.has("RE-X07"), "황혼(19시): 너구리가 먼저 나온다(18~06) %s" % str(dusk))
	t.ok(not dusk.has("RE-X05"), "황혼은 아직 밤 사냥 들개 아님(밤 20~05)")
	var d5 := Encounters.re_def("RE-X05")
	t.eq(str((d5["groups"][0] as Dictionary).get("leader", [""])[0]), "CR-106", "밤 사냥 들개엔 우두머리 자리가 있다(§4.2)")
	t.ok(str(d5.get("sign", "")) != "" and str(Encounters.re_def("RE-X07").get("sign", "")) == "rustle", "밤 짐승도 흔적이 먼저(SD-22 §3.4)")


func test_raccoon_data(t) -> void:
	var st := _st()
	var cr: Dictionary = st.enemies.get("CR-136", {}) if "enemies" in st else {}
	if cr.is_empty():
		var f := FileAccess.open("res://data/enemies.json", FileAccess.READ)
		var all = JSON.parse_string(f.get_as_text())
		for r in (all if typeof(all) == TYPE_ARRAY else all.get("rows", all.values())):
			if typeof(r) == TYPE_DICTIONARY and str(r.get("id", "")) == "CR-136":
				cr = r
	t.ok(not cr.is_empty(), "CR-136 너구리 자료가 있다")
	t.eq(int(cr.get("hp", 0)), 30, "너구리 HP 30(SD-14 §11.2)")
	t.eq(str(EnemyTraits.of("CR-136").get("ai", "")), "AI-01", "너구리 = 겁 많은 짐승(AI-01)")
	t.eq(int(EnemyTraits.of("CR-136").get("conf", -1)), 0, "자신감 0 = 보면 달아나고, 몰리면 문다")
	t.ok(ResourceLoader.exists("res://assets/sprites/cr_cr136_loco.tres"), "너구리 걸음 시트")
