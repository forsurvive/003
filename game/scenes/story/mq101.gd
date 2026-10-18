## 1막 MQ-101 「산 아래 마을」 진행기(단계 0-10, SD-03a §8.1). 프롤로그 장면(prologue.gd)이 첫 풍경·공보방송 뒤 넘겨준다.
## 같은 InteriorHost 위에서 돈다: 관악산 비탈(X-S07) → 봉천 계단마을(X-BC) → 옥탑 이장실(B-01)·약국(B-03).
## 원고(script/act1/MQ-101.txt)가 대사·선택지를 맡고, 이 진행기는 원고가 부르는 사건(@cmd mq …)과 실시간 부분을 맡는다:
##   S1 들개 셋·백구(쫓으면 백구가 앞장서 길을 안내) · 생활 세 가지 확인 · 밤(상황 필터·추적조 배치) · 계단 방어전(감시조 4 아군,
##   독사 HP 25%에서 도주) · 해법 결과(카르마·호감도·판도, MQ101_RESULT 1~5) · 기울기 체감(주민 호칭·게시판·고물상 값) · 다음 날 아침.
## 봇(--auto --sol=1~5): 해법 하나를 골라 처음부터 끝까지 논다(0-12 분기 봇의 바탕). --from=xwalk·xroof는 걷기 확인만.
class_name Mq101
extends Node

var host: InteriorHost
var st: StoryState
var auto := false
var log_on := false
var sol := 1                                       ## 봇이 고를 해법: 1 방어 · 2 유인 · 3 거짓말 · 4 돈 · 5 마을을 판다
var shots := ""                                    ## 봇 스크린샷 폴더(--shots=)
var t := 0.0
var done := false

# ---- S1 들개·백구
var dogs: Array = []
var baek: Actor
var baek_lead := false
const WATER_IDS := ["I-054", "I-055", "I-056", "I-057"]          ## 마실 물(물값 배수 대상)
const BAEK_WAY := [Vector2i(13, 20), Vector2i(13, 17), Vector2i(13, 15), Vector2i(14, 9), Vector2i(14, 2)]
var baek_i := 0
var baek_path := PackedVector2Array()

# ---- 밤·방어전
var fight := false
var doksa: Enemy
var doksa_gone := false
var foes: Array = []
const DEFENDERS := [["N-R01-035", "land1"], ["N-R01-028", "land2"], ["N-R01-036", "land3"], ["N-R01-033", "land4"]]
const TRACKERS := [["SB1", "sb1", "en_cr436_loco"], ["SB2", "sb2", "en_cr437_loco"], ["SB3", "sb3", "en_cr437_loco"]]
var res_applied := 0
var lessons_hinted := false
var morning_due := false


# ---------------------------------------------------------------- 터치 봇(0-11): 손가락 0 = 이동 스틱 · 1 = 조준 스틱 · 2 = 단추·화면 누르기
var touch_bot := false
var touch: TouchHud
var _fing := {}                                    ## 손가락 → 누르고 있는 자리(화면 좌표)
var _tap_q: Array = []                             ## 누를 자리 차례(누르고 다음 프레임에 뗀다)


## 논리 화면 좌표(640×360 이상) → 창 좌표(엔진이 늘이기를 되돌려 논리 좌표로 넘긴다)
func _win(p: Vector2) -> Vector2:
	return p * (Vector2(get_window().size) / get_viewport().get_visible_rect().size)


