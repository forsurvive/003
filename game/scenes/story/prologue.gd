## 프롤로그 진행(단계 0-6~): MQ-P1 출생신고 → MQ-P2 열 살, 첫 배정을 처음부터 끝까지 이어 논다.
##   MQ-P1: S1 의무실 컷신(주인공 = 침대의 갓난아기) + 출생신고서 → '2259' → S2 돌잔치 걸음마 → S3 돌잡이 → '2268'
##   MQ-P2: S1 교실 생활기록부 → S2 식당 생일잔치(핍-보이·HUD) → S3 행정실 첫 배정 → S4 배급소 지우(선택, 카르마 5갈래)
##          → S5 사격장(BB총: 표적 10 → 은신 표적 2) → S6 배관실(하도윤 동행, 증기 분출·스팀팩, 큰바퀴 6) → '2274'
##   사격장 단계 넘김·바퀴 전멸 장면은 여기서 연다(전투 신호). 주인공이 쓰러지면(프롤로그 특례, 정합): 하도윤이 끌어내
##   배관실 입구에서 HP 가득으로 깨어난다(바퀴는 그대로).
## 실행: godot --path game res://scenes/story/prologue.tscn [-- --auto --pick=N --jiwoo=N --from=p2 --shots=디렉터리]
##   --auto: 대사를 넘기고 서류를 내고 길을 찾아 걸어가며(맵을 넘어) 사격·은신·근접·스팀팩까지 하는 봇.
##   --pick: 돌잡이 1~6(기본 2 청진기) · --jiwoo: 지우 장면 선택 1~6(기본 3 [인지력 5] 카드 찾기) · --from=p2: MQ-P2부터
extends Node

var host: InteriorHost
var phase := "P1S1"
var auto := false
var pick := 2
var jiwoo := 3
var shots := ""
var shot_n := 0
var hold := 0.0
var path := PackedVector2Array()
var path_goal := Vector2.INF
var t := 0.0
var talked := false
var stealth_started := false
var _re_t := 0.0
var _pip_t := 0.0
var log_on := false                             ## --log: 5초마다 진행 상태 한 줄(봇·녹화 점검)


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0B0A0D"))
	var from := ""
	for a in OS.get_cmdline_user_args():
		if a == "--auto":
			auto = true
		elif a.begins_with("--pick="):
			pick = clampi(int(a.substr(7)), 1, 6)
		elif a.begins_with("--jiwoo="):
			jiwoo = clampi(int(a.substr(8)), 1, 6)
		elif a.begins_with("--from="):
			from = a.substr(7)
		elif a == "--log":
			log_on = true
		elif a.begins_with("--shots="):
			shots = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shots)
	host = InteriorHost.new()
	add_child(host)
	host.use_keyboard = not auto
	host.box.finished.connect(_on_dialogue_done)
	host.combat.target_down.connect(_on_target_down)
	host.combat.enemy_killed.connect(_on_enemy_killed)
	host.combat.player_down.connect(_on_player_down)
	host.child_entered_tree.connect(_on_child)
	if from == "p2":
		_quick_p1()
		_start_p2.call_deferred()
		return
	if from in ["range", "pipe"]:                              # 개발용: 사격장·배관실부터
		_quick_p1()
		phase = "P2"
		host.body = "kid"
		host.pipboy_ok = true
		host.hud_on = true
		host.date_text = "2268. 03. 02.  15:20"
		host.st.quests.set_stage("MQ-P2", 40 if from == "range" else 60)
		if from == "pipe":
			host.st.call_fn("give", ["W-065"])
			host.st.call_fn("give", ["BB탄", 150])
			stealth_started = true
		host.enter("V-09" if from == "range" else "V-10", "from_V-01" if from == "range" else "from_V-04")
		return
	host.body = "hidden"                                       # 주인공은 윤정인 품의 갓난아기(침대 그림 안)
	host.enter("V-08", "door")
	host.banner_t = 0.0
	host.play_scene.call_deferred("MQ-P1_S01")


## --from=p2: MQ-P1을 건너뛴 상태(이름·외형·돌잡이)를 만든다
func _quick_p1() -> void:
	var st := host.st
	CharDocs.write_name(st, "윤", "서진")
	st.vars.set_v("P_REGNO", CharDocs.REGNO)
	st.vars.set_v("V_DOL", pick)
	st.quests.set_stage("MQ-P1", 100)


