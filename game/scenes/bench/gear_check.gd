## 장비 상태 확인 장면(단계 1-8a, SD-13 §8 · SD-11 §11.8 · SD-15 §5.2): 봉천에서
##   ① 핍-보이 소지품(이름 뒤 상태 · 4칸 막대) → ② [R] 스스로 고치기(같은 계열 부품) → ③ 위태 파이프 소총 재장전 20번(탄 걸림 80%)
##   → ④ 남무진(V03) 정비 메뉴(정비비 태그) → ⑤ 정비 한 단계(캡이 줄고 열쇠가 오른다) 를 차례로 돌며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/gear_check.tscn -- [스크린샷 폴더]
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
	st.vars.set_v("GAME_DAY", 3)
	st.vars.set_v("PC_CAPS", 300)
	st.vars.set_v("PC_SKP_REPAIR", 30)
	st.events.clear()
	st.quests.events.clear()
	for k in ["W-002@2", "W-003@4", "W-013@3", "A-004@1", "W-013@1"]:
		st.items[k] = 1
	st.call_fn("give", ["10mm 탄", 60])
	st.call_fn("give", [".32 구경탄", 60])
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 24.  10:20"
	host.enter("X-BC", "")
	host.combat.equip("W-002@2", st)


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	match stage:
		0:
			if t > 1.0:
				var pb := host.open_pipboy()
				pb.open_at(1, 0)
				pb.select_id("W-002@2")
				_go()
		1:
			if t > 0.8 and not has_meta("items_shot"):
				set_meta("items_shot", true)
				_shot("1_pipboy_items")
				return
			if t > 1.2:
				var r := host.repair_self("W-002@2")
				_check(r["ok"] and r["key"] == "W-002@1" and not st.items.has("W-003@4"), "스스로 고치기: 낡음 → 양호(같은 계열 W-003 파손을 부품으로) %s" % str(r))
				_go()
		2:
			if t > 0.8:
				_shot("2_pipboy_repaired")
				if host.pipboy != null:
					host.pipboy.close(true)
				_go()
		3:
			host.combat.equip("W-013@3", st)
			var jams := 0
			for i in 20:
				host.combat.mags[host.combat.weapon_id] = 0
				host.combat.reload_t = 0.0
				var j0 := int(host.combat.stats.get("jams", 0))
				host.combat.start_reload(st)
				jams += int(host.combat.stats.get("jams", 0)) - j0
			_check(jams >= 10 and jams <= 20, "위태 무기 재장전 20번에 탄 걸림 %d번(80%%)" % jams)
			host.combat.equip("W-002@1", st)
			_go()
		4:
			if t > 0.5:
				host.shop_state("V03")                                         # 상인 표를 읽어 둔다(정비 사양)
				var jobs := host.fix_jobs("V03")
				print("  남무진 정비 일감: ", jobs)
				_check(jobs.any(func(j): return str(j["key"]) == "W-013@3") and not jobs.any(func(j): return str(j["key"]).begins_with("W-002")),
					"남무진(수제·공구·TS): 파이프 소총은 맡고 10mm 권총(미군)은 안 맡는다")
				set_meta("caps0", int(st.vars.get_v("PC_CAPS")))
				set_meta("jobs", jobs)
				host.fix_menu("V03")
				_go()
		5:
			if t < 0.4:
				return
			if host.box.active and str(host.box.state.get("type", "")) == "line":
				host.box.next()
				t = 0.0
				return
			if host.box.active and str(host.box.state.get("type", "")) == "choices" and t > 1.0:
				if not has_meta("menu_shot"):
					set_meta("menu_shot", true)
					_shot("3_fix_menu")
					t = 0.5
					return
				var jobs: Array = get_meta("jobs")
				var k := 0
				for i in jobs.size():
					if str(jobs[i]["key"]) == "W-013@3":
						k = i
				host.box.pick(k)
				_go()
		6:
			if host.box.active and t < 6.0:
				if str(host.box.state.get("type", "")) == "line":
					host.box.next()
				return
			if t > 0.5:
				var paid: int = int(get_meta("caps0")) - int(st.vars.get_v("PC_CAPS"))
				_check(st.items.has("W-013@2") and not st.items.has("W-013@3") and paid > 0, "정비 한 단계: 위태 → 낡음, 정비비 %d캡" % paid)
				_shot("4_after_fix")
				_go()
		7:
			var n := checks.filter(func(c): return c[0]).size()
			print("장비 벤치: %s %d/%d" % ["○" if n == checks.size() else "×", n, checks.size()])
			stage = 99
			get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


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
	get_viewport().get_texture().get_image().save_png("%s/gear_%s.png" % [shots, tag])
