## 1-13a3 깡철이 보스전(SD-14 CR-512 §10.2 · §10.3 · SD-09a L-R01-15 · 계획 docs/seoul-fallout/_plans/1-13_closing_plan.md §4). 원고: script/act1/KC.txt.
## 신림 사거리 고가 아래 그늘 마당(월드 손 자리 @820,1349)에 깡철이 · 사슬에 묶인 경비견 · 드럼불 졸개를 세운다(마당 40칸 안 · 60칸 밖이면 거둔다).
## 사실은 변수 한 곳(SD-20 P1): KC_STATE 0 그대로 · 2 놓아줌(말로 물러나게 한 것 포함 — KC_TALK 1) · 3 헬멧을 벗겨 놓아줌 · 4 죽음 ·
##   KC_DAY 결말 날 · KC_DOGS 죽은 경비견 수 · KC_LOOSE 사슬 고리를 빼 개가 흩어짐 · KC_TOLL 통행세 낸 날 · KC_BOUNTY 현상금 받음 · KC_HELM 고물상 진열 ·
##   KC_BALD 맨머리 소문 날 · KC_FOUGHT 마지막으로 싸운 날(그날 다시 오면 말 없이 싸움 · 깎인 HP 그대로 KC_HPF %, 다음 날부터 통행세 두 배) ·
##   KC_GCSAID 고시촌 문지기가 부두목 죽음을 한 번 말함.
## 재미 검수(구현 뒤): 웅크려 다가가면 먼저 말을 걸지 않는다(3칸 — 말뚝까지 숨어 갈 수 있게) · 놓아줌 카르마 +10 · 결말별 바크(엔진 '고맙다' 대신).
## 국면(밸런스 조율사 2026-10-23): ① 싸움이 붙으면 사슬을 푸는 2초 동안 깡철이는 쏘지 않는다 → 경비견 셋 ② HP 70%(문턱 고정)에서 동쪽 램프 윗단
##   (두 층이 만나는 칸 — 층이 다르면 탄이 안 맞는다, D-002)으로 올라 사냥총 ③ 자리를 잡은 뒤 HP 40%(문턱 고정 — 한 방에 넘지 않는다)에서 항복.
##   졸개(CR-424 ×2 · CR-423, 밤 + CR-420)는 12칸 밖 드럼불에서 총소리를 듣고 온다 · 새벽엔 졸고 있다.
## 퍽 없이 개를 빼는 길: 사슬 말뚝 고리(은신) · 애니멀 프렌드(PK-045): 경비견이 주인공 곁에 앉는다 → 깡철이 혼자 남아 바로 항복 · 졸개는 무기를 내리고 물러난다.
## 항복한 깡철이에게 말 걸기(조사 키) → 놓아줌 · 헬멧을 벗겨 감 · 쏨. 항복 순간 XP 40(한 번) — 그 뒤 쏘아도 XP는 없고 카르마 −10(엔진 사기 규칙).
class_name KcBoss
extends Node

const YARD := Vector2i(838, 1351)         ## '지부장 자리'(고철 의자 앞 칸)
const STAKE := Vector2i(834, 1352)        ## 사슬 말뚝
const RAMP := Vector2i(853, 1345)         ## 동쪽 램프 윗단(월드 고가 — 땅과 상판이 만나는 칸)
const CAMP := Vector2i(823, 1352)         ## 드럼불 야영(깡철이에서 15칸)
const SPAWN_R := 40.0
const DESPAWN_R := 60.0
const MEET_R := 7.0                        ## 다가가면 깡철이가 먼저 말을 건다
const MEET_SNEAK := 3.0                    ## 웅크려 다가가면 이만큼 와서야 알아챈다(말뚝은 의자에서 4칸)
const LINGER_R := 3.0                      ## 통행세를 거절하고 이만큼 붙어 3초 버티면 싸움
const STAGE_HP := 0.7
const GIVE_HP := 0.4
const UNCHAIN_S := 2.0
const TOLL := 30
const HELM_DAYS := 3                       ## 놓아준 뒤 사흘이면 봉천 고물상에 헬멧이 걸린다(SD-09a)

