## 관악(R01) 사이드 퀘스트 진행기(단계 1-11). 지금은 SQ-S01 「외눈의 인식표」(SD-04a §4.1). 원고: script/act1/SQ-S01.txt · TRAVEL.txt TR_EOM(엄태경).
## 바위굴(X-BW, 월드 손 맵 L-R01-05) 반경 40칸에 들어오면 시간대 무리를 세우고 60칸 밖이면 거둔다. 사실은 변수 한 곳(SD-20 P1):
##   SQ_S01_SOL 해법 · LEFT 무리 이동 · DROP 바닥의 인식표 · DOG 백구 동행 · BAIT 미끼 시각 · KILLS 쓰러뜨린 무리 · BC 봉천이 아직 모르는 호감 ·
##   FLED_DAY 외눈이 숲으로 달아난 날(그날은 굴에 없다 · 이틀은 HP 60%로 돌아온다 — SD-14 §10.3 ③, 1-13h).
## 외눈의 하루(S3): 낮 10~16 별관 2층 관람석(K-31)에서 잔다(무리는 마당에서 쉰다) · 17~19 해 질 녘 뼈 마당 · 20~05 밤 무리 +2, 더 잘 본다 · 06~09 마당.
## 해법: A 소탕(외눈이 쓰러지면 — 인식표는 드롭) · B 백구 대치(해 질 녘 백구 동행으로 외눈 앞 8칸 — 10초 동안 들개 둘을 30% 깎아 쫓으면 흩어진다) ·
##   C 애니멀 프렌드(PK_045 — 무리가 먼저 치지 않고, 외눈 곁에서 원고) · D 낮잠(K-31 잠든 외눈 곁 원고 — 소음 칸을 밟거나 깨우면 A로) ·
##   E 미끼(남쪽 빈터에 멧돼지 고기 3 — 한 시간 뒤 안전한 순간에 무리가 남쪽 능선으로).
## 봉천 호감은 공개도 1(봉천 안 소문, SD-06 §6): 해법 몫은 봉천(X-BC)에 돌아와야 반영한다. 건넴(조담희 · 엄태경)은 그 자리에서.
## 백구(C-015): 이 퀘스트에서 죽지 않는다 — HP 20% 이하면 짖으며 마을로 돌아간다(DOG 2). 주인공이 때리면 동행 해제 · 봉천 −10 · 카르마 −25.
class_name SideR01
extends Node

const SPAWN_R := 40.0                    ## 무리를 세우는 거리(칸)
const DESPAWN_R := 60.0
const START_R := 30.0                    ## 엿보기형 발동(외눈 목격) — 단계 20부터
const NEAR_R := 20.0                     ## 단계 20 '바위굴 반경 20타일'
const STAND_R := 8.0                     ## 백구 대치가 시작되는 외눈과의 거리(칸)
const STAND_S := 10.0
const STAND_MIN := 6.0                    ## 대치가 적어도 이만큼은 선다(1-12l D-088 — 두 발로 지나가지 않게: 들개를 일찍 쫓아도 외눈과 백구는 마주 서 있다)
const STAND_CAM := 2.5                    ## 처음 이만큼 카메라가 둘 사이를 잡는다
const CHASE_FRAC := 0.7                  ## 피해 30% 이상 = HP 70% 이하
const BAIT_MIN := 60                     ## 미끼를 놓고 무리가 옮기기까지(게임 분)
const DOG_RETREAT := 0.2
const PD_CENTER := Vector2i(930, 1520)   ## PD-R01-1(관악산 판도 구역) 대략 중심 — 소탕 뒤 크리처 인카운터 −30%(Encounters.cat_mult)
const PD_R := 90
const NOISE := ["noise1", "noise2", "noise3", "noise4", "noise5", "noise6"]

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var pack: Array = []                     ## 지금 세운 무리(외눈 포함)
var one: Enemy = null                    ## 외눈
var pack_on := false
var band := ""                           ## 무리를 세운 시간대(nap · dusk · night · morn)
var stand_t := -1.0                      ## 대치 남은 초(-1 = 아님)
var _stand_done := false                 ## 이번에 세운 무리에서 대치를 한 번 했나
var _stand_beat := 0                     ## 대치 박자(0 마주 섬 · 1 두 귀 · 2 카메라 놓음 · 3 무리가 다 물러섬)
var _beat4 := false
var _beat5 := false
var _chased := {}
var _perk_asked := false
var _nap_asked := false
var tag_prop := {}
var rats: Array = []
var leaving: Array = []                  ## 떠나는 중인 개(거둘 때 함께 치운다)
var _hit_hooked: Combatant = null
var blood: Array = []                    ## 달아나는 외눈이 남긴 핏방울(런타임 덧그림 — 거둘 때 함께 치운다)
var _blood_at := Vector2.INF             ## 마지막 핏방울 자리
var lick := {}                           ## 핏자국이 끊긴 자리(다가가면 안내 — 재미 검수 1-13h)
var _lick_c := Vector2i.ZERO
var _scar_said := false
var _night_warned := false               ## 밤 무리(+2)를 세운 뒤 굴 30칸 안에서 한 번 — 울부짖음이 겹겹이(1-13h 조율: 밤은 일부러 더 위험한 판 — 먼저 알린다)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s01"] = _cmd
	host.map_entered.connect(_on_map)
	host.combat.enemy_killed.connect(_on_killed)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[관악 사이드] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S01")


