## 함정 · 환경 폭발 확인 장면(단계 1-9c, SD-11 §9.2 · §9.3): 사당 승강장(D-02) 빈 바닥에 원자력 차량 · 드럼 · 부비트랩 자판기 · 가스 누출 배관 소품과
## 숨긴 함정(철선 · 덫 · 지향성 지뢰 · 압력판 + 함정 산탄총)을 놓고 ① 발견(3t) ② 해체 진행 ③ 차를 쏘아 불붙음 ④ 차 폭발 + 드럼 연쇄 ⑤ 자판기 경보 · 폭발 ⑥ 가스 점화
## 를 차례로 보여 주며 스크린샷과 확인을 남긴다.
## 실행: xvfb-run godot --path game --resolution 1280x720 res://scenes/bench/hazards_check.tscn -- [스크린샷 폴더]
extends Node2D

var st: StoryState
var map: InteriorMap
var combat: InteriorCombat
var pc: Actor
var shots_dir := ""
var checks: Array = []
var o := Vector2i.ZERO
var stage := 0
var t := 0.0
var cam: Camera2D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	shots_dir = args[0] if args.size() > 0 else ""
	st = StoryState.new()
	st.load_data()
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("PC_SKP_REPAIR", 30)
	st.vars.set_v("PC_PE", 7)
	map = InteriorMap.new()
	map.load_map("D-02", st)
	add_child(map)
	o = _open(16, 9)
	map.data["traps"] = [
		{"type": "wire", "x": o.x + 2, "y": o.y + 1, "dir": "E", "len": 3, "id": "", "link": "", "cond": ""},
		{"type": "bear", "x": o.x + 6, "y": o.y + 2, "dir": "E", "len": 1, "id": "", "link": "", "cond": ""},
		{"type": "claymore", "x": o.x + 7, "y": o.y + 4, "dir": "W", "len": 2, "id": "", "link": "", "cond": ""},
		{"type": "plate", "x": o.x + 3, "y": o.y + 7, "dir": "E", "len": 1, "id": "", "link": "s1", "cond": ""},
		{"type": "shotgun", "x": o.x + 7, "y": o.y + 7, "dir": "W", "len": 1, "id": "s1", "link": "", "cond": ""}]
	map.add_runtime_prop("car_wreck", o + Vector2i(11, 1))
	map.add_runtime_prop("drum", o + Vector2i(14, 4))
	map.add_runtime_prop("trap_vending", o + Vector2i(11, 6))
	map.add_runtime_prop("gas_pipe", o + Vector2i(14, 7))
	combat = InteriorCombat.new()
	map.add_child(combat)
	pc = Actor.new()
	pc.setup_doll(CharDocs.paperdoll_look(CharDocs.look_of(st)), _at(1, 4), map)
	map.add_actor(pc)
	combat.on_map(map, pc, st)
	for e in combat.enemies.duplicate():
		combat.drop_enemy(e)
	st.call_fn("give", ["W-002", 1])
	st.call_fn("give", ["10mm 탄", 60])
	cam = Camera2D.new()
	cam.zoom = Vector2(1.5, 1.5)
	cam.position = _at(8, 4) + Vector2(0, -8)
	add_child(cam)
	cam.make_current()


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


func _at(dx: int, dy: int) -> Vector2:
	return Vector2((o.x + dx) * 32 + 16, (o.y + dy) * 32 + 16)


func _item(tp: String) -> Dictionary:
	for it in combat.hazards.items:
		if it["type"] == tp and (it["cell"] as Vector2i).x >= o.x and (it["cell"] as Vector2i).y >= o.y:
			return it
	return {}


