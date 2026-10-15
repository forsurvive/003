## MQ-106 「첫 번째 추적자」(단계 1-7, SD-03a §8.6 · §4.1 막 전환 · §6.5 수배 · §6.7 생포 계엄군 판 · §12.4 '그 자리에 있어라' ·
## SD-09d L-R11-01 C05 귀빈실). 원고 script/act1/MQ-106.txt가 부르는 사건(@cmd vb …)과 맵 사건을 맡는다.
## 발동: K_CODE가 선 뒤 실내에서 바깥(월드)으로 나온 순간(V_ACT 1 이상). 무전(MQ-106_RADIO) → 18초 뒤 버티버드가 화면 밖에서 날아와(6초)
##   주인공 가까이 탁 트인 땅에 내려앉는다(6초) = 30초. 기다리는 동안 건물에 들어가면 '숨음'으로 센다.
## 착지: 문 앞에 육지환(지휘만), 윤석진 + 인도 분대 둘(보병 6) + 기갑 계엄병이 내려 반원으로 선다 → 확성기(MQ-106_LAND).
## 해법(행동): 싸움(vb fight — 생포 규칙: 쓰러지면 귀빈실 · 윤석진은 HP 40%에서 기체로 물러남 · 보병이 모두 쓰러지면 철수) ·
##   숨음(vb run 또는 교전 중 시야 밖 60초 · 건물 안에 60초) · 말(화술 보통 · 여의도 인증 단말 기록) · 걸어 들어감(vb walk — 무기를 맡기고 탄다).
## 하도윤(V_DOYUN 1): 화물칸 철창(문 앞에 서서 말을 건다) [자물쇠 따기 50] · [힘 8] → V_DOYUN 2 · 카르마 +100(봉천으로 혼자 간다).
## 귀빈실 CG-05(MQ106_CUSTODY 1 걸어 들어감 · 2 생포 · 3 새벽인력 인계): 남궁혁 면담(K_SIGNER · K_LINEAGE) → 사흘째 아침 관악 산자락(X-S07)에
##   버티버드가 내려 준다. 생포·인계면 소지품을 압수해 청계산 북사면 환기탑(L-R11-02) '압수품 보관함'에 둔다. 걸어 들어가면 무기만 맡겼다 돌려받는다.
## 결과 MQ106_RESULT 1 싸움(비상 −15 · 수배 +10 · 사살 1명당 +2) · 2 숨음(0) · 3 말(+5) · 4 걸어 들어감(+15 · 사흘 등급 1 · 정착 −3) · 5 생포(+5).
##   모두 XP 300 · 수배 max(현재, 30)(4는 사흘 뒤). 판도 R01: 쫓아냄(1) −비상 10 · 그 밖 +비상 10(관악 검문소 상설화) → PD_R01_BJ.
## 막 전환(§4.1): K_CODE · MQ-106 끝 → V_ACT 2: 자동 저장 요청 → 막 제목 카드 「2막 강」 → 공보방송 → 새 막 목표.
class_name Mq106
extends Node

signal act_up(act: int)                              ## 막이 올랐다 — 진행(prologue)이 자동 저장한다

const RADIO_SECS := 18.0
const HIDE_SECS := 60.0
const SEEN_TILES := 22.0
const SQUAD := ["CR-403", "CR-402", "CR-402", "CR-403", "CR-402", "CR-401"]   ## 인도 분대 둘(분대장 + 분대원 둘씩, SD-14 §9.2.1)
const SHEETS := {"CR-401": "en_cr401_loco", "CR-402": "en_cr402_loco", "CR-403": "en_cr403_loco", "CR-405": "en_cr405_loco"}
var host: InteriorHost
var st: StoryState
var log_on := false
var state := ""                                      ## "" · radio · fly · stand · fight · walk · leave · hiding · custody
var vb: Vertibird
var _radio := 0.0
var _tries := 0
var _hide := 0.0
var _inside_t := 0.0
var _hint_t := 0.0
var _foes: Array = []                                ## 교전 중 분대(Enemy)
var _yoon: Enemy
var _pa: Enemy
var _men: Array = []                                 ## 대치 중 선 사람(연출 인물 ID)
var _fake: Array = []                                ## host.npcs에 넣은 말 거는 자리(육지환 · 하도윤)
var _was_inside := false
var _seen_kills := 0


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["vb"] = _cmd
	host.map_entered.connect(_on_map)
	host.capture_hooks["BJ"] = _captured
	host.capture_hooks["BJ_HANDOVER"] = _handover
	host.combat.enemy_killed.connect(_on_killed)
	host.day_tick.connect(_on_day)
	_check_resume.call_deferred()


