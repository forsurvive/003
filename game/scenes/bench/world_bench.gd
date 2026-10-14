## 단계 1-1 월드 성능 측정(SD-19 §10.4·§6.5 '청크 붙이기 1회 4ms 이하'): 실제 진행기로 관악산 비탈(X-S07)에 들어가
## 굽기가 찾은 월드 길을 따라 봉천(X-BC)까지 걸어간다 — 청크 수십 개가 붙고 떨어지며 건물·나무·그림자가 화면을 채운다.
## 5초 예열 뒤 secs초 동안 프레임 시간·스크립트 시간·그리기 호출·청크 붙이기 시간을 잰다.
## godot --path game res://scenes/bench/world_bench.tscn [-- --secs=30]  →  출력 + user://world_bench.json
## 주의: 수치는 실행한 기계의 것(이 개발 환경은 GPU 없는 소프트웨어 렌더러). 합격 판정은 §10.3 기준 기기 실측으로 한다.
extends Node

var host: InteriorHost
var secs := 30.0
var warm := 5.0
var t := 0.0
var frames: Array = []
var script_ms: Array = []
var draws: Array = []
var way: Array = []
var way_i := 0
var path := PackedVector2Array()
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
		if a.begins_with("--secs="):
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
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		host.st.quests.set_stage(q, 100)
	host.body = "adult"
	host.hud_on = true
	host.enter("X-S07", "start")
	var wm: WorldMap = host.map
	way = wm.route_between("X-S07", "X-BC")
	print("월드 벤치: 경유점 %d · 측정 %.0f초" % [way.size(), secs])


func _process(dt: float) -> void:
	t += dt
	_walk_player()
	if t < warm:
		return
	frames.append(dt * 1000.0)
	script_ms.append(float(_proc_us + _phys_us) / 1000.0)
	_phys_us = 0
	draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if t >= warm + secs:
		_report()
		set_process(false)
		get_tree().quit()


## 주인공: 경유점 사이를 칸 길찾기로 걷는다(MQ-101 봇과 같은 입력 — 축마다 맞추고 지난 칸은 건너뛴다)
func _walk_player() -> void:
	if OS.get_environment("BENCH_DEBUG") != "" and int(t * 2) != int((t - get_process_delta_time()) * 2):
		print("  %.1f초 칸 %s 경유점 %d 길 %d" % [t, host.map.tile_of(host.player.loco.logical), way_i, path.size()])
	if host.input_fn.is_null():
		host.input_fn = _bot_input


func _bot_input() -> Vector2:
	if way_i >= way.size():
		return Vector2.ZERO
	var g := Vector2(int(way[way_i][1]) * 32 + 16, int(way[way_i][2]) * 32 + 16)
	var p := host.player.loco.render
	if p.distance_to(g) < 6.0:
		way_i += 1
		path = PackedVector2Array()
		return Vector2.ZERO
	if path.is_empty():
		path = NpcRoutine.with_start(host.map, p, g)
	while path.size() > 0 and (NpcRoutine.arrived(p, path[0]) or (path.size() > 1 and p.distance_to(path[1]) <= path[0].distance_to(path[1]) + 2.0)):
		path.remove_at(0)
	if path.is_empty():
		return (g - p).normalized() if p.distance_to(g) > 2.0 else Vector2.ZERO
	return NpcRoutine.step_dir(p, path[0])


func _pct(a: Array, p: float) -> float:
	var s := a.duplicate()
	s.sort()
	return s[clampi(int(p * (s.size() - 1)), 0, s.size() - 1)]


func _report() -> void:
	var wm: WorldMap = host.map
	var avg := 0.0
	for f in frames:
		avg += f
	avg /= maxf(1.0, frames.size())
	var sc := 0.0
	for f in script_ms:
		sc += f
	sc /= maxf(1.0, script_ms.size())
	var r := {"zone": wm.id, "tile": [wm.tile_of(host.player.loco.logical).x, wm.tile_of(host.player.loco.logical).y], "way": [way_i, way.size()],
		"frames": frames.size(), "fps_avg": 1000.0 / avg, "frame_ms_avg": avg, "frame_ms_p95": _pct(frames, 0.95), "frame_ms_max": _pct(frames, 1.0),
		"fps_p95_low": 1000.0 / _pct(frames, 0.95), "script_ms_avg": sc, "script_ms_p95": _pct(script_ms, 0.95),
		"draw_calls_avg": _pct(draws, 0.5), "draw_calls_max": _pct(draws, 1.0), "chunks_loaded": wm.chunks.size(),
		"attach_count": wm.attach_count, "attach_ms_max": wm.attach_usec_max / 1000.0,
		"renderer": RenderingServer.get_video_adapter_name(), "display": DisplayServer.get_name()}
	print("월드 벤치 결과: 평균 %.1f fps(%.2f ms) · 95%% 느린 프레임 %.2f ms(%.1f fps) · 최대 %.1f ms · 스크립트 평균 %.2f ms / 95%% %.2f ms · 그리기 호출 %d(최대 %d) · 청크 붙이기 %d회 최대 %.2f ms · 경유점 %d/%d · %s" % [
		r["fps_avg"], avg, r["frame_ms_p95"], r["fps_p95_low"], r["frame_ms_max"], sc, r["script_ms_p95"], int(r["draw_calls_avg"]), int(r["draw_calls_max"]),
		wm.attach_count, r["attach_ms_max"], way_i, way.size(), r["renderer"]])
	var f := FileAccess.open("user://world_bench.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(r, "  "))
	f.close()