func _on_child(n: Node) -> void:
	if not auto:
		return
	if n is RegisterTerminal:
		get_tree().create_timer(1.5).timeout.connect(func() -> void: n._press("ok"))
	elif n is RecordBook:                                      # 봇: 인지력·지구력·지능·민첩성·행운 +1 → 확정
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			for c in ["PE", "EN", "IN", "AG", "LK"]:
				n._adjust(c, 1)
			get_tree().create_timer(1.5).timeout.connect(func() -> void: n._press("ok")))
	elif n is PipBoy:                                          # 봇: 탭을 한 바퀴 둘러보고 닫는다
		_pip_t = 0.0


func _on_dialogue_done() -> void:
	var st := host.st
	var p1 := st.quests.stage("MQ-P1")
	var p2 := st.quests.stage("MQ-P2")
	if phase == "P1S1" and p1 >= 20:
		phase = "P1S2"
		_shot("s1_end")
		host.busy = true
		host.body = "toddler"
		host.enter("V-01", "dol_start")
		host.ev.run("fade_in", ["white", "8"], func() -> void:
			host.busy = false
			host.hint("방향키·WASD: 아장아장 걷기 (아직 뛸 수 없다)", 6.0)
			host.hint("E·Enter: 조사하기 · 말 걸기", 6.0))
	elif phase == "P1S2" and p1 >= 100:
		print("MQ-P1 완료: %s · V_DOL=%d · 단계 %d" % [st.vars.get_v("P_FULL"), st.vars.get_v("V_DOL"), p1])
		_shot("p1_end")
		_start_p2()
	elif phase == "P2" and p2 >= 100:
		phase = "end"
		print("MQ-P2 완료: 카르마 %d · 지우 %d · XP %d · 표적 %d(기습 %d) · 바퀴 %d · 스팀팩 %d · 받은 피해 %d" % [
			int(st.vars.get_v("V_KARMA")), int(st.vars.get_v("MQP2_RESULT")), int(st.vars.get_v("PC_XP")),
			host.combat.stats["hits"], host.combat.stats["sneak"], host.combat.stats["downs"], host.combat.stats["stims"],
			int(host.combat.stats["hurt"])])
		_shot("end")
		if auto:
			get_tree().create_timer(0.5).timeout.connect(get_tree().quit)


func _start_p2() -> void:
	phase = "P2"
	host.busy = true
	host.body = "kid"
	host.date_text = "2268. 03. 02.  09:10"
	host.st.quests.set_stage("MQ-P2", 10)                     # 2268년(year())으로 맵을 연다 — 교실의 차명수·하도윤
	host.enter("V-03", "p2_seat")
	host.ev.run("fade_in", ["white", "8"], func() -> void:
		host.busy = false
		host.play_scene("MQ-P2_S01"))


# ---------------------------------------------------------------- 전투 신호 → 장면
func _on_target_down(kind: String, _sneak: bool, _left: int) -> void:
	var c := host.combat
	if host.st.quests.stage("MQ-P2") != 50:
		return
	if kind == "target" and c.targets_left("target") == 0 and not stealth_started:
		stealth_started = true
		_scene_soon("MQ-P2_S05B")
	elif kind == "stealth" and c.targets_left("stealth") == 0:
		_scene_soon("MQ-P2_S05C")


func _on_enemy_killed(_id: String, left: int) -> void:
	if left == 0 and host.st.quests.stage("MQ-P2") == 60:
		_scene_soon("MQ-P2_S06_END")


func _scene_soon(id: String) -> void:
	get_tree().create_timer(0.8).timeout.connect(func() -> void:
		if not host.box.active:
			host.play_scene(id))


## 프롤로그 특례(정합 — 문서에 없음): 쓰러지면 하도윤이 끌어내고, 배관실 입구에서 HP 가득으로 깨어난다
func _on_player_down() -> void:
	host.busy = true
	host.ev.run("fade_out", ["black", "6"], func() -> void:
		var c := host.combat
		c.pc.hp = c.pc.max_hp
		c.pc.dead = false
		host.player.loco.place(host.map.mark_pos("p2_pipe") if host.map.marks.has("p2_pipe") else host.player.loco.logical)
		host.ev.run("fade_in", ["black", "6"], func() -> void:
			host.busy = false
			host.say_text("정신이 들었다. 하도윤이 통로까지 끌고 나왔다. 스팀팩을 쓰고 다시 가자.")))


func _shot(tag: String) -> void:
	if shots == "":
		return
	shot_n += 1
	get_viewport().get_texture().get_image().save_png("%s/p_%02d_%s.png" % [shots, shot_n, tag])


