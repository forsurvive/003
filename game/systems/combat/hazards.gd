## 함정 · 환경 폭발(SD-11 §9.2 함정 표 · §9.3 환경 폭발, 단계 1-9c).
## 함정(맵 자료 traps + 함정 소품): 인계철선 + 수류탄 다발 · 압력판(연결 함정 발동) · 덫(다리 · 2초 묶임) · 함정 산탄총(철선·압력판 연결) ·
##   폭탄 택배함(2t 접근) · 부비트랩 자판기(접근 → 경보음 → 폭발 + 파편 지뢰) · 폭탄 단말기(쓰려 하면 감전 + 폭발) · 도시가스 누출(불씨 → 점화 · 넘어짐) ·
##   중국군 지향성 지뢰(철선 → 부채꼴 4t 파편, 인지력 7 이상이면 발견 반경 +1t). 방사능 함정은 방사능 구역(1-9d)과 함께.
##   숨긴 함정(철선 · 압력판 · 덫 · 지향성 지뢰)은 3t 안에 들어와야 보인다(발견하면 계속 보인다). 웅크려 1t 안에서 1초 상호작용 = 해체(요구 기술 · 회수).
## 환경 폭발: 원자력 차량(승용차 · 버스 · 화물차) 누적 피해 50(버스 120) → 불붙음 → 4초 뒤 폭발(1.5/4t, 300, DR 절반) → 방사능 지대 15초.
##   불붙은 차를 쏘면 1초씩 앞당긴다. 연료 드럼 · 가스통 피해 30 → 폭발(0.8/2.5t, 120, 화상). 연쇄 폭발. 처치 XP 없음(편 env).
## 터진 · 해체한 자리는 st.hazards("맵:x,y")에 남아 다시 열어도 그대로다.
class_name Hazards
extends Node2D

const CARS := {"car_wreck": 50.0, "car_wreck2": 50.0, "bus_wreck": 120.0, "convoy_truck": 120.0}
const DRUMS := {"drum": 30.0, "lp_gas": 30.0}
const PROP_TRAPS := {"trap_vending": "vending", "trap_parcel": "parcel", "gas_pipe": "gas"}
const HIDDEN := ["wire", "plate", "bear", "claymore"]
## 해체 요구(SD-10 스킬 단계 II 25 · III 50 · IV 75) — 둘 중 하나면 된다
const NEED := {"wire": [["수리", 25], ["폭발물", 25]], "plate": [["수리", 25]], "bear": [["수리", 25]], "shotgun": [["수리", 50]],
	"parcel": [["폭발물", 50]], "vending": [["폭발물", 75]], "terminal": [["폭발물", 50]], "claymore": [["폭발물", 75]]}
const LOOT := {"wire": ["W-060", 2], "shotgun": ["12게이지 산탄", 3], "parcel": ["W-060", 1], "vending": ["W-063", 1], "claymore": ["W-063", 1]}
const SEE_T := 3.0
const CAR_BURN_S := 4.0
var shots: Projectiles
var ord: Ordnance
var weapons := {}
var st: StoryState
var map
var map_id := ""
var items: Array = []                          ## {key, kind(car·drum·trap), type, cell, cells, p, hp, burn, state, dir, len, id, link, seen, beep}
var stats := {"triggered": 0, "disarmed": 0, "cars": 0, "drums": 0, "gas": 0}
var _sync_t := 0.0
var _ground: Node2D


func _init() -> void:
	z_index = 4
	_ground = Node2D.new()
	_ground.z_index = -9
	add_child(_ground)
	_ground.draw.connect(_draw_ground)


func bind(p: Projectiles, o: Ordnance, w: Dictionary) -> void:
	shots = p
	ord = o
	weapons = w
	shots.struck.connect(_on_struck)
	shots.exploded.connect(_on_blast)


func setup(m, s: StoryState) -> void:
	map = m
	st = s
	map_id = str(m.data.get("id", ""))
	items.clear()
	for t in m.data.get("traps", []):
		if not InteriorMap._cond_ok(str(t.get("cond", "")), s):
			continue
		var c := Vector2i(int(t["x"]), int(t["y"]))
		var it := {"key": _key(c), "kind": "trap", "type": str(t["type"]), "cell": c, "cells": _trap_cells(t), "p": Vector2(c.x * 32 + 16, c.y * 32 + 16),
			"dir": str(t.get("dir", "E")), "len": int(t.get("len", 1)), "id": str(t.get("id", "")), "link": str(t.get("link", "")), "state": "ready",
			"seen": false, "beep": -1.0}
		_restore(it)
		items.append(it)
	_sync_props()


