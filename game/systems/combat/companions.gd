## 일시 동행 NPC(SD-11 §8.2 · SD-12 §11.4, 단계 1-10a): 동료 시스템이 아니다 — 퀘스트가 붙여 줄 때만, 대화로 '따라와/기다려'만.
## 모드: 추종(기본, 뒤 2~4t · 15t 넘게 떨어져 안 보이면 뒤 3t로) → 교전이 시작되면 엄호(플레이어가 공격한 적 → 플레이어를 공격 중인 적 → 가장 가까운 적,
## 사수는 엄폐를 쓰고 돌격형은 붙는다) · 은신 동조(플레이어가 웅크리면 먼저 치지 않는다, 백구는 3t 안 숨은 적을 노려본다) · 대기(6t 안 적만) ·
## 호위 대상(싸우지 않고 엄폐로) · 지점 방어(반경 5t).
## 수치: HP = 기본 × (1 + 0.06 × (레벨 − 1)) · 기본 무기 탄약 무한 · 열화 없음 · 전투마다 스팀팩 1회(HP 35% 이하) · 동시 2명.
## 기절(기본): HP 0이면 쓰러져 표적에서 빠지고, 전투가 끝나면 HP 30%로 일어난다. 전투 중엔 다가가 상호작용 2초 + 스팀팩 1개로 일으킨다.
## 전투가 끝나면 서 있는 동행은 HP 전량. 동행이 쓰러뜨린 적의 XP는 플레이어가 그 적 HP의 30% 이상을 깎았을 때만(InteriorCombat).
class_name Companions
extends RefCounted

const MAX := 2
const FOLLOW_NEAR := 2.0 * 32.0
const FOLLOW_FAR := 4.0 * 32.0
const LOST := 15.0 * 32.0
const WAIT_R := 6.0 * 32.0
const GUARD_R := 5.0 * 32.0
const STIM_AT := 0.35
const REVIVE_S := 2.0
const REVIVE_R := 1.5 * 32.0
const CALM_S := 2.0                                ## 교전이 끝나고 이만큼 조용하면 '전투 종료'(회복 · 일어남)

## 인물 → 동행 자료(퀘스트 데이터 고정, SD-11 §8.2 '장비는 퀘스트 데이터'): 무기 · 성향 · 기본 HP · 소속(호감도 약호) · 대사
const ROSTER := {
	"C-002": {"weapon": "W-067", "style": "melee", "hp": 80.0, "skill": 25.0, "fac": "S7",                 # 하도윤(프롤로그 대걸레 자루)
		"hello": "왜? 나 여기 있어.", "wait": "알았어. 여기 있을게. 빨리 와.", "follow": "가자. 뒤는 내가 볼게."},
	"C-018": {"weapon": "W-049", "style": "rush", "hp": 120.0, "skill": 45.0, "fac": "JH",                 # 박춘삼(계약 경호 구울, 소방 도끼)
		"hello": "계약서엔 '같이 다닌다'고 돼 있소. 무슨 일이오.", "wait": "여기 서 있지. 계약은 계약이니까.", "follow": "앞장서시오. 등은 내가 맡지."},
	"C-015": {"weapon": "", "style": "dog", "hp": 80.0, "bite": 15.0, "skill": 40.0, "fac": "JC_BC", "sheet": "cr_baekgu_loco",   # 백구(진돗개 — 물기 15, SD-14 CR-108)
		"hello": "(백구가 꼬리를 한 번 친다.)", "wait": "(백구가 그 자리에 앉는다.)", "follow": "(백구가 일어나 앞장선다.)"},
}
const DEFAULT := {"weapon": "W-002", "style": "shooter", "hp": 80.0, "skill": 40.0, "fac": "",
	"hello": "응?", "wait": "여기서 기다릴게.", "follow": "따라갈게."}

var c                                              ## InteriorCombat
var list: Array = []                               ## 지금 맵의 동행: {id, name, actor, cmb, w, style, mode, home, cool, stim, down, ...}
var away := {}                                     ## 다른 맵에 기다리게 둔 동행: id -> {map, pos, hp, mode}
var fight := false                                 ## 지금 교전 중
var _calm := 0.0
var rev_prog := -1.0                               ## 일으키는 중 진행(0~2초, -1 = 아님)
var glare: Enemy                                   ## 백구가 노려보는 숨은 적(위치 표시)
var stats := {"downs": 0, "revives": 0, "stims": 0, "hits": 0}
var push := Vector2.ZERO                           ## 주인공이 가려는 쪽(호스트가 매 프레임 넣는다) — 길목에 선 동행이 비킨다


