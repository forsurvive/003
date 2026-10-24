## 필드 보스 교전 시간 실측(1-13 D-380, SD-11 §10.3 기준 35~60초 · SD-25 B3): 관악산 비탈(월드) 빈 땅에 보스와 호위를 세우고,
## 그 레벨의 표준 무기(10mm 권총 W-002 — SD-25 표준 무기)를 든 주인공을 싸움 봇으로 돌린다. 보스가 쓰러지거나 달아나고 호위가 다 정리되면
## 'BOSSFIGHT|보스|초|주인공 HP|스팀팩|끝' 한 줄. 사람 손이 아니라 '늘 맞히려 드는 봇'이라 실제보다 조금 빠르다(추세 기록).
## 실행: godot --headless --path game res://scenes/bench/boss_fight_check.tscn -- CR-500 [씨앗] [맵|W] [표지]
##   BF_STAND=1 제자리에서 쏜다(뒷걸음 없음 — 받는 피해의 위쪽 끝) · BF_PLV=n 주인공 레벨 · BF_LOG=1 반초마다 읽기만(적을 건드리지 않는다)
extends Node

const SETUP := {
	"CR-500": {"lv": 6, "adds": [["CR-104", 4], ["CR-105", 2]]},          # 외눈 + 무리(SD-14 §10.2 · balance_check BOSS_FIGHT와 같은 편성)
	"CR-501": {"lv": 5, "adds": [["CR-002", 3]]},                          # 배수구 어미(부화는 진행 중 15초마다 — enemy.gd)
}
const LIMIT := 240.0
var host: InteriorHost
var boss: Enemy
var boss_id := "CR-500"
var t := 0.0
var started := false
var stims0 := 5
var done := false
var hp_min := 99999.0
var field := Vector2i.ZERO                  ## 싸움터 왼쪽 위 칸(12×12) — 주인공은 이 안에서만 물러선다
var mine: Array = []                         ## 벤치가 세운 적만 센다(월드에 따로 사는 쥐 · 들개가 끼어도 싸움 끝을 흐리지 않게)
var boss_dead := false
var map_id0 := ""
var phases := ""                            ## 외눈 국면이 바뀐 시각(①→② · ③)
var rng := RandomNumberGenerator.new()
var live := false                           ## J-10 실전 판(어미는 맵이 세운 것 · 진행기 UqR02가 국면을 몬다)
var uq: UqR02 = null
var t_wake := -1.0                          ## 어미가 천장에서 내려온 시각(실전 판 — 교전 시간은 첫 알 낙하부터 센다)
var t_drop := -1.0                          ## 첫 알 낙하 시각


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	boss_id = a[0] if a.size() > 0 else "CR-500"
	seed(int(a[1]) if a.size() > 1 else 7)
	rng.seed = int(a[1]) if a.size() > 1 else 7
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	var lv: int = SETUP[boss_id]["lv"]
	var plv := int(OS.get_environment("BF_PLV")) if OS.get_environment("BF_PLV") != "" else lv   # 주인공 레벨만 따로(보스는 그대로)
	st.vars.set_v("PC_XP", Perks.xp_at(plv) + 10)
	st.call_fn("give", ["W-002"])
	st.call_fn("give", ["10mm 탄", 400])
	st.call_fn("give", ["I-001", stims0])
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true                                                    # HUD가 꺼져 있으면 연출 중으로 보고 적이 멈춘다
	host.date_text = "2277. 10. 27.  13:00"
	var mid := a[2] if a.size() > 2 else "J-02"                           # 싸울 맵(기본 지하시장 넓은 마당 — 트인 14×14칸을 찾는다)
	var mark := a[3] if a.size() > 3 else "from_J-01"
	if boss_id == "CR-501" and mid == "J-10":                             # 실전 판(D-380): 맵에 사는 천장 어미를 그대로 — 알 낙하 · 내려옴 · 배 터짐은 UQ-09 진행기가 몬다
		live = true
		mark = a[3] if a.size() > 3 else "from_J02"
		uq = UqR02.new()
		add_child(uq)
		uq.setup(host, false)
	if mid == "W":
		PlaceLog.load_db()
		var arr: Array = PlaceLog.db["L-R01-05"]["arrive"]
		host.enter("W", "", {}, Vector2(int(arr[0]) * 32 + 16, int(arr[1]) * 32 + 16))
	else:
		host.enter(mid, mark)
	host.combat.equip("W-002", st)
	Encounters.new(st, 1)
	if host.enc_live != null:
		host.enc_live.off = true                                           # 길 위 RE가 끼어들지 않게