var host: InteriorHost
var st: StoryState
var log_on := false
var on := false
var kc: Enemy = null
var dogs: Array = []
var gang: Array = []
var phase := 0                             ## 0 마주침 전 · 1 싸움(사슬 풀기) · 2 램프로 · 3 램프에서 사격 · 4 항복 · 5 끝
var met := false
var refused := false
var _linger := 0.0
var _unchain := 0.0
var _fight_t := 0.0
var _dash_t := 0.0
var _t := 0.0


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["kc"] = _cmd
	host.interact_pre.append(_interact)
	host.map_entered.connect(func(_id = "") -> void: _drop_refs())


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[깡철이] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func _px(t: Vector2i) -> Vector2:
	return Vector2(t.x * 32 + 16, t.y * 32 + 16)


func _safe() -> bool:
	return not host.box.active and not host.ev.busy() and not host.busy and not host.combat.in_combat()


func _alive(e) -> bool:
	return e != null and is_instance_valid(e) and not e.cmb.dead


## 맵이 바뀌면 세운 몸들은 맵과 함께 사라진다 — 참조만 놓는다
func _drop_refs() -> void:
	kc = null
	dogs.clear()
	gang.clear()
	on = false
	phase = 0


func _process(dt: float) -> void:
	if host.map == null:
		return
	_t += dt
	if _t < 0.25:
		return
	var step := _t
	_t = 0.0
	tick(step)


func tick(step: float = 0.25) -> void:
	_helm_shop()
	if not (host.map is WorldMap) or v("V_ACT") < 1:
		return
	var d := host.player.loco.logical.distance_to(_px(YARD)) / 32.0
	if d <= SPAWN_R and not on:
		_spawn()
	elif d > DESPAWN_R and on and not host.combat.in_combat():
		_clear()
	if not on or not _alive(kc):
		return
	match phase:
		0:
			_calm_tick(step)
		1, 2, 3:
			_fight_tick(step)


# ---------------------------------------------------------------- 세우기 · 거두기
func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("KC:%d:%d" % [Clock.abs_min(host.date_text) / 60, v("KC_DOGS")])   # 같은 때 다시 오면 같은 자리 — 때가 바뀌면 다른 방향 · 자리(SD-22)
	return r


func _near(c: Vector2i, r: RandomNumberGenerator, dx: int, dy: int) -> Vector2:
	for _i in 20:
		var t := c + Vector2i(r.randi_range(-dx, dx), r.randi_range(-dy, dy))
		if not host.map.is_solid(t):
			return _px(t)
	return _px(c)


func _spawn() -> void:
	on = true
	met = false
	refused = false
	phase = 0
	dogs.clear()
	gang.clear()
	kc = null
	if v("KC_STATE") != 0:
		_log("빈 마당(결말 %d)" % v("KC_STATE"))
		return
	var again := v("KC_FOUGHT") > 0 and v("KC_FOUGHT") == day()                   # 그날 싸웠던 사람이 돌아왔다                                                           # 놓아줬거나 죽었다 — 마당은 식은 드럼불과 빈 의자만(손 자리 소품)
	var r := _rng()
	var h := Clock.hour(host.date_text)
	kc = host.combat.spawn("CR-512", _px(YARD), host.map, st, {"dir": ["S", "SW", "SE"][r.randi() % 3], "stance": "hold", "who": "N-R01-061"})
	kc.cmb.hp_floor = kc.cmb.max_hp * STAGE_HP                          # 국면 문턱 고정: 램프에 닿기 전엔 70% 아래로 내려가지 않는다
	_calm(kc)
	_hook(kc)
	if again and v("KC_HPF") > 0:
		kc.cmb.hp = maxf(kc.cmb.hp_floor, kc.cmb.max_hp * v("KC_HPF") / 100.0)       # 깎인 HP는 그날 그대로(하루 쉬면 낫는다)
	if v("KC_LOOSE") == 0:
		for i in maxi(0, 3 - v("KC_DOGS")):
			var dg := host.combat.spawn("CR-105", _near(STAKE, r, 1, 1), host.map, st, {"dir": ["N", "E", "W", "S"][r.randi() % 4], "stance": "hold"})
			dg.set_meta("kc_dog", true)
			if str(dg.cmb.team) == "enemy":
				_calm(dg)                                                # 사슬에 묶여 있다(애니멀 프렌드면 이미 우호 — 그대로 둔다)
			_hook(dg)
			dogs.append(dg)
	var kinds := ["CR-424", "CR-424", "CR-423"]
	if h >= 20 or h < 4:
		kinds.append("CR-420")                                         # 밤: 드럼불 곁 보초 하나 더(+50% — 밸런스 조율사 '+1까지')
	var doze := h >= 4 and h < 6                                       # 새벽: 반은 졸고 있다
	for i in kinds.size():
		var opts := {"dir": ["N", "E", "W", "S", "NE", "SW"][r.randi() % 6]}
		if doze and i % 2 == 0:
			opts["sleep"] = true
		var g := host.combat.spawn(str(kinds[i]), _near(CAMP, r, 2, 1), host.map, st, opts)
		_calm(g)
		_hook(g)
		gang.append(g)
	_log("깡철이 · 개 %d · 졸개 %d(%d시)" % [dogs.size(), gang.size(), h])
	if again:
		met = true
		kc.say_text = "또 왔냐. 풀어!"
		kc.say_t = 2.0
		_fight("그날 다시")