var _resume := false


## 불러온 판(저장을 다 펼친 뒤): 귀빈실 구간이면 그대로, 사건 한가운데(저장은 막지만 중단 저장 등)면 무전부터 다시
func _check_resume() -> void:
	_was_inside = host.map != null and not (host.map is WorldMap)
	if v("MQ106_CUSTODY") > 0:
		state = "custody"
	elif st.quests.stage("MQ-106") == 10 and state == "":
		_resume = true
		if host.map is WorldMap:
			_resume = false
			_begin()


## 출두 확인 사흘이 끝났다: 정식 공고(등급 2)
func _on_day(_day: int) -> void:
	if v("WANTED_HOLD") > 0 and v("GAME_DAY") >= v("WANTED_HOLD"):
		st.vars.set_v("WANTED_HOLD", 0)
		Wanted.set_value(st, maxi(Wanted.value(st), 30))


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[MQ-106] " + s)


## 진행 중(저장 불가 · 인카운터 멈춤): 무전부터 버티버드가 떠날 때까지
func active() -> bool:
	return state in ["radio", "fly", "stand", "fight", "walk", "leave"]


# ---------------------------------------------------------------- 발동
func _due() -> bool:
	return v("V_ACT") >= 1 and v("K_CODE") >= 1 and st.quests.stage("MQ-106") == 0 and v("MQ106_CUSTODY") == 0


func _on_map(id: String) -> void:
	var inside := not (host.map is WorldMap)
	if state == "" and not inside and (_was_inside or _resume) and (_due() or _resume) and not host.zone_walk:
		_resume = false
		_begin()
	elif active() and inside and state != "walk":
		_went_inside()
	elif state == "hiding" and not inside:
		_came_out()
	if not inside or id == "CG-05":
		_act_check()
	_was_inside = inside


func _begin() -> void:
	state = "radio"
	_radio = RADIO_SECS
	_tries = 0
	host.story_hold = true
	st.quests.set_stage("MQ-106", 10)
	host.play_scene.call_deferred("MQ-106_RADIO")
	_log("발동(무전)")


func _process(dt: float) -> void:
	if state == "":
		return
	if state == "hiding":
		_inside_t += dt
		return
	if state == "radio":
		if host.box.active or host.ev.busy() or host.busy:
			return
		_radio -= dt
		if _radio <= 0.0:
			_fly()
	elif state == "fight":
		_fight_tick(dt)


# ---------------------------------------------------------------- 날아옴 · 착지
## 착지 자리: 주인공 둘레 6~16칸, 9×6칸이 모두 같은 높이의 걷는 땅, 둘레 5칸에 인물 없음, 주인공에게서 보이는 곳
func site(wide := false) -> Vector2:
	var m = host.map
	var p: Vector2i = m.tile_of(host.player.loco.logical)
	var lv: int = m.level_at(p)
	for r in range(6, 26 if wide else 17):
		var ring: Array = []
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) == r:
					ring.append(p + Vector2i(dx, dy))
		ring.sort_custom(func(a, b): return absi(a.y - p.y) < absi(b.y - p.y))   # 같은 거리면 좌우(화면 안 — 세로는 5칸 반만 보인다)
		for c in ring:
			if _clear(c, lv) and m.line_of_sight(host.player.loco.logical, Vector2(c.x * 32 + 16, c.y * 32 + 16)):
				return Vector2(c.x * 32 + 16, c.y * 32 + 16)
	return Vector2.INF


func _clear(c: Vector2i, lv: int) -> bool:
	var m = host.map
	for dy in range(-3, 3):
		for dx in range(-4, 5):
			var t := c + Vector2i(dx, dy)
			if m.is_solid(t) or m.level_at(t) != lv:
				return false
	var cp := Vector2(c.x * 32 + 16, c.y * 32 + 16)
	for n in host.npcs:
		if is_instance_valid(n["actor"]) and n["actor"].loco.logical.distance_to(cp) < 5.0 * 32.0:
			return false
	return true


