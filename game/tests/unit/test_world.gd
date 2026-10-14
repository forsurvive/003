## 심리스 월드(단계 1-1): 굽기 색인·도달성, 손 맵 자리, 막힘, 길찾기, 스트리밍(붙이기 예산), 구역 좌표.
extends RefCounted


func _world() -> WorldMap:
	var m := WorldMap.new()
	m.load_map("W")
	return m


func test_world_index(t) -> void:
	var w: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/world.json"))
	t.eq(w["chunks"], [53.0, 43.0], "청크 53×43(SD-08 §3.2)")
	t.eq(int(w["chunk_size"]), 40, "청크 40×40")
	t.eq((w["unreached"] as Array).size(), 0, "놀이 청크 1,230 모두 걸어서 닿는다(물 청크 제외)")
	for k in w["water_chunks"]:
		t.ok(true, "물 청크 " + str(k))
	t.ok((w["water_chunks"] as Array).size() <= 4, "걷는 칸 없는 물 청크는 한강 몇 곳뿐")
	var n := 0
	for o in w["offsets"]:
		if int(o[1]) > 0:
			n += 1
	t.ok(n >= 1230, "내보낸 청크 %d ≥ 1230(놀이 + 경계 띠)" % n)
	t.ok((w["routes"]["X-S07>X-BC"] as Array).size() > 5, "비탈 → 봉천 걷는 길이 있다")


func test_world_insets(t) -> void:
	var m := _world()
	t.ok(WorldMap.covers("X-S07") and WorldMap.covers("X-BC") and WorldMap.covers("W"), "월드가 바깥 손 맵을 맡는다")
	t.ok(not WorldMap.covers("B-01") and not WorldMap.covers("V-00"), "실내는 따로")
	t.eq(m.tile_of(m.mark_pos("X-S07:from_vault")), Vector2i(959, 1503), "볼트 S-07 정문 = L-R01-01 좌표(959,1503)")
	var bc := m.to_world("X-BC", 30, 23)
	t.ok(bc.distance_to(Vector2i(892, 1362)) <= 1.5, "봉천 계단마을 가운데 ≈ L-R01-09(892,1362)")
	var to := {}
	for c in m.exits:
		to[str(m.exits[c]["to"])] = c
	t.ok(not to.has("X-S07") and not to.has("X-BC"), "손 맵끼리 잇던 가장자리 출구는 없다(이어진 땅)")
	t.ok(to.has("B-01") and to.has("B-03"), "봉천 실내 문(마을 회관·약국)은 남는다")
	t.eq(m.zone_of(m.to_world("X-BC", 5, 35)), "X-BC", "구역 판정")
	t.eq(m.zone_of(Vector2i(1058, 793)), "W", "광화문은 월드")
	m.id = "X-BC"
	t.eq(m.cell_local(5, 35), m.to_world("X-BC", 5, 35), "연출 좌표는 지금 구역의 손 맵 좌표")
	t.eq(m.zone_key("from_B-01"), "X-BC:from_B-01", "표지는 지금 구역 것을 먼저")
	t.eq(m.region_at(Vector2i(959, 1503)), "R01", "볼트 S-07은 R01")
	t.eq(m.region_name("R01"), "관악", "권역 이름(SD-08 §7)")
	t.eq(m.region_at(Vector2i(1058, 793)), "R05", "광화문은 R05")
	m.free()


func test_world_cells_path(t) -> void:
	var m := _world()
	var start := m.mark_pos("X-S07:start")
	m.load_now(start)
	t.ok(m.chunks.size() >= 9, "둘레 3×3 청크가 붙었다(%d)" % m.chunks.size())
	t.ok(not m.is_solid(m.tile_of(start)), "비탈 첫 칸은 걷는 칸")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/tiles/ts_r01_ext.json"))
	var deep := int(meta["water_deep"]["atlas"][0])
	var wet := 0
	var bad := 0
	var built := 0
	var built_bad := 0
	for k in m.chunks:
		var a: PackedByteArray = m.chunks[k]["a"]
		for i in 1600:
			var cell := Vector2i(k.x * 40 + i % 40, k.y * 40 + i / 40)
			if a[WorldMap.L_FG + i * 2] == deep:
				wet += 1
				if not m.is_solid(cell) and a[WorldMap.L_BODY + i * 2] == 0:
					bad += 1
			var b := a[WorldMap.L_BODY + i * 2] | (a[WorldMap.L_BODY + i * 2 + 1] << 8)
			if b > 0 and a[WorldMap.L_FG + i * 2 + 1] == 1 and a[WorldMap.L_STAIR + i] == 0:
				built += 1
				if not m.is_solid(cell):
					built_bad += 1
	t.eq(bad, 0, "깊은 물(다리 상판 아닌 곳)은 막힘(%d칸)" % wet)
	t.ok(built > 0, "건물·암벽 칸이 있다(%d)" % built)
	t.eq(built_bad, 0, "건물·암벽 칸은 막힘")
	var rt: Array = m.route_between("X-S07", "X-BC")
	var goal := Vector2(int(rt[2][1]) * 32 + 16, int(rt[2][2]) * 32 + 16)
	m.load_now(goal)
	var p := m.path(Vector2(int(rt[1][1]) * 32 + 16, int(rt[1][2]) * 32 + 16), goal)
	t.ok(not p.is_empty(), "경유점 사이 길찾기")
	t.eq(m.route_between("X-BC", "X-S07").size(), rt.size(), "거꾸로 길")
	m.free()


