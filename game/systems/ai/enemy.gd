## 적 v0: 인지(0.1초)·상태(0.1초)·전술(0.5초)·행동(매 프레임) 4층 (SD-11 §7.1).
## 성향: 'swarm'(큰바퀴: 둘러싸고 3t 안 2초 머물면 도약 물기) / 'shooter'(보병 계엄병: 유효 사거리 60~90% 유지, 공격 토큰).
class_name Enemy
extends Actor

var brain: AIBrain
var cmb := Combatant.new()
var row: Dictionary
var style := "shooter"
var weapon: Dictionary
var skill := 45.0
var per := 5.0
var react := 0.3                              ## 반응 지연(계엄군 0.3초, §7.4)
var has_token := false
var _t_per := 0.0
var _t_tac := 0.0
var _cool := 0.0
var _close_t := 0.0
var _leap := 0.0
var _path := PackedVector2Array()
var _path_i := 0
var _hist: Array = []                         ## [time, pos] of the target for the reaction delay
var _clock := 0.0
var _intent := {"goal": "hold"}
var _move := Vector2.ZERO
var _dead_t := 0.0
var _heard := 0.0
var _heard_at := Vector2.ZERO
var ui_font: Font
var shots_fired := 0
var _wander_t := 0.0
var _rng := RandomNumberGenerator.new()


func setup_enemy(enemy_row: Dictionary, weapon_row: Dictionary, pos: Vector2, w) -> void:
	row = enemy_row
	weapon = weapon_row
	var is_roach: bool = row["id"] == "CR-002"
	setup("cr_cr002_base_loco" if is_roach else "pc_comp_t06_pf01_loco", pos, w)
	style = "swarm" if is_roach else "shooter"
	cmb.actor = self
	cmb.team = "enemy"
	cmb.hp = float(row["hp"])
	cmb.max_hp = cmb.hp
	cmb.dr = float(row["dr"])
	cmb.radius = float(row["radius"]) * 32.0
	radius_px = cmb.radius
	cmb.weights = {"head": 15, "torso": 55, "leg": 30} if is_roach else CombatRules.HUMANOID_WEIGHTS
	per = 3.0 if is_roach else 5.0
	brain = AIBrain.new(pos, per, "insect" if is_roach else "human")
	if is_roach:
		loco.custom = {"run": {"frames": 4, "px": 3.0, "diag": 2.0, "contact": [0, 2], "speed_t": float(row["speed"])},
			"walk": {"frames": 4, "px": 3.0, "diag": 2.0, "contact": [0, 2], "speed_t": float(row["speed"]) * 0.5}}
	ui_font = load("res://assets/fonts/Galmuri9.ttf")
	_rng.seed = int(pos.x * 7 + pos.y * 13)
	_t_tac = _rng.randf() * 0.5                                    # 전술 갱신을 개체마다 엇갈리게(한 프레임 몰림 방지)
	_t_per = _rng.randf() * 0.1


## 소리 사건(총성 등): 다음 인지 틱에 반영
func hear(kind: String, at: Vector2) -> void:
	var g := Perception.sound_gain(kind, loco.logical.distance_to(at) / 32.0)
	if g > _heard:
		_heard = g
		_heard_at = at


func think(dt: float, target: Combatant, nav: NavGrid, shots: Projectiles) -> void:
	_clock += dt
	if cmb.dead:
		_die_step(dt)
		return
	if cmb.flash > 0:
		cmb.flash -= 1
	_hist.append([_clock, target.pos()])
	while _hist.size() > 2 and _clock - float(_hist[0][0]) > react + 0.1:
		_hist.pop_front()
	_t_per += dt
	if _t_per >= 0.1:                                              # 인지 + 상태 층
		var step := _t_per
		_t_per = 0.0
		var to := target.pos() - loco.logical
		var dist_t := to.length() / 32.0
		var fwd: Vector2 = Locomotion.VEC[loco.facing].normalized()
		var fov := brain.state == AIBrain.S.COMBAT or Perception.in_fov(fwd, to, brain.kind)   # 교전 중에는 표적을 계속 본다
		var sees: bool = not target.dead and dist_t <= Perception.sight_range(per) and world.line_of_sight(loco.logical, target.pos())
		var rate: float = Perception.detect_rate(dist_t, per, {"movement": "move", "alert": brain.alert(), "in_fov": fov}) if sees else 0.0
		var hit: bool = cmb.last_hit_from != Vector2.ZERO
		cmb.last_hit_from = Vector2.ZERO
		_intent = brain.tick(step, {"sees": sees and (fov or dist_t <= 3.0), "rate": rate, "target": target.pos(),
			"hit": hit, "sound": _heard, "sound_at": _heard_at, "at_home": loco.logical.distance_to(brain.home) < 24.0})
		_heard = 0.0
	_t_tac += dt
	if _t_tac >= 0.5:                                              # 전술 층
		_t_tac = 0.0
		_tactics(target, nav)
	_act(dt, target, shots)
	queue_redraw()