func _init(combat) -> void:
	c = combat


static func row(id: String) -> Dictionary:
	return ROSTER.get(id, DEFAULT)


## 동행을 붙인다(이미 있으면 그대로). 3명째는 받지 않는다(퀘스트 설계 상한 2)
func add(id: String, actor: Actor, nm: String = "", mode := "follow") -> Dictionary:
	for m in list:
		if m["id"] == id:
			m["actor"] = actor
			m["cmb"].actor = actor
			return m
	if list.size() >= MAX or actor == null:
		return {}
	var r := row(id)
	var cmb := Combatant.new()
	cmb.team = "ally"
	cmb.actor = actor
	cmb.radius = actor.radius_px
	var lv := 1
	if c._st_ref != null:
		lv = Loot.level_of(int(c._st_ref.vars.get_v("PC_XP")))
	cmb.max_hp = roundf(float(r["hp"]) * (1.0 + 0.06 * (lv - 1)))
	cmb.hp = cmb.max_hp
	cmb.hp_floor = 1.0                                                 # 기절(기본): 0 대신 1에서 멈추고 '쓰러짐'으로 바꾼다
	var w: Dictionary = c.weapons.get(str(r["weapon"]), {}).duplicate() if str(r["weapon"]) != "" else {}
	var m := {"id": id, "name": nm if nm != "" else id, "actor": actor, "cmb": cmb, "w": w, "style": str(r["style"]),
		"skill": float(r.get("skill", 40.0)), "bite": float(r.get("bite", 10.0)), "mode": mode, "home": actor.loco.logical,
		"cool": 0.5, "stim": false, "down": false, "stim_t": 0.0, "cover": Vector2.INF, "cover_t": 0.0}
	cmb.hit.connect(func() -> void: _on_hit(m))
	actor.set_meta("mate", true)                                       # 연출 실행기가 세우지 않는다(동행은 이 모듈이 걷게 한다)
	list.append(m)
	c._rebuild_list()
	return m


func remove(id: String) -> void:
	for m in list.duplicate():
		if m["id"] == id:
			if is_instance_valid(m["actor"]):
				(m["actor"] as Actor).remove_meta("mate")
			list.erase(m)
	away.erase(id)
	c._rebuild_list()


func clear() -> void:
	for m in list:
		if is_instance_valid(m["actor"]):
			(m["actor"] as Actor).remove_meta("mate")
	list.clear()
	glare = null
	rev_prog = -1.0
	c._rebuild_list()


func first_actor() -> Actor:
	for m in list:
		if is_instance_valid(m["actor"]):
			return m["actor"]
	return null


func get_mate(id: String) -> Dictionary:
	for m in list:
		if m["id"] == id:
			return m
	return {}


## 쓰러지지 않은 동행의 전투 몸(표적 · 탄 판정 목록)
func bodies() -> Array:
	var out: Array = []
	for m in list:
		if not m["down"] and is_instance_valid(m["actor"]):
			out.append(m["cmb"])
	return out


func set_mode(id: String, mode: String) -> void:
	var m := get_mate(id)
	if m.is_empty():
		return
	m["mode"] = mode
	m["home"] = (m["actor"] as Actor).loco.logical


func _on_hit(m: Dictionary) -> void:
	var cmb: Combatant = m["cmb"]
	if m["down"] or cmb.hp > cmb.hp_floor + 0.001:
		return
	m["down"] = true                                                   # 기절: 표적 목록에서 빠지고 눕는다
	stats["downs"] += 1
	var a: Actor = m["actor"]
	a.set_pose("lie")
	c._pop("쓰러짐", a.loco.logical + Vector2(0, -26), Color("E04A35"))
	if glare != null and m["style"] == "dog":
		glare = null
	c._rebuild_list()


func _stand(m: Dictionary, frac: float) -> void:
	m["down"] = false
	var cmb: Combatant = m["cmb"]
	cmb.hp = maxf(cmb.hp, roundf(cmb.max_hp * frac))
	(m["actor"] as Actor).set_pose("stand")
	c._rebuild_list()


