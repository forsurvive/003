## 투척·설치(SD-11 §3.4 투척·설치 계열 · §9.2 폭발물과 지뢰 · SD-13 §3.8.4, 단계 1-9b): 던진 수류탄 · 놓인 지뢰 · 지대(불 · 최루 · 연막).
## - 수류탄: 포물선(가짜 높이) → 착지점은 산포 반경 `1.5 − 폭발물/100`t 안에서 흩어지고, 벽에 한 번 튕긴다. 시간 신관 2.5초(던진 순간부터).
##   화염병 · 최루탄 · 연막탄은 착탄하면 바로 지대가 된다. 적이 던진 수류탄은 떨어질 자리에 붉은 원(외부 반경)을 그린다.
## - 지뢰: 설치 1초 뒤 활성 → 1.2t 안에 설치자 편이 아닌 대상이 들어오면 경보 → 경보 시간 뒤 폭발
##   (주인공 지뢰 `0.8 × (1 − 폭발물/200)`초 · 적 지뢰 `0.8 × (1 + 폭발물/200)`초). 웅크려 1t 안에서 1초 해체 → 회수(폭발물 I(15)).
## - 연쇄: 폭발 외부 반경 안의 지뢰 · 수류탄은 0.2초 뒤 유폭한다.
## - 지대: 불(초당 화상, 불 위의 대상은 갱신) · 최루(인간형 명중 −30% · 인지력 −2, 구울 · 로봇 · 파워 아머 무효) · 연막(안에 있는 대상은 보이지 않는다).
## 폭발 판정 · 그림은 Projectiles.explode(같은 식, DR 절반, 엄폐)를 쓴다.
class_name Ordnance
extends Node2D

const FUSE := 2.5
const SPREAD_BASE := 1.5                       ## 착지 산포 반경(타일) = 1.5 − 폭발물/100
const MINE_SENSE := 1.2 * 32.0
const MINE_ALARM := 0.8
const DISARM_R := 1.0 * 32.0
const DISARM_S := 1.0
const DISARM_SKILL := 15                       ## 폭발물 I(15) — 파편 · 펄스 지뢰 해체 요구(SD-11 §9.2)
const CHAIN_S := 0.2
const THROW_HOLD_S := 1.2                      ## 1.2초 누르면 최대 거리
var shots: Projectiles
var rng := RandomNumberGenerator.new()
var nades: Array = []                          ## {from, to, bounce, t, fly, fuse, w, team, skill, p, h, spin, landed}
var mines: Array = []                          ## {p, w, team, skill, arm, alarm(-1 = 조용), chain, disarm}
var zones: Array = []                          ## {p, r, t, kind, team, w, skill}
var thrown_total := 0
var placed_total := 0
var disarmed_total := 0


func _ready() -> void:
	rng.seed = 2277
	z_index = 4


## 던지기: 누른 시간(0~1.2초)이 거리(최대 = 투척 사거리)를 정한다. to를 주면 그 자리(봇 · 적)를 겨눈다.
func throw(from: Vector2, aim: Vector2, w: Dictionary, team: String, skill: float, max_t: float, hold := THROW_HOLD_S) -> Dictionary:
	var dir := (aim - from).normalized() if aim.distance_to(from) > 1.0 else Vector2.RIGHT
	var want := minf(from.distance_to(aim), max_t * 32.0 * clampf(hold / THROW_HOLD_S, 0.15, 1.0))
	var land := from + dir * want
	var sr := maxf(0.0, SPREAD_BASE - skill / 100.0) * 32.0              # 착지 산포
	land += Vector2.RIGHT.rotated(rng.randf() * TAU) * sr * sqrt(rng.randf())
	var path := _bounce(from, land)
	var d := from.distance_to(path[0]) + (path[0] as Vector2).distance_to(path[1])
	var n := {"from": from, "mid": path[0], "to": path[1], "t": 0.0, "fly": lerpf(0.4, 0.6, clampf(d / (6.0 * 32.0), 0.0, 1.0)),
		"fuse": float(w.get("fuse", 0.0)), "w": w, "team": team, "skill": skill, "p": from, "h": 0.0, "spin": 0, "landed": false,
		"kind": _look(w)}
	nades.append(n)
	thrown_total += 1
	return n


