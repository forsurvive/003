## 실내 실시간 전투 (단계 0-7, MQ-P2 사격장·해충 구제): 실내 진행기(InteriorHost)에 붙어 주인공의 무기·조준·사격·재장전·웅크리기(은신)·
## 근접·스팀팩·단축키, 맵의 표적(사격장)과 적(큰바퀴), 일시 동행(하도윤)을 돌린다. 판정은 단계 T의 모듈을 그대로 쓴다:
##   CombatRules(퍼짐·피해·기습 배수) · Projectiles(투사체 40t/초, 엄폐) · Enemy/AIBrain/Perception(적 인지·행동).
## 수치 출처: 무기 SD-13(data/weapons.json), 주인공 HP·AP SD-10 §2.3(data/special.json), 재장전·스팀팩·은신 SD-11 §3.5·§2.7·§9.1.
## 표적(정합 — 문서에 없음, STAGE_0.md 0-7): 소품 target = 한 발에 넘어가는 일반 표적, target_low = 은신 표적(관찰자).
##   은신 표적은 사대(서쪽)를 보고 탐지 게이지(SD-11 §7.3 식, 인지력 5)를 채운다. 낮은 엄폐 뒤에 웅크린 사람은 보지 못한다(§4.2).
##   들키지 않은 채 맞히면 은신 기습(치명 확정 + 원거리 ×2)으로 넘어가고, 들키면 받침 뒤로 숨었다가 3초 뒤 다시 선다.
## 적: 맵 원고의 enemy 줄(cond가 참일 때). 쓰러뜨리면 enemy_killed, 큰바퀴는 바퀴 고기(I-036)를 떨어뜨린다(SD-14 §3.1, 100%).
## 주인공 HP 0 → player_down(프롤로그 특례는 진행 장면이 정한다).
class_name InteriorCombat
extends Node2D

signal target_down(kind: String, sneak: bool, left: int)
signal enemy_killed(id: String, left: int)
signal player_down
signal message(text: String)
signal hurt(amount: float)

const STIMPAK := "I-001"
const SHOT_SPEED := 40.0 * 32.0                   ## 실탄 40t/초(SD-11 §3.3)
const STIM_QUEUE_S := 2.0                         ## 회복 대기열: 한 개를 2.0초에 고르게(SD-11 §2.7)
const STIM_INJECT_S := 0.4                        ## 단축키 사용 투여 모션: 이동 50%·사격 불가
const STEALTH_PER := 5.0                          ## 은신 표적의 인지력(정합)
const STEALTH_RESET_S := 3.0
const DOLL := {"W-065": "bb", "W-067": "pole"}    ## 무기 → 페이퍼돌 손 무기(SD-13 §3.11 형상 차분). 그 밖은 계열로(Arms.doll, 1-9a)

var shots: Projectiles
var pc := Combatant.new()
var weapons := {}                                 ## data/weapons.json
var enemy_rows := {}                              ## data/enemies.json
var weapon_id := ""                               ## 고른 무기("" = 맨손)
var holstered := false                            ## F: 무기 넣기(SD-11 §2.3)
var mags := {}                                    ## 무기 ID -> 탄창에 든 탄 수
var hotkeys := {}                                 ## 1~8 -> 아이템 ID(무기·구호품, SD-12 §3.2)
var reload_t := 0.0
var cool := 0.0
var crouch := false
var since_shot := 999.0                            ## 주인공이 마지막으로 쏜 뒤 지난 초(1-E 인카운터 확률 '30초 안 총성 ×1.4')
var inject_t := 0.0
var heal_q: Array = []                            ## 회복 대기열: 남은 회복량(앞에서부터 2.0초씩)
var heal_rate := 0.0
var enemies: Array = []
var _token_t := 0.0                                ## 공격 토큰 다시 나누기까지 남은 초
var targets: Array = []                           ## [{"prop", "kind": "target"|"stealth", "cmb", "gauge", "seen_t", "down", "facing", "live"}]
var stealth_live := false                         ## 은신 표적을 쓰는 중(사격장 2부) — 아니면 받침 뒤에 숨어 있다
var buddy: Actor                                  ## 일시 동행(MQ-P2 하도윤): 따라오고, 가까운 바퀴를 대걸레 자루로 친다. 불사
var buddy_weapon := "W-067"
var armor_dr := Callable()                         ## 주인공 DR(입은 옷 × 상태, 1-8a) — 호스트가 준다
var nav: InteriorNav
var bot := {}                                     ## 봇 입력: {"aim", "fire", "crouch", "reload", "stim"}
var popups: Array = []                            ## [글, 위치, 남은 초, 색]
var stats := {"shots": 0, "hits": 0, "sneak": 0, "spotted": 0, "stims": 0, "downs": 0, "hurt": 0.0}
var font: Font
var sneak_skill := 0.0
var aim_hold := 0.0                               ## 쏜 뒤 조준 자세를 유지하는 남은 초
var aim_mode := "key"                             ## 조준 장치: mouse(커서 360°) · key(고전 조작: 바라보는 방향 + 자동 조준 원뿔)
const AIM_HOLD_S := 1.0
var _aim_real := false                            ## 조준점이 실제 점(봇·마우스·자동 조준이 잡은 표적)인가 — 아니면 바라보는 방향 그대로 쏜다
var _auto_hit := false
const AUTO_AIM_HALF := 15.0                       ## 고전 조작 자동 조준 반각(SD-11 §2.3 '원뿔 30°', 조준 보정 반각 15°)
var _buddy_cool := 0.0
var _rng := RandomNumberGenerator.new()
## 1-9a 무기 계열
var ap := APPool.new(5)                            ## 행동력(SD-11 §5): 파워 공격·(구르기·질주는 호스트)
var _spin := 0.0                                  ## 회전 기관포 예열(누르고 있는 초)
var _recoil := 0.0                                ## 돌격소총 반동 누적(°, 최대 +4)
var _recoil_t := 0.0
var _charge := -1.0                               ## 근접 누르는 중(초) — 0.5초면 파워 공격. -1 = 누르지 않음
var power_hits := 0                               ## 시험용: 파워 공격 횟수