func _key(c: Vector2i) -> String:
	return "%s:%d,%d" % [map_id, c.x, c.y]


static func _trap_cells(t: Dictionary) -> Array:
	var c := Vector2i(int(t["x"]), int(t["y"]))
	var out: Array = [c]
	if str(t["type"]) in ["wire", "claymore"]:
		var d: Vector2i = {"E": Vector2i(1, 0), "W": Vector2i(-1, 0), "S": Vector2i(0, 1), "N": Vector2i(0, -1)}[str(t.get("dir", "E"))]
		for k in range(1, int(t.get("len", 3 if t["type"] == "wire" else 2)) + (0 if t["type"] == "wire" else 1)):
			out.append(c + d * k)
	return out


func _restore(it: Dictionary) -> void:
	var s := str(st.hazards.get(it["key"], "")) if st != null else ""
	if s in ["done", "off", "burnt", "boom"]:
		it["state"] = "done"
	if s == "seen":
		it["seen"] = true


## 소품 위험물(차 · 드럼 · 가스통 · 함정 소품): 맵 소품에서 찾는다. 월드는 청크가 오가니 0.5초마다 맞춘다
func _sync_props() -> void:
	var have := {}
	for it in items:
		have[it["key"]] = true
	var live := {}
	for p in map.props:
		var nm := str(p["name"])
		if not (CARS.has(nm) or DRUMS.has(nm) or PROP_TRAPS.has(nm)):
			continue
		var c := Vector2i(int(p["x"]), int(p["y"]))
		var k := _key(c)
		live[k] = true
		if have.has(k):
			continue
		var cells: Array = []
		for yy in range(c.y, c.y + int(p.get("h", 1))):
			for xx in range(c.x, c.x + int(p.get("w", 1))):
				cells.append(Vector2i(xx, yy))
		var ctr := Vector2((c.x + int(p.get("w", 1)) * 0.5) * 32, (c.y + int(p.get("h", 1)) * 0.5) * 32)
		var it := {"key": k, "cell": c, "cells": cells, "p": ctr, "name": nm, "state": "ready", "seen": true, "beep": -1.0, "burn": -1.0}
		if CARS.has(nm):
			it.merge({"kind": "car", "type": "car", "hp": CARS[nm]})
		elif DRUMS.has(nm):
			it.merge({"kind": "drum", "type": "drum", "hp": DRUMS[nm]})
		else:
			it.merge({"kind": "trap", "type": PROP_TRAPS[nm]})
		_restore(it)
		if it["state"] == "done":
			map.set_prop_state(c, "burnt" if it["kind"] in ["car", "drum"] else "boom")
		items.append(it)
	if map is WorldMap:                                                # 내려간 청크의 소품은 목록에서 뺀다
		items = items.filter(func(it): return it["kind"] == "trap" and not it.has("name") or live.has(it["key"]))


# ---------------------------------------------------------------- 맞음 · 폭발
func _hit_item(tile: Vector2i) -> Dictionary:
	for it in items:
		if it["state"] != "done" and (it["cells"] as Array).has(tile):
			return it
	return {}


func _on_struck(at: Vector2, tile: Vector2i, w: Dictionary, team: String) -> void:
	var it := _hit_item(tile)
	if it.is_empty():
		return
	_damage(it, float(w.get("dmg", 5.0)), team)


func _on_blast(at: Vector2, outer: float, team: String) -> void:
	for it in items.duplicate():
		if it["state"] == "done":
			continue
		var d := (it["p"] as Vector2).distance_to(at)
		if d > outer + 24.0:
			continue
		match it["type"]:
			"car", "drum":
				_damage(it, 120.0 * (1.0 - clampf(d / (outer + 24.0), 0.0, 0.8)), team)   # 폭발에 휘말림: 가까울수록 크다(드럼 30 · 차 50 · 버스 120)
			"gas":
				_ignite(it, team)
			"parcel", "vending", "claymore", "wire":
				_trigger(it, team)                                       # 연쇄: 폭탄 함정도 터진다


