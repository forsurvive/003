## 들어가 보는 건물(단계 1-5e, STAGE_1 §1.1 '자유도 = 탐험이 서사를 만든다'): 굽기가 만든 건물 문과 실내 'G-x-y'가 짝이 맞는다 ·
## 실내 출구는 그 문 앞 칸('@x,y')으로 나온다 · 1막 권역(R01·R02)에만 · 종류가 여럿 · 용기 종류가 루팅 표에 있다 · 잠긴 문은 25·50.
extends RefCounted


func test_gen_doors(t) -> void:
	PlaceLog.load_db()
	var doors := PlaceLog.doors.filter(func(d): return str(d.get("kind", "")) == "facade")
	t.ok(doors.size() >= 300, "들어가는 건물 문 %d곳(1막 권역에 청크당 2곳 안팎)" % doors.size())
	var kinds := {}
	var bad_exit := 0
	var missing := 0
	var bad_lock := 0
	var bad_region := 0
	var box_kinds := {}
	for d in doors:
		var mid := str(d["to"])
		if not InteriorMap.exists(mid):
			missing += 1
			continue
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % mid))
		kinds[str(m.get("gen", ""))] = true
		var want := "@%d,%d" % [int(d["at"][0]), int(d["at"][1]) + 1]
		if str(d.get("lid", "")) != "":                                      # 손 실내(1-5e K-*): 장소 도착 칸 = 문 앞
			want = str(d["lid"])
			PlaceLog.load_db()
			var arr = PlaceLog.db.get(want, {}).get("arrive")
			if arr == null or int(arr[0]) != int(d["at"][0]) or int(arr[1]) != int(d["at"][1]) + 1:
				bad_exit += 1
		for e in m["exits"]:
			if str(e["to"]) == "W" and str(e["mark"]) != want:
				bad_exit += 1
		if not m["marks"].has("from_W"):
			bad_exit += 1
		if not str(m.get("region", "")) in ["R01", "R02"]:
			bad_region += 1
		if not int(d.get("lock", 0)) in [0, 25, 50]:
			bad_lock += 1
		for b in m["boxes"]:
			box_kinds[str(b["kind"])] = true
	t.eq(missing, 0, "문마다 실내 맵이 있다")
	t.eq(bad_exit, 0, "실내 출구는 모두 그 문 앞 칸으로 나간다")
	t.eq(bad_region, 0, "1막 권역(R01·R02)에만 만든다")
	t.eq(bad_lock, 0, "잠긴 문은 자물쇠 25 또는 50")
	t.ok(kinds.size() >= 5, "실내 종류 %d가지: %s" % [kinds.size(), str(kinds.keys())])
	Loot._load()
	for k in box_kinds:
		t.ok(Loot.tables.has(k), "실내 용기 종류 '%s'가 루팅 표에 있다" % k)


func test_gen_enter(t) -> void:
	var host := InteriorHost.new()
	PlaceLog.load_db()
	var d: Dictionary = {}
	for x in PlaceLog.doors:
		if str(x.get("kind", "")) == "facade" and int(x.get("lock", 0)) == 25:
			d = x
			break
	t.ok(not d.is_empty(), "잠긴 건물 문이 있다(자물쇠 25)")
	host.body = "adult"
	host._ready()
	host.st.quests.set_stage("MQ-P4", 100)
	host.enter("W", "@%d,%d" % [int(d["at"][0]), int(d["at"][1]) + 1])
	host.player.loco.facing = 6
	t.ok(host._front_go().get("to", "") == d["to"], "문 앞에서 북쪽을 보면 그 문")
	t.ok(host.box_prompt().contains("[잠김: 쉬움"), "잠긴 문 안내: " + host.box_prompt())
	host.st.boxes["wdoor:%d,%d" % [int(d["at"][0]), int(d["at"][1])]] = {"open": true}
	t.ok(host.box_prompt().begins_with("(E) 들어간다"), "딴 뒤에는 '(E) 들어간다'")
	host.free()


## 쪽지 따라가기(1-5e): 쪽지가 가리키는 가게 이름은 하나뿐이고, 그 가게에 숨겨 둔 상자(stash)가 있다 · 쪽지에 자리 표시자가 남지 않는다
func test_gen_stash(t) -> void:
	var dir := DirAccess.open("res://data/maps")
	var by_name := {}
	var stash_maps := {}
	var notes: Array = []
	var texts: Array = []
	for f in dir.get_files():
		if not f.begins_with("G-") or not f.ends_with(".json"):
			continue
		var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		by_name[str(m["name"])] = int(by_name.get(str(m["name"]), 0)) + 1
		for b in m["boxes"]:
			if str(b["kind"]) == "stash":
				stash_maps[str(m["name"])] = true
		for x in m["texts"]:
			texts.append([str(m["name"]), str(x["text"])])
	for pair in texts:                                                  # 쪽지 = 다른 건물에서 숨긴 가게 이름 + 방위를 말하는 글(문장 틀은 여럿 — rooms.txt stash_note)
		var tx: String = pair[1]
		if not tx.contains("쪽지") and not tx.contains("뒷장") and not tx.contains("뒷면"):
			continue
		for nm in stash_maps:
			if nm != pair[0] and tx.contains(nm) and ["북", "남", "동", "서"].any(func(d): return tx.contains(d)):
				notes.append(tx)
				break
	t.ok(stash_maps.size() >= 20, "숨겨 둔 상자 %d곳" % stash_maps.size())
	var bad := 0
	for nm in stash_maps:
		if int(by_name[nm]) != 1:
			bad += 1
	t.eq(bad, 0, "숨긴 가게 이름은 실내 가운데 하나뿐(헷갈리지 않는다)")
	var holes := 0
	for s in notes:
		if s.contains("{"):
			holes += 1
	t.ok(notes.size() >= 20, "쪽지 %d장" % notes.size())
	t.eq(holes, 0, "쪽지에 자리 표시자가 남지 않는다")
	Loot._load()
	t.ok(Loot.tables.has("stash"), "숨겨 둔 상자 루팅 표")