func _init() -> void:
	z_index = 6
	_rng.seed = 2268
	font = load("res://assets/fonts/Galmuri9.ttf")
	weapons = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
	if FileAccess.file_exists("res://data/weapons_craft.json"):                # 제작 무기 W-153~157(1-8c, SD-13 §3.10)
		weapons.merge(JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons_craft.json")))
	Gear.expand_weapons(weapons)                                       # 상태 변형 "W-002@2"(1-8a): 같은 수치 + condition
	enemy_rows = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies.json"))
	shots = Projectiles.new()
	add_child(shots)
	pc.team = "player"
	pc.died.connect(func() -> void:                                    # Combatant.take가 HP 0에서 dead를 세우고 died를 낸다
		heal_q.clear()
		player_down.emit())


## 주인공 최대 HP·AP(SD-10 §2.3): 레벨 1 = special.json의 hp_lv1(지구력), ap_max(민첩성)
static var _special := {}


static func derived(st: StoryState) -> Dictionary:
	if _special.is_empty():
		_special = JSON.parse_string(FileAccess.get_file_as_string("res://data/special.json"))
	var sp: Dictionary = _special
	var en := str(clampi(st.stat("EN"), 1, 10))
	var ag := str(clampi(st.stat("AG"), 1, 10))
	return {"hp_max": float(sp[en]["hp_lv1"]), "ap_max": float(sp[ag]["ap_max"])}


## 맵이 바뀌었다: 표적·적을 새 맵에서 다시 만든다(주인공 HP는 그대로)
func on_map(map: InteriorMap, player: Actor, st: StoryState) -> void:
	for e in enemies:
		if is_instance_valid(e):
			e.queue_free()
	enemies.clear()
	residents.clear()
	allies.clear()
	targets.clear()
	shots.shots.clear()
	shots.world = map
	nav = InteriorNav.new(map)
	pc.actor = player
	pc.radius = player.radius_px
	pc.dead = false
	buddy = null
	if st != null:
		var mx: float = derived(st)["hp_max"]
		if pc.max_hp != mx:
			pc.hp = mx if pc.max_hp <= 0.0 or pc.hp >= pc.max_hp else minf(pc.hp, mx)
			pc.max_hp = mx
	for p in map.props:
		if p["name"] in ["target", "target_low"]:
			var c := Combatant.new()
			c.team = "target"
			c.hp = 1.0
			c.max_hp = 1.0
			c.radius = 9.0
			c.weights = {"torso": 1}
			c.actor = _Pos.new(Vector2(int(p["x"]) * 32 + 16, int(p["y"]) * 32 + 16))
			var t := {"prop": p, "kind": "stealth" if p["name"] == "target_low" else "target", "cmb": c, "gauge": 0.0,
				"seen_t": 0.0, "down": false, "facing": Vector2.LEFT, "live": true}
			targets.append(t)
	set_stealth_live(stealth_live)
	for row in map.data.get("enemies", []):
		if InteriorMap._cond_ok(str(row.get("cond", "")), st):
			spawn(str(row["id"]), Vector2(int(row["x"]) * 32 + 16, int(row["y"]) * 32 + 16), map, st, row)
	_rebuild_list()
	if st != null:
		ap.max_ap = APPool.max_for(st.stat("AG"))
		ap.ap = minf(ap.ap, ap.max_ap)
	_doll()


## 은신 표적 켜기·끄기(사격장 1부에는 받침 뒤에 숨겨 둔다)
func set_stealth_live(on: bool) -> void:
	stealth_live = on
	for t in targets:
		if t["kind"] == "stealth" and not t["down"]:
			t["live"] = on
			t["gauge"] = 0.0
			t["seen_t"] = 0.0
			_prop_state(t, "" if on else "duck")


## 적 무기(정합, 0-9): 보안요원 진압봉 W-041 · 권총 W-002, 계엄군은 생포 사격(W-002 판정을 빌린다), 파워 아머는 그 세 배 연사
func _enemy_weapon(enemy_id: String, arm: String) -> Dictionary:
	if enemy_id == "CR-002" or enemy_id in Enemy.DOGS:
		return {}
	var w: Dictionary = weapons.get("W-041" if arm in ["baton", "claw"] else "W-002", {}).duplicate()
	if arm == "claw":                                                   # 야생 구울(1-4): 맨손 내려치기 — 피해는 SD-14 표 '근접 n'
		var row: Dictionary = enemy_rows.get(enemy_id, {})
		w["dmg"] = float(str(row.get("attack", "근접 5")).get_slice(" ", 1))
		w["crit_dmg"] = w["dmg"]
		w["name"] = "맨손"
		w["rate"] = 0.8                                             # 한 번 내려치고 숨 고르기(떼로 붙으면 초당 30 안팎 — 1.4면 3초 만에 쓰러졌다)
	if enemy_id == "CR-405":
		w["rate"] = float(w.get("rate", 2.0)) * 3.0
	if enemy_id in ["CR-436", "CR-534"]:                               # 기관단총(0-10 정합: 무기 표에 아직 없어 W-002 판정 + 연사 1.5배)
		w["rate"] = float(w.get("rate", 2.0)) * 1.5
	return w


signal enemy_down(e: Enemy)


func spawn(enemy_id: String, pos: Vector2, map: InteriorMap, st: StoryState = null, opts: Dictionary = {}) -> Enemy:
	var e := Enemy.new()
	var arm := str(opts.get("arm", "baton" if enemy_id == "CR-473" else ("claw" if enemy_id in ["CR-200", "CR-201"] else "")))
	e.setup_enemy(enemy_rows[enemy_id], _enemy_weapon(enemy_id, arm), pos, map, opts)
	e.set_meta("enemy_id", enemy_id)
	e.set_meta("row", opts)
	e.cmb.unaware = func() -> bool: return e.brain.state != AIBrain.S.COMBAT and e.brain.gauge < 100.0
	if enemy_id == "CR-405":                                            # '못 이기는 적'(SD-03a §7.4 연출 메모): HP 하한 1, 체력 표시 없음
		e.cmb.hp_floor = 1.0
		e.hide_bar = true
	map.objects.add_child(e)
	enemies.append(e)
	e.cmb.died.connect(func() -> void:
		var by_pc: bool = e.cmb.last_by in ["player", "ally", ""]          # 교전(1-E): 다른 무리가 쓰러뜨린 적은 경험치·카르마가 없다
		if by_pc:
			stats["downs"] += 1
		if st != null and by_pc:
			if not e.has_meta("xp_given"):
				e.set_meta("xp_given", true)
				st.call_fn("xp", [int(enemy_rows[enemy_id]["xp"])])
			if enemy_id == "CR-002":
				st.call_fn("give", ["I-036", 1])                         # 바퀴 고기 100%(SD-14 §3.1)
			if e.cmb.killed_lethal and enemy_id == "CR-473":             # 보안요원 사살: 카르마 -25(기절은 0, SD-03a §7.4)
				st.call_fn("karma", [-25])
				st.vars.set_v("MQP4_SEC_KO", int(st.vars.get_v("MQP4_SEC_KO")) + 1)
			elif e.cmb.killed_lethal and enemy_id == "CR-401":
				st.vars.set_v("MQP4_BJ_KO", int(st.vars.get_v("MQP4_BJ_KO")) + 1)
		if e.cmb.ko:
			e.ko_t = Enemy.KO_SECS
			_pop("기절", e.loco.logical + Vector2(0, -26), Color("8E9BA8"))
		if e.who == "N-R01-018" and st != null and int(st.vars.get_v("MQP4_KEY")) == 0:   # 무기고 담당 권서준: 무기고 열쇠(0-9 정합)
			st.vars.set_v("MQP4_KEY", 1)
			message.emit("권서준의 허리춤에서 무기고 열쇠를 빼앗았다.")
		if not e.cmb.ko:
			enemy_down.emit(e)                                          # 유해(1-4 파밍): 호스트가 그 자리에 소지품 용기를 둔다
		enemy_killed.emit(enemy_id, alive_enemies()))
	_rebuild_list()
	return e


## 주민(SD-10 §6.3, 0-9): 맵 인물도 맞는다. 공기총·근접은 기절(비살상), 실총으로 죽이면 진행기가 카르마 −100.
## 프롤로그 불사 4인(윤정인·하도윤·육지환·도경철)은 HP 1에서 멈춘다(무릎). 적의 탄은 주민을 맞히지 않는다.
signal resident_hit(id: String)
signal resident_down(id: String, killed: bool)
const IMMORTAL := ["C-001", "C-002", "C-004", "C-022", "C-003"]   # C-003 남궁혁(1-7 귀빈실 — 4막 MQ-402 전에는 쓰러지지 않는다)
const RESIDENT_HP := 40.0
var residents: Array = []                         ## [{"id", "cmb", "actor"}]


func set_residents(list: Array) -> void:
	residents.clear()
	for n in list:
		var a = n["actor"]
		if not is_instance_valid(a) or n.get("dead", false):
			continue
		var c := Combatant.new()
		c.team = "resident"
		c.actor = a
		c.hp = RESIDENT_HP
		c.max_hp = RESIDENT_HP
		c.can_ko = true
		var id := str(n["id"])
		if id in IMMORTAL:
			c.hp_floor = 1.0
		c.hit.connect(func() -> void: resident_hit.emit(id))
		c.died.connect(func() -> void: resident_down.emit(id, c.killed_lethal))
		residents.append({"id": id, "cmb": c, "actor": a})
	_rebuild_list()


## 아군(0-10 MQ-101 계단 방어): 계단참을 지키는 감시조. 제자리에서 보이는 가장 가까운 적을 쏜다. 주인공 탄은 지나가고, 적 탄은 맞는다.
signal ally_down(id: String)
var allies: Array = []                            ## [{"id", "actor", "cmb", "cool", "weapon"}]


func add_ally(id: String, actor: Actor, hp: float, weapon_id: String = "W-002") -> Combatant:
	var c := Combatant.new()
	c.team = "ally"
	c.actor = actor
	c.hp = hp
	c.max_hp = hp
	c.radius = actor.radius_px
	c.died.connect(func() -> void:
		actor.sprite.rotation_degrees = -90.0
		actor.sprite.position = Vector2(-4, -8)
		actor.sprite.modulate = Color(0.7, 0.7, 0.75)
		_pop("쓰러짐", actor.loco.logical + Vector2(0, -26), Color("E04A35"))
		ally_down.emit(id))
	allies.append({"id": id, "actor": actor, "cmb": c, "cool": 0.5 + _rng.randf(), "weapon": weapons.get(weapon_id, {})})
	_rebuild_list()
	return c


func clear_allies() -> void:
	allies.clear()
	_rebuild_list()


func _allies(dt: float) -> void:
	for a in allies:
		var c: Combatant = a["cmb"]
		if c.dead or not is_instance_valid(a["actor"]):
			continue
		var me: Actor = a["actor"]
		a["cool"] = float(a["cool"]) - dt
		var best: Enemy = null
		var bd := 11.0 * 32.0
		for e in enemies:
			if not is_instance_valid(e) or e.cmb.dead or not e.cmb.team.begins_with("enemy"):
				continue
			var d: float = e.loco.logical.distance_to(me.loco.logical)
			if d < bd and shots.world.line_of_sight(me.loco.logical, e.loco.logical) and e.meets(a["cmb"]):
				bd = d
				best = e
		if best == null:
			continue
		me.loco.facing = Locomotion.snap8(best.loco.logical - me.loco.logical, 0.0)
		me._show()
		if float(a["cool"]) <= 0.0 and not (a["weapon"] as Dictionary).is_empty():
			var w: Dictionary = a["weapon"]
			a["cool"] = 1.0 / (float(w.get("rate", 2.0)) * 0.25) * shots.rng.randf_range(0.8, 1.4)   # 감시조는 아껴 쏜다(초당 1발 안팎)
			var aim := rad_to_deg((best.loco.logical - me.loco.logical).angle())
			var ang := CombatRules.shot_angle(aim, CombatRules.spread(20.0, "stand", false), shots.rng)
			shots.fire(me.loco.logical + Vector2(0, -14) + Vector2.RIGHT.rotated(deg_to_rad(aim)) * 10.0, ang, SHOT_SPEED, "ally", w, 20.0, false, 5, "auto", me.floor_id)


## 적이 노릴 대상: 그 적이 노리는 편(foes — 주인공·아군 · 교전 중이면 다른 무리) 가운데 보이는 가장 가까운 쪽
## (지금 대상은 1.5배 가까운 쪽이 나타날 때까지 유지). 노릴 편이 아무도 없으면 '아무도 아님'(죽은 허수아비)을 준다
func _target_for(e: Enemy) -> Combatant:
	var plain: bool = e.foes.size() == 2 and "player" in e.foes and "ally" in e.foes
	if plain and allies.is_empty():
		return pc
	var cand: Array = []
	if "player" in e.foes:
		cand.append(pc)
	if "ally" in e.foes:
		for a in allies:
			if not (a["cmb"] as Combatant).dead:
				cand.append(a["cmb"])
	if not plain:
		for o in enemies:
			if is_instance_valid(o) and o != e and not o.cmb.dead and o.cmb.team in e.foes:
				cand.append(o.cmb)
	if cand.is_empty():
		return _nobody()
	var cur: Combatant = e.focus if e.focus != null and not e.focus.dead and e.focus in cand else null
	var best: Combatant = cur
	var bd := e.loco.logical.distance_to(cur.pos()) / 1.5 if cur != null else INF
	for c in cand:
		var d := e.loco.logical.distance_to((c as Combatant).pos())
		if d < bd and (c == pc or e.sight_of(c) > 0.0):
			bd = d
			best = c
	e.focus = best if best != null else cand[0]
	return e.focus


## 노릴 편이 없는 적에게 주는 허수아비(죽어 있어 보지도 쏘지도 않는다)
class _NoLoco:
	var logical := Vector2(-1.0e6, -1.0e6)


class _NoActor:
	var loco := _NoLoco.new()


var _none: Combatant


func _nobody() -> Combatant:
	if _none == null:
		_none = Combatant.new()
		_none.actor = _NoActor.new()
		_none.dead = true
		_none.team = "none"
	return _none


signal provoked(team: String)


## 비적대 무리를 주인공이 때렸다(1-E): 그 무리(같은 편) 모두 주인공을 노린다. 탄도 이제 주인공을 맞힌다
func _provoked() -> void:
	for e in enemies:
		if not is_instance_valid(e) or e.cmb.dead or "player" in e.foes or e.cmb.last_by != "player":
			continue
		var team: String = e.cmb.team
		var nt := "enemy" + team.trim_prefix("calm")
		for o in enemies:
			if is_instance_valid(o) and o.cmb.team == team:
				o.foes.append_array(["player", "ally"])
				o.cmb.team = nt
				o.wake()
		for o in enemies:                                                # 그 무리를 노리던 쪽은 바뀐 편 이름도 노린다
			if is_instance_valid(o) and team in o.foes and not nt in o.foes:
				o.foes.append(nt)
		provoked.emit(team)


func resident(id: String) -> Combatant:
	for r in residents:
		if r["id"] == id:
			return r["cmb"]
	return null


## 맵의 적을 지금 조건대로 다시 본다(연출 명령 refresh, 0-9): 조건이 거짓이 된 적은 치운다(하도윤의 미끼·엄마의 거짓 무전으로 분대가 빠진다)
func refresh_enemies(st: StoryState) -> void:
	for e in enemies.duplicate():
		if not is_instance_valid(e):
			continue
		var row: Dictionary = e.get_meta("row", {})
		if not InteriorMap._cond_ok(str(row.get("cond", "")), st):
			enemies.erase(e)
			e.queue_free()
	_rebuild_list()


## 적 하나를 전장에서 뺀다(물러남 · 기체에 오름 · 고기에 정신 팔림): 목록과 탄 판정 목록을 함께 고친다
func drop_enemy(e: Enemy) -> void:
	enemies.erase(e)
	if is_instance_valid(e):
		e.queue_free()
	_rebuild_list()


func alive_enemies() -> int:
	return enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead).size()


