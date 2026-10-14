## 지도 확인 장면(단계 1-2): 봉천(1막)에서 R01·R02 장소 일부를 발견·표시·소문으로 둔 채 핍-보이 지도를 연다.
## 실행: godot --path game res://scenes/bench/map_check.tscn --write-movie out.png --fixed-fps 2 --quit-after 4 -- 1 [확대 0~3]
## 첫 인자 0 = 지역 지도, 1 = 월드 지도.
extends Node
func _ready() -> void:
	var host := InteriorHost.new()
	add_child(host)
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		host.st.quests.set_stage(q, 100)
	host.body = "adult"
	host.date_text = "2277. 10. 23.  16:40"
	host.enter("X-BC", "from_X-S07")
	PlaceLog.load_db()
	var i := 0
	for lid in PlaceLog.db:                                              # R01: 앞 절반 발견, 나머지 표시 · R02: 소문 몇 곳
		if lid.begins_with("L-R01-"):
			host.st.places.raise(lid, PlaceLog.FOUND if i % 2 == 0 else PlaceLog.MARKED)
			i += 1
		elif lid.begins_with("L-R02-") and int(lid.substr(7)) % 4 == 0:
			host.st.places.raise(lid, PlaceLog.RUMOR)
	host.st.places.regions["R01"] = true
	var me: Vector2 = host.player.loco.logical
	for dy in range(-30, 31, 6):                                         # 봉천 둘레를 본 것으로
		for dx in range(-30, 31, 10):
			host.st.places.mark_seen(host.map.tile_of(me) + Vector2i(dx, dy))
	var args := OS.get_cmdline_user_args()
	var p := host.open_pipboy()
	p.t_open = 1.0
	p.open_at(2, int(args[0]) if args.size() > 0 else 1)
	p.map = PipMap.new(p)
	if args.size() > 1:
		p.map.zoom = int(args[1])
	p.map.cursor = Vector2(892, 1362)
	p.map.center = Vector2(892, 1362)