## 일으키기 대상: 플레이어 1.5t 안의 쓰러진 동행
func revive_target(p: Vector2) -> Dictionary:
	for m in list:
		if m["down"] and is_instance_valid(m["actor"]) and (m["actor"] as Actor).loco.logical.distance_to(p) <= REVIVE_R:
			return m
	return {}


## 상호작용을 누르는 동안(2초): 스팀팩 1개로 HP 30%. 반환 "busy" · "done" · "no_stim" · "none"
func revive_tick(p: Vector2, dt: float, st: StoryState) -> String:
	var m := revive_target(p)
	if m.is_empty():
		rev_prog = -1.0
		return "none"
	if st != null and int(st.items.get(InteriorCombat.STIMPAK, 0)) <= 0:
		rev_prog = -1.0
		return "no_stim"
	rev_prog = maxf(0.0, rev_prog) + dt
	if rev_prog < REVIVE_S:
		return "busy"
	rev_prog = -1.0
	if st != null:
		st.call_fn("take", [InteriorCombat.STIMPAK, 1])
	_stand(m, 0.3)
	stats["revives"] += 1
	c._pop("일어남", (m["actor"] as Actor).loco.logical + Vector2(0, -26), Color("7CF08E"))
	return "done"


# ---------------------------------------------------------------- 매 틱
func tick(dt: float) -> void:
	if list.is_empty():
		return
	var now := bool(c.in_combat())
	if now:
		fight = true
		_calm = 0.0
	elif fight:
		_calm += dt
		if _calm >= CALM_S:                                           # 전투 끝: 서 있는 동행 HP 전량 · 쓰러진 동행 HP 30%로 일어남 · 스팀팩 다시
			fight = false
			for m in list:
				if m["down"]:
					_stand(m, 0.3)
				else:
					(m["cmb"] as Combatant).hp = (m["cmb"] as Combatant).max_hp
				m["stim"] = false
	var pc: Combatant = c.pc
	var player: Actor = pc.actor
	glare = null
	for i in list.size():
		var m: Dictionary = list[i]
		var a: Actor = m["actor"]
		if not is_instance_valid(a):
			continue
		m["cool"] = maxf(0.0, float(m["cool"]) - dt)
		if m["down"]:
			a.move(Vector2.ZERO, dt)
			continue
		if float(m["stim_t"]) > 0.0:                                   # 스팀팩 쓰는 0.5초: 선다
			m["stim_t"] = float(m["stim_t"]) - dt
			a.move(Vector2.ZERO, dt)
			continue
		var cmb: Combatant = m["cmb"]
		if fight and not m["stim"] and cmb.hp <= cmb.max_hp * STIM_AT:   # 자기 회복: 전투마다 한 번
			m["stim"] = true
			m["stim_t"] = 0.5
			cmb.hp = minf(cmb.max_hp, cmb.hp + cmb.max_hp * 0.35)
			stats["stims"] += 1
			c._pop("스팀팩", a.loco.logical + Vector2(0, -26), Color("7CF08E"))
			continue
		if not fight and _yield(m, player, dt):                      # 주인공 길목이면 먼저 비킨다(서로 막아 멈추지 않게)
			continue
		var tgt := _target(m)
		match str(m["mode"]):
			"wait":                                                     # 대기: 6t 안 적만 — 먼저 시비 걸지 않는다(교전 중이거나 우릴 본 적만)
				if tgt != null and (fight or not _unseen(tgt)) and tgt.loco.logical.distance_to(a.loco.logical) <= WAIT_R:
					_engage(m, tgt, dt, false)
				else:
					_go(m, m["home"], dt, 8.0)
			"guard":
				if tgt != null and (fight or not _unseen(tgt)) and tgt.loco.logical.distance_to(m["home"]) <= GUARD_R + 64.0:
					_engage(m, tgt, dt, true)
				else:
					_go(m, m["home"], dt, 16.0)
			"escort":
				if fight:
					_hide(m, dt)
				else:
					_follow(m, i, player, dt)
			_:
				if tgt != null and fight and not (c.crouch and _unseen(tgt)):
					_engage(m, tgt, dt, true)
				else:
					_follow(m, i, player, dt)
					if c.crouch and not fight and m["style"] == "dog":
						_glare(m)