func _damage(it: Dictionary, amt: float, team: String) -> void:
	match it["type"]:
		"car":
			if it["state"] == "burning":
				it["burn"] = maxf(0.2, float(it["burn"]) - 1.0)          # 불붙은 차를 쏘면 앞당긴다
				return
			it["hp"] = float(it["hp"]) - amt
			if float(it["hp"]) <= 0.0:
				it["state"] = "burning"
				it["burn"] = CAR_BURN_S
				it["team"] = team
		"drum":
			it["hp"] = float(it["hp"]) - amt
			if float(it["hp"]) <= 0.0:
				_drum_boom(it)
		"gas":
			_ignite(it, team)
		"parcel", "vending":
			_trigger(it, team)


func _car_boom(it: Dictionary) -> void:
	it["state"] = "done"
	stats["cars"] += 1
	_mark(it, "burnt")
	shots.explode(it["p"], {"blast": 300.0, "proj": "car", "condition": "new", "name": "원자력 차량"}, 100.0, "env")
	ord.zones.append({"p": it["p"], "r": 3.0 * 32.0, "t": 15.0, "t0": 15.0, "kind": "rad", "team": "env", "w": {"rad": 5.0}})   # 방사능 지대(1-9d가 읽는다)


func _drum_boom(it: Dictionary) -> void:
	it["state"] = "done"
	stats["drums"] += 1
	_mark(it, "burnt")
	shots.explode(it["p"], {"blast": 120.0, "proj": "drum", "condition": "new", "blast_burn": 3.0}, 100.0, "env")


func _ignite(it: Dictionary, team: String) -> void:
	if it["state"] == "done":
		return
	it["state"] = "done"
	stats["gas"] += 1
	_mark(it, "boom")
	shots.explode(it["p"], {"blast": 30.0, "proj": "gas", "condition": "new", "blast_burn": 2.0}, 100.0, "env")
	for c in shots.combatants:                                         # 점화: 넘어짐 2초(SD-11 §9.2)
		if not c.dead and c.pos().distance_to(it["p"]) <= 2.0 * 32.0:
			c.hold("down", 2.0)


func _mark(it: Dictionary, state: String) -> void:
	if st != null:
		st.hazards[it["key"]] = "done"
	if it.has("name") and map != null:
		map.set_prop_state(it["cell"], state)


# ---------------------------------------------------------------- 함정 발동
func _trigger(it: Dictionary, team: String = "enemy") -> void:
	if it["state"] == "done":
		return
	stats["triggered"] += 1
	var p: Vector2 = it["p"]
	match it["type"]:
		"wire":                                                         # 수류탄 다발: 말뚝 자리에 셋이 떨어져 1초 뒤 터진다
			it["state"] = "done"
			_mark(it, "")
			for k in 3:
				var n := ord.throw(p, p + Vector2(k * 6 - 6, 4), weapons["W-060"], "enemy", 40.0, 0.5, 0.2)
				n["fuse"] = 1.0 + k * 0.1
			_fire_links(it)
		"plate":
			it["state"] = "done"
			_mark(it, "")
			_fire_links(it)
		"shotgun":                                                      # 함정 산탄총: 산탄 1발(전투 산탄총 판정)
			it["state"] = "done"
			_mark(it, "")
			var ang := {"E": 0.0, "S": 90.0, "W": 180.0, "N": -90.0}[str(it.get("dir", "E"))] as float
			shots.fire_weapon(p + Vector2(0, -8), ang, "enemy", weapons["W-028"], 50.0)
		"parcel":
			it["state"] = "done"
			_mark(it, "boom")
			shots.explode(p, weapons["W-060"].merged({"proj": "grenade"}, true), 50.0, "enemy")
		"vending":                                                      # 경보음 1.5초 → 폭발 + 파편 지뢰
			if float(it["beep"]) < 0.0:
				it["beep"] = 1.5
		"terminal":
			it["state"] = "done"
			_mark(it, "")
			for c in shots.combatants:
				if not c.dead and c.team == "player" and c.pos().distance_to(p) <= 48.0:
					c.take({"hp": 20.0, "part": "torso"}, p)                 # 감전
					c.hold("stun", 1.0)
			shots.explode(p, {"blast": 60.0, "proj": "grenade", "condition": "new"}, 50.0, "enemy")
		"claymore":                                                     # 부채꼴 4t 파편(펠릿 판정을 빌린다)
			it["state"] = "done"
			_mark(it, "")
			var ang := {"E": 0.0, "S": 90.0, "W": 180.0, "N": -90.0}[str(it.get("dir", "E"))] as float
			var w := {"dmg": 135.0, "crit_dmg": 0.0, "kind": "ranged", "proj": "pellet", "pellets": 9, "cone": 30.0, "family": "shotgun",
				"range_eff": 4.0, "range_max": 4.5, "falloff_min": 0.4, "name": "지향성 지뢰"}
			shots.fire_weapon(p, ang, "enemy", w, 50.0, {"flash": "flash_shotgun"})
			shots.booms.append({"at": p, "age": 0.0, "k": 1, "born": Engine.get_process_frames(), "set": "boom"})
		"bear":
			pass


