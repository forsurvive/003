## 세력 퀘스트 FQ-JC-01 「계단 물길」 진행기(단계 1-12a, SD-04d §10.3). 원고: script/act1/FQ-JC-01.txt · MQ-101.txt X-BC_BOARD(JCN) · SQ-S02.txt(수위 갈래).
## 발동: MQ-101이 끝난 날 + 4일 06시 하루 판정에 신림 고시원 7동 물당번들의 흙막이가 생긴다(CUT = 그날). S02와 따로 선다(재미 검수 F4).
## 배수지 수위는 S02 진행기 level() 한 곳이 min(윗물, 빗물)로 셈(SD-20 P1) — 이 진행기는 물길 사실(FLOW · CRACK)만 바꾼다.
## 단계: 10 앎(게시판 · 조만석 · 조담희 · 홈통 · 흙막이를 먼저 봄) · 20 백구가 앞장 · 갈림을 맞게 읽음 · 30 흙막이를 봄 · 40 유입구 균열 · 100 보고.
## 악당 · 습격 없음(재미 검수 F6 — 원문의 남부순환 보복 습격은 쓰지 않는다). 백구 일시 동행은 SQ-S01과 같은 규칙(맞으면 달아남 · 20% 아래면 물러남 · 일을 마치면 개집으로).
class_name FqJc01
extends Node

signal want_save(why: String)

const QID := "FQ-JC-01"
const ARM_DAYS := 4                       ## MQ-101 끝난 날 + 4일 06시
const DOG_RETREAT := 0.2
const NEST_X := 12                        ## K-08 암거 입구 쪽 둥지 쥐(이 칸보다 서쪽에 선 CR-095)

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _hit_hooked: Combatant = null
var _nest: Array = []                     ## 지금 맵(K-08)에 선 둥지 쥐
var _nest_seen := false
var _hr := -1                             ## 지금 시(K-08 새벽 물당번을 시각 바뀔 때 다시 세운다)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["jc01"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)


