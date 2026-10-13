## 프롤로그 진행(단계 0-6~): MQ-P1 출생신고를 처음부터 끝까지 이어 놀기.
##   S1 의무실 컷신(주인공 = 침대의 갓난아기, 안 보임) + 출생신고서 → '2259' 연도 카드
##   S2 돌잔치(V-01 공동 식당): 걸음마 이동 튜토리얼(걷기만·느림), 주민 6명에게 조사 키로 말 걸기, 길목에서 아기 하도윤이 기어 나와
##      막는다(우회) → 윤정인 앞(돌상 둘레)에 닿으면 단계 20 완료
##   S3 돌잡이: 물건 여섯 가운데 하나 → V_DOL, 주민 한마디, MQ-P1 완료(100) → '2268' 연도 카드
## 실행: godot --path game res://scenes/story/prologue.tscn [-- --auto --pick=N --shots=디렉터리]
##   --auto: 대사를 넘기고 신고서를 내고, 걸음마로 손님 한 명에게 말을 건 뒤 엄마에게 걸어가 N번째(1~6, 기본 2 청진기)를 잡는다.
extends Node

var host: InteriorHost
var phase := "S1"
var auto := false
var pick := 2
var shots := ""
var shot_n := 0
var hold := 0.0
var bot := "talk"                               ## talk(손님 한 명) → walk(엄마에게) → done
var path := PackedVector2Array()
var talked := false
var t := 0.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0B0A0D"))
	for a in OS.get_cmdline_user_args():
		if a == "--auto":
			auto = true
		elif a.begins_with("--pick="):
			pick = clampi(int(a.substr(7)), 1, 6)
		elif a.begins_with("--shots="):
			shots = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots)
	host = InteriorHost.new()
	add_child(host)
	host.use_keyboard = not auto
	host.body = "hidden"                                       # 주인공은 윤정인 품의 갓난아기(침대 그림 안)
	host.enter("V-08", "door")
	host.banner_t = 0.0
	host.box.finished.connect(_on_dialogue_done)
	host.child_entered_tree.connect(func(n: Node) -> void:
		if auto and n is RegisterTerminal:
			get_tree().create_timer(1.5).timeout.connect(func() -> void: n._press("ok")))
	host.play_scene.call_deferred("MQ-P1_S01")


func _on_dialogue_done() -> void:
	var stage := host.st.quests.stage("MQ-P1")
	if phase == "S1" and stage >= 20:
		phase = "S2"
		_shot("s1_end")
		host.busy = true
		host.body = "toddler"
		host.enter("V-01", "dol_start")
		host.ev.run("fade_in", ["white", "8"], func() -> void:
			host.busy = false
			host.hint("방향키·WASD: 아장아장 걷기 (아직 뛸 수 없다)", 6.0)
			host.hint("E·Enter: 조사하기 · 말 걸기", 6.0))
	elif phase == "S2" and stage >= 100:
		phase = "end"
		print("MQ-P1 완료: %s · V_DOL=%d · 단계 %d" % [host.st.vars.get_v("P_FULL"), host.st.vars.get_v("V_DOL"), stage])
		_shot("end")
		if auto:
			get_tree().create_timer(0.5).timeout.connect(get_tree().quit)


func _shot(tag: String) -> void:
	if shots == "":
		return
	shot_n += 1
	get_viewport().get_texture().get_image().save_png("%s/p1_%02d_%s.png" % [shots, shot_n, tag])


# ---------------------------------------------------------------- 자동 진행
func _process(dt: float) -> void:
	if not auto:
		return
	t += dt
	var box := host.box
	if box.active and not box.waiting_cmd:
		host.input_vec = Vector2.ZERO
		match box.state.get("type", ""):
			"line":
				if box.reveal >= box.page_len:
					hold += dt
					if hold > 0.8:
						hold = 0.0
						if box.state.get("who", "") in ["N-R01-010", "C-002", "SYS"] or box.state.get("text", "").contains("하나 잡아"):
							_shot(str(box.state.get("who", "")))
						box.next()
			"choices":
				hold += dt
				if hold > 1.2:
					hold = 0.0
					_shot("dol_choices")
					box.pick(pick - 1)
		return
	if phase != "S2" or host.busy or host.ev.busy():
		return
	match bot:
		"talk":                                                       # 손님 한 명(송새봄)에게 다가가 말 걸기
			if talked:
				bot = "walk"
				path = PackedVector2Array()
				return
			var n := _npc("N-R01-010")
			if n.is_empty():
				bot = "walk"
				return
			var to: Vector2 = n["actor"].loco.logical + Vector2(-32, 0)
			if NpcRoutine.arrived(host.player.loco.render, to):
				host.input_vec = Vector2.ZERO
				host.player.loco.facing = 0
				host.player._show()
				talked = host.interact()
			else:
				host.input_vec = _follow(to)
		"walk":                                                       # 엄마에게(돌상 앞) — 길목에서 하도윤이 막으면 돌아간다
			var to := host.map.mark_pos("dol_front")
			host.input_vec = _follow(to)
			if host.st.quests.stage("MQ-P1") >= 30:
				bot = "done"
				host.input_vec = Vector2.ZERO


func _npc(id: String) -> Dictionary:
	for n in host.npcs:
		if n["id"] == id:
			return n
	return {}


func _follow(goal: Vector2) -> Vector2:
	var p := host.player.loco.render
	if path.is_empty() or host.map.tile_of(path[path.size() - 1]) != host.map.tile_of(goal) or t > 0.0 and int(t * 2.0) % 6 == 0:
		path = NpcRoutine.with_start(host.map, p, goal)              # 하도윤이 길을 막으면 다시 찾는다(3초마다)
	while path.size() > 0 and NpcRoutine.arrived(p, path[0]):
		path.remove_at(0)
	if path.is_empty():
		return Vector2.ZERO
	return NpcRoutine.step_dir(p, path[0])