func targets_left(kind: String) -> int:
	return targets.filter(func(t): return t["kind"] == kind and not t["down"]).size()


func _rebuild_list() -> void:
	var l: Array = [pc]
	for e in enemies:
		if is_instance_valid(e):
			l.append(e.cmb)
	for r in residents:
		if is_instance_valid(r["actor"]):
			l.append(r["cmb"])
	for a in allies:
		if is_instance_valid(a["actor"]):
			l.append(a["cmb"])
	for t in targets:
		l.append(t["cmb"])
	shots.combatants = l


func armed() -> bool:
	return weapon_id != "" and weapons.has(weapon_id) and not holstered


func weapon() -> Dictionary:
	return weapons.get(weapon_id, {})


## 무기 고르기. 처음 드는 원거리 무기는 소지 탄약으로 탄창을 채운다
func equip(id: String, st: StoryState) -> void:
	if id != "" and Gear.cond(id) >= 4:                                 # 파손(SD-13 §8.1): 사용 불가 — 고치거나 부품으로 쓴다
		message.emit("부서져서 쓸 수 없다. 고쳐야 한다.")
		return
	weapon_id = id
	holstered = false
	reload_t = 0.0
	if id != "" and weapons.has(id) and weapons[id]["kind"] == "ranged" and not mags.has(id):
		mags[id] = _ammo_take(id, int(weapons[id]["mag"]), st)
	if st != null:
		st.weapon_out = armed()
	_doll()


