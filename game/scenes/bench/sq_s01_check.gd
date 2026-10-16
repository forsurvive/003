## SQ-S01 「외눈의 인식표」 확인 장면(단계 1-11a, SD-04a §4.1 · SD-09a L-R01-05): 실제 월드의 관악산 들개 바위굴(X-BW)에서
##   ① 해 질 녘 뼈 마당 — 외눈(CR-500) · 들개 무리 · 목줄 더미 ② 백구 대치(외눈 앞 3칸에 마주 섬 · 10초) → 들개 둘을 쫓아 흩어짐 · 바닥의 인식표
##   ③ 목줄 더미 조사 3회째(봉천 · 신림 · 낙성대) ④ 밤 무리 +2 ⑤ 별관 1층 체육관(K-30) ⑥ 2층 관람석(K-31) 한낮 낮잠 · 소음 칸 · 낮잠 원고
##   ⑦ 핍-보이 잡화 '살펴보기' → 인식표 원고 를 보이며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/sq_s01_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var side: SideR01
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var dogs: Array = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	st.quests.set_stage("SQ-S01", 10)
	st.vars.set_v("SQ_S01_DOG", 1)
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.hud_on = true
	host.pipboy_ok = true
	host.story_hold = true
	host.date_text = "2277. 10. 27.  17:40"
	side = SideR01.new()
	add_child(side)
	side.setup(host, true)
	host.enter("X-BW", "arrive")
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0
	host.player.loco.place(host.map.mark_pos("X-BW:yard") + Vector2(-4 * 32, 3 * 32))
	host.player.loco.facing = 0
	host._bring_buddy("C-015")
	host.hints.clear()


var _ls := -1
var _lt := 0


func _process(dt: float) -> void:
	t += dt
	if stage != _ls:
		print("STAGE %d at %d ms (frame dt %.3f)" % [stage, Time.get_ticks_msec() - _lt, dt])
		_lt = Time.get_ticks_msec()
		_ls = stage
	var st := host.st
	match stage:
		0:
			if t > 0.8:
				_check(side.pack_on and is_instance_valid(side.one), "해 질 녘: 뼈 마당에 외눈과 무리")
				_check(st.quests.stage("SQ-S01") == 20, "바위굴 반경 20칸 — 단계 20")
				for e in side.pack:
					if e != side.one:
						e._cool = 999.0
				_shot("01_dusk_yard")
				host.player.loco.place(host.map.mark_pos("X-BW:baek_face") + Vector2(32, 32))
				stage = 1
				t = 0.0
		1:
			if side.stand_t > 0.0 and t > 3.2:
				_check(str(side._dog_mate().get("mode", "")) == "wait", "백구가 외눈 앞에 마주 선다(대치)")
				var b: Actor = side._dog_mate()["actor"]
				_check(b.loco.logical.distance_to(side.one.loco.logical) <= 4.0 * 32.0, "외눈과 백구 3칸 남짓 간격")
				_shot("02_standoff")
				dogs = side.pack.filter(func(e): return e != side.one)
				stage = 2
				t = 0.0
			elif t > 8.0:
				_check(false, "대치가 시작되지 않았다")
				stage = 2
		2:
			if t > 0.4 and dogs.size() >= 2:
				for i in 2:
					dogs[i].cmb.hp = dogs[i].cmb.max_hp * 0.6                 # 들개 둘을 쫓았다(피해 30%+)
			if t > 1.2:
				_check(int(st.vars.get_v("SQ_S01_SOL")) == 2 and int(st.vars.get_v("SQ_S01_LEFT")) == 1, "흩어짐 — 해법 B · 외눈 생존")
				_check(not side.tag_prop.is_empty(), "인식표가 바닥에")
				stage = 3
				t = 0.0
		3:
			if t > 2.0:
				_shot("03_scatter_tag")
				var dc := side._drop_cell()
				host.player.loco.place(Vector2(dc.x * 32 + 16, dc.y * 32 + 16))
				host.player.loco.facing = 0
				stage = 4
				t = 0.0
		4:
			if t > 0.6:
				_check(st.count_of("M-158") == 1, "떨어진 인식표를 주웠다")
				st.vars.set_v("SQ_S01_COLL", 2)
				host.play_scene("SQS01_COLLARS")
				stage = 5
				t = 0.0
		5:
			if t > 1.6:
				_check(host.box.active, "목줄 더미 조사 3회째 원고")
				_shot("04_collar_pile")
				host.box._take({"type": "end"})
				stage = 6
				t = 0.0
		6:
			if t > 0.3:
				st.vars.set_v("SQ_S01_SOL", 0)                                 # 다시 보기: 밤 무리
				st.vars.set_v("SQ_S01_LEFT", 0)
				side._clear_pack()
				host.date_text = "2277. 10. 27.  22:30"
				side.tick()
				var n := side.pack.filter(func(e): return e != side.one).size()
				_check(n >= 8, "밤 무리 +2(%d)" % n)
				for e in side.pack:
					e._cool = 999.0
					e.foes.clear()
				host.player.loco.place(host.map.mark_pos("X-BW:yard") + Vector2(0, 4 * 32))
				stage = 7
				t = 0.0
		7:
			if t > 1.0:
				_shot("05_night_pack")
				stage = 70
				t = 0.0
		70:
			if t > 0.4:
				side._clear_pack()
				host.date_text = "2277. 10. 28.  12:10"
				host.enter("K-30", "from_X")
				stage = 8
				t = 0.0
		8:
			if t > 1.0:
				_shot("06_gym_k30")
				stage = 80
				t = 0.0
		80:
			if t > 0.4:
				host.enter("K-31", "from_K-30")
				stage = 9
				t = 0.0
		9:
			if t > 1.0:
				_check(is_instance_valid(side.one) and side.one.asleep, "한낮 관람석: 외눈이 둥지에서 잔다")
				host.player.loco.place(host.map.mark_pos("noise4") + Vector2(-64, 0))
				_shot("07_nap_k31")
				host.player.loco.place(host.map.mark_pos("nap_side"))
				host.combat.crouch = true
				stage = 10
				t = 0.0
		10:
			if t > 1.0:
				_check(host.box.active, "잠든 외눈 곁: 낮잠 원고가 열린다")
				_shot("08_nap_scene")
				stage = 11
				t = 0.0
		11:
			if t > 0.5:
				host.box._take({"type": "end"})
				host.open_pipboy()
				stage = 12
				t = 0.0
		12:
			if t > 0.8:
				if host.pipboy != null:
					host.pipboy.open_at(1, 3)
					for i in host.pipboy.rows.size():
						if str(host.pipboy.rows[i]["id"]) == "M-158":
							host.pipboy.sel = i
					pass
				stage = 13
				t = 0.0
		13:
			if t > 0.6:
				_check(host.pipboy != null and host.pipboy._enter_label() == "살펴보기", "핍-보이 잡화: 인식표 '살펴보기'")
				_shot("09_pip_examine")
				_finish()


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
	print("SQ-S01 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
