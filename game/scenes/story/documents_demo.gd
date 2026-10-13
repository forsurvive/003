## 서류 UI 5종 시연(단계 0-4): 출생신고서 → 생활기록부 → 적성 평가 카드 → 결과 통지서·태그 → 출구 점검표.
## 실행: godot --path game res://scenes/story/documents_demo.tscn  [-- --auto --shots=디렉터리]
##   --auto: 정해 둔 조작(입력 동작 + 직접 호출)으로 다섯 서류를 끝까지 채운다. --shots: 단계마다 화면을 저장하고 끝나면 종료.
extends Node

var st: StoryState
var auto := false
var shots := ""
var shot_n := 0
var cur: DocScreen


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0B0A0D"))
	st = StoryState.new()
	st.load_data()
	for a in OS.get_cmdline_user_args():
		if a == "--auto":
			auto = true
		elif a.begins_with("--shots="):
			shots = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots)
	_run()


func _open(doc_name: String) -> DocScreen:
	cur = Documents.open(doc_name, st, self, func(ok: bool) -> void: print("서류 %s 닫힘 (확정 %s)" % [doc_name, ok]))
	return cur


func _closed() -> void:
	if is_instance_valid(cur) and cur.is_inside_tree():
		await cur.closed


func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout


func _shot(tag: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	shot_n += 1
	get_viewport().get_texture().get_image().save_png("%s/doc_%02d_%s.png" % [shots, shot_n, tag])


func _key(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await get_tree().process_frame
	var u := InputEventAction.new()
	u.action = action
	Input.parse_input_event(u)
	await _wait(0.08)


func _run() -> void:
	for doc_name in Documents.NAMES:
		var d := _open(doc_name)
		if auto:
			await call("_auto_" + doc_name, d)
		await _closed()
		await _wait(0.2)
	print("시연 끝: %s %s · 성별 %d · 외형 %s/%s/%s · 능력치 %s · 태그 %s · 적성 %s · V_Q10 %d" % [st.vars.get_v("P_FULL"),
		st.vars.get_v("P_REGNO"), st.vars.get_v("PC_SEX"), st.vars.get_v("PC_HAIR"), st.vars.get_v("PC_HCOL"), st.vars.get_v("PC_SKIN"),
		str(CharDocs.stats_of(st)), str(CharDocs.tags_of(st)), st.vars.get_v("PC_APT"), st.vars.get_v("V_Q10")])
	if auto:
		get_tree().quit()


func _auto_birth(d: RegisterTerminal) -> void:
	await _wait(0.5)
	await _shot("birth_open")
	d.given_edit.text = "Seo"                                              # 로마자 → 거부
	d._press("ok")
	await _wait(0.3)
	await _shot("birth_error")
	d.sur_edit.text = "한"
	d.given_edit.text = "서진"
	d._pool_name = ""
	d.error = ""
	d._set_sex(CharDocs.SEX_F)
	d.focus_on("hair")
	await _wait(0.05)
	for i in 5:
		await _key("ui_right")
	await _key("ui_down")
	await _key("ui_right")
	await _wait(0.6)
	await _shot("birth_look")
	d._press("ok")
	await _wait(0.8)
	await _shot("birth_signal")
	await _wait(1.6)
	await _shot("birth_done")


func _auto_record(d: RecordBook) -> void:
	await _wait(0.4)
	await _shot("record_open")
	d.focus_on("PE")
	await _wait(0.05)
	for k in [["PE", 2], ["IN", 3], ["CH", -1], ["LK", 1]]:
		d.stats[k[0]] = int(d.stats[k[0]]) + int(k[1])
	d.focus_on("CH")
	await _wait(0.05)
	await _key("ui_left")                                                  # 키 입력 경로로 한 칸 내림(담임 의견 다시 쓰기)
	await _wait(0.15)
	await _shot("record_rewrite")
	await _key("ui_right")
	await _wait(0.5)
	await _shot("record_full")
	d._press("ok")
	await _wait(1.0)
	await _shot("record_signed")


func _auto_aptitude(d: AptitudeCard) -> void:
	await _wait(0.4)
	await _shot("aptitude_q1")
	var picks := [1, 1, 2, 3, 1, 1, 4, 2, 4, 1]                           # 의학·수리·에너지·과학·과학·수리·은신·화술·수리 + 10-①
	for i in picks.size():
		d._press("opt%d" % (picks[i] - 1))
		await _wait(0.45)
		if i == 4:
			await _shot("aptitude_q6")
		if i == 8:
			await _shot("aptitude_q10")
	await _wait(0.2)
	await _shot("aptitude_full")
	d._press("submit")
	await _wait(0.6)
	await _shot("aptitude_stamp")


func _auto_result(d: ResultSheet) -> void:
	await _wait(0.4)
	await _shot("result_open")
	d._press("SMALL_GUNS")                                                 # 추천 3번째(10번 답의 소형 화기)를 화술로 바꾼다
	d._press("MEDICINE")
	d._press("SPEECH")
	d.focus_on("SPEECH")
	await _wait(0.3)
	await _shot("result_swap")
	d._press("ok")
	await _wait(0.5)


func _auto_exit(d: RegisterTerminal) -> void:
	await _wait(0.5)
	await _shot("exit_open")
	d._press("regno")
	await _wait(0.3)
	await _shot("exit_regno")
	d._press("stats")
	await _wait(0.4)
	var rb := get_children().filter(func(n): return n is RecordBook)
	await _shot("exit_record")
	if not rb.is_empty():
		rb[0].stats["ST"] = int(rb[0].stats["ST"]) + 1
		rb[0].stats["LK"] = int(rb[0].stats["LK"]) - 1
		rb[0]._press("ok")
		await rb[0].closed
	await _wait(0.4)
	await _shot("exit_after")
	d._press("ok")
	await _wait(0.8)
	await _shot("exit_done")
