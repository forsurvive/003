## 무기 계열 확인 장면(단계 1-9a, SD-11 §3 · SD-16 §10.1 · §10.4): 사당 환승촌 승강장(D-02)의 빈 바닥에서 주인공이
## 계열마다 무기를 들고 허수아비 셋을 향해 쏜다/휘두른다 — 권총 · 기관단총 · 레이저 소총 · 전투 산탄총 · 미니건(예열) · 화염방사기 ·
## 미사일 발사기(폭발) · 유탄 발사기(곡사) · 야구 방망이(파워 공격 · 넉백) · 해머 · 식칼 · 맨주먹. 무기마다 0.06 · 0.3 · 0.6초 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/arms_check.tscn -- [스크린샷 폴더]
extends Node2D

const ROUND := [["W-002", "fire"], ["W-015", "fire"], ["W-023", "fire"], ["W-029", "fire"], ["W-032", "fire"], ["W-030", "fire"],
	["W-033", "fire"], ["W-031", "fire"], ["W-047", "power"], ["W-050", "fire"], ["W-037", "fire"], ["W-052", "fire"]]
const SHOT_AT := [0.06, 0.3, 0.6]
var st: StoryState
var map: InteriorMap
var combat: InteriorCombat
var pc: Actor
var cam: Camera2D
var shots_dir := ""
var checks: Array = []
var idx := -1
var t := 0.0
var taken := 0
var dummies: Array = []
var origin := Vector2.ZERO
var stats0 := {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots_dir = args[0] if args.size() > 0 else ""
	st = StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("PC_SKP_BIG_GUNS", 40)
	st.vars.set_v("PC_SKP_ENERGY", 40)
	map = InteriorMap.new()
	map.load_map("D-02", st)
	add_child(map)
	var o := _open(14, 5)
	origin = Vector2(o.x * 32 + 16, (o.y + 2) * 32 + 16)
	combat = InteriorCombat.new()
	map.add_child(combat)
	pc = Actor.new()
	pc.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), origin, map)
	map.add_actor(pc)
	combat.on_map(map, pc, st)
	for e in combat.enemies.duplicate():
		combat.drop_enemy(e)
	for id in ["W-002", "W-015", "W-023", "W-029", "W-032", "W-030", "W-033", "W-031", "W-047", "W-050", "W-037"]:
		st.call_fn("give", [id, 1])
	for a in [["10mm 탄", 200], ["마이크로퓨전 전지", 100], ["12게이지 산탄", 40], ["5mm 탄", 400], ["화염방사기 연료", 200], ["미사일", 6], ["40mm 유탄", 12]]:
		st.call_fn("give", a)
	cam = Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position = origin + Vector2(130, -20)
	add_child(cam)
	cam.make_current()
	_next()


func _open(w: int, h: int) -> Vector2i:
	for y in range(2, 60):
		for x in range(2, 80):
			var ok := true
			for dy in h:
				for dx in w:
					var tt := Vector2i(x + dx, y + dy)
					if map.is_solid(tt) or map.cover_at(tt) != 0:
						ok = false
				if not ok:
					break
			if ok:
				return Vector2i(x, y)
	return Vector2i(4, 4)


func _next() -> void:
	idx += 1
	t = 0.0
	taken = 0
	for d in dummies:
		if is_instance_valid(d):
			combat.drop_enemy(d)
	dummies.clear()
	if idx >= ROUND.size():
		_finish()
		return
	var id: String = ROUND[idx][0]
	pc.loco.place(origin)
	combat.pc.holds.clear()
	combat.ap.ap = combat.ap.max_ap
	combat.cool = 0.0
	combat.equip(Arms.FIST if id == "W-052" else id, st)
	var w := combat.weapon()
	var near := str(w["kind"]) != "ranged"
	var gap := 30.0 if near else (3.0 if Arms.proj(w) == "flame" else 6.0) * 32.0
	for k in 3:
		var at := origin + Vector2(gap + (0 if near else k * 20.0), (k - 1) * (14.0 if near else 40.0))
		var e := combat.spawn("CR-420", at, map, st, {"lv": 3})
		e.cmb.hp = 600.0
		e.cmb.max_hp = 600.0
		e.cmb.dr = 0.0
		e.cmb.unaware = Callable()
		dummies.append(e)
	stats0 = {"shots": int(combat.stats["shots"]), "hits": int(combat.stats["hits"]), "hits_p": int(combat.shots.hits_total),
		"booms": int(combat.shots.blasts_total), "power": combat.power_hits}
	combat.bot = {"aim": origin + Vector2(gap, -10), "aimed": true, ROUND[idx][1]: true}


func _process(dt: float) -> void:
	if idx >= ROUND.size():
		return
	t += dt
	for e in dummies:                                                 # 허수아비는 맞기만 한다(제자리)
		if is_instance_valid(e):
			e.has_token = false
			e._cool = 99.0
			e._t_tac = -99.0                                           # 전술(다가오기) 없음 — 맞고 밀리기만
			e._move = Vector2.ZERO
	combat.tick(dt, true, st)
	pc.move(Vector2.ZERO, dt)                                         # 조준 자세 · 인형 갱신(호스트가 하던 일)
	if ROUND[idx][1] == "power" and t > 0.1:
		combat.bot.erase("power")
	if taken < SHOT_AT.size() and t >= SHOT_AT[taken]:
		_shot("%02d_%s_%d" % [idx, ROUND[idx][0], taken])
		taken += 1
	if t >= 1.4:
		_judge()
		_next()


func _judge() -> void:
	var id: String = ROUND[idx][0]
	var w := combat.weapon()
	var dmg := 0.0
	for e in dummies:
		if is_instance_valid(e):
			dmg += e.cmb.max_hp - e.cmb.hp
	var nm := str(w.get("name", id))
	match Arms.fam(w):
		"heavy":
			if Arms.proj(w) in ["missile", "grenade"]:
				_check(combat.shots.blasts_total > int(stats0["booms"]) and dmg > 0.0, "%s: 폭발 · 피해 %.0f" % [nm, dmg])
			else:
				_check(dmg > 0.0, "%s: 피해 %.0f (사격 %d)" % [nm, dmg, int(combat.stats["shots"]) - int(stats0["shots"])])
		"melee1", "melee2", "unarmed":
			if ROUND[idx][1] == "power":
				_check(combat.power_hits > int(stats0["power"]) and dmg > 0.0, "%s: 파워 공격 · 피해 %.0f · AP %.0f" % [nm, dmg, combat.ap.ap])
			else:
				_check(int(combat.stats["hits"]) > int(stats0["hits"]), "%s: 닿는다 · 피해 %.0f" % [nm, dmg])
		_:
			_check(dmg > 0.0, "%s: 피해 %.0f (사격 %d · 명중 %d)" % [nm, dmg, int(combat.stats["shots"]) - int(stats0["shots"]),
				combat.shots.hits_total - int(stats0["hits_p"])])
	_check(pc.doll != null and pc.doll.look["weapon"] == Arms.doll(w), "%s: 손 무기 그림 '%s'" % [nm, Arms.doll(w)])


func _shot(nm: String) -> void:
	if shots_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(nm + ".png"))


func _check(ok: bool, what: String) -> void:
	checks.append([ok, what])
	print(("○ " if ok else "✕ ") + what)


func _finish() -> void:
	var n := checks.filter(func(c): return c[0]).size()
	print("무기 계열 확인: %d/%d" % [n, checks.size()])
	get_tree().quit()
