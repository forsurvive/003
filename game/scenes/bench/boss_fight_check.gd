## 필드 보스 교전 시간 실측(1-13 D-380, SD-11 §10.3 기준 35~60초 · SD-25 B3): 관악산 비탈(월드) 빈 땅에 보스와 호위를 세우고,
## 그 레벨의 표준 무기(10mm 권총 W-002 — SD-25 표준 무기)를 든 주인공을 싸움 봇으로 돌린다. 보스가 쓰러지거나 달아나고 호위가 다 정리되면
## 'BOSSFIGHT|보스|초|주인공 HP|스팀팩|끝' 한 줄. 사람 손이 아니라 '늘 맞히려 드는 봇'이라 실제보다 조금 빠르다(추세 기록).
## 실행: godot --headless --path game res://scenes/bench/boss_fight_check.tscn -- CR-500 [씨앗]
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


func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	boss_id = a[0] if a.size() > 0 else "CR-500"
	seed(int(a[1]) if a.size() > 1 else 7)
	host = InteriorHost.new()
	add_child(host)
	var st := host.st
	for q in ["MQ-P1", "MQ-P2", "MQ-P3", "MQ-P4", "MQ-101"]:
		st.quests.set_stage(q, 100)
	st.vars.set_v("V_ACT", 1)
	st.vars.set_v("GAME_DAY", 4)
	var lv: int = SETUP[boss_id]["lv"]
	st.vars.set_v("PC_XP", Perks.xp_at(lv) + 10)
	st.call_fn("give", ["W-002"])
	st.call_fn("give", ["10mm 탄", 400])
	st.call_fn("give", ["I-001", stims0])
	host.body = "adult"
	host.pipboy_ok = true
	host.hud_on = true                                                    # HUD가 꺼져 있으면 연출 중으로 보고 적이 멈춘다
	host.date_text = "2277. 10. 27.  13:00"
	var mid := a[2] if a.size() > 2 else "J-02"                           # 싸울 맵(기본 지하시장 넓은 마당 — 트인 14×14칸을 찾는다)
	var mark := a[3] if a.size() > 3 else "from_J-01"
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
	var field := _open_field(host.map.tile_of(host.player.loco.logical), 12)   # 다 트인 14×14칸(담 · 난간 · 높이 단 없음 — 필드 보스 마당과 같은 조건)
	print("  싸움터 %s(맵 %s)" % [str(field), host.map.id])
	host.player.loco.place(Vector2(field + Vector2i(6, 10)) * 32.0 + Vector2(16, 16))
	host.player.position = host.player.loco.render
	var at := Vector2(field + Vector2i(6, 1)) * 32.0 + Vector2(16, 16)
	boss = host.combat.spawn(boss_id, at, host.map, host.st, {"lv": lv})
	boss.brain.gauge = 100.0
	boss.brain.state = AIBrain.S.COMBAT
	boss.set_meta("dbg", true)
	boss.brain.home = host.player.loco.logical                          # 세운 자리에 묶이지 않게(집 반경 밖으로 쫓아오지 않는다)
	print("  길 시험: %d점 · 보스 층 %d · 주인공 층 %d" % [host.combat.nav.path(boss.loco.logical, host.player.loco.logical, boss.floor_id, host.player.floor_id).size(), boss.floor_id, host.player.floor_id])
	var k := 0
	for ad in SETUP[boss_id]["adds"]:
		for i in int(ad[1]):
			k += 1
			var e := host.combat.spawn(str(ad[0]), _free(at + Vector2((k % 4 - 1.5) * 40.0, (k / 4) * 40.0)), host.map, host.st, {"lv": lv})
			e.brain.gauge = 100.0
			e.brain.state = AIBrain.S.COMBAT
			e.brain.home = host.player.loco.logical


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
	var me: Vector2 = host.player.loco.logical
	var alive := host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy" and e.loco.logical.distance_to(me) < 30.0 * 32.0)
	var boss_out := not is_instance_valid(boss) or boss.cmb.dead or boss.loco.logical.distance_to(me) > 30.0 * 32.0
	if (alive.is_empty() and boss_out) or t > LIMIT or host.combat.pc.dead:
		done = true
		var how := "시간 초과" if t > LIMIT else ("주인공 쓰러짐" if host.combat.pc.dead else ("처치" if not is_instance_valid(boss) or boss.cmb.dead else "달아남"))
		print("BOSSFIGHT|%s|%.1f|%d|%d|%s|최저 %d/%d" % [boss_id, t, int(host.combat.pc.hp), stims0 - int(host.st.items.get("I-001", 0)), how, int(hp_min), int(host.combat.pc.max_hp)])
		get_tree().create_timer(0.3).timeout.connect(get_tree().quit)
		return
	if alive.is_empty():
		host.combat.bot = {}
		return
	alive.sort_custom(func(a, b): return a.loco.logical.distance_to(me) < b.loco.logical.distance_to(me))
	var tgt: Enemy = alive[0]
	var d := tgt.loco.logical.distance_to(me)
	if OS.get_environment("BF_LOG") != "" and int(t * 2.0) != int((t - dt) * 2.0) and (t < 1.0 or absf(t - 6.0) < 0.3):
		for e in alive:
			var tg = host.combat._target_for(e)
			e._tactics(tg, host.combat.nav)
			var p0: Vector2 = e.loco.logical
			for k2 in 10:
				e.move(e.steer(Vector2(0, 1)), 1.0 / 60.0)
			print("    손으로 걷기 10프레임: %.1fpx · 속도 %s · fixed %s" % [e.loco.logical.distance_to(p0), str(e.row.get("speed")), e.fixed])
			print("    손으로 전술 → 길 %d · 의도 %s · 스타일 %s · 둥지 %s · 이끔 %s" % [e._path.size(), str(e._intent), e.style, e.nest, e.led])
			print("    표적 %s 칸 %s 층 %d · 길 %d" % [tg.team, str(host.map.tile_of(tg.pos())), tg.fl(), host.combat.nav.path(e.loco.logical, tg.pos(), e.floor_id, tg.fl()).size()])
			print("  적 %s 목표 %s 토큰 %s 근접토큰 %s 길 %d 자세 %s 잠 %s 묶임 %s 위치 %s 집 %s" % [str(e.get_meta("enemy_id", "")), str(e._intent.get("goal", "")), e.has_token, e.has_mtoken, e._path.size(), e.stance, e.asleep, e.cmb.held(), str(host.map.tile_of(e.loco.logical)), str(host.map.tile_of(e.brain.home))])
	if OS.get_environment("BF_LOG") != "" and int(t * 2.0) != int((t - dt) * 2.0):
		print("  %.1f초 남은 %d · 가까운 %s %.1f칸 hp%d 상태 %d · 나 hp%d · 적 칸 %s 나 칸 %s 층 %d/%d" % [t, alive.size(), str(tgt.get_meta("enemy_id", "")), d / 32.0, int(tgt.cmb.hp), int(tgt.brain.state), int(host.combat.pc.hp), str(host.map.tile_of(tgt.loco.logical)), str(host.map.tile_of(me)), tgt.floor_id, host.player.floor_id])
	# 물러나며 쏜다(가까우면 뒷걸음, 멀면 다가감) — 사람처럼 거리를 벌리려 든다
	if d < 3.0 * 32.0:
		host.input_fn = func() -> Vector2: return (me - tgt.loco.logical).normalized()
	elif d > 7.0 * 32.0:
		host.input_fn = func() -> Vector2: return (tgt.loco.logical - me).normalized()
	else:
		host.input_fn = func() -> Vector2: return Vector2.ZERO
	host.combat.bot = {"aim": tgt.loco.logical + Vector2(0, -10), "fire": true, "aimed": true,
		"reload": host.combat.mags.get(host.combat.weapon_id, 1) == 0, "stim": host.combat.pc.hp < host.combat.pc.max_hp * 0.4}