static func band_of(h: int) -> String:
	if h >= 10 and h <= 16:
		return "nap"
	if h >= 17 and h <= 19:
		return "dusk"
	if h >= 6 and h <= 9:
		return "morn"
	return "night"


func hour() -> int:
	return Clock.hour(host.date_text)


func _now() -> int:
	return Clock.abs_min(host.date_text)


func _safe() -> bool:
	return not host.box.active and not host.ev.busy() and not host.busy and not host.combat.in_combat()


# ---------------------------------------------------------------- 매 0.25초
func _process(dt: float) -> void:
	if host.map == null:
		return
	if stand_t >= 0.0:
		_stand_tick(dt)
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	tick()


func tick() -> void:
	_dog_tick()
	if host.map is WorldMap:
		_den_tick()
	elif host.map.id == "K-31":
		_nap_tick()
	_facts()


## 사실 맞추기: 인식표를 쥐면 30 · 7일 소지 자동 종료 · 건네지 않고 손을 떠나면(판매) 97
func _facts() -> void:
	var s := stage()
	if s >= 100:
		return
	var has := st.count_of("M-158") > 0
	if has and v("SQ_S01_TAG_DAY") == 0:
		st.vars.set_v("SQ_S01_TAG_DAY", day())
		if s < 30:
			if s < 20:
				st.quests.set_stage("SQ-S01", 20)
			st.quests.set_stage("SQ-S01", 30)
		host.hint("외눈의 인식표 — 핍-보이 잡화에서 살펴볼 수 있다", 5.0)
		_log("인식표 입수(단계 %d)" % stage())
	if has and v("SQ_S01_TAG_DAY") > 0 and day() >= v("SQ_S01_TAG_DAY") + 7:
		st.vars.set_v("SQH_TAG", 0)                                       # 7일 소지 뒤 자동 종료(SD-04a §4.1 단계 100)
		_finish("지님")
	elif not has and v("SQ_S01_TAG_DAY") > 0 and v("SQH_TAG") == -1 and v("SQ_S01_DROP") == 0:
		st.vars.set_v("SQH_TAG", 97)                                      # 건네지 않고 손을 떠났다(세월상회 V14 등에 팜)
		_finish("팜")


func _finish(why: String) -> void:
	if stage() >= 100:
		return
	st.vars.set_v("SQS01_RESULT", v("SQ_S01_SOL"))
	st.quests.set_stage("SQ-S01", 100)
	st.call_fn("xp", [300])
	_log("SQ-S01 끝(%s · 해법 %d · 인도처 %d)" % [why, v("SQ_S01_SOL"), v("SQH_TAG")])


## 해법이 섰다: 카르마는 그 자리에서, 봉천 호감은 봉천에 돌아와서(공개도 1)
func _solve(sol: int, karma: int, bc: int, left: bool) -> void:
	if v("SQ_S01_SOL") != 0:
		return
	st.vars.set_v("SQ_S01_SOL", sol)
	if stage() < 20:
		st.quests.set_stage("SQ-S01", 20)
	if left:
		st.vars.set_v("SQ_S01_LEFT", 1)
		st.vars.set_v("SQ_S01_LEFT_DAY", day())
		st.quests.set_stage("SQ-S01", 31)
	if karma != 0:
		st.call_fn("karma", [karma])
	st.vars.set_v("SQ_S01_BC", v("SQ_S01_BC") + bc)
	_log("해법 %d(카르마 %+d · 봉천 %+d 대기)" % [sol, karma, bc])


# ---------------------------------------------------------------- 백구(일시 동행)
func _dog_mate() -> Dictionary:
	return host.combat.mates.get_mate("C-015")


func _dog_tick() -> void:
	if v("SQ_S01_DOG") != 1:
		return
	var m := _dog_mate()
	if m.is_empty():
		return
	var cmb: Combatant = m["cmb"]
	if _hit_hooked != cmb:
		_hit_hooked = cmb
		cmb.hit.connect(func() -> void:
			if cmb.last_by == "player" and v("SQ_S01_DOG") == 1:
				_betray())
	if m["down"] or cmb.hp <= cmb.max_hp * DOG_RETREAT:
		_dog_away(2, "백구가 짖으며 물러난다. 다리를 끌며 마을 쪽으로 달려간다.")
	elif host.map is WorldMap and host.map.id == "X-BC" and (v("SQ_S01_LEFT") == 1 or v("SQ_S01_SOL") != 0 or stage() >= 100):
		_dog_away(3, "백구가 개집으로 돌아가 몸을 만다. 일을 마친 얼굴이다.")


func _betray() -> void:
	st.vars.set_v("SQ_S01_BETRAY", 1)
	st.call_fn("aff", ["JC_BC", -10])
	st.call_fn("karma", [-25])
	_dog_away(2, "백구가 비명을 지르고 마을 쪽으로 달아난다.")
	_log("백구를 때림(봉천 −10 · 카르마 −25)")


