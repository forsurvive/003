## 1-13j2 관악 비탈 바위 틈 깡통(재미 검수 반영 — 계획 docs/seoul-fallout/_plans/1-13j2_wander_tin_plan.md): 돌탑 · 깡통 자리 · 손댐(비움 1 · 남김 2) ·
## 이틀 뒤 주인이 다녀감(멀리 있을 때만 — 3 '고맙다' 남긴 것을 가져감 · 4 '누가 가져갔냐') · 다시 꺼내면 다시 정함 · 그 뒤로는 그대로.
extends RefCounted


func _host() -> Array:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 2)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 25.  10:00"
	var w := WanderTin.new()
	w.setup(h)
	h.enter("W", "@950,1461")
	return [h, st, w]


func _far(h: InteriorHost) -> void:
	h.player.loco.logical = Vector2(900, 1380) * 32.0


func test_wander_tin_spot(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var w: WanderTin = a[2]
	var b := w._tin()
	t.ok(not b.is_empty(), "돌탑 칸(949,1459)에 깡통 용기")
	var c := h.box_contents(b)
	var caps := int(c["items"].get("M-001", 0))
	t.ok(caps >= 20 and caps <= 25 and c["items"].size() == 1, "캡 20~25만(아이템 없음): %d" % caps)
	var cairn := false
	for p in h.map.props:
		if str(p["name"]) == "wander_cairn" and int(p["x"]) == WanderTin.TILE.x and int(p["y"]) == WanderTin.TILE.y:
			cairn = true
	t.ok(cairn, "그 칸에 돌탑 소품(아무 바위와 다른 그림)")
	w._on_box(b, c)
	t.eq(w.state(), 0, "열어 보기만 하고 닫으면 그대로")
	h.player.loco.logical = (Vector2(WanderTin.TILE) + Vector2(0.5, 1.5)) * 32.0      # 돌탑 바로 아래 칸에서 위를 본다
	h.player.loco.facing = 6
	t.ok(w._pre(), "돌탑을 누르면 진행기가 먼저 받는다")
	t.ok(h.box.active, "쪽지 글을 먼저 띄운다(용기보다 먼저)")
	t.ok(not w._pre(), "본 글은 다시 띄우지 않는다 — 곧장 용기")
	h.free()


func test_wander_tin_emptied_then_owner(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var w: WanderTin = a[2]
	var b := w._tin()
	var c := h.box_contents(b)
	c["items"].erase("M-001")
	c["taken"] = 1
	w._on_box(b, c)
	t.eq(w.state(), 1, "다 꺼냄 = 비움(1)")
	t.eq(int(st.vars.get_v("WT_DAY")), 2, "처음 손댄 날")
	st.vars.set_v("GAME_DAY", 4)
	w._owner_back()
	t.eq(w.state(), 1, "이틀이 지나도 돌탑 30칸 안에 서 있으면 주인은 오지 않는다")
	_far(h)
	st.vars.set_v("GAME_DAY", 3)
	w._owner_back()
	t.eq(w.state(), 1, "이틀이 안 됐으면 그대로")
	st.vars.set_v("GAME_DAY", 4)
	w._owner_back()
	t.eq(w.state(), 4, "멀리 있고 이틀 — '누가 가져갔냐'(4)")
	c["items"]["M-047"] = 1
	w._on_box(b, c)
	t.eq(w.state(), 4, "주인이 다녀간 뒤엔 넣어도 그대로(한 번뿐)")
	h.free()


func test_wander_tin_left_then_thanks(t) -> void:
	var a := _host()
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var w: WanderTin = a[2]
	var b := w._tin()
	var c := h.box_contents(b)
	c["items"]["M-001"] = 10
	c["taken"] = 1
	w._on_box(b, c)
	t.eq(w.state(), 2, "캡 반만 꺼냄 = 남김(2)")
	c["items"].erase("M-001")
	w._on_box(b, c)
	t.eq(w.state(), 1, "주인이 오기 전에 다시 다 꺼내면 비움(1)으로 다시 정한다")
	c["items"]["M-047"] = 2
	w._on_box(b, c)
	t.eq(w.state(), 2, "내 물건을 넣고 닫으면 남김(2)")
	_far(h)
	st.vars.set_v("GAME_DAY", 4)
	w._owner_back()
	t.eq(w.state(), 3, "이틀 뒤 멀리 — '고맙다'(3)")
	t.eq(c["items"].size(), 0, "남긴 것은 주인이 가져갔다")
	t.eq(WanderTin.PROP_STATE[3], "restacked", "돌탑은 다시 쌓인 그림")
	h.free()
