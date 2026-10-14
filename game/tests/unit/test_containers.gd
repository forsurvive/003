## 단계 0-9 용기·절도(SD-12 §7.3·§9.2·§11.1): 표로 굴린 내용물(결정적·시대별), 맵 배치(주인·자물쇠), 2단 창 옮기기,
## 소유 용기에서 꺼내면 절도(열 때마다 한 번 카르마 −5, [장물] 수, 돌려놓으면 줄어든다), 내 것·주인 없는 것은 절도가 아니다.
extends RefCounted


func _state(year_stage := 10) -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3"]:
		st.quests.set_stage(q, 100)
	st.quests.set_stage("MQ-P4", year_stage)
	return st


func _box(owner: String, kind := "locker") -> Dictionary:
	return {"x": 3, "y": 4, "w": 1, "h": 1, "kind": kind, "owner": owner, "lock": 0, "name": "", "cond": ""}


func test_box_loot_roll(t) -> void:
	var a := Loot.roll("crate", "V-04:2,20@2277")
	var b := Loot.roll("crate", "V-04:2,20@2277")
	t.eq(a, b, "같은 열쇠면 같은 내용물")
	var safe := Loot.roll("safe", "V-02:47,3@2277")
	t.ok(int(safe.get("M-002", 0)) >= 12, "금고는 늘 돈이 든다")
	var kinds := 0
	for k in ["locker", "school_locker", "aid", "cabinet", "desk", "crate", "pantry", "ammo", "safe"]:
		kinds += 1 if Loot.kind_name(k) != k else 0
	t.eq(kinds, 9, "용기 종류 9개에 이름이 있다")
	var st := _state()
	var bx := _box("S7", "crate")
	var c := Loot.contents(st, "V-04", bx)
	c["items"]["M-010"] = 99
	t.eq(int(Loot.contents(st, "V-04", bx)["items"]["M-010"]), 99, "한 번 정해진 내용물은 이야기 상태에 남는다")
	t.ok(Loot.key("V-04", bx, 2277) != Loot.key("V-04", bx, 2268), "시대마다 따로 채워진다")
	t.ok(Loot.owned(_box("S7")) and Loot.owned(_box("C-001")), "공용·인물 소유는 남의 것")
	t.ok(not Loot.owned(_box("PC")) and not Loot.owned(_box("")), "내 것·주인 없는 것은 아니다")


func test_box_placement(t) -> void:
	var st := _state()
	var total := 0
	var owners := {}
	for id in ["V-00", "V-01", "V-02", "V-03", "V-04", "V-05", "V-06", "V-07", "V-08", "V-09", "V-10", "V-11"]:
		var m := InteriorMap.new()
		m.load_map(id, st)
		for b in m.data["boxes"]:
			total += 1
			owners[str(b["owner"])] = true
			t.ok(m.boxes.has(Vector2i(int(b["x"]), int(b["y"]))), "%s 용기 칸이 조사 표에 있다" % id)
		m.free()
	t.ok(total >= 40, "볼트 곳곳에 용기 40개 이상(%d)" % total)
	t.ok(owners.has("") and owners.has("PC") and owners.has("S7") and owners.has("C-022"), "주인 없음·내 것·공용·인물 소유가 섞여 있다")
	var m4 := InteriorMap.new()
	m4.load_map("V-04", st)
	var mine: Dictionary = m4.boxes.get(Vector2i(20, 3), {})
	t.eq(str(mine.get("owner", "")), "PC", "A-07 사물함은 내 것")
	m4.free()


