## 인게임 컷신 시연(단계 0-3): 이벤트 실행기 + 대화 창으로 MQ-P1 의무실 장면을 무대(임시: S-07 정문 안)에 올린다.
## 실행: godot --path game res://scenes/story/cutscene_demo.tscn [-- --auto]  (녹화: --write-movie out.png --fixed-fps 20)
extends Node2D

var st: StoryState
var box: DialogueBox
var ev: EventRunner
var auto := false
var hold := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0B0A0D"))
	var room := InteriorRoom.new()
	add_child(room)
	y_sort_enabled = true
	st = StoryState.new()
	st.load_data()
	for kv in [["P_SURNAME", "윤"], ["P_GIVEN", "서윤"], ["P_FULL", "윤서윤"], ["P_REGNO", "S07-2258-0031"]]:
		st.vars.set_v(kv[0], kv[1])
	ev = EventRunner.new()
	add_child(ev)
	ev.setup(room, "int_s07_gate")
	box = DialogueBox.new()
	add_child(box)
	ev.attach(box)
	Documents.attach(ev, st, self)                                    # `doc birth` → 출생신고서(0-4)
	child_entered_tree.connect(func(n: Node) -> void:
		if auto and n is RegisterTerminal:                              # 자동 시연: 미리 채운 이름 그대로 1.5초 뒤 [신고]
			get_tree().create_timer(1.5).timeout.connect(func() -> void: n._press("ok")))
	box.finished.connect(func() -> void:
		print("컷신 끝: 연출 %d개, MQP1_STAGE=%d, 오류 %s" % [ev.log.size(), st.quests.stage("MQ-P1"), str(box.runner.errors)])
		if auto:
			get_tree().create_timer(0.5).timeout.connect(get_tree().quit))
	auto = "--auto" in OS.get_cmdline_user_args()
	box.open(st, JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/MQ-P1_S01.json")))


func _process(dt: float) -> void:
	if not auto or not box.active or box.waiting_cmd:
		return
	if box.state.get("type", "") == "line" and box.reveal >= box.page_len:
		hold += dt
		if hold > 0.9:
			hold = 0.0
			box.next()