## 백구를 동행에서 떼어 마을로(2 다쳐 돌아감 · 3 일을 마침). 몸은 감추고, 봉천 개집 자리는 맵 조건(SQ_S01_DOG != 1)이 다시 세운다
func _dog_away(state: int, text: String) -> void:
	var m := _dog_mate()
	st.vars.set_v("SQ_S01_DOG", state)
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
	if host.map is WorldMap and host.map.id == "X-BC":
		host.refresh_npcs()
	_log("백구 동행 끝(%d)" % state)


# ---------------------------------------------------------------- 바위굴(월드)
func _yard() -> Vector2:
	return host.map.mark_pos("X-BW:yard")


func _dist_t() -> float:
	return host.player.loco.logical.distance_to(_yard()) / 32.0


func _den_tick() -> void:
	var d := _dist_t()
	if d <= SPAWN_R and not pack_on:
		_spawn_pack()
	elif d > DESPAWN_R and pack_on and not host.combat.in_combat():
		_clear_pack()
	var s := stage()
	if s < 20 and v("V_ACT") >= 1:
		if s >= 10 and d <= NEAR_R:
			st.quests.set_stage("SQ-S01", 20)
			_log("바위굴 반경 20칸(단계 20)")
		elif s == 0 and d <= START_R and is_instance_valid(one) and not one.cmb.dead:
			st.quests.set_stage("SQ-S01", 20)                               # 엿보기형: 외눈을 먼저 봤다(SD-04a §4.1 발동)
			host.hint("흰 들개 한 마리 — 한쪽 눈이 없다. 목에서 무언가 반짝인다.", 5.0)
			_log("외눈 목격(단계 20부터)")
	if not pack_on:
		_bait_tick(false)
		return
	_one_fled_check()
	_scar_tick()
	if not _night_warned and band == "night" and d <= START_R and not pack.is_empty() and not host.combat.in_combat():
		_night_warned = true
		host.hint("바위굴 쪽에서 여러 마리가 한꺼번에 울부짖는다. 밤에는 낮보다 수가 많다.", 5.0)
	_band_shift()
	_tag_tick()
	_bait_tick(true)
	if stand_t < 0.0:
		_stand_check()
	_perk_check()


func _one_alive() -> bool:
	return v("SQ_S01_SOL") == 0 and v("SQ_S01_LEFT") == 0 and not st.is_dead("CR-500")


## 외눈이 굴에 있나: 오늘 숲으로 달아났으면(③) 하루 동안 돌아오지 않는다 — 무리만 남는다
func _one_home() -> bool:
	return _one_alive() and v("SQ_S01_FLED_DAY") != day()


## 달아났던 외눈은 이틀 동안 상처가 덜 아문 채(HP 60%) 돌아온다 — 제자리 곁에 마른 핏자국 · 처음 마주치면 낮게 으르렁댄다(눈에 보이는 상처)
func _scar(e: Enemy) -> void:
	if v("SQ_S01_FLED_DAY") > 0 and day() <= v("SQ_S01_FLED_DAY") + 2:
		e.cmb.hp = e.cmb.max_hp * 0.6
		e.set_meta("scarred", true)
		e.slow_mul = 0.85                                                # 걸음이 조금 무겁다(상처)
		_scar_said = false
		var bp := host.map.add_runtime_prop("blood_drops", host.map.tile_of(e.loco.logical) + Vector2i(1, 1))
		if not bp.is_empty():
			blood.append(bp)


func _scar_tick() -> void:
	if _scar_said or not is_instance_valid(one) or one.cmb.dead or not one.has_meta("scarred") or one.asleep:
		return
	if one.loco.logical.distance_to(host.player.loco.logical) <= 10.0 * 32.0:
		_scar_said = true
		one._say("growl", 2.0)
		host.hint("외눈 옆구리에 덜 아문 상처가 벌겋다. 걸음이 조금 무겁다.", 5.0)


## 외눈 ③: 숲으로 달아나 시야에서 벗어났다(주인공과 14칸) — 거두고 하루를 비운다. 무리 절반은 전투 모듈이 이미 흩었다
func _one_fled_check() -> void:
	_lick_tick()
	if not is_instance_valid(one) or one.cmb.dead or one.one_phase != 2 or not one.brain.fleeing():
		return
	var p: Vector2 = one.loco.logical
	if blood.size() < 8 and (_blood_at == Vector2.INF or p.distance_to(_blood_at) >= 3.0 * 32.0):   # 달아나는 길에 3칸마다 핏방울(따라갈 거리)
		_blood_at = p
		var bp := host.map.add_runtime_prop("blood_drops", host.map.tile_of(p))
		if not bp.is_empty():
			blood.append(bp)
	if p.distance_to(host.player.loco.logical) < 14.0 * 32.0:
		return
	st.vars.set_v("SQ_S01_FLED_DAY", day())
	_lick_c = host.map.tile_of(p)
	lick = host.map.add_runtime_prop("blood_lick", _lick_c)                # 핏자국이 끊긴 자리 — 다가가 보면 안다(안내를 미리 띄우지 않는다)
	pack.erase(one)
	host.combat.drop_enemy(one)
	one = null
	_log("외눈 도주(%d일)" % day())


