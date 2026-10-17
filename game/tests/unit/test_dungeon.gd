## 던전 체계(1-D0, SD-14 §11.3 · 설계안 docs/seoul-fallout/_plans/1-D_dungeons_plan.md): 쓰러뜨린 맵 자리는 72게임시간(3일) 비어 있다 ·
## 우두머리는 다시 서지 않는다 · 기록은 저장(st.boxes)에 남는다
extends RefCounted


func test_kill_respawn(t) -> void:
	var h := InteriorHost.new()
	h._ready()
	h.body = "adult"
	h.st.quests.set_stage("MQ-P4", 100)
	h.st.vars.set_v("GAME_DAY", 5)
	var mid := ""
	for f in InteriorMap.gen_ids():
		var m: Dictionary = InteriorMap.read_data(f)
		if (m["enemies"] as Array).size() >= 2:
			mid = str(f)
			break
	t.ok(mid != "", "적이 둘 이상인 생성 실내")
	h.enter(mid, "from_W")
	var n0 := h.combat.alive_enemies()
	var e: Enemy = h.combat.enemies[0]
	e.cmb.last_by = "player"
	e.cmb.take({"hp": 99999.0}, e.loco.logical)
	t.eq(h.combat.alive_enemies(), n0 - 1, "하나를 쓰러뜨렸다")
	h.enter(mid, "from_W")
	t.eq(h.combat.alive_enemies(), n0 - 1, "다시 들어가도 쓰러뜨린 자리는 비어 있다")
	h.st.vars.set_v("GAME_DAY", 7)
	h.enter(mid, "from_W")
	t.eq(h.combat.alive_enemies(), n0 - 1, "이틀 뒤에도 비어 있다")
	h.st.vars.set_v("GAME_DAY", 8)
	h.enter(mid, "from_W")
	t.eq(h.combat.alive_enemies(), n0, "사흘(72게임시간)이 지나면 다시 선다(SD-14 §11.3)")
	h.st.boxes["kill:X:1,1"] = {"day": 1, "boss": true}
	h.st.vars.set_v("GAME_DAY", 99)
	t.ok(not InteriorCombat.respawn_due(h.st, "kill:X:1,1"), "우두머리는 다시 서지 않는다")
	h.free()


func _db_host() -> InteriorHost:
	var h := InteriorHost.new()
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 25.  14:00"
	h.st.quests.set_stage("MQ-P4", 100)
	h.st.vars.set_v("GAME_DAY", 10)
	h.st.vars.set_v("UQ71_SQ", 9)                                       # 분대 없는 판(던전 체계만 본다)
	return h


func _kill(h: InteriorHost, e: Enemy) -> void:
	e.cmb.last_by = "player"
	e.cmb.take({"hp": 99999.0}, e.loco.logical)


## 던전 표(dungeons.json): 대방 지하차도 = DG-DB · 맵 DB-01 · 우두머리 하나 · 층 표시 · 정리 변수
func test_dungeon_table(t) -> void:
	var d := Dungeon.of_map("DB-01")
	t.eq(str(d.get("id", "")), "DG-DB", "DB-01은 대방 지하차도 던전")
	t.eq((d["bosses"] as Array).size(), 1, "우두머리 하나(큰집게)")
	t.eq(Dungeon.floor_of("DB-01"), "지하", "층 표시")
	var h := _db_host()
	t.eq(int(h.st.vars.get_v("DG_DB")), 0, "정리 변수는 엔진이 선언한다(0 손 안 댐)")
	h.enter("DB-01", "from_N")
	t.ok(h._place_name().ends_with("대방 지하차도 · 지하"), "HUD 장소 이름 뒤에 층(%s)" % h._place_name())
	h.free()