func test_world_streaming(t) -> void:
	var m := _world()
	var p := Vector2(959 * 32, 1503 * 32)
	m.load_now(p)
	for step in 6:                                                       # 북쪽으로 6청크 걸어 올라간다
		p.y -= 40 * 32
		m.load_now(p)
	t.ok(m.chunks.size() <= 49, "7×7 밖은 해제(%d)" % m.chunks.size())
	t.ok(not m.chunks.has(Vector2i(23, 37)), "출발 청크는 해제됨")
	t.ok(m.attach_count >= 9 * 2, "붙인 청크 %d" % m.attach_count)
	print("  월드 청크 붙이기 최대 %.2fms · %d회" % [m.attach_usec_max / 1000.0, m.attach_count])
	t.ok(m.attach_usec_max < 40000, "붙이기 1회 40ms 이하(헤드리스, 기준 기기 측정은 이월)")
	m.free()


func test_world_places(t) -> void:
	PlaceLog.load_db()
	t.eq(PlaceLog.db.size(), 425, "장소 425곳(SD-08 §11 · SD-09a~f)")
	var p := PlaceLog.new()
	t.eq(int(PlaceLog.db["L-R01-09"]["xp"]), 25, "봉천 계단마을 = 주요(정착지) 25 XP")
	t.eq(int(PlaceLog.db["L-R01-01"]["xp"]), 0, "볼트 S-07 = 통계 제외 0 XP")
	t.ok(bool(PlaceLog.db["L-R01-02"]["hidden"]), "S-07 비상 탈출구 = 발견 전 숨김")
	t.ok(not bool(PlaceLog.db["L-R02-27"]["marker"]), "온수 경계 둑 = 마커 N")
	t.eq(int(PlaceLog.db["L-UG-01"]["xp"]), 5, "지하철역 5 XP")
	var got := p.discover_near(Vector2i(892 + 3, 1362 - 2))
	t.ok("L-R01-09" in got, "반경 4타일 안 = 발견")
	t.eq(p.discover_near(Vector2i(892, 1362)).size(), 0, "두 번 발견하지 않는다")
	t.eq(p.discover_near(Vector2i(892 + 6, 1362)).size(), 0, "반경 밖")
	t.ok(not p.on_map("L-R01-02"), "숨김 장소는 표시만으로는 지도에 없다")
	p.raise("L-R01-02", PlaceLog.MARKED)
	t.ok(not p.on_map("L-R01-02"), "숨김 장소는 표시 상태여도 지도에 없다")
	p.raise("L-R01-02", PlaceLog.FOUND)
	t.ok(p.on_map("L-R01-02"), "발견하면 지도에 있다")
	t.ok(not p.raise("L-R01-02", PlaceLog.RUMOR), "상태는 내려가지 않는다")
	var q := PlaceLog.new()
	q.from_dict(JSON.parse_string(JSON.stringify(p.to_dict())))
	t.eq(q.get_state("L-R01-09"), PlaceLog.FOUND, "저장 왕복")
	t.eq(q.count_found(), 2, "발견 수(마커 Y)")


func test_world_fast_travel(t) -> void:
	var st := StoryState.new()
	st.load_data()
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	h.body = "adult"
	h.date_text = "2277. 10. 23.  22:40"
	h.enter("X-BC", "from_X-S07")
	t.eq(h.travel_check("L-R01-18")[1], InteriorHost.TRAVEL_MSG["F1"], "F1 아직 가 보지 않은 장소")
	st.places.raise("L-R01-18", PlaceLog.FOUND)
	var ok: Array = h.travel_check("L-R01-18")
	t.ok(ok[0] and int(ok[2]) == 1, "같은 강변(남안) 사당 환승촌 = 1시간")
	st.places.raise("L-R03-03", PlaceLog.FOUND)
	t.eq(h.travel_check("L-R03-03")[1], InteriorHost.TRAVEL_MSG["F7"], "F7 강 건너(탱크마을 북안) — 확보한 횡단로 없음")
	st.places.raise("L-R05-01", PlaceLog.FOUND)
	t.eq(h.travel_check("L-R05-01")[1], InteriorHost.TRAVEL_MSG["F6"], "F6 도심 밀폐 구역")
	h._arrive("L-R01-18", 1)
	var e: Dictionary = PlaceLog.db["L-R01-18"]
	t.ok(h.map.tile_of(h.player.loco.logical).distance_to(Vector2i(int(e["tx"]), int(e["ty"]))) <= 12.0, "사당 환승촌 곁에 도착")
	t.ok(not h.map.is_solid(h.map.tile_of(h.player.loco.logical)), "도착 칸은 걷는 칸")
	t.eq(h.date_text, "2277. 10. 23.  23:40", "1시간이 지났다")
	h._arrive("L-R01-18", 2)
	t.eq(h.date_text, "2277. 10. 24.  01:40", "날이 넘어간다")
	t.eq(h.map.id, "W", "봉천 밖 구역")
	t.eq(PlaceLog.bank_at(Vector2i(892, 1362)), "S", "봉천은 남안")
	t.eq(PlaceLog.bank_at(Vector2i(1058, 793)), "N", "광화문은 북안")
	h.free()
