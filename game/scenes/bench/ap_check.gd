## AP 행동 확인 장면(단계 1-9e3, SD-11 §5.3 · §3.4 · §15.5 · SD-12 §17.2): 생성 창고 G-444-1265에서
##   ① 질주(AP 초당 10 · 숨참) ② 회피 구르기(무적 컷) ③ 집중 사격(0.3초 조준 → 돌격소총 3발 점사) ④ 저격소총 스코프 안정(카메라 6칸)
##   ⑤ 터치: 이동 스틱 링 밖 0.3초 = 질주(노란 질주 링) · 구르기 · 집중 단추 ⑥ 교전 끝 3초 뒤 단추 30% 를 보이며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/ap_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var o := Vector2i.ZERO
var e: Enemy
var th: TouchHud
var _ap0 := 0.0
var _x0 := 0.0
var _n0 := 0
var _inv := false


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
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 24.  10:20"
	host.enter("G-444-1265", "")
	o = _open(host.map, 12, 2)                                         # 기둥 없는 12칸 통로(질주 · 구르기 거리)
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0
	for x in host.combat.enemies.duplicate():
		host.combat.drop_enemy(x)
	host.player.loco.place(_at(1, 0))
	for id in ["W-018", "W-021"]:
		st.call_fn("give", [id, 1])
	st.call_fn("give", ["5.56mm 탄", 90])
	st.call_fn("give", [".308 구경탄", 20])