func _fly() -> void:
	var at := site(_tries >= 3)
	if at == Vector2.INF:
		_tries += 1
		_radio = 3.0
		if _tries > 6:                                                   # 내려앉을 땅이 없다(좁은 골목·지하상가 입구): 무전만으로 끝 — 말로 돌려보낸 것과 같다
			host.hint("회전음이 머리 위를 맴돌다 멀어진다. 내려앉을 땅이 없었다.", 5.0)
			_finish(2)
		return
	vb = Vertibird.new().setup(host.map, host.cam, at)
	host.map.objects.add_child(vb)
	vb.landed.connect(_on_landed)
	vb.arrive()
	state = "fly"
	_mark("vb_mid", (host.player.loco.logical + at) / 2.0)
	get_tree().create_timer(Vertibird.FLY_SECS).timeout.connect(func() -> void:   # 내려오기 시작하면 카메라가 주인공과 착지점 사이로
		if state == "fly" and not host.ev.busy():
			host.ev.run("cam", ["vb_mid", "15"], func() -> void: pass))
	host.hint("버티버드가 내려온다.", 4.0)
	_log("날아옴 %s" % str(host.map.tile_of(at)))


func _mark(name: String, p: Vector2, dir := "S") -> void:
	var t: Vector2i = host.map.tile_of(p)
	host.map.marks[name] = [t.x, t.y, dir]


## 걸을 수 있는 가까운 칸(막혔으면 둘레에서)
func _free_near(p: Vector2) -> Vector2:
	var m = host.map
	var c: Vector2i = m.tile_of(p)
	for r in 4:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var t := c + Vector2i(dx, dy)
				if not m.is_solid(t):
					return Vector2(t.x * 32 + 16, t.y * 32 + 16)
	return p


var land_check := false                             ## 착지 순간 기체 밑 칸이 막혔나(봇 확인)


func _on_landed() -> void:
	state = "stand"
	land_check = host.map.is_solid(host.map.tile_of(vb.land_at))
	vb.door_open = true
	vb.grille = v("V_DOYUN") == 1
	var door := _free_near(vb.door_ground())
	_mark("vb_door", door, "N")
	var me: Vector2 = host.player.loco.logical
	var dir := (me - door).normalized() if me.distance_to(door) > 1.0 else Vector2.DOWN
	# 육지환: 문 앞(오른쪽 반 칸) — 말을 걸 수 있는 자리
	host.ev._show_actor("C-004", Vector2(door.x + 34.0, vb.land_at.y + 8.0), "S")   # 문 옆 발판(기체 칸 안) — 길도 총알도 막지 않는다
	_add_fake("C-004", false)
	if v("V_DOYUN") == 1:                                                # 화물칸 철창 안 하도윤(기체 앞에 그린다)
		host.ev._show_actor("C-002", vb.door_seat(), "S")
		if host.ev.actors.has("C-002"):
			host.ev.actors["C-002"].z_index = 1
			_add_fake("C-002", false)
	# 분대: 문에서 내려 주인공 쪽으로 반원(반지름 3.5칸, ±70°). 윤석진은 가운데 앞, 기갑 계엄병은 문 왼쪽
	_men.clear()
	var ids: Array = SQUAD.duplicate()
	for i in ids.size():
		var ang := deg_to_rad(-70.0 + 140.0 * float(i) / float(ids.size() - 1))
		var to := door + dir.rotated(ang) * 3.5 * 32.0
		_spawn_man("BJ%d" % i, str(ids[i]), door, to)
	_spawn_man("C-031", "CR-403", door, door + dir * 2.4 * 32.0)
	_spawn_man("BJPA", "CR-405", door, door + Vector2(-56, 12))
	host.ev.run("wait", ["20"], func() -> void:
		if state == "stand":
			for id in _men:
				if host.ev.actors.has(id):
					host.ev.actors[id].loco.facing = Locomotion.snap8(host.player.loco.logical - host.ev.actors[id].loco.logical)
					host.ev.actors[id]._show()
			host.play_scene("MQ-106_LAND"))
	_log("착지 · 대치")


