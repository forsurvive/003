## 라디오 확인 장면(단계 1-10b, SD-12 §10 · SD-17 §4): 생성 창고 G-444-1265(1막)에서
##   ① 남산 방송 자막 띠(잡음 · 송미래 얼굴) + HUD [라디오] 표시 ② 탈출 소식이 대기열 → 다음 편성에 먼저 ③ 공보방송(남궁혁 담화)
##   ④ 교전 중 1행 ⑤ R 길게(0.6초) = 끄기 — 재장전하지 않는다 ⑥ 핍-보이 데이터 > 라디오(목록 · 상세 · 지난 소식) ⑦ 터치 배치 를 보이며 확인한다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/radio_check.tscn -- [스크린샷 폴더]
extends Node

var host: InteriorHost
var shots := ""
var checks: Array = []
var t := 0.0
var stage := 0
var e1: Enemy


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots = args[0] if args.size() > 0 else ""
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("P_REGNO", "S07-58-0193")
	st.events.clear()
	st.quests.events.clear()
	host.body = "adult"
	host.hud_on = true
	host.pipboy_ok = true
	host.story_hold = true
	host.date_text = "2277. 10. 24.  14:20"
	host.enter("G-444-1265", "")
	host.combat.pc.hp = 99999.0
	host.combat.pc.max_hp = 99999.0
	for x in host.combat.enemies.duplicate():
		host.combat.drop_enemy(x)
	host.hints.clear()


## 맞춘 방송국에서 자막 줄이 나올 때까지(또는 그 블록 종류가 나올 때까지) 방송을 앞으로 감는다
func _seek(kind := "", id_prefix := "") -> bool:
	var r := host.st.radio
	for i in 4000:
		r.tick(0.1, host.st, host._rctx if not host._rctx.is_empty() else host.radio_ctx())
		var np := r.now_playing()
		if str(np.get("kind", "")) == "line" and (kind == "" or str(np["bkind"]) == kind) and str(np["block"]).begins_with(id_prefix) and float(np["age"]) < 0.3:
			return true
	return false


func _process(dt: float) -> void:
	t += dt
	var r := host.st.radio
	var c := host.combat
	match stage:
		0:
			if t > 0.3:
				_check(r.heard.has("ST-01") and r.heard.has("ST-02") and not r.heard.has("ST-11"), "볼트 밖: 남산 · 공보 잡힘, 구내방송 안 잡힘")
				r.tune("ST-01")
				_check(_seek(), "남산 방송 자막 줄")
				_check(Radio.quality("ST-01", host.radio_ctx()) == 1, "봉천 · 관악: 남산 방송은 잡음 섞임")
				_go()
		1:
			if t > 0.2 and t - dt <= 0.2:
				_shot("1_band_namsan")
			if t > 0.4:
				host.st.vars.set_v("V_ESCAPE", 2)                           # 탈출(은신) 소식 → 대기열
				r._chk = 0.0
				r.tick(0.01, host.st, host.radio_ctx())
				_check(r.queue.has("N-P4") and r.queue.has("N-P4-2"), "탈출 소식이 대기열에(처음 참이 된 순간)")
				_check(_seek("news", "N-P4"), "다음 편성: 뉴스 머리 징글 → 소식 먼저")
				_go()
		2:
			if t > 0.2 and t - dt <= 0.2:
				_shot("2_band_news")
			if t > 0.4:
				r.tune("ST-02")
				_check(_seek("speech") or _seek("notice"), "공보방송: 담화 · 공고")
				_go()
		3:
			if t > 0.2 and t - dt <= 0.2:
				_check(Radio.quality("ST-02", host.radio_ctx()) == 0, "공보방송: 깨끗")
				_shot("3_band_gov")
			if t > 0.4:
				e1 = c.spawn("CR-420", host.player.loco.logical + Vector2(160, 0), host.map, host.st, {"lv": 3})
				e1.brain.state = AIBrain.S.COMBAT
				e1.brain.gauge = 100.0
				e1._cool = 999.0
				r.tune("ST-01")
				_seek()
				_go()
		4:
			if e1 != null and is_instance_valid(e1):
				e1._cool = 999.0
				e1._move = Vector2.ZERO
				e1._path = PackedVector2Array()
			if t > 0.3 and t - dt <= 0.3:
				_check(c.in_combat(), "교전 중")
				_shot("4_combat_1row")
			if t > 0.5:
				c.drop_enemy(e1)
				e1 = null
				var mag0 := int(c.mags.get(c.weapon_id, 0))
				c.r_long = false
				host._r_hold = 0.0
				Input.action_press("reload")
				stage = 5
				t = 0.0
				set_meta("mag0", mag0)
		5:
			if t > 0.75 and t - dt <= 0.75:
				_check(not r.on and c.r_long, "R 0.6초 길게: 라디오 끔")
				Input.action_release("reload")
			if t > 0.9:
				_check(c.reload_t <= 0.0, "길게 누른 R은 재장전하지 않는다")
				host.radio_toggle()
				_check(r.on, "다시 켬")
				host.open_pipboy()
				_go()
		6:
			if host.pipboy == null:
				return
			if t > 0.4 and t - dt <= 0.4:
				host.pipboy.open_at(2, 4)
				host.pipboy.rows = host.pipboy._rows()
				host.pipboy.sel = 0
				for i in host.pipboy.rows.size():
					if str(host.pipboy.rows[i]["id"]) == "ST-01":
						host.pipboy.sel = i
				host.pipboy.view.queue_redraw()
			if t > 0.9 and t - dt <= 0.9:
				var ids: Array = host.pipboy.rows.map(func(x): return str(x["id"]))
				_check(ids.has("ST-01") and ids.has("ST-02") and ids.has("past"), "핍-보이 라디오 목록: 방송국 · 지난 소식(%s)" % str(ids))
				_shot("5_pip_station")
			if t > 1.1 and t - dt <= 1.1:
				host.pipboy.sel = host.pipboy.rows.map(func(x): return str(x["id"])).find("past")
				host.pipboy.view.queue_redraw()
			if t > 1.5 and t - dt <= 1.5:
				_check(not r.news_log.is_empty() and str(r.news_log[0]["id"]).begins_with("N-P4"), "지난 소식에 탈출 소식")
				_shot("6_pip_past")
			if t > 1.8:
				host.pipboy.close(true)
				host.touch_layout = true
				_go()
		7:
			if t > 0.2 and t - dt <= 0.2:
				host.hints.clear()
				_seek()
			if t > 0.5:
				_shot("7_touch")
				_finish()


func _go() -> void:
	stage += 1
	t = 0.0


func _shot(nm: String) -> void:
	print("DBG %s %s q=%d hud=%.2f" % [nm, str(host.st.radio.now_playing()).left(120), Radio.quality(host.st.radio.tuned, host._rctx), host._hud_t])
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
	print("라디오 확인: %d/%d" % [checks.filter(func(x): return x[0]).size(), checks.size()])
	get_tree().quit()
