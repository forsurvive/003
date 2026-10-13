## 바닥 합성 검증 장면: 시험 구역 한 곳(20×11타일)을 GroundLayer로 그린다. art/tools/ground.py가 같은 구역을 그린
## 대조본(assets/ground/ref_*.png)과 픽셀 단위로 같아야 한다(tools/screens/ground_check.py가 찍어서 비교).
## 실행: godot --path game res://scenes/bench/ground_check.tscn --write-movie out.png --fixed-fps 1 --quit-after 2 -- --region=r01|s07 [--origin=x,y]
extends Node2D

const SIZE := Vector2i(20, 11)
var ORIGIN := Vector2i(160, 165)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	var which := "r01"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--region="):
			which = a.substr(9)
		elif a.begins_with("--origin="):
			var xy := a.substr(9).split(",")
			ORIGIN = Vector2i(int(xy[0]), int(xy[1]))
	if which == "s07":
		var room := InteriorRoom.new()
		add_child(room)
		return
	var idx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/chunks/_index.json"))
	var cs := int(idx["chunk_size"])
	var g := GroundLayer.new()
	g.setup("r01", ORIGIN, SIZE)
	var cache := {}
	for ty in range(ORIGIN.y - 1, ORIGIN.y + SIZE.y + 1):
		for tx in range(ORIGIN.x - 1, ORIGIN.x + SIZE.x + 1):
			var id := "C-%02d-%02d" % [tx / cs, ty / cs]
			if not cache.has(id):
				cache[id] = JSON.parse_string(FileAccess.get_file_as_string("res://data/chunks/%s.json" % id))
			var c: Dictionary = cache[id]
			var i := (ty % cs) * cs + (tx % cs)
			g.put(tx, ty, int(c["ground"][i]), int(c["deco"][i]))
	g.commit()
	position = -Vector2(ORIGIN * 32)
	add_child(g)
