## 실내 맵 사이 길(출구 그래프): 자동 진행 봇·안내가 '다음에 어느 출구로 나가야 하나'를 묻는다.
## 맵 자료(data/maps/*.json)의 exits를 한 번 읽어 두고 넓이 우선 탐색.
class_name MapGraph
extends RefCounted

static var _edges := {}                      ## 맵 ID -> [[갈 맵, 출구 타일 Vector2i], …]


static func _load() -> void:
	if not _edges.is_empty():
		return
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/_index.json"))["maps"]
	for id in idx:
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % id))
		_edges[id] = []
		for e in d["exits"]:
			if idx.has(e["to"]):
				_edges[id].append([e["to"], Vector2i(int(e["x"]), int(e["y"]))])


## from에서 to로 가는 맵 차례(from 제외, to 포함). 길이 없으면 빈 배열
static func route(from_id: String, to_id: String) -> Array:
	_load()
	if from_id == to_id:
		return []
	var came := {from_id: ""}
	var q: Array = [from_id]
	while not q.is_empty():
		var cur: String = q.pop_front()
		for e in _edges.get(cur, []):
			if not came.has(e[0]):
				came[e[0]] = cur
				if e[0] == to_id:
					var out: Array = [to_id]
					var t: String = cur
					while t != from_id:
						out.push_front(t)
						t = came[t]
					return out
				q.append(e[0])
	return []


## 지금 맵에서 to 쪽으로 나가는 출구 타일(없으면 (-1, -1))
static func next_exit(from_id: String, to_id: String) -> Vector2i:
	var r := route(from_id, to_id)
	if r.is_empty():
		return Vector2i(-1, -1)
	for e in _edges[from_id]:
		if e[0] == r[0]:
			return e[1]
	return Vector2i(-1, -1)
