## 맵 변환기 자동 용기(AUTO_BOX — 사용자 지시 2026-10-22): 맥락상 안에 물건이 있을 소품은 파밍 가능 · 원고 용기 우선 · 배낭 같은 '사라지는' 용기는 다 꺼내면 소품째 사라지고 다시 들어와도 없다.
extends RefCounted


func _host(map_id: String, mark: String) -> Array:
	var st := StoryState.new()
	st.load_data()
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 5)
	var h := InteriorHost.new()
	h.st = st
	h._ready()
	h.body = "adult"
	h.date_text = "2277. 10. 28.  10:00"
	h.enter(map_id, mark)
	return [h, st]


func _box_at(h: InteriorHost, c: Vector2i) -> Dictionary:
	return h.map.boxes.get(c, {})


func _prop_at(h: InteriorHost, c: Vector2i) -> String:
	for p in h.map.props:
		if int(p["x"]) == c.x and int(p["y"]) == c.y:
			return str(p["name"])
	return ""


func test_auto_box_backpack_vanish(t) -> void:
	var a := _host("K-02", "from_W")
	var h: InteriorHost = a[0]
	var st: StoryState = a[1]
	var c := Vector2i(9, 7)
	t.eq(_prop_at(h, c), "backpack", "K-02 (9,7) 배낭 소품")
	var b0 := _box_at(h, Vector2i(4, 6))
	t.ok(not b0.is_empty() and not bool(b0.get("auto", false)) and bool(b0.get("vanish", false)), "원고 용기(4,6 버리고 간 가방)도 배낭 위면 사라짐")
	var b := _box_at(h, c)
	t.ok(not b.is_empty() and str(b.get("kind", "")) == "bag" and bool(b.get("vanish", false)), "배낭 용기 bag · 사라짐")
	var cont := h.box_contents(b)
	cont["items"] = {}
	cont["taken"] = 1
	h._vanish_check(b, cont)
	t.ok(bool(cont.get("gone", false)), "다 꺼냄 — gone")
	t.eq(_prop_at(h, c), "", "소품이 그 자리에서 사라짐")
	t.ok(_box_at(h, c).is_empty(), "용기도 사라짐")
	h.enter("K-02", "from_W")
	t.eq(_prop_at(h, c), "", "다시 들어와도 없음(기록)")
	t.ok(_box_at(h, c).is_empty(), "용기도 없음")


func test_auto_box_rules(t) -> void:
	var a := _host("K-43", "from_W")
	var h: InteriorHost = a[0]
	var b := _box_at(h, Vector2i(14, 3))
	t.ok(not b.is_empty() and str(b.get("kind", "")) == "desk" and bool(b.get("auto", false)), "권성민 책상 — 자동 desk 용기(원고 용기 없음)")
	var g := _box_at(h, Vector2i(8, 8))
	t.ok(not g.is_empty() and str(g.get("kind", "")) == "gift" and not bool(g.get("auto", false)), "원고 용기(공물 드럼통)는 그대로 — 자동이 덮지 않음")
	t.ok(_box_at(h, Vector2i(16, 3)).is_empty(), "장면이 달린 조사 글 칸(스탠드)엔 용기를 더하지 않음")
	var k := _host("K-41", "from_roof")
	var hk: InteriorHost = k[0]
	var d := _box_at(hk, Vector2i(6, 4))
	t.ok(not d.is_empty() and str(d.get("owner", "")) == "N-R01-060", "주인 있는 용기(금고) 가까이의 두목 책상 — 주인 상속(절도)")
