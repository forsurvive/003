## 월드 자리 촬영(단계 1-13a — 마감 배치 대조가 채운 자리를 눈으로 본다): 1막 시작 상태로 월드의 칸마다 들어가 한 장씩 찍는다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/spot_shot.tscn -- 폴더 x,y[,시] x,y …
##   시 = 그 칸에서의 시각(기본 10시). 파일 이름 = spot_x_y.png
extends Node

var host: InteriorHost
var out := ""
var spots: Array = []
var i := -1
var t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "user://"
	spots = args.slice(1)
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.events.clear()
	host.body = "adult"
	host.story_hold = true
	_next()


func _next() -> void:
	i += 1
	if i >= spots.size():
		get_tree().quit()
		return
	var a: PackedStringArray = str(spots[i]).split(",")
	var hour := int(a[2]) if a.size() > 2 else 10
	host.date_text = "2277. 10. 25.  %02d:00" % hour
	host.st.vars.set_v("GAME_HOUR", hour)
	host.enter("X-BC", "@%s,%s" % [a[0], a[1]])
	t = 0.0


func _process(dt: float) -> void:
	t += dt
	if i < spots.size() and t > 2.0:
		var a: PackedStringArray = str(spots[i]).split(",")
		var img := get_viewport().get_texture().get_image()
		var p := out.path_join("spot_%s_%s.png" % [a[0], a[1]])
		img.save_png(p)
		print("찍음 ", p, " · 인물 ", host.npcs.map(func(n): return str(n["id"])))
		_next()
