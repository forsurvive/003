## 벤치 씬 (SD-19 §5.2 측정 9항목 중 자동 측정 가능한 1~5, §6.17).
## godot --path game res://scenes/bench/bench.tscn  ->  각 항목을 차례로 돌리고 결과를 출력·user://bench_report.json에 남긴다.
## 주의: 이 수치는 실행한 기계의 것이다. 합격 판정은 PC 기준 기기·모바일 중급 기기 실측으로 한다(§10.3).
extends Node2D

const SECS := 6.0
var world: ChunkWorld
var report := {}
var _stage := 0
var _t := 0.0
var _frame_ms: Array = []
var _work_us: Array = []
var _actors: Array = []
var shots: Projectiles
var _expl: Array = []
var _rng := RandomNumberGenerator.new()
var _dirs := {}
var _dolls: Array = []
var _target := Combatant.new()
var _enemies: Array = []
var nav := NavGrid.new()
var _last_us := 0
var cam: Camera2D
var _chase_x := 0.0
var label: Label


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_rng.seed = 7
	world = ChunkWorld.new()
	world.y_sort_enabled = true
	add_child(world)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	var c: Vector2 = Vector2(world.index["spawns"]["player"][0], world.index["spawns"]["player"][1]) * 32.0
	cam.position = c
	for i in 30:                                                    # warm up: let the 5×5 chunks attach
		world.update_focus(c)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(4, 4)
	layer.add_child(label)
	_begin(0)


func _begin(stage: int) -> void:
	_stage = stage
	_t = 0.0
	_frame_ms.clear()
	_work_us.clear()
	_last_us = Time.get_ticks_usec()
	var c := cam.position
	match stage:
		0:                                                          # ① 24명 + 투사체 128 + 폭발 4
			shots = Projectiles.new()
			shots.world = world
			world.add_child(shots)
			for i in 24:
				var a := Actor.new()
				a.setup(["pc_comp_t01_pf00_loco", "pc_comp_t06_pf01_loco", "pc_comp_t03_pf00_loco"][i % 3],
					c + Vector2(_rng.randf_range(-280, 280), _rng.randf_range(-150, 150)), world)
				world.add_child(a)
				_actors.append(a)
				_dirs[a] = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
		1:                                                          # ② AI 40명: 근경 16(매 프레임) + 중경 24(0.5초)
			_clear_actors()
			var rows: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
			var weps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
			nav.rebuild(world, world.chunk_of_px(c), world.cs)
			var dummy := Actor.new()
			dummy.setup("pc_comp_t01_pf00_loco", c, world)
			world.add_child(dummy)
			_target.actor = dummy
			_actors.append(dummy)
			for i in 40:
				var e := Enemy.new()
				var r: float = 6.0 * 32 if i < 16 else 22.0 * 32
				var ang := TAU * i / 40.0
				e.setup_enemy(rows["CR-401" if i % 2 else "CR-002"], weps["W-002"], c + Vector2.RIGHT.rotated(ang) * r, world)
				world.add_child(e)
				_enemies.append(e)
				_actors.append(e)
		2:                                                          # ③ 경로 64×64 구역 1건
			_clear_actors()
		3:                                                          # ④ 페이퍼돌 × 24명: 몸·몸통 인덱스 시트 + 머리 앵커 층 3 + 팔레트 셰이더
			var looks := [{"hair": "HR05", "gear": "HD05", "eyes": "EY01"}, {"torso": "T06", "gear": "HD04", "faction": "PF-01", "eyes": "EY05"},
				{"torso": "T02", "hair": "HR08", "gear": "HD03", "eyes": "EY01"}, {"torso": "T03", "hair": "HR09", "gear": "HD02", "eyes": "EY05"}]
			for i in 24:
				var d := Paperdoll.new()
				d.set_look(looks[i % 4])
				d.position = c + Vector2(-280 + (i % 8) * 70, -100 + (i / 8) * 90)
				world.add_child(d)
				_dolls.append(d)
		4:                                                          # ⑤ 청크 경계 교전 추격
			for d in _dolls:
				d.queue_free()
			_dolls.clear()
			var b := (world.chunk_of_px(cam.position).x + 1) * world.cs * 32.0
			_chase_x = b - 6.0 * 32.0                                  # 경계 6타일 앞에서 출발, 왕복마다 경계를 넘는다


func _clear_actors() -> void:
	for a in _actors:
		a.queue_free()
	_actors.clear()
	_enemies.clear()
	if shots:
		shots.shots.clear()


