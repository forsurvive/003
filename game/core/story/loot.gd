## 용기 내용물(SD-12 §7.3, 단계 0-9): 처음 열 때 표(data/loot_s07.json)로 굴려 정하고, 그 뒤로는 이야기 상태(st.boxes)에 남는다.
## 씨앗 = 용기 자리 + 연도 → 같은 시대에 다시 열면 같은 내용, 시대가 바뀌면 새로 채워진다(200년 볼트, 사물함 주인이 바뀐다).
## 소유(owner): "" 주인 없음 · "PC" 내 것 · "S7" 볼트 공용(관리동·보안과) · 인물 ID. 내 것이 아니고 주인이 있으면 꺼내는 것이 절도.
class_name Loot
extends RefCounted

static var tables := {}


static func _load() -> void:
	if not tables.is_empty():
		return
	var p := "res://data/loot_s07.json"
	if FileAccess.file_exists(p):
		tables = JSON.parse_string(FileAccess.get_file_as_string(p))["tables"]


static func kind_name(kind: String) -> String:
	_load()
	return str(tables.get(kind, {}).get("name", kind))


## 용기 하나의 상태 열쇠: "맵:x,y@연도"
static func key(map_id: String, b: Dictionary, year: int) -> String:
	return "%s:%d,%d@%d" % [map_id, int(b["x"]), int(b["y"]), year]


## 표로 내용물을 굴린다(결정적: 같은 열쇠면 같은 결과)
static func roll(kind: String, seed_key: String) -> Dictionary:
	_load()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_key)
	var out := {}
	for r in tables.get(kind, {}).get("rows", []):
		if rng.randf() < float(r[1]):
			var n := rng.randi_range(int(r[2]), int(r[3]))
			out[str(r[0])] = int(out.get(str(r[0]), 0)) + n
	return out


## 이 용기의 지금 내용물(없으면 굴려서 st.boxes에 넣는다)
static func contents(st: StoryState, map_id: String, b: Dictionary) -> Dictionary:
	var k := key(map_id, b, st.year())
	if not st.boxes.has(k):
		st.boxes[k] = {"items": roll(str(b["kind"]), k), "opened": 0, "taken": 0}
	return st.boxes[k]


## 주인이 있는 남의 물건인가(절도 판정 대상)
static func owned(b: Dictionary) -> bool:
	var o := str(b.get("owner", ""))
	return o != "" and o != "PC"
