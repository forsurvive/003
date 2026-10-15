## 순회 상인 확인 장면(단계 1-8d, SD-15 §4.3 · §5.1): 봉천에서
##   ① 수송대가 정류장에 있는 시각을 찾아 들어가면 연보경 · 호위 둘 · 짐소 · 의료반 소윤희가 선다 → ② 연보경에게 해진 가죽 아머 정비 →
##   ③ 소윤희 치료(손상 지수 → 중상 70캡) · 카르마 선함 무료 · 악함 거절 → ④ 12시간 뒤 수송대가 그 자리에서 떠난다 →
##   ⑤ 이레 중 2~3일째엔 의료반이 지하상가 북쪽 출구에 있다 를 돌며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/travel_check.tscn -- [스크린샷 폴더]
extends Node

const ORIGIN := Vector2i(862, 1339)                ## X-BC 손 맵의 월드 원점(world.json insets)

var host: InteriorHost
var car: Caravans
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0


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
	st.vars.set_v("GAME_DAY", 7)
	st.vars.set_v("PC_CAPS", 300)
	st.vars.set_v("PC_SKP_REPAIR", 10)
	st.events.clear()
	st.call_fn("give", ["A-023@3", 1])
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 29.  06:00"
	car = Caravans.new()
	add_child(car)
	car.setup(host)
	for i in 60:                                                          # 수송대가 봉천에 있는 시각까지 한 시간씩
		if Caravans.v54_at(Clock.abs_min(host.date_text)) == 1:
			break
		host.date_text = Clock.add_hours(host.date_text, 1)
	st.vars.set_v("GAME_DAY", 7)                                          # 7일째 = 이레 주기 0일째(의료반 봉천)
	car.tick()
	host.wear("A-023@3")
	host.enter("X-BC", "from_B-03")


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	match stage:
		0:
			if t > 1.5:
				var ids := host.npcs.map(func(n): return str(n["id"]))
				_check(ids.has("N-R01-040") and ids.has("CR-091") and ids.has("N-HS-E1") and ids.has("N-HS-E2"), "정류장 시각: 연보경 · 호위 둘 · 짐소가 아랫문 안 마당에 선다 (%s)" % host.date_text)
				_check(ids.has("C-067"), "이레 주기 0일째: 순회 의료반 소윤희가 약국 앞에 선다")
				_stand(ORIGIN + Vector2i(25, 35), 2)
				_go()
		1:
			if t > 1.0:
				_shot("1_caravan")
				var jobs := host.fix_jobs("V54")
				_check(jobs.any(func(j): return str(j["key"]) == "A-023@3"), "연보경 정비 일감: 위태 가죽 아머 %s" % str(jobs))
				host.fix_menu("V54")
				_go()
		2:
			if _drive(func(s: Dictionary) -> int: return _opt(s, "가죽")):
				_go()
		3:
			if host.box.active:
				if str(host.box.state.get("type", "")) == "line" and t > 0.3:
					host.box.next()
					t = 0.0
				elif str(host.box.state.get("type", "")) == "choices" and t > 0.3:
					host.box.pick(_opt(host.box.state, "됐다"))
				return
			if t > 0.8:
				_check(st.items.has("A-023@2") or host.worn() == "A-023@2", "가죽 아머 위태 → 낡음(정비비 냄)")
				host.combat.pc.hp = host.combat.pc.max_hp * 0.45
				var pr := host.doctor_prices("V56")
				_check(str(pr["tier"]) == "중상" and int(pr["heal"]) == 70, "손상 지수 0.55 → 중상 70캡 %s" % str(pr))
				set_meta("caps0", int(st.vars.get_v("PC_CAPS")))
				host.doctor_menu("V56")
				_go()
		4:
			if host.box.active and str(host.box.state.get("type", "")) == "choices" and t > 0.2 and not has_meta("s2"):
				set_meta("s2", true)
				_shot("2_doctor")
				return
			if _drive(func(s: Dictionary) -> int: return _opt(s, "치료")):
				_go()
		5:
			if host.box.active or host.busy:
				if host.box.active and str(host.box.state.get("type", "")) == "line" and t > 0.3:
					host.box.next()
					t = 0.0
				return
			if t > 0.8:
				_check(host.combat.pc.hp >= host.combat.pc.max_hp and int(get_meta("caps0")) - int(st.vars.get_v("PC_CAPS")) == 70, "치료: HP 전부 · 70캡")
				st.vars.set_v("V_KARMA", 300)
				host.combat.pc.hp = host.combat.pc.max_hp * 0.2
				var good := host.doctor_prices("V56")
				st.vars.set_v("V_KARMA", -300)
				var evil := host.doctor_prices("V56")
				var other := host.doctor_prices("V54")
				_check(bool(good["free"]) and int(good["heal"]) == 0 and str(good["tier"]) == "위중", "카르마 선함: 위중이어도 무료")
				_check(bool(evil["refuse"]) and not bool(other["refuse"]), "카르마 악함: 소윤희는 치료 거절(다른 의사 규칙은 그대로)")
				st.vars.set_v("V_KARMA", 0)
				host.advance_minutes(13 * 60)                              # 정류장 12시간이 지난다
				car.tick()
				_go()
		6:
			if t > 1.0:
				var ids := host.npcs.map(func(n): return str(n["id"]))
				_check(not ids.has("N-R01-040") and not ids.has("CR-091"), "12시간 뒤: 수송대가 그 자리에서 떠났다(맵에 있는 채로)")
				_shot("3_gone")
				st.vars.set_v("GAME_DAY", 9)                               # 이레 중 2일째
				car.tick()
				host.enter("J-01", "from_W")
				_go()
		7:
			if t > 1.2:
				var ids := host.npcs.map(func(n): return str(n["id"]))
				_check(int(st.vars.get_v("MEDIC_AT")) == 2 and ids.has("C-067"), "이레 중 2일째: 소윤희가 지하상가 북쪽 출구에 있다")
				_shot("4_j01_medic")
				_go()
		8:
			if t > 0.5:
				host.enter("X-BC", "from_B-03")
				_go()
		9:
			if t > 1.5:
				var ids := host.npcs.map(func(n): return str(n["id"]))
				_check(ids.has("N-R01-033"), "봉천 마당 동쪽: 사냥꾼 엄태경이 오두막 앞에 선다")
				_check(_world_has("hunter_shack") and _world_has("hide_rack"), "사냥꾼 오두막 · 가죽 말림 틀 배치")
				_stand(ORIGIN + Vector2i(52, 38), 6)
				host.shop_state("V04")
				var m: Dictionary = host.merchants.get("V04", {})
				_check(str(m.get("npc", "")) == "N-R01-033" and not (m.get("stock", []) as Array).is_empty(), "V04 사냥꾼 오두막 재고 %d종" % (m.get("stock", []) as Array).size())
				host.play_scene("TR_EOM")
				_go()
		10:
			if host.box.active and t > 0.2 and not has_meta("s5"):
				set_meta("s5", true)
				_shot("5_hunter")
				return
			if _drive(func(s: Dictionary) -> int: return _opt(s, "산은")):
				_go()
		11:
			if host.box.active:
				if t > 0.3:
					if str(host.box.state.get("type", "")) == "line":
						host.box.next()
					elif str(host.box.state.get("type", "")) == "choices":
						host.box.pick(_opt(host.box.state, "됐다"))
					t = 0.0
				return
			if t > 0.5:
				_check(int(st.vars.get_v("TR_EOM_MET")) == 1, "엄태경 첫 만남 기록(TR_EOM_MET) · 외눈 이야기")
				_go()
		12:
			if t > 0.5:
				var n := checks.filter(func(c): return c[0]).size()
				print("순회 상인 벤치: %s %d/%d" % ["○" if n == checks.size() else "×", n, checks.size()])
				stage = 99
				get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