func _spawn_man(id: String, cr: String, from: Vector2, to: Vector2) -> void:
	var sheet := str(SHEETS.get(cr, "en_cr401_loco"))
	if id == "C-031":
		sheet = str(host.ev.cast_sheets.get("C-031", sheet))
	host.ev._show_actor(id, from, "S", sheet)
	if not host.ev.actors.has(id):
		return
	host.ev.actors[id].set_meta("cr", cr)
	_men.append(id)
	var dest := _free_near(to)
	_mark("vb_" + id, dest)
	host.ev.run("go", [id, "vb_" + id, "walk"], func() -> void: pass)


## 말을 거는 자리(host.npcs에 넣는다 — 대화는 원고의 @npc 장면)
func _add_fake(id: String, block := true) -> void:
	var a: Actor = host.ev.actors.get(id)
	if a == null:
		return
	var e := {"id": id, "actor": a, "routine": null, "bark": "", "idx": -1}
	host.npcs.append(e)
	_fake.append(e)
	if block:
		host.map.blockers.append(a)


func _clear_fake() -> void:
	for e in _fake:
		host.npcs.erase(e)
		host.map.blockers.erase(e["actor"])
	_fake.clear()


# ---------------------------------------------------------------- 원고 사건(@cmd vb …)
func _cmd(a: Array, done: Callable) -> void:
	host.ev.cam_locked = false                                          # 대치가 끝나면 카메라는 다시 주인공을 따른다
	match str(a[0]):
		"talk":
			_withdraw(3)
		"walk":
			_walk_in()
		"fight", "run":
			_engage(str(a[0]) == "fight")
		"pick":
			if Lockpick.can_try(50, st.skill("LOCKPICK")):
				host.open_lock(50, "pad", _free_doyun)
			else:
				host.hint("자물쇠가 단단하다. [자물쇠 따기 50 필요]", 4.0)
		"free":
			_free_doyun()
		"interview":                                                    # 남궁혁 면담(K_SIGNER · K_LINEAGE, §8.6 걸어 들어간다)
			st.vars.set_v("MQ106_TALKED", 1)
			st.vars.set_v("K_SIGNER", 1)
			st.vars.set_v("K_LINEAGE", 1)
		"release":
			_release.call_deferred()
	done.call()


## 대치 → 교전(싸움 · 달아남): 선 사람을 생포 분대(Enemy)로 바꿔 세운다
func _engage(_attack: bool) -> void:
	state = "fight"
	_hide = 0.0
	_hint_t = 0.0
	var lv := host.level()
	for id in _men:
		var a: Actor = host.ev.actors.get(id)
		if a == null or not is_instance_valid(a):
			continue
		var cr := str(a.get_meta("cr", "CR-402"))
		var pos: Vector2 = a.loco.logical
		var opts := {"lv": clampi(lv + 2, 3, 8)}
		if cr == "CR-405":
			opts = {"lv": clampi(lv + 4, 5, 15), "stance": "hold", "dir": "S"}   # 기갑 계엄병은 기체 곁을 지킨다
		elif id == "C-031":
			opts = {"lv": clampi(lv + 3, 4, 12), "who": "C-031"}
		host.ev.actors.erase(id)
		host.map.remove_actor(a)
		a.queue_free()
		var e := host.combat.spawn(cr, pos, host.map, st, opts)
		e.set_meta("capture", "BJ")
		e.brain.gauge = 100.0
		if id == "C-031":
			_yoon = e
			e.cmb.hp_floor = e.cmb.max_hp * 0.39                       # 이 퀘스트에서는 죽지 않는다(40%에서 물러남)
		elif cr == "CR-405":
			_pa = e
		else:
			_foes.append(e)
	_men.clear()
	host.hint("계엄군이 생포하러 온다 — 다리만 노린다. 시야에서 1분 벗어나면 물러난다.", 6.0)
	_log("교전(%d)" % _foes.size())