func _spawn() -> void:
	var lv: int = SETUP[boss_id]["lv"]
	map_id0 = host.map.id
	if live:
		for e in host.combat.enemies:
			if is_instance_valid(e) and str(e.who) == UqR02.MOM_WHO:
				boss = e
		if boss == null:
			print("  J-10에 어미가 없음")
			done = true
			get_tree().quit()
			return
		print("  실전 판 J-10 · 어미 칸 %s · 주인공 칸 %s · 맵 적 %d" % [str(host.map.tile_of(boss.loco.logical)), str(host.map.tile_of(host.player.loco.logical)), host.combat.enemies.size()])
		return
	field = _open_field(host.map.tile_of(host.player.loco.logical), 12)   # 다 트인 14×14칸(담 · 난간 · 높이 단 없음 — 필드 보스 마당과 같은 조건)
	print("  싸움터 %s(맵 %s)" % [str(field), host.map.id])
	host.player.loco.place(Vector2(field + Vector2i(6, 10)) * 32.0 + Vector2(16, 16))
	host.player.position = host.player.loco.render
	var at := Vector2(field + Vector2i(rng.randi_range(3, 9), 1)) * 32.0 + Vector2(16, 16)   # 씨앗마다 보스 자리 · 호위 자리가 다르다
	boss = host.combat.spawn(boss_id, at, host.map, host.st, {"lv": lv})
	boss.brain.gauge = 100.0
	boss.brain.state = AIBrain.S.COMBAT
	mine.append(boss)
	if OS.get_environment("BF_LOG") != "":
		boss.tree_exiting.connect(func() -> void: print("  보스가 나무에서 빠짐 t=%.1f" % t); print_stack())
	boss.brain.home = host.player.loco.logical                          # 세운 자리에 묶이지 않게(집 반경 밖으로 쫓아오지 않는다)
	print("  길 시험: %d점 · 보스 층 %d · 주인공 층 %d" % [host.combat.nav.path(boss.loco.logical, host.player.loco.logical, boss.floor_id, host.player.floor_id).size(), boss.floor_id, host.player.floor_id])
	var k := 0
	for ad in SETUP[boss_id]["adds"]:
		for i in int(ad[1]):
			k += 1
			var e := host.combat.spawn(str(ad[0]), _free(at + Vector2((k % 4 - 1.5) * 40.0 + rng.randf_range(-12, 12), (k / 4) * 40.0 + rng.randf_range(0, 24))), host.map, host.st, {"lv": lv})
			e.brain.gauge = 100.0
			e.brain.state = AIBrain.S.COMBAT
			e.brain.home = host.player.loco.logical
			mine.append(e)


func _open_field(c0: Vector2i, n: int) -> Vector2i:
	var lv0: int = host.map.level_at(c0)
	for r in range(0, 80, 2):
		for dy in range(-r, r + 1, 2):
			for dx in range(-r, r + 1, 2):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var o := c0 + Vector2i(dx, dy)
				var ok := true
				for yy in n:
					for xx in n:
						var c := o + Vector2i(xx, yy)
						var outside: bool = not (host.map is WorldMap) and (c.x < 1 or c.y < 1 or c.x >= host.map.size.x - 1 or c.y >= host.map.size.y - 1)
						if outside or host.map.is_solid(c) or host.map.level_at(c) != lv0:
							ok = false
							break
					if not ok:
						break
				if ok:
					return o
	print("  트인 땅 못 찾음")
	return c0 - Vector2i(6, 6)