## 맵을 새로 열었다: 지난 맵의 덧그림은 맵과 함께 사라졌다
func _forget_marks() -> void:
	blood.clear()
	lick = {}
	_blood_at = Vector2.INF


## 핏자국이 끊긴 자리에 다가가면(1.5칸): 핥은 자국 — 오늘은 굴에 돌아오지 않겠다
func _lick_tick() -> void:
	if lick.is_empty() or host.box.active:
		return
	var c := Vector2(_lick_c.x * 32 + 16, _lick_c.y * 32 + 16)
	if host.player.loco.logical.distance_to(c) <= 1.5 * 32.0:
		host.hint("핏자국이 바위 밑에서 끊긴다. 고인 피를 핥아 낸 자국과 흰 털 몇 가닥. 외눈은 오늘 굴로 돌아오지 않겠다.", 6.0)
		host.map.remove_runtime_prop(lick)
		lick = {}


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("BW:%d:%d" % [_now() / 60, v("SQ_S01_KILLS")])         # 같은 때 다시 오면 같은 자리 — 때가 바뀌면 다른 수 · 방향 · 자리(SD-22)
	return r


## 뼈 마당 안 빈 칸(마당 표지 둘레 ±6 · ±3)
func _yard_spot(r: RandomNumberGenerator) -> Vector2:
	var c0: Vector2i = host.map.tile_of(_yard())
	for _i in 30:
		var c := c0 + Vector2i(r.randi_range(-6, 6), r.randi_range(-3, 3))
		if not host.map.is_solid(c):
			return Vector2(c.x * 32 + 16, c.y * 32 + 16)
	return _yard()


func _spawn_pack() -> void:
	pack_on = true
	_night_warned = false
	_stand_done = false
	_perk_asked = false
	pack.clear()
	rats.clear()
	one = null
	band = band_of(hour())
	if v("SQ_S01_DROP") == 1:
		_show_tag()
	if v("SQ_S01_SOL") == 1 or st.is_dead("CR-500"):                  # 소탕 뒤: 사흘 지나면 변이 시궁쥐가 든다
		if day() >= v("SQ_S01_CLEAR_DAY") + 3:
			var r := _rng()
			for i in r.randi_range(3, 4):
				rats.append(host.combat.spawn("CR-095", _yard_spot(r), host.map, st, {"lv": r.randi_range(2, 4)}))
			_log("빈 굴에 시궁쥐 %d" % rats.size())
		return
	if v("SQ_S01_LEFT") == 1:
		return                                                          # 무리는 남쪽 능선으로 옮겼다
	if v("SQ_S01_KILLS") > 0 and day() >= v("SQ_S01_KILL_DAY") + 3:
		st.vars.set_v("SQ_S01_KILLS", 0)                                # 72시간 뒤 다시 채워진다(SD-19 단계 1)
	var r := _rng()
	var kinds: Array = []
	for i in 4:
		kinds.append("CR-104")
	for i in r.randi_range(2, 3):
		kinds.append("CR-105")
	if band == "night":
		kinds.append_array(["CR-104", "CR-104"])                        # 밤(20~05시) 무리 +2(SD-14 §11.2)
	kinds.shuffle()
	var n := maxi(0, kinds.size() - v("SQ_S01_KILLS"))
	var calm := v("PK_045") >= 1 or (band == "dusk" and v("SQ_S01_DOG") == 1)   # 애니멀 프렌드 · 해 질 녘 백구와 함께: 무리가 먼저 덤비지 않고 지켜본다(대치를 기다린다)
	for i in n:
		var opts := {"lv": r.randi_range(3, 8), "dir": ["N", "S", "E", "W", "SE", "SW"][r.randi() % 6]}
		if band == "nap" and r.randf() < 0.6:
			opts["sleep"] = true                                         # 한낮: 마당에서 졸고 있다
		var e := host.combat.spawn(str(kinds[i]), _yard_spot(r), host.map, st, opts)
		e.det_mul = {"nap": 0.5, "night": 1.3}.get(band, 1.0)
		if calm:
			_calm(e, "calmbw")
		pack.append(e)
	if band != "nap" and _one_home():
		_spawn_one(host.map.mark_pos("X-BW:one_yard"))
	_log("무리 %d + 외눈 %s(%s, %d시)" % [n, "있음" if one != null else "별관", band, hour()])


func _spawn_one(at: Vector2) -> void:
	one = host.combat.spawn("CR-500", at, host.map, st, {"lv": 6, "dir": "S", "stance": "hold"})   # 우두머리는 마당 한가운데 자리를 지킨다
	one.det_mul = 1.3 if band == "night" else 1.0
	_scar(one)
	if v("PK_045") >= 1 or (band == "dusk" and v("SQ_S01_DOG") == 1):
		_calm(one, "calmbw")
	pack.append(one)