func _touch(idx: int, p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = _win(p)
	e.pressed = down
	Input.parse_input_event(e)
	if down:
		_fing[idx] = p
	else:
		_fing.erase(idx)


func _drag(idx: int, p: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = _win(p)
	e.relative = _win(p) - _win(_fing.get(idx, p))
	Input.parse_input_event(e)
	_fing[idx] = p


func _tap(p: Vector2) -> void:
	_tap_q.append(p)


## 매 프레임: 이동 방향(봇 길찾기) → 이동 스틱 끌기. 조준 → 조준 스틱(사격 링 밖). 누를 자리 → 손가락 2
func _touch_tick(move_dir: Vector2, aim_dir: Vector2) -> void:
	if _fing.has(0):
		_touch(0, _fing[0], false)
	elif not _tap_q.is_empty():
		_touch(0, _tap_q.pop_front(), true)
	var home := TouchHud.MOVE_HOME
	if move_dir.length() > 0.1:
		if not _fing.has(1):
			_touch(1, home, true)
		_drag(1, home + move_dir.normalized() * TouchHud.RING * 0.7)
	elif _fing.has(1):
		_touch(1, _fing[1], false)
	var ah := TouchHud.AIM_HOME + Vector2(touch.off_r, 0)
	if aim_dir.length() > 0.1:
		if not _fing.has(2):
			_touch(2, ah, true)
		_drag(2, ah + aim_dir.normalized() * TouchHud.RING * 0.95)
	elif _fing.has(2):
		_touch(2, _fing[2], false)


func _btn_center(id: String) -> Vector2:
	return touch._btn_rect(id).get_center()


func setup(h: InteriorHost, is_auto: bool, is_log: bool, solution: int = 1, shot_dir: String = "") -> void:
	host = h
	st = h.st
	auto = is_auto
	log_on = is_log
	sol = solution
	shots = shot_dir


## 개발용 밤 시작(--from=xnight): 세 가지를 마치고 빌린 침대에서 잠든 뒤 — 조만석의 밤 안내까지 끝난 상태
var from_night := false


func start_night() -> void:
	from_night = true
	for k in ["MQ101_TRADE", "MQ101_WATER", "MQ101_RAD", "MQ101_TANK", "MQ101_ROOF"]:
		st.vars.set_v(k, 1)
	st.vars.set_v("MQ101_DOG", 2)
	st.vars.set_v("MQ101_NIGHT", 2)
	st.vars.set_v("V_WANTED", 10)
	st.vars.set_v("PC_CAPS", 300)
	st.call_fn("give", ["A-016"])
	st.call_fn("give", ["I-057", 3])
	st.call_fn("give", ["I-001", 2])
	st.quests.set_stage("MQ-101", 40)
	start("B-01", "bed_side")
	host.date_text = "2277. 10. 23.  22:40"
	host.set_night(true)


## 저장 한 장(0-11): 이야기 변수에 없는 진행기 쪽 표시만
func snapshot() -> Dictionary:
	return {"baek": baek_lead, "baek_i": baek_i, "bark": bark_hinted, "lessons": lessons_hinted, "res": res_applied}


## 불러오기: 신호·명령을 잇고(start와 같게) 맵은 진행기가 연다(GameSnapshot.apply_host가 enter → _on_map)
func resume(d: Dictionary) -> void:
	host.map_entered.connect(_on_map)
	host.box.finished.connect(_after_box)
	host.ev.handlers["mq"] = _mq_cmd
	host.ev.handlers["trade"] = _trade_cmd
	host.combat.ally_down.connect(_on_ally_down)
	host.combat.player_down.connect(_on_player_down)
	baek_lead = bool(d.get("baek", false))
	baek_i = int(d.get("baek_i", 0))
	bark_hinted = bool(d.get("bark", false))
	lessons_hinted = bool(d.get("lessons", false))
	res_applied = int(d.get("res", 0))


## 1막 시작: 비탈 첫 칸(첫 풍경에서 주인공이 멈춘 흙길과 같은 자리)
func start(map_id: String = "X-S07", mark: String = "start") -> void:
	host.map_entered.connect(_on_map)
	host.box.finished.connect(_after_box)
	host.ev.handlers["mq"] = _mq_cmd
	host.ev.handlers["trade"] = _trade_cmd
	host.combat.ally_down.connect(_on_ally_down)
	host.combat.player_down.connect(_on_player_down)
	host.body = "adult"
	host.hud_on = true
	host.pipboy_ok = true
	if int(st.vars.get_v("GAME_DAY")) == 0:
		st.vars.set_v("GAME_DAY", 1)
	host.date_text = "2277. 10. 23.  14:30"
	if host.combat.weapon_id == "" and st.best_of("W-002") != "":
		host.combat.equip(st.best_of("W-002"), st)
	host.enter(map_id, mark)
	if st.quests.stage("MQ-101") == 0:
		host.play_scene.call_deferred("MQ-101_START")


func v(k: String) -> int:
	return int(st.vars.get_v(k))


# ================================================================================================ 맵에 들어설 때
func _on_map(id: String) -> void:
	var nightish := v("MQ101_NIGHT") in [1, 2] and v("MQ101_RESULT") == 0
	host.set_night(nightish)
	if id == "X-S07" and v("MQ101_DOG") == 1:
		_spawn_dogs()
	if id == "X-BC":
		if v("MQ101_DOG") == 1:
			st.vars.set_v("MQ101_DOG", 3)                              # 들개를 두고 산을 내려왔다: 백구는 혼자 빠져나와 마을에 와 있다
			host.refresh_npcs()
		if v("MQ101_NIGHT") == 2 and v("MQ101_RESULT") == 0:
			if v("MQ101_FIGHT") == 1:
				_start_fight()
			else:
				_stage_trackers()
	_board()
	_attitude()


# ================================================================================================ 원고 사건(@cmd mq …)
func _mq_cmd(a: Array, finish: Callable) -> void:
	var what := str(a[0])
	match what:
		"panorama":
			_panorama(finish)
			return
		"rads":
			host.hint("방사능 %d 라드 — 핍-보이 능력치 화면에도 뜬다" % v("PC_RADS"), 5.0)
		"dogs":
			if dogs.is_empty():
				_spawn_dogs()
		"heal":
			_heal(int(a[1]))
		"night":
			host.set_night(true)
			host.date_text = "2277. 10. 23.  22:40"
			# 밤 소동에 사람들이 집집마다 뛰어다닌다 — 아직 아무도 못 본 봉천의 시체는 이때 발견된다(1-X 재미 검수 ① · SD-06 §6.4, 지목 주사위는 이미 굴린 값)
			Crimes.find_now(st, "JC_BC", Clock.abs_min(host.date_text))
		"trackers":
			pass                                                        # 아랫마당에 내려가면 배치(_on_map)
		"fight":
			st.vars.set_v("MQ101_FIGHT", 1)
			_start_fight()
		"leave", "sell":
			_trackers_leave()
		"lure":
			_trackers_leave()
			host.ev.handlers["pc"].call(["5,35", "E"], func() -> void: pass)
	finish.call()


## 전망 망원경: 첫 풍경의 먼 그림(키아트 원경)을 3초 보여 준다(SD-09a §3.3 '전망 상호작용 → 픽처 1장')
func _panorama(finish: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 9
	host.add_child(layer)
	var back := ColorRect.new()
	back.color = Color("0B0A0D")
	back.size = Vector2(4000, 3000)
	layer.add_child(back)
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/ui/first_view_far.png")
	sp.centered = false
	var vs := host.get_viewport().get_visible_rect().size
	sp.position = Vector2(floorf((vs.x - 640.0) / 2.0), floorf((vs.y - 330.0) / 2.0))
	layer.add_child(sp)
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		layer.queue_free()
		finish.call())


## 하숙자 약국 치료(SD-15 §6.1 의사 40·70·100캡, 정합: 값마다 회복 35%·65%·전부)
func _heal(price: int) -> void:
	if v("PC_CAPS") < price:
		host.hint("캡이 모자라다", 3.0)
		return
	st.call_fn("caps", [-price])
	var c := host.combat.pc
	var k: float = {40: 0.35, 70: 0.65, 100: 1.0}.get(price, 0.35)
	c.hp = minf(c.max_hp, c.hp + c.max_hp * float(k))


## 거래 창(0-10c, SD-15 §3.6 상점 특전): 오봉수 고물상은 MQ-101 방어(결과 1)·몰래 내보냄(2)이면 사는 값 −10%,
## 돈으로 해결(4)이면 +10%. 창 위 인사는 가장 큰 보정 하나를 말로 알린다(§3.10). 한 번이라도 사고팔면 MQ101_TRADE = 1
func _trade_cmd(a: Array, finish: Callable) -> void:
	var vid := str(a[0])
	if str(host.merchants.get(vid, {}).get("settle", "")) == "BC" and st.vars.has("SQ_S04_LOITER") \
			and v("SQ_S04_LOITER") > Clock.abs_min(host.date_text):
		host.hint("오늘은 장사 안 해. 아랫문 앞에 쇳덩이 셋이 서성이잖아.", 4.0)   # SQ-S04 해법 C 뒤 72시간: 봉천 상인 휴업(SD-04a §4.4)
		finish.call()
		return
	var m := trade_mult(vid)
	host.open_trade(vid, func(caps: int) -> void:
		if caps > 0:
			st.vars.set_v("MQ101_TRADE", 1)
		finish.call(), m[0], m[1], m[2])


## 거래 배수 [[사는 값, 파는 값], 인사, 물건별 배수]: MQ-101 결과 · SQ-S01 인식표 · 지하시장 단골 · SQ-S02 수위(봉천 상인 — 붉은 띠면 +10% · 물값 2배, 우회 관로 뒤 정수 물 −20%)
func trade_mult(vid: String) -> Array:
	var r := v("MQ101_RESULT")
	var k := [1.0, 1.0]
	var greet := ""
	if vid == "V01" and r in [1, 2]:
		k = [0.90, 1.0]
		greet = "계단 지켜 준 사람한테 제값 받으면 벌 받지. 빼 줄게." if r == 1 else "놈들 하수구로 몰아낸 머리값이야. 빼 줄게."
	elif vid == "V01" and r == 4:
		k = [1.10, 1.0]
		greet = "새벽인력이랑 장사하는 손님이면 값도 그쪽 시세로 받아야지."
	if vid == "V04" and v("SQH_TAG") == 20:                             # SQ-S01 인식표를 오두막에 걸었다(SD-04a §4.1): 상시 −10% · 매입 +10%
		k = [0.90, 1.10]
		greet = "산의 이름 걸어 둔 사람 값이야."
	host.shop_state(vid)                                              # 상인 표를 읽어 둔다(세력 확인)
	if str(host.merchants.get(vid, {}).get("settle", "")) == "JH" and v("JM_REG") == 1:   # 지하시장 단골(1-4): −10%
		k = [0.90, 1.0]
		greet = "단골한테는 덜 남겨."
	if vid == "V11" and st.vars.has("SQ_S12_REWARD") and v("SQ_S12_REWARD") & 1:   # SQ-S12 보상(SD-04a §5.5): 엄수연 약 상시 −15% — 그이 이름을 돌려준 손님
		k = [k[0] * 0.85, k[1]]
		greet = "그이 이름 찾아 준 사람이잖아요. 약값은 덜 받아요."
	if vid == "VJ05" and st.vars.has("SQ_S12_REWARD") and v("SQ_S12_REWARD") & 2:   # SQ-S12: 진재석 진공관 감정(원문 '무료 감정') — 매입을 제값에(+10%)
		k = [k[0], k[1] * 1.10]
		greet = "사위 놈 신분증 들고 온 사람이야. 진공관은 내가 제값 쳐 줘."
	if vid == "V05" and st.vars.has("SQ_S05_PYO") and v("SQ_S05_PYO") == 1:   # SQ-S05 보상(SD-04a §4.5): 표하경 상시 −15% — 서쪽 측실 선반
		k = [k[0] * 0.85, k[1]]
		greet = "서쪽 측실 선반 몫이야. 너한테는 싸게."
	var item_k := {}
	if r == 5:                                                        # 마을을 팖: 다음 날 마을 물값 2배(SD-03a §8.1 표)
		for w in WATER_IDS:
			item_k[w] = 2.0
		greet = "물값이 왜 올랐는지는 당신이 더 잘 알 텐데."
	if str(host.merchants.get(vid, {}).get("settle", "")) == "BC" and st.vars.has("SQ_S02_LEVEL"):
		if v("SQ_S02_POSTED") == 1 and v("SQ_S02_LEVEL") == 0:
			k = [k[0] * 1.10, k[1]]                                   # SD-04a §4.2 시간 제한: 5일째 봉천 상인 가격 +10% · 물값 2배
			for w in WATER_IDS:
				item_k[w] = float(item_k.get(w, 1.0)) * 2.0
			greet = "배수지가 바닥이야. 물이 금값이라 다른 것도 따라 올라."
		elif v("SQ_S02_B") == 1:
			for w in WATER_IDS:
				item_k[w] = float(item_k.get(w, 1.0)) * 0.8                # 해법 B: 배수지 정수 물 상시 −20%
	return [k, greet, item_k]


# ================================================================================================ S1 들개·백구
func _spawn_dogs() -> void:
	dogs.clear()
	for k in 3:
		var m := "dog%d" % (k + 1)
		var e := host.combat.spawn("CR-104", host.map.mark_pos(m), host.map, st, {"stance": "hold", "dir": "W"})
		dogs.append(e)
	host.ev._show_actor("C-015", host.map.mark_pos("baekgu"), "E", "cr_baekgu_loco")
	baek = host.ev.actors.get("C-015")
	host.map.blockers.erase(baek)                                     # 앞장서는 개는 길을 막지 않는다(좁은 돌계단에서 비켜 지나감)


func _dogs_tick(dt: float) -> void:
	if v("MQ101_DOG") == 1 and not dogs.is_empty() and host.map.id == "X-S07":
		var alive := dogs.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
		if alive.is_empty() and not host.box.active and not host.ev.busy():
			st.vars.set_v("MQ101_DOG", 2)
			baek_lead = true
			baek_i = 0
			host.play_scene("MQ-101_DOGS_WIN")
	if baek_lead and is_instance_valid(baek) and host.map.id == "X-S07" and not host.box.active:
		var me := host.player.loco.logical
		var goal := Vector2(host.map.cell_local(BAEK_WAY[baek_i].x, BAEK_WAY[baek_i].y) * 32) + Vector2(16, 16)
		if baek.loco.logical.distance_to(goal) < 6.0:
			baek_i = mini(baek_i + 1, BAEK_WAY.size() - 1)
			baek_path = PackedVector2Array()
		if baek.loco.logical.distance_to(me) < 5.0 * 32.0 and baek.loco.logical.distance_to(goal) >= 6.0:
			if baek_path.is_empty():
				baek_path = NpcRoutine.with_start(host.map, baek.loco.render, goal)
			while baek_path.size() > 0 and NpcRoutine.arrived(baek.loco.render, baek_path[0]):
				baek_path.remove_at(0)
			baek.mode = "run"
			baek.move(NpcRoutine.step_dir(baek.loco.render, baek_path[0]) if baek_path.size() > 0 else Vector2.ZERO, dt)
		else:
			baek.move(Vector2.ZERO, dt)                                # 멈춰 서서 돌아본다
			baek.loco.facing = Locomotion.snap8(me - baek.loco.logical, 0.0)
			baek._show()


# ================================================================================================ 밤: 추적조·방어전
func _stage_trackers() -> void:
	for tr in TRACKERS:
		host.ev._show_actor(tr[0], host.map.mark_pos(tr[1]), "N", tr[2])
	if host.ev.actors.has("C-015"):
		host.ev.actors["C-015"].set_meta("bark", true)


## 백구의 경보(SD-03a §8.1 S4 '백구가 짖어 매복 위치를 알려 준다'): 밤 아랫마당에 추적조가 서 있는 동안 4초마다 백구 '!'·추적조 '?'.
## 처음 한 번은 안내 줄. 백구가 그 사이 죽었으면(맵 주민 — 1-X) 짖는 개가 없다(조용히 넘어간다).
var bark_t := 0.0
var bark_hinted := false


func _bark_tick(dt: float) -> void:
	if host.map == null or host.map.id != "X-BC" or not host.ev.actors.has("SB1") or host.box.active:
		return
	bark_t -= dt
	if bark_t > 0.0:
		return
	bark_t = 4.0
	var dog: Actor = host.ev.actors.get("C-015")
	if dog == null:
		for n in host.npcs:
			if str(n["id"]) == "C-015" and is_instance_valid(n["actor"]):
				dog = n["actor"]
	if dog == null:
		return
	host.ev.balloons.append({"actor": dog, "kind": "!", "t": 0.0})
	for tr in TRACKERS:
		var a: Actor = host.ev.actors.get(tr[0])
		if a != null and is_instance_valid(a):
			host.ev.balloons.append({"actor": a, "kind": "?", "t": 0.0})
	host.ev.queue_redraw()
	if not bark_hinted:
		bark_hinted = true
		host.hint("백구가 아랫문 쪽을 보고 짖는다 — 어둠 속에 누가 서 있다", 5.0)


func _trackers_leave() -> void:
	for tr in TRACKERS:
		if host.ev.actors.has(tr[0]):
			host.ev.actors[tr[0]].queue_free()
			host.ev.actors.erase(tr[0])
	host.refresh_npcs()


func _start_fight() -> void:
	if fight or host.map.id != "X-BC":
		return
	fight = true
	_trackers_leave()                                                 # 말 상대(인물 독사)·단역을 치우고 전투 개체로 다시 세운다
	foes.clear()
	doksa = host.combat.spawn("CR-534", host.map.mark_pos("doksaf"), host.map, st, {"who": "C-021", "lv": 4})
	foes.append(doksa)
	for i in TRACKERS.size():
		var id := "CR-436" if TRACKERS[i][2] == "en_cr436_loco" else "CR-437"
		foes.append(host.combat.spawn(id, host.map.mark_pos("sbf%d" % (i + 1)), host.map, st, {"lv": 3}))
	host.player.loco.logical = host.map.mark_pos("pc_fight")            # 아랫문 안에서 막는다(대화 끝의 페이드 사이)
	host.player.loco.render = host.player.loco.logical
	host.player.position = host.player.loco.render
	host.player.loco.facing = 2                                         # 남쪽(아랫문)을 본다
	for e in foes:
		e.brain.state = AIBrain.S.COMBAT                                  # 이미 마을을 노리고 왔다: 처음부터 교전
		e.brain.gauge = 100.0
	for d in DEFENDERS:
		if st.is_dead(d[0]):
			continue
		var pos := host.map.mark_pos(d[1])
		host.ev._show_actor(d[0], pos, "S")
		var a: Actor = host.ev.actors.get(d[0])
		if a != null:
			host.combat.add_ally(d[0], a, 60.0, "W-002")
	if st.best_of("W-002") == "":                                     # 총 없이(또는 부서진 총뿐) 나온 갈래(은신·설득·하도윤): 남태하가 감시조 예비 권총을 건넨다
		st.call_fn("give", ["W-002"])
		st.call_fn("give", ["10mm 탄", 24])
		st.vars.set_v("MQ101_LOAN", 1)
	if Gear.base(host.combat.weapon_id) != "W-002":
		host.combat.equip(st.best_of("W-002"), st)
	host.hint("계단 방어 — 감시조가 계단참마다 섰다", 5.0)


func _fight_tick(_dt: float) -> void:
	if not fight:
		return
	if is_instance_valid(doksa) and not doksa_gone and not doksa.cmb.dead and doksa.cmb.hp <= doksa.cmb.max_hp * 0.25:
		doksa_gone = true                                                 # 독사는 체력 25%에서 도주(SD-03a §8.1)
		doksa.cmb.team = "gone"
		doksa.foes.clear()                                                # 달아나는 동안 아무도 노리지 않는다(예전엔 노리는 편이 남아 보이지 않는 채로 물었다 — 해법 1 봇 원인)
		doksa.brain.state = AIBrain.S.RETURN
		host.combat._rebuild_list()
		host.combat.message.emit("독사가 피를 흘리며 아랫문 밖으로 달아난다")
		var tw := create_tween()
		tw.tween_property(doksa, "position", doksa.position + Vector2(0, 160), 1.6)
		var gone_d := doksa
		tw.tween_callback(func() -> void:
			if is_instance_valid(gone_d):
				gone_d.visible = false
				host.combat.drop_enemy(gone_d))                       # 전장에서 뺀다(사라진 몸이 남아 싸우지 않게)
	if is_instance_valid(doksa) and doksa.cmb.dead and doksa.cmb.killed_lethal and not st.is_dead("C-021"):
		st.kill("C-021")                                           # 독사 사살: 카르마 0(SD-03a §8.1 표)
	var left := foes.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy")
	if left.is_empty() and not host.box.active:
		fight = false
		host.combat.clear_allies()
		st.call_fn("result", ["MQ-101", 1])


func _on_ally_down(id: String) -> void:
	st.vars.set_v("MQ101_DEAD", v("MQ101_DEAD") + 1)
	st.kill(id)


## 방어전에서 쓰러지면(정합: 생포 이벤트는 단계 0 범위 밖) 감시조가 계단참④로 끌어 올린다 — HP 절반
func _on_player_down() -> void:
	if not fight:
		return
	var c := host.combat.pc
	c.dead = false
	c.hp = c.max_hp * 0.5
	host.ev.handlers["pc"].call(["land4", "S"], func() -> void: pass)
	host.hint("정신을 잃었다가 깼다 — 감시조가 계단참④로 끌어 올렸다", 5.0)


# ================================================================================================ 결과(행동이 정한 해법)
## SD-03a §8.1 표: 카르마 · 봉천(AFF_JC_BC) · 새벽인력(AFF_SB) · 판도(봉천 정착 PD_BC, R01 PD_R01). XP 150. 방어 사망 1명당 봉천 −3
const RESULT_FX := {1: [0, 20, -15, 10, 5], 2: [25, 15, -5, 0, 0], 3: [0, 5, 0, 0, 0], 4: [0, -5, 10, 0, 0], 5: [-100, -20, 10, -10, 0]}


func _apply_result(r: int) -> void:
	if r == 6:                                                          # 봉천이 문을 닫음(1-X) — 밤 결과가 아니다
		res_applied = 6
		return
	res_applied = r
	var fx: Array = RESULT_FX[r]
	if int(fx[0]) != 0:
		st.call_fn("karma", [int(fx[0])])
	st.call_fn("aff", ["BC", int(fx[1]) - (3 * v("MQ101_DEAD") if r == 1 else 0)])
	st.call_fn("aff", ["SB", int(fx[2])])
	st.vars.set_v("PD_BC", v("PD_BC") + int(fx[3]))
	st.vars.set_v("PD_R01", v("PD_R01") + int(fx[4]))
	st.call_fn("xp", [150])
	st.quests.set_stage("MQ-101", 50)
	var after: String = {1: "MQ-101_R1", 5: "MQ-101_SELL"}.get(r, "")
	if after != "" and not host.box.active:
		host.play_scene(after)
	morning_due = true


## 봉천이 문을 닫았다(1-X 교차 감사, SD-20 P11 · SD-06 §4.3.8 적대): MQ-101 진행 중에 봉천이 적대(≤ −60 — 대표 살해가 알려짐 · 학살 ·
## 목격된 살인이 쌓임)가 되면 이장의 일은 이어질 수 없다. MQ-101을 사유와 함께 닫고(결과 6, 정합: SD-03a §8.1 표에 없는 값) 허브를 연다.
## 깨진 글자를 읽을 사람은 소문(영등포 지하시장)과 경로 장소(O-02)로 찾는다. 밤 싸움 한가운데면 끝난 뒤에(P5).
func _hostile_check() -> void:
	var s := st.quests.stage("MQ-101")
	if s == 0 or s >= 100 or not Crimes.hostile(st, "JC_BC"):
		return
	if host.box.active or host.ev.busy() or host.busy or (v("MQ101_NIGHT") == 2 and v("MQ101_RESULT") == 0):
		return
	res_applied = 6
	morning_due = false
	st.vars.set_v("MQ101_RESULT", 6)
	st.quests.set_stage("MQ-101", 100)
	if st.quests.stage("MQ-102") == 0:
		st.quests.set_stage("MQ-102", 10)
	host.hint("봉천은 문을 닫았다. 손목 기계의 깨진 글자를 읽을 사람은 혼자 찾아야 한다.", 7.0)


## 다음 날 아침: 밤 필터를 끄고 빌린 침대에서 깬다(조만석과 다음 일을 의논한다)
func _morning() -> void:
	morning_due = false
	host.busy = true
	host.ev.run("fade_out", ["black", "10"], func() -> void:
		for id in ["SB1", "SB2", "SB3", "C-021"] + DEFENDERS.map(func(d): return d[0]):
			if host.ev.actors.has(id) and is_instance_valid(host.ev.actors[id]):
				host.ev.actors[id].queue_free()
				host.ev.actors.erase(id)
		st.vars.set_v("MQ101_NIGHT", 3)
		st.vars.set_v("GAME_DAY", 2)
		host.date_text = "2277. 10. 24.  07:10"
		var c := host.combat.pc
		c.hp = maxf(c.hp, c.max_hp * 0.8)                                  # 빌린 침대에서 잤다(SD-12 §11.4 수면 회복의 정합: 80%까지)
		host.enter("B-01", "bed")
		host.ev.run("fade_in", ["black", "10"], func() -> void:
			host.busy = false
			host.hint("아침이다 — %s 다음 일을 의논한다" % _chief_role(), 6.0)))


## 아침에 의논할 사람(A52 — 이름 대신 지금 그 일을 맡은 사람): 조만석 → 하숙자 → 반상회 게시판
func _chief_role() -> String:
	if not st.known_dead("C-010"):
		return "조만석과"
	if not st.known_dead("C-057"):
		return "이장 대행 하숙자와"
	return "반상회 게시판 공고를 보고"


# ================================================================================================ 기울기 체감(SD-03a §8.1): 게시판·호칭
const BOARD_STATE := {1: "torn", 2: "crumpled", 3: "crossed", 4: "rate", 5: "water", 6: "wanted"}   # 6 봉천이 문을 닫음(1-X): 수배 쪽지 그대로


func _board() -> void:
	if host.map.id != "X-BC":
		return
	var s := ""
	if v("MQ101_RESULT") != 0:
		s = str(BOARD_STATE.get(v("MQ101_RESULT"), "wanted"))
	elif v("MQ101_NIGHT") >= 1:
		s = "wanted"
	host.map.set_prop_state(host.map.cell_local(22, 35), s)


## 주민 한마디: 밤에 바뀌는 대사 3종(경계·두려움·감쌈) + 해법별 호칭(이름 · 손님 · '볼트 애' · 침묵)
const NIGHT_BARKS := {"N-R01-028": "쪽지 봤어. …이장님이 손님이라면 손님이야. 들어가 있어.",
	"N-R01-036": "새벽인력이 너 하나 때문에 왔다며? 마을이 무슨 죄야.",
	"N-R01-033": "독사 놈들은 숫자를 세는 게 일이야. 우리 숫자도 세고 있을걸.",
	"N-R01-034": "백구가 계속 짖어요. 무서워요."}
const ABSENT_BARKS := {"N-R01-029": "이장님이 오늘은 안 내려오시네. 별일이야.", "N-R01-031": "옥탑방 문이 종일 닫혀 있더라.",
	"N-R01-028": "이장님 못 봤어? 망루 교대 얘기 할 게 있는데."}
const RESULT_BARKS := {
	1: {"N-R01-028": "{name}! 어젯밤 계단 막은 거 잊지 않는다.", "N-R01-029": "{name}, 아침은 먹었어? 텃밭 상추 좀 가져가.",
		"N-R01-034": "{name} 언니! 백구 밥 같이 줘요!", "N-R01-030": "{name}, 총 손볼 거 있으면 가져와. 공짜다.",
		"N-R01-031": "애들이 다 {name} 얘기만 해.", "N-R01-033": "{name}, 사냥 갈 때 불러. 너 같은 손이면 든든하지."},
	2: {"N-R01-028": "{name}, 옥상길로 놈들을 끌고 나갔다며? 머리 좋네.", "N-R01-029": "{name}, 하수구 냄새 났었는데 고생했어.",
		"N-R01-034": "{name} 언니, 옥상 판자 다리 나도 건널래요!", "N-R01-030": "{name}, 사다리 삐걱대면 말해.",
		"N-R01-031": "{name} 얘기 들었어. 싸우지 않고 끝냈다고.", "N-R01-033": "{name}, 배수로 길 알아 두면 쓸 데가 많아."},
	3: {"N-R01-028": "손님, 강 건넜다던 그 볼트 애 얘기 들었어? 하하.", "N-R01-029": "손님은 어디서 왔다고 했지?",
		"N-R01-034": "강 건너간 언니 얘기 진짜예요?", "N-R01-030": "손님, 뭐 고칠 거 있어?",
		"N-R01-031": "손님, 거짓말도 재주라더라.", "N-R01-033": "독사가 그 말을 믿었다고? 운 좋네, 손님."},
	4: {"N-R01-028": "새벽인력하고 거래한 손님이구먼.", "N-R01-029": "캡으로 끝났다며. 우리 것도 아닌데 뭐.",
		"N-R01-034": "그 아저씨들 또 와요?", "N-R01-030": "새벽인력 거래처 손님이면 값은 따로 받아.",
		"N-R01-031": "돈으로 사는 평화는 오래 안 가.", "N-R01-033": "독사가 '다음엔 값이 오른다'더라. 들었지?"},
	5: {"N-R01-028": "…", "N-R01-029": "물 반 컵이 애들 하루치야. 알기나 해?", "N-R01-034": "엄마가 말 걸지 말래요.",
		"N-R01-030": "볼일 없으면 가.", "N-R01-031": "…", "N-R01-033": "저수조 털어 간 손수레 바퀴 자국, 아직 남아 있다."}}


func _attitude() -> void:
	var r := v("MQ101_RESULT")
	var nm := str(st.vars.get_v("P_GIVEN"))
	for n in host.npcs:
		var id := str(n["id"])
		var b := ""
		if r != 0:
			b = str((RESULT_BARKS.get(r, {}) as Dictionary).get(id, ""))   # 6(문을 닫음)은 호스트의 적대 인사가 맡는다
		elif v("MQ101_NIGHT") >= 1:
			b = str(NIGHT_BARKS.get(id, ""))
		elif st.is_dead("C-010") and not st.known_dead("C-010"):
			b = str(ABSENT_BARKS.get(id, ""))                            # 아직 아무도 모른다 — '안 보인다'만(N12)
		if id == "N-R01-034" and st.known_dead("C-015") and b.contains("백구"):
			b = "…백구 그릇에 오늘도 물 채웠어요."                          # 죽은 개를 산 개처럼 말하지 않는다(1-X)
		elif id == "N-R01-034" and st.is_dead("C-015") and b.contains("백구"):
			b = "백구가 안 들어왔어요. 어디 갔지?"
		if b != "":
			n["bark"] = b.replace("{name}", nm)


# ================================================================================================ 매 틀
func _after_box() -> void:
	if res_applied == 0 and v("MQ101_RESULT") != 0:
		_apply_result(v("MQ101_RESULT"))
		return
	if morning_due and not host.box.active:
		_morning()


func _process(dt: float) -> void:
	if host == null or host.map == null:
		return
	t += dt
	_dogs_tick(dt)
	_fight_tick(dt)
	_bark_tick(dt)
	if res_applied == 0 and v("MQ101_RESULT") != 0 and not host.box.active and not host.ev.busy():
		_apply_result(v("MQ101_RESULT"))
	_hostile_check()
	if morning_due and not host.box.active and not host.ev.busy() and not host.busy:
		_morning()
	if not lessons_hinted and st.quests.stage("MQ-101") == 30 and v("MQ101_TRADE") == 1 and v("MQ101_WATER") == 1 and v("MQ101_RAD") == 1:
		lessons_hinted = true
		st.call_fn("xp", [50])
		host.hint("생활 세 가지를 다 배웠다 — 이장실 옆 빌린 침대에서 쉴 수 있다", 7.0)
	if auto:
		_bot(dt)


# ================================================================================================ 봇
var route: Array = []                              ## 걷기 지점 [[맵 ID, 칸 x, 칸 y], …]
var route_i := 0
var path := PackedVector2Array()
var path_goal := Vector2.INF
var _re_t := 0.0
var stuck_t := 0.0
var _last_p := Vector2.ZERO
var _greet_shot := false
var _ev_greet := ""                                 ## 0-12 증거: 아침 고물상 첫마디
var _ev_price := -1                                 ## 0-12 증거: 아침 스팀팩 사는 값(-1 = 거래 안 함)
var plan: Array = []                               ## 봇 할 일 [[종류, 인자…], …]
var plan_i := 0
var wait_t := 0.0
var hold := 0.0
var walk_only := false


func walk(points: Array) -> void:
	route = _expand(points)
	route_i = 0
	walk_only = true
	host.input_fn = _bot_input


## 이 맵 ID의 지점을 지금 맵에서 걸어서 갈 수 있나(월드는 "W"·손 맵 모두, 1-1)
func _scope(map_id: String) -> bool:
	return host.map.id == map_id or (host.map is WorldMap and WorldMap.covers(map_id))


## 지점 [맵, x, y] → 지금 맵의 픽셀(월드는 손 맵 좌표를 옮긴다)
func _goal_px(r: Array) -> Vector2:
	var c := Vector2i(int(r[1]), int(r[2]))
	if host.map is WorldMap:
		c = host.map.to_world(str(r[0]), c.x, c.y)
	return Vector2(c * 32) + Vector2(16, 16)


## 지금 맵 칸 좌표를 그대로 쓰는 지점의 맵 이름(월드는 "W")
func _here() -> String:
	return "W" if host.map is WorldMap else host.map.id


## 월드에서 손 맵이 바뀌는 지점 사이에 굽기가 찾은 걷는 길(경유점)을 끼운다
func _expand(points: Array) -> Array:
	if host.map == null or not host.map is WorldMap:
		return points
	var out: Array = []
	for i in points.size():
		var r: Array = points[i]
		if i > 0:
			var a := str(points[i - 1][0])
			var b := str(r[0])
			if a != b and a != "W" and b != "W" and WorldMap.covers(a) and WorldMap.covers(b):
				out.append_array(host.map.route_between(a, b))
		out.append(r)
	return out


func _bot_input() -> Vector2:
	if route_i >= route.size() or host.map == null:
		return Vector2.ZERO
	while route_i + 1 < route.size() and not _scope(str(route[route_i][0])) and _scope(str(route[route_i + 1][0])):
		route_i += 1                                               # 출구를 밟아 맵이 바뀌었다: 그 맵의 다음 지점으로
		path = PackedVector2Array()
	var r: Array = route[route_i]
	if not _scope(str(r[0])):
		return Vector2.ZERO
	var goal := _goal_px(r)
	var p := host.player.loco.render
	if p.distance_to(goal) < 6.0:
		route_i += 1
		path = PackedVector2Array()
		return Vector2.ZERO
	if path.is_empty() or path_goal != goal or t - _re_t > 3.0:
		_re_t = t
		path = NpcRoutine.with_start(host.map, p, goal)
		path_goal = goal
	while path.size() > 0 and (NpcRoutine.arrived(p, path[0]) or (path.size() > 1 and p.distance_to(path[1]) <= path[0].distance_to(path[1]) + 2.0)):
		path.remove_at(0)                                              # 지난 칸 가운데는 발걸음 단위로 정확히 밟지 못한다
	if path.is_empty():
		return (goal - p).normalized() if p.distance_to(goal) > 2.0 else Vector2.ZERO
	return NpcRoutine.step_dir(p, path[0])


## 봇 할 일 목록(해법 sol): 비탈(들개는 1·3·5만 쫓는다) → 아랫문 → 이장 → 생활 세 가지 → 침대 → 밤 → 해법 → 아침
func make_plan() -> void:
	plan = []
	if from_night:                                                    # --from=xnight: 침대에서 깬 밤부터(해법만)
		plan += [["go", "X-BC", 27, 9]]
	elif sol in [1, 3, 5] and st.count_of("W-002") > 0:      # 총이 있으면 들개를 쫓는다(없으면 지나친다 — 백구는 혼자 마을에 와 있다)
		plan += [["go", "X-S07", 14, 22], ["fight_dogs"], ["go", "X-BC", 55, 43]]
	else:
		plan += [["go", "X-BC", 55, 43]]
	if not from_night:
		plan += [["go", "X-BC", 29, 37], ["go", "X-BC", 29, 34], ["shot", "gate"], ["go", "X-BC", 27, 9], ["go", "B-01", 6, 9],
			["talk", "C-010"], ["shot", "chief"], ["go", "X-BC", 27, 9], ["go", "X-BC", 22, 26], ["go", "B-03", 7, 7], ["talk", "C-057"],
			["go", "X-BC", 22, 26], ["go", "X-BC", 11, 35], ["talk", "N-R01-026"], ["drink"], ["go", "X-BC", 27, 9], ["go", "B-01", 22, 6],
			["use", "B-01", 22, 5], ["wait_night"], ["shot", "night"], ["go", "X-BC", 27, 9]]
	match sol:
		1:
			plan += [["go", "X-BC", 24, 37], ["board"], ["go", "X-BC", 29, 38], ["talk", "C-021"], ["battle"]]
		2:
			plan += [["go", "X-BC", 6, 14], ["go", "X-BC", 5, 20], ["go", "X-BC", 5, 27], ["go", "X-BC", 5, 35], ["use", "X-BC", 5, 36]]
		3:
			plan += [["equip", "A-016"], ["go", "X-BC", 24, 37], ["board"], ["go", "X-BC", 29, 40], ["talk", "C-021"]]
		4:
			plan += [["caps", 260], ["go", "X-BC", 29, 40], ["talk", "C-021"]]
		5:
			plan += [["go", "X-BC", 29, 40], ["talk", "C-021"]]
	plan += [["wait_morning"], ["talk", "C-010"], ["go", "X-BC", 27, 9], ["go", "X-BC", 24, 37], ["board"], ["shot", "board"],
		["go", "X-BC", 11, 35], ["talk", "N-R01-026"], ["shot", "shop"], ["end"]]
	plan_i = 0


## 대사·선택지(봇): 해법마다 고를 말
const PICKS := {"MQ-101_S2": "고맙다", "MQ-101_HA": "괜찮다", "B-01_BED": "눈을 붙인다"}


func _bot_box(dt: float) -> void:
	var box := host.box
	host.combat.bot = {"walk": true}
	match box.state.get("type", ""):
		"line":
			if box.reveal >= box.page_len:
				hold += dt
				if hold > 0.5:
					hold = 0.0
					if not _greet_shot and str(box.state.get("who", "")) == "N-R01-026" and st.quests.stage("MQ-101") >= 100:
						_greet_shot = true                                   # 아침 고물상 첫마디(해법별 호칭, 0-12 비교) — 찍고 다음 차례에 넘긴다
						_ev_greet = str(box.state.get("text", ""))
						_shot("greet")
						return
					if touch_bot:
						_tap(Vector2(320, 300))                                 # 터치: 대사 창 아무 곳이나 누른다
					else:
						box.next()
		"choices":
			hold += dt
			if hold > 0.9:
				hold = 0.0
				var opts: Array = box.state.get("opts", [])
				var want := ""
				if opts.any(func(o): return str(o["text"]).contains("돌아선다")) and opts.any(func(o): return str(o["text"]).contains("200캡")):
					want = {1: "총을 꺼낸다" if st.count_of("W-002") > 0 else "감시조 옆에", 2: "돌아선다", 3: "흙색 작업복", 4: "200캡", 5: "저수조"}[sol]
					_shot("doksa")
				elif opts.any(func(o): return str(o["text"]).contains("눈을 붙인다")):
					want = "눈을 붙인다"
				elif opts.any(func(o): return str(o["text"]).contains("괜찮다")):
					want = "괜찮다"
				elif opts.any(func(o): return str(o["text"]).contains("고맙다")):
					want = "고맙다"
				var i := 0
				for k in opts.size():
					if want != "" and str(opts[k]["text"]).contains(want):
						i = k
				if touch_bot:
					_tap(box.row_center(i))                                     # 터치: 그 선택지 줄을 눌러 강조하고
					_tap(box.row_center(i))                                     # 한 번 더 눌러 결정(§17.5)
				else:
					box.pick(i)


func _bot(dt: float) -> void:
	if done:
		return
	if walk_only:
		_walk_check(dt)
		return
	if plan.is_empty():
		make_plan()
		host.input_fn = _bot_input if not touch_bot else Callable()
	if touch_bot:
		var mv := Vector2.ZERO
		var aim := Vector2.ZERO
		if not (host.box.active or host.busy or host.ev.busy() or host.container != null):
			mv = _bot_input() if plan_i < plan.size() and str(plan[plan_i][0]) in ["go", "talk"] else Vector2.ZERO
			if plan_i < plan.size() and str(plan[plan_i][0]) in ["battle", "fight_dogs"]:
				var es := host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy")
				if not es.is_empty():
					es.sort_custom(func(a, b): return a.loco.logical.distance_to(host.player.loco.logical) < b.loco.logical.distance_to(host.player.loco.logical))
					aim = es[0].loco.logical - host.player.loco.logical
		_touch_tick(mv, aim)
	if host.container is TradeScreen:
		_bot_trade(host.container, dt)
		return
	if log_on and int(t) % 8 == 0 and int(t - dt) % 8 != 0 and (host.box.active or host.busy or host.ev.busy()):
		print("[%3.0f초] 대기: 대화 %s(%s, 명령 대기 %s) · 연출 %s · 바쁨 %s" % [t, host.box.active, str(host.box.state.get("type", "")),
			host.box.waiting_cmd, host.ev.busy(), host.busy])
	if host.box.active and not host.box.waiting_cmd:
		_bot_box(dt)
		return
	if host.box.active or host.busy or host.ev.busy() or host.pipboy != null:
		return
	if log_on and int(t) % 4 == 0 and int(t - dt) % 4 != 0:
		print("[%3.0f초] %s 칸 %s 할 일 %d/%d %s 단계 %d 밤 %d 결과 %d 개 %d/%d HP %.0f" % [t, host.map.id, host.map.tile_of(host.player.loco.render),
			plan_i, plan.size(), plan[plan_i] if plan_i < plan.size() else [], st.quests.stage("MQ-101"), v("MQ101_NIGHT"),
			v("MQ101_RESULT"), v("MQ101_DOG"), dogs.size(), host.combat.pc.hp])
		if OS.has_feature("debug") and "--dbg" in OS.get_cmdline_user_args():
			var pp: Vector2 = host.player.loco.logical
			var rr: float = host.player.radius_px
			print("  dbg hits NW %s N %s W %s here %s r %.1f world_is_map %s" % [host.map.circle_hits(pp + Vector2(-4, -4), rr), host.map.circle_hits(pp + Vector2(0, -4), rr), host.map.circle_hits(pp + Vector2(-4, 0), rr), host.map.circle_hits(pp, rr), rr, host.player.world == host.map])
			print("  dbg pos %s render %s fa %d talking %s motion %s path %s route %s baek %s blockers %d input %s" % [str(host.player.loco.logical), str(host.player.loco.render), host.player.loco.frames_advanced, str([host.locked, host.busy, host.ev.busy(), host.box.active, host.container]), host.player.loco.motion, str(path.slice(0, 3)), str(route), str(host.map.tile_of(baek.loco.logical)) if is_instance_valid(baek) else "-", host.map.blockers.size(), str(host.input_fn.call())])
	if plan_i >= plan.size():
		return
	var job: Array = plan[plan_i]
	match str(job[0]):
		"go":
			if route.is_empty() or route_i >= route.size() or route[route.size() - 1] != [job[1], job[2], job[3]]:
				var here_zone := host.map.id
				route = [[job[1], job[2], job[3]]]
				if host.map is WorldMap and here_zone != str(job[1]) and here_zone != "W" and WorldMap.covers(str(job[1])):
					route = host.map.route_between(here_zone, str(job[1])) + route     # 손 맵 사이는 월드 길로(1-1)
				route_i = 0
				path = PackedVector2Array()
			if _scope(str(job[1])) and host.player.loco.render.distance_to(_goal_px(job.slice(1))) < 8.0:
				_next()
			elif not _scope(str(job[1])):
				_exit_toward(str(job[1]))
			else:
				_stuck_check(dt)
		"talk":
			_talk(str(job[1]))
		"use":
			host.player.loco.facing = Locomotion.snap8(_goal_px(job.slice(1)) - host.player.loco.logical, 0.0)
			host.player._show()
			if touch_bot:
				_tap(_btn_center("act"))
			else:
				host.interact()
			_next()
		"fight_dogs":
			var alive := dogs.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
			if v("MQ101_DOG") >= 2 or (alive.is_empty() and v("MQ101_DOG") == 1 and not dogs.is_empty()):
				host.combat.bot = {}
				if v("MQ101_DOG") >= 2:
					_next()
				return
			if alive.is_empty():
				return
			route = []
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			if not touch_bot:
				host.combat.bot = {"aim": alive[0].loco.logical + Vector2(0, -12), "fire": true, "aimed": true}
			if wait_t <= 0.0:
				_shot("dogs")
				wait_t = 99.0
		"drink":
			host._pip_action("use", "I-057")
			_next()
		"equip":
			host._pip_action("equip", str(job[1]))
			_next()
		"caps":
			st.vars.set_v("PC_CAPS", maxi(v("PC_CAPS"), int(job[1])))
			_next()
		"board":
			host.player.loco.facing = 6
			host.player._show()
			host.play_scene("X-BC_BOARD")
			_next()
		"wait_night":
			if v("MQ101_NIGHT") == 2:
				_next()
		"battle":
			if v("MQ101_RESULT") != 0:
				host.combat.bot = {}
				_next()
				return
			var alive := host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team == "enemy")
			route = []
			host.input_fn = func() -> Vector2: return Vector2.ZERO
			if alive.is_empty():
				host.combat.bot = {}
				if log_on and int(t) % 4 == 0 and int(t - dt) % 4 != 0:
					print("  전투 대기: fight %s · 적 %d · 남은 적 %d · FIGHT %d" % [fight, foes.size(), host.combat.enemies.size(), v("MQ101_FIGHT")])
				return
			alive.sort_custom(func(a, b): return a.loco.logical.distance_to(host.player.loco.logical) < b.loco.logical.distance_to(host.player.loco.logical))
			if log_on and int(t * 2.0) % 4 == 0 and int((t - dt) * 2.0) % 4 != 0:
				print("  전투 %.0f초: 나 %.0f · 감시조 %s · 적 %s" % [t, host.combat.pc.hp, str(host.combat.allies.map(func(a): return int(a["cmb"].hp))),
					str(alive.map(func(e): return "%s %d/%d %s" % [e.get_meta("enemy_id"), int(e.cmb.hp), int(e.cmb.max_hp), AIBrain.S.keys()[e.brain.state]]))])
				var other := host.combat.enemies.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and e.cmb.team != "enemy")
				if not other.is_empty():                                            # 진단: 다른 편(경비 · 정착지 · 무명)도 함께 — 보이지 않는 공격자 찾기
					print("    다른 편: %s" % str(other.map(func(e): return "%s[%s] %d %s 거리%.0f" % [e.get_meta("enemy_id"), e.cmb.team, int(e.cmb.hp),
						AIBrain.S.keys()[e.brain.state], e.loco.logical.distance_to(host.player.loco.logical) / 32.0])))
			if not touch_bot:
				host.combat.bot = {"aim": alive[0].loco.logical + Vector2(0, -12), "fire": true, "aimed": true,
				"reload": host.combat.mags.get(host.combat.weapon_id, 1) == 0, "stim": host.combat.pc.hp < host.combat.pc.max_hp * 0.4}
			if int(t * 2.0) % 9 == 0 and int((t - dt) * 2.0) % 9 != 0:
				_shot("battle")
		"wait_morning":
			if v("MQ101_NIGHT") == 3 and host.map.id == "B-01":
				_next()
		"shot":
			_shot(str(job[1]))
			_next()
		"end":
			done = true
			print("MQ-101 완료: 해법 %d · 결과 %d · 카르마 %d · 봉천 %d · 새벽 %d · 판도 봉천 %d · R01 %d · 감시조 사망 %d · 수배 %d · 백구 %d · 캡 %d · XP %d · MQ-102 %d" % [
				sol, v("MQ101_RESULT"), v("V_KARMA"), v("AFF_JC_BC"), v("AFF_SB"), v("PD_BC"), v("PD_R01"), v("MQ101_DEAD"),
				v("V_WANTED"), v("MQ101_DOG"), v("PC_CAPS"), v("PC_XP"), st.quests.stage("MQ-102")])
			print("해법 증거: 게시판=%s | 사는 값=%d | 첫마디=%s" % [BOARD_STATE.get(v("MQ101_RESULT"), "?"), _ev_price, _ev_greet.replace("\n", " ")])
			get_tree().create_timer(0.6).timeout.connect(get_tree().quit)