func _doll() -> void:
	var a: Actor = pc.actor
	if a == null or a.doll == null:
		return
	var w := ""
	if armed():
		w = DOLL.get(Gear.base(weapon_id), Arms.doll(weapon()))
	a.doll.set_look({"weapon": w})


## 탄약(이름이 곧 ID, SD-13 §4.1)에서 n발을 꺼낸다
func _ammo_take(id: String, n: int, st: StoryState) -> int:
	var ammo_id := str(weapons[id].get("ammo_id", ""))
	if ammo_id == "" or st == null:
		return n
	var k := mini(int(st.items.get(ammo_id, 0)), n)
	if k > 0:
		st.call_fn("take", [ammo_id, k])
	return k


func ammo_left(st: StoryState) -> int:
	var ammo_id := str(weapon().get("ammo_id", ""))
	return int(st.items.get(ammo_id, 0)) if ammo_id != "" and st != null else 0


## 단축키 1~8(SD-12 §3.2): 무기면 들고, 구호품이면 쓴다
func hotkey(n: int, st: StoryState) -> void:
	var id: String = hotkeys.get(n, "")
	if id == "" or st == null or int(st.items.get(id, 0)) <= 0:
		return
	if weapons.has(id):
		equip("" if id == weapon_id and not holstered else id, st)
	elif id == STIMPAK:
		use_stimpak(st, true)


## 아이템을 처음 받으면 빈 단축키 칸에 넣는다(무기 1·2…, 스팀팩 3)
func auto_hotkey(id: String) -> void:
	if hotkeys.values().has(id):
		return
	var want := 3 if id == STIMPAK else 1
	for n in range(want, 9):
		if not hotkeys.has(n):
			hotkeys[n] = id
			return


# ---------------------------------------------------------------- 매 프레임(진행기가 부른다)
func tick(dt: float, free: bool, st: StoryState) -> void:
	var player: Actor = pc.actor
	if player == null:
		return
	nav.new_frame()
	if st != null:
		sneak_skill = float(st.skill("SNEAK"))
	pc.posture = "crouch" if crouch else "stand"                          # 적의 탐지식 입력(SD-11 §7.3, 0-9)
	pc.movement = "still" if player.loco.motion == "idle" else ("sneak" if crouch else "move")
	pc.sneak = sneak_skill
	if armor_dr.is_valid():
		pc.dr = float(armor_dr.call())
	cool = maxf(0.0, cool - dt)
	if pc.flash > 0:
		pc.flash -= 1
	if player.doll != null:
		player.doll.set_flash(1.0 if pc.flash > 0 else 0.0)
		if pc.flash == 2:
			player.doll.flash_face("hurt", 0.3)
	var hp0 := pc.hp
	var step := dt if free else 0.0
	_token_t -= step
	since_shot += step
	if _token_t <= 0.0:                                                 # 공격 토큰(SD-11 §7.4, 난이도 보통 원거리 3): 대상에 가까운 사수 셋만 쏜다(편마다 — 1-E 교전)
		_token_t = 1.5
		_provoked()
		var cands := enemies.filter(func(e): return is_instance_valid(e) and e.style == "shooter" and not e.cmb.dead)
		cands.sort_custom(func(a, b): return a.loco.logical.distance_to(_target_for(a).pos()) < b.loco.logical.distance_to(_target_for(b).pos()))
		var per_team := {}
		for i in cands.size():
			var tm: String = cands[i].cmb.team
			per_team[tm] = int(per_team.get(tm, 0)) + 1
			cands[i].has_token = int(per_team[tm]) <= 3
	for e in enemies:
		if is_instance_valid(e):
			var was: bool = e.cmb.flash > 0
			e.think(step, _target_for(e), nav, shots)
			if e.cmb.flash == 2 and not was and e.cmb.last_sneak:
				e.cmb.last_sneak = false
				_pop("기습 치명타 ×%d" % int(CombatRules.sneak_mult("ranged", false)), e.loco.logical + Vector2(0, -22), Color("E8C23A"))
	if free:
		ap.tick(dt, false)
		_status(dt)
		_heal(dt)
		_targets(dt, player)
		_buddy(dt)
		_allies(dt)
	shots.step(step)
	if pc.hp < hp0:
		stats["hurt"] += hp0 - pc.hp
		hurt.emit(hp0 - pc.hp)
	for p in popups:
		p[2] -= dt
		p[1] += Vector2(0, -12) * dt
	popups = popups.filter(func(p): return p[2] > 0.0)
	queue_redraw()
	if pc.dead:
		return
	if free:
		_player(dt, player, st)


## 1-9a 상태 이상 흐름: 지속 피해 틱 · 행동 제한 시간 · 넉백(발이 뜬 이동 — 막히면 거기서 선다, SD-16 §5.4 ⑦)
func _status(dt: float) -> void:
	var all: Array = [pc]
	for e in enemies:
		if is_instance_valid(e):
			all.append(e.cmb)
	for r in residents:
		all.append(r["cmb"])
	for c in all:
		c.tick_status(dt)
		if c.push == Vector2.ZERO or c.dead:
			c.push = Vector2.ZERO
			continue
		var a = c.actor
		var step: Vector2 = c.push.limit_length(240.0 * dt)
		c.push -= step
		if c.push.length() < 0.5:
			c.push = Vector2.ZERO
		if not (a is Actor) or a.world == null:
			continue
		var from: Vector2 = a.loco.logical
		var to: Vector2 = a.world.move_circle(from, from + step, a.radius_px)
		if to.distance_to(from + step) > 0.5:                      # 벽·엄폐에 닿으면 넉백은 거기서 끝(비비지 않는다)
			c.push = Vector2.ZERO
		a.loco.place(to.round() if to.distance_to(from) > 0.0 else from)
	_recoil_t += dt
	while _recoil_t >= 0.3 and _recoil > 0.0:                      # 쏘지 않으면 0.3초마다 1°씩 돌아온다
		_recoil_t -= 0.3
		_recoil = maxf(0.0, _recoil - 1.0)