func _fight_tick(dt: float) -> void:
	if _yoon != null and is_instance_valid(_yoon) and not _yoon.cmb.dead and _yoon.cmb.hp <= _yoon.cmb.max_hp * 0.4 + 0.5:
		_yoon_retreat()
	var alive := _foes.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
	if alive.is_empty():
		_withdraw(1)
		return
	var me: Vector2 = host.player.loco.logical
	var seen := false
	for e in alive + ([_yoon] if _yoon != null and is_instance_valid(_yoon) and not _yoon.cmb.dead else []):
		if e.loco.logical.distance_to(me) <= SEEN_TILES * 32.0 and host.map.line_of_sight(e.loco.logical, me):
			seen = true
			break
	_hide = 0.0 if seen else _hide + dt
	_hint_t += dt
	if not seen and _hide >= 20.0 and _hint_t >= 15.0:
		_hint_t = 0.0
		host.hint("수색대가 주변을 뒤진다… (%d초)" % int(_hide), 3.0)
	if _hide >= HIDE_SECS:
		_withdraw(2)


func _yoon_retreat() -> void:
	var p: Vector2 = _yoon.loco.logical
	host.combat.drop_enemy(_yoon)
	_yoon = null
	host.hint("윤석진: 대위 부상! 기체로 물러난다! 엄호!", 4.0)
	host.ev._show_actor("C-031", p, "N", str(host.ev.cast_sheets.get("C-031", "en_cr403_loco")))
	_walk_off("C-031", "vb_door", "run")
	_log("윤석진 철수")


func _on_killed(eid: String, _alive: int) -> void:
	if state != "fight":
		return
	for e in _foes:
		if is_instance_valid(e) and e.cmb.dead and e.cmb.killed_lethal and not e.has_meta("counted"):
			e.set_meta("counted", true)
			_seen_kills += 1
			st.call_fn("wanted", [2, "kill"])                            # 계엄군 사살(SD-03a §6.5 +2, 하루 +10)
	if eid == "CR-405":
		pass


## 하도윤 구출(화물칸 철창)
func _free_doyun() -> void:
	if v("V_DOYUN") != 1:
		return
	st.vars.set_v("V_DOYUN", 2)
	st.call_fn("karma", [100])
	if vb != null and is_instance_valid(vb):
		vb.grille = false
	for e in _fake.duplicate():
		if e["id"] == "C-002":
			host.npcs.erase(e)
			_fake.erase(e)
	host.play_scene.call_deferred("MQ-106_DOYUN_FREE")
	var a: Actor = host.ev.actors.get("C-002")
	if a != null:
		a.z_index = 0
		a.loco.place(_free_near(vb.door_ground() + Vector2(0, 32)) if vb != null and is_instance_valid(vb) else a.loco.logical)
		var away := a.loco.logical + (a.loco.logical - host.player.loco.logical).normalized().rotated(1.2) * 12.0 * 32.0
		_mark("vb_doyun_away", _free_near(away))
		_wait_box(func() -> void: _walk_off("C-002", "vb_doyun_away", "run"))
	_log("하도윤 구출")


## 철수: 선 사람은 기체로 걸어 들어가고(교전이면 서 있거나 기절한 병사를 싣고) 버티버드가 뜬다 → 결과
func _withdraw(result: int) -> void:
	if state in ["leave", "walk", ""]:
		return
	state = "leave"
	st.vars.set_v("MQ106_RESULT", result)
	_clear_fake()
	for e in _foes + [_pa, _yoon]:
		if e != null and is_instance_valid(e) and (not e.cmb.dead or e.cmb.ko):
			var p: Vector2 = e.loco.logical
			var cr := str(e.get_meta("enemy_id", "CR-402"))
			host.combat.drop_enemy(e)                                     # 서 있는 병사 · 기절한 병사는 기체에 오른다(죽은 병사는 남는다)
			var id := "BJR%d" % _men.size()
			host.ev._show_actor(id, p, "N", str(SHEETS.get(cr, "en_cr401_loco")))
			if host.ev.actors.has(id):
				_men.append(id)
	_foes.clear()
	_pa = null
	_yoon = null
	_log("철수(결과 %d)" % result)
	if vb == null or not is_instance_valid(vb):
		_finish(result)
		return
	_wait_box(func() -> void:
		var names: Array = _men + ["C-031"]
		_men.clear()
		if host.ev.actors.has("C-004"):                                     # 육지환은 문 옆에서 바로 기체에 오른다
			host.ev.run("hide", ["C-004"], func() -> void: pass)
		for id in names:
			_walk_off(id, "vb_door")
		_lift_when_gone(names, 0.0, result))