func _tactics(target: Combatant, nav: NavGrid) -> void:
	var goal: String = _intent.get("goal", "hold")
	var at: Vector2 = _intent.get("at", loco.logical)
	_move = Vector2.ZERO
	if goal == "engage":
		var d := loco.logical.distance_to(target.pos()) / 32.0
		var los: bool = world.line_of_sight(loco.logical, target.pos())
		if style == "swarm":
			_repath(nav, target.pos())
		else:
			var lo: float = float(weapon["range_eff"]) * 0.6
			var hi: float = float(weapon["range_eff"]) * 0.9
			if d > hi or not los:
				_repath(nav, target.pos())
			elif d < lo:
				_path = PackedVector2Array()
				_move = (loco.logical - target.pos()).normalized()       # back off to the preferred band
			else:
				_path = PackedVector2Array()
	elif goal == "walk_to" or goal == "home":
		_repath(nav, at)
	else:                                                          # 대기: 배회 반경 4t (§7.2)
		_wander_t -= 0.5
		if _wander_t <= 0.0:
			_wander_t = 3.0 + _rng.randf() * 3.0
			var p := brain.home + Vector2(_rng.randf_range(-4, 4), _rng.randf_range(-4, 4)) * 32.0
			_repath(nav, p)


func _repath(nav: NavGrid, to: Vector2) -> void:
	var p := nav.path(loco.logical, to)
	if p.size() > 0:
		_path = p
		_path_i = 1


func _act(dt: float, target: Combatant, shots: Projectiles) -> void:
	var goal: String = _intent.get("goal", "hold")
	mode = "walk" if goal == "walk_to" or goal == "home" or goal == "hold" else "run"
	var input := _move
	if _path.size() > 0 and _path_i < _path.size():
		var wp: Vector2 = _path[_path_i]
		if loco.logical.distance_to(wp) < 6.0:
			_path_i += 1
		input = (wp - loco.logical)
	var to_t := target.pos() - loco.logical
	if goal == "engage" or goal == "face":
		aim_dir = Locomotion.snap8(to_t, 0.0) if style == "shooter" else -1
	else:
		aim_dir = -1
	if style == "swarm" and goal == "engage":
		_swarm(dt, target, to_t)
		if _leap > 0.0:
			return
		if to_t.length() < cmb.radius + target.radius + 2.0:
			input = Vector2.ZERO
	move(input, dt)
	if aim_dir >= 0 and loco.motion == "idle":
		loco.facing = aim_dir                                       # 서서 조준하면 그쪽을 본다(시야각 기준)
	if goal == "engage" and style == "shooter":
		_shoot(dt, target, shots)


func _swarm(dt: float, target: Combatant, to_t: Vector2) -> void:
	_cool = maxf(0.0, _cool - dt)
	if _leap > 0.0:                                               # leap: airborne frames only, then bite
		_leap -= dt
		var blocked := func(a: Vector2, b: Vector2) -> Vector2: return world.move_circle(a, b, radius_px)
		loco.logical = blocked.call(loco.logical, loco.logical + to_t.normalized() * 160.0 * dt)
		loco.render = loco.logical.round()
		position = loco.render
		if _leap <= 0.0 and loco.logical.distance_to(target.pos()) <= 32.0 + target.radius:
			target.take({"hp": 3.0}, loco.logical)
		return
	if to_t.length() <= 3.0 * 32.0:
		_close_t += dt
		if _close_t >= 2.0 and _cool <= 0.0:
			_leap = 0.25
			_close_t = 0.0
			_cool = 1.2
	else:
		_close_t = 0.0


func _shoot(dt: float, target: Combatant, shots: Projectiles) -> void:
	_cool = maxf(0.0, _cool - dt)
	if not has_token or _cool > 0.0 or target.dead:
		return
	if not world.line_of_sight(loco.logical, target.pos()):
		return
	var seen: Vector2 = _hist[0][1] if not _hist.is_empty() else target.pos()     # aim lags by the reaction delay
	var aim := rad_to_deg((seen - loco.logical).angle())
	var sp := CombatRules.spread(skill, "stand", loco.motion != "idle")
	var ang := CombatRules.shot_angle(aim, sp, shots.rng)
	if shots.fire(loco.logical + Vector2(0, -14) + Vector2.RIGHT.rotated(deg_to_rad(aim)) * 10.0, ang, 640.0, "enemy", weapon, skill):
		_cool = 1.0 / (float(weapon["rate"]) * 0.6)                  # semi-auto: 60% of max rate
		shots_fired += 1


func _die_step(dt: float) -> void:
	_dead_t += dt
	if style == "swarm":
		var f := mini(int(_dead_t * 10.0), sprite.sprite_frames.get_frame_count("death_E") - 1)
		sprite.animation = "death_E"
		sprite.frame = f
	else:
		sprite.modulate = Color(1, 1, 1, 0) if _dead_t > 0.3 else (Color(3, 3, 3) if int(_dead_t * 20) % 2 == 0 else Color(1, 1, 1))


func _show() -> void:
	super._show()
	if cmb != null and cmb.flash > 0:
		sprite.modulate = Color(4, 4, 4)
	elif cmb != null and not cmb.dead:
		sprite.modulate = Color(1, 1, 1)


func _draw() -> void:
	if cmb.dead:
		return
	var top := -float(meta["foot"][1]) + (14.0 if style == "shooter" else 6.0)
	match brain.state:
		AIBrain.S.SUSPICIOUS, AIBrain.S.SEARCH:
			draw_string(ui_font, Vector2(-3, top - 2), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e8c23a"))
		AIBrain.S.LOST:
			draw_string(ui_font, Vector2(-3, top - 2), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e04a35"))
		AIBrain.S.COMBAT:
			if brain._t_state < 0.8:
				draw_string(ui_font, Vector2(-2, top - 2), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("e04a35"))
			elif cmb.hp < cmb.max_hp:
				var w := 16.0
				draw_rect(Rect2(-w / 2, top + 2, w, 2), Color("1a181d"))
				draw_rect(Rect2(-w / 2, top + 2, w * cmb.hp / cmb.max_hp, 2), Color("e04a35"))