func _fire_links(it: Dictionary) -> void:
	var lk := str(it.get("link", ""))
	if lk == "":
		return
	for o in items:
		if str(o.get("id", "")) == lk and o["state"] != "done":
			_trigger(o)


## 단말기를 쓰려 한다: 폭탄 단말기면 터지고 true(호스트는 단말을 열지 않는다)
func on_use(cell: Vector2i) -> bool:
	for it in items:
		if it["type"] == "terminal" and it["state"] != "done" and (it["cell"] == cell or (it["cell"] as Vector2i).distance_to(cell) <= 1.0):
			_trigger(it, "player")
			return true
	return false


# ---------------------------------------------------------------- 매 프레임
func step(dt: float, combatants: Array) -> void:
	_sync_t -= dt
	if _sync_t <= 0.0 and map != null and map is WorldMap:
		_sync_t = 0.5
		_sync_props()
	var pc: Combatant = null
	for c in combatants:
		if c.team == "player":
			pc = c
	var see := SEE_T * 32.0
	for it in items:
		if it["state"] == "done":
			continue
		var tp: String = it["type"]
		if pc != null and not it["seen"] and tp in HIDDEN:            # 발견: 3t(+1t 지향성 지뢰 · 인지력 7 이상)
			var r := see + (32.0 if tp == "claymore" and st != null and st.stat("PE") >= 7 else 0.0)
			var dmin := INF
			for cc in it["cells"]:                                         # 철선 · 지향성 지뢰는 가장 가까운 칸으로 잰다
				dmin = minf(dmin, pc.pos().distance_to(Vector2(cc.x * 32 + 16, cc.y * 32 + 16)))
			if dmin <= r:
				it["seen"] = true
				if st != null:
					st.hazards[it["key"]] = "seen"
		match tp:
			"car":
				if it["state"] == "burning":
					it["burn"] = float(it["burn"]) - dt
					if float(it["burn"]) <= 0.0:
						_car_boom(it)
			"vending":
				if float(it["beep"]) >= 0.0:
					it["beep"] = float(it["beep"]) - dt
					if float(it["beep"]) < 0.0:
						it["state"] = "done"
						_mark(it, "boom")
						shots.explode(it["p"], {"blast": 120.0, "proj": "grenade", "condition": "new"}, 50.0, "enemy")
						ord.lay(it["p"] + Vector2(0, 40), weapons["W-063"])
				elif pc != null and pc.pos().distance_to(it["p"]) <= 1.5 * 32.0:
					_trigger(it, "player")
			"parcel":
				if pc != null and pc.pos().distance_to(it["p"]) <= 2.0 * 32.0:
					_trigger(it, "player")
			"gas":
				for s in shots.shots:                                      # 불씨: 지나가는 탄 · 화염
					if (s["p"] as Vector2).distance_to(it["p"]) <= 1.5 * 32.0:
						_ignite(it, str(s["team"]))
						break
				for bm in shots.beams:
					if Geometry2D.get_closest_point_to_segment(it["p"], bm["a"], bm["b"]).distance_to(it["p"]) <= 1.5 * 32.0:
						_ignite(it, "player")
						break
			"wire", "plate", "bear", "claymore":
				for c in combatants:
					if c.dead or c.team in ["enemy", "gone", "target", "resident"] or c.big:
						continue
					var cell := Vector2i(floori(c.pos().x / 32), floori(c.pos().y / 32))
					if not (it["cells"] as Array).has(cell):
						continue
					if tp == "bear":                                    # 덫: 다리 부위 손상 · 2초 묶임
						it["state"] = "done"
						it["shut"] = true
						_mark(it, "")
						c.take({"hp": 25.0, "part": "leg"}, it["p"])
						c.set_meta("leg_hurt", true)
						c.hold("root", 2.0)
						stats["triggered"] += 1
					else:
						_trigger(it, c.team)
					break
	queue_redraw()
	_ground.queue_redraw()