## 비켜서기: 주인공이 가려는 쪽 1.75t 안 · 옆 0.8t 안에 서 있으면 옆 칸으로 비킨다. 좁은 길에서 0.6초 넘게 서로 막히면
## 자리를 바꾼다(쯔꾸르 대열처럼 주인공 뒤 칸으로) — 미끄러지거나 벽을 비비지 않고, 막힌 채 둘 다 서 있지도 않는다
func _yield(m: Dictionary, player: Actor, dt: float) -> bool:
	if player == null or push.length() < 0.2:
		m["yield_t"] = 0.0
		return false
	var a: Actor = m["actor"]
	var fwd := push.normalized()
	var rel := a.loco.logical - player.loco.logical
	var ahead := rel.dot(fwd)
	var lat := rel - fwd * ahead
	if ahead <= 0.0 or ahead > 56.0 or lat.length() > 26.0:
		m["yield_t"] = 0.0
		return false
	m["yield_t"] = float(m.get("yield_t", 0.0)) + dt
	var w = c.shots.world
	if float(m["yield_t"]) > 0.6:
		var behind := player.loco.logical - fwd * 32.0
		if not w.is_solid(Vector2i(floori(behind.x / 32.0), floori(behind.y / 32.0))):
			a.loco.place(behind)
			a.loco.facing = player.loco.facing
			a._show()
			m["yield_t"] = 0.0
			return true
	var side := fwd.orthogonal()
	if lat.dot(side) < 0.0:
		side = -side
	for sv in [side, -side]:
		var to: Vector2 = a.loco.logical + sv * 32.0
		if not w.is_solid(Vector2i(floori(to.x / 32.0), floori(to.y / 32.0))):
			a.mode = "run"
			a.move(a.steer(sv), dt)
			return true
	a.move(Vector2.ZERO, dt)
	return true


## 표적 순서(§8.2 엄호): 플레이어가 공격한 적 → 플레이어를 공격 중인 적 → 가장 가까운 적(보이는 적만, 15t 안)
func _target(m: Dictionary) -> Enemy:
	var a: Actor = m["actor"]
	var pt = c.pc_target
	if pt != null and is_instance_valid(pt) and not pt.cmb.dead and pt.loco.logical.distance_to(a.loco.logical) <= LOST:
		return pt
	var best: Enemy = null
	var bd := LOST
	for e in c.enemies:
		if not is_instance_valid(e) or e.cmb.dead or not e.cmb.team.begins_with("enemy") or not "ally" in e.foes:
			continue
		var d: float = e.loco.logical.distance_to(a.loco.logical)
		if e.focus == c.pc and e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY]:
			d *= 0.5                                                    # 플레이어를 노리는 적이 먼저
		if d < bd and c.shots.world.line_of_sight(a.loco.logical, e.loco.logical):
			bd = d
			best = e
	return best


## 아직 교전 전인 적(은신 동조: 먼저 치지 않는다)
func _unseen(e: Enemy) -> bool:
	return not e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.FRENZY]


func _follow(m: Dictionary, i: int, player: Actor, dt: float) -> void:
	var a: Actor = m["actor"]
	if player == null:
		return
	var back: Vector2 = -Locomotion.VEC[player.loco.facing].normalized()
	var side := back.orthogonal() * (20.0 if i == 0 else -20.0)        # 둘이면 좌우로 비켜 선다
	var goal := player.loco.logical + back * 64.0 + side
	var dv := goal - a.loco.logical
	var to_p := player.loco.logical - a.loco.logical
	if dv.length() > 1.0 and to_p.length() < dv.length():               # 주인공 앞에 섰다가 뒤로 가는 길: 주인공을 뚫지 않고 옆으로 돌아간다
		var u := dv.normalized()
		var k := clampf(to_p.dot(u), 0.0, dv.length())
		if (a.loco.logical + u * k).distance_to(player.loco.logical) < 26.0:
			var sv := u.orthogonal()
			if sv.dot(to_p) > 0.0:
				sv = -sv
			goal = a.loco.logical + sv * 32.0 + u * 8.0
	var d := a.loco.logical.distance_to(player.loco.logical)
	if d > LOST and not c.shots.world.line_of_sight(player.loco.logical, a.loco.logical):
		var t := Vector2i(floori(goal.x / 32.0), floori(goal.y / 32.0))
		a.loco.place(goal if not c.shots.world.is_solid(t) else player.loco.logical + back * 32.0)   # 너무 떨어지면 뒤 3t로(§8.2)
		return
	if d > FOLLOW_FAR or (d > FOLLOW_NEAR and a.loco.motion != "idle" and a.loco.logical.distance_to(goal) > 16.0):
		a.mode = "run" if d > FOLLOW_FAR * 1.5 else ("walk" if c.crouch else "run")
		a.move(a.steer(goal - a.loco.logical), dt)
	else:
		a.move(Vector2.ZERO, dt)
		if a.loco.motion == "idle" and a.aim_dir < 0:
			a.loco.facing = player.loco.facing