## 우두머리를 쓰러뜨리면 정리(DG_DB 1) → 쓰러뜨린 자리는 사흘이 지나도 비어 있다 → 30일 뒤 하루 한 번 20%로 다른 무리(사람 먼저)가 든다 →
## 그 무리를 몰아내면 다시 정리
func test_dungeon_clear_refill(t) -> void:
	var h := _db_host()
	var msgs: Array = []
	h.combat.message.connect(func(m): msgs.append(m))
	h.enter("DB-01", "from_N")
	var boss: Enemy = null
	var other: Enemy = null
	for e in h.combat.enemies:
		if e.has_meta("boss"):
			boss = e
		elif other == null:
			other = e
	t.ok(boss != null and other != null, "우두머리와 졸개가 선다")
	_kill(h, other)
	t.eq(int(h.st.vars.get_v("DG_DB")), 0, "졸개만으로는 정리되지 않는다")
	_kill(h, boss)
	t.eq(int(h.st.vars.get_v("DG_DB")), 1, "우두머리를 쓰러뜨리면 정리")
	t.ok(msgs.any(func(m): return str(m).contains("정리했다")), "정리 알림")
	var n1 := h.combat.alive_enemies()
	h.st.vars.set_v("GAME_DAY", 20)
	h.enter("DB-01", "from_N")
	t.eq(h.combat.alive_enemies(), n1, "정리한 던전은 사흘이 지나도 쓰러뜨린 자리가 비어 있다")
	h.st.vars.set_v("GAME_DAY", 39)
	h.enter("DB-01", "from_N")
	t.eq(int(h.st.vars.get_v("DG_DB")), 1, "30일이 안 됐으면 아무도 들지 않는다")
	var day := 40
	while int(h.st.vars.get_v("DG_DB")) == 1 and day < 200:
		h.st.vars.set_v("GAME_DAY", day)
		h.enter("DB-01", "from_N")
		h.enter("DB-01", "from_S")                                     # 같은 날 두 번 들어도 한 번만 굴린다
		day += 1
	t.eq(int(h.st.vars.get_v("DG_DB")), 2, "30일 뒤 언젠가 다른 무리가 든다(%d일째)" % (day - 1))
	t.ok(day - 1 > 40, "날마다 20% — 첫날 바로 들지는 않는다(씨앗 고정)")
	var rec: Dictionary = h.st.boxes.get("dg_refill:DG-DB", {})
	var newcomers: Array = h.combat.enemies.filter(func(e): return str(e.get_meta("spawn_key", "")).begins_with("refill:"))
	t.eq(newcomers.size(), (rec["ids"] as Array).size(), "재입주 무리가 첫 맵에 선다(%s)" % str(rec.get("kind", "")))
	for e in newcomers:
		_kill(h, e)
	t.eq(int(h.st.vars.get_v("DG_DB")), 1, "몰아내면 다시 정리")
	t.ok(not h.st.boxes.has("dg_refill:DG-DB"), "재입주 기록은 지운다(다음 무리는 새로)")
	h.free()


## 두 입구(1-D): 월드 문 둘(북 · 남)이 같은 맵의 다른 표지로 들고, 맵 출구 'L-ID>표지'는 그 문 앞으로 나온다
func test_dungeon_two_mouths(t) -> void:
	PlaceLog.load_db()
	var mouths: Dictionary = {}
	for d in PlaceLog.doors:
		if str(d.get("to", "")) == "DB-01":
			mouths[str(d["mark"])] = d
	t.ok(mouths.has("from_N") and mouths.has("from_S"), "월드 입구 둘")
	var h := _db_host()
	for mk in ["from_N", "from_S"]:
		var d: Dictionary = mouths[mk]
		h.enter("W", "L-R02-17>" + mk)
		var tile: Vector2i = h.map.tile_of(h.player.loco.logical)
		t.eq(tile, Vector2i(int(d["at"][0]), int(d["at"][1]) + 1), "%s 출구로 나오면 그 입구 앞" % mk)
	var m: Dictionary = InteriorMap.read_data("DB-01")
	var outs := {}
	for e in m["exits"]:
		outs[str(e["mark"])] = true
	t.ok(outs.has("L-R02-17>from_N") and outs.has("L-R02-17>from_S"), "맵 양 끝 출구가 각 입구로")
	h.free()
