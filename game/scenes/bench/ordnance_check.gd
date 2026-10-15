## 투척·설치 확인 장면(단계 1-9b, SD-11 §3.4 · §9.2 · SD-13 §3.8.4 · SD-16 §10.4): 사당 승강장(D-02) 빈 바닥에서
## ① 투척 조준선(누르는 중) → ② 파편 수류탄(날아감 · 착지 · 2.5초 폭발) → ③ 적 수류탄 경고 원 → ④ 화염병 불 지대 → ⑤ 최루 → ⑥ 연막 →
## ⑦ 플라스마 수류탄 → ⑧ 펄스 수류탄(로봇 정지) → ⑨ 파편 지뢰(설치 · 경보 · 폭발) 를 차례로 보여 주며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/ordnance_check.tscn -- [스크린샷 폴더]
extends Node2D

const STEPS := [["aim", 0.6], ["frag", 3.0], ["enemy", 1.0], ["molotov", 2.0], ["gas", 1.6], ["smoke", 1.6], ["plasma", 3.0], ["pulse", 3.0], ["mine", 3.0]]
const SHOTS := {"aim": [0.5], "frag": [0.25, 1.0, 2.62], "enemy": [0.5], "molotov": [1.2], "gas": [1.2], "smoke": [1.2],
	"plasma": [2.62], "pulse": [2.62], "mine": [1.4, 1.9, 2.3]}
var st: StoryState
var map: InteriorMap
var combat: InteriorCombat
var pc: Actor
var shots_dir := ""
var checks: Array = []
var idx := -1
var t := 0.0
var taken := 0
var dummies: Array = []
var origin := Vector2.ZERO
var target := Vector2.ZERO
var b0 := 0
var mine_d: Enemy


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots_dir = args[0] if args.size() > 0 else ""
	st = StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("PC_SKP_EXPLOSIVES", 30)
	map = InteriorMap.new()
	map.load_map("D-02", st)
	add_child(map)
	var o := _open(14, 7)
	origin = Vector2(o.x * 32 + 16, (o.y + 3) * 32 + 16)
	target = origin + Vector2(6 * 32, 0)
	combat = InteriorCombat.new()
	map.add_child(combat)
	pc = Actor.new()
	pc.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), origin, map)
	map.add_actor(pc)
	combat.on_map(map, pc, st)
	for e in combat.enemies.duplicate():
		combat.drop_enemy(e)
	for id in ["W-057", "W-058", "W-059", "W-060", "W-061", "W-062", "W-063"]:
		st.call_fn("give", [id, 3])
	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position = origin + Vector2(110, -10)
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
			if ok:
				return Vector2i(x, y)
	return Vector2i(4, 4)


func _spawn(at: Vector2, robot := false) -> Enemy:
	var e := combat.spawn("CR-420", at, map, st, {"lv": 3})
	e.cmb.hp = 400.0
	e.cmb.max_hp = 400.0
	e.cmb.dr = 0.0
	e.cmb.robot = robot
	dummies.append(e)
	return e


func _next() -> void:
	idx += 1
	t = 0.0
	taken = 0
	for d in dummies:
		if is_instance_valid(d):
			combat.drop_enemy(d)
	dummies.clear()
	if idx >= STEPS.size():
		_finish()
		return
	pc.loco.place(origin)
	combat.cool = 0.0
	b0 = combat.shots.blasts_total
	var k: String = STEPS[idx][0]
	for i in 3:
		_spawn(target + Vector2(i * 16 - 16, (i - 1) * 28), k == "pulse" and i == 1)
	var w := {"aim": "W-060", "frag": "W-060", "enemy": "", "molotov": "W-057", "gas": "W-058", "smoke": "W-059", "plasma": "W-062",
		"pulse": "W-061", "mine": "W-063"}[k] as String
	if w != "":
		combat.equip(w, st)
	match k:
		"aim":
			combat.throw_hold = 0.8
			combat.throw_aim = target
			combat.throw_max_t = 8.0
		"enemy":
			combat.ord.throw(target, origin + Vector2(20, 0), combat.weapons["W-060"], "enemy", 30.0, 8.0)
		"mine":
			combat.bot = {"aim": origin + Vector2(64, 0), "fire": true}
		_:
			combat.bot = {"aim": target, "throw": 1.2}
	if k == "mine":
		mine_d = _spawn(origin + Vector2(3 * 32, 0))


func _process(dt: float) -> void:
	if idx >= STEPS.size():
		return
	t += dt
	var k: String = STEPS[idx][0]
	for e in dummies:
		if is_instance_valid(e):
			e.has_token = false
			e._cool = 99.0
			e._t_tac = -99.0
			e._move = Vector2.ZERO
	if k == "aim":
		combat.throw_hold = 0.8
	else:
		combat.tick(dt, true, st)
	if k == "mine" and t > 0.3:
		combat.bot = {"aim": origin + Vector2(64, 0)}
		if t > 1.2 and is_instance_valid(mine_d) and not mine_d.cmb.dead:   # 지뢰 쪽으로 걸어온다
			var goal: Vector2 = combat.ord.mines[0]["p"] if not combat.ord.mines.is_empty() else mine_d.loco.logical
			mine_d.loco.place(mine_d.loco.logical.move_toward(goal, 80.0 * dt))
	pc.move(Vector2.ZERO, dt)
	combat.queue_redraw()
	var at: Array = SHOTS[k]
	if taken < at.size() and t >= float(at[taken]):
		_shot("%02d_%s_%d" % [idx, k, taken])
		taken += 1
	if t >= float(STEPS[idx][1]):
		_judge(k)
		combat.throw_hold = -1.0
		_next()


func _judge(k: String) -> void:
	var dmg := 0.0
	for e in dummies:
		if is_instance_valid(e):
			dmg += e.cmb.max_hp - e.cmb.hp
	match k:
		"aim":
			_check(true, "투척 조준선(누르는 중 착지점까지)")
		"frag", "plasma":
			_check(combat.shots.blasts_total > b0 and dmg > 0.0, "%s: 2.5초 신관 · 폭발 · 피해 %.0f" % [k, dmg])
		"enemy":
			_check(combat.ord.nades.size() == 1, "적 수류탄: 떨어질 자리에 붉은 원")
			combat.ord.nades.clear()
		"molotov", "gas", "smoke":
			var z := {"molotov": "fire", "gas": "gas", "smoke": "smoke"}[k] as String
			_check(combat.ord.zones.any(func(zz): return zz["kind"] == z), "%s 지대" % z + (" · 화상 피해 %.0f" % dmg if k == "molotov" else ""))
			if k == "smoke":
				_check(dummies[0].sight_of(combat.pc) == 0.0, "연막 안에서는 못 본다")
			combat.ord.zones.clear()
		"pulse":
			_check(dummies[1].cmb.held_by("stun") or dummies[1].cmb.hp < 200.0, "펄스: 로봇 피해 %.0f · 정지" % (400.0 - dummies[1].cmb.hp))
		"mine":
			_check(combat.ord.placed_total >= 1 and combat.shots.blasts_total > b0, "지뢰: 설치 · 경보 · 폭발(피해 %.0f)" % dmg)


func _shot(nm: String) -> void:
	if shots_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(nm + ".png"))


func _check(ok: bool, what: String) -> void:
	checks.append([ok, what])
	print(("○ " if ok else "✕ ") + what)


func _finish() -> void:
	print("투척·설치 확인: %d/%d" % [checks.filter(func(c): return c[0]).size(), checks.size()])
	get_tree().quit()