func _go(m: Dictionary, to: Vector2, dt: float, near: float) -> void:
	var a: Actor = m["actor"]
	if a.loco.logical.distance_to(to) > near:
		a.mode = "run"
		a.move(a.steer(to - a.loco.logical), dt)
	else:
		a.move(Vector2.ZERO, dt)


## 엄호: 근접 · 돌격 · 개는 붙어서 치고, 사수는 엄폐 자리로 가서 쏜다
func _engage(m: Dictionary, e: Enemy, dt: float, may_move: bool) -> void:
	var a: Actor = m["actor"]
	var to: Vector2 = e.loco.logical - a.loco.logical
	var style := str(m["style"])
	if style == "shooter":
		var w: Dictionary = m["w"]
		var reach := float(w.get("range_eff", 8.0)) * 32.0
		if may_move:
			m["cover_t"] = float(m["cover_t"]) - dt
			if float(m["cover_t"]) <= 0.0:
				m["cover_t"] = 0.6
				m["cover"] = _cover_spot(a.loco.logical, e.loco.logical)
			var cv: Vector2 = m["cover"]
			if cv != Vector2.INF and a.loco.logical.distance_to(cv) > 6.0:
				a.mode = "run"
				a.move(a.steer(cv - a.loco.logical), dt)
				return
			if to.length() > reach:
				a.mode = "run"
				a.move(a.steer(to), dt)
				return
		a.move(Vector2.ZERO, dt)
		a.aim_dir = Locomotion.snap8(to, 0.0)
		a.loco.facing = a.aim_dir
		a._show()
		if float(m["cool"]) <= 0.0 and to.length() <= reach * 1.2 and c.shots.world.line_of_sight(a.loco.logical, e.loco.logical):
			m["cool"] = 1.0 / maxf(0.3, float(w.get("rate", 2.0))) * 1.4
			var sp := CombatRules.spread(float(m["skill"]), "crouch" if m["cover"] != Vector2.INF else "stand", false)
			var muzzle := a.loco.logical + Vector2(0, -14) + to.normalized() * 10.0
			var ang := CombatRules.shot_angle(rad_to_deg(to.angle()), sp, c.shots.rng)
			if c.shots.fire_weapon(muzzle, ang, "ally", w, float(m["skill"]), {"flash": "auto", "fl": a.floor_id, "target": e.loco.logical}) > 0:
				for o in c.enemies:
					if is_instance_valid(o):
						o.hear(str(w.get("sound", "pistol")), a.loco.logical)
		return
	a.aim_dir = -1
	var reach2 := (float(m["w"].get("range_eff", 1.0)) * 32.0 if style != "dog" else 0.0) + e.cmb.radius + a.radius_px + 4.0
	if to.length() > reach2:
		if may_move:
			a.mode = "run"
			a.move(a.steer(to), dt)
		else:
			a.move(Vector2.ZERO, dt)
		return
	a.move(Vector2.ZERO, dt)
	a.loco.facing = Locomotion.snap8(to, 0.0)
	a._show()
	if float(m["cool"]) > 0.0 or not e.meets(m["cmb"]):
		return
	e.cmb.last_by = "mate"
	if style == "dog":                                                 # 백구: 물기
		m["cool"] = 1.1
		e.cmb.take({"hp": float(m["bite"]), "part": CombatRules.pick_part(e.cmb.weights, c._rng)}, a.loco.logical)
	else:
		var w2: Dictionary = m["w"]
		m["cool"] = 1.0 / maxf(0.3, float(w2.get("rate", 1.0)))
		var r := CombatRules.resolve({"weapon": w2, "skill": float(m["skill"]), "attacker": {"str": 6},
			"part": CombatRules.pick_part(e.cmb.weights, c._rng), "dr": e.cmb.dr})
		e.cmb.take(r, a.loco.logical)
		c._swing_fx(a.loco.logical + Vector2(0, -10) + to.normalized() * 18.0)
	stats["hits"] += 1
	if not e.cmb.dead and e.brain.state != AIBrain.S.COMBAT:
		e.hear("melee", a.loco.logical)


