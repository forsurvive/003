## 생물 특수 확인 장면(단계 1-9e4, SD-14 §4.2 · §7.2 · SD-11 §9.2 · SD-16 §10.5): 생성 창고 G-444-1265에서
##   ① 빛나는 구울(오라 맥동) ② 방사능 폭발 — 고리 · 녹색 지대 · 다친 야생 구울 HP +30% ③ 들개 우두머리 울부짖기(말풍선 · 무리 +15%)
##   ④ 들개가 깔린 지뢰를 비켜 간다 ⑤ 최루 지대: 약탈자 인지력 −2 · 주인공 기침 을 보이며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/creature_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var o := Vector2i.ZERO
var g: Enemy
var ferals: Array = []
var dogs: Array = []
var _h0 := 0.0
var _mine := {}
const MINE_W := "W-063"                          ## 파편 지뢰


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
	host.date_text = "2277. 10. 24.  22:40"
	host.enter("G-444-1265", "")
	o = Vector2i(2, 9)                                                # 기둥 없는 12×2 통로(1-9e3 벤치와 같은 자리)
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0
	for x in host.combat.enemies.duplicate():
		host.combat.drop_enemy(x)
	host.player.loco.place(_at(0, 0))


func _at(dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _foe(id: String, at: Vector2, fight := true) -> Enemy:
	var e := host.combat.spawn(id, at, host.map, host.st, {"lv": 9})
	if fight:
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
	return e


func _clear() -> void:
	for x in host.combat.enemies.duplicate():
		host.combat.drop_enemy(x)


func _hold(e: Enemy) -> void:
	e._cool = 999.0
	e._move = Vector2.ZERO
	e._path = PackedVector2Array()
	e._t_tac = -99.0


func _process(dt: float) -> void:
	t += dt
	var c := host.combat
	host.player.loco.place(_at(0, 0)) if stage < 3 else null
	match stage:
		0:                                                              # 빛나는 구울 오라
			if g == null:
				g = _foe("CR-202", _at(3, 0))
				g._burst_cd = 99.0
				for i in 2:
					var f := _foe("CR-200", _at(7 + i * 2, i))
					f.cmb.hp = f.cmb.max_hp * 0.4
					ferals.append(f)
			for e in [g] + ferals:
				_hold(e)
			if t > 0.6 and t - dt <= 0.6:
				_check(g.glow and g._aura != null and g._aura.visible, "빛나는 구울: 오라 가산 덧그림 · 녹빛 맥동")
				_shot("1_glow")
			if t > 0.9:
				_h0 = ferals[0].cmb.hp
				g._burst_cd = 0.0
				_go()
		1:                                                              # 방사능 폭발
			for e in [g] + ferals:
				_hold(e)
			if t > 0.22 and t - dt <= 0.22:
				_shot("2_burst")
			if t > 0.8:
				_check(int(c.stats.get("bursts", 0)) == 1, "표적 4t 안 → 방사능 폭발(고리)")
				_check(ferals[0].cmb.hp >= _h0 + ferals[0].cmb.max_hp * 0.29, "다친 야생 구울 HP +30%%(%.0f → %.0f)" % [_h0, ferals[0].cmb.hp])
				_check(c.rad_rate > 0.0, "주인공 피폭(+%.1f 라드/초 지대)" % c.rad_rate)
				_shot("2b_burst_zone")
				_go()
		2:                                                              # 울부짖기
			if dogs.is_empty():
				_clear()
				ferals.clear()
				var lead := _foe("CR-106", _at(9, 0))
				dogs.append(lead)
				for i in 3:
					dogs.append(_foe("CR-104", _at(8 + i, 1), false))
			for d in dogs:
				_hold(d)
			if t > 0.35 and t - dt <= 0.35:
				_check(dogs[0].say_text != "" and dogs.all(func(d): return d.buff_t > 19.0), "우두머리 울부짖기 '%s' → 무리 20초" % dogs[0].say_text)
				_check(absf(dogs[1].loco.speed_mul - 1.15) < 0.01, "무리 속도 +15%")
				_shot("3_howl")
			if t > 0.8:
				_clear()
				dogs.clear()
				_go()
		3:                                                              # 지뢰 비켜 가기
			if dogs.is_empty():
				host.player.loco.place(_at(0, 0))
				_mine = c.ord.place(_at(5, 0), Vector2.ZERO, c.weapons[MINE_W], "player", 30.0)
				_mine["arm"] = 0.0
				for i in 6:
					var d := _foe("CR-104", _at(10 + i % 2, i % 2) + Vector2(float(i) * 3.0, 0))
					d.cmb.hp = 9999.0
					d.cmb.max_hp = 9999.0
					dogs.append(d)
			host.player.loco.place(_at(0, 0))
			for d in dogs:
				d._cool = 999.0
			if t > 0.9 and t - dt <= 0.9:
				_shot("4_dog_mines")
			if t > 2.2:
				var decided := dogs.filter(func(d): return not d._mine_skip.is_empty())
				var dodgers := decided.filter(func(d): return bool(d._mine_skip.values()[0]))
				_check(decided.size() >= 3, "지뢰 앞에서 굴린 들개 %d마리" % decided.size())
				_check(dodgers.size() >= 1 and dodgers.size() < decided.size() + 1, "그중 %d마리가 비켜 간다(50%%)" % dodgers.size())
				_clear()
				c.ord.mines.clear()
				dogs.clear()
				_go()
		4:                                                              # 최루
			if g == null or not is_instance_valid(g) or g.get_meta("enemy_id", "") != "CR-420":
				g = _foe("CR-420", _at(7, 0), false)
				var gas: Dictionary = c.weapons.get("W-058", {})
				c.ord.zones.append({"p": _at(6, 0), "r": 96.0, "t": 8.0, "kind": "gas", "team": "player", "w": gas, "skill": 0.0})
				c.ord.zones.append({"p": _at(1, 0), "r": 48.0, "t": 0.6, "kind": "gas", "team": "enemy", "w": gas, "skill": 0.0})
			_hold(g)
			if t > 0.5 and t - dt <= 0.5:
				_check(g.gassed(), "최루 지대 안 약탈자: 인지력 −2(시야 %.1f → %.1f칸)" % [Perception.sight_range(g.per), Perception.sight_range(g.per - 2.0)])
				_check(c.cough_t > 0.0 and host.st.stat_tmp.get("PE", 0) == -2, "주인공 기침: 질주 불가 · AP 회복 −50% · 인지력 −2")
				_shot("5_gas")
			if t > 1.0:
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
	print("생물 특수 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
