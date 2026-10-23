## 1막 마감 배치(1-13a2): 배치 대조가 찾은 '자리 · 대화 없는 인물'을 채운 것 — 장면 · 맵 자리 · 새 가게 둘(경희 수선 · 버섯 선반) · 갈래.
extends RefCounted


func _host(map_id := "J-02", mark := "from_J-03") -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 10)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 11. 01.  10:00"
	st.vars.set_v("GAME_HOUR", 10)
	h.enter(map_id, mark)
	return [h, st]


func _scene(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % id))


func test_act1_people_data(t) -> void:
	for s in ["ZBJ_SHIN", "ZSB_SEONBUL", "ZBJ_HA", "ZSB_JOO", "ZJH_GH", "ZSA_EOM", "R01-16_RIDER", "R02-27_PASS"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % s), "장면 %s" % s)
	var mer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	t.ok(mer.has("VJ_GH") and str(mer["VJ_GH"]["npc"]) == "N-R02-507", "경희 수선 = 감경희")
	t.eq((mer["VJ_GH"]["fix"] as Dictionary)["kinds"], ["의복"], "경희 수선은 옷 · 가죽만 기운다")
	t.ok(mer.has("VSA_EOM") and (mer["VSA_EOM"]["buys"] as Array).is_empty(), "엄기철은 팔기만 한다")
	t.ok(str(mer["VSA_EOM"]["stock"][0][0]) == "I-044" and int(mer["VSA_EOM"]["stock"][0][1]) == 3, "느타리 셋")
	var where := {"J-02": "N-R02-507", "J-11": "N-R02-503", "GS-02": "N-R01-504", "D-05": "N-R01-505", "H-02": "N-R02-502"}
	for m in where:
		var md: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % m))
		t.ok((md["npcs"] as Array).any(func(n): return str(n["id"]) == where[m]), "%s에 %s" % [m, where[m]])
	var sb := _scene("ZSB_SEONBUL")
	t.ok((sb["labels"] as Dictionary).has("AFTER") and (sb["labels"] as Dictionary).has("LINE"), "선불: 호송차 뒤 인사 · 본소 칠판으로 잇는 갈래")


func test_act1_people_fix(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	t.ok(h.npcs.any(func(n): return str(n["id"]) == "N-R02-507"), "감경희가 J-02에 선다")
	st.call_fn("give", [Gear.key_of("A-016", 3), 1])
	var jobs := h.fix_jobs("VJ_GH")
	t.ok(jobs.any(func(j): return Gear.base(str(j["key"])) == "A-016"), "해진 정착민 복장을 맡길 수 있다")
	st.vars.set_v("AFF_JH", -80)
	t.ok(h.fix_jobs("VJ_GH").is_empty(), "상인회와 원수면 기워 주지 않는다(장면 COLD와 같은 문턱)")
