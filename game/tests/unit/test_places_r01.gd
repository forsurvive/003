## R01 정착지 · 거점 보강(단계 1-8d · 1-8f · 1-8g): 수송대 정류장 셋(봉천 · 사당 · 노들섬) · 의료반 이레 주기 · 사당 맵 일과 배타 ·
## 역무실 서랍 정기권 · 검문소 차단봉 조건 · 중계소 실내 접두(GS-).
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	return st


func _map(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))


func test_r01p_caravan_stops(t) -> void:
	var seen := {0: 0, 1: 0, 2: 0, 3: 0}
	var order: Array = []
	for h in Caravans.V54_CYCLE_H:
		var s := Caravans.v54_at(h * 60)
		seen[s] += 1
		if s != 0 and (order.is_empty() or order[-1] != s):
			order.append(s)
	t.eq(seen[1], 12, "봉천 정류장 12시간")
	t.eq(seen[2], 12, "사당 정류장 12시간")
	t.eq(seen[3], 12, "노들섬 정류장 12시간")
	t.eq(seen[0], 18, "정류장 사이 길 위 6시간 × 3")
	var first := order.find(1)
	var rot: Array = order.slice(first) + order.slice(0, first)
	t.eq(rot.slice(0, 3), [1, 2, 3], "남부 고개길 순서: 봉천 → 사당 → 노들섬 %s" % str(rot))
	t.eq(Caravans.v54_at(5 * 60), Caravans.v54_at((5 + Caravans.V54_CYCLE_H) * 60), "54시간마다 같은 자리")


func test_r01p_medic_week(t) -> void:
	var w: Array = []
	for d in 7:
		w.append(Caravans.medic_at(d))
	t.eq(w, [1, 1, 2, 2, 0, 0, 0], "의료반 이레: 봉천 0~1 · 지하상가 2~3 · 강 건너")
	t.eq(Caravans.medic_at(-1), Caravans.medic_at(6), "음수 날도 주기 안")


func test_r01p_sadang_people_one_place(t) -> void:
	var st := _state()
	var maps := ["X-SD", "D-01", "D-02", "D-03", "D-04", "D-05", "D-06"]
	for hour in [3, 9, 15, 21]:
		st.vars.set_v("GAME_HOUR", hour)
		st.vars.set_v("CARAVAN_V54", 2)
		var where := {}
		for id in maps:
			for n in _map(id)["npcs"]:
				var nid := str(n["id"])
				if not nid.begins_with("N-R01-04") and nid != "N-R01-040":
					continue
				if InteriorMap._cond_ok(str(n.get("cond", "")), st):
					where[nid] = where.get(nid, []) + [id]
		var dup := where.keys().filter(func(k): return (where[k] as Array).size() > 1)
		t.ok(dup.is_empty(), "%d시: 사당 이름 있는 인물은 한 곳에만 %s" % [hour, str(where)])
		for nid in ["N-R01-041", "N-R01-042", "N-R01-043", "N-R01-044", "N-R01-045", "N-R01-046"]:
			t.ok(where.has(nid), "%d시: %s가 어딘가에 있다" % [hour, nid])


func test_r01p_drawer_pass(t) -> void:
	var loot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/loot.json"))
	var rows: Array = loot["tables"]["sd_drawer"]["rows"]
	t.ok(rows.any(func(r): return str(r[0]) == "M-071" and float(r[1]) >= 1.0), "역무실 서랍: 정기권 M-071 한 장(반드시)")
	t.ok(not loot.get("restock", {}).has("sd_drawer"), "역무실 서랍은 다시 차지 않는다")
	var box: Array = _map("D-03")["boxes"].filter(func(b): return str(b["kind"]) == "sd_drawer")
	t.ok(box.size() == 1 and str(box[0]["owner"]) == "N-R01-041", "서랍 주인 = 허순자(가져가면 절도)")
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	var v05: Dictionary = m.get("merchants", m)["V05"]
	t.ok(not (v05["stock"] as Array).any(func(r): return str(r[0]) == "M-071"), "V05 진열에 정기권 없음(서랍 · SQ-S05 보상과 겹치지 않게)")


func test_r01p_gate_booms(t) -> void:
	var st := _state()
	var props: Array = _map("X-SG")["props"]
	var down: Array = props.filter(func(p): return str(p["name"]) == "bj_boom")
	var up: Array = props.filter(func(p): return str(p["name"]) == "bj_boom_up")
	t.eq(down.size(), 2, "차단봉 둘")
	var ok := func() -> bool: return InteriorMap._cond_ok(str(down[0]["cond"]), st) and not InteriorMap._cond_ok(str(up[0]["cond"]), st)
	t.ok(ok.call(), "시작(BJ −30): 내려와 있다")
	st.vars.set_v("AFF_BJ", 25)
	t.ok(ok.call(), "우호여도 등록증이 없으면 내려와 있다")
	st.call_fn("give", ["M-120", 1])
	t.ok(not InteriorMap._cond_ok(str(down[0]["cond"]), st) and InteriorMap._cond_ok(str(up[0]["cond"]), st), "우호 + 임시 등록증: 올라간다")
	st.vars.set_v("AFF_BJ", 10)
	t.ok(InteriorMap._cond_ok(str(down[0]["cond"]), st), "등록증이 있어도 중립으로 떨어지면 다시 내려온다")


func test_r01p_relay_prefix(t) -> void:
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/_index.json"))
	var keys: Array = idx.get("maps", idx).keys()
	for id in ["GS-01", "GS-02", "GS-03", "Q-01", "Q-02", "X-SG", "X-GS"]:
		t.ok(keys.has(id), "맵 색인에 %s" % id)
	t.ok(not keys.any(func(k): return str(k).begins_with("G-0")), "중계소 실내는 G- 접두(생성 실내)를 쓰지 않는다")
