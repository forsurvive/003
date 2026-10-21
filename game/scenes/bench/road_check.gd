## 길 · 철길 확인 장면(1-12g 도로 고침, SD-21 §11 끝): 월드 한 점들에 주인공을 세우고 청크가 붙을 때까지 기다린 뒤 스크린샷.
## 동네 길이 보도를 지나 간선에 닿는 입구 · 철길 덧그림(레일 · 침목 · 건널목)이 게임 셰이더 위에서 제대로 얹히는지 본다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/road_check.tscn -- 스크린샷폴더 x,y[,이름] ...
extends Node

var host: InteriorHost
var shots := ""
var spots: Array = []
var i := 0
var wait := 0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	for k in range(1, args.size()):
		var p := str(args[k]).split(",")
		spots.append([Vector2i(int(p[0]), int(p[1])), p[2] if p.size() > 2 else "%s_%s" % [p[0], p[1]]])
	if spots.is_empty():
		spots = [[Vector2i(882, 1172), "noryang"]]
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.quests.set_stage("MQ-101", 50)
	st.vars.set_v("MQ101_RESULT", 1)
	st.vars.set_v("GAME_DAY", 2)
	host.body = "adult"
	host.date_text = "2277. 10. 24.  12:00"
	host.enter("W", "", {}, Vector2(spots[0][0]) * 32.0 + Vector2(16, 16))
	host.story_hold = true
	wait = 40


func _process(_dt: float) -> void:
	if wait > 0:
		wait -= 1
		return
	await _shot(str(spots[i][1]))
	i += 1
	if i >= spots.size():
		get_tree().quit()
		return
	host.player.loco.place(Vector2(spots[i][0]) * 32.0 + Vector2(16, 16))
	host.cam.position = host.player.loco.logical.round()
	host.cam.reset_smoothing()
	wait = 40


func _shot(tag: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/road_%s.png" % [shots, tag])
	print("  스크린샷 ", tag)
