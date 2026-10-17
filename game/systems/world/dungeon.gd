class_name Dungeon
extends RefCounted
## 던전(1-D0, data/dungeons.json ← script/world/dungeons.txt · 1-D 계획 §1 · SD-14 §11.3 소굴 정리).
## 정리 변수 DG_<접미>: 0 손 안 댐 · 1 정리 · 2 다시 들어섬(재입주 무리). _DAY 정리 · 재입주 날 · _ROLL 재입주를 굴린 날.
## 사실 한 곳(SD-20 P1): 던전의 상태는 이 변수 하나 — 맵 풍경 · 소문 · 정착지 바크는 모두 이것을 읽는다.

static var db: Dictionary = {}
static var by_map: Dictionary = {}


static func load_db() -> void:
	if not db.is_empty():
		return
	var f := FileAccess.open("res://data/dungeons.json", FileAccess.READ)
	if f == null:
		return
	var d: Dictionary = JSON.parse_string(f.get_as_text())
	db = d.get("dungeons", {})
	by_map = d.get("by_map", {})


static func of_map(map_id: String) -> Dictionary:
	load_db()
	return db.get(str(by_map.get(map_id, "")), {})


static func state(st: StoryState, d: Dictionary) -> int:
	return int(st.vars.get_v(str(d["var"])))


## HUD 장소 이름 뒤에 붙는 층(예: '대방 지하차도 · 지하')
static func floor_of(map_id: String) -> String:
	for m in of_map(map_id).get("maps", []):
		if str(m["id"]) == map_id:
			return str(m["floor"])
	return ""


## 깊이 z(SD-09f §3.5: −3 이하 라디오 잡음 · −4 끊김). 던전이 아니면 0
static func depth_of(map_id: String) -> int:
	for m in of_map(map_id).get("maps", []):
		if str(m["id"]) == map_id:
			return int(m["z"])
	return 0


## 이 맵의 처치 기록이 다시 서지 않는가(정리된 던전 — 쓰러뜨린 자리는 비어 있다, 재입주는 따로)
static func keeps_dead(st: StoryState, map_id: String) -> bool:
	var d := of_map(map_id)
	return not d.is_empty() and state(st, d) >= 1


## 우두머리 처치 · 비전투 해법 뒤: 정리 판정. 정리되면 알림 문구, 아니면 ""
static func check_clear(st: StoryState, map_id: String) -> String:
	var d := of_map(map_id)
	if d.is_empty() or state(st, d) != 0:
		return ""
	var bosses: Array = d.get("bosses", [])
	var done := not bosses.is_empty()
	for k in bosses:
		if not st.boxes.has(str(k)):
			done = false
	if not done and str(d.get("clear", "")) != "":
		done = InteriorMap._cond_ok(str(d["clear"]), st)
	if not done:
		return ""
	st.vars.set_v(str(d["var"]), 1)
	st.vars.set_v(str(d["var"]) + "_DAY", int(st.vars.get_v("GAME_DAY")))
	return "%s — 정리했다. 한동안 조용할 것이다." % str(d["name"])


## 맵에 들 때: 재입주 굴리기(정리 뒤 refill.days 지나면 하루 한 번 pct% — 사람 먼저 70%) · 지금 서 있어야 할 재입주 무리 줄
static func refill_rows(st: StoryState, map_id: String, rng: RandomNumberGenerator) -> Array:
	var d := of_map(map_id)
	if d.is_empty() or d.get("refill") == null or str(d["maps"][0]["id"]) != map_id:
		return []
	var v := str(d["var"])
	var day := int(st.vars.get_v("GAME_DAY"))
	var rf: Dictionary = d["refill"]
	if state(st, d) == 1 and day - int(st.vars.get_v(v + "_DAY")) >= int(rf["days"]) and int(st.vars.get_v(v + "_ROLL")) != day:
		st.vars.set_v(v + "_ROLL", day)
		if rng.randi_range(1, 100) <= int(rf["pct"]):
			var people: Array = rf.get("people", [])
			var beasts: Array = rf.get("beasts", [])
			var kind := "people" if not people.is_empty() and (beasts.is_empty() or rng.randf() < 0.7) else "beasts"
			_clear_refill_keys(st, d)
			st.boxes["dg_refill:" + str(d["id"])] = {"ids": (people if kind == "people" else beasts).duplicate(), "kind": kind, "day": day}
			st.vars.set_v(v, 2)
			st.vars.set_v(v + "_DAY", day)
	if state(st, d) != 2:
		return []
	var rec: Dictionary = st.boxes.get("dg_refill:" + str(d["id"]), {})
	var spots: Array = d.get("spots", [])
	var out: Array = []
	var ids: Array = rec.get("ids", [])
	for i in ids.size():
		var key := "refill:%s:%d" % [str(d["id"]), i]
		if st.boxes.has(key) or i >= spots.size():
			continue
		out.append({"id": str(ids[i]), "x": int(spots[i][1]), "y": int(spots[i][2]), "refill_key": key})
	return out


## 재입주 무리를 다 쓰러뜨렸으면 다시 정리(그날부터 다시 셈). 다시 정리되면 알림 문구
static func refill_check(st: StoryState, map_id: String) -> String:
	var d := of_map(map_id)
	if d.is_empty() or state(st, d) != 2:
		return ""
	var rec: Dictionary = st.boxes.get("dg_refill:" + str(d["id"]), {})
	for i in rec.get("ids", []).size():
		if not st.boxes.has("refill:%s:%d" % [str(d["id"]), i]):
			return ""
	_clear_refill_keys(st, d)
	st.boxes.erase("dg_refill:" + str(d["id"]))
	st.vars.set_v(str(d["var"]), 1)
	st.vars.set_v(str(d["var"]) + "_DAY", int(st.vars.get_v("GAME_DAY")))
	return "%s — 들어앉았던 무리를 몰아냈다." % str(d["name"])


static func _clear_refill_keys(st: StoryState, d: Dictionary) -> void:
	for k in st.boxes.keys():
		if str(k).begins_with("refill:%s:" % str(d["id"])):
			st.boxes.erase(k)
