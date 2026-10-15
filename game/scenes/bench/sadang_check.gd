## 사당 환승촌 확인 장면(단계 1-8f, SD-09a L-R01-18 · SD-15 V05 · §5.1 · §5.5):
##   ① 수송대가 사당 정류장에 있는 낮 — 4번 출구 광장에 연보경 · 호위 · 짐소 · 위강윤 · 경비 → ② D-01 개찰구 12기 · 성지후 →
##   ③ D-02 대합실 천막 거리 · 의원 할매 의사 요금 → ④ D-03 역무실: 허순자 '서쪽 터널' → SA_MAKCHA_HEARD · 서랍 정기권 → ⑤ D-04 환승 통로 LR-09 →
##   ⑥ D-05 버섯 측실(낮 표하경 · 반로아) → ⑦ D-06 터널 입구(낮 경비) → ⑧ 밤: 표하경 D-02 천막 · 매트 빌리기(10캡 · 소유 침대) · 성지후 D-06 ·
##   위강윤 D-01 초소 → ⑨ 출입구 이음(모든 exit의 표지가 그 맵에 있다) 을 돌며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/sadang_check.tscn -- [스크린샷 폴더]
extends Node

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
	st.vars.set_v("GAME_DAY", 9)
	st.vars.set_v("PC_CAPS", 300)
	st.events.clear()
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 30.  06:00"
	car = Caravans.new()
	add_child(car)
	car.setup(host)
	for i in 80:                                                          # 수송대가 사당에 있는 낮 시각까지 한 시간씩
		var h := int(host.date_text.substr(host.date_text.length() - 5, 2))
		if Caravans.v54_at(Clock.abs_min(host.date_text)) == 2 and h >= 8 and h < 18:
			break
		host.date_text = Clock.add_hours(host.date_text, 1)
	_hour()
	car.tick()
	host.enter("X-SD", "arrive")


func _hour() -> void:
	st_set("GAME_HOUR", int(host.date_text.substr(host.date_text.length() - 5, 2)))


func st_set(k: String, v: int) -> void:
	host.st.vars.set_v(k, v)