## 거래 창(봇): 파는 쪽 첫 줄 하나를 팔고, 스팀팩을 하나 산 뒤 닫는다
func _bot_trade(t: TradeScreen, dt: float) -> void:
	hold += dt
	if hold < 1.0:
		return
	hold = 0.0
	var step := int(t.get_meta("bot_step", 0))
	t.set_meta("bot_step", step + 1)
	if touch_bot:
		_trade_taps(t, step)
		return
	match step:
		0:                                                             # 바구니에 담는다(잡동사니만 판다 — 총·탄은 남긴다)
			var sell := t._list(0).filter(func(id): return id in ["W-067", "M-010", "M-046", "M-002"])
			if not sell.is_empty():
				t.offer(0, str(sell[0]))
			if t.state["items"].has("I-001"):
				t.offer(1, "I-001")
			t.view.queue_redraw()
		1:                                                             # 담은 모습(화면 찍기는 프레임 끝에 된다 — 확정은 다음 차례)
			_shot("trade")
		2:
			if not t.confirm():
				t.cart = [{}, {}]
			print("거래 %s: 오간 캡 %d · 스팀팩 사는 값 %d · 내 캡 %d" % [t.vid, t.total, t.price("I-001", true), v("PC_CAPS")])
			if st.quests.stage("MQ-101") >= 100:
				_ev_price = t.price("I-001", true)
		_:
			t.close(true)