func _calm(e: Enemy, team: String) -> void:
	e.cmb.team = team
	e.foes.clear()


func _hostile(e: Enemy) -> void:
	if not is_instance_valid(e) or e.cmb.dead:
		return
	e.cmb.team = "enemy"
	e.foes = ["player", "ally"]
	e.wake()


func _clear_pack() -> void:
	for e in pack + rats + leaving:
		if is_instance_valid(e) and not e.cmb.dead:
			host.combat.drop_enemy(e)
	pack.clear()
	rats.clear()
	leaving.clear()
	one = null
	pack_on = false
	stand_t = -1.0
	if not tag_prop.is_empty():
		host.map.remove_runtime_prop(tag_prop)
		tag_prop = {}
	for bp in blood:
		host.map.remove_runtime_prop(bp)
	blood.clear()
	_blood_at = Vector2.INF
	if not lick.is_empty():
		host.map.remove_runtime_prop(lick)
		lick = {}
	_log("무리 거둠")


## 시간대가 바뀌었다: 해 질 녘이 되면 외눈이 북쪽 암굴로 내려오고, 한낮이 되면 별관으로 올라간다(보는 앞에서 — 끊김 없이)
func _band_shift() -> void:
	var b := band_of(hour())
	if b == band or not _one_alive():
		return
	if band == "nap" and one == null and not host.combat.in_combat() and _one_home():
		band = b
		_spawn_one(host.map.mark_pos("X-BW:north_in"))
		_log("외눈이 마당으로 내려옴(%d시)" % hour())
	elif b == "nap" and is_instance_valid(one) and not one.cmb.dead and not host.combat.in_combat() and stand_t < 0.0:
		band = b
		_send_off(one, host.map.mark_pos("X-BW:baek_face"), host.map.mark_pos("X-BW:north_in"))   # 북쪽 암굴로(별관 2층 둥지)
		one = null
		_log("외눈이 별관으로 올라감(%d시)" % hour())
	else:
		band = b


## 멀어지게 보낸다(from에서 반대쪽으로 걸어가 사라진다). to = 정해진 출구(바위굴이면 남쪽 숲길 · 북쪽 암굴)
func _send_off(e, from: Vector2, to := Vector2.INF) -> void:          # e는 형 없이 — 대치를 기다리는 사이 쓰러져 지워진 들개가 올 수 있다(1-12l)
	if not is_instance_valid(e) or e.cmb.dead:
		return
	e.wake()
	e.released = true
	e.set_meta("leave_from", from)
	if to != Vector2.INF:
		e.set_meta("leave_to", to)
	if not leaving.has(e):
		leaving.append(e)
	e.foes.clear()
	e.cmb.team = "gone"
	e.brain.state = AIBrain.S.RETURN
	host.combat._rebuild_list()


## 무리가 남쪽 능선으로 떠난다(B · C · E): 북쪽 암굴에서 멀어지는 쪽 = 남쪽 숲길
func _pack_leaves() -> void:
	var north := host.map.mark_pos("X-BW:north_in")
	var out := host.map.mark_pos("X-BW:south_out")
	for e in pack:
		_send_off(e, north, out)
	pack.clear()
	one = null


func _on_killed(_eid: String, _alive: int) -> void:
	for e in pack.duplicate():
		if is_instance_valid(e) and e.cmb.dead and not e.has_meta("s01_dead"):
			e.set_meta("s01_dead", true)
			if e == one:
				_one_down()
			else:
				st.vars.set_v("SQ_S01_KILLS", v("SQ_S01_KILLS") + 1)
				st.vars.set_v("SQ_S01_KILL_DAY", day())


## 해법 A: 외눈이 쓰러졌다 — 인식표는 몸에서(드롭 M-158). 남은 무리 절반은 흩어지고(전투 모듈 _pack_scatter) 나머지는 끝까지 싸운다
func _one_down() -> void:
	st.kill("CR-500")
	st.vars.set_v("SQ_S01_NAP", 0)
	stand_t = -1.0
	if v("SQ_S01_SOL") == 0 and v("SQ_S01_LEFT") == 0:
		_solve(1, 0, 3, false)
		st.vars.set_v("SQ_S01_CLEAR_DAY", day())
	one = null
	host.hint("외눈이 쓰러졌다. 목에 걸린 쇠붙이가 흙에 떨어진다.", 5.0)


