## MQ-105 새벽인력 본소(단계 1-6, SD-03a §8.5 · SD-09a L-R02-19): 손 맵 X-SB가 월드에 찍혔다 · 장소 도착 칸 = 정문 앞 길 ·
## 본소 실내 출구가 서로 맞물린다 · 정문 장면·습격 자리 10 · 우리 '인력' 여섯 · 장부 문서 · 매점 · 진행기 변수.
extends RefCounted


func _map(id: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))


func test_sb_inset(t) -> void:
	t.ok(WorldMap.covers("X-SB"), "손 맵 X-SB가 월드에 찍혔다")
	var o := WorldMap.origin_of("X-SB")
	var d := _map("X-SB")
	PlaceLog.load_db()
	var arr = PlaceLog.db.get("L-R02-19", {}).get("arrive")
	var m: Array = d["marks"]["arrive"]
	t.ok(arr != null and int(arr[0]) == o.x + int(m[0]) and int(arr[1]) == o.y + int(m[1]), "본소 도착 칸 = 정문 앞 길 표지(%s)" % str(arr))
	var raid := 0
	for k in d["marks"]:
		if str(k).begins_with("raid_"):
			raid += 1
	t.eq(raid, 10, "정면 습격 자리 10(조직원 10)")
	var gate: Array = d["triggers"].filter(func(g): return str(g["scene"]) == "X-SB_GATE")
	t.eq(gate.size(), 1, "정문 밟는 칸 하나")
	t.ok(d["structs"].size() >= 10, "구조물(철골동 · 지붕 · 철판 담 · 폐건물) %d장" % d["structs"].size())
	var dogs: Array = d["enemies"].filter(func(e): return str(e["id"]) == "CR-107")
	t.eq(dogs.size(), 4, "뒷마당 경비견 넷(SD-09a H-07)")


func test_sb_exits(t) -> void:
	var bad := []
	for id in ["X-SB", "H-02", "H-03", "H-04", "H-05"]:
		var d := _map(id)
		for e in d["exits"]:
			var to := str(e["to"])
			var mk := str(e["mark"])
			if not InteriorMap.exists(to) or not _map(to)["marks"].has(mk):
				bad.append("%s → %s:%s" % [id, to, mk])
	t.eq(bad, [], "본소 출구가 모두 있는 맵·표지로 간다")
	t.ok(_map("H-03")["exits"].all(func(e): return str(e["to"]) == "X-SB"), "창고동 우리 출구는 마당·뒷마당(X-SB)")


func test_sb_cages(t) -> void:
	var d := _map("H-03")
	var people := 0
	for x in Act1Paths.SB_CAGES:
		var r := Rect2i(x - 3, 3, 6, 5)
		for p in d["props"]:
			if str(p["name"]).begins_with("detainee") and r.has_point(Vector2i(int(p["x"]), int(p["y"]))):
				people += 1
		for n in d["npcs"]:
			if r.has_point(Vector2i(int(n["x"]), int(n["y"]))):
				people += 1
	var want := 0
	for x in Act1Paths.SB_CAGES:
		want += int(Act1Paths.SB_CAGES[x])
	t.eq(want, 6, "우리의 다른 '인력' 여섯(SD-03a §8.5)")
	t.eq(people, 6, "H-03 우리 칸에 실제로 선 사람도 여섯")


func test_sb_data(t) -> void:
	var notes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/notes.json"))
	for id in ["SB-RULE", "SB-LEDGER", "SB-ORDER", "SB-ORDER7"]:
		t.ok(notes.get("notes", notes).has(id), "기록물 %s" % id)
	var mer: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/merchants.json"))
	t.ok(mer.has("VSB") and str(mer["VSB"]["npc"]) == "N-R02-037", "본소 매점(소개비)")
	var idx: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/_index.json"))["scenes"]
	for s in ["X-SB_GATE", "MQ-105_HDC_DEAL", "MQ-105_HDC_BUY", "MQ-105_LEDGER", "MQ-105_COAT", "X-SB_FIRE", "MQ-105_JO", "MQ-105_BJ", "H-03_CAGE"]:
		t.ok(idx.has(s), "장면 %s" % s)
	var st := StoryState.new()
	st.load_data()
	for k in ["GAME_HOUR", "SB_RAID", "SB_PASS", "SB_READ", "SB_FREED", "HO_LEDGER", "D_HDC"]:
		t.ok(st.vars.has(k), "변수 %s" % k)


## 정문 장면: 볼트 작업복 + 수배 공고면 알아본다(손을 내밀기 · 화술 · 총 · 달아남), 아니면 사러 왔는지 묻는다
func test_sb_gate_known(t) -> void:
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/X-SB_GATE.json"))
	var texts := []
	for op in g["ops"]:
		if op["op"] == "choice":
			for o in op["opts"]:
				texts.append(str(o["text"]))
	t.ok(texts.any(func(s): return s.contains("손을 내민다")), "알아보면 '손을 내민다'(일부러 잡힌다)")
	t.ok(texts.any(func(s): return s.contains("사람을 사러")), "구매자 위장")
	t.ok(texts.any(func(s): return s.contains("돈 얘기")), "거래(소장 면담)")
	t.ok(texts.any(func(s): return s.contains("총을 꺼낸다")), "정면 습격")
