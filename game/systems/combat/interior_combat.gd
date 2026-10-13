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
const DOLL := {"W-065": "bb", "W-067": "pole"}    ## 무기 → 페이퍼돌 손 무기(SD-13 §3.11 형상 차분). 그 밖은 레이어 첫 글자로
const DOLL_LAYER := {"P": "pistol", "R": "rifle", "M": "baton", "T": "pole"}

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
var inject_t := 0.0
var heal_q: Array = []                            ## 회복 대기열: 남은 회복량(앞에서부터 2.0초씩)
var heal_rate := 0.0
var enemies: Array = []
var targets: Array = []                           ## [{"prop", "kind": "target"|"stealth", "cmb", "gauge", "seen_t", "down", "facing", "live"}]
var stealth_live := false                         ## 은신 표적을 쓰는 중(사격장 2부) — 아니면 받침 뒤에 숨어 있다
var buddy: Actor                                  ## 일시 동행(MQ-P2 하도윤): 따라오고, 가까운 바퀴를 대걸레 자루로 친다. 불사
var buddy_weapon := "W-067"
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


func _init() -> void:
	z_index = 6
	_rng.seed = 2268
	font = load("res://assets/fonts/Galmuri9.ttf")
	weapons = JSON.parse_string(FileAccess.get_file_as_string("res://data/weapons.json"))
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
			spawn(str(row["id"]), Vector2(int(row["x"]) * 32 + 16, int(row["y"]) * 32 + 16), map, st)
	_rebuild_list()
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


func spawn(enemy_id: String, pos: Vector2, map: InteriorMap, st: StoryState = null) -> Enemy:
	var e := Enemy.new()
	e.setup_enemy(enemy_rows[enemy_id], {}, pos, map)
	e.set_meta("enemy_id", enemy_id)
	e.cmb.unaware = func() -> bool: return e.brain.state != AIBrain.S.COMBAT and e.brain.gauge < 100.0
	map.objects.add_child(e)
	enemies.append(e)
	e.cmb.died.connect(func() -> void:
		stats["downs"] += 1
		if st != null:
			st.call_fn("xp", [int(enemy_rows[enemy_id]["xp"])])
			if enemy_id == "CR-002":
				st.call_fn("give", ["I-036", 1])                         # 바퀴 고기 100%(SD-14 §3.1)
		enemy_killed.emit(enemy_id, alive_enemies()))
	_rebuild_list()
	return e


func alive_enemies() -> int:
	return enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead).size()


func targets_left(kind: String) -> int:
	return targets.filter(func(t): return t["kind"] == kind and not t["down"]).size()


func _rebuild_list() -> void:
	var l: Array = [pc]
	for e in enemies:
		if is_instance_valid(e):
			l.append(e.cmb)
	for t in targets:
		l.append(t["cmb"])
	shots.combatants = l


func armed() -> bool:
	return weapon_id != "" and weapons.has(weapon_id) and not holstered


func weapon() -> Dictionary:
	return weapons.get(weapon_id, {})


