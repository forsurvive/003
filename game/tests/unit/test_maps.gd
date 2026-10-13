## 실내 맵 체계 v1 (단계 0-5): S-07 실내 12장 자료, 충돌·길찾기, 출구·표지 연결, 문 열림, 인물 일과(실제로 걸려 본다).
extends RefCounted

const S07 := ["V-00", "V-01", "V-02", "V-03", "V-04", "V-05", "V-06", "V-07", "V-08", "V-09", "V-10", "V-11"]


func _load(id: String) -> InteriorMap:
	var m := InteriorMap.new()
	m.load_map(id)
	return m


func test_index(t) -> void:
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/_index.json"))["maps"]
	for id in S07:
		t.ok(idx.has(id), "맵 있음 " + id)
	t.eq(idx["V-01"]["size"], [60.0, 44.0], "아트리움 60×44(SD-09a)")


func test_exits_and_paths(t) -> void:
	var maps := {}
	for id in S07:
		maps[id] = _load(id)
	for id in S07:
		var m: InteriorMap = maps[id]
		t.ok(m.size.x > 0 and m.data["floor"].size() == m.size.y, id + " 격자")
		t.ok(not m.exits.is_empty(), id + " 출구가 하나 이상")
		var start: Vector2 = m.mark_pos(m.marks.keys()[0])
		for c in m.exits:
			var e: Dictionary = m.exits[c]
			t.ok(maps.has(e["to"]), "%s 출구 → %s 맵 있음" % [id, e["to"]])
			if maps.has(e["to"]):
				t.ok((maps[e["to"]] as InteriorMap).marks.has(e["mark"]), "%s → %s 도착 표지 %s" % [id, e["to"], e["mark"]])
				var back: InteriorMap = maps[e["to"]]
				t.ok(not back.is_solid(back.tile_of(back.mark_pos(e["mark"]))), "도착 표지가 바닥")
				t.ok(back.exit_at(back.tile_of(back.mark_pos(e["mark"]))).is_empty(), "도착 표지가 출구 칸이 아니다(되돌아 튕기지 않게)")
			var goal := Vector2(c.x * 32 + 16, c.y * 32 + 16)
			t.ok(not m.path(start, goal).is_empty() or m.tile_of(start) == c, "%s 첫 표지에서 출구 %s까지 길" % [id, str(c)])
	for m in maps.values():
		m.free()


func test_solid_and_props(t) -> void:
	var m := _load("V-08")
	t.ok(m.is_solid(Vector2i(0, 0)), "맵 귀퉁이 벽")
	t.ok(m.is_solid(Vector2i(-1, 5)) and m.is_solid(Vector2i(40, 5)), "맵 밖은 막힘")
	t.ok(m.is_solid(Vector2i(6, 4)) and m.is_solid(Vector2i(6, 5)), "분만 침대 발 칸(1×2)이 막힘")
	t.eq(m.set_prop_state(Vector2i(6, 5), "occupied"), "birth_bed", "침대 → 누운 윤정인·아기 그림")
	t.eq(m.set_prop_state(Vector2i(8, 5), "lit"), "terminal_cart", "표지 칸 위의 등록 단말 → 6번 칸 점등")
	t.eq(m.set_prop_state(Vector2i(20, 20), "lit"), "", "상태 그림이 없는 곳")
	t.ok(not m.is_solid(Vector2i(7, 12)), "의무실 문 자리는 뚫림")
	t.ok(m.texts.has(Vector2i(8, 4)), "등록 단말 조사 글")
	var hit := m.move_circle(Vector2(208, 216), Vector2(208, 170), 9.6)
	t.ok(hit.y >= 200.0, "분만대(소품 발 칸)에 막힘: %s" % str(hit))
	t.ok(m.objects.get_child_count() > 40, "소품·문·문패가 물건 층에 있다")
	m.free()


func test_doors(t) -> void:
	var m := _load("V-08")
	var d: Dictionary = m.doors[0]
	t.eq(d["is_open"], false, "처음엔 닫힘")
	var who := Node2D.new()
	who.position = Vector2(int(d["x"]) * 32 + 16, (int(d["y"]) + 2) * 32 + 16)
	m.actors.append(who)
	m._process(0.016)
	t.eq(d["is_open"], true, "가까이 오면 열림")
	t.eq((d["node"].texture as AtlasTexture).region, d["open"], "열린 그림")
	who.position = Vector2(30 * 32, 25 * 32)
	m._process(0.016)
	t.eq(d["is_open"], false, "멀어지면 닫힘")
	who.free()
	var v09 := _load("V-09")
	var locked := v09.doors.filter(func(x): return x["locked"])
	t.eq(locked.size(), 1, "보안과 무기고 문은 잠김")
	t.ok(v09.is_solid(Vector2i(int(locked[0]["x"]), int(locked[0]["y"]) + 1)), "잠긴 문은 막힘")
	t.eq(v09.texts.get(Vector2i(int(locked[0]["x"]), int(locked[0]["y"]) + 1), ""), "잠겨 있다.", "잠긴 문 조사 글")
	v09.free()
	m.free()