# ---------------------------------------------------------------- 자동 진행
func _process(dt: float) -> void:
	if not auto:
		return
	t += dt
	if log_on and int(t) % 5 == 0 and int(t - dt) % 5 != 0:
		var c := host.combat
		print("[%3.0f초] %s %s 단계 %d HP %.0f 무기 %s 대화 %s 바쁨 %s 표적 %d/%d 바퀴 %d" % [t, host.map.id, host.player.loco.render,
			host.st.quests.stage("MQ-P2"), c.pc.hp, c.weapon_id, host.box.active, host.busy or host.ev.busy(),
			c.targets_left("target"), c.targets_left("stealth"), c.alive_enemies()])
	var box := host.box
	if host.pipboy != null:
		_pip_bot(dt)
		return
	if box.active and not box.waiting_cmd:
		_stop()
		host.combat.bot = {"walk": true}                                   # 봇이지만 조준은 하지 않는다(걷는 쪽을 본다)
		match box.state.get("type", ""):
			"line":
				if box.reveal >= box.page_len:
					hold += dt
					if hold > 0.8:
						hold = 0.0
						if box.state.get("who", "") in ["N-R01-010", "C-002", "C-023", "C-027"] or box.state.get("text", "").contains("하나 잡아"):
							_shot(str(box.state.get("who", "")))
						box.next()
			"choices":
				hold += dt
				if hold > 1.4:
					hold = 0.0
					_shot("choices")
					if host.st.quests.stage("MQ-P2") == 40:
						box.pick(_by_text(box.state.get("opts", []), JIWOO_KEYS[jiwoo - 1]))
					else:
						box.pick(pick - 1)
		return
	if host.busy or host.ev.busy():
		return
	if phase == "P1S2":
		_p1_bot()
	elif phase == "P2":
		_p2_bot()


## 지우 장면 선택지(원고 차례 1~6)를 문장으로 찾는다 — 조건이 안 맞는 줄은 숨어서 번호가 밀린다
const JIWOO_KEYS := ["간식 쿠폰을 준다", "재발급", "바닥 틈", "주변을 찾아본다", "지나친다", "남은 쿠폰"]


func _by_text(opts: Array, key: String) -> int:
	for i in opts.size():
		if str(opts[i]["text"]).contains(key) and opts[i]["enabled"]:
			return i
	return opts.size() - 2 if opts.size() >= 2 else 0


func _pip_bot(dt: float) -> void:
	_pip_t += dt
	var p := host.pipboy
	var k := int(_pip_t / 1.1)
	if _pip_t > 0.6 and k != int((_pip_t - dt) / 1.1):
		_shot("pip%d" % k)
		match k:
			1: p._sub(1)
			2: p._sub(1)
			3: p._tab(1)
			4: p._tab(2)
			5: p.close(true)


func _p1_bot() -> void:
	if not talked:
		var n := _npc("N-R01-010")
		if n.is_empty():
			talked = true
			return
		var to: Vector2 = n["actor"].loco.logical + Vector2(-32, 0)
		if NpcRoutine.arrived(host.player.loco.render, to):
			_stop()
			host.player.loco.facing = 0
			host.player._show()
			talked = host.interact()
		else:
			_move_to(to)
		return
	_move_to(host.map.mark_pos("dol_front"))


## MQ-P2 봇: 단계마다 갈 곳(맵·표지)과 할 일
func _p2_bot() -> void:
	var st := host.st
	var c := host.combat
	var s := st.quests.stage("MQ-P2")
	c.bot = {"walk": true}
	match s:
		20:
			_go("V-01", "bday_front")
		30:
			_go("V-02", "p2_window")
		40:
			var met := host.fired.has("V-01:37,30")
			if int(st.vars.get_v("MQP2_RESULT")) == 0 and not (met and jiwoo != 4):
				if jiwoo == 4 and met:
					_crack()                                                 # 조사 3회 길
				else:
					_go("V-01", "p2_ration")
			else:
				_go("V-09", "p2_range")                                      # (화술 실패로 결과 없이 떠나도 된다)
		50:
			_range()
		60:
			if host.map.id != "V-11" or not host.fired.has("V-11:10,15"):
				_go("V-11", "p2_pipe")
			else:
				_pipe()


## 조사 3회 길(--jiwoo=4 → '주변을 찾아본다' 뒤): 바닥 틈 앞에서 아래를 보고 조사
func _crack() -> void:
	var to := Vector2(37 * 32 + 16, 38 * 32 + 16)
	if NpcRoutine.arrived(host.player.loco.render, to):
		_stop()
		host.player.loco.facing = 2
		host.player._show()
		host.interact()
	else:
		_move_to(to)


## 다른 맵의 표지까지: 지금 맵이 아니면 다음 출구로, 맞으면 표지로
func _go(map_id: String, mark: String) -> void:
	var goal: Vector2
	if host.map.id != map_id:
		var e := MapGraph.next_exit(host.map.id, map_id)
		if e.x < 0:
			return
		goal = Vector2(e.x * 32 + 16, e.y * 32 + 16)
	else:
		goal = host.map.mark_pos(mark)
	_move_to(goal)


