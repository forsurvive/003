## 사당 고개 검문소 · 노량진 관제 중계소 확인 장면(단계 1-8g, SD-09a L-R01-19 · L-R01-23 · SD-06 §4.3.1 · §4.3.7 · SD-15 V06 · V07):
##   ① 검문소 낮: 검문소장 · 계엄병 · 분대장, BJ 경계(−30)면 차단봉 내려옴 · 황보서현 '멈추십시오, 관리 후보' · 분류관 '미등록자는 상담 대상 아님' →
##   ② BJ 우호(25)로 올리면 권은서가 임시 등록증 M-120 발급 · 차단봉 조건 열림 · 배급소는 상설화(MQ-106 뒤) 전엔 닫힘 → 상설화 뒤 V07 재고 →
##   ③ 밤: 검문소장은 막사(Q-01) → ④ 중계소: 정비 당번장 · 개통파 당번장 마당 → GS-02 류정 첫 만남(GS_MET_RJ) · 대기등 → 천공 카드 벽(MQ-106 결과 있으면 내 번호) →
##   GS-03 「도성 문답」 LR-50 → GS-01 대기실 → V06 재고 → ⑤ 출입구 이음 을 돌며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/gate_relay_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
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
	host.date_text = "2277. 10. 31.  10:00"
	_hour()
	host.enter("X-SG", "arrive")


func _hour() -> void:
	host.st.vars.set_v("GAME_HOUR", int(host.date_text.substr(host.date_text.length() - 5, 2)))


func _ids() -> Array:
	return host.npcs.map(func(n): return str(n["id"]))