## 무기 고르기. 처음 드는 원거리 무기는 소지 탄약으로 탄창을 채운다
func equip(id: String, st: StoryState) -> void:
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
		w = DOLL.get(weapon_id, DOLL_LAYER.get(str(weapon().get("layer", "")).substr(0, 1), ""))
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
	cool = maxf(0.0, cool - dt)
	if pc.flash > 0:
		pc.flash -= 1
	if player.doll != null:
		player.doll.set_flash(1.0 if pc.flash > 0 else 0.0)
		if pc.flash == 2:
			player.doll.flash_face("hurt", 0.3)
	var hp0 := pc.hp
	var step := dt if free else 0.0
	for e in enemies:
		if is_instance_valid(e):
			var was: bool = e.cmb.flash > 0
			e.think(step, pc, nav, shots)
			if e.cmb.flash == 2 and not was and e.cmb.last_sneak:
				e.cmb.last_sneak = false
				_pop("기습 치명타 ×%d" % int(CombatRules.sneak_mult("ranged", false)), e.loco.logical + Vector2(0, -22), Color("E8C23A"))
	if free:
		_heal(dt)
		_targets(dt, player)
		_buddy(dt)
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
	if bot.is_empty():
		if Input.is_action_just_pressed("crouch"):
			crouch = not crouch
		if Input.is_action_just_pressed("holster") and weapon_id != "":
			holstered = not holstered
			reload_t = 0.0
			if st != null:
				st.weapon_out = armed()
			_doll()
	else:
		crouch = bot.get("crouch", false)
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
	if not fire or cool > 0.0:
		return
	cool = 1.0 / float(w["rate"])
	if ranged:
		if int(mags.get(weapon_id, 0)) <= 0:
			start_reload(st)                                              # 탄창이 비면 자동 재장전(옵션 기본 켬)
			return
		var sk := float(st.skill("SMALL_GUNS")) if st != null else 15.0
		var aiming: bool = Input.is_action_pressed("aim") if bot.is_empty() else bool(bot.get("aimed", true))
		var stance := ("crouch_aim" if aiming else "crouch") if crouch else ("aim" if aiming else "stand")
		var sp := CombatRules.spread(sk, stance, player.loco.motion != "idle", "new", 1.0, 0.0, 0.0, float(w.get("min_spread", 1.0)))
		# 탄은 그려진 총의 총구에서 나가 조준점으로 간다(SD-16 §5 'muzzle'). 총 그림 방향 = 조준 중이면 조준 방향, 아니면 몸 방향.
		# 총구 화염은 인형이 총과 같은 층에 그린다(N·NE 조준이면 머리 뒤).
		var gdir: int = player.aim_dir if player.aim_dir >= 0 else player.loco.facing
		var muzzle := player.loco.logical + Vector2(0, -14) + to.normalized() * 10.0
		if player.doll != null:
			muzzle = player.position + player.doll.position + player.doll.muzzle_local(gdir)
		var line := aim - muzzle
		var ang := CombatRules.shot_angle(rad_to_deg((line if _aim_real and line.length() > 24.0 else to).angle()), sp, shots.rng)
		if shots.fire(muzzle, ang, SHOT_SPEED, "player", w, sk, false, 5, "" if player.doll != null else "auto"):
			shots.shots[-1]["sneak_ok"] = true
			mags[weapon_id] = int(mags[weapon_id]) - 1
			stats["shots"] += 1
			if player.doll != null:
				player.doll.flash_face("fire", 0.14)
				player.doll.fire_flash(gdir, ang, CombatFx.flash_for(w))
			for e in enemies:
				if is_instance_valid(e):
					e.hear(str(w.get("sound", "pistol")), player.loco.logical)
	else:
		_melee(player, w, to, st)


## 근접(SD-11 §3.4): 한손 호 90°·1.1t, 양손 호 140°·1.4t(무기 사거리), 호 안의 충돌체 중심이면 명중(굴림 없음)
func _melee(player: Actor, w: Dictionary, to: Vector2, st: StoryState) -> void:
	var two: bool = w.get("two_handed", false)
	var reach := float(w["range_eff"]) * 32.0
	var arc := deg_to_rad(70.0 if two else 45.0)
	var n := 0
	for e in enemies:
		if not is_instance_valid(e) or e.cmb.dead or n >= (4 if two else 3):
			continue
		var d: Vector2 = e.loco.logical - player.loco.logical
		if d.length() <= reach + e.cmb.radius and (d.length() < pc.radius + e.cmb.radius or absf(to.angle_to(d)) <= arc):
			n += 1
			var sneak: bool = e.cmb.unaware.call()
			var part := CombatRules.pick_part(e.cmb.weights, shots.rng)
			var r := CombatRules.resolve({"weapon": w, "skill": float(st.skill("MELEE")) if st != null else 15.0,
				"attacker": {"str": st.stat("ST") if st != null else 5}, "part": part, "dr": e.cmb.dr, "sneak": sneak, "crit": sneak})
			e.cmb.take(r, player.loco.logical)
			e.hear("melee", player.loco.logical)
			stats["hits"] += 1
			if sneak:
				stats["sneak"] += 1
				_pop("기습 치명타 ×%d" % int(CombatRules.sneak_mult("melee", false)), e.loco.logical + Vector2(0, -22), Color("E8C23A"))
	_swing_fx(player.loco.logical + Vector2(0, -12) + to.normalized() * reach * 0.6)


func start_reload(st: StoryState) -> void:
	if not armed() or reload_t > 0.0:
		return
	var w := weapon()
	if w["kind"] != "ranged" or int(mags.get(weapon_id, 0)) >= int(w["mag"]):
		return
	if str(w.get("ammo_id", "")) != "" and ammo_left(st) <= 0:
		message.emit("탄이 없다.")
		return
	var sk := float(st.skill("SMALL_GUNS")) if st != null else 15.0
	reload_t = float(w.get("reload_s", 2.0)) * (1.2 - 0.004 * sk)            # SD-11 §3.5


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