## 사격 중 중화기는 정조준 이동 속도(3.0t/초)로 걷는다(SD-11 §3.4)
func heavy_slow() -> bool:
	return armed() and Arms.fam(weapon()) == "heavy" and aim_hold > 0.0


func _heal(dt: float) -> void:
	if heal_q.is_empty():
		return
	var amt := minf(heal_rate * dt, float(heal_q[0]))
	pc.hp = minf(pc.max_hp, pc.hp + amt)
	heal_q[0] = float(heal_q[0]) - amt
	if float(heal_q[0]) <= 0.001:
		heal_q.pop_front()
		if not heal_q.is_empty():
			heal_rate = float(heal_q[0]) / STIM_QUEUE_S


func _player(dt: float, player: Actor, st: StoryState) -> void:
	if inject_t > 0.0:
		inject_t -= dt
		return
	if pc.held():                                                     # 1-9a: 넘어짐·기절·마비·그물 동안 공격 못 한다
		_charge = -1.0
		return
	if bot.is_empty():
		if Input.is_action_just_pressed("crouch"):
			crouch = not crouch
		if Input.is_action_just_pressed("holster"):
			if weapon_id == "" or weapon_id == Arms.FIST:                 # 빈손이면 주먹을 쥐고 편다(SD-11 §3.4 비무장, 1-9a)
				equip("" if weapon_id == Arms.FIST else Arms.FIST, st)
			else:
				holstered = not holstered
				reload_t = 0.0
				if st != null:
					st.weapon_out = armed()
				_doll()
	else:
		crouch = bot.get("crouch", false)
		if bot.has("weapon") and str(bot["weapon"]) != weapon_id:
			equip(str(bot["weapon"]), st)
		if bot.get("stim", false):
			bot["stim"] = false
			use_stimpak(st, true)
			return
	if not armed():
		player.aim_dir = -1
		return
	var w := weapon()
	var aim := _aim_point(player)
	var to := aim - (player.loco.logical + Vector2(0, -14))
	var fire: bool = bot.get("fire", false) if not bot.is_empty() else Input.is_action_pressed("fire")
	if fire:
		aim_hold = AIM_HOLD_S
	aim_hold = maxf(0.0, aim_hold - dt)
	# 조준 자세(상·하체 분리, SD-16 §5.10): 정조준을 누르고 있거나 · 쏜 뒤 1초 · 교전 중일 때만. 그 밖에는 전신이 걷는 쪽을 본다
	# (조준하면서 90° 넘게 반대로 걸을 때만 뒷걸음 — SD-11 §2.4). 커서가 주인공 위에 겹쳐 있으면 조준하지 않는다.
	var hold_aim: bool = Input.is_action_pressed("aim") if bot.is_empty() else bot.has("aim")
	var aiming_pose: bool = (hold_aim or aim_hold > 0.0 or in_combat()) and to.length() > 12.0
	player.aim_dir = Locomotion.snap8(to, 0.0) if aiming_pose else -1
	if reload_t > 0.0:
		reload_t -= dt
		if reload_t <= 0.0:
			mags[weapon_id] = int(mags.get(weapon_id, 0)) + _ammo_take(weapon_id, int(w["mag"]) - int(mags.get(weapon_id, 0)), st)
		return
	var ranged: bool = w["kind"] == "ranged"
	if ranged and (bot.get("reload", false) if not bot.is_empty() else Input.is_action_just_pressed("reload")):
		start_reload(st)
		return
	if not ranged:
		_melee_input(dt, player, w, to, st, fire)
		return
	var spin := float(w.get("spinup", 0.0))
	if spin > 0.0:                                                     # 회전 기관포(SD-11 §3.4): 누르면 예열 뒤 연사, 예열 중에도 회전음
		if not fire:
			_spin = 0.0
		elif _spin < spin:
			_spin += dt
			for e in enemies:
				if is_instance_valid(e):
					e.hear("pistol", player.loco.logical)
			return
	if not fire or cool > 0.0:
		return
	cool = 1.0 / float(w["rate"])
	var need := Arms.per_shot(w)
	if int(mags.get(weapon_id, 0)) < need:
		start_reload(st)                                              # 탄창이 비면 자동 재장전(옵션 기본 켬)
		return
	var sk := float(st.skill(Arms.skill_name(w))) if st != null else 15.0
	var aiming: bool = Input.is_action_pressed("aim") if bot.is_empty() else bool(bot.get("aimed", true))
	var stance := Arms.aim_stance(w, aiming, crouch)
	var assault := str(w.get("layer", "")) in ["R04", "R05", "R06"]
	var sp := CombatRules.spread(sk, stance, player.loco.motion != "idle", str(w.get("condition", "new")), 1.0, 0.0, _recoil if assault else 0.0, float(w.get("min_spread", 1.0)))
	# 탄은 그려진 총의 총구에서 나가 조준점으로 간다(SD-16 §5 'muzzle'). 총 그림 방향 = 조준 중이면 조준 방향, 아니면 몸 방향.
	# 총구 화염은 인형이 총과 같은 층에 그린다(N·NE 조준이면 머리 뒤).
	var gdir: int = player.aim_dir if player.aim_dir >= 0 else player.loco.facing
	var muzzle := player.loco.logical + Vector2(0, -14) + to.normalized() * 10.0
	if player.doll != null:
		muzzle = player.position + player.doll.position + player.doll.muzzle_local(gdir)
	var line := aim - muzzle
	var ang := CombatRules.shot_angle(rad_to_deg((line if _aim_real and line.length() > 24.0 else to).angle()), sp, shots.rng)
	var n := shots.fire_weapon(muzzle, ang, "player", w, sk, {"flash": "" if player.doll != null else "auto", "fl": player.floor_id,
		"sneak_ok": true, "target": aim, "per": 5})
	if n <= 0:
		if Arms.proj(w) == "nuke":
			message.emit("너무 가깝다. 6걸음 밖을 겨눠야 한다.")
		return
	mags[weapon_id] = int(mags[weapon_id]) - need
	stats["shots"] += 1
	since_shot = 0.0
	if assault:
		_recoil = minf(4.0, _recoil + 0.5)
		_recoil_t = 0.0
	_wear_weapon(st, 1)
	if player.doll != null:
		player.doll.flash_face("fire", 0.14)
		var fs := CombatFx.flash_for(w)
		if fs != "":
			player.doll.fire_flash(gdir, ang, fs)
	for e in enemies:
		if is_instance_valid(e):
			e.hear(str(w.get("sound", "pistol")), player.loco.logical)