## 벽에 한 번 튕긴다: 날아가는 길이 벽 · 높은 엄폐에 닿으면 그 자리에서 면에 반사해 남은 길의 절반만 더 간다
func _bounce(a: Vector2, b: Vector2) -> Array:
	var n := int(ceil(a.distance_to(b) / 6.0)) + 1
	var prev := a
	for i in range(1, n + 1):
		var p := a.lerp(b, float(i) / n)
		var t := Vector2i(floori(p.x / 32), floori(p.y / 32))
		if shots.world != null and (shots.world.is_solid(t) or int(shots.world.cover_at(t)) >= 2):
			var pt := Vector2i(floori(prev.x / 32), floori(prev.y / 32))
			var rest := b - prev
			if pt.x != t.x:
				rest.x = -rest.x
			if pt.y != t.y:
				rest.y = -rest.y
			var back := prev + rest * 0.5
			var bt := Vector2i(floori(back.x / 32), floori(back.y / 32))
			if shots.world.is_solid(bt) or int(shots.world.cover_at(bt)) >= 2:
				back = prev
			return [prev, back]
		prev = p
	return [b, b]


## 설치: 발밑 0.8t 앞(SD-11 §3.4). 설치 1초 뒤 활성
func place(at: Vector2, facing: Vector2, w: Dictionary, team: String, skill: float) -> Dictionary:
	var p := at + facing.normalized() * 0.8 * 32.0
	if shots.world != null and (shots.world.is_solid(Vector2i(floori(p.x / 32), floori(p.y / 32)))):
		p = at
	var m := {"p": p, "w": w, "team": team, "skill": skill, "arm": float(w.get("arm_s", 1.0)), "alarm": -1.0, "chain": -1.0,
		"disarm": 0.0, "kind": _look(w)}
	mines.append(m)
	placed_total += 1
	return m


## 맵에 깔린 지뢰(적 편): 바로 활성
func lay(at: Vector2, w: Dictionary, skill := 30.0) -> Dictionary:
	var m := place(at, Vector2.ZERO, w, "enemy", skill)
	m["arm"] = 0.0
	placed_total -= 1
	return m


static func _look(w: Dictionary) -> String:
	var nm := str(w.get("name", ""))
	if w.get("kind", "") == "mine":
		return "cap" if nm.contains("병뚜껑") else ("pulse" if str(w.get("blast_kind", "")) == "emp" else "frag")
	if str(w.get("zone", "")) == "fire" or nm.contains("화염병"):
		return "molotov"
	if str(w.get("zone", "")) == "gas":
		return "gas"
	if str(w.get("zone", "")) == "smoke":
		return "smoke"
	match str(w.get("blast_kind", "")):
		"emp": return "pulse"
		"plasma": return "plasma"
	return "nuka" if nm.contains("번개") else "frag"