func v(k: String) -> int:
	return int(st.vars.get_v("FQ_JC01_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("FQ_JC01_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[계단 물길] " + s)


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func stage() -> int:
	return st.quests.stage(QID)


func _up(n: int) -> void:
	if stage() < n and stage() < 100:
		st.quests.set_stage(QID, n)
		_log("단계 %d" % n)


func _zone() -> String:
	return host.map.id if host.map != null else ""


## 퀘스트를 연다(어디서 먼저 알았든) — 이미 한 일은 따라 올린다(SD-20 P2 '이미 함')
func start() -> void:
	if v("CUT") == 0:
		return
	_up(10)
	if v("DOG") in [1, 5] or v("FORK1") == 1 or v("FORK2") == 1:
		_up(20)
	if v("SEEN") == 1 or v("FLOW") > 0:
		_up(30)
	if v("LEAK") == 1:
		_up(40)


# ---------------------------------------------------------------- 시간 · 하루 판정
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	tick()


func tick() -> void:
	if st.quests.stage("MQ-101") >= 100 and v("ARM") == 0:
		_sv("ARM", day())                                                # MQ-101이 끝난 날
	_dog_tick()
	if _zone() == "K-08":
		_nest_tick()
		var hr := int(st.vars.get_v("GAME_HOUR"))
		if hr != _hr and not host.box.active and not host.ev.busy():
			if _hr >= 0 and (hr == 3 or hr == 6):
				host.refresh_npcs()                                      # 03시에 물당번이 오고 06시에 교대로 떠난다(근무표)
			_hr = hr
	_orphan_done()


func _on_day(d: int) -> void:
	if v("ARM") > 0 and v("CUT") == 0 and d >= v("ARM") + ARM_DAYS and int(st.vars.get_v("V_ACT")) >= 1:
		_sv("CUT", d)                                                    # 7동 물당번의 흙막이 — 봉천 호감과 무관한 사실(조만석의 부탁만 호감을 본다)
		_log("흙막이가 생김(%d일)" % d)


func _on_map(id: String) -> void:
	_nest.clear()
	_nest_seen = false
	_hr = -1
	if id == "K-08":
		_props_k08()
	elif id == "X-BS" and v("FLOW") > 0 and v("CRACK") == 0 and v("LEAK") == 0:
		_sv("LEAK", 1)                                                   # 물이 돌자 유입구 이음매가 샌다 — 배수지에 들어서면 들린다(단계 40)
		start()
		host.hint("배수지 한쪽에서 쉭쉭 물 새는 소리. 계곡 수로 유입구 쪽이다.", 5.0)


## K-08 소품 상태(맵에 들 때 한 번): 흙막이 · 물통 줄 · 분배함 · 둥지
func _props_k08() -> void:
	if v("CUT") == 0:
		return
	var f := v("FLOW")
	host.map.set_prop_state(Vector2i(6, 4), ["", "filled", "split"][f] if v("NEST") != 2 or f > 0 else "breach")
	host.map.set_prop_state(Vector2i(3, 3), ["", "dry", "half"][f])
	host.map.set_prop_state(Vector2i(8, 3), "open" if f == 2 else "")
	host.map.set_prop_state(Vector2i(9, 7), ["", "empty", "drowned"][v("NEST")])


## 둥지 쥐 셋: 모두 쓰러지면 NEST 1(처치). 맵이 세운 적 가운데 입구 쪽 CR-095를 센다
func _nest_tick() -> void:
	if v("NEST") != 0 or v("CUT") == 0:
		return
	if not _nest_seen:
		_nest_seen = true
		for e in host.combat.enemies:
			if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-095" and host.map.tile_of(e.loco.logical).x < NEST_X:
				_nest.append(e)
		return
	if _nest.is_empty():
		return
	for e in _nest:
		if is_instance_valid(e) and not e.cmb.dead:
			return
	_sv("NEST", 1)
	host.map.set_prop_state(Vector2i(9, 7), "empty")
	_log("둥지 처치")


# ---------------------------------------------------------------- 백구(일시 동행)
func _dog_mate() -> Dictionary:
	return host.combat.mates.get_mate("C-015")


func _dog_tick() -> void:
	if v("DOG") == 5 and v("FLOW") > 0:
		_sv("DOG", 3)                                                    # 앞장선 길잡이: 물길이 돌자 개집으로(동행 칸을 쓰지 않았다)
		return
	if v("DOG") != 1:
		return
	var m := _dog_mate()
	if m.is_empty():
		return
	var cmb: Combatant = m["cmb"]
	if _hit_hooked != cmb:
		_hit_hooked = cmb
		cmb.hit.connect(func() -> void:
			if cmb.last_by == "player" and v("DOG") == 1:
				_betray())
	if m["down"] or cmb.hp <= cmb.max_hp * DOG_RETREAT:
		_dog_away(2, "백구가 짖으며 물러난다. 다리를 끌며 마을 쪽으로 달려간다.")
	elif v("FLOW") > 0 and host.map is WorldMap and _zone() == "X-BC":
		_dog_away(3, "백구가 312계단 홈통에 코를 대 보고는 개집으로 돌아가 몸을 만다.")


func _betray() -> void:
	_sv("BETRAY", 1)
	st.call_fn("aff", ["JC_BC", -10])
	st.call_fn("karma", [-25])
	_dog_away(4, "백구가 비명을 지르고 마을 쪽으로 달아난다.")
	_log("백구를 때림(봉천 −10 · 카르마 −25)")


## 백구를 동행에서 떼어 마을로. 몸은 감추고, 개집 자리는 맵 조건(FQ_JC01_DOG != 1)이 다시 세운다
func _dog_away(state: int, text: String) -> void:
	var m := _dog_mate()
	_sv("DOG", state)
	if not m.is_empty():
		var a: Actor = m["actor"]
		host.combat.mates.remove("C-015")
		host._sync_mates()
		if is_instance_valid(a):
			host.map.blockers.erase(a)
			host.map.remove_actor(a)
			if host.ev.actors.get("C-015") == a:
				host.ev.actors.erase("C-015")
			a.queue_free()
	host.combat.mates.away.erase("C-015")
	_hit_hooked = null
	host.hint(text, 5.0)
	if host.map is WorldMap and _zone() == "X-BC":
		host.refresh_npcs()
	_log("백구 동행 끝(%d)" % state)


func _dog_join() -> void:
	if st.is_dead("C-015"):
		return
	var b: Actor = host.ev.actors.get("C-015")
	_sv("DOG", 1)
	if b != null:
		for n in host.npcs.duplicate():                                   # 맵 인물에서 떼어 낸다(맵 조건이 거짓이 돼도 다시 세울 때 치우지 않게)
			if n["actor"] == b:
				host.npcs.erase(n)
		host.sync_residents()
		host.ev.handlers["buddy"].call(["C-015"], func() -> void: pass)
	if _dog_mate().is_empty():                                           # 동행이 이미 둘(상한, 1-10a): 동행 칸 없이 먼저 계곡 쪽으로 달려 나간다
		_sv("DOG", 5)
		if b != null and is_instance_valid(b):
			host.map.blockers.erase(b)
			host.map.remove_actor(b)
			if host.ev.actors.get("C-015") == b:
				host.ev.actors.erase("C-015")
			b.queue_free()
		host.hint("백구가 먼저 아랫문으로 달려 나간다. 계곡 암거 앞에서 기다리겠다는 얼굴이다.", 5.0)
	start()
	_up(20)
	_log("백구 %s" % ("동행" if v("DOG") == 1 else "앞장"))


# ---------------------------------------------------------------- 물길 · 균열 · 끝
func _fill() -> void:
	if v("FLOW") != 0:
		return
	_sv("FLOW", 1)
	st.call_fn("karma", [-10])                                           # 7동 물통이 마른다(SD-04d 확정안 — 손해가 있는 선택, 재미 검수 F10)
	start()
	_up(30)
	_props_k08()
	_log("다 메움(카르마 −10)")
	want_save.emit("flow")


func _split() -> void:
	if v("FLOW") != 0:
		return
	_sv("FLOW", 2)                                                       # UQ-62 신림 고시촌 이야기에 넘길 '나눔' 사실(FLOW 2 하나)
	_sv("GIFT", day())                                                   # 다음 날부터 7동 물통 줄에 보답 꾸러미(재미 검수 — 나눔의 값)
	st.call_fn("karma", [25])
	start()
	_up(30)
	_props_k08()
	_log("분배 밸브로 나눔(카르마 +25)")
	want_save.emit("flow")


## 새벽 물당번이 설득돼 스스로 흙막이를 거둠: 물길은 메움과 같고(봉천 다섯) · 7동이 알고 물러났으니 카르마는 덜 깎인다
func _yield() -> void:
	if v("FLOW") != 0:
		return
	_sv("FLOW", 1)
	_sv("KNOW", 1)
	st.call_fn("karma", [-5])
	start()
	_up(30)
	_props_k08()
	_log("물당번이 거둠(카르마 −5)")
	want_save.emit("flow")


func _breach() -> void:
	if v("NEST") != 0:
		return
	_sv("NEST", 2)                                                       # 물을 웅덩이로 쏟아 둥지를 쓸어 버림 — 싸움 없이
	if _zone() == "K-08":
		host.combat.refresh_enemies(st)                                  # 맵 조건(NEST == 0)이 거짓이 된 둥지 쥐를 뺀다
	_nest.clear()
	_props_k08()
	if v("FLOW") == 0:
		host.map.set_prop_state(Vector2i(6, 4), "breach")
	_log("둥지가 떠내려감")


func _fix() -> void:
	if v("CRACK") != 0:
		return
	_sv("CRACK", 1)
	start()
	if v("FLOW") > 0:
		_up(40)                                                          # 새는 걸 보고 고쳤다 — 40을 지나 끝 보고만 남는다
	_log("유입구 균열 고침")


func _done() -> void:
	if stage() >= 100:
		return
	var cold := int(st.vars.get_v("AFF_JC_BC")) <= -20                   # 봉천과 적대: 물길은 고친 사실 · 사례만 없다(계획 §2-16)
	st.call_fn("aff", ["JC_BC", 8 if v("FLOW") == 2 else 12])          # 나눔: 반상회가 덜 기뻐한다(재미 검수 F10 — 원문 +12는 메움 몫)
	st.call_fn("xp", [250])
	if not cold:
		st.call_fn("caps", [50])
		if v("FLOW") == 1:
			st.call_fn("give", ["I-056", 2])                             # 메움: 반상회가 따로 챙겨 둔 약수 두 병
		if int(st.vars.get_v("AFF_JC_BC")) >= 20 and v("REWARD") == 0:
			_sv("REWARD", 1)                                             # 봉천 우호: 이장님의 엽총(W-101 고유) · 계단마을 증표(M-136)
			st.call_fn("give", ["W-101", 1])
			st.call_fn("give", ["M-136", 1])
	_sv("DONE", day())
	st.quests.set_stage(QID, 100)
	_log("끝(%s · 물길 %d)" % ["사례 없음" if cold else "사례", v("FLOW")])
	want_save.emit("done")


## 조만석도 하숙자도 없으면 보고할 데가 없다 — 물길과 균열이 다 되면 그대로 끝(반상회관 문 앞 보따리, P10)
func _orphan_done() -> void:
	if stage() >= 10 and stage() < 100 and v("FLOW") > 0 and v("CRACK") == 1 and st.known_dead("C-010") and st.known_dead("C-057"):
		host.hint("반상회관 문 앞에 보따리 하나. 쪽지 '물 고마워요 — 계단마을'.", 6.0)
		_done()


# ---------------------------------------------------------------- 원고 명령(@cmd jc01 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"start":
			start()
		"board":                                                       # 게시판 쪽지 + 빗물 당번표(백구 없이 갈림을 읽는 길)
			if v("POSTED") == 0:
				_sv("POSTED", 1)
			_sv("ROSTER", 1)
			start()
		"told":
			_sv("POSTED", 2)
			start()
		"spout":
			_sv("SPOUT", 1)
			start()
		"dog":
			_dog_join()
		"perc":
			_sv("PERC", 1)
		"fork1":
			_sv("FORK1", int(a[1]))
			start()
			if int(a[1]) == 1:
				_up(20)
		"fork2":
			_sv("FORK2", int(a[1]))
			start()
			if int(a[1]) == 1:
				_up(20)
		"shelter":
			_sv("SHELTER", 1)
			_sv("KNOW", 1)
		"know":
			_sv("KNOW", 1)
		"talk":                                                        # 새벽 물당번과 마주침 — 누가 막았는지 안다 · 흙막이를 본 것과 같다
			_sv("TALK", 1)
			_sv("KNOW", 1)
			_sv("SEEN", 1)
			start()
			_up(30)
		"yield":
			_yield()
		"flee":                                                        # 근무표대로 철수 — 그날 밤엔 다시 오지 않는다
			_sv("SAID", int(st.vars.get_v("GAME_DAY")))
			host.refresh_npcs()
		"gift":
			_sv("GIFT", -1)
		"seen":
			_sv("SEEN", 1)
			start()
			_up(30)
		"fill":
			_fill()
		"split":
			_split()
		"breach":
			_breach()
		"leak":
			_sv("LEAK", 1)
			start()
			_up(40)
		"fix":
			_fix()
			_orphan_done()
		"done":
			_done()
	done.call()