func _process(dt: float) -> void:
	var now := Time.get_ticks_usec()
	_frame_ms.append((now - _last_us) / 1000.0)
	_last_us = now
	_t += dt
	var w0 := Time.get_ticks_usec()
	match _stage:
		0:
			for a in _actors:
				var v: Vector2 = _dirs[a]
				if _rng.randf() < 0.01:
					_dirs[a] = Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1))
				a.move(v, dt)
			while shots.shots.size() < 128:
				shots.fire(cam.position + Vector2(_rng.randf_range(-300, 300), _rng.randf_range(-160, 160)),
					_rng.randf() * 360.0, 200.0, "bench", {"range_max": 14.0, "dmg": 1.0}, 50)
			shots.step(dt)
			if _expl.size() < 4:
				_expl.append([cam.position + Vector2(_rng.randf_range(-250, 250), _rng.randf_range(-120, 120)), 0.0])
			for e in _expl:
				e[1] += dt
			_expl = _expl.filter(func(e): return e[1] < 0.6)
			queue_redraw()
		1:
			nav.new_frame()
			for i in _enemies.size():
				var e: Enemy = _enemies[i]
				if i < 16 or (Engine.get_process_frames() + i) % 30 == 0:
					e.think(dt if i < 16 else 0.5, _target, nav, shots)
		2:
			if _work_us.is_empty():
				var g := AStarGrid2D.new()
				g.region = Rect2i(0, 0, 64, 64)
				g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
				g.jumping_enabled = true
				g.update()
				for k in 64 * 64 / 5:
					g.set_point_solid(Vector2i(_rng.randi_range(1, 62), _rng.randi_range(1, 62)), true)
				for q in 200:
					var t0 := Time.get_ticks_usec()
					g.get_point_path(Vector2i(0, 0), Vector2i(63, 63), true)
					_work_us.append(Time.get_ticks_usec() - t0)
				_t = SECS
		3:                                                         # 매 프레임 프레임·방향 갱신 + 2초마다 1명 장비 교체
			var f := int(Engine.get_process_frames() / 4) % 6
			for i in _dolls.size():
				_dolls[i].show_frame("walk", (i + int(_t)) % 8, f)
			if Engine.get_process_frames() % 120 == 0:
				_dolls[_rng.randi() % 24].set_look({"hair_color": ["H1", "H4", "H6"][_rng.randi() % 3]})
		4:
			_chase_x += 6.5 * 32.0 * dt * (1.0 if int(_t / 1.5) % 2 == 0 else -1.0)   # 질주 속도로 청크 경계 왕복
			cam.position.x = _chase_x
			world.update_focus(cam.position)
	if _stage != 2:
		_work_us.append(Time.get_ticks_usec() - w0)
	label.text = "벤치 %d/5  %.1f초" % [_stage + 1, _t]
	if _t >= SECS:
		_finish()


func _draw() -> void:
	if _stage != 0:
		return
	for e in _expl:
		var r: float = 8.0 + e[1] * 60.0
		draw_circle(e[0] - position, r, Color("ffc24a"))
		draw_circle(e[0] - position, r * 0.6, Color("ffec9a"))


func _finish() -> void:
	var names := ["1_render_24_proj128_expl4", "2_ai_40", "3_path_64x64", "4_paperdoll_6x24", "5_chunk_chase"]
	var fm := _frame_ms.slice(10)
	fm.sort()
	var avg := 0.0
	for x in fm:
		avg += x
	avg /= maxi(1, fm.size())
	var wk := _work_us.duplicate()
	wk.sort()
	var wavg := 0.0
	for x in wk:
		wavg += x
	wavg /= maxi(1, wk.size())
	var r := {"frames": fm.size(), "avg_fps": snappedf(1000.0 / maxf(avg, 0.001), 0.1),
		"low1_fps": snappedf(1000.0 / maxf(fm[int(fm.size() * 0.99)] if fm.size() > 0 else 1.0, 0.001), 0.1),
		"max_frame_ms": snappedf(fm[fm.size() - 1] if fm.size() > 0 else 0.0, 0.01),
		"work_avg_ms": snappedf(wavg / 1000.0, 0.001), "work_max_ms": snappedf((wk[wk.size() - 1] if wk.size() > 0 else 0) / 1000.0, 0.001)}
	if _stage == 4:
		r["attach_max_ms"] = snappedf(world.attach_usec_max / 1000.0, 0.01)
		r["chunks_attached"] = world.attach_count
	report[names[_stage]] = r
	print("%s: %s" % [names[_stage], JSON.stringify(r)])
	if _stage < 4:
		_begin(_stage + 1)
	else:
		report["machine"] = "%s / %s / %s" % [OS.get_name(), OS.get_processor_name(), RenderingServer.get_video_adapter_name()]
		var f := FileAccess.open("user://bench_report.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(report, " ", true))
		f.close()
		print("벤치 끝: user://bench_report.json")
		get_tree().quit()