func _open(m: InteriorMap, w: int, h: int) -> Vector2i:
	for y in range(2, 40):
		for x in range(2, 60):
			var ok := true
			for dy in h:
				for dx in w:
					var tt := Vector2i(x + dx, y + dy)
					if m.is_solid(tt) or m.cover_at(tt) != 0 or m.circle_hits(Vector2(tt * 32) + Vector2(16, 16), 12.0):
						ok = false                                     # 소품 몸통(책상 · 선반)도 막는다
			if ok:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _at(dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _process(dt: float) -> void:
	t += dt
	var c := host.combat
	var p := host.player
	if false:
		print("DBG s%d t%.2f x%.0f sp%s want%s mot%s ap%.1f foc%.2f cool%.2f mag%s bot%s ts%s mo%.2f hid%s" % [stage, t, p.loco.logical.x, c.sprinting, c.sprint_want, p.loco.motion, c.ap.ap, c.focus_t, c.cool, c.mags.get(c.weapon_id, -1), c.bot.keys(), host.touch_sprint, th.move_out if th != null else -1.0, th.hidden() if th != null else false])
	match stage:
		0:                                                              # 질주
			if t < dt * 1.5:
				_ap0 = c.ap.ap
				host.touch_sprint = true                                   # 질주 키를 누른 것과 같다
			host.input_vec = Vector2.RIGHT if p.loco.logical.x < _at(10, 0).x else Vector2.ZERO
			if t > 0.35 and t - dt <= 0.35:
				_check(c.sprinting and p.mode == "sprint", "질주: 걸음 'sprint'")
				_check(c.ap.ap < _ap0 - 1.5 and c.ap.ap > _ap0 - 4.0, "질주 AP 초당 10(뛰기 시작 0.2초: %.1f → %.1f)" % [_ap0, c.ap.ap])
				_shot("1_sprint")
			if t > 1.4:
				host.touch_sprint = false
				host.input_vec = Vector2.ZERO
				c.ap.ap = c.ap.max_ap
				_go()
		1:                                                              # 구르기
			if t < dt * 1.5:
				p.loco.place(_at(2, 0))
				_x0 = p.loco.logical.x
				p.loco.facing = 4                                           # 몸은 왼쪽 → 입력 없으면 뒤(오른쪽)로 구른다
				host.roll_req = true
			if c.pc.invuln and not _inv:
				_inv = true
				_shot("2_roll_invuln")
			if t > 0.8:
				_check(_inv, "구르기 2~4컷 무적")
				_check(absf(p.loco.logical.x - _x0 - Actor.ROLL_DIST) < 6.0, "입력 없으면 뒤로 2.5칸(%.0fpx)" % (p.loco.logical.x - _x0))
				_check(c.ap.ap <= c.ap.max_ap - 19.0, "구르기 AP 20")
				_go()
		2:                                                              # 집중 사격
			if e == null:
				p.loco.place(_at(1, 0))
				c.equip("W-018", host.st)
				e = c.spawn("CR-420", _at(10, 0), host.map, host.st, {"lv": 3})
				e.cmb.hp = 9999.0
				e.cmb.max_hp = 9999.0
				e._cool = 999.0
				c.ap.ap = c.ap.max_ap
				_n0 = int(c.stats["shots"])
			e._cool = 999.0
			e._move = Vector2.ZERO
			e._path = PackedVector2Array()
			var aim := e.loco.logical + Vector2(0, -6)
			if not c.bot.has("aim"):
				c.bot = {"aimed": true}
			c.bot["aim"] = aim                                             # 봇 칸은 물리 틱이 읽는다: 매 프레임 새로 만들지 않는다
			if t > 0.2 and t - dt <= 0.2:
				c.bot["focus"] = true
			if t > 0.35 and t - dt <= 0.35:
				_check(c.focus_t >= 0.0, "집중: 0.3초 조준(노란 좁은 커서)")
				_shot("3a_focus_aim")
			if t > 0.62 and t - dt <= 0.62:
				_shot("3b_focus_burst")
			if t > 1.2:
				_check(int(c.stats["shots"]) - _n0 == 3, "돌격소총 집중 점사 %d발" % (int(c.stats["shots"]) - _n0))
				_go()
		3:                                                              # 스코프 안정
			if t < dt * 1.5:
				c.equip("W-021", host.st)
			e._cool = 999.0
			e._move = Vector2.ZERO
			e._path = PackedVector2Array()
			c.bot["aim"] = e.loco.logical + Vector2(64, -6)
			if t > 1.2:
				_check(c.scope_steady(), "저격소총 정조준 0.6초 = 스코프 안정")
				_check(host.cam_lead.length() > 100.0, "카메라 리드 %.0fpx(최대 6칸)" % host.cam_lead.length())
				_shot("4_scope")
				c.bot = {}
				_go()
		4:                                                              # 터치
			if th == null:
				c.drop_enemy(e)
				e = c.spawn("CR-420", _at(10, 1), host.map, host.st, {"lv": 3})
				e.cmb.hp = 9999.0
				e._cool = 999.0
				e.brain.state = AIBrain.S.COMBAT
				p.loco.place(_at(1, 0))
				c.ap.ap = c.ap.max_ap
				c.equip("W-018", host.st)
				th = TouchHud.new().setup(host, Callable())
				add_child(th)
				th.on = true
				th.move_id = 0
				th.move_c = Vector2(72, 288)
				th.move_raw = 60.0                                          # 바깥 링(44) 밖
				th.move_v = Vector2(1, 0)
			e._cool = 999.0
			e._move = Vector2.ZERO
			e._path = PackedVector2Array()
			if t > 0.7 and t - dt <= 0.7:
				_check(host.touch_sprint and c.sprinting, "터치: 링 밖 0.3초 = 질주")
				_shot("5a_touch_sprint")
				th.move_raw = 30.0
				th.move_v = Vector2(0.6, 0)
				th._press("dodge")
			if t > 0.85 and t - dt <= 0.85:
				_check(p.rolling() or c.ap.ap < c.ap.max_ap, "터치 '구르기' 단추")
				_shot("5b_touch_roll")
			if t > 1.4:
				th.move_id = -1
				th.move_raw = 0.0
				th.move_v = Vector2.ZERO
				c.drop_enemy(e)
				_go()
		5:                                                              # 비전투 축소
			if t > 3.4:
				_check(th.calm_t >= TouchHud.CALM_S, "교전 끝 3초: 집중 · 구르기 단추 30%")
				_shot("6_touch_calm")
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
	print("AP 행동 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