func test_follow_rules(t) -> void:
	t.ok(NpcRoutine.arrived(Vector2(240, 464), Vector2(242, 465)), "허용 안(가로 3·세로 2)")
	t.ok(not NpcRoutine.arrived(Vector2(240, 460), Vector2(240, 464)), "세로 4 어긋남은 아직")
	t.eq(NpcRoutine.step_dir(Vector2(240, 460), Vector2(272, 464)), Vector2(1, 1), "두 축 다 어긋나면 대각선")
	t.eq(NpcRoutine.step_dir(Vector2(270, 463), Vector2(272, 464)), Vector2(0, 0), "허용 안이면 멈춤")
	t.eq(NpcRoutine.step_dir(Vector2(240, 463), Vector2(272, 464)), Vector2(1, 0), "세로는 맞음 → 가로만")
	var m := _load("V-08")
	var p := NpcRoutine.with_start(m, Vector2(246, 456), Vector2(18 * 32 + 16, 15 * 32 + 16))
	t.eq(p[0], Vector2(246, 464), "가로로 갈 때 세로 어긋남만 먼저 바로잡는다")
	var q := NpcRoutine.with_start(m, Vector2(306, 464), Vector2(18 * 32 + 16, 14 * 32 + 16))
	t.eq(q[0], Vector2(336, 464), "진행 방향 어긋남(가로 2)은 그대로 — 되돌아가지 않는다")
	m.free()


## 맵마다 인물 일과를 실제로 걸려 본다: 정해진 시간 안에 모든 일과 지점을 한 바퀴 돈다(막힘·맴돌기 없음)
func test_routines_walk(t) -> void:
	for step in [1.0 / 60.0, 0.1]:                                     # 0.1초 프레임(녹화·느린 기기)에서도 맴돌지 않는다
		_routines_walk(t, step)


func _routines_walk(t, step: float) -> void:
	var cast: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/story_cast.json"))["sheets"]
	var total := 0
	for id in S07:
		var m := _load(id)
		for n in m.data["npcs"]:
			if n["route"].is_empty() or not cast.has(n["id"]):
				continue
			var a := Actor.new()
			a.setup(cast[n["id"]], Vector2(int(n["x"]) * 32 + 16, int(n["y"]) * 32 + 16), m)
			a.mode = "walk"
			var r := NpcRoutine.new(a, m, n["route"])
			for p in n["route"]:
				p[3] = 0.05                                          # 머무는 시간은 줄여서 걷기만 본다
			var seen := {}
			var steps := 0
			while seen.size() < n["route"].size() and steps * step < 120.0:
				r.tick(step, Vector2(-999, -999))
				steps += 1
				if r.wait_t > 0.0:
					seen[r.idx] = true
			t.eq(seen.size(), n["route"].size(), "%s %s 일과 지점 %d곳 모두 도착(%.1f초, 프레임 %.3f)" % [id, n["id"],
				n["route"].size(), steps * step, step])
			total += 1
			a.free()
		m.free()
	t.ok(total >= 15, "일과 인물 %d명" % total)


## 컷신 move: 문에서 침대 옆까지 소품(아기 바구니·진찰대)을 돌아 걸어간다 — 곧장 걸으면 끼어 제자리에서 버둥거렸다.
## 프레임 길이 1/60초와 0.1초(녹화 10fps) 둘 다: 긴 프레임에서 칸 가운데를 지나쳤다 되돌아오기를 되풀이했다
func test_cutscene_move_paths(t) -> void:
	for step in [1.0 / 60.0, 0.1]:
		_move_once(t, step)


func _move_once(t, step: float) -> void:
	var m := _load("V-08")
	var ev := EventRunner.new()
	ev.setup(m, "V-08", Camera2D.new())
	var done := [false]
	ev.run("show", ["C-024", "door", "N"], func() -> void: pass)
	t.ok(ev.actors.has("C-024"), "방금례 무대에 섬")
	ev.run("move", ["C-024", "bed_side"], func() -> void: done[0] = true)
	var secs := 0.0
	while not done[0] and secs < 25.0:
		ev._process(step)
		secs += step
	var a: Actor = ev.actors["C-024"]
	t.ok(done[0] and secs < 8.0, "프레임 %.3f초: 침대 옆에 %.1f초 만에 도착(8초 안)" % [step, secs])
	t.ok(a.loco.render.distance_to(m.mark_pos("bed_side")) < 6.0, "표지 자리에 섰다: %s" % str(a.loco.render))
	a.free()
	ev.free()
	m.free()
