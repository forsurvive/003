## 방사능 확인 장면(단계 1-9d, SD-11 §11.2 · §9.2 방사능 함정 · §9.3 · SD-12 §5.6): 생성 창고 G-444-1265(차폐 용기 + 압력판)에서
##   ① 지대 밖(선량계 없음) ② 폐기물 드럼 옆 Z2(선량계 · 녹색 테) ③ 웅덩이 Z1 ④ 압력판 → 차폐 용기 열림 20라드/초 ⑤ 단계 오름(바늘 흔들림 · 알림)
##   ⑥ 웅크려 봉인(수리 75) ⑦ 원자력 차량 폭발 잔류 지대 ⑧ 핵 투사기 폭심 지대 ⑨ 대기 막힘 · 라드-X ⑩ 핍-보이 방사능 화면 ⑪ 터치 배치 를 돌며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/rad_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var o := Vector2i.ZERO
var cask: Dictionary


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.quests.set_stage("MQ-101", 100)
	st.vars.set_v("MQ101_RESULT", 1)
	st.vars.set_v("GAME_DAY", 3)
	st.vars.set_v("PC_EN", 5)
	st.vars.set_v("PC_SKP_REPAIR", 80)
	st.events.clear()
	st.quests.events.clear()
	st.call_fn("give", ["I-003", 2])
	st.call_fn("give", ["I-002", 3])
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 24.  10:20"
	host.enter("G-444-1265", "")
	o = _open(host.map, 6, 3)
	host.map.add_runtime_prop("waste_drum", o + Vector2i(1, 0))
	host.map.add_runtime_prop("rad_puddle", o + Vector2i(4, 1))
	host.combat.rad.setup(host.map, st)
	for it in host.combat.hazards.items:
		if it["type"] == "radcask":
			cask = it


func _open(m: InteriorMap, w: int, h: int) -> Vector2i:
	for y in range(2, 40):
		for x in range(6, 60):
			var ok := true
			for dy in h:
				for dx in w:
					var tt := Vector2i(x + dx, y + dy)
					if m.is_solid(tt) or m.cover_at(tt) != 0 or not m.props.filter(func(p): return Vector2i(int(p["x"]), int(p["y"])) == tt).is_empty():
						ok = false
			if ok:
				return Vector2i(x, y)
	return Vector2i(8, 4)


func _at(c: Vector2i) -> Vector2:
	return Vector2(c.x * 32 + 16, c.y * 32 + 16)


