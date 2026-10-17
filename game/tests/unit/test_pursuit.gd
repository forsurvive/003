## 쫓기다 건물로 들어가면(1-B4, 설계안 §7.3): 사람형은 몇 초 뒤 일부가 문 앞 칸으로 따라 들어온다 · 짐승은 들어오지 않고 문을 긁다가,
## 같은 문으로 나오면 문 앞에서 기다린다 · 오래 숨어 있으면 흩어져 '놓친 무리'로 기억 · 추적대(이야기 사건)는 따라오지 않는다
extends RefCounted


func _host(t) -> Array:
	var h := InteriorHost.new()
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 25.  14:00"
	h.st.quests.set_stage("MQ-P4", 100)
	PlaceLog.load_db()
	var d: Dictionary = {}
	for x in PlaceLog.doors:
		if str(x.get("kind", "")) == "facade" and str(x["to"]).begins_with("G-") and int(x.get("lock", 0)) == 0:
			d = x
			break
	t.ok(not d.is_empty(), "생성 건물 문")
	h.enter("W", "@%d,%d" % [int(d["at"][0]), int(d["at"][1]) + 1])
	return [h, d]


func _chase(h: InteriorHost, ids: Array, cat: String) -> void:
	var foes: Array = []
	for i in ids.size():
		var e: Enemy = h.combat.spawn(str(ids[i]), h.player.loco.logical + Vector2(96 + i * 32, 64), h.map, h.st,
			{"team": "enemy", "foes": ["player", "ally"]})
		foes.append(e)
	h.enc_live.cur = {"re": "RE-T", "cat": cat, "phase": "live", "foes": foes, "actors": [], "props": [], "t": 1.0}


## 문 앞 6칸 안의 그 적(월드에는 원래 서 있던 들개도 있다)
func _near(h: InteriorHost, id: String, d: Dictionary) -> int:
	var at := Vector2(int(d["at"][0]) * 32 + 16, (int(d["at"][1]) + 1) * 32 + 16)
	return h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and str(e.get_meta("enemy_id", "")) == id \
		and not e.cmb.dead and e.loco.logical.distance_to(at) <= 6 * 32.0).size()


func _run(h: InteriorHost, secs: float) -> void:
	var n := int(secs / 0.25)
	for i in n:
		h.enc_live.tick(0.25)


func test_pursuit_people(t) -> void:
	var r := _host(t)
	var h: InteriorHost = r[0]
	var d: Dictionary = r[1]
	_chase(h, ["CR-423", "CR-423", "CR-423"], "raider")
	h.enter(str(d["to"]), "from_W")
	t.ok(not h.enc_live.pursuit.is_empty() and not bool(h.enc_live.pursuit["beast"]), "약탈자 셋에 쫓기며 들어감 → 쫓김 기록(사람형)")
	t.eq(h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and str(e.get_meta("enemy_id", "")) == "CR-423").size(), 0, "들어선 순간엔 아무도 없다")
	_run(h, 7.0)
	var inn: Array = h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and str(e.get_meta("enemy_id", "")) == "CR-423")
	t.eq(inn.size(), 2, "몇 초 뒤 셋 중 둘이 문을 열고 들어온다")
	t.ok(h.enc_live.pursuit.is_empty(), "쫓김은 실내 싸움으로 넘어갔다")
	h.free()


func test_pursuit_beasts(t) -> void:
	var r := _host(t)
	var h: InteriorHost = r[0]
	var d: Dictionary = r[1]
	_chase(h, ["CR-104", "CR-104"], "creature")
	h.enter(str(d["to"]), "from_W")
	t.ok(bool(h.enc_live.pursuit.get("beast", false)), "들개에 쫓기며 들어감 → 짐승 쫓김")
	_run(h, 10.0)
	t.eq(h.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion() and str(e.get_meta("enemy_id", "")) == "CR-104").size(), 0, "들개는 들어오지 않는다")
	h.enter("W", "@%d,%d" % [int(d["at"][0]), int(d["at"][1]) + 1])
	var base := _near(h, "CR-104", d)
	_run(h, 0.5)
	t.eq(_near(h, "CR-104", d) - base, 2, "같은 문으로 나오면 문 앞에서 기다리고 있었다")
	# 오래 숨으면 흩어진다
	_chase(h, ["CR-104"], "creature")
	h.enter(str(d["to"]), "from_W")
	_run(h, 62.0)
	t.ok(h.enc_live.pursuit.is_empty(), "1분 넘게 숨으면 흩어진다")
	h.enter("W", "@%d,%d" % [int(d["at"][0]), int(d["at"][1]) + 1])
	var base2 := _near(h, "CR-104", d)
	_run(h, 0.5)
	t.eq(_near(h, "CR-104", d) - base2, 0, "흩어진 뒤 나오면 문 앞에 기다리는 들개가 없다")
	h.free()


func test_pursuit_tracker(t) -> void:
	var r := _host(t)
	var h: InteriorHost = r[0]
	var d: Dictionary = r[1]
	_chase(h, ["CR-436"], "tracker")
	h.enter(str(d["to"]), "from_W")
	t.ok(h.enc_live.pursuit.is_empty(), "추적대(이야기 사건)는 쫓아 들어오지 않는다 — 퀘스트 규칙이 먼저(P4)")
	h.free()