func _calm(e: Enemy) -> void:
	e.cmb.team = "calmkc"
	e.foes.clear()


func _hostile(e: Enemy) -> void:
	if not _alive(e):
		return
	e.cmb.team = "enemy"
	e.foes = ["player", "ally"]
	e.wake()


func _hook(e: Enemy) -> void:
	e.cmb.hit.connect(func() -> void:
		if e.cmb.last_by == "player" and phase == 0:
			_fight("맞음"))
	e.cmb.died.connect(func() -> void: _on_killed(e))


func _clear() -> void:
	if phase >= 1 and phase <= 3 and _alive(kc):
		st.vars.set_v("KC_HPF", roundi(kc.cmb.hp / kc.cmb.max_hp * 100.0))   # 싸우다 떠났다 — 그날 다시 오면 이 HP로
	for e in [kc] + dogs + gang:
		if _alive(e):
			host.combat.drop_enemy(e)
	_drop_refs()
	_log("거둠")


# ---------------------------------------------------------------- 마주침(국면 0)
func _calm_tick(step: float) -> void:
	var d := host.player.loco.logical.distance_to(kc.loco.logical) / 32.0
	var reach := MEET_SNEAK if host.combat.crouch else MEET_R
	if not met and d <= reach and _safe():
		met = true
		host.play_scene("KC_MEET")
		return
	if refused and not (v("KC_TOLL") > 0 and v("KC_TOLL") == day()) and d <= LINGER_R and _safe():
		_linger += step
		if _linger >= 3.0:
			_fight("버팀")
	else:
		_linger = 0.0


## 싸움이 붙었다
func _fight(why: String) -> void:
	if phase != 0 or not _alive(kc):
		return
	phase = 1
	_fight_t = 0.0
	st.vars.set_v("KC_FOUGHT", day())
	_log("싸움(%s)" % why)
	var sitting := dogs.filter(func(dg): return _alive(dg) and not str(dg.cmb.team).begins_with("calmkc"))
	if v("PK_045") >= 1 and not sitting.is_empty():                    # 애니멀 프렌드: 개들은 우호 그대로 — 주인공 곁에 앉는다
		for k in sitting.size():
			var dg: Enemy = sitting[k]
			dg.start_dash(host.player.loco.logical + Vector2(-40 + 40 * k, 36))   # 주인공 곁으로 가서 앉는다
			dg.cmb.dr -= dg._dash_dr
			dg._dash_dr = 0.0
		kc.say_text = "…이 배신자들."
		kc.say_t = 2.5
		host.hint("경비견들이 사슬을 끌고 깡철이에게서 물러나 당신 쪽에 엎드린다.", 5.0)
		st.call_fn("xp", [30])                                           # 해법 XP(개 셋 처치 몫 — 퍽을 고른 사람이 덜 받지 않게)
		_surrender()
		for g in gang:
			if _alive(g):
				g.flee_now(host.player.loco.logical, 25.0)              # 졸개는 무기를 내리고 물러난다
		return
	_unchain = UNCHAIN_S
	kc.say_text = "풀어!"
	kc.say_t = 1.5
	host.hint("깡철이가 사슬을 푼다 — 경비견이 달려든다.", 3.0)
	for dg in dogs:
		_hostile(dg)
	for g in gang:
		_hostile(g)


