## 인카운터 확인 장면(단계 1-3): MQ-101이 끝난 1막 아침, 봉천 북쪽 큰길(C-21-31 근처)에서 생포 추적대(RE-087)를 바로 세운다.
## 실행: godot --path game res://scenes/bench/encounter_check.tscn --write-movie out.png --fixed-fps 10 --quit-after 400 -- [talk|fight|leave|roach|capture]
## talk = 다가와 말을 걸 때까지 · fight = '덤벼 봐' → 교전 · leave = [화술] 성공 처리 → 물러남 · roach = 밤 RE-004 · capture = 교전 중 HP 0 → 생포
extends Node

var host: InteriorHost
var mode := "talk"
var t := 0.0
var picked := false
var log_t := 0.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	mode = args[0] if args.size() > 0 else "talk"
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.quests.set_stage("MQ-101", 50)
	st.vars.set_v("MQ101_NIGHT", 3)
	st.vars.set_v("MQ101_RESULT", 1)
	st.vars.set_v("GAME_DAY", 2)
	st.vars.set_v("PC_CAPS", 120)
	Wanted.set_value(st, 10)
	st.events.clear()
	st.quests.events.clear()
	st.call_fn("give", ["W-002"])
	st.call_fn("give", ["10mm 탄", 24])
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	host.date_text = "2277. 10. 24.  09:20" if mode != "roach" else "2277. 10. 24.  22:10"
	host.enter("W", "", {}, Vector2(833 * 32 + 16, 1343 * 32 + 16))      # 신림 사거리 고가(L-R01-15) 도착 칸
	host.combat.equip("W-002", st)
	st.events.clear()
	host.enc_live.ended.connect(func(re, how): print("인카운터 끝: %s %s" % [re, how]))
	host.pc_died.connect(func(): print("쓰러짐"))
	host.combat.player_down.connect(host.on_pc_down)
	var ok := host.enc_live.start({"re": "RE-004" if mode == "roach" else "RE-087", "src": "bench"})
	print("인카운터 세움: ", ok, " · 상태 ", host.enc_live.cur.get("state", ""))


func _process(dt: float) -> void:
	t += dt
	log_t += dt
	if log_t >= 1.0:
		log_t = 0.0
		var c := host.enc_live.cur
		var lead := ""
		if not c.get("actors", []).is_empty() and is_instance_valid(c["actors"][0]):
			var a: Actor = c["actors"][0]
			lead = " · 앞장 %.1f타일 경로 %d/%d 칸 %s" % [a.loco.logical.distance_to(host.player.loco.logical) / 32.0,
				int(a.get_meta("pi", 0)), (a.get_meta("path", PackedVector2Array()) as PackedVector2Array).size(), str(host.map.tile_of(a.loco.logical))]
		print("[%4.1f초] 상태 %s · 대화 %s · HP %d · 적 %d · 시각 %s%s" % [t, str(c.get("state", "-")), str(host.box.active),
			int(host.combat.pc.hp), host.combat.alive_enemies(), host.date_text, lead])
	if host.box.active:
		var s: Dictionary = host.box.state
		if s.get("type", "") == "line":
			if fmod(t, 0.8) < dt:
				host.box.next()
		elif s.get("type", "") == "choices" and not picked and t > 0.5:
			picked = true
			host.box.pick(1 if mode == "leave" else 0)
	if mode == "capture" and host.enc_live.cur.get("state", "") == "fight" and host.combat.pc.hp > 0.0 and t > 6.0:
		host.combat.pc.take({"hp": host.combat.pc.hp + 5.0}, host.player.loco.logical)   # 생포 확인: 쓰러뜨린다