## 근접 입력(SD-11 §3.4·§5.3): 눌렀다 떼면 일반 공격, 0.5초 누르고 있으면 파워 공격(피해 ×2 · 0.6t 전진 · 넉백 · AP = 무기 AP ÷ 2, 최소 10).
## 회전날(리퍼)은 누르는 동안 0.1초마다 틱(틱당 피해 ÷ 10). 봇은 fire = 일반 공격(쿨마다), power = 파워 공격.
func _melee_input(dt: float, player: Actor, w: Dictionary, to: Vector2, st: StoryState, fire: bool) -> void:
	if w.get("saw", false):
		if fire and cool <= 0.0:
			cool = 0.1
			_melee(player, w, to, st, false, 0.1)
		return
	var cost := maxf(10.0, float(w.get("ap_cost", 0.0) if w.get("ap_cost") != null else 0.0) * 0.5)
	if not bot.is_empty():
		if cool > 0.0:
			return
		if bot.get("power", false) and ap.spend(cost):
			cool = 1.0 / float(w["rate"])
			_melee(player, w, to, st, true)
		elif fire:
			cool = 1.0 / float(w["rate"])
			_melee(player, w, to, st, false)
		return
	if _charge < 0.0:
		if fire and cool <= 0.0 and Input.is_action_just_pressed("fire"):
			_charge = 0.0
		return
	if fire:
		_charge += dt
		if _charge >= Arms.POWER_HOLD_S:
			_charge = -1.0
			cool = 1.0 / float(w["rate"])
			_melee(player, w, to, st, ap.spend(cost))                  # AP가 모자라면 일반 공격
		return
	_charge = -1.0
	cool = 1.0 / float(w["rate"])
	_melee(player, w, to, st, false)


## 근접(SD-11 §3.4): 한손 호 90°·최대 3명, 양손 호 140°·4명, 비무장 호 70°·2명(사거리는 무기 자료), 호 안 충돌체 중심이면 명중(굴림 없음).
## 파워 공격 = 피해 ×2 · 0.6t 전진 · 넉백(양손 1.0t + 경직, 한손·비무장 0.3t). 슈퍼 슬레지급 파워 공격은 인간형 25% 넘어뜨림(§4.9).
## 비무장은 머리에 맞으면 15%(맨주먹 30%) 1.5초 기절. 프롤로그(볼트 평시)의 근접은 비살상(사람은 기절, 0-9) — 1막부터는 실제 피해(1-9a 정합).
func _melee(player: Actor, w: Dictionary, to: Vector2, st: StoryState, power: bool = false, tick_mult: float = 1.0) -> void:
	var fam := Arms.fam(w)
	var reach := float(w["range_eff"]) * 32.0
	var arc := Arms.melee_arc(w)
	var cap := Arms.melee_max(w)
	var sk := float(st.skill(Arms.skill_name(w))) if st != null else 15.0
	var calm := st == null or st.quests.cur_act() < 1                   # 프롤로그: 근접 = 기절
	var dirv: Vector2 = to.normalized() if to.length() > 0.1 else (Locomotion.VEC[player.loco.facing] as Vector2).normalized()
	if power:                                                          # 0.6t 전진 — 앞의 상대 몸 앞에서 멈춘다(겹치지 않는다)
		power_hits += 1
		var go := Arms.POWER_LUNGE_T * 32.0
		for e in enemies:
			if is_instance_valid(e) and not e.cmb.dead:
				var dd: Vector2 = e.loco.logical - player.loco.logical
				if absf(dirv.angle_to(dd)) <= arc:
					go = minf(go, maxf(0.0, dd.length() - pc.radius - e.cmb.radius - 2.0))
		if go > 0.5 and player.world != null:
			var lunge: Vector2 = player.world.move_circle(player.loco.logical, player.loco.logical + dirv * go, player.radius_px)
			player.loco.place(lunge.round())
	var kb := Arms.knockback(w, power) * 32.0
	var n := 0
	var hits: Array = []
	for e in enemies:
		if not is_instance_valid(e) or e.cmb.dead or not e.meets(pc):
			continue                                                     # 다른 층(고가 위·아래)은 닿지 않는다
		hits.append([e.cmb, e.loco.logical, e])
	for rr in residents:                                               # 주민도 맞는다
		if not rr["cmb"].dead and is_instance_valid(rr["actor"]):
			hits.append([rr["cmb"], rr["actor"].loco.logical, null])
	for h in hits:
		if n >= cap:
			break
		var c: Combatant = h[0]
		var d: Vector2 = (h[1] as Vector2) - player.loco.logical
		if d.length() > reach + c.radius or (d.length() >= pc.radius + c.radius and absf(dirv.angle_to(d)) > arc):
			continue
		n += 1
		var e = h[2]
		var sneak: bool = e != null and c.unaware.is_valid() and c.unaware.call()
		var part := CombatRules.pick_part(CombatRules.part_weights(c.weights, {"melee": true, "attacker_crouch": crouch}), shots.rng)
		var r := CombatRules.resolve({"weapon": w, "skill": sk, "power": power, "part": part, "dr": c.dr, "sneak": sneak, "crit": sneak,
			"attacker": {"str": st.stat("ST") if st != null else 5, "unarmed": sk}})
		r["hp"] = float(r["hp"]) * tick_mult * (float(w.get("robot_mult", 1.0)) if c.robot else 1.0)
		r["nonlethal"] = calm or str(w.get("id", "")) == "W-066"
		c.last_by = "player"
		c.take(r, player.loco.logical)
		Projectiles.after_hit(c, w, "", d.length() / 32.0, shots.rng, dirv)
		if not c.dead:
			if kb > 0.0 and not c.big:
				c.push += d.normalized() * kb
			if power and fam == "melee2":
				c.hold("stun", 0.6)                                      # 파워 공격 경직
				if str(w.get("layer", "")) == "T05" and c.weights.has("arm") and shots.rng.randf() < 0.25:
					c.hold("down", 1.5)
			if fam == "unarmed" and part == "head" and shots.rng.randf() < (0.3 if Gear.base(str(w.get("id", ""))) == Arms.FIST else 0.15):
				c.hold("stun", 1.5)
		if e != null:
			e.hear("melee", player.loco.logical)
		stats["hits"] += 1
		if sneak:
			stats["sneak"] += 1
			_pop("기습 치명타 ×%d" % int(CombatRules.sneak_mult("melee", false)), (h[1] as Vector2) + Vector2(0, -22), Color("E8C23A"))
	if tick_mult >= 1.0:
		_wear_weapon(st, n)                                            # 근접은 타격마다 카운터 1(SD-13 §8.2) · 리퍼 틱은 열 번에 한 번
	elif n > 0 and shots.rng.randf() < tick_mult:
		_wear_weapon(st, 1)
	if tick_mult >= 1.0 or shots.rng.randf() < 0.3:
		_swing_fx(player.loco.logical + Vector2(0, -12) + dirv * reach * 0.6)


func start_reload(st: StoryState) -> void:
	if not armed() or reload_t > 0.0:
		return
	var w := weapon()
	if w["kind"] != "ranged" or int(mags.get(weapon_id, 0)) >= int(w["mag"]):
		return
	if str(w.get("ammo_id", "")) != "" and ammo_left(st) <= 0:
		message.emit("탄이 없다.")
		return
	var sk := float(st.skill(Arms.skill_name(w))) if st != null else 15.0
	reload_t = float(w.get("reload_s", 2.0)) * (1.2 - 0.004 * sk)            # SD-11 §3.5
	var jam: float = Gear.JAM[Gear.cond(weapon_id)]
	if jam > 0.0 and _rng.randf() < jam:                                 # 탄 걸림(SD-11 §11.8): 낡음 25% · 위태 80%, 재장전 +1.5초
		reload_t += 1.5
		stats["jams"] = int(stats.get("jams", 0)) + 1
		message.emit("탄 걸림! 노리쇠를 당긴다.")


