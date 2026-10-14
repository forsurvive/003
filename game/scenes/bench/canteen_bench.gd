## 단계 0-12 성능 측정(SD-19 §5.3 '성능 예산(§10.4) 준수: S-07 식당 장면(NPC 15명 이상)에서 PC 60fps·모바일 중급 55fps 이상').
## 실제 진행기(InteriorHost)로 V-01 아트리움 식당에 들어가, 2277년 주민에 더해 인물 16명이 일과(배식 창구 ↔ 식탁 ↔ 게시판)를
## 오가게 하고, 주인공은 식당을 한 바퀴 걷는다. 8초 예열 뒤 20초 동안 프레임 시간·스크립트(_process+_physics) 시간·그리기 호출을 잰다.
## godot --path game res://scenes/bench/canteen_bench.tscn [-- --npcs=16 --secs=20]  →  출력 + user://canteen_bench.json
## 주의: 수치는 실행한 기계의 것(이 개발 환경은 GPU 없는 소프트웨어 렌더러). 합격 판정은 §10.3 기준 기기 실측으로 한다.
extends Node

const SPOTS := [[14, 31], [35, 32], [39, 33], [40, 34], [14, 35], [44, 35], [20, 33], [26, 31], [30, 36], [10, 33]]

var host: InteriorHost
var n_npcs := 16
var secs := 20.0
var warm := 8.0
var t := 0.0
var frames: Array = []
var script_ms: Array = []
var draws: Array = []
var walk_i := 0
var _p0 := 0
var _f0 := 0
var _proc_us := 0
var _phys_us := 0


## 처리 단계 앞뒤 표지: 처음(우선순위 −1000)과 끝(+1000)에서 시각을 찍어 그 사이 모든 노드의 _process·_physics_process 시간을 잰다
class Mark extends Node:
	var bench
	var first := true
	func _process(_dt: float) -> void:
		if first:
			bench._p0 = Time.get_ticks_usec()
		else:
			bench._proc_us = Time.get_ticks_usec() - bench._p0
	func _physics_process(_dt: float) -> void:
		if first:
			bench._f0 = Time.get_ticks_usec()
		else:
			bench._phys_us += Time.get_ticks_usec() - bench._f0


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--npcs="):
			n_npcs = int(a.substr(7))
		elif a.begins_with("--secs="):
			secs = float(a.substr(7))
	for k in [true, false]:
		var m := Mark.new()
		m.bench = self
		m.first = k
		m.process_priority = -1000 if k else 1000
		m.process_physics_priority = -1000 if k else 1000
		add_child(m)
	host = InteriorHost.new()
	add_child(host)
	host.use_keyboard = false
	for q in ["MQ-P1", "MQ-P2", "MQ-P3"]:
		host.st.quests.set_stage(q, 100)
	host.st.quests.set_stage("MQ-P4", 10)                          # 2277년 아트리움(개방의 날 아침)
	host.body = "adult"
	host.hud_on = true
	host.enter("V-01", "p2_canteen")
	var ids: Array = host.ev.cast_sheets.keys().filter(func(k): return str(k).begins_with("N-R01-0"))
	ids.sort()
	var made := 0
	var i := 0
	while made < n_npcs and i < 200:
		var id := str(ids[i % ids.size()])
		var a: Array = SPOTS[i % SPOTS.size()]
		var b: Array = SPOTS[(i * 3 + 4) % SPOTS.size()]
		var c: Array = SPOTS[(i * 7 + 2) % SPOTS.size()]
		var off := Vector2i(i % 3 - 1, (i / 3) % 3 - 1)
		var start := Vector2i(a[0], a[1]) + off
		i += 1
		if host.map.is_solid(start):
			continue
		host._spawn_npc(1000 + made, {"id": "%s#%d" % [id, made], "x": start.x, "y": start.y, "dir": "S",
			"sheet": host.ev.cast_sheets[id], "route": [["가", b[0], b[1], 1.5], ["나", c[0], c[1], 1.5], ["다", start.x, start.y, 1.0]]})
		made += 1
	print("식당 벤치: 맵 %s · 인물 %d명(덧붙인 %d) · 측정 %.0f초" % [host.map.id, host.npcs.size(), made, secs])


func _process(dt: float) -> void:
	t += dt
	_walk_player()
	if t < warm:
		return
	frames.append(dt * 1000.0)
	script_ms.append(float(_proc_us + _phys_us) / 1000.0)                # 지난 프레임의 스크립트(처리+물리) 시간
	_phys_us = 0
	draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if t >= warm + secs:
		_report()
		set_process(false)
		get_tree().quit()


## 주인공: 식당 지점을 차례로 걸어 돈다(카메라가 따라가며 인물이 화면 안팎을 드나들게)
func _walk_player() -> void:
	var goal: Array = SPOTS[walk_i % SPOTS.size()]
	var g := Vector2(goal[0] * 32 + 16, goal[1] * 32 + 16)
	var d := g - host.player.loco.logical
	if d.length() < 12.0:
		walk_i += 1
	host.input_vec = d.normalized() if d.length() > 4.0 else Vector2.ZERO


func _pct(a: Array, p: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(p * (s.size() - 1)), 0, s.size() - 1)]


func _report() -> void:
	var avg := 0.0
	for f in frames:
		avg += f
	avg /= maxf(1.0, frames.size())
	var sc := 0.0
	for f in script_ms:
		sc += f
	sc /= maxf(1.0, script_ms.size())
	var r := {"map": host.map.id, "people": host.npcs.size(), "frames": frames.size(), "fps_avg": 1000.0 / avg,
		"frame_ms_avg": avg, "frame_ms_p95": _pct(frames, 0.95), "frame_ms_max": _pct(frames, 1.0), "fps_p95_low": 1000.0 / _pct(frames, 0.95),
		"script_ms_avg": sc, "script_ms_p95": _pct(script_ms, 0.95), "draw_calls_avg": _pct(draws, 0.5), "draw_calls_max": _pct(draws, 1.0),
		"renderer": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name()}
	print("식당 벤치 결과: 평균 %.1f fps(%.2f ms) · 95%% 느린 프레임 %.2f ms(%.1f fps) · 스크립트 평균 %.2f ms / 95%% %.2f ms · 그리기 호출 %d(최대 %d) · %s" % [
		r["fps_avg"], avg, r["frame_ms_p95"], r["fps_p95_low"], sc, r["script_ms_p95"], int(r["draw_calls_avg"]), int(r["draw_calls_max"]), r["renderer"]])
	var f := FileAccess.open("user://canteen_bench.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(r, "  "))
	f.close()