func _free(p: Vector2) -> Vector2:
	var t0: Vector2i = host.map.tile_of(p)
	for r in range(0, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var c := t0 + Vector2i(dx, dy)
				if not host.map.is_solid(c):
					return Vector2(c) * 32.0 + Vector2(16, 16)
	return p


func _process(dt: float) -> void:
	if done or host == null or host.map == null or host.player == null:
		return
	if not started:
		t += dt
		if t > 1.5:
			_spawn()
			started = true
			t = 0.0
		return
	t += dt
	hp_min = minf(hp_min, host.combat.pc.hp)
	if OS.get_environment("BF_LOG") != "" and is_instance_valid(boss) and int(t * 2.0) != int((t - dt) * 2.0):
		print("  보스 hp%d 상태 %d 국면 %d 칸 %s 팀 %s · 목표 %s 성향 %s 토큰 %s 쉼 %.1f 묶임 %s 걸음 %s 거리 %.0fpx" % [int(boss.cmb.hp), int(boss.brain.state), boss.one_phase, str(host.map.tile_of(boss.loco.logical)), boss.cmb.team,
			str(boss._intent.get("goal", "")), boss.style, boss.has_mtoken, boss._cool, boss.leash, boss.loco.motion, boss.loco.logical.distance_to(host.player.loco.logical)])
	if is_instance_valid(boss) and boss.cmb.dead:
		boss_dead = true                                              # 쓰러진 몸은 곧 치워진다 — 그 전에 적어 둔다
	var me: Vector2 = host.player.loco.logical
	if live:
		dt_last = dt
		_live_step(me)
		return
	var alive := mine.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy" and e.loco.logical.distance_to(me) < 30.0 * 32.0)
	var boss_out := not is_instance_valid(boss) or boss.cmb.dead or boss.loco.logical.distance_to(me) > 30.0 * 32.0
	if (alive.is_empty() and boss_out) or t > LIMIT or host.combat.pc.dead:
		done = true
		var how := "시간 초과" if t > LIMIT else ("주인공 쓰러짐" if host.combat.pc.dead else ("처치" if boss_dead else ("사라짐" if not is_instance_valid(boss) else "달아남")))
		if host.map.id != map_id0:
			how += "(맵이 %s로 바뀜)" % host.map.id
		print("BOSSFIGHT|%s|%.1f|%d|%d|%s|최저 %d/%d|국면%s" % [boss_id, t, int(host.combat.pc.hp), stims0 - int(host.st.items.get("I-001", 0)), how, int(hp_min), int(host.combat.pc.max_hp), phases])
		get_tree().create_timer(0.3).timeout.connect(get_tree().quit)
		return
	if alive.is_empty():
		host.combat.bot = {}
		return
	alive.sort_custom(func(a, b): return a.loco.logical.distance_to(me) < b.loco.logical.distance_to(me))
	var tgt: Enemy = alive[0]
	var d := tgt.loco.logical.distance_to(me)
	if OS.get_environment("BF_LOG") != "" and int(t * 2.0) != int((t - dt) * 2.0):
		print("  %.1f초 남은 %d · 가까운 %s %.1f칸 hp%d 상태 %d · 나 hp%d · 적 칸 %s 나 칸 %s 층 %d/%d" % [t, alive.size(), str(tgt.get_meta("enemy_id", "")), d / 32.0, int(tgt.cmb.hp), int(tgt.brain.state), int(host.combat.pc.hp), str(host.map.tile_of(tgt.loco.logical)), str(host.map.tile_of(me)), tgt.floor_id, host.player.floor_id])
	if is_instance_valid(boss) and not boss.cmb.dead and phases.count("|") < int(boss.one_phase):
		phases += "|%d@%.1f%s" % [boss.one_phase, t, "(다리)" if boss.cmb.crippled.has("leg") else ""]
	# 물러나며 쏜다(가까우면 뒷걸음, 멀면 다가감) — 사람처럼 거리를 벌리려 든다. 싸움터 밖으로는 물러서지 않는다(가장자리면 옆걸음)
	if OS.get_environment("BF_STAND") != "":
		host.input_fn = func() -> Vector2: return Vector2.ZERO           # 제자리에서 쏘는 사람(뒷걸음 없이 — 받는 피해의 위쪽 끝)
	elif d < 3.0 * 32.0:
		var back := (me - tgt.loco.logical).normalized()
		var nxt: Vector2i = host.map.tile_of(me + back * 40.0) - field
		if nxt.x < 0 or nxt.y < 0 or nxt.x >= 12 or nxt.y >= 12:
			back = back.orthogonal() if (Vector2(field) * 32.0 + Vector2(192, 192) - me).dot(back.orthogonal()) > 0.0 else -back.orthogonal()
		host.input_fn = func() -> Vector2: return back
	elif d > 7.0 * 32.0:
		host.input_fn = func() -> Vector2: return (tgt.loco.logical - me).normalized()
	else:
		host.input_fn = func() -> Vector2: return Vector2.ZERO
	host.combat.bot = {"aim": tgt.loco.logical + Vector2(0, -10), "fire": true, "aimed": true,
		"reload": host.combat.mags.get(host.combat.weapon_id, 1) == 0, "stim": host.combat.pc.hp < host.combat.pc.max_hp * 0.4 and not host.combat.healing()}


## J-10 실전 판: 맵의 적 모두(천장 어미 · 잔바퀴 떼 · 큰바퀴 · 낙하 알 · 부화 · 배 터짐)를 교전으로 센다.
## 봇은 서서 걸어 들어간다(웅크리지 않는 보통 사람 — 알 낙하가 일어난다). 깬 적이 없으면 어미 밑으로 길을 따라 걷고, 있으면 가까운 것부터 쏜다.
## 교전 시간 = 첫 알 낙하부터 마지막 적이 쓰러질 때까지(필드 보스 '교전 전체' — SD-25 §6).
func _live_step(me: Vector2) -> void:
	if is_instance_valid(boss):
		n_chg = boss.charges
		n_stag = boss.staggers
	var hp_now: float = host.combat.pc.hp
	if hp_prev >= 0.0 and hp_now < hp_prev:
		taken += hp_prev - hp_now
	hp_prev = hp_now
	if t_drop < 0.0 and uq != null and uq._drops > 0:
		t_drop = t
	if t_wake < 0.0 and is_instance_valid(boss) and not boss.asleep:
		t_wake = t
		phases += "|깸@%.1f" % t
	if uq != null and uq._burst and not phases.contains("터짐"):
		phases += "|터짐@%.1f" % t
	if is_instance_valid(boss) and boss.cmb.dead:
		boss_dead = true
	var alive: Array = host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy" and e.loco.logical.distance_to(me) < 40.0 * 32.0)
	var awake: Array = alive.filter(func(e): return not e.asleep)
	if alive.is_empty() or t > LIMIT or host.combat.pc.dead or host.map.id != map_id0:
		done = true
		var how := "시간 초과" if t > LIMIT else ("주인공 쓰러짐" if host.combat.pc.dead else ("맵이 %s로 바뀜" % host.map.id if host.map.id != map_id0 else ("처치" if boss_dead else "어미 없음")))
		var t0 := t_drop if t_drop >= 0.0 else (t_wake if t_wake >= 0.0 else 0.0)
		print("BOSSFIGHT|%s@J-10|%.1f|%d|%d|%s|최저 %d/%d|국면%s|낙하부터 %.1f초|돌진 %d · 벽 %d|받은 피해 %d%%" % [boss_id, t - t0, int(host.combat.pc.hp), stims0 - int(host.st.items.get("I-001", 0)), how, int(hp_min), int(host.combat.pc.max_hp), phases, t - t0,
			n_chg, n_stag, int(round(taken / maxf(1.0, host.combat.pc.max_hp) * 100.0))])
		get_tree().create_timer(0.3).timeout.connect(get_tree().quit)
		return
	if awake.is_empty() or (is_instance_valid(boss) and boss.asleep and awake.size() == 0):   # 아직 아무도 안 깸 — 어미 쪽으로 걸어 들어가되 DROP_R − 1칸에서 선다(① 알 낙하를 끝까지 본다 — 조율사 도구 고침 1)
		host.combat.bot = {}
		var goal: Vector2 = boss.loco.logical if is_instance_valid(boss) else alive[0].loco.logical
		if me.distance_to(goal) > (UqR02.DROP_R - 1.0) * 32.0:
			host.input_fn = _walk_to(me, goal)
		else:
			host.input_fn = func() -> Vector2: return Vector2.ZERO
		return
	if is_instance_valid(boss) and boss.asleep:                          # 천장 어미는 아직 겨누지 않는다(깬 큰바퀴 · 떼만)
		awake = awake.filter(func(e): return e != boss)
		if awake.is_empty():
			host.combat.bot = {}
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			return
	awake.sort_custom(func(a, b): return a.loco.logical.distance_to(me) < b.loco.logical.distance_to(me))
	var tgt: Enemy = awake[0]
	var d := tgt.loco.logical.distance_to(me)
	if OS.get_environment("BF_LOG") != "" and int(t * 2.0) != int((t - dt_last) * 2.0):
		print("  %.1f초 깬 %d/%d · 가까운 %s %.1f칸 hp%d · 나 hp%d 칸 %s" % [t, awake.size(), alive.size(), str(tgt.get_meta("enemy_id", "")), d / 32.0, int(tgt.cmb.hp), int(host.combat.pc.hp), str(host.map.tile_of(me))])
	if OS.get_environment("BF_STAND") != "":
		host.input_fn = _walk_to(me, tgt.loco.logical) if d > 7.0 * 32.0 else func() -> Vector2: return Vector2.ZERO   # 제자리 판도 사거리까지는 걸어 들어간다
	elif d < 3.0 * 32.0:
		var back := (me - tgt.loco.logical).normalized()
		if host.map.is_solid(host.map.tile_of(me + back * 40.0)):
			back = back.orthogonal() if not host.map.is_solid(host.map.tile_of(me + back.orthogonal() * 40.0)) else -back.orthogonal()
		host.input_fn = func() -> Vector2: return back
	elif d > 7.0 * 32.0:
		host.input_fn = _walk_to(me, tgt.loco.logical)
	else:
		host.input_fn = func() -> Vector2: return Vector2.ZERO
	host.combat.bot = {"aim": tgt.loco.logical + Vector2(0, -10), "fire": true, "aimed": true,
		"reload": host.combat.mags.get(host.combat.weapon_id, 1) == 0, "stim": host.combat.pc.hp < host.combat.pc.max_hp * 0.4 and not host.combat.healing()}


var dt_last := 0.0
var n_chg := 0
var n_stag := 0
var taken := 0.0                             ## 받은 피해 합(스팀팩으로 찬 몫은 빼지 않는다 — SD-25 B4 '받은 피해')
var hp_prev := -1.0


var _wpath := PackedVector2Array()
var _wgoal := Vector2.INF
var _wt := -1.0


## 높은 턱 · 사다리 · 층을 넘는 길(지하시장 봇 _walk와 같은 NpcRoutine) — 0.5초마다 다시 찾는다
func _walk_to(me: Vector2, goal: Vector2) -> Callable:
	var p := host.player.loco.render
	if _wpath.is_empty() or goal.distance_to(_wgoal) > 48.0 or t - _wt > 0.5:
		_wpath = NpcRoutine.with_start(host.map, p, goal, host.player.floor_id)
		_wgoal = goal
		_wt = t
	while _wpath.size() > 0 and (NpcRoutine.arrived(p, _wpath[0]) or (_wpath.size() > 1 and p.distance_to(_wpath[1]) <= _wpath[0].distance_to(_wpath[1]) + 2.0)):
		_wpath.remove_at(0)
	var dir := (goal - p).normalized() if _wpath.is_empty() else NpcRoutine.step_dir(p, _wpath[0])
	return func() -> Vector2: return dir
