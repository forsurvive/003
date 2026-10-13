## 대화 창 시연·검사 장면(단계 0-2): MQ-P1 장면을 차례로 연다. 배경은 S-07 실내 방(바닥 합성 층).
## 실행: godot --path game res://scenes/story/dialogue_demo.tscn  [-- --auto --pick=5 --shots=디렉터리]
##   --auto: 0.35초마다 결정 키, 선택지에서는 --pick 번째를 고른다. --shots: 줄마다(다 나온 뒤) 화면을 저장, 끝나면 종료.
extends Node2D

const SCENES := ["MQ-P1_S01", "MQ-P1_S02_HRW", "MQ-P1_S02_DOYUN", "MQ-P1_S03"]
var st: StoryState
var box: DialogueBox
var si := 0
var auto := false
var pick := 5
var shots := ""
var t := 0.0
var shot_n := 0
var shot_key := ""
var mid_done := false
var log_done := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("1A181D"))
	add_child(InteriorRoom.new())
	st = StoryState.new()
	st.load_data()
	st.check_seed = randi()
	st.vars.set_v("P_SURNAME", "윤")
	st.vars.set_v("P_GIVEN", "서윤")
	st.vars.set_v("P_FULL", "윤서윤")
	st.vars.set_v("P_REGNO", "S07-2258-0031")
	box = DialogueBox.new()
	add_child(box)
	box.finished.connect(_next_scene)
	box.command.connect(_cmd)
	for a in OS.get_cmdline_user_args():
		if a == "--auto":
			auto = true
		elif a.begins_with("--pick="):
			pick = int(a.substr(7))
		elif a.begins_with("--shots="):
			shots = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots)
	_next_scene()


func _cmd(name: String, args: Array) -> void:
	print("연출: %s %s" % [name, " ".join(args)])
	get_tree().create_timer(0.2).timeout.connect(box.resume)


func _next_scene() -> void:
	if si >= SCENES.size():
		print("시연 끝: V_DOL=%d, MQP1_STAGE=%d, 기록 %d줄, 오류 %s" % [int(st.get_var("V_DOL")), st.quests.stage("MQ-P1"),
			box.runner.log.size(), str(box.runner.errors)])
		if auto:
			get_tree().quit()
		return
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/%s.json" % SCENES[si]))
	si += 1
	box.open(st, g)


func _shot(tag: String) -> void:
	if shots == "":
		return
	shot_n += 1
	get_viewport().get_texture().get_image().save_png("%s/dlg_%02d_%s.png" % [shots, shot_n, tag])


func _process(dt: float) -> void:
	if not auto or not box.active or box.waiting_cmd:
		return
	t += dt
	if t < 0.35:
		return
	t = 0.0
	var s: Dictionary = box.state
	if s.get("type", "") == "line":
		if box.reveal < box.page_len:
			if not mid_done:                                      # 글자가 나오는 중인 화면 한 장
				mid_done = true
				_shot("typing")
			return                                                # 끝까지 저절로 나오게 둔다
		var key := "%d:%s:%d" % [si, s["text"], box.page_i]
		if key != shot_key:
			shot_key = key
			_shot("line")
			if not log_done and si == SCENES.size():              # 마지막 장면에서 대화 기록 한 장
				log_done = true
				box.log_open = true
				box.view.queue_redraw()
				await get_tree().process_frame
				await get_tree().process_frame
				_shot("log")
				box.log_open = false
			return
		box.next()
	elif s.get("type", "") == "choices":
		_shot("choices")
		box.pick(pick)
