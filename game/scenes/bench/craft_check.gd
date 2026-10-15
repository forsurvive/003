## 제작 확인 장면(단계 1-8c, SD-13 §7.9 · SD-12 §11.3): 봉천 대장간 마당의 한결 공구 작업대에서
##   ① 작업대 앞 '작업대' → 제작 창(설계도 가진 것만) → ② 압력 대못총(설계도 2장 · 수리 상한 = 만든 직후 상태) →
##   ③ 병뚜껑 지뢰(설계도 3장 = 세트당 3개 · 캡 10) → ④ 수리 키트 → ⑤ [조리] 탭: 맑은 물부터 · 한강 물로 끓이면 라드 변형 →
##   ⑥ 퍽 레시피 잠김 · 드럼통 화덕은 조리만 · 휴대용 버너로 어디서나 조리 → ⑦ 만든 대못총 장착(소총 그림)
##   을 돌며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/craft_check.tscn -- [스크린샷 폴더]
extends Node

const BENCH := Vector2i(911, 1374)                 ## 작업대(911~912,1373) 아래 칸 — 위를 보고 선다
const FIRE := Vector2i(904, 1376)                  ## 드럼통 화덕(X-BC 42,37)

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
	st.vars.set_v("PC_CAPS", 100)
	st.vars.set_v("PC_SKP_REPAIR", 25)
	st.events.clear()
	st.quests.events.clear()
	for kv in [["M-102", 2], ["M-032", 1], ["M-018", 1], ["M-030", 1], ["M-033", 1],          # 압력 대못총 설계도 2장 + 재료
			["M-100", 3], ["M-045", 1], ["M-044", 1], ["M-017", 1],                             # 병뚜껑 지뢰 설계도 3장 + 재료(캡 10)
			["M-010", 5], ["M-025", 1], ["M-024", 1],                                           # 수리 키트 · 대못
			["I-023", 2], ["I-057", 1], ["I-054", 1]]:                                          # 컵라면 2 · 정화수 1 · 한강 물 1
		st.call_fn("give", kv)
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true
	host.story_hold = true
	host.date_text = "2277. 10. 26.  14:00"
	host.enter("X-BC", "from_B-01")