# ---------------------------------------------------------------- 해법 B 백구와 대치
func _stand_check() -> void:
	if _stand_done or v("SQ_S01_DOG") != 1 or band_of(hour()) != "dusk" or not _one_alive():
		return
	if not is_instance_valid(one) or one.cmb.dead or one.released:
		return
	var m := _dog_mate()
	if m.is_empty() or m["down"] or host.box.active or host.ev.busy() or host.busy:
		return
	if not one.cmb.team.begins_with("calm"):
		return                                                          # 이미 싸움이 붙었다(대치 없이 해법 A로)
	if host.player.loco.logical.distance_to(one.loco.logical) > STAND_R * 32.0:
		return
	_stand_done = true
	stand_t = STAND_S
	_chased.clear()
	var k := 0
	for e in pack:
		if is_instance_valid(e) and not e.cmb.dead:
			k += 1
			_calm(e, "calmbw%d" % k)                                  # 저마다 다른 편: 한 마리를 쳐도 무리 전체가 덤비지 않는다
			e.wake()
	var face := _face_spot(host.player.loco.logical)
	host.combat.mates.set_mode("C-015", "wait")
	m["home"] = face                                                    # 외눈 앞 3칸에 마주 선다(주인공 쪽)
	for a in [one, m["actor"]]:
		host.ev.balloons.append({"actor": a, "kind": "!", "t": 0.0})
	host.ev.queue_redraw()
	_stand_beat = 0
	_beat4 = false
	_beat5 = false
	host.ev.cam_locked = true                                           # 둘 사이를 잡는다(SD-04a §4.1 연출 메모 — 컷 없이 맵 위에서)
	var mid: Vector2 = (one.loco.logical + (m["actor"] as Actor).loco.logical) / 2.0 + Vector2(0, -16)
	if host.is_inside_tree() and host.cam != null:
		host.create_tween().tween_property(host.cam, "position", mid.round(), 0.6)
	host.hint("외눈과 백구가 마주 섰다. 같은 흰 털, 같은 귀 — 그사이 들개를 쫓아낸다", 6.0)
	_log("대치 시작")


## 외눈에게서 주인공 쪽으로 3칸 — 빈 칸이 아니면 바위굴 표지(baek_face)
func _face_spot(toward: Vector2) -> Vector2:
	var dir := (toward - one.loco.logical).normalized()
	for r in [3.0, 2.5, 3.5, 2.0]:
		var c: Vector2i = host.map.tile_of(one.loco.logical + dir * r * 32.0)
		if not host.map.is_solid(c):
			return Vector2(c.x * 32 + 16, c.y * 32 + 16)
	return host.map.mark_pos("X-BW:baek_face")


func _stand_tick(dt: float) -> void:
	stand_t -= dt
	var gone := STAND_S - stand_t
	var bw := _dog_mate()
	if _stand_beat == 0 and gone >= 1.2 and is_instance_valid(one) and not bw.is_empty():
		_stand_beat = 1                                                 # 두 귀가 동시에 선다
		var mid: Vector2 = (one.loco.logical + (bw["actor"] as Actor).loco.logical) / 2.0
		host.combat._pop("(두 귀가 동시에 선다)", mid + Vector2(0, -44), Color("F2E6C8"))
	if _stand_beat == 1 and gone >= STAND_CAM:
		_stand_beat = 2
		host.ev.cam_locked = false                                      # 이제 주인공 몫 — 카메라는 다시 주인공을 따른다
		if is_instance_valid(one):
			host.combat._pop("으르르…", one.loco.logical + Vector2(0, -40), Color("D8C890"))
	if _stand_beat in [2, 3] and gone >= 4.0 and not _beat4 and is_instance_valid(one) and not bw.is_empty():
		_beat4 = true                                                   # 외눈이 한 발 물러서고 백구가 한 발 다가선다(1-12l 재미 검수)
		host.combat._pop("(외눈이 한 발 물러선다)", one.loco.logical + Vector2(0, -44), Color("F2E6C8"))
		host.ev.balloons.append({"actor": bw["actor"], "kind": "!", "t": 0.0})
	if _beat4 and not _beat5 and gone >= 5.0 and is_instance_valid(one):
		_beat5 = true
		host.combat._pop("(외눈이 먼저 눈을 내린다)", one.loco.logical + Vector2(0, -44), Color("F2E6C8"))
	for e in pack:
		if not is_instance_valid(e) or e == one or _chased.has(e):
			continue
		if e.cmb.dead:
			_chased[e] = true                                           # 쓰러뜨려도 '쫓은' 것(피해 30% 이상)
			continue
		if e.cmb.hp <= e.cmb.max_hp * CHASE_FRAC:
			_chased[e] = true
			_send_off(e, host.player.loco.logical, host.map.mark_pos("X-BW:south_out"))   # 깨갱 — 숲으로 달아난다(처치 불필요)
			host.ev.balloons.append({"actor": e, "kind": "!", "t": 0.0})
	var need := STAND_MIN - (1.5 if host.combat.holstered else 0.0)      # 총을 거두고 기다리면 조금 일찍 — 기다림이 '총을 거두는 선택'이 된다
	if _chased.size() >= 2 and gone >= need:
		stand_t = -1.0
		_scatter()
		return
	if _chased.size() >= 2 and _stand_beat < 3:
		_stand_beat = 3                                                 # 무리는 물러섰다 — 외눈은 아직 백구를 본다(대치가 끝까지 선다)
		if host.ev.cam_locked:
			host.ev.cam_locked = false
		host.hint("들개들이 물러선다. 외눈은 아직 백구에게서 눈을 떼지 않는다 — 기다린다", 4.0)
	var one_hit: bool = is_instance_valid(one) and (one.cmb.dead or one.cmb.hp < one.cmb.max_hp)
	if stand_t <= 0.0 or one_hit or _dog_mate().is_empty():
		stand_t = -1.0
		host.ev.cam_locked = false
		for e in pack:
			_hostile(e)                                                 # 대치가 깨졌다: 무리가 덤빈다(해법 A로)
		host.combat.mates.set_mode("C-015", "follow")
		host.hint("외눈이 이빨을 드러낸다. 대치가 깨졌다!", 4.0)
		_log("대치 실패")