func step(dt: float, combatants: Array) -> void:
	for n in nades.duplicate():
		n["t"] = float(n["t"]) + dt
		var k := clampf(float(n["t"]) / float(n["fly"]), 0.0, 1.0)
		var d1 := (n["from"] as Vector2).distance_to(n["mid"])
		var d2 := (n["mid"] as Vector2).distance_to(n["to"])
		var s := k * (d1 + d2)
		n["p"] = (n["from"] as Vector2).lerp(n["mid"], s / d1) if s <= d1 or d2 < 0.5 else (n["mid"] as Vector2).lerp(n["to"], (s - d1) / maxf(0.5, d2))
		n["h"] = 4.0 * 22.0 * k * (1.0 - k) if s <= d1 else 4.0 * 8.0 * k * (1.0 - k)
		n["spin"] = int(float(n["t"]) * 12.0) % 4 if k < 1.0 else int(n["spin"])
		if k >= 1.0 and not n["landed"]:
			n["landed"] = true
			n["h"] = 0.0
			if str(n["w"].get("zone", "")) != "":                     # 화염병 · 최루탄 · 연막탄: 착탄 즉시 지대
				_zone(n)
				nades.erase(n)
				continue
		if float(n["fuse"]) > 0.0 and float(n["t"]) >= float(n["fuse"]):
			_boom(n["p"], n["w"], float(n["skill"]), str(n["team"]))
			nades.erase(n)
	for m in mines.duplicate():
		if float(m["arm"]) > 0.0:
			m["arm"] = float(m["arm"]) - dt
			continue
		if float(m["chain"]) >= 0.0:
			m["chain"] = float(m["chain"]) - dt
			if float(m["chain"]) <= 0.0:
				mines.erase(m)
				_boom(m["p"], m["w"], float(m["skill"]), str(m["team"]))
			continue
		if float(m["alarm"]) < 0.0:
			for c in combatants:
				if c.dead or c.team == m["team"] or c.team in ["gone", "target", "resident"] or (m["team"] == "player" and c.team == "ally"):
					continue
				if c.pos().distance_to(m["p"]) <= MINE_SENSE + c.radius:
					var ex := float(m["skill"])
					m["alarm"] = MINE_ALARM * ((1.0 - ex / 200.0) if m["team"] == "player" else (1.0 + ex / 200.0))
					break
		else:
			m["alarm"] = float(m["alarm"]) - dt
			if float(m["alarm"]) <= 0.0:
				mines.erase(m)
				_boom(m["p"], m["w"], float(m["skill"]), str(m["team"]))
	for z in zones.duplicate():
		z["t"] = float(z["t"]) - dt
		if float(z["t"]) <= 0.0:
			zones.erase(z)
			continue
		if z["kind"] == "fire":                                        # 불 위의 대상: 화상 갱신(SD-13 W-057 '화염 5/초(5초)')
			for c in combatants:
				if not c.dead and c.team not in ["gone", "target"] and c.pos().distance_to(z["p"]) <= float(z["r"]):
					c.add_dot("burn", float(z["w"].get("dot", 5.0)), 1.0)
					c.last_by = str(z["team"])
	queue_redraw()


func _zone(n: Dictionary) -> void:
	var w: Dictionary = n["w"]
	zones.append({"p": n["p"], "r": float(w.get("zone_r", 2.0)) * 32.0, "t": float(w.get("zone_s", 5.0)), "t0": float(w.get("zone_s", 5.0)),
		"kind": str(w["zone"]), "team": n["team"], "w": w})


func _boom(at: Vector2, w: Dictionary, skill: float, team: String) -> void:
	var pw := w.duplicate()
	pw["proj"] = "grenade" if str(w.get("kind", "")) != "mine" else "mine"
	if str(w.get("name", "")).contains("병뚜껑"):
		pw["proj"] = "capmine"
	shots.explode(at, pw, skill, team)
	if float(w.get("dot", 0.0)) > 0.0:                                 # 번개 수류탄: 폭발 + 화염 지대
		zones.append({"p": at, "r": 2.0 * 32.0, "t": float(w.get("dot_s", 5.0)), "t0": float(w.get("dot_s", 5.0)), "kind": "fire", "team": team,
			"w": {"dot": w["dot"]}})
	var outer := float(Arms.blast_r(str(pw["proj"]))[1]) * 32.0
	for m in mines:                                                    # 연쇄 폭발: 외부 반경 안 지뢰 · 수류탄 0.2초 뒤
		if float(m["chain"]) < 0.0 and (m["p"] as Vector2).distance_to(at) <= outer:
			m["chain"] = CHAIN_S
			m["arm"] = 0.0
	for n in nades:
		if (n["p"] as Vector2).distance_to(at) <= outer and float(n["fuse"]) > 0.0:
			n["fuse"] = minf(float(n["fuse"]), float(n["t"]) + CHAIN_S)


