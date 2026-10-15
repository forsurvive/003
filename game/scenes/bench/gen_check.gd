## 들어가 보는 건물 확인(단계 1-5e): 종류마다 실내 한 장씩 들어가 찍고, 월드 건물 문 앞에서 (E)로 들어갔다가 출구로 나와 문 앞에 서는지 본다.
## 실행: xvfb-run godot --path game res://scenes/bench/gen_check.tscn -- /tmp/shots
extends Node

var host: InteriorHost
var st: StoryState
var shots := ""
var queue: Array = []
var t := 0.0
var step := 0
var ok := 0
var fail := 0
var door: Dictionary = {}


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	shots = a[0] if a.size() > 0 else ""
	host = InteriorHost.new()
	add_child(host)
	st = host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 3)
	host.body = "adult"
	host.hud_on = true
	host.date_text = "2277. 10. 25.  14:00"
	var want := {}                                                    # 종류(가게는 이름 끝)마다 하나
	var dir := DirAccess.open("res://data/maps")
	for f in dir.get_files():
		if not f.begins_with("G-") or not f.ends_with(".json"):
			continue
		var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/" + f))
		var k := str(d.get("gen", ""))
		if k == "shop":
			for suf in ["슈퍼", "상회", "마트", "약국", "철물", "공구", "세탁", "크리닝", "분식", "김밥"]:
				if str(d["name"]).ends_with(suf):
					k = "shop_" + suf
		if str(d["name"]) == "버려진 집":
			k = "den"
		if d["size"][0] >= 26:
			k += "_bath"
		if not want.has(k):
			want[k] = str(d["id"])
	for k in want:
		queue.append(want[k])
	queue.sort()
	PlaceLog.load_db()
	for d in PlaceLog.doors:                                          # 봉천 가까운 건물 문 하나(월드 출입 확인)
		if str(d.get("kind", "")) == "facade" and int(d.get("lock", 0)) == 0:
			if door.is_empty() or Vector2(int(d["at"][0]), int(d["at"][1])).distance_to(Vector2(892, 1362)) < Vector2(int(door["at"][0]), int(door["at"][1])).distance_to(Vector2(892, 1362)):
				door = d
	print("종류 %d: %s" % [queue.size(), str(want.keys())])


func _process(dt: float) -> void:
	t += dt
	if step < queue.size():
		if t < 0.05:
			return
		if host.map == null or host.map.id != queue[step]:
			if t > 0.3:
				host.enter(queue[step], "from_W")
				t = 0.0
			return
		if t > 1.2:
			_shot(queue[step])
			var en := host.combat.enemies.size()
			print("  %s %s %d×%d · 용기 %d · 글 %d · 적 %d" % [queue[step], host.map.data.get("name", ""), host.map.data["size"][0], host.map.data["size"][1],
				host.map.boxes.size(), host.map.texts.size(), en])
			ok += 1
			step += 1
			t = 0.0
		return
	match step - queue.size():
		0:                                                            # 월드: 문 앞에 서서 북쪽을 본다
			var at := Vector2i(int(door["at"][0]), int(door["at"][1]))
			host.enter("W", "@%d,%d" % [at.x, at.y + 1])
			step += 1
			t = 0.0
		1:
			if t < 1.5:
				return
			host.player.loco.facing = 6
			host.player._show()
			var pr := host.box_prompt()
			print("  월드 문 %s 앞: 안내 '%s'" % [str(door["at"]), pr])
			_check(pr.begins_with("(E) 들어간다"), "건물 문 앞 안내 '(E) 들어간다'")
			_shot("world_door")
			host.interact()
			step += 1
			t = 0.0
		2:
			if t < 2.0:
				return
			_check(host.map.id == str(door["to"]), "E로 실내 %s에 들어감(지금 %s)" % [door["to"], host.map.id])
			_shot("inside")
			var ex: Dictionary = host.map.data["exits"][0]               # 출구 칸을 밟는다
			host.player.loco.place(Vector2(int(ex["x"]) * 32 + 16, int(ex["y"]) * 32 + 16))
			step += 1
			t = 0.0
		3:
			if t < 2.5:
				return
			var tile: Vector2i = host.map.tile_of(host.player.loco.logical)
			_check(host.map is WorldMap and tile == Vector2i(int(door["at"][0]), int(door["at"][1]) + 1), "나오면 그 문 앞 칸(지금 %s)" % str(tile))
			_shot("back_out")
			print("들어가는 건물 확인: %s 실내 %d · 실패 %d" % ["○" if fail == 0 else "×", ok, fail])
			step += 1
			get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


func _check(c: bool, what: String) -> void:
	print("  [확인] %s %s" % ["○" if c else "×", what])
	if not c:
		fail += 1


func _shot(tag: String) -> void:
	if shots == "":
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/gen_%s.png" % [shots, tag.replace(" ", "_")])