# ---------------------------------------------------------------- 싸움(국면 1~3)
func _fight_tick(step: float) -> void:
	_fight_t += step
	if phase == 1:
		if _unchain > 0.0:
			_unchain -= step
			if _unchain <= 0.0:
				_hostile(kc)                                             # 사슬을 다 풀고 나서야 총을 든다(첫 국면 몰림 완화)
			return
		var dogs_left := dogs.filter(func(dg): return _alive(dg) and dg.cmb.team == "enemy").size()
		if kc.cmb.hp <= kc.cmb.max_hp * STAGE_HP + 0.5 or (dogs_left == 0 and _fight_t > 8.0):
			phase = 2
			_dash_t = 0.0
			kc.start_dash(_px(RAMP))
			kc.cmb.dr -= kc._dash_dr                                    # 진행기 달리기의 DR +25는 금고로 뛰는 황두칠 몫 — 깡철이는 맨몸으로 뛴다
			kc._dash_dr = 0.0
			kc.say_text = "위로 올라간다!"
			kc.say_t = 1.5
			_log("램프로(%.0f초)" % _fight_t)
	elif phase == 2:
		_dash_t += step
		if kc.has_meta("dash_done") or _dash_t > 12.0:
			kc.end_dash()
			kc.fixed = true                                              # 램프 윗단에서 버티며 쏜다(붙으면 렌치)
			kc.cmb.hp_floor = kc.cmb.max_hp * GIVE_HP
			phase = 3
			_log("램프 자리(%.0f초)" % _fight_t)
	elif phase == 3:
		if kc.cmb.hp <= kc.cmb.max_hp * GIVE_HP + 0.5:
			_surrender()


func _surrender() -> void:
	phase = 4
	kc.fixed = false
	kc.end_dash()
	kc.brain.surrender()
	kc.set_meta("surrendered", true)
	kc.set_meta("xp_given", true)                                       # 항복 뒤에 쏘아도 처치 XP는 없다(조율사 ⑦)
	kc.cmb.hp_floor = 0.0
	kc.say_text = "그만! 그만, 손 들었어!"
	kc.say_t = 3.0
	st.call_fn("xp", [40])                                              # SD-14 CR-512 XP 40 — 항복하는 순간 한 번(조율사 ⑦)
	for e in dogs + gang:
		if _alive(e) and e.cmb.team == "enemy":
			e.flee_now(host.player.loco.logical, 25.0)
	host.hint("깡철이가 렌치를 내던지고 손을 든다. 다가가서 조사 키로 말을 걸 수 있다.", 6.0)
	_log("항복(%.0f초)" % _fight_t)


## 항복한 깡철이 앞에서 조사 키 = 결말 장면(엔진의 '그냥 놓아주기'보다 먼저)
func _interact() -> bool:
	if phase != 4 or not _alive(kc) or host.box.active:
		return false
	if host.player.loco.logical.distance_to(kc.loco.logical) > 1.6 * 32.0 + 8.0:
		return false
	host.play_scene("KC_GIVE")
	return true


func _on_killed(e: Enemy) -> void:
	if e == kc:
		_end(4)
		if v("KC_STATE") == 4 and v("KC_STRIP") == 0:
			st.call_fn("give", ["A-102", 1])
			host.hint("깡철이의 헬멧을 벗겨 챙겼다.", 4.0)
	elif e.has_meta("kc_dog"):
		st.vars.set_v("KC_DOGS", mini(3, v("KC_DOGS") + 1))


