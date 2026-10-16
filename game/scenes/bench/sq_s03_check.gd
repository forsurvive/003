## SQ-S03 「곰팡이의 근원」 확인 장면(단계 1-11d, SD-04a §4.3 · SD-09a L-R01-02 · 08 · 10): 실제 맵에서
##   ① 봉천 배수지 저수조 이음 벽 얼룩 · 옛 관 입 거름망 ② 관악 계곡 배수로(K-08) 천장 군락 · 시궁쥐 무리 · 왕쥐
##   ③ 군락 상태 넷(그을음 · 약품 · 마르는 중 · 다 마름) ④ S-07 배수 갱도(E-01) 바깥 철문 · 측실 · 쥐 · 수문
##   ⑤ 수문 닫힘 · 볼트 쪽 용접 창살 ⑥ 볼트 정문 인터컴 ⑦ 맑아진 배수지 ⑧ 월드의 배수 출구(L-R01-02) 를 보이며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/sq_s03_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var side: SideS03
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var _next: Callable = Callable()
var _next_t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 8)
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.hud_on = true
	host.pipboy_ok = true
	host.story_hold = true
	host.date_text = "2277. 10. 30.  10:20"
	side = SideS03.new()
	add_child(side)
	side.setup(host, true)
	host.enter("X-BS", "tanks")
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0
	host.player.loco.place(host.map.mark_pos("X-BS:tanks") + Vector2(1 * 32, 1 * 32))
	host.player.loco.facing = 0
	host.hints.clear()


func _v(k: String) -> int:
	return int(host.st.vars.get_v(k))


func _alive(id: String) -> int:
	return host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == id).size()


## K-08 플레이어를 군락 아래에(쥐는 멈춰 세워 둔다 — 그림 확인용)
func _k08_view() -> void:
	host.player.loco.place(Vector2(20 * 32 + 16, 5 * 32 + 16))
	host.player.loco.facing = 0
	for e in host.combat.enemies:
		if is_instance_valid(e):
			e.set_process(false)
			e.set_physics_process(false)


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	if _next.is_valid():
		_next_t += dt
		if _next_t > 0.3:
			var f := _next
			_next = Callable()
			f.call()
		return
	match stage:
		0:
			if t > 1.0:
				_check(host.map.id == "X-BS", "배수지(X-BS)")
				_shot("01_reservoir_wall")
				_later(func() -> void:
					side._cmd(["wall"], func() -> void: pass)
					host.enter("K-08", "from_W")
					_k08_view()
					stage = 1
					t = 0.0)
		1:
			if t > 1.0:
				_check(st.quests.stage("SQ-S03") >= 40, "저수조 벽 → 20 · 암거에 들어섬 → 40")
				_check(_alive("CR-095") >= 8, "K-08 시궁쥐 무리(맵 넷 + 진행기 4~6)")
				_check(_alive("CR-097") == 1, "왕쥐(퀘스트가 열려 있으면 첫 방문)")
				_shot("02_k08_colony_live")
				_later(func() -> void:
					st.vars.set_v("SQ_S03_SOL", 1)
					side._looks()
					stage = 2
					t = 0.0)
		2:
			if t > 0.5:
				_shot("03_colony_burnt")
				_later(func() -> void:
					st.vars.set_v("SQ_S03_SOL", 2)
					side._looks()
					stage = 3
					t = 0.0)
		3:
			if t > 0.5:
				_shot("04_colony_sprayed")
				_later(func() -> void:
					st.vars.set_v("SQ_S03_SOL", 3)
					st.vars.set_v("SQ_S03_DRY_DAY", 1)
					side._looks()
					stage = 4
					t = 0.0)
		4:
			if t > 0.5:
				_shot("05_colony_dry1")
				_later(func() -> void:
					st.vars.set_v("GAME_DAY", 16)
					side._looks()
					stage = 5
					t = 0.0)
		5:
			if t > 0.5:
				_shot("06_colony_dry2")
				_later(func() -> void:
					for k in ["SQ_S03_SOL", "SQ_S03_DRY_DAY"]:
						st.vars.set_v(k, 0)
					st.vars.set_v("GAME_DAY", 8)
					host.enter("E-01", "from_W")
					host.player.loco.place(Vector2(8 * 32 + 16, 6 * 32 + 16))
					stage = 6
					t = 0.0)
		6:
			if t > 1.0:
				_check(host.map.id == "E-01", "S-07 배수 갱도(E-01)")
				_check(_alive("CR-095") == 3 and _alive("CR-002") == 2, "갱도: 시궁쥐 셋 · 큰바퀴 둘")
				_shot("07_e01_outer")
				_later(func() -> void:
					for e in host.combat.enemies:
						if is_instance_valid(e):
							e.set_process(false)
							e.set_physics_process(false)
					side._cmd(["shut"], func() -> void: pass)
					host.player.loco.place(Vector2(30 * 32 + 16, 5 * 32 + 16))
					stage = 7
					t = 0.0)
		7:
			if t > 1.0:
				_check(_v("SQ_S03_GATE") == 2, "수문 닫힘")
				_shot("08_e01_gate_grate")
				_later(func() -> void:
					host.enter("X-S07", "from_vault")
					host.player.loco.facing = 2
					stage = 8
					t = 0.0)
		8:
			if t > 1.0:
				_check(host.map != null and host.map.has_method("to_world"), "볼트 정문 앞(심리스 월드의 X-S07 구역)")
				_shot("09_vault_intercom")
				_later(func() -> void:
					st.vars.set_v("SQ_S03_CLEAN", 1)
					host.enter("X-BS", "tanks")
					host.player.loco.place(host.map.mark_pos("X-BS:tanks") + Vector2(1 * 32, 1 * 32))
					stage = 9
					t = 0.0)
		9:
			if t > 1.0:
				_shot("10_reservoir_clean")
				_later(func() -> void:
					host.enter("W", "", {}, Vector2(932 * 32 + 16, 1536 * 32 + 16))
					host.player.loco.facing = 0
					stage = 10
					t = 0.0)
		10:
			if t > 2.0:
				_check(host.map != null, "월드: 배수 출구 앞")
				_shot("11_world_drain_out")
				_later(_finish)


func _later(f: Callable) -> void:
	_next = f
	_next_t = 0.0


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
	print("SQ-S03 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
