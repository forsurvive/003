## 정보상 확인 장면(단계 1-8d, SD-15 §5.3 · §4.2 V12): 지하상가 북쪽 출구 계단참의 구문철 '귀동냥'에게
##   ① 말을 걸면 첫 만남 대사 → '들은 걸 좀 사지' → 정보 메뉴 → ② 관악·동작(R01) → 장소 하나 → 50캡 · 지도 '표시' →
##   ③ 다섯 번 사면 R01 줄이 사라진다 를 돌며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/info_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var bought: Array = []


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
	st.vars.set_v("GAME_DAY", 4)
	st.vars.set_v("PC_CAPS", 400)
	st.events.clear()
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 27.  11:00"
	host.enter("J-01", "from_W")


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	match stage:
		0:
			if t > 1.0:
				host.play_scene("JM_GUMC")
				_go()
		1:                                                               # 첫 만남 → 고르기 '들은 걸 좀 사지'
			if _drive(func(s: Dictionary) -> int: return _opt(s, "사지")):
				_go()
		2:
			if t > 0.5 and host.box.active and str(host.box.state.get("type", "")) == "choices":
				if not has_meta("s1"):
					set_meta("s1", true)
					_shot("1_menu")
					return
				_check(_opt(host.box.state, "관악") >= 0 and _opt(host.box.state, "영등포") >= 0, "정보 메뉴: 권역 둘(관악·동작 · 영등포·여의도)")
				host.box.pick(_opt(host.box.state, "관악"))
				_go()
			elif host.box.active and str(host.box.state.get("type", "")) == "line" and t > 0.3:
				host.box.next()
				t = 0.0
		3:
			if host.box.active and str(host.box.state.get("type", "")) == "choices" and t > 0.6:
				var opts: Array = host.box.state.get("choices", host.box.state.get("opts", []))
				if not has_meta("s2"):
					set_meta("s2", true)
					_shot("2_places")
					return
				var cands := host.rumor_places("R01")
				bought.append(str(cands[0]))
				set_meta("caps0", int(st.vars.get_v("PC_CAPS")))
				host.box.pick(0)
				_go()
			elif host.box.active and str(host.box.state.get("type", "")) == "line" and t > 0.3:
				host.box.next()
				t = 0.0
		4:
			if host.box.active:
				if str(host.box.state.get("type", "")) == "line" and t > 0.3:
					host.box.next()
					t = 0.0
				return
			if t > 0.8:
				var lid: String = bought[0]
				_check(st.places.get_state(lid) == PlaceLog.MARKED and int(get_meta("caps0")) - int(st.vars.get_v("PC_CAPS")) == 50
					and int(st.vars.get_v("INFO_RUMOR_R01")) == 1, "장소 소문 1곳: %s → 지도 '표시' · 50캡" % str(PlaceLog.db[lid]["name"]))
				for i in 4:                                                 # 네 번 더(엔진 명령으로 바로) — 다섯 곳이 한도
					var c := host.rumor_places("R01")
					host.ev.handlers["infodo"].call(["V12", c[0]], func() -> void: pass)
				host.info_menu("V12")
				_go()
		5:
			if host.box.active and str(host.box.state.get("type", "")) == "choices" and t > 0.5:
				_check(_opt(host.box.state, "관악") < 0 and _opt(host.box.state, "영등포") >= 0, "다섯 곳을 사면 관악·동작 줄이 사라진다(영등포는 남음)")
				_shot("3_cap")
				host.box.pick(_opt(host.box.state, "됐다"))
				_go()
			elif host.box.active and str(host.box.state.get("type", "")) == "line" and t > 0.3:
				host.box.next()
				t = 0.0
		6:
			if t > 0.8:
				var here := host.npcs.any(func(n): return str(n["id"]) == "N-R02-501")
				_check(here, "구문철이 J-01 계단참에 서 있다")
				var n := checks.filter(func(c): return c[0]).size()
				print("정보상 벤치: %s %d/%d" % ["○" if n == checks.size() else "×", n, checks.size()])
				stage = 99
				get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


## 대화를 굴린다: 줄은 넘기고, 고르기에서 pick(s) 번호를 고른다(−1이면 기다림). 고르고 나면 true
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


## 보이는 선택지 중 글에 word가 든 첫 번호(없으면 −1)
func _opt(s: Dictionary, word: String) -> int:
	var opts: Array = s.get("choices", s.get("opts", []))
	for i in opts.size():
		var o = opts[i]
		var txt := str(o.get("text", "")) if o is Dictionary else str(o)
		if txt.contains(word):
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
	get_viewport().get_texture().get_image().save_png("%s/info_%s.png" % [shots, tag])
