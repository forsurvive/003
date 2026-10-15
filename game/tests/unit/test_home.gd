## 거처(단계 1-8b, SD-15 §7.2 · §7.5 · §7.7 · SD-11 §11.5): 봉천 옥탑방 가구·보관함 조건 · 보관함은 비어서 시작해 다시 차지 않는다 ·
## 열쇠 증표 · 숙면 경험치 · 원고 장면.
extends RefCounted


func _state() -> StoryState:
	var st := StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("GAME_DAY", 3)
	return st


func _map(st: StoryState) -> InteriorMap:
	var m := InteriorMap.new()
	m.load_map("B-01", st)
	return m


func _names(m: InteriorMap) -> Array:
	return m.props.map(func(p): return str(p["name"]))


func test_home_map_by_state(t) -> void:
	var st := _state()
	var m := _map(st)
	t.ok(not _names(m).has("keepsake_case") and not _names(m).has("bandaji"), "열쇠 전: 거처 가구가 없다(빌린 침대 방)")
	t.ok(not InteriorMap._cond_ok(str(m.boxes[Vector2i(20, 12)].get("cond", "")), st), "열쇠 전: 궤짝은 열리지 않는다")
	m.free()
	st.vars.set_v("HOME_BC", 1)
	m = _map(st)
	for nm in ["keepsake_case", "bandaji", "home_locker", "yo_bed"]:
		t.ok(_names(m).has(nm), "거처: %s" % nm)
	for c in [Vector2i(20, 12), Vector2i(21, 12), Vector2i(24, 6)]:
		var b: Dictionary = m.boxes.get(c, {})
		t.eq(str(b.get("kind", "")), "home", "보관함 칸 %s" % str(c))
		t.eq(str(b.get("owner", "")), "PC", "내 보관함 %s" % str(c))
		t.ok(InteriorMap._cond_ok(str(b.get("cond", "")), st), "거처: 열린다 %s" % str(c))
		t.ok(m.is_solid(c), "가구가 길을 막는다 %s" % str(c))
	m.free()
	st.vars.set_v("HOME_BC", 2)
	m = _map(st)
	t.ok(_names(m).has("bandaji"), "압류: 가구는 그대로 있다")
	t.ok(not InteriorMap._cond_ok(str(m.boxes[Vector2i(24, 6)].get("cond", "")), st), "압류: 사물함이 닫힌다")
	m.free()


func test_home_box_never_restocks(t) -> void:
	var st := _state()
	st.vars.set_v("HOME_BC", 1)
	var b := {"x": 20, "y": 12, "w": 2, "h": 1, "kind": "home", "owner": "PC", "lock": 0, "name": "반닫이 궤짝", "cond": "HOME_BC == 1"}
	var c := Loot.contents(st, "B-01", b, "R01")
	t.ok((c["items"] as Dictionary).is_empty(), "새 거처 보관함은 비어 있다")
	for d in [10, 40, 200]:
		st.vars.set_v("GAME_DAY", 3 + d)
		c = Loot.contents(st, "B-01", b, "R01")
		t.ok((c["items"] as Dictionary).is_empty(), "%d일 뒤에도 저절로 차지 않는다" % d)
	c["items"]["I-002"] = 4
	st.vars.set_v("GAME_DAY", 500)
	t.eq(int(Loot.contents(st, "B-01", b, "R01")["items"].get("I-002", 0)), 4, "넣어 둔 물건은 그대로")
	t.ok(not Loot.owned(b), "내 보관함: 절도 판정 없음")


func test_home_key_token(t) -> void:
	var p := "res://data/items_tokens.json"
	t.ok(FileAccess.file_exists(p), "세력 증표 자료")
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(p))
	var k: Dictionary = d.get("M-136-BC", {})
	t.eq(str(k.get("name", "")), "봉천 계단 열쇠", "M-136 봉천 차분")
	t.ok(bool(k.get("no_sell", false)) and float(k.get("weight", 1.0)) == 0.0, "증표: 무게 0 · 판매 불가")
	t.ok(d.has("M-136") and d.has("M-120"), "SD-13 §7.4.2 증표 표 전체")


func test_home_well_rested_xp(t) -> void:
	var st := _state()
	var x0 := int(st.vars.get_v("PC_XP"))
	st.call_fn("xp", [100])
	t.eq(int(st.vars.get_v("PC_XP")) - x0, 100, "숙면 없이 100")
	st.vars.set_v("WELL_RESTED", 99999)
	x0 = int(st.vars.get_v("PC_XP"))
	st.call_fn("xp", [100])
	t.eq(int(st.vars.get_v("PC_XP")) - x0, 110, "숙면 중 +10%")


func test_home_scenes(t) -> void:
	for sc in ["HOME_BC_KEY", "HOME_BC_WARN", "HOME_BC_SEIZED", "HOME_BC_BACK"]:
		t.ok(FileAccess.file_exists("res://data/dialogue/%s.json" % sc), "원고 장면 " + sc)
	var key := FileAccess.get_file_as_string("res://data/dialogue/HOME_BC_KEY.json")
	t.ok(key.contains("빌린 침대였지. 이제 빌린 거 아니다.") and key.contains("M-136-BC"), "열쇠 장면: SD-04a §2.5 대사와 열쇠")