## 사격장: 1부 사대에서 표적마다 쏜다 → 2부 웅크려 모래주머니 뒤로 가서 은신 표적
func _range() -> void:
	var c := host.combat
	if host.map.id != "V-09":
		_go("V-09", "p2_range")
		return
	var live: Array = c.targets.filter(func(x): return not x["down"] and (x["kind"] == "target" or (stealth_started and x["live"])))
	if live.is_empty():
		_stop()
		return
	var normal: Array = live.filter(func(x): return x["kind"] == "target")
	var tgt: Dictionary = normal.front() if not normal.is_empty() else live.front()
	var stand: Vector2
	var crouch := false
	var aim: Vector2 = tgt["cmb"].pos() + Vector2(0, -4)
	if tgt["kind"] == "stealth":
		crouch = true
		stand = host.map.mark_pos("sneak_1" if int(tgt["prop"]["y"]) < 16 else "sneak_2")
		if tgt["seen_t"] > 0.0:                                          # 들켰다: 모래주머니 뒤에서 기다린다
			_move_to(stand)
			c.bot = {"walk": true, "crouch": true}
			return
	else:                                                                 # 사대(x 30)의 세 자리 가운데 표적과 가까운 곳에서 비스듬히 쏜다
		var ty := int(tgt["prop"]["y"])                                   # (BB총 최대 사거리 12.25칸 — 맨 끝 표적은 앞 자리에서)
		var lane := 9 if ty <= 11 else (22 if ty >= 21 else 16)
		stand = Vector2(30 * 32 + 16, lane * 32 + 16)
	if host.player.loco.logical.distance_to(stand) > 6.0:
		_move_to(stand)
		c.bot = {"walk": true, "crouch": crouch}                          # 자리로 가는 동안은 조준하지 않는다(뒷걸음 없이 걷는다)
		return
	_stop()
	c.bot = {"aim": aim, "fire": true, "crouch": crouch, "aimed": true}


## 배관실: HP가 60% 밑이면 스팀팩(단축키 3), 가장 가까운 바퀴에게 다가가 휘두른다
func _pipe() -> void:
	var c := host.combat
	var me := host.player.loco.logical
	if c.pc.hp < c.pc.max_hp * 0.6 and not c.healing() and int(host.st.items.get(InteriorCombat.STIMPAK, 0)) > 0 and c.inject_t <= 0.0:
		c.hotkey(3, host.st)
		_stop()
		return
	if c.weapon_id != "W-067":
		c.equip("W-067", host.st)
	var best: Enemy = null
	var bd := 1e9
	for e in c.enemies:
		if is_instance_valid(e) and not e.cmb.dead and me.distance_to(e.loco.logical) < bd:
			bd = me.distance_to(e.loco.logical)
			best = e
	if best == null:
		_stop()
		return
	var reach := float(c.weapon()["range_eff"]) * 32.0
	if bd > reach + best.cmb.radius - 4.0:
		_move_to(best.loco.logical)
		c.bot = {"aim": best.loco.logical + Vector2(0, -6)}
	else:
		_stop()
		c.bot = {"aim": best.loco.logical + Vector2(0, -6), "fire": true}


func _npc(id: String) -> Dictionary:
	for n in host.npcs:
		if n["id"] == id:
			return n
	return {}


## 봇 이동: 목표만 정해 두면 진행기가 1/60초마다 _bot_input을 불러 길을 따라간다(긴 프레임에서도 칸 가운데를 지나치지 않는다)
var bot_goal := Vector2.INF


func _move_to(goal: Vector2) -> void:
	bot_goal = goal
	host.input_fn = _bot_input


func _stop() -> void:
	bot_goal = Vector2.INF


func _bot_input() -> Vector2:
	if bot_goal == Vector2.INF or host.map == null:
		return Vector2.ZERO
	return _follow(bot_goal)


## 길찾기 경로를 따라가는 입력. 목표가 바뀌었거나 3초마다(움직이는 인물이 길을 막으면) 다시 찾는다
func _follow(goal: Vector2) -> Vector2:
	var p := host.player.loco.render
	if path.is_empty() or host.map.tile_of(path_goal) != host.map.tile_of(goal) or t - _re_t > 3.0:
		_re_t = t
		path = NpcRoutine.with_start(host.map, p, goal)
		path_goal = goal
	while path.size() > 0 and NpcRoutine.arrived(p, path[0]):
		path.remove_at(0)
	if path.is_empty():
		return Vector2.ZERO
	return NpcRoutine.step_dir(p, path[0])