func _scatter() -> void:
	var at: Vector2i = host.map.tile_of(one.loco.logical) if is_instance_valid(one) else host.map.tile_of(_yard())
	st.vars.set_v("SQ_S01_DROP", 1)
	st.vars.set_v("SQ_S01_DROP_AT", at.x * 10000 + at.y)               # 떨군 칸(월드 칸 — 불러와도 그 자리)
	_solve(2, 50, 5, true)
	if is_instance_valid(one):
		host.ev.balloons.append({"actor": one, "kind": "♪", "t": 0.0})
	_pack_leaves()
	_show_tag()
	host.combat.mates.set_mode("C-015", "follow")
	var m := _dog_mate()
	if not m.is_empty():
		host.ev.balloons.append({"actor": m["actor"], "kind": "♪", "t": 0.0})
	host.ev.cam_locked = false
	host.hint("무리가 흩어진다. 외눈이 인식표를 떨군 채 남쪽 능선으로 간다.", 6.0)
	var o := one
	if not is_inside_tree():
		_log("대치 성공 — 무리 흩어짐")
		return
	get_tree().create_timer(2.6).timeout.connect(func() -> void:          # 능선에서 한 번 울부짖고(외눈) — 백구가 대답한다(SD-04a §4.1 연출 메모)
		if is_instance_valid(o) and not o.cmb.dead:
			host.combat._pop("아우——", o.loco.logical + Vector2(0, -40), Color("F2E6C8")))
	get_tree().create_timer(3.8).timeout.connect(func() -> void:
		var bm := _dog_mate()
		if not bm.is_empty() and is_instance_valid(bm["actor"]):
			host.combat._pop("아우우…", (bm["actor"] as Actor).loco.logical + Vector2(0, -40), Color("F2E6C8")))
	_log("대치 성공 — 무리 흩어짐")


# ---------------------------------------------------------------- 바닥의 인식표(해법 B)
func _drop_cell() -> Vector2i:
	var k := v("SQ_S01_DROP_AT")
	return Vector2i(k / 10000, k % 10000) if k > 0 else host.map.tile_of(host.map.mark_pos("X-BW:one_yard"))


func _show_tag() -> void:
	if tag_prop.is_empty():
		tag_prop = host.map.add_runtime_prop("tag_drop", _drop_cell())


func _tag_tick() -> void:
	if v("SQ_S01_DROP") != 1 or tag_prop.is_empty():
		return
	var dc := _drop_cell()
	var c := Vector2(dc.x * 32 + 16, dc.y * 32 + 16)
	if host.player.loco.logical.distance_to(c) <= 20.0 and not host.box.active:
		st.vars.set_v("SQ_S01_DROP", 0)
		st.call_fn("give", ["M-158", 1])
		host.map.remove_runtime_prop(tag_prop)
		tag_prop = {}
		host.hint("외눈의 인식표를 주웠다", 4.0)
		_log("떨어진 인식표 주움")


# ---------------------------------------------------------------- 해법 C 애니멀 프렌드(PK-045)
func _perk_check() -> void:
	if _perk_asked or v("PK_045") < 1 or not _one_alive() or not is_instance_valid(one) or one.cmb.dead:
		return
	if not one.cmb.team.begins_with("calm") or not _safe():
		return
	if host.player.loco.logical.distance_to(one.loco.logical) <= 1.6 * 32.0:
		_perk_asked = true
		host.play_scene("SQS01_PERK")


# ---------------------------------------------------------------- 해법 E 미끼
func _bait_tick(here: bool) -> void:
	var b := v("SQ_S01_BAIT")
	if b <= 0 or not _one_alive() or _now() - b < BAIT_MIN:
		return
	if here:
		if not _safe():
			return                                                      # 교전 · 대화 중엔 미룬다(P5)
		host.hint("들개들이 고개를 들고 남쪽 숲 냄새를 맡는다. 무리가 줄지어 능선 쪽으로 움직인다.", 6.0)
		_pack_leaves()
	_solve(5, 0, 2, true)


# ---------------------------------------------------------------- 해법 D 낮잠(별관 2층 K-31)
var _map_ref: InteriorMap = null