## 터치 거래: 스팀팩 줄을 누르고(고르기) 다시 누르고(담기) → 찍기 → 거래 확정 두 번 → 닫기
func _trade_taps(t: TradeScreen, step: int) -> void:
	var at := func(id: String) -> Vector2:
		for it in t.items:
			if str(it["id"]) == id:
				return t.view.position + (it["rect"] as Rect2).get_center()
		return Vector2(-1, -1)
	var row := "row1_%d" % t._list(1).find("I-001")
	match step:
		0, 1:
			if t._list(1).has("I-001"):
				_tap(at.call(row))
		2:
			_shot("trade")
		3, 4:
			_tap(at.call("confirm"))
		5:
			print("거래 %s(터치): 오간 캡 %d · 내 캡 %d" % [t.vid, t.total, v("PC_CAPS")])
			_tap(at.call("close"))
		_:
			if is_instance_valid(t):
				t.close(true)


func _next() -> void:
	plan_i += 1
	wait_t = 0.0
	stuck_t = 0.0
	route = []
	host.input_fn = _bot_input


## 지금 맵에서 목표 맵으로 가는 출구 칸으로 걷는다
func _exit_toward(to: String) -> void:
	for c in host.map.exits:
		if str(host.map.exits[c]["to"]) == to:
			if route.is_empty() or route[0] != [_here(), c.x, c.y]:
				route = [[_here(), c.x, c.y]]
				route_i = 0
				path = PackedVector2Array()
			return