## 호위 대상: 교전이 시작되면 가장 가까운 엄폐 뒤로(적 반대쪽)
func _hide(m: Dictionary, dt: float) -> void:
	var a: Actor = m["actor"]
	var near: Enemy = null
	var nd := INF
	for e in c.enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.cmb.team.begins_with("enemy"):
			var d: float = e.loco.logical.distance_to(a.loco.logical)
			if d < nd:
				nd = d
				near = e
	if near == null:
		a.move(Vector2.ZERO, dt)
		return
	m["cover_t"] = float(m["cover_t"]) - dt
	if float(m["cover_t"]) <= 0.0:
		m["cover_t"] = 0.6
		m["cover"] = _cover_spot(a.loco.logical, near.loco.logical)
	var cv: Vector2 = m["cover"]
	if cv == Vector2.INF:
		cv = a.loco.logical + (a.loco.logical - near.loco.logical).normalized() * 64.0
	_go(m, cv, dt, 6.0)


## 엄폐 자리: 4t 안의 빈 칸 중, 옆 칸에 엄폐(가구 · 낮은 벽)가 있고 그 엄폐가 적 쪽을 막는 가장 가까운 칸
func _cover_spot(from: Vector2, enemy_at: Vector2) -> Vector2:
	var w = c.shots.world
	if w == null or not w.has_method("cover_at"):
		return Vector2.INF
	var t0 := Vector2i(floori(from.x / 32.0), floori(from.y / 32.0))
	var best := Vector2.INF
	var bd := INF
	for dy in range(-4, 5):
		for dx in range(-4, 5):
			var t := t0 + Vector2i(dx, dy)
			if w.is_solid(t) or w.cover_at(t) != 0:
				continue
			var p := Vector2(t.x * 32 + 16, t.y * 32 + 16)
			var to_e := (enemy_at - p).normalized()
			for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if w.cover_at(t + n) > 0 and Vector2(n).dot(to_e) > 0.5:
					var d := from.distance_to(p)
					if d < bd:
						bd = d
						best = p
					break
	return best


## 백구(은신 동조): 3t 안의 아직 모르는 적을 짖지 않고 노려본다 — 그 자리를 플레이어에게 보여 준다(InteriorCombat이 표식을 그린다)
func _glare(m: Dictionary) -> void:
	var a: Actor = m["actor"]
	for e in c.enemies:
		if not is_instance_valid(e) or e.cmb.dead or not _unseen(e):
			continue
		if e.loco.logical.distance_to(a.loco.logical) <= 3.0 * 32.0 + 16.0:
			glare = e
			a.loco.facing = Locomotion.snap8(e.loco.logical - a.loco.logical, 0.0)
			a._show()
			return


# ---------------------------------------------------------------- 맵 넘김 · 저장
## 맵을 떠날 때: 따라오는 동행 목록(다음 맵에 다시 세운다)을 돌려주고, 기다리는 동행은 그 맵에 남긴다(away)
func leaving(map_id: String) -> Array:
	var go: Array = []
	for m in list:
		var cmb: Combatant = m["cmb"]
		if m["mode"] in ["wait", "guard"]:
			away[m["id"]] = {"map": map_id, "pos": [m["home"].x, m["home"].y], "hp": cmb.hp, "mode": m["mode"], "name": m["name"]}
		else:
			go.append({"id": m["id"], "hp": cmb.hp if not m["down"] else cmb.max_hp * 0.3, "name": m["name"]})
	list.clear()
	return go


func snapshot() -> Dictionary:
	var here: Array = []
	for m in list:
		here.append({"id": m["id"], "name": m["name"], "mode": m["mode"], "hp": (m["cmb"] as Combatant).hp, "home": [m["home"].x, m["home"].y]})
	return {"here": here, "away": away.duplicate(true)}
