## 고가 확인 장면(단계 1-Rd·Re, SD-21 §6): 신림 사거리 고가(L-R01-15) 둘레에서 주인공이 걸어서
##   ① 램프 아래 끝 땅 → ② 램프를 올라 상판(층 1) → ③ 상판 위를 걷다 → ④ 저장 왕복(층 유지) → ⑤ 램프로 내려와 상판 아래 그늘(층 0, 디더)
## 을 차례로 지나며 스크린샷을 찍고 층을 확인한다. 끊긴 경간이 둘레에 있으면 그 끝까지 가서 멈추는지도 본다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/deck_check.tscn -- [스크린샷 폴더] [가운데 x y]
extends Node

var host: InteriorHost
var shots := ""
var plan: Array = []                    ## [["go", 칸, 층 또는 -1, 이름] | ["shot", 이름] | ["save"] | ["check", 식 설명]]
var step := 0
var step_t := 0.0
var path := PackedVector2Array()
var goal := Vector2.ZERO
var checks: Array = []
var center := Vector2i(833, 1343)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	if args.size() > 2:
		center = Vector2i(int(args[1]), int(args[2]))
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.quests.set_stage("MQ-101", 50)
	st.vars.set_v("MQ101_RESULT", 1)
	st.vars.set_v("GAME_DAY", 2)
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	host.date_text = "2277. 10. 24.  10:20"
	host.enter("W", "", {}, Vector2(center) * 32.0 + Vector2(16, 16))
	host.story_hold = true                                              # 인카운터 판정 끔(벤치)
	var m: WorldMap = host.map
	# 둘레 60칸에서 램프 아래 끝(땅과 맞닿은 램프 칸)과 상판 칸·끊긴 끝을 찾는다
	var foot := Vector2i(-1, -1)
	var outside := Vector2i(-1, -1)
	var decks: Array = []
	var broken := Vector2i(-1, -1)
	for cy in range(-2, 3):                                              # 둘레 청크를 한 번씩만 붙인다
		for cx in range(-2, 3):
			m.load_now(Vector2(center + Vector2i(cx, cy) * 40) * 32.0)
	for r in range(0, 60):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := center + Vector2i(dx, dy)
				var d := m.deck_at(c)
				if d == InteriorMap.DK_RAMP and foot.x < 0:
					for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var o: Vector2i = c + n
						if m.deck_at(o) == InteriorMap.DK_NONE and not m.is_solid(o) and not InteriorMap.is_top(m.deck_at(o + n)) and not m.is_solid(o + n):
							foot = c
							outside = o + n
							break
				elif d == InteriorMap.DK_DECK and decks.size() < 400:
					decks.append(c)
				elif d == InteriorMap.DK_BROKEN and broken.x < 0:
					broken = c
	print("램프 아래 끝 ", foot, " 바깥 ", outside, " 상판 칸 ", decks.size(), " 끊긴 끝 ", broken)
	if foot.x < 0 or decks.is_empty():
		print("고가 없음 — 끝")
		get_tree().quit()
		return
	var far: Vector2i = decks[0]
	for c in decks:                                                       # 램프 아래 끝에서 12~22칸 떨어진 상판 칸
		var dd := Vector2(c - foot).length()
		if dd > 12 and dd < 22:
			far = c
			break
	var under := far
	for c in decks:                                                       # 그늘 목표: 상판 칸이되 지금 자리에서 6~12칸, 아래 땅이 걸을 수 있는 곳
		var dd := Vector2(c - far).length()
		if dd > 6 and dd < 12 and not m.is_solid(c):
			under = c
			break
	host.player.loco.place(Vector2(outside) * 32.0 + Vector2(16, 16))
	host.player.set_floor(0)
	host.map.load_now(host.player.loco.logical)
	plan = [["shot", "1_ground"], ["go", foot, -1, "램프"], ["shot", "2_ramp"], ["go", far, 1, "상판"], ["shot", "3_deck"],
		["check", "on_deck"], ["save"], ["check", "saved"]]
	if broken.x >= 0:
		plan += [["go", broken, 1, "끊긴 끝"], ["shot", "4_broken"], ["push", broken], ["check", "stopped"]]
	plan += [["go", under, 0, "그늘"], ["shot", "5_under"], ["check", "under"]]


