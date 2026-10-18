## 들어가 보는 건물(단계 1-5e, STAGE_1 §1.1 '자유도 = 탐험이 서사를 만든다'): 굽기가 만든 건물 문과 실내 'G-x-y'가 짝이 맞는다 ·
## 실내 출구는 그 문 앞 칸('@x,y')으로 나온다 · 1-B부터 전 권역 모든 건물 · 종류가 여럿 · 용기 종류가 루팅 표에 있다 · 잠긴 문은 25·50.
extends RefCounted

const REGIONS := ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11", "HR", "0"]


func test_gen_doors(t) -> void:
	PlaceLog.load_db()
	var doors := PlaceLog.doors.filter(func(d): return str(d.get("kind", "")) == "facade")
	t.ok(doors.size() >= 6000, "들어가는 건물 문 %d곳(1-B: 전 권역 모든 건물)" % doors.size())
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
		var m: Dictionary = InteriorMap.read_data(mid)
		kinds[str(m.get("gen", ""))] = true
		var want := "@%d,%d" % [int(d["at"][0]), int(d["at"][1]) + 1]
		var want2 := want
		if str(d.get("lid", "")) != "":                                      # 손 실내(1-5e K-*): 장소 도착 칸 = 문 앞
			want = str(d["lid"])
			want2 = want + ">" + str(d.get("mark", ""))                      # 1-D3 정면 문이 둘인 장소(독산): 'L-ID>표지' = 그 표지로 드는 문 앞
			PlaceLog.load_db()
			var arr = PlaceLog.db.get(want, {}).get("arrive")
			var fronts := doors.filter(func(o): return str(o.get("lid", "")) == want).map(func(o): return Vector2i(int(o["at"][0]), int(o["at"][1]) + 1))
			if arr == null or not fronts.has(Vector2i(int(arr[0]), int(arr[1]))):
				bad_exit += 1
		for e in m["exits"]:
			if str(e["to"]) == "W" and str(e["mark"]) != want and str(e["mark"]) != want2 \
					and not (str(d.get("lid", "")) != "" and str(e["mark"]).begins_with(want + ">")):   # 1-D6 정면 문 둘이 한 실내로(가산 정문 · 간판 사다리) — 출구마다 제 문 앞
				bad_exit += 1
		if not m["marks"].has("from_W"):
			bad_exit += 1
		var rg: Variant = m.get("region", "")
		if not (str(rg) if rg is String else str(int(rg))) in REGIONS:
			bad_region += 1
		if not int(d.get("lock", 0)) in [0, 25, 50]:
			bad_lock += 1
		for b in m["boxes"]:
			box_kinds[str(b["kind"])] = true
	t.eq(missing, 0, "문마다 실내 맵이 있다")
	t.eq(bad_exit, 0, "실내 출구는 모두 그 문 앞 칸으로 나간다")
	t.eq(bad_region, 0, "권역 표시가 있다(R01~R11 · HR · 0 = 표 밖)")
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


## 쪽지 따라가기(1-5e): 쪽지가 가리키는 가게 이름은 그 둘레에 하나뿐이고(1-B 전 권역 — 60칸 안에 같은 이름 없음), 그 가게에 숨겨 둔 상자(stash)가 있다 ·
## 쪽지에 자리 표시자가 남지 않는다 · 3고리까지 이어진 사슬이 있다
func test_gen_stash(t) -> void:
	var by_name := {}                                                   # 이름 → 문 자리들
	var stash_at: Array = []
	var stash_maps := {}
	var notes: Array = []
	var texts: Array = []
	for f in InteriorMap.gen_ids():
		var m: Dictionary = InteriorMap.read_data(f)
		var at := Vector2(int(str(f).split("-")[1]), int(str(f).split("-")[2]))
		if not by_name.has(str(m["name"])):
			by_name[str(m["name"])] = []
		by_name[str(m["name"])].append(at)
		for b in m["boxes"]:
			if str(b["kind"]) == "stash":
				stash_maps[str(m["name"])] = true
				stash_at.append([str(m["name"]), at])
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
	for pr in stash_at:
		if by_name[pr[0]].filter(func(o): return (o as Vector2).distance_to(pr[1]) <= 60.0).size() != 1:
			bad += 1
	t.eq(bad, 0, "숨긴 가게 이름은 그 둘레 60칸 안에 하나뿐(헷갈리지 않는다)")
	var next := texts.filter(func(p): return str(p[1]).contains("나머지는") or str(p[1]).contains("반은 여기") or str(p[1]).contains("옮긴다") or str(p[1]).contains("따로."))
	t.ok(next.size() >= 5, "다음 고리 글 %d장(3고리까지)" % next.size())
	var holes := 0
	for s in notes:
		if s.contains("{"):
			holes += 1
	t.ok(notes.size() >= 20, "쪽지 %d장" % notes.size())
	t.eq(holes, 0, "쪽지에 자리 표시자가 남지 않는다")
	Loot._load()
	t.ok(Loot.tables.has("stash"), "숨겨 둔 상자 루팅 표")