## 든 무기의 열쇠가 바뀌었다(열화·수리): 탄창·단축키를 새 열쇠로 옮긴다
func rekey(old: String, nk: String, st: StoryState) -> void:
	if weapon_id == old:
		weapon_id = nk
		if mags.has(old):
			mags[nk] = mags[old]
			mags.erase(old)
	for k in hotkeys.keys():
		if hotkeys[k] == old and int(st.items.get(old, 0)) <= 0:
			hotkeys[k] = nk


## 무기 열화(SD-13 §8.2): 공격 1회(연사는 발마다, 근접은 타격마다)에 카운터 1. 볼트 안(프롤로그)은 정비반이 손봐 닳지 않는다(정합 1-8a).
## 단계가 바뀌면 든 무기의 열쇠를 바꿔 낀다(탄창·단축키를 옮긴다). 파손이면 내려놓는다
func _wear_weapon(st: StoryState, n: int) -> void:
	if st == null or n <= 0 or weapon_id == "" or weapon_id == Arms.FIST or st.quests.cur_act() < 1:
		return
	var old := weapon_id
	var nk := Gear.use(st, old, n)
	if nk == old:
		return
	rekey(old, nk, st)
	var nm := str(weapons.get(Gear.base(nk), {}).get("name", nk))
	if Gear.cond(nk) >= 4:
		message.emit("%s — 부서졌다. 더는 쏠 수 없다." % nm)
		mags.erase(nk)
		weapon_id = ""
		holstered = false
		reload_t = 0.0
		st.weapon_out = false
		_doll()
	else:
		message.emit("%s — 상태가 '%s'(으)로 떨어졌다." % [nm, Gear.NAMES[Gear.cond(nk)]])


## 스팀팩(SD-11 §2.7, SD-13 §6.2): 30 × (1 + 의학/50)을 회복 대기열에 2.0초로. 단축키면 0.4초 투여 모션
func use_stimpak(st: StoryState, quick: bool = false) -> bool:
	if st == null or int(st.items.get(STIMPAK, 0)) <= 0:
		message.emit("스팀팩이 없다.")
		return false
	if pc.hp >= pc.max_hp and heal_q.is_empty():
		message.emit("다친 데가 없다.")
		return false
	st.call_fn("take", [STIMPAK, 1])
	var amount := 30.0 * (1.0 + float(st.skill("MEDICINE")) / 50.0)
	heal_q.append(amount)
	if heal_q.size() == 1:
		heal_rate = amount / STIM_QUEUE_S
	if quick:
		inject_t = STIM_INJECT_S
	stats["stims"] += 1
	_pop("스팀팩 +%d" % roundi(amount), pc.pos() + Vector2(0, -34), Color("7CD62B"))
	return true


func healing() -> bool:
	return not heal_q.is_empty()


## 연출 피해(증기 분출 등): 방어 무시
func damage(amount: float) -> void:
	var before := pc.hp
	pc.take({"hp": amount}, pc.pos())
	stats["hurt"] += before - pc.hp
	hurt.emit(before - pc.hp)


## 조준점: 봇이 준 점 · 마우스 커서(360°) · 고전 조작(바라보는 방향, 원뿔 안의 가장 가까운 표적·적에게 끌어당김)
func _aim_point(player: Actor) -> Vector2:
	_aim_real = true
	if not bot.is_empty() and bot.has("aim"):
		return bot["aim"]
	if bot.is_empty() and aim_mode == "mouse":
		return get_global_mouse_position()
	var p := auto_aim(player)
	_aim_real = _auto_hit
	return p


## 고전 조작 조준(SD-11 §2.3): 8방향 바라보는 쪽 기준 반각 15° 안, 사거리 안의 가장 가까운 적·표적 중심. 없으면 그 방향 3칸
func auto_aim(player: Actor) -> Vector2:
	var eye := player.loco.logical + Vector2(0, -14)
	var f: Vector2 = Locomotion.VEC[player.loco.facing].normalized()
	var reach := float(weapon().get("range_max", 8.0)) * 32.0 if armed() else 256.0
	var best := Vector2.INF
	var bd := 1e9
	var cands: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.cmb.dead:
			cands.append(e.loco.logical + Vector2(0, -6))
	for t in targets:
		if not t["down"] and t["live"]:
			cands.append(t["cmb"].pos() + Vector2(0, -12))
	for p in cands:
		var d: Vector2 = p - eye
		if d.length() <= reach and d.length() < bd and absf(f.angle_to(d)) <= deg_to_rad(AUTO_AIM_HALF):
			bd = d.length()
			best = p
	_auto_hit = best != Vector2.INF
	return best if _auto_hit else eye + f * 96.0


## 교전 중: 주인공을 표적으로 잡은 적이 있다(SD-11 §2.5) — 이동 중에도 상체가 조준을 따른다
func in_combat() -> bool:
	for e in enemies:
		if is_instance_valid(e) and not e.cmb.dead and e.brain.state == AIBrain.S.COMBAT:
			return true
	return false


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion or (e is InputEventMouseButton and e.pressed):
		aim_mode = "mouse"
	elif e is InputEventKey and e.pressed and e.physical_keycode in [KEY_Z, KEY_X]:
		aim_mode = "key"                                                # 고전 조작으로 쏘기 시작하면 키보드 조준


## HUD 탐지 표시(SD-12 §4.5): 숨음 · 주의 · 발각 · 위험 중 가장 나쁜 것. 웅크리지 않았으면 위험만 보인다
func detect_state() -> String:
	var worst := 0
	for e in enemies:
		if not is_instance_valid(e) or e.cmb.dead:
			continue
		if e.brain.state == AIBrain.S.COMBAT:
			worst = maxi(worst, 3)
		elif e.brain.gauge >= 40.0:
			worst = maxi(worst, 1)
	for t in targets:
		if t["kind"] != "stealth" or t["down"] or not t["live"]:
			continue
		if t["seen_t"] > 0.0:
			worst = maxi(worst, 2)
		elif t["gauge"] >= 40.0:
			worst = maxi(worst, 1)
	if not crouch:
		return "위험" if worst == 3 else ""
	return ["숨음", "주의", "발각", "위험"][worst]


# ---------------------------------------------------------------- 표적
func _targets(dt: float, player: Actor) -> void:
	var pp := player.loco.logical
	for t in targets:
		var c: Combatant = t["cmb"]
		if t["down"]:
			continue
		if t["kind"] == "stealth":
			if not t["live"]:
				c.hp = c.max_hp
				c.dead = false
				continue
			var to: Vector2 = pp - c.pos()
			var dist_t := to.length() / 32.0
			var sees: bool = dist_t <= Perception.sight_range(STEALTH_PER) and shots.world.line_of_sight(c.pos(), pp, crouch)
			if t["seen_t"] > 0.0:
				t["seen_t"] -= dt
				if t["seen_t"] <= 0.0:
					t["gauge"] = 0.0
					_prop_state(t, "")
			elif sees:
				var moving := player.loco.motion != "idle"
				var rate := Perception.detect_rate(dist_t, STEALTH_PER, {"posture": "crouch" if crouch else "stand",
					"movement": ("sneak" if crouch else "move") if moving else "still",
					"in_fov": Perception.in_fov(t["facing"], to, "human"), "sneak_skill": sneak_skill})
				if dist_t <= 1.2:
					rate = 1000.0                                              # 접촉 1.2t: 바로 들킨다(SD-11 §7.3)
				t["gauge"] = minf(100.0, t["gauge"] + rate * dt)
				if t["gauge"] >= 100.0:
					t["seen_t"] = STEALTH_RESET_S
					stats["spotted"] += 1
					_prop_state(t, "duck")
					_pop("들켰다!", c.pos() + Vector2(0, -30), Color("E04A35"))
					message.emit("들켰다 — 표적이 숨었다. 웅크리고(Ctrl) 상자 뒤로 다가가자.")
			else:
				t["gauge"] = maxf(0.0, t["gauge"] - 10.0 * dt)
		if c.dead or c.hp < c.max_hp:
			_hit_target(t)


