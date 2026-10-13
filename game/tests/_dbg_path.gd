extends SceneTree
func _init() -> void:
	var st := StoryState.new()
	st.load_data()
	st.quests.set_stage("MQ-P1", 100)
	st.quests.set_stage("MQ-P2", 40)
	var m := InteriorMap.new()
	m.load_map("V-01", st)
	var from := Vector2(1774, 840)
	print("tile ", m.tile_of(from), " solid ", m.is_solid(m.tile_of(from)))
	print("path ", m.path(from, m.mark_pos("p2_ration")).size())
	for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
		print(d, " solid ", m.is_solid(m.tile_of(from) + d))
	print("hits circle ", m.circle_hits(from, 9.6))
	quit()