## 해체: 웅크려 1t 안에서 1초. 스킬이 모자라면 못 한다(경보가 울리는 중이면 남은 시간 안에 끝내야 한다). 끝나면 돌려준 지뢰(회수)
func near_mine(p: Vector2) -> Dictionary:
	var best := {}
	var bd := DISARM_R
	for m in mines:
		var d := (m["p"] as Vector2).distance_to(p)
		if d <= bd:
			bd = d
			best = m
	return best


func disarm_step(m: Dictionary, dt: float, skill: float) -> String:
	if not mines.has(m):
		return "gone"
	if skill < DISARM_SKILL:
		return "skill"
	m["disarm"] = float(m["disarm"]) + dt
	if float(m["disarm"]) >= DISARM_S:
		mines.erase(m)
		disarmed_total += 1
		return "done"
	return "busy"


## 지대 묻기: kind 지대 안인가(연막 · 최루 판정)
func in_zone(p: Vector2, kind: String) -> bool:
	for z in zones:
		if z["kind"] == kind and (z["p"] as Vector2).distance_to(p) <= float(z["r"]):
			return true
	return false


# ---------------------------------------------------------------- 그림
func _draw() -> void:
	var tex := CombatFx.sheet()
	var frame := Engine.get_process_frames()
	for z in zones:                                                   # 지대: 32칸 덩이를 반경만큼 흩어 깐다(3컷 순환)
		var set_name := "zone_" + str(z["kind"])
		if not CombatFx.has_set(set_name):
			continue
		var r := float(z["r"])
		var n := maxi(1, int(r * r / 260.0))
		var k0 := int(float(z["t"]) * 5.0)
		for i in n:
			var a := float(i) * 2.399
			var rr := r * 0.75 * sqrt((float(i) + 0.5) / n)
			var c: Vector2 = (z["p"] as Vector2) + Vector2(cos(a), sin(a) * 0.8) * rr
			var rg := CombatFx.region(set_name, 0.0, (k0 + i) % 3)
			if float(z["t"]) < 1.0 and (i + k0) % 2 == 1:
				continue                                              # 사그라드는 지대: 덩이가 줄어든다
			draw_texture_rect_region(tex, Rect2(c - rg.size * 0.5, rg.size), rg)
	for m in mines:
		var blink := 1 if float(m["arm"]) <= 0.0 and (float(m["alarm"]) >= 0.0 and int(frame / 4) % 2 == 0 or int(frame / 40) % 2 == 0) else 0
		var rg := CombatFx.region("mine_" + str(m["kind"]), 0.0, blink)
		draw_texture_rect_region(tex, Rect2((m["p"] as Vector2) - rg.size * 0.5, rg.size), rg)
		if float(m["alarm"]) >= 0.0:
			draw_arc(m["p"], MINE_SENSE, 0, TAU, 24, Color("A82A26"), 1.0)
	for n in nades:
		if str(n["team"]) != "player" and float(n["fuse"]) > 0.0:   # 적 수류탄 경고: 떨어질 자리에 붉은 원(외부 반경)
			var pr := "grenade"
			draw_arc(n["to"], float(Arms.blast_r(pr)[1]) * 32.0, 0, TAU, 32, Color("E04A35"), 1.0)
		var at: Vector2 = n["p"]
		if float(n["h"]) > 0.0:
			draw_circle(at, 2.5, Color(0, 0, 0, 0.35))
		var rg := CombatFx.region("thrown_" + str(n["kind"]), 0.0, int(n["spin"]))
		draw_texture_rect_region(tex, Rect2(at - Vector2(0, float(n["h"])) - rg.size * 0.5, rg.size), rg)
