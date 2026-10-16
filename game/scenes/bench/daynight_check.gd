## 낮밤 · 실내 확인 장면(1-T1 · 1-T2 · 1-T3): 봉천 계단마을을 새벽 · 낮 · 노을 · 밤 · 깊은 밤에 찍고,
## 같은 길에 낮 · 밤 인카운터 몹을 세워 보이고, 실내(작은 방 — 주인공 가운데 · 방 밖 검정)와 불 꺼진 암거(핍-보이 조명)를 찍는다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/daynight_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var _next: Callable = Callable()
var _next_t := 0.0
var spawned: Array = []
const TIMES := [["2277. 10. 27.  05:30", "01_dawn", "새벽"], ["2277. 10. 27.  12:00", "02_day", "낮"], ["2277. 10. 27.  18:30", "03_dusk", "노을"],
	["2277. 10. 27.  21:30", "04_night", "밤"], ["2277. 10. 28.  02:30", "05_deep", "깊은 밤"]]


func _ready() -> void:
	shots = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else ""
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	host.body = "adult"
	host.hud_on = true
	host.story_hold = true
	host.date_text = TIMES[0][0]
	host.enter("X-BC", "from_X-S07")
	host.combat.pc.hp = 99999.0
	host.player.loco.place(host.map.mark_pos("X-BC:land1") + Vector2(2 * 32, 2 * 32))
	host.hints.clear()


func _process(dt: float) -> void:
	t += dt
	if _next.is_valid():
		_next_t += dt
		if _next_t > 0.3:
			var f := _next
			_next = Callable()
			f.call()
		return
	if stage < TIMES.size():
		if t > 1.0:
			var tm: Array = TIMES[stage]
			_check(TimeOfDay.band(TimeOfDay.minute(host.date_text)) == str(tm[2]) and (stage == 1) != TimeOfDay.is_dark(host.tone_now), "봉천 %s(색조 %s)" % [tm[2], host.tone_now])
			if stage == 4:
				_check(host.pip_light > 0.9, "깊은 밤: 핍-보이 조명")
			_shot(str(tm[1]))
			_later(func() -> void:
				stage += 1
				t = 0.0
				if stage < TIMES.size():
					host.date_text = TIMES[stage][0])
		return
	match stage:
		5:                                                            # 낮 몹 · 밤 몹(같은 길)
			if t > 0.5:
				host.date_text = "2277. 10. 27.  12:00"
				var day := _spawn_re(false)
				_check(day.size() > 0 and day.all(func(id): return id in ["RE-001", "RE-X01", "RE-057", "RE-002", "RE-012"] or not Encounters.re_def(id).get("cat", "") in ["creature"]), "낮 크리처 RE: %s" % [day])
				stage = 6
				t = 0.0
		6:
			if t > 1.2:
				_shot("06_day_mobs")
				_later(func() -> void:
					_clear()
					host.date_text = "2277. 10. 27.  22:00"
					var night := _spawn_re(true)
					_check(night.size() > 0, "밤 크리처 RE: %s" % [night])
					stage = 7
					t = 0.0)
		7:
			if t > 1.2:
				_shot("07_night_mobs")
				_later(func() -> void:
					_clear()
					host.date_text = "2277. 10. 27.  12:00"
					host.enter("K-31", "from_K-30")
					stage = 8
					t = 0.0)
		8:
			if t > 1.2:
				_check(not host.outdoor() and not TimeOfDay.is_dark(host.tone_now), "작은 방: 색조 없음 · 주인공 가운데")
				_shot("08_room_centered")
				_later(func() -> void:
					host.date_text = "2277. 10. 27.  12:00"
					host.enter("K-08", "from_W")
					stage = 9
					t = 0.0)
		9:
			if t > 1.2:
				_check(host.dark_inside() and host.pip_light > 0.9, "불 꺼진 암거: 실내 정전 + 핍-보이 조명(낮에도)")
				_shot("09_culvert_dark")
				stage = 99
				print("낮밤 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
				get_tree().quit()


## 그 시각에 고른 크리처 RE 셋을 주인공 둘레에 세운다(인카운터 표 그대로)
func _spawn_re(night: bool) -> Array:
	var ids: Array = []
	var rules := Encounters.new(host.st, 7)
	rules.ctx = {"hour": Clock.hour(host.date_text)}
	var t0: Vector2i = host.map.tile_of(host.player.loco.logical)
	var seen := {}
	for i in 40:
		var id := rules._pick("R01", night, t0)
		if id == "" or seen.has(id) or str(Encounters.re_def(id).get("cat", "")) != "creature":
			continue
		seen[id] = true
		ids.append(id)
	var k := 0
	for id in ids:
		var d: Dictionary = Encounters.re_def(id)
		var u: Array = d["groups"][0]["units"][0]
		for j in 2:
			var p: Vector2 = host.player.loco.logical + Vector2((k % 4 - 1.5) * 72.0, (k / 4 - 1) * 72.0 + 40.0)
			var e := host.combat.spawn(str(u[0]), p, host.map, host.st, {"lv": 3, "dir": "W", "team": "calmbench"})
			e.foes.clear()
			spawned.append(e)
			k += 1
	return ids


func _clear() -> void:
	for e in spawned:
		if is_instance_valid(e):
			host.combat.drop_enemy(e)
	spawned.clear()


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