func _cond_props(nm: String) -> Array:
	var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/X-SG.json"))
	return (d["props"] as Array).filter(func(p): return str(p["name"]) == nm)


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	for c in host.get_children():
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
				_check(ids.has("N-R01-047") and ids.count("CR-401") >= 4 and ids.has("CR-403"), "검문소 낮: 검문소장 · 계엄병 넷 · 분대장")
				var down: Array = _cond_props("bj_boom")
				_check(down.size() == 2 and InteriorMap._cond_ok(str(down[0]["cond"]), st), "BJ 경계(−30): 차단봉 둘이 내려와 있다")
				_stand(1113 - 15 + 15, 1454 + 12)
				_go()
		1:
			if t > 0.8:
				_shot("1_gate")
				host.play_scene("SG_HWANG")
				_go()
		2:
			if host.box.active and t > 0.2 and not has_meta("s2"):
				set_meta("s2", true)
				_shot("2_hwang")
				return
			if _finish("됐습니다"):
				_check(int(st.vars.get_v("SG_MET_HWANG")) == 1, "황보서현 첫 만남 · 경계 호칭")
				host.enter("Q-02", "from_X")
				_go()
		3:
			if t > 1.2:
				_check(_ids().has("N-R01-048"), "Q-02 분류반 천막: 권은서")
				host.play_scene("SG_KWON")
				_go()
		4:
			if _finish("됐습니다"):
				_check(not st.items.has("M-120"), "미등록(경계): 등록증 발급 없음")
				st.vars.set_v("AFF_BJ", 25)
				host.play_scene("SG_KWON")
				_go()
		5:
			if host.box.active and t > 0.2 and not has_meta("s3"):
				set_meta("s3", true)
				_shot("3_kwon")
				return
			if _drive(func(s: Dictionary) -> int: return _opt(s, "임시 등록")):
				_go()
		6:
			if _finish("배급소"):
				_check(st.items.has("M-120") and int(st.vars.get_v("SG_ISSUED")) == 1, "우호(25): 임시 등록증 M-120 '충성 4등급' 발급")
				var up: Array = _cond_props("bj_boom_up")
				_check(InteriorMap._cond_ok(str(up[0]["cond"]), st) and not InteriorMap._cond_ok(str(_cond_props("bj_boom")[0]["cond"]), st), "등록증 + 우호: 차단봉 조건이 올라감으로 바뀐다")
				_check(not host.get_children().any(func(c): return c is TradeScreen), "상설화 전: 배급소 닫힘(거래 창이 열리지 않는다)")
				st.vars.set_v("MQ106_RESULT", 3)
				st.vars.set_v("PD_R01_BJ", 10)
				host.shop_state("V07")
				var m: Dictionary = host.merchants.get("V07", {})
				_check(str(m.get("npc", "")) == "N-R01-048" and (m.get("stock", []) as Array).size() >= 6, "상설화 뒤 V07 배급소 재고 %d종" % (m.get("stock", []) as Array).size())
				host.date_text = "2277. 10. 31.  22:00"
				_hour()
				host.enter("Q-01", "from_X")
				_go()
		7:
			if t > 1.2:
				_check(_ids().has("N-R01-047"), "밤: 검문소장은 막사 무전 당번")
				_stand(8, 8)
				_go()
		8:
			if t > 0.8:
				_shot("4_barracks")
				host.date_text = "2277. 11. 01.  10:00"
				_hour()
				host.enter("X-GS", "arrive")
				_go()
		9:
			if t > 1.8:
				var ids := _ids()
				_check(ids.has("N-R01-055") and ids.has("C-053") and ids.has("N-GS-1"), "중계소 마당 낮: 정비 당번장 · 개통파 당번장 · 신도")
				_stand(898 - 15 + 14, 1183 + 16)
				_go()
		10:
			if t > 0.8:
				_shot("5_relay")
				host.enter("GS-02", "from_X")
				_go()
		11:
			if t > 1.2:
				_check(_ids().has("C-014") and _ids().has("N-R01-054"), "GS-02 대기등 홀: 류정 · 노신도 마노을")
				_stand(11, 12)
				host.play_scene("GS_RJ")
				_go()
		12:
			if host.box.active and t > 0.2 and not has_meta("s6"):
				set_meta("s6", true)
				_shot("6_lamp_hall")
				return
			if _finish("됐습니다"):
				_check(int(st.vars.get_v("GS_MET_RJ")) == 1, "류정 첫 만남(GS_MET_RJ — MQ-207 '이미 앎')")
				host.play_scene("GS_CARDS")
				_go()
		13:
			if _finish(""):
				_check(int(st.vars.get_v("GS_CARD_SEEN")) == 1, "천공 카드 벽: 공보방송이 부른 내 번호 카드(MQ-106 결과 있음)")
				host.enter("GS-03", "from_GS-02")
				_go()
		14:
			if t > 1.2:
				_check(_ids().has("N-R01-502"), "GS-03 서고: 응답자 하은결")
				host.play_scene("GS_LR50")
				_go()
		15:
			if _finish(""):
				_check(int(st.vars.get_v("GS_LR50")) == 1, "「도성 문답」 LR-50")
				_stand(9, 6)
				_go()
		16:
			if t > 0.8:
				_shot("7_library")
				host.enter("GS-01", "from_X")
				_go()
		17:
			if t > 1.2:
				_stand(16, 10)
				host.shop_state("V06")
				var m: Dictionary = host.merchants.get("V06", {})
				_check(str(m.get("npc", "")) == "N-R01-055" and not (m.get("stock", []) as Array).is_empty(), "V06 부품 교환대 재고 %d종" % (m.get("stock", []) as Array).size())
				_go()
		18:
			if t > 0.8:
				_shot("8_waiting_room")
				var bad: Array = []
				for mid in ["X-SG", "Q-01", "Q-02", "X-GS", "GS-01", "GS-02", "GS-03"]:
					var d: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % mid))
					for e in d["exits"]:
						var to := str(e["to"])
						if to == "W":
							continue
						var td: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % to))
						if not td["marks"].has(str(e["mark"])):
							bad.append("%s→%s:%s" % [mid, to, e["mark"]])
				_check(bad.is_empty(), "출입구 이음: 손 맵 둘 · 실내 5장의 모든 출구 표지가 있다 %s" % str(bad))
				_go()
		19:
			if t > 0.5:
				var n := checks.filter(func(c): return c[0]).size()
				print("검문소 · 중계소 벤치: %s %d/%d" % ["○" if n == checks.size() else "×", n, checks.size()])
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
	get_viewport().get_texture().get_image().save_png("%s/gate_%s.png" % [shots, tag])   # 마지막으로 그린 화면(맵을 바꾸기 전)