func _hit_target(t: Dictionary) -> void:
	var c: Combatant = t["cmb"]
	var sneak: bool = t["kind"] == "stealth" and t["seen_t"] <= 0.0 and t["gauge"] < 100.0
	if t["kind"] == "stealth" and not sneak:
		c.hp = c.max_hp                                                   # 숨은 표적: 맞지 않는다
		c.dead = false
		return
	t["down"] = true
	c.dead = true
	stats["hits"] += 1
	_prop_state(t, "down")
	if sneak:
		stats["sneak"] += 1
		_pop("기습 치명타 ×%d" % int(CombatRules.sneak_mult("ranged", false)), c.pos() + Vector2(0, -30), Color("E8C23A"))
	target_down.emit(t["kind"], sneak, targets_left("target") + targets_left("stealth"))


func _prop_state(t: Dictionary, state: String) -> void:
	var p: Dictionary = t["prop"]
	if shots.world != null:
		shots.world.set_prop_state(Vector2i(int(p["x"]), int(p["y"])), state)


# ---------------------------------------------------------------- 일시 동행(하도윤)
## 뒤 2~4t를 따라온다(SD-11 §8.2). 1.4t 안에 바퀴가 오면 대걸레 자루로 친다. 프롤로그 불사(SD-03a §6.4).
func _buddy(dt: float) -> void:
	if buddy == null or not is_instance_valid(buddy):
		return
	_buddy_cool = maxf(0.0, _buddy_cool - dt)
	var w: Dictionary = weapons[buddy_weapon]
	var near: Enemy = null
	var nd := 1e9
	for e in enemies:
		if is_instance_valid(e) and not e.cmb.dead:
			var d: float = e.loco.logical.distance_to(buddy.loco.logical)
			if d < nd:
				nd = d
				near = e
	if near != null and nd <= float(w["range_eff"]) * 32.0 + near.cmb.radius:
		buddy.move(Vector2.ZERO, dt)
		buddy.loco.facing = Locomotion.snap8(near.loco.logical - buddy.loco.logical, 0.0)
		buddy._show()
		if _buddy_cool <= 0.0:
			_buddy_cool = 1.0 / float(w["rate"])
			var r := CombatRules.resolve({"weapon": w, "skill": 15.0, "attacker": {"str": 5},
				"part": CombatRules.pick_part(near.cmb.weights, _rng), "dr": near.cmb.dr})
			near.cmb.take(r, buddy.loco.logical)
			_swing_fx(buddy.loco.logical + Vector2(0, -10) + (near.loco.logical - buddy.loco.logical).normalized() * 18.0)
		return
	var goal: Vector2 = pc.pos()
	if near != null and nd < 6.0 * 32.0:
		goal = near.loco.logical                                         # 교전: 가까운 바퀴에게 간다
	var d := buddy.loco.logical.distance_to(goal)
	if near == null and d > 15.0 * 32.0:
		buddy.loco.place(pc.pos() + (buddy.loco.logical - pc.pos()).normalized() * 96.0)   # 너무 떨어지면 뒤 3t로(§8.2)
	elif d > (3.0 * 32.0 if near == null else 24.0):
		buddy.mode = "run"
		buddy.move(buddy.steer(goal - buddy.loco.logical), dt)
	else:
		buddy.move(Vector2.ZERO, dt)


# ---------------------------------------------------------------- 그리기
func _pop(text: String, at: Vector2, col: Color) -> void:
	popups.append([text, at, 1.0, col])


var _swings: Array = []


func _swing_fx(at: Vector2) -> void:
	_swings.append([at, 0.12])


## 조준 커서(SD-11 §12.4): 퍼짐 원(반지름 = 그 거리에서 지금 퍼짐 반각), 사거리 밖이면 점선, 장전 중이면 회색 원호
func _draw_cursor() -> void:
	var a: Actor = pc.actor
	if a == null or not armed() or not visible_cursor:
		return
	if not (aim_mode == "mouse" and bot.is_empty()) and a.aim_dir < 0:
		return                                                          # 키보드·봇: 조준 자세일 때만(마우스면 늘 커서 자리에)
	var w := weapon()
	var aim := _aim_point(a)
	var from := a.loco.logical + Vector2(0, -14)
	var d := aim - from
	var col := Color("7CF08E")
	if w["kind"] != "ranged":
		draw_arc(aim.round(), 3.0, 0, TAU, 8, col, 1.0)
		return
	var sk := 15.0
	var sp := CombatRules.spread(sk, "crouch" if crouch else "stand", a.loco.motion != "idle", "new", 1.0, 0.0, 0.0, float(w.get("min_spread", 1.0)))
	var r := clampf(d.length() * tan(deg_to_rad(sp)), 3.0, 40.0)
	var far := d.length() > float(w["range_max"]) * 32.0
	if reload_t > 0.0:
		var k := 1.0 - reload_t / maxf(0.01, float(w.get("reload_s", 2.0)))
		draw_arc(aim.round(), r, -PI / 2.0, -PI / 2.0 + TAU * k, 24, Color("8B857D"), 2.0)
		return
	var segs := 16
	for i in segs:
		if far and i % 2 == 1:
			continue                                                    # 사거리 밖: 점선
		var a0 := TAU * i / segs
		draw_arc(aim.round(), r, a0, a0 + TAU / segs, 3, col if not far else Color("E04A35"), 1.0)
	draw_rect(Rect2(aim.round() - Vector2(0.5, 0.5), Vector2(1, 1)), col)


var visible_cursor := true


func _draw() -> void:
	_draw_cursor()
	for s in _swings:
		var a: Vector2 = (s[0] as Vector2).round()
		draw_arc(a, 7.0, -0.8, 0.8, 6, Color("E9E4D8"), 1.0)
		s[1] -= get_process_delta_time()
	_swings = _swings.filter(func(s): return s[1] > 0.0)
	for p in popups:
		var w := font.get_string_size(p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		var at: Vector2 = (p[1] as Vector2).round() - Vector2(roundf(w / 2.0), 0)
		for o in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			draw_string(font, at + o, p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("0B0A0D"))
		draw_string(font, at, p[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, p[3])
	for t in targets:                                                    # 은신 표적의 탐지 게이지
		if t["kind"] != "stealth" or t["down"] or not t["live"] or (t["gauge"] <= 0.0 and t["seen_t"] <= 0.0):
			continue
		var c: Vector2 = t["cmb"].pos() + Vector2(-8, -28)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(18, 5)), Color("0B0A0D"))
		draw_rect(Rect2(c, Vector2(16.0 * t["gauge"] / 100.0, 3)), Color("E04A35") if t["seen_t"] > 0.0 else Color("E8C23A"))


## 표적 자리표(Combatant.pos()가 actor.loco.logical을 읽는다)
class _Pos:
	extends RefCounted
	var loco: Locomotion

	func _init(p: Vector2) -> void:
		loco = Locomotion.new(p)