func _lift_when_gone(names: Array, t: float, result: int) -> void:
	var left := names.filter(func(id): return host.ev.actors.has(id))
	if not left.is_empty() and t < 9.0:
		get_tree().create_timer(0.3).timeout.connect(_lift_when_gone.bind(names, t + 0.3, result))
		return
	if vb != null and is_instance_valid(vb):
		vb.leave()
	if result in [1, 3]:
		host.play_scene("MQ-106_GONE")
	else:
		host.hint("회전음이 멀어진다. 수색대가 물러났다.", 5.0)
	_finish(result)


## 연출 인물을 표지까지 걷게 하고(기다리지 않는 이동), 다 걸으면 숨긴다(기체에 오름)
func _walk_off(id: String, mark: String, mode := "walk", then := Callable()) -> void:
	if not host.ev.actors.has(id):
		if then.is_valid():
			then.call()
		return
	host.ev.run("go", [id, mark, mode], func() -> void: pass)
	_poll_off(id, 0.0, then)


func _poll_off(id: String, t: float, then: Callable) -> void:
	var a: Actor = host.ev.actors.get(id)
	if a == null or not is_instance_valid(a) or not host.ev.drives(a) or t > 8.0:
		if host.ev.actors.has(id):
			host.ev.run("hide", [id], func() -> void: pass)
		if then.is_valid():
			then.call()
		return
	get_tree().create_timer(0.25).timeout.connect(_poll_off.bind(id, t + 0.25, then))


## 실내로 들어갔다(무전 · 대치 · 교전 중): 버티버드와 분대는 바깥 맵과 함께 사라졌다 — 숨은 시간을 센다
func _went_inside() -> void:
	state = "hiding"
	_inside_t = 0.0
	_fake.clear()
	_men.clear()
	_foes.clear()
	_yoon = null
	_pa = null
	vb = null
	host.story_hold = false
	_log("실내로 숨음")


func _came_out() -> void:
	if _inside_t >= HIDE_SECS:
		state = "leave"
		st.vars.set_v("MQ106_RESULT", 2)
		host.hint("하늘이 조용하다. 버티버드는 이미 떠났다.", 5.0)
		_finish(2)
		return
	state = "radio"                                                     # 아직 머리 위를 맴돈다: 다시 내려앉는다
	host.story_hold = true
	_radio = 2.0
	host.hint("회전음이 아직 머리 위에 있다.", 4.0)
	_log("너무 일찍 나옴(%.0f초)" % _inside_t)


# ---------------------------------------------------------------- 걸어 들어간다 · 생포 · 귀빈실
func _walk_in() -> void:
	state = "walk"
	_clear_fake()
	host.combat.equip("", st)
	host.locked = true
	_wait_box(func() -> void: host.ev.run("move", ["PC", "vb_door", "walk"], func() -> void:
		host.ev.run("fade_out", ["black", "8"], func() -> void:
			_deposit_arms()
			st.vars.set_v("MQ106_RESULT", 4)
			host.locked = false
			if vb != null and is_instance_valid(vb):
				vb.queue_free()
			vb = null
			host.play_scene("MQ-106_RIDE")
			_wait_box(func() -> void: _custody(1)))))
	_log("걸어 들어감")


## 대화창이 닫히면 이어서
func _wait_box(then: Callable) -> void:
	if host.box.active or host.ev.busy():
		get_tree().create_timer(0.2).timeout.connect(_wait_box.bind(then))
		return
	then.call()


## 무기는 정문 보관함에(걸어 들어감 — 나올 때 돌려받는다, SD-09d C01)
func _deposit_arms() -> void:
	var box := {"items": {}, "opened": 0, "taken": 0}
	for id in st.items.keys():
		if str(id).begins_with("W-"):
			box["items"][id] = int(st.items[id])
	for id in box["items"]:
		st.items.erase(id)
	st.boxes["bj_armory"] = box


