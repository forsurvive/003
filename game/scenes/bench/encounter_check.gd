## 인카운터 확인 장면(단계 1-3 → 1-E): MQ-101이 끝난 1막, 신림 사거리 고가(L-R01-15) 둘레에서 RE를 바로 세운다.
## 실행: godot --path game res://scenes/bench/encounter_check.tscn -- [talk|fight|leave|roach|capture] 또는
##        -- RE-ID 상황 [시] [고를 선택지] [스크린샷 폴더]   (예: -- RE-002 S4 23 0 /tmp/shots)
## talk = 다가와 말을 걸 때까지 · fight = '덤벼 봐' → 교전 · leave = [화술] 성공 처리 → 물러남 · roach = 밤 RE-004 · capture = 교전 중 HP 0 → 생포
## RE 모드(1-E): 흔적 뒤 본체가 서면 주인공이 그쪽으로 7타일까지 걸어가 보고(스크린샷), 대화가 열리면 정한 선택지를 고른다.
extends Node

var host: InteriorHost
var mode := "talk"
var re := ""
var state := ""
var hour := 9
var pick_i := 0
var shots := ""
var t := 0.0
var picked := false
var log_t := 0.0
var shot_n := 0
var shot_at := [3.0, 9.0, 16.0, 26.0, 40.0]
var saw := {}
var path := PackedVector2Array()
var kill_t := 2.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "talk"
	if mode.begins_with("RE-"):
		re = mode
		state = args[1] if args.size() > 1 else ""
		hour = int(args[2]) if args.size() > 2 else 9
		pick_i = int(args[3]) if args.size() > 3 else 0
		shots = args[4] if args.size() > 4 else ""
		mode = "re"
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.quests.set_stage("MQ-101", 50)
	st.vars.set_v("MQ101_NIGHT", 3)
	st.vars.set_v("MQ101_RESULT", 1)
	st.vars.set_v("GAME_DAY", 2)
	st.vars.set_v("PC_CAPS", 120)
	Wanted.set_value(st, 10)
	st.events.clear()
	st.quests.events.clear()
	st.call_fn("give", ["W-002"])
	st.call_fn("give", ["10mm 탄", 60])
	st.call_fn("give", ["I-001", 3])
	st.call_fn("give", ["I-055", 2])
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	var hh := hour if mode == "re" else (22 if mode == "roach" else 9)
	host.date_text = "2277. 10. 24.  %02d:%s" % [hh, "10" if mode == "roach" else "20"]
	host.enter("W", "", {}, Vector2(833 * 32 + 16, 1343 * 32 + 16))      # 신림 사거리 고가(L-R01-15) 도착 칸
	host.combat.equip("W-002", st)
	st.events.clear()
	host.ev.handlers["trade"] = func(a: Array, done: Callable) -> void:  # 1막 진행기 대신(벤치): 거래 창
		host.open_trade(str(a[0]), func(_c: int) -> void: done.call())
	host.enc_live.ended.connect(func(r, how): print("인카운터 끝: %s %s" % [r, how]))
	host.pc_died.connect(func(): print("쓰러짐"))
	host.combat.player_down.connect(host.on_pc_down)
	var req := {"re": re, "src": "bench", "state": state} if mode == "re" else {"re": "RE-004" if mode == "roach" else "RE-087", "src": "bench"}
	host.enc_live._ctx(host.map.tile_of(host.player.loco.logical))
	var ok := host.enc_live.start(req)
	print("인카운터 세움: ", ok, " · ", host.enc_live.cur.get("re", ""), " ", host.enc_live.cur.get("state", ""), " · 단계 ", host.enc_live.cur.get("phase", ""))