func _process(dt: float) -> void:
	if plan.is_empty() or step >= plan.size():
		return
	step_t += dt
	var s: Array = plan[step]
	match str(s[0]):
		"shot":
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			if step_t > 0.6:
				_shot(str(s[1]))
				_next()
		"go":
			var g := Vector2(s[1]) * 32.0 + Vector2(16, 16)
			if path.is_empty() and step_t < 0.05:
				path = host.map.path(host.player.loco.logical, g, 9000, host.player.floor_id, int(s[2]))
				print("  길 %s: %d칸 (층 %d → %d)" % [s[3], path.size(), host.player.floor_id, int(s[2])])
			host.input_fn = _walk.bind(g)
			if host.player.loco.logical.distance_to(g) < 6.0 or step_t > 45.0:
				print("  %s 도착: %s 층 %d (%.1f초)" % [s[3], host.map.tile_of(host.player.loco.logical), host.player.floor_id, step_t])
				_next()
		"push":                                                           # 끊긴 끝에서 빈 경간 쪽으로 2초 민다 — 서야 한다
			var b: Vector2i = s[1]
			var dir := Vector2.ZERO
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if host.map.deck_at(b + n) == InteriorMap.DK_NONE and not InteriorMap.is_top(host.map.deck_at(b + n)):
					dir = Vector2(n)
			if step_t < 0.05:
				set_meta("p0", host.player.loco.logical)
			host.input_fn = func() -> Vector2: return dir
			if step_t > 2.0:
				set_meta("p1", host.player.loco.logical)
				_next()
		"save":
			var d := GameSnapshot.host(host)
			host.player.set_floor(0)
			GameSnapshot.apply_host(host, d)
			_next()
		"check":
			var ok := false
			match str(s[1]):
				"on_deck":
					ok = host.player.floor_id == 1 and InteriorMap.is_top(host.map.deck_at(host.map.tile_of(host.player.loco.logical)))
				"saved":
					ok = host.player.floor_id == 1
				"stopped":
					var p0: Vector2 = get_meta("p0")
					var p1: Vector2 = get_meta("p1")
					ok = host.player.floor_id == 1 and InteriorMap.is_top(host.map.deck_at(host.map.tile_of(p1))) and p1.distance_to(p0) < 32.0
				"under":
					ok = host.player.floor_id == 0 and InteriorMap.is_top(host.map.deck_at(host.map.tile_of(host.player.loco.logical))) and host.map.hole_r > 0.0
			checks.append([ok, str(s[1])])
			print("  [확인] %s %s · 층 %d · 칸 %s 부호 %d" % ["○" if ok else "×", s[1], host.player.floor_id, host.map.tile_of(host.player.loco.logical),
				host.map.deck_at(host.map.tile_of(host.player.loco.logical))])
			_next()
	if step >= plan.size():
		var n := checks.filter(func(c): return c[0]).size()
		print("고가 벤치: %s %d/%d" % ["○" if n == checks.size() else "×", n, checks.size()])
		get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


func _next() -> void:
	step += 1
	step_t = 0.0
	path = PackedVector2Array()
	host.input_fn = func() -> Vector2: return Vector2.ZERO


func _walk(g: Vector2) -> Vector2:
	var p := host.player.loco.render
	if p.distance_to(g) < 4.0:
		return Vector2.ZERO
	if path.is_empty() or int(step_t * 2.0) % 6 == 0 and step_t - floorf(step_t) < 0.02:
		var np := host.map.path(p, g, 9000, host.player.floor_id, -1)
		if not np.is_empty():
			path = np
	while path.size() > 0 and (NpcRoutine.arrived(p, path[0]) or (path.size() > 1 and p.distance_to(path[1]) <= path[0].distance_to(path[1]) + 2.0)):
		path.remove_at(0)
	if path.is_empty():
		return (g - p).normalized()
	return NpcRoutine.step_dir(p, path[0])


func _shot(tag: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/deck_%s.png" % [shots, tag])
	print("  스크린샷 ", tag)