## 계엄군 생포(SD-03a §6.7 계엄군 판, 1~3막 전원 없음): 캡 30% · 소지품 압수(퀘스트 물건 빼고) → 귀빈실에서 깬다
func _captured() -> void:
	host.busy = true
	st.vars.set_v("CAPTURE_DAY", v("GAME_DAY"))
	var taken := int(floor(v("PC_CAPS") * 0.3))
	if taken > 0:
		st.call_fn("caps", [-taken])
	host.enc_live.captured()
	if st.quests.stage("MQ-106") == 10:
		st.vars.set_v("MQ106_RESULT", 5)
	host.ev.run("fade_out", ["black", "8"], func() -> void:
		host.combat.pc.dead = false
		host.combat.pc.hp = maxf(1.0, host.combat.pc.max_hp * 0.3)
		_seize()
		_custody(2))
	_log("생포")


## 새벽인력 사흘 → 계엄군 인계(SD-03a §6.7): 같은 귀빈실 구간(목걸이·수갑은 벙커에서 푼다)
func _handover() -> void:
	host.busy = true
	host.ev.run("fade_out", ["black", "10"], func() -> void:
		st.vars.set_v("SB_CUFF", 0)
		st.vars.set_v("SB_COLLAR", 0)
		st.vars.set_v("CAPTURE_BY", 2)
		host.advance_minutes(3 * 24 * 60 - 120)
		_seize()
		_custody(3))
	_log("새벽인력 인계")


func _seize() -> void:
	host.combat.equip("", st)
	var box := {"items": {}, "opened": 0, "taken": 0}
	var quest := {}
	if FileAccess.file_exists("res://data/items_quest.json"):
		var q = JSON.parse_string(FileAccess.get_file_as_string("res://data/items_quest.json"))
		quest = q.get("items", q) if q is Dictionary else {}
	for id in st.items.keys():
		var s := str(id)
		if quest.has(s) or s.begins_with("M-2"):                           # 퀘스트 물건 · 메인 물건(M-201~250)은 몸에 남는다
			continue
		box["items"][s] = int(st.items[id])
	for id in box["items"]:
		st.items.erase(id)
	var old: Dictionary = st.boxes.get("bj_seized", {})
	for id in old.get("items", {}):                                     # 지난번 압수품도 그대로 있다
		box["items"][id] = int(box["items"].get(id, 0)) + int(old["items"][id])
	st.boxes["bj_seized"] = box
	st.vars.set_v("MQ106_SEIZED", 1 if not box["items"].is_empty() else 0)
	st.places.raise("L-R11-02", PlaceLog.MARKED)


func _custody(kind: int) -> void:
	state = "custody"
	host.story_hold = false
	st.vars.set_v("MQ106_CUSTODY", kind)
	st.vars.set_v("MQ106_TALKED", 0)
	st.vars.set_v("MQ106_AT", Clock.abs_min(host.date_text))
	if kind != 3:
		host.advance_minutes(60)                                          # 청계산까지 12분 + 수속
	host.enter("CG-05", "arrive")
	host.ev.run("fade_in", ["black", "8"], func() -> void:
		host.busy = false
		host.play_scene("CG-05_ARRIVE"))
	_log("귀빈실(%d)" % kind)


## 사흘째 아침: 관악 산자락에 버티버드가 내려 준다(윤석진) → 결과
func _release() -> void:
	host.busy = true
	host.ev.run("fade_out", ["black", "10"], func() -> void:
		var spent := Clock.abs_min(host.date_text) - v("MQ106_AT")
		host.advance_minutes(maxi(60, 3 * 24 * 60 - spent))
		var kind := v("MQ106_CUSTODY")
		host.enter("X-S07", "start")
		var at := site(true)
		if at != Vector2.INF:
			vb = Vertibird.new().setup(host.map, host.cam, at)
			host.map.objects.add_child(vb)
			vb.sit()
			vb.door_open = true
			var door := _free_near(vb.door_ground())
			_mark("vb_door", door, "N")
			host.player.loco.place(_free_near(door + Vector2(0, 40)))
			host.player.position = host.player.loco.render
			host.cam.position = host.player.loco.logical.round()
			host.cam.reset_smoothing()
			host.ev._show_actor("C-031", _free_near(door + Vector2(-34, 0)), "S", str(host.ev.cast_sheets.get("C-031", "en_cr403_loco")))
		if kind == 1 and st.boxes.has("bj_armory"):                          # 맡긴 무기를 돌려받는다
			for id in st.boxes["bj_armory"]["items"]:
				st.call_fn("give", [id, int(st.boxes["bj_armory"]["items"][id])])
			st.boxes.erase("bj_armory")
		host.ev.run("fade_in", ["black", "10"], func() -> void:
			host.busy = false
			host.play_scene("MQ-106_DROP")
			_wait_box(func() -> void:
				_walk_off("C-031", "vb_door", "walk", func() -> void:
					if vb != null and is_instance_valid(vb):
						vb.leave())
				_after_custody(kind))))
	_log("내려 줌")