func _process(dt: float) -> void:
	t += dt
	var st := host.st
	match stage:
		0:
			if t > 1.5:
				_stand(BENCH, 6)
				_go()
		1:
			if t > 0.6 and not has_meta("s0"):
				set_meta("s0", true)
				_shot("0_bench_world")
				return
			if t > 1.0:
				var wb := host.bench_front()
				_check(not wb.is_empty() and bool(wb["bench"]) and host.interact_label() == "작업대", "작업대 앞: '작업대' %s" % str(wb))
				host.interact()
				_check(host.craft_ui != null and host.craft_ui.bench and not host.craft_ui.cook, "작업대 → 제작 창(제작 탭)")
				if host.craft_ui == null:
					stage = 8
					return
				var l := Craft.listing(st, false)
				_check(l.has("W-153") and l.has("W-151") and not l.has("W-155") and l.has("I-067"), "목록: 설계도 가진 것만(대못총·지뢰 O, 토치 검 X) + 설계도 없는 레시피 %s" % str(l))
				host.craft_ui.focus_on("r:W-153")
				host.craft_ui._press("r:W-153")
				_go()
		2:
			if t > 0.8 and not has_meta("s1"):
				set_meta("s1", true)
				_shot("1_bench_weapon")
				return
			if t > 1.2:
				var q := Craft.quality(st, "W-153")
				var cap := Gear.repair_cap(st.skill("REPAIR"))
				host.craft_ui._press("make")
				var key := Gear.key_of("W-153", q)
				_check(q == cap and int(st.items.get(key, 0)) == 1 and not st.items.has("M-032"),
					"압력 대못총: 설계도 2장 → 수리 상한 그대로(%s, 수리 %d) · 재료 소모" % [Gear.NAMES[q], st.skill("REPAIR")])
				set_meta("gun", key)
				host.craft_ui._press("r:W-151")
				var caps0 := int(st.vars.get_v("PC_CAPS"))
				host.craft_ui._press("make")
				_check(int(st.items.get("W-151", 0)) == 3 and caps0 - int(st.vars.get_v("PC_CAPS")) == 10, "병뚜껑 지뢰: 설계도 3장 → 세트당 3개 · 캡 10 녹임")
				host.craft_ui._press("r:I-067")
				host.craft_ui._press("make")
				_check(int(st.items.get("I-067", 0)) == 1 and int(st.items.get("M-010", 0)) == 3, "수리 키트: 고철 2 · 테이프 · 접착제")
				_check(Craft.max_sets(st, "M-074") == 0 and not Craft.perk_ok(st, Craft.recipes["M-074"]), "휴대 정수 키트: 퍽(PK-111) 없으면 잠김")
				host.craft_ui._press("tab_cook")
				_go()
		3:
			if t > 0.8 and not has_meta("s2"):
				set_meta("s2", true)
				host.craft_ui.focus_on("r:I-077")
				host.craft_ui._press("r:I-077")
				return
			if t > 1.2 and not has_meta("s3"):
				set_meta("s3", true)
				_shot("2_bench_cook")
				return
			if t > 1.6:
				host.craft_ui._press("make")
				_check(int(st.items.get("I-077", 0)) == 1 and not st.items.has("I-057") and int(st.items.get("I-054", 0)) == 1, "끓인 컵라면: 맑은 물(정화수)부터 쓴다 → 라드 2")
				host.craft_ui._press("make")
				var dirty := "I-077+I-054"
				_check(int(st.items.get(dirty, 0)) == 1 and int(host.items_db.get(dirty, {}).get("rads", 0)) == 10,
					"한강 물로 끓이면 '끓인 컵라면(한강 물)' 라드 10(재료 합)")
				host.craft_ui.close(true)
				_go()
		4:
			if t > 0.5:
				_stand(FIRE + Vector2i(0, 1), 6)
				_go()
		5:
			if t > 0.6:
				var wb := host.bench_front()
				_check(not wb.is_empty() and not bool(wb["bench"]) and host.interact_label() == "조리", "드럼통 화덕 앞: '조리'(제작 탭 없음) %s" % str(wb))
				_stand(BENCH + Vector2i(-6, 4), 2)
				st.call_fn("give", ["M-047", 1])
				st.call_fn("give", ["I-038", 1])
				host._pip_action("use", "M-047")
				_go()
		6:
			if t > 0.6 and host.craft_ui != null and not has_meta("s4"):
				set_meta("s4", true)
				_check(not host.craft_ui.bench and not host.craft_ui.station and host.craft_ui.cook, "휴대용 버너: 아무 데서나 조리 창(조리만)")
				host.craft_ui.focus_on("r:I-081")
				host.craft_ui._press("r:I-081")
				return
			if has_meta("s4") and t > 1.2 and not has_meta("s5"):
				set_meta("s5", true)
				_shot("3_burner")
				return
			if has_meta("s5") and t > 1.6:
				host.craft_ui._press("make")
				_check(int(st.items.get("I-081", 0)) == 1 and int(st.items.get("M-047", 0)) == 1, "멧돼지 구이(버너는 남는다)")
				host.craft_ui.close(true)
				host.combat.equip(str(get_meta("gun")), st)
				_go()
		7:
			if t > 0.8:
				var w := host.combat.weapon()
				_check(str(w.get("name", "")) == "압력 대못총" and str(w.get("ammo_id", "")) == "건설용 대못", "만든 압력 대못총 장착(탄: 건설용 대못)")
				_shot("4_equipped")
				_go()
		8:
			if t > 0.6:
				var n := checks.filter(func(c): return c[0]).size()
				print("제작 벤치: %s %d/%d" % ["○" if n == checks.size() else "×", n, checks.size()])
				stage = 99
				get_tree().create_timer(0.3).timeout.connect(get_tree().quit)


## 주인공을 칸에 세우고 방향(EventRunner.DIR_IDX: 0 E · 2 S · 4 W · 6 N)을 본다
func _stand(c: Vector2i, facing: int) -> void:
	host.player.loco.place(Vector2(c.x * 32 + 16, c.y * 32 + 16))
	host.player.loco.facing = facing
	host.player._show()


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
	get_viewport().get_texture().get_image().save_png("%s/craft_%s.png" % [shots, tag])