# ---------------------------------------------------------------- 해체
func near(p: Vector2) -> Dictionary:
	var best := {}
	var bd := 1.0 * 32.0 + 8.0
	for it in items:
		if it["state"] == "done" or not NEED.has(it["type"]) or (it["type"] in HIDDEN and not it["seen"]):
			continue
		var d := INF
		for c in it["cells"]:
			d = minf(d, Vector2(c.x * 32 + 16, c.y * 32 + 16).distance_to(p))
		if d <= bd:
			bd = d
			best = it
	return best


func can_disarm(it: Dictionary) -> bool:
	for need in NEED.get(it["type"], []):
		if st != null and st.skill(str(need[0])) >= int(need[1]):
			return true
	return false


func need_text(it: Dictionary) -> String:
	return " 또는 ".join((NEED.get(it["type"], []) as Array).map(func(n): return "%s %d" % [n[0], n[1]]))


func finish_disarm(it: Dictionary) -> void:
	it["state"] = "done"
	stats["disarmed"] += 1
	if st != null:
		st.hazards[it["key"]] = "off"
		var lt: Array = LOOT.get(it["type"], [])
		if not lt.is_empty():
			st.call_fn("give", [lt[0], int(lt[1])])


# ---------------------------------------------------------------- 그림
func _draw() -> void:
	var tex := CombatFx.sheet()
	for it in items:                                                  # 불붙은 차: 덩이 불길(위층)
		if it["type"] == "car" and it["state"] == "burning":
			var k := int(float(it["burn"]) * 6.0)
			var hot := 1.0 - float(it["burn"]) / CAR_BURN_S                 # 터질 때가 가까울수록 불이 커진다
			var n := 2 + int(hot * 4.0)
			for i in n:
				var rg := CombatFx.region("zone_fire", 0.0, (k + i) % 3)
				var o := Vector2(cos(i * 2.4) * 26.0, sin(i * 2.4) * 8.0 - 18.0 - hot * 6.0)
				draw_texture_rect_region(tex, Rect2((it["p"] as Vector2) + o - rg.size * 0.5, rg.size), rg)
			for i in 3:                                                    # 위로 오르는 불티
				var rf := CombatFx.region("flame", 0.0, (k + i * 2) % 5)
				var q := Vector2(sin(i * 1.7 + k) * 18.0, -34.0 - fmod(float(k) * 3.0 + i * 9.0, 20.0))
				draw_texture_rect_region(tex, Rect2((it["p"] as Vector2) + q - rf.size * 0.5, rf.size), rf)
		if it["type"] == "vending" and float(it["beep"]) >= 0.0 and int(float(it["beep"]) * 8.0) % 2 == 0:
			draw_circle((it["p"] as Vector2) + Vector2(0, -50), 3.0, Color("E04A35"))


func _draw_ground() -> void:
	var tex := CombatFx.sheet()
	for it in items:
		var tp: String = it["type"]
		if not (tp in HIDDEN or tp == "shotgun"):
			continue
		if not it["seen"] and tp != "shotgun":
			continue
		if it["state"] == "done" and tp != "bear":
			continue
		var p: Vector2 = it["p"]
		match tp:
			"bear":
				var rg := CombatFx.region("trap_bear", 0.0, 1 if it.get("shut", false) or it["state"] == "done" else 0)
				_ground.draw_texture_rect_region(tex, Rect2(p - rg.size * 0.5, rg.size), rg)
			"wire", "claymore":
				var cells: Array = it["cells"]
				var a: Vector2 = p
				var b := Vector2((cells[-1] as Vector2i).x * 32 + 16, (cells[-1] as Vector2i).y * 32 + 16)
				_ground.draw_line(a + Vector2(0, -4), b + Vector2(0, -4), Color("ABA49A"), 1.0)
				var rg := CombatFx.region("trap_" + tp, 0.0, 0)
				_ground.draw_texture_rect_region(tex, Rect2(p - rg.size * 0.5, rg.size), rg)
			_:
				var rg := CombatFx.region("trap_" + tp, 0.0, 0)
				_ground.draw_texture_rect_region(tex, Rect2(p - rg.size * 0.5, rg.size), rg)