func test_box_take_and_theft(t) -> void:
	var st := _state()
	var host := InteriorHost.new()
	host.st = st
	var stolen_first: Array = []
	var bx := _box("N-R01-024")
	var c := {"items": {"M-070": 2, "M-249": 1}, "opened": 0, "taken": 0}
	var scr := ContainerScreen.new().setup(st, bx, c, {}, "고나래", 150.0)
	scr.stole.connect(func(first: bool) -> void:
		stolen_first.append(first)
		host._on_stole(first, bx))
	t.eq(int(c["opened"]), 1, "열 때마다 연 횟수가 오른다")
	scr.side = 1
	scr.move_sel()
	scr.take_all()
	t.eq(int(st.items.get("M-070", 0)), 2, "꺼낸 물건이 소지품에")
	t.eq(int(st.items.get("M-249", 0)), 1, "모두 가져가기")
	t.ok(c["items"].is_empty(), "용기는 비었다")
	t.eq(stolen_first, [true, false, false], "절도 신호: 꺼낼 때마다, first는 이 용기의 첫 절도만")
	t.eq(int(st.vars.get_v("V_KARMA")), -5, "남의 사물함에서 꺼내면 카르마 −5(한 번)")
	t.eq(int(st.stolen.get("M-070", 0)), 2, "장물 수")
	scr.side = 0
	scr.sel[0] = scr._list(0).find("M-070")
	scr.move_sel(true)
	t.eq(int(st.stolen.get("M-070", 0)), 0, "돌려놓으면 장물이 아니다")
	t.eq(int(c["items"].get("M-070", 0)), 2, "돌려놓은 물건은 용기에")
	scr.free()
	var scr2 := ContainerScreen.new().setup(st, bx, c, {}, "고나래", 150.0)
	scr2.stole.connect(func(first: bool) -> void: host._on_stole(first, bx))
	scr2.side = 1
	scr2.take_all()
	t.eq(int(st.vars.get_v("V_KARMA")), -5, "같은 용기는 하루(시대) 한 번만 판정(SD-10 §6.3 반복 루프 차단)")
	scr2.free()
	var other := {"items": {"M-002": 3}, "opened": 0, "taken": 0}
	var scr4 := ContainerScreen.new().setup(st, _box("S7", "cabinet"), other, {}, "볼트 S-07 공용", 150.0)
	scr4.stole.connect(func(first: bool) -> void: host._on_stole(first, _box("S7", "cabinet")))
	scr4.side = 1
	scr4.take_all()
	t.eq(int(st.vars.get_v("V_KARMA")), -10, "다른 용기는 따로 −5")
	scr4.free()
	var mine := {"items": {"M-070": 1}, "opened": 0, "taken": 0}
	var scr3 := ContainerScreen.new().setup(st, _box("PC"), mine, {}, "", 150.0)
	var fired := [false]
	scr3.stole.connect(func(_f: bool) -> void: fired[0] = true)
	scr3.side = 1
	scr3.take_all()
	t.ok(not fired[0], "내 사물함은 절도가 아니다")
	t.eq(int(st.vars.get_v("V_KARMA")), -10, "카르마 그대로")
	scr3.free()
	host.free()


func test_box_locked(t) -> void:
	var st := _state(40)
	var host := InteriorHost.new()
	host.st = st
	host.map = InteriorMap.new()
	host.map.load_map("V-09", st)
	var safe: Dictionary = host.map.boxes.get(Vector2i(18, 9), {})
	t.eq(int(safe.get("lock", 0)), 75, "보안부장 금고: 자물쇠 75")
	t.ok(host.box_locked(safe), "처음엔 잠겨 있다")
	t.eq(host.box_owner_label(safe), "도경철", "주인 이름")
	Loot.contents(st, "V-09", safe)["unlocked"] = true
	t.ok(not host.box_locked(safe), "따고 나면 열린 채로 남는다")
	var cab: Dictionary = host.map.boxes.get(Vector2i(1, 3), {})
	t.eq(host.box_owner_label(cab), "볼트 S-07 공용", "공용 용기 이름")
	host.map.free()
	host.free()


func test_box_witness(t) -> void:
	var st := _state(40)
	var host := InteriorHost.new()
	host.st = st
	host.map = InteriorMap.new()
	host.map.load_map("V-04", st)
	host.player = Actor.new()
	host.player.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), Vector2(20 * 32 + 16, 4 * 32 + 16), host.map)
	var a := Actor.new()
	a.setup("st_look_k1_s3_hr00_h1_t01_0_pf11_hd00_ey00", Vector2(17 * 32 + 16, 4 * 32 + 16), host.map)
	a.loco.facing = 0                                                     # 동쪽(주인공 쪽)을 본다
	host.npcs = [{"id": "N-R01-024", "actor": a, "routine": null, "bark": ""}]
	t.eq(host.theft_witness(), "N-R01-024", "같은 방에서 이쪽을 보는 주민은 목격자")
	a.loco.facing = 4
	t.eq(host.theft_witness(), "", "등지고 있으면 못 본다")
	a.loco.place(Vector2(20 * 32 + 16, 10 * 32 + 16))
	a.loco.facing = 6
	t.eq(host.theft_witness(), "", "벽 너머 복도에서는 못 본다")
	host.player.loco.facing = 6
	t.ok(host.box_prompt().begins_with("(E) 열기  A-07 내 사물함"), "사물함 앞 안내: " + host.box_prompt())
	a.free()
	host.player.free()
	host.map.free()
	host.free()