func _on_map(id: String) -> void:
	var fresh := host.map != _map_ref                                    # 맵을 새로 열었다(구역만 바뀐 게 아니다): 전투 모듈이 적을 비웠다
	_map_ref = host.map
	if id != "K-31":
		st.vars.set_v("SQ_S01_NAP", 0)
	if id == "K-31":
		_nap_asked = false
		pack_on = false
		pack.clear()
		rats.clear()
		leaving.clear()
		one = null
		tag_prop = {}
		_forget_marks()
		if band_of(hour()) == "nap" and _one_home() and stage() < 100:
			one = host.combat.spawn("CR-500", host.map.mark_pos("nap"), host.map, st, {"lv": 6, "dir": "W", "sleep": true})
			one.det_mul = 0.15                                           # 잠(SD-22 S4)
			_scar(one)
			pack = [one]
			st.vars.set_v("SQ_S01_NAP", 1)
			if stage() < 20:
				st.quests.set_stage("SQ-S01", 20)
			_log("외눈 낮잠(%d시)" % hour())
	elif fresh:
		pack_on = false                                                 # 실내 · 월드를 새로 열면 적이 비었다 — 다시 세운다
		pack.clear()
		rats.clear()
		leaving.clear()
		one = null
		tag_prop = {}
		_forget_marks()
		stand_t = -1.0
	if id == "X-BC" and v("SQ_S01_BC") != 0:
		st.call_fn("aff", ["JC_BC", v("SQ_S01_BC")])                       # 봉천이 이제 안다(공개도 1 — 마을 안 소문)
		_log("봉천 반영 %+d" % v("SQ_S01_BC"))
		st.vars.set_v("SQ_S01_BC", 0)


func _nap_tick() -> void:
	if v("SQ_S01_NAP") != 1 or not is_instance_valid(one):
		return
	if one.cmb.dead:
		return
	if not one.asleep:
		_nap_fail("외눈이 눈을 떴다!")
		return
	var here: Vector2i = host.map.tile_of(host.player.loco.logical)
	for k in NOISE:
		if here == host.map.tile_of(host.map.mark_pos(k)):
			_nap_fail("마루가 삐걱 울린다. 둥지의 외눈이 벌떡 일어선다!")
			return
	if band_of(hour()) != "nap" and _safe():
		st.vars.set_v("SQ_S01_NAP", 0)                                   # 해 질 녘: 일어나 마당으로 내려간다
		_send_off(one, host.player.loco.logical, host.map.mark_pos("from_K-30"))
		one = null
		return
	var d := host.player.loco.logical.distance_to(one.loco.logical)
	if d > 3.0 * 32.0:
		_nap_asked = false
	elif not _nap_asked and d <= 2.2 * 32.0 and _safe():
		_nap_asked = true
		host.play_scene("SQS01_NAP")


## 실패: 외눈이 깨어 무리를 부른다(해법 A로) — 아래층 계단에서 들개 둘이 올라온다
func _nap_fail(text: String) -> void:
	st.vars.set_v("SQ_S01_NAP", 0)
	_hostile(one)
	var at := host.map.mark_pos("from_K-30")
	for i in 2:
		var e := host.combat.spawn("CR-104" if i == 0 else "CR-105", at + Vector2(i * 32, 0), host.map, st, {"lv": 4 + i})
		e.brain.gauge = 100.0
		pack.append(e)
	host.hint(text, 4.0)
	_log("낮잠 실패")


# ---------------------------------------------------------------- 원고 명령(@cmd s01 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"dog":                                                          # 백구가 따라나선다(봉천 아랫문)
			if st.is_dead("C-015"):                                       # 장면은 @npc C-015라 열리지 않지만, 명령만 따로 불려도 죽은 개는 따라오지 않는다
				done.call()
				return
			st.vars.set_v("SQ_S01_DOG", 1)
			var b: Actor = host.ev.actors.get("C-015")
			if b != null:
				for n in host.npcs.duplicate():                               # 맵 인물에서 떼어 낸다(맵 조건 SQ_S01_DOG != 1이 거짓이 돼도 다시 세울 때 치우지 않게)
					if n["actor"] == b:
						host.npcs.erase(n)
				host.sync_residents()                                         # 아이는 거른 채로(1-X)
				host.ev.handlers["buddy"].call(["C-015"], func() -> void: pass)
			_log("백구 동행")
		"bait":
			st.vars.set_v("SQ_S01_BAIT", _now())
			_log("미끼 놓음")
		"cut":                                                          # D 성공: 목줄을 끊었다 — 외눈은 깨어 무리를 이끌고 옮긴다
			st.call_fn("give", ["M-158", 1])
			st.vars.set_v("SQ_S01_NAP", 0)
			_solve(4, 25, 3, true)
			if is_instance_valid(one):
				_send_off(one, host.player.loco.logical, host.map.mark_pos("from_K-30") if not (host.map is WorldMap) else Vector2.INF)
			one = null
		"wake":
			_nap_fail("외눈이 깨어 무리를 부른다!")
		"back":
			pass
		"untie":                                                        # C: 목줄을 풀었다 / 2랭크 — 스스로 떨군다
			st.call_fn("give", ["M-158", 1])
			_solve(3, 50, 5, true)
			_pack_leaves()
		"hand":                                                         # 건넴(81 조담희 · 20 엄태경) — 원고가 SQH_TAG를 먼저 적는다
			_finish("건넴 %s" % str(a[1]) if a.size() > 1 else "건넴")
		"report":                                                       # E: 인식표 없이 엄태경에게 알림(다른 결과)
			_finish("미끼 보고")
	done.call()