## 1-B 전 권역 · 가구 · 리듬 · 시간 층 · 문 앞 표식(설계안 §7): 권역마다 실내가 있다 · 집마다 조사 글 하나 이상 · 자리 표시자 · 이름 있는 인물 이름이 없다 ·
## 방 리듬 훑기가 대부분 · 표식은 실내와 맞는다(해골 = 적 · 덫 = 함정 · ✕ = 무너짐 — 거짓말하지 않는다, SD-20 P1)
func test_gen_b_all(t) -> void:
	var per_region := {}
	var homes := 0
	var empty := 0
	var holes := 0
	var named := 0
	var modes := {}
	var seen := {}
	var names := {}
	var npcs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs.json"))["npcs"]
	for k in npcs:
		names[str(npcs[k].get("name", ""))] = true
	var ids: Array = InteriorMap.gen_ids()
	t.ok(ids.size() >= 6000, "생성 실내 %d장(gen.bin 묶음)" % ids.size())
	for f in ids:
		var m: Dictionary = InteriorMap.read_data(f)
		per_region[str(m.get("region", ""))] = int(per_region.get(str(m.get("region", "")), 0)) + 1
		if not m.has("house"):
			continue
		homes += 1
		modes[str(m["house"]["mode"])] = int(modes.get(str(m["house"]["mode"]), 0)) + 1
		if m["texts"].is_empty():
			empty += 1
		for tx in m["texts"]:
			var s := str(tx["text"])
			if s.contains("{") or s.contains("}"):
				holes += 1
			seen[s] = int(seen.get(s, 0)) + 1
		for nm in m["house"].get("people", []):                         # 그 집 식구 이름(가구 생성기)
			if names.has(str(nm)):
				named += 1
	for r in ["R01", "R02", "R03", "R04", "R05", "R06", "R07", "R08", "R09", "R10", "R11", "HR"]:
		t.ok(int(per_region.get(r, 0)) >= (8 if r == "R05" else 10), "%s 실내 %d장" % [r, int(per_region.get(r, 0))])   # R05 도심은 폐허가 많아 정면 문이 적다 — 손 장소 기준점을 더하면 도시 배치가 다시 굴러 9~10장을 오간다(1-D6)
	t.ok(homes >= 2000, "가구가 있는 집 %d채" % homes)
	t.eq(empty, 0, "조사 글 없는 집 없음(빈 실내 금지)")
	t.eq(holes, 0, "자리 표시자가 남은 글 없음")
	t.eq(named, 0, "이름 있는 인물(SD-07)과 같은 이름이 집 글에 없음")
	var top := 0
	var top_s := ""
	for k in seen:
		if int(seen[k]) > top:
			top = int(seen[k])
			top_s = str(k)
	t.ok(float(top) / maxf(1.0, float(homes)) < 0.03, "가장 흔한 집 글이 집의 3%% 미만(%d번: %s)" % [top, top_s])
	var lived := float(homes - int(modes.get("den", 0)))                 # 떠돌이 소굴은 리듬 밖(살던 집 한 줄 + 떠돌이 층)
	var skim := float(modes.get("skim", 0)) / maxf(1.0, lived)
	t.ok(skim > 0.6 and skim < 0.8 and int(modes.get("story", 0)) > 0 and int(modes.get("scene", 0)) > 0, "방 리듬 훑기 %.2f · %s" % [skim, str(modes)])
	PlaceLog.load_db()
	var signs := {}
	var lie := 0
	for d in PlaceLog.doors:
		if not d.has("sign"):
			continue
		signs[str(d["sign"])] = int(signs.get(str(d["sign"]), 0)) + 1
		var m2: Dictionary = InteriorMap.read_data(str(d["to"]))
		var beasts := ["CR-002", "CR-095", "CR-097", "CR-104", "CR-105", "CR-106", "CR-108", "CR-136"]
		match str(d["sign"]):
			"skull":
				lie += 0 if m2.get("enemies", []).any(func(e): return not str(e["id"]) in beasts) else 1
			"claw":
				lie += 0 if not m2.get("enemies", []).is_empty() and m2["enemies"].all(func(e): return str(e["id"]) in beasts) else 1
			"live":
				lie += 0 if "l3" in m2.get("house", {}).get("layers", []) else 1
			"trap":
				var tp: bool = not m2.get("traps", []).is_empty() or not m2.get("mines", []).is_empty() \
					or m2["props"].any(func(p): return str(p["name"]) in ["trap_parcel", "trap_vending"])
				lie += 0 if tp else 1
			"x":
				lie += 0 if str(m2.get("gen", "")) == "collapsed" else 1
	t.ok(signs.size() >= 4, "문 앞 표식 갈래 %s" % str(signs))
	t.eq(lie, 0, "표식은 실내와 맞는다(P1)")