func _ids() -> Array:
	return host.npcs.map(func(n): return str(n["id"]))


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	for c in host.get_children():                                      # 종이 기록물 창: 한 장 찍고 끝 쪽까지 넘겨 닫는다
		if c is NoteScreen:
			if t > 1.0:
				t = 0.0
				if c.page == 0 and not has_meta("note_" + str(c.note.get("id", "")).replace("-", "_")):
					set_meta("note_" + str(c.note.get("id", "")).replace("-", "_"), true)
					_shot("note_" + str(c.note.get("id", "")))
				elif c.page < c._pages.size() - 1:
					c.page += 1
				else:
					c.close(true)
			return
	match stage:
		0:
			if t > 1.8:
				var ids := _ids()
				_check(int(st.vars.get_v("CARAVAN_V54")) == 2, "진행기: 지금 수송대는 사당 정류장(CARAVAN_V54 = 2, %s)" % host.date_text)
				_check(ids.has("N-R01-040") and ids.has("N-HS-E1") and ids.has("N-HS-E2") and ids.count("CR-091") == 2, "4번 출구 광장: 연보경 · 호위 둘 · 짐소(수송대 + 대여)")
				_check(ids.has("N-R01-043") and ids.has("N-SA-G1"), "낮: 위강윤 광장 · 출구 경비")
				_shot("1_plaza")
				_go()
		1:
			if t > 0.5:
				host.enter("D-01", "from_X")
				_go()
		2:
			if t > 1.2:
				var gates := host.map.props.filter(func(p): return str(p["name"]).begins_with("sd_gate")).size()
				_check(gates == 12, "D-01 판독기 개찰구 %d기" % gates)
				_check(_ids().has("N-R01-044") and not _ids().has("N-R01-043"), "낮: 성지후가 개찰구 초소에(위강윤은 광장)")
				_stand(19, 13)
				_go()
		3:
			if t > 0.8:
				_shot("2_gates")
				host.enter("D-02", "from_D-01")
				_go()
		4:
			if t > 1.2:
				var tents := host.map.props.filter(func(p): return str(p["name"]).begins_with("sd_tent")).size()
				_check(tents >= 30, "D-02 대합실 천막 %d동" % tents)
				_check(_ids().has("N-R01-046") and not _ids().has("N-R01-042"), "의원 할매 천막 의원 · 낮엔 표하경이 측실에")
				host.combat.pc.hp = host.combat.pc.max_hp * 0.45
				var pr := host.doctor_prices("VSD")
				_check(str(pr["tier"]) == "중상" and int(pr["heal"]) == 70 and not bool(pr["refuse"]), "탁순복 의사 요금: 중상 70캡 %s" % str(pr))
				host.combat.pc.hp = host.combat.pc.max_hp
				_stand(32, 22)
				_go()
		5:
			if t > 0.8:
				_shot("3_hall")
				_stand(46, 31)
				_go()
		6:
			if t > 0.8:
				_shot("3b_clinic")
				host.enter("D-03", "from_D-02")
				_go()
		7:
			if t > 1.2:
				_check(_ids().has("N-R01-041"), "D-03 역무실: 허순자")
				var dr: Dictionary = host.map.boxes.get(Vector2i(5, 6), {})
				_check(str(dr.get("kind", "")) == "sd_drawer" and str(dr.get("owner", "")) == "N-R01-041", "역무실 서랍(정기권 M-071 · 주인 허순자)")
				_stand(5, 8)
				host.play_scene("SD_HUH")
				_go()
		8:
			if host.box.active and t > 0.2 and not has_meta("s4"):
				set_meta("s4", true)
				_shot("4_office")
				return
			if _drive(func(s: Dictionary) -> int: return _opt(s, "서쪽")):
				_go()
		9:
			if _finish("됐어요"):
				_check(int(st.vars.get_v("SA_MAKCHA_HEARD")) == 1 and int(st.vars.get_v("SD_MET_HUH")) == 1, "허순자: 서쪽 터널 '막차 손님' 들음(SA_MAKCHA_HEARD — SQ-S05 이미 앎)")
				host.enter("D-04", "from_D-02")
				_go()
		10:
			if t > 1.2:
				_stand(38, 14)
				_go()
		11:
			if t > 0.8:
				_shot("5_passage")
				host.play_scene("SD_LR09")
				_go()
		12:
			if _finish(""):
				_check(int(st.vars.get_v("SD_LR09")) == 1, "D-04 볼트 분양 광고판 LR-09")
				host.enter("D-05", "from_D-02")
				_go()
		13:
			if t > 1.2:
				_check(_ids().has("N-R01-042") and _ids().has("N-R01-045") and _ids().has("N-SA-R4"), "낮: 버섯 측실에 표하경 · 반로아 · 버섯 일꾼")
				_stand(15, 10)
				_go()
		14:
			if t > 0.8:
				_shot("6_mushroom")
				host.enter("D-06", "from_D-02")
				_go()
		15:
			if t > 1.2:
				_check(_ids().has("N-SA-G3") and not _ids().has("N-R01-044"), "낮: 서쪽 터널 입구엔 경비(성지후는 개찰구)")
				_stand(21, 9)
				_go()
		16:
			if t > 0.8:
				_shot("7_tunnel")
				host.date_text = "2277. 10. 31.  21:00"                   # 밤
				_hour()
				host.enter("D-02", "from_D-01")
				_go()
		17:
			if t > 1.2:
				_check(_ids().has("N-R01-042") and _ids().has("N-R01-045"), "밤: 표하경 · 반로아가 대합실 천막에")
				var mat := host.bed_front([Vector2i(40, 33)])
				_check(bool(mat.get("other", false)) and str(mat.get("why", "")).contains("10캡"), "빌리기 전 매트: 쓸 수 없다(%s)" % str(mat.get("why", "")))
				set_meta("caps0", int(st.vars.get_v("PC_CAPS")))
				_stand(39, 34)
				host.play_scene("SD_PYO")
				_go()
		18:
			if host.box.active and t > 0.2 and not has_meta("s8"):
				set_meta("s8", true)
				_shot("8_night_hall")
				return
			if _drive(func(s: Dictionary) -> int: return _opt(s, "매트")):
				_go()
		19:
			if _finish(""):
				var mat := host.bed_front([Vector2i(40, 33)])
				_check(int(get_meta("caps0")) - int(st.vars.get_v("PC_CAPS")) == 10 and bool(mat.get("owned", false)) and not bool(mat.get("other", true)),
					"매트 빌림: 10캡 · 하룻밤 소유 침대(숙면) %s" % str(mat))
				host.date_text = Clock.add_hours(host.date_text, 25)
				var mat2 := host.bed_front([Vector2i(40, 33)])
				_check(bool(mat2.get("other", false)), "24시간 뒤: 매트 기한 끝")
				host.date_text = "2277. 10. 31.  22:00"
				_hour()
				host.enter("D-06", "from_D-02")
				_go()
		20:
			if t > 1.2:
				_check(_ids().has("N-R01-044") and not _ids().has("N-SA-G3"), "밤: 성지후가 서쪽 터널 철망을 지킨다")
				host.enter("D-01", "from_D-02")
				_go()
		21:
			if t > 1.2:
				_check(_ids().has("N-R01-043") and not _ids().has("N-R01-044"), "밤: 위강윤이 개찰구 초소에(성지후는 터널)")
				var bad: Array = []
				for mid in ["X-SD", "D-01", "D-02", "D-03", "D-04", "D-05", "D-06"]:
					var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % mid))
					for e in d["exits"]:
						var to := str(e["to"])
						if to == "W":
							continue
						var td: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % to))
						if not td["marks"].has(str(e["mark"])):
							bad.append("%s→%s:%s" % [mid, to, e["mark"]])
				_check(bad.is_empty(), "출입구 이음: 광장 · 실내 6장의 모든 출구 표지가 있다 %s" % str(bad))
				_go()
		22:
			if t > 0.5:
				var n := checks.filter(func(c): return c[0]).size()
				print("사당 환승촌 벤치: %s %d/%d" % ["○" if n == checks.size() else "×", n, checks.size()])
				stage = 99
				get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


func _stand(x: int, y: int) -> void:
	host.player.loco.place(Vector2(x * 32 + 16, y * 32 + 16))
	host.player._show()


## 대화가 끝날 때까지 줄을 넘기고 고를 게 나오면 word(빈 문자열이면 마지막)를 고른다 — 끝나면 true
func _finish(word: String) -> bool:
	if host.box.active or host.busy:
		if host.box.active and t > 0.3:
			var s: Dictionary = host.box.state
			if str(s.get("type", "")) == "line":
				host.box.next()
			elif str(s.get("type", "")) == "choices":
				var k := _opt(s, word) if word != "" else -1
				host.box.pick(k if k >= 0 else (s.get("opts", []) as Array).size() - 1)
			t = 0.0
		return false
	return t > 0.6


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
	get_viewport().get_texture().get_image().save_png("%s/sadang_%s.png" % [shots, tag])   # 마지막으로 그린 화면(맵을 바꾸기 전)