func _process(dt: float) -> void:
	t += dt
	log_t += dt
	var c := host.enc_live.cur
	if log_t >= 1.0:
		log_t = 0.0
		var lead := ""
		if not c.get("actors", []).is_empty() and is_instance_valid(c["actors"][0]):
			var a: Actor = c["actors"][0]
			lead = " · 앞장 %.1f타일" % [a.loco.logical.distance_to(host.player.loco.logical) / 32.0]
		var teams := {}
		for e in host.combat.enemies:
			if is_instance_valid(e) and not e.cmb.dead:
				teams[e.cmb.team] = int(teams.get(e.cmb.team, 0)) + 1
		print("[%4.1f초] %s %s · 단계 %s · 대화 %s · HP %d · 편 %s · 용기 %d%s" % [t, str(c.get("re", "-")), str(c.get("state", "-")),
			str(c.get("phase", "-")), str(host.box.active), int(host.combat.pc.hp), str(teams), host.map.boxes.size(), lead])
	if host.box.active:
		var s: Dictionary = host.box.state
		if s.get("type", "") == "line":
			if fmod(t, 0.8) < dt:
				if not saw.has(str(s.get("text", ""))):
					saw[str(s.get("text", ""))] = true
					print("  대사: ", s.get("who", ""), " ", s.get("text", ""))
					if shots != "" and saw.size() == 2:
						_shot("talk")
				host.box.next()
		elif s.get("type", "") == "choices" and not picked and t > 0.5:
			picked = true
			if shots != "":
				_shot("choice")
			host.box.pick((1 if mode == "leave" else 0) if mode != "re" else pick_i)
	if mode == "capture" and host.enc_live.cur.get("state", "") == "fight" and host.combat.pc.hp > 0.0 and t > 6.0:
		host.combat.pc.take({"hp": host.combat.pc.hp + 5.0}, host.player.loco.logical)   # 생포 확인: 쓰러뜨린다
	if mode == "re":
		_walk_to_scene()
		if kill_t >= 0.0:                                                # 주인공이 싸운 셈(벤치): 교전에 든 적대를 차례로 쓰러뜨린다
			kill_t -= get_process_delta_time()
			if kill_t <= 0.0:
				kill_t = 1.5
				for e in host.combat.enemies:
					if is_instance_valid(e) and not e.cmb.dead and "player" in e.foes and e.brain.state == AIBrain.S.COMBAT \
							and e.loco.logical.distance_to(host.player.loco.logical) < 12.0 * 32.0:
						e.cmb.last_by = "player"
						e.cmb.take({"hp": 9999.0}, host.player.loco.logical)
						print("  [벤치] 처치 ", e.get_meta("enemy_id", ""))
						break
		if shots != "" and shot_n < shot_at.size() and t >= float(shot_at[shot_n]):
			_shot("t%02d" % int(t))
			shot_n += 1


## 본체가 서면 그 자리 7타일 앞까지 걸어간다(장면을 화면에 담는다)
func _walk_to_scene() -> void:
	var c := host.enc_live.cur
	if c.is_empty() or str(c.get("phase", "")) != "live" or host.box.active:
		host.input_fn = func() -> Vector2: return Vector2.ZERO
		return
	var goal: Vector2 = Vector2(c["center"]) * 32.0 + Vector2(16, 16)
	var p: Vector2 = host.player.loco.logical
	var near := 7.0
	if not c.get("actors", []).is_empty() and is_instance_valid(c["actors"][0]) and bool(c["actors"][0].get_meta("wait", false)):
		near = 3.0                                                      # 기다리는 사람(누운 민병·야영 상인)에게는 곁까지
	if (c.get("note", Vector2i(-1, -1)) as Vector2i).x >= 0:
		var side: Array = host.enc_live._cluster(c["note"], 2)          # 쪽지 유해: 옆 빈 칸까지
		goal = Vector2(side[-1] if not side.is_empty() else c["note"]) * 32.0 + Vector2(16, 16)
		near = 0.3
	if p.distance_to(goal) <= near * 32.0:
		host.input_fn = func() -> Vector2: return Vector2.ZERO
		return
	if path.is_empty() or fmod(t, 1.0) < get_process_delta_time():
		path = NpcRoutine.with_start(host.map, p, goal)
	while path.size() > 0 and (NpcRoutine.arrived(p, path[0]) or (path.size() > 1 and p.distance_to(path[1]) <= path[0].distance_to(path[1]) + 2.0)):
		path.remove_at(0)
	var d := (goal - p).normalized() if path.is_empty() else NpcRoutine.step_dir(p, path[0])
	host.input_fn = func() -> Vector2: return d


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(shots)
	img.save_png("%s/%s_%s_%s.png" % [shots, re, state, tag])