func _process(dt: float) -> void:
	t += dt
	combat.tick(dt, true, st)
	pc.move(Vector2.ZERO, dt)
	match stage:
		0:                                                              # 발견: 가운데로 걸어가며 숨긴 함정이 보인다
			pc.loco.place(_at(4, 4))
			if t > 0.4:
				_check(_item("wire")["seen"] and _item("bear")["seen"], "3t 안 숨긴 함정 발견(철선 · 덫)")
				_check(_item("claymore")["seen"], "지향성 지뢰: 인지력 7이면 4t에서 발견")
				_shot("1_seen")
				_go()
		1:                                                              # 철선 해체(웅크려 1초)
			combat.crouch = true
			pc.loco.place(_at(3, 2))
			combat.disarm_tick(dt, st)
			if t > 0.5 and t - dt <= 0.5:
				_shot("2_disarm")
			if t > 1.2:
				_check(_item("wire")["state"] == "done" and int(st.items.get("W-060", 0)) == 2, "철선 해체 · 수류탄 둘 회수")
				combat.crouch = false
				_go()
		2:                                                              # 차를 쏜다 → 불붙음
			pc.loco.place(_at(8, 2))
			combat.equip("W-002", st)
			combat.bot = {"aim": (_item("car")["p"] as Vector2), "fire": true}
			if _item("car")["state"] == "burning" or t > 6.0:
				combat.bot = {"aim": _at(12, 2)}
				_check(_item("car")["state"] == "burning", "원자력 차량: 누적 피해 50 → 불붙음")
				pc.loco.place(_at(2, 4))
				_go()
		3:
			if t > 1.0 and t - dt <= 1.0:
				_shot("3_burning")
			if _item("car")["state"] == "done":
				_go()
		4:
			if t > 0.15 and t - dt <= 0.15:
				_shot("4_car_boom")
			if t > 0.6:
				var dr := combat.hazards.items.filter(func(it): return it["cell"] == o + Vector2i(14, 4))
				_check(not dr.is_empty() and dr[0]["state"] == "done", "차 폭발 → 드럼 연쇄")
				_check(combat.ord.zones.any(func(z): return z["kind"] == "rad"), "방사능 지대(15초)")
				pc.loco.place(_at(10, 6))
				_go()
		5:                                                              # 자판기 경보 → 폭발
			if t > 0.7 and t - dt <= 0.7:
				_shot("5_vending_beep")
				pc.loco.place(_at(4, 5))
			if t > 1.75 and t - dt <= 1.75:
				_shot("6_vending_boom")
			if t > 2.2:
				_check(_item("vending")["state"] == "done", "부비트랩 자판기: 경보 1.5초 → 폭발")
				combat.pc.hp = combat.pc.max_hp
				combat.pc.holds.clear()
				_go()
		6:                                                              # 가스 누출을 쏜다 → 점화
			pc.loco.place(_at(10, 7))
			combat.bot = {"aim": (_item("gas")["p"] as Vector2), "fire": true}
			if _item("gas")["state"] == "done":
				_shot("7_gas")
				_check(true, "가스 누출: 탄 → 점화 · 넘어짐")
				combat.bot = {"aim": _at(1, 7)}
				_go()
			elif t > 4.0:
				_check(false, "가스 누출 점화")
				_go()
		7:                                                              # 압력판 → 함정 산탄총
			combat.pc.hp = combat.pc.max_hp
			combat.pc.holds.clear()
			pc.loco.place(_at(3, 7))
			if t > 0.05 and t - dt <= 0.05:
				_shot("8_plate_shotgun")
			if t > 0.4:
				_check(_item("shotgun")["state"] == "done", "압력판 → 함정 산탄총")
				_finish()


func _go() -> void:
	stage += 1
	t = 0.0


func _shot(nm: String) -> void:
	if shots_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(shots_dir)
	get_viewport().get_texture().get_image().save_png(shots_dir.path_join(nm + ".png"))


func _check(ok: bool, what: String) -> void:
	checks.append([ok, what])
	print(("○ " if ok else "✕ ") + what)


func _finish() -> void:
	stage = 99
	print("함정·환경 폭발 확인: %d/%d" % [checks.filter(func(c): return c[0]).size(), checks.size()])
	get_tree().quit()