func _world_has(nm: String) -> bool:
	for ins in host.map.get("insets"):
		if str(ins["id"]) == "X-BC":
			return (ins["data"]["props"] as Array).any(func(p): return str(p.get("name", "")) == nm)
	return false


func _stand(c: Vector2i, facing: int) -> void:
	host.player.loco.place(Vector2(c.x * 32 + 16, c.y * 32 + 16))
	host.player.loco.facing = facing
	host.player._show()


func _drive(pick: Callable) -> bool:
	if not host.box.active or t < 0.3:
		return false
	var s: Dictionary = host.box.state
	if str(s.get("type", "")) == "line":
		host.box.next()
		t = 0.0
		return false
	if str(s.get("type", "")) == "choices":
		var k: int = pick.call(s)
		if k >= 0:
			host.box.pick(k)
			t = 0.0
			return true
	return false


func _opt(s: Dictionary, word: String) -> int:
	var opts: Array = s.get("opts", [])
	for i in opts.size():
		if str(opts[i].get("text", "")).contains(word):
			return i
	return -1


func _go() -> void:
	stage += 1
	t = 0.0


func _check(ok: bool, what: String) -> void:
	checks.append([ok, what])
	print("  [확인] %s %s" % ["○" if ok else "×", what])


func _shot(tag: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/travel_%s.png" % [shots, tag])