func _after_custody(kind: int) -> void:
	state = ""
	if kind == 3:                                                          # 새벽인력 인계(1-3 생포): 비상 +5, 결과는 MQ-106과 따로
		st.call_fn("aff", ["BJ", 5])
		st.vars.set_v("CAPTURE_BY", 0)
	st.vars.set_v("MQ106_CUSTODY", 0)
	if st.quests.stage("MQ-106") == 10:
		_finish(v("MQ106_RESULT") if v("MQ106_RESULT") > 0 else (4 if kind == 1 else 5))
	elif kind == 2:
		st.call_fn("aff", ["BJ", 5])


# ---------------------------------------------------------------- 결과 · 막 전환
func _finish(result: int) -> void:
	if st.quests.stage("MQ-106") >= 100:
		return
	state = ""
	host.story_hold = false
	st.vars.set_v("MQ106_RESULT", result)
	match result:
		1:
			st.call_fn("aff", ["BJ", -15])
			st.call_fn("wanted", [10])                                    # MQ-106 교전 +10(§6.5)
			st.vars.set_v("PD_R01_BJ", -10)                              # 수색대를 쫓아냄: 판도 R01 −비상 10(§4.5)
		2:
			st.vars.set_v("PD_R01_BJ", 10)                               # 그 밖: 관악 검문소 상설화(R01 +비상 10)
		3:
			st.call_fn("aff", ["BJ", 5])
			st.vars.set_v("PD_R01_BJ", 10)
		4:
			st.call_fn("aff", ["BJ", 15])
			st.call_fn("aff", ["JC", -3])                                 # 정착 −3(소문: 볼트 아이가 비상정부 벙커에 다녀왔다)
			st.vars.set_v("WANTED_HOLD", v("GAME_DAY") + 3)              # 공고 → '출두 확인', 사흘 등급 1(§6.5 하한 예외 1회)
			st.vars.set_v("PD_R01_BJ", 10)
		5:
			st.call_fn("aff", ["BJ", 5])
			st.vars.set_v("PD_R01_BJ", 10)
	st.call_fn("xp", [300])
	st.quests.set_stage("MQ-106", 100)
	_act_check()
	if result != 4:
		Wanted.set_value(st, maxi(Wanted.value(st), 30))                # 공보방송 정식 공고: 등급 2(§6.5)
	_log("MQ-106 완료: 결과 %d · 비상 %d · 수배 %d · 카르마 %d · 하도윤 %d · V_ACT %d" % [result, v("AFF_BJ"), v("V_WANTED"), v("V_KARMA"), v("V_DOYUN"), v("V_ACT")])


## 막 전환 판정(§4.1, 1 → 2만 — 다른 막은 그 막의 진행기와 함께): K_CODE · MQ-106 끝
func _act_check() -> void:
	if v("V_ACT") == 1 and v("K_CODE") >= 1 and st.quests.stage("MQ-106") >= 100 and state == "":
		_act_up(2)


func _act_up(n: int) -> void:
	st.vars.set_v("V_ACT", n)
	Wanted.refresh(st)
	act_up.emit(n)                                                       # ① 자동 저장(연출이 끝나면 저장된다)
	_wait_box(func() -> void:
		host.ev.run("title_card", ["2막 「강」", "강 건너 서울의 세력들을 만난다."], func() -> void:   # ② 막 제목 카드
			host.play_scene("ACT2_BROADCAST")                             # ③ 공보방송
			_wait_box(func() -> void:
				host.hint("새 목표: 강 건너 서울의 세력들을 만난다.", 7.0))))   # ④ 새 막 목표
	_log("막 전환 → %d" % n)