## 인물에게 다가가 말을 건다(옆 칸에 서서 바라보고 조사 키)
func _talk(id: String) -> void:
	var a: Actor = host.ev.actors.get(id)
	if a == null or not is_instance_valid(a):
		return
	var me := host.player.loco.render
	if me.distance_to(a.loco.logical) > 40.0:
		var goal := host.map.tile_of(a.loco.logical)
		var best := Vector2i(-1, -1)
		for d in [Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			var c: Vector2i = goal + d
			if not host.map.is_solid(c) and host.map.level_link(c, goal) and (best.x < 0 or me.distance_to(Vector2(c * 32) + Vector2(16, 16)) < me.distance_to(Vector2(best * 32) + Vector2(16, 16))):
				best = c
		if best.x >= 0 and (route.is_empty() or route[0] != [_here(), best.x, best.y]):
			route = [[_here(), best.x, best.y]]
			route_i = 0
			path = PackedVector2Array()
		return
	host.player.loco.facing = Locomotion.snap8(a.loco.logical - host.player.loco.logical, 0.0)
	host.player._show()
	if touch_bot:
		if host.interact_label() == "말하기" and _tap_q.is_empty() and not _fing.has(0):
			_tap(_btn_center("act"))                                     # 터치: 상황 단추 '말하기'
			_next()
		return
	if host.interact():
		_next()


func _stuck_check(dt: float) -> void:
	var p := host.player.loco.render
	if p.distance_to(_last_p) < 0.5:
		stuck_t += dt
	else:
		stuck_t = 0.0
	_last_p = p
	if stuck_t > 8.0:
		done = true
		print("MQ-101 봇: 막힘 — %s %s 할 일 %d %s" % [host.map.id, host.map.tile_of(p), plan_i, plan[plan_i]])
		get_tree().create_timer(0.5).timeout.connect(get_tree().quit)


func _walk_check(dt: float) -> void:
	var p := host.player.loco.render
	if p.distance_to(_last_p) < 0.5 and not host.box.active and not host.busy:
		stuck_t += dt
	else:
		stuck_t = 0.0
	_last_p = p
	if log_on and int(t) % 3 == 0 and int(t - dt) % 3 != 0:
		var c := host.map.tile_of(p)
		print("[%3.0f초] %s 칸 %s 높이 %d 지점 %d/%d" % [t, host.map.id, c, host.map.level_at(c), route_i, route.size()])
	if route_i >= route.size():
		done = true
		print("MQ-101 봇: 지점 %d개 끝 — %s %s" % [route.size(), host.map.id, host.map.tile_of(p)])
		get_tree().create_timer(0.5).timeout.connect(get_tree().quit)
	elif stuck_t > 6.0:
		done = true
		print("MQ-101 봇: 막힘 — %s %s 지점 %d %s" % [host.map.id, host.map.tile_of(p), route_i, route[route_i]])
		get_tree().create_timer(0.5).timeout.connect(get_tree().quit)


func _shot(tag: String) -> void:
	if shots == "":
		return
	await RenderingServer.frame_post_draw
	host.get_viewport().get_texture().get_image().save_png("%s/sol%d_%s.png" % [shots, sol, tag])