func _place(c: Vector2i) -> void:
	host.player.loco.place(_at(c))


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	var c := host.combat
	match stage:
		0:
			_place(o + Vector2i(5, 2) + Vector2i(0, 3))
			if t > 1.0:
				_check(c.rad_rate == 0.0, "지대 밖: 선량계 없음")
				_shot("1_outside")
				_go()
		1:
			_place(o + Vector2i(2, 0))
			if t > 1.6:
				_check(absf(c.rad_dose - 3.0) < 0.01 and c.rad_rate > 2.5, "폐기물 드럼 옆 Z2 3라드/초(저항 뒤 %.2f)" % c.rad_rate)
				_shot("2_drum_geiger")
				_go()
		2:
			_place(o + Vector2i(4, 2))
			if t > 1.2:
				_check(absf(c.rad_dose - 1.0) < 0.01, "웅덩이 Z1 1라드/초")
				_shot("3_puddle")
				_go()
		3:                                                              # 압력판 → 뚜껑
			var cc: Vector2i = cask.get("cell", Vector2i(3, 4))
			_place(cc + Vector2i(0, 1))
			if t > 0.3 and str(cask.get("state", "")) == "open" and not has_meta("opened"):
				set_meta("opened", true)
				_check(absf(c.rad.dose_at(_at(cc + Vector2i(0, 1))) - 20.0) < 0.01, "압력판 → 차폐 용기 열림 20라드/초")
				st.vars.set_v("PC_RADS", 190)
			if t > 1.3:
				_check(Radiation.stage(Radiation.rads(st)) >= 1, "단계 오름: 경미한 방사능 중독(%d 라드)" % Radiation.rads(st))
				_check(st.stat("EN") == 4, "지구력 −1")
				_shot("4_cask_stage_up")
				_go()
		4:                                                              # 봉인: 웅크려 상호작용을 누르고 있는 것처럼 매 프레임(호스트 키 처리는 잠시 멈춘다)
			var cc: Vector2i = cask.get("cell", Vector2i(3, 4))
			_place(cc + Vector2i(0, 1))
			host.set_physics_process(false)
			c.crouch = true
			c.tick(dt, true, st)
			c.disarm_tick(dt, st)
			if t > 0.55 and t - dt <= 0.55:
				_shot("5_cask_sealing")
			if t > 1.3:
				c.crouch = false
				host.set_physics_process(true)
				_check(cask["state"] == "done" and c.rad.dose_at(_at(cc + Vector2i(0, 1))) == 0.0, "봉인(수리 75) — 새지 않는다")
				_check(int(st.items.get("M-018", 0)) >= 1, "선원 회수(핵분열 배터리)")
				_go()
		5:                                                              # 원자력 차량 폭발 잔류
			if t < dt * 1.5:
				host.map.add_runtime_prop("car_wreck", o + Vector2i(1, 1))
				c.hazards.setup(host.map, st)
				_place(o + Vector2i(5, 3) + Vector2i(0, 3))
				for it in c.hazards.items:
					if it["type"] == "car":
						c.hazards._car_boom(it)
			if t > 1.2 and t - dt <= 1.2:
				_place(o + Vector2i(4, 3))
				_check(c.ord.zones.any(func(z): return z["kind"] == "rad"), "차 폭발 → 방사능 지대 15초(5라드/초)")
			if t > 1.2:
				_place(o + Vector2i(4, 3))
			if t > 2.2:
				_check(c.rad_dose >= 5.0, "잔류 지대 안 %.1f라드/초" % c.rad_dose)
				_shot("6_car_zone")
				_go()
		6:                                                              # 핵 투사기 폭심
			if t < dt * 1.5:
				c.ord.zones.clear()
				c.pc.hp = c.pc.max_hp
				c.shots.explode(_at(o + Vector2i(3, 1)), {"blast": 0.0, "proj": "nuke", "condition": "new"}, 50.0, "env")
			_place(o + Vector2i(5, 1))
			if t > 1.0:
				_check(absf(c.rad_dose - 8.0) < 0.01, "핵 투사기 폭심 4t 8라드/초")
				_shot("7_nuke_zone")
				_go()
		7:                                                              # 대기 막힘 · 라드-X
			_place(o + Vector2i(5, 1))
			if t > 0.3:
				host.story_hold = false
				_check(host.wait_block() == "방사능 지대에서는 쉴 수 없다.", "지대 안: %s" % host.wait_block())
				host.story_hold = true
				var r0 := c.rad_rate
				host.consume("I-003")
				c.tick(0.016, true, st)
				_check(c.rad_rate < r0, "라드-X: 저항 %d%% → 초당 %.2f → %.2f" % [roundi(Radiation.resist(st, host.items_db) * 100.0), r0, c.rad_rate])
				_go()
		8:
			if t > 0.8:
				_shot("8_geiger_radx")
				var pb := host.open_pipboy()
				pb.open_at(0, 0)
				pb.select_id("rad")
				_go()
		9:
			if t > 0.8 and t - dt <= 0.8:
				_shot("9_pipboy_rad")
			if t > 1.2:
				if host.pipboy != null:
					host.pipboy.close(true)
				host.touch_layout = true
				_go()
		10:
			_place(o + Vector2i(5, 1))
			if t > 0.8:
				_shot("10_touch")
				_check(true, "터치 배치: 방위 링 아래 선량계")
				_finish()


func _go() -> void:
	stage += 1
	t = 0.0


func _shot(nm: String) -> void:
	if shots == "":
		return
	DirAccess.make_dir_recursive_absolute(shots)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots.path_join(nm + ".png"))


func _check(ok: bool, what: String) -> void:
	checks.append([ok, what])
	print(("○ " if ok else "✕ ") + what)


func _finish() -> void:
	stage = 99
	print("방사능 확인: %d/%d" % [checks.filter(func(c): return c[0]).size(), checks.size()])
	get_tree().quit()