## 이웃 고리(1-B3) · 실내 상황(1-B4) · 업종(1-B5): 외상 장부 가게에 적힌 집이 40칸 안에 있고 그 집 글이 가게 이름을 말한다(양쪽이 함께) ·
## 소굴 사람형 자는 중 · 유해 곁 짐승 먹는 중 · 다방 · 미용실 · 비디오 · 노래방이 있다
func test_gen_b_links(t) -> void:
	var by_jip := {}
	var ledgers: Array = []
	var sleep := 0
	var feed := 0
	var kinds := {}
	for f in InteriorMap.gen_ids():
		var m: Dictionary = InteriorMap.read_data(f)
		var at := Vector2(int(str(f).split("-")[1]), int(str(f).split("-")[2]))
		if m.has("house"):
			by_jip[str(m["house"]["집"])] = by_jip.get(str(m["house"]["집"]), []) + [[at, m]]
		for tx in m["texts"]:
			if str(tx["text"]).begins_with("계산대에서 떨어진 외상 장부 한 장."):
				ledgers.append([str(m["name"]), at, str(tx["text"]).get_slice("'", 1).get_slice(" — ", 0)])
		for e in m["enemies"]:
			sleep += 1 if bool(e.get("sleep", false)) else 0
			feed += 1 if float(e.get("det", 1.0)) < 1.0 else 0
		for suf in ["다방", "커피숍", "미용실", "이용원", "비디오", "대여점", "노래방", "노래연습장"]:
			if str(m["name"]).ends_with(suf):
				kinds[suf] = true
	t.ok(ledgers.size() >= 10, "외상 장부 고리 %d" % ledgers.size())
	var bad := 0
	for l in ledgers:
		var ok := false
		for hm in by_jip.get(l[2], []):
			if (hm[0] as Vector2).distance_to(l[1]) <= 40.0 and (hm[1]["texts"] as Array).any(func(x): return str(x["text"]).contains(l[0])):
				ok = true
		bad += 0 if ok else 1
	t.eq(bad, 0, "장부의 집이 가까이 있고 그 집 가계부가 이 가게 이름을 말한다(한쪽만 있는 고리 없음)")
	t.ok(sleep >= 10 and feed >= 50, "실내 상황: 자는 사람 %d · 먹는 짐승 %d" % [sleep, feed])
	t.ok(kinds.size() >= 8, "업종 이름 %s" % str(kinds.keys()))