func _end(state: int) -> void:
	if v("KC_STATE") == 0:
		st.vars.set_v("KC_STATE", state)
		st.vars.set_v("KC_DAY", day())
	phase = 5
	_log("결말 %d" % v("KC_STATE"))


## 놓아준 깡철이는 사흘 뒤 봉천 고물상 진열대에 헬멧을 판다(SD-09a — 팔리기 전까지 남는 장물 칸)
func _helm_shop() -> void:
	if v("KC_STATE") != 2 or v("KC_HELM") != 0 or day() < v("KC_DAY") + HELM_DAYS:
		return
	st.vars.set_v("KC_HELM", 1)
	var key := "shop:V01"
	var sh: Dictionary = st.boxes.get(key, {})
	var mine: Dictionary = sh.get("mine", {})
	mine["A-102"] = int(mine.get("A-102", 0)) + 1
	sh["mine"] = mine
	if sh.has("items"):
		sh["items"]["A-102"] = int((sh["items"] as Dictionary).get("A-102", 0)) + 1
	st.boxes[key] = sh
	_log("고물상에 헬멧")


# ---------------------------------------------------------------- 원고 명령(@cmd kc …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"fight":
			_fight("고름")
		"refuse":
			refused = true
		"toll":                                                          # 통행세(캡은 선택지 태그가 이미 냈다): 그날은 고가 아래 매복이 없다(RE-002 cond)
			st.vars.set_v("KC_TOLL", day())
		"talk":                                                          # 말로 물러나게 했다 = 놓아줌과 같은 결과(싸움 없이)
			st.vars.set_v("KC_TALK", 1)
			_let_go(2)
		"perk":                                                          # 애니멀 프렌드 선택지: 개들이 주인공 쪽으로 — 깡철이 혼자 남아 항복
			_fight("애니멀 프렌드")
		"loose":                                                         # 사슬 고리를 뺐다: 개는 흩어지고 다시 묶이지 않는다
			if phase != 0:
				done.call()
				return
			st.vars.set_v("KC_LOOSE", 1)
			if _alive(kc):
				kc.say_text = "…어? 야, 어디 가!"
				kc.say_t = 2.5
			for dg in dogs:
				if _alive(dg):
					dg.cmb.team = "gone"
					dg.foes.clear()
					dg.flee_now(_px(STAKE), 30.0)
			dogs.clear()
			_log("고리 뺌")
		"caught":
			_fight("고리 들킴")
		"release":
			_let_go(2)
		"helm":
			st.vars.set_v("KC_STRIP", 1)
			st.call_fn("give", ["A-102", 1])
			st.vars.set_v("KC_BALD", day())                               # 맨머리 소문(출처 깡철이 — 고시촌 상담료 두 배는 그날)
			_let_go(3)
		"shoot":
			if _alive(kc):
				kc.cmb.last_by = "player"
				kc.cmb.take({"hp": kc.cmb.hp + 1.0}, host.player.loco.logical)
	done.call()


func _let_go(state: int) -> void:
	_end(state)
	if state == 2 and v("KC_TALK") == 0:
		st.call_fn("karma", [10])                                         # 놓아줌(계획 §4.1 — 고르는 값: 헬멧 · 현상금 절반을 버린다)
	if _alive(kc):
		kc.released = true                                               # 엔진 release()와 같되 '고, 고맙다…' · '다시는 덤비지 않을 것이다' 알림 없이(결말별 바크)
		kc.set_meta("leave_from", host.player.loco.logical)
		kc.foes.clear()
		kc.cmb.team = "gone"
		kc.brain.state = AIBrain.S.RETURN
		kc.say_text = {2: "…빚졌다." if v("KC_TALK") == 0 else "", 3: ""}.get(state, "")
		kc.say_t = 2.5 if kc.say_text != "" else 0.0
		host.combat._rebuild_list()
	for e in dogs + gang:
		if _alive(e):
			e.cmb.team = "gone"
			e.foes.clear()
			e.flee_now(host.player.loco.logical, 30.0)
