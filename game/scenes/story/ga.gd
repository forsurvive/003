## 가산 아울렛 거리 DG-GA 1-D6 진행기(SD-09a L-R01-28 · 1-D 계획 §12.5~§12.7).
##   원고: script/act1/GA.txt(진열창 GA_WINDOW · 작업복 상자 GA_CRATE). 맵: GA-01 A관(1층 마네킹 줄 · 2층 패거리) · GA-02 지하 물류 창고.
## 동사 '눈을 속인다': 방독면(A-074 — 머리 칸 PC_HEAD)을 쓰고 · 마네킹 줄 칸(맵 사실 pose)에 · 서서 멈춰 있으면 사람 눈엔 마네킹(감지 배수 0).
##   방독면 없이 줄 안이면 0.5(의심) · 뛰거나 쏘면 깨진다 · 쥐는 냄새로 안다(배수를 건드리지 않는다 — 금탑 페로몬과 반대 축).
##   망꾼: 처음엔 줄 속 '마네킹'(보이지 않는 적 + 마네킹 그림) — 3칸 안에 들면 고개를 돌린다(GA_SEEN 1 · 당하면서 배운다).
##   재고 세기: 두목이 장부를 들고 줄 통로를 돈다 — 마네킹인 척하는 나를 지나치면 그 줄 셈이 하나 는다 → 줄 끝에서 '313?' → 그 칸으로 되돌아온다.
## 옷이 세계와 이어진다: 볼트 작업복(A-001) 차림이면 패거리가 알아보고(한 번 외침) 생포 표지 SB(새벽인력 우리 — 황두칠 · 구만호가 둘 다 죽었으면 없음).
##   탈의실 칸에서 다른 몸통 옷으로 갈아입으면 쫓던 사람 적이 놓친다(60초에 한 번).
## 잃는 선택: 작업복 상자(GA_BOX 하나 — P1) · 판도 반영은 다음 06:00에 한 번(P6) · 소문은 하루 늦게(P7). 세기 · 미끼 · 놓침은 맵을 떠나면 휘발(A119).
class_name Ga
extends Node

const HALL := "GA-01"
const STORE := "GA-02"
const BOSS := "N-GA-B1"
const GANG := ["CR-420", "CR-421", "CR-423"]   ## 사람 적(약탈자) — 눈으로 본다
const SB_HEADS := ["C-013", "C-049"]           ## 새벽인력 소장 · 실장 — 둘 다 죽었으면 인솔조가 오지 않는다(구로 장부쟁이와 같은 판정)
const MASK := "A-074"
const VAULT := "A-001"
const SUIT := "A-012"
const RAINCOAT := "M-196"
const STILL_S := 0.6                           ## 이만큼 멈춰 있어야 마네킹으로 보인다
const LOOK_R := 3.0                            ## 망꾼이 고개를 돌리는 거리(칸)
const LOSE_GAP := 60.0                         ## 탈의실에서 놓치기 — 이 초에 한 번
const LURE_S := 30.0                           ## 진열창 미끼에 몰려가 서성이는 초
const PICKUP_DAYS := 3                         ## 상자를 처음 본 날부터 이만큼 지나 06:00 인솔조가 그냥 가져간다
const LOOKOUT_AT := Vector2i(21, 28)
const WINDOW_AT := Vector2i(17, 30)
const WINDOW_MARK := Vector2i(18, 29)
const CRATE_AT := Vector2i(28, 15)
const FITTING := [Vector2i(35, 15), Vector2i(37, 15), Vector2i(39, 15), Vector2i(41, 15), Vector2i(43, 15), Vector2i(45, 15)]
const AISLES := [20, 23, 26, 29]               ## 줄 통로(줄 y + 1) — 두목이 걸으며 그 위 줄을 센다
## 재고 세기 길: 책상 → 줄 넷을 번갈아(왼 → 오 · 오 → 왼) → 책상
const COUNT_ROUTE := [[26, 6, 12.0], [8, 20, 1.0], [30, 20, 1.0], [30, 23, 0.5], [8, 23, 1.0], [8, 26, 0.5], [30, 26, 1.0], [30, 29, 0.5], [8, 29, 1.0]]
const PD_DELTA := {1: 10, 2: -10, 3: -5, 4: 5, 5: -5}   ## GA_BOX → 판도 PD-R01-6 사건 보정(+ 새벽인력 · − 약탈자)

var host: InteriorHost
var st: StoryState
var log_on := false
var _pose := {}
var _still_t := 0.0
var _last_tile := Vector2i(-99, -99)
var _lookout: Enemy = null
var _mann := {}                                ## 망꾼을 덮은 마네킹 그림(실행 소품)
var _boss: Enemy = null
var _aisle := -1                               ## 두목이 지금 걷는 줄 통로(y)
var _extra := Vector2i(-99, -99)               ## 이 줄에서 하나 더 센 칸(나)
var _check := {}                               ## 되돌아와 살피는 중 {"cell", "t"}
var _shouted := false
var _lose_t := -999.0
var _clock := 0.0
var _torso := ""
var _lure_t := 0.0
var _tick := 0.0


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["ga"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.box_closed.connect(_on_box)
	host.combat.enemy_down.connect(_on_down)


func v(k: String) -> int:
	return int(st.vars.get_v("GA_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("GA_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[가산 아울렛] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func _tc(c: Vector2i) -> Vector2:
	return Vector2(c) * 32.0 + Vector2(16, 16)


func _gang(e) -> bool:
	return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) in GANG


## 새벽인력이 아직 서 있나(소장 · 실장 둘 다 죽지 않았다)
func sb_alive() -> bool:
	return not SB_HEADS.all(func(c): return st.is_dead(c))


func worn() -> String:
	return str(st.call_fn("worn", []))


## 인솔조가 지금 하역장에 있나(판도 새벽인력 우세 · 낮 06~18 — 맵 npc 조건과 같은 식)
func watched() -> bool:
	var h := int(st.vars.get_v("GAME_HOUR"))
	return _mid() == STORE and int(st.vars.get_v("PD_R01_6")) >= 10 and h >= 6 and h < 18 and sb_alive()


# ---------------------------------------------------------------- 맵에 들어섰다: 망꾼 · 두목 · 상자 첫날
func _on_map(id: String) -> void:
	_pose = {}
	_still_t = 0.0
	_lookout = null
	_mann = {}
	_boss = null
	_aisle = -1
	_extra = Vector2i(-99, -99)
	_check = {}
	_shouted = false
	_lure_t = 0.0
	_torso = str(st.vars.get_v("PC_TORSO"))
	if not id.begins_with("GA-"):
		return
	_pose = host.map.pose_cells()
	if id == STORE and v("CRATE_DAY") == 0:
		_sv("CRATE_DAY", day())
	if id != HALL:
		return
	for e in host.combat.enemies:
		if not _gang(e):
			continue
		var t := host.map.tile_of(e.loco.logical)
		if str(e.who) == BOSS:
			_boss = e
			for r in COUNT_ROUTE:
				e.route.append([_tc(Vector2i(int(r[0]), int(r[1]))), float(r[2])])
		elif t == LOOKOUT_AT and v("SEEN") == 0:
			_lookout = e
			e.det_mul = 0.0
			e.visible = false
			_mann = host.map.add_runtime_prop("mann_ga", LOOKOUT_AT)
			for cc in _mann.get("cells", []):                                 # 그림만 — 발 칸은 망꾼이 선 자리라 막지 않는다
				host.map._put_solid(cc.x, cc.y, 0)
				host.map._put_cover(cc.x, cc.y, 0)
			if not _mann.is_empty():
				_mann["cells"] = []
	_log("A관 — 두목 %s · 망꾼 %s" % ["있음" if _boss != null else "없음", "숨음" if _lookout != null else "-"])


func _process(dt: float) -> void:
	if host == null or host.map == null or not _mid().begins_with("GA-") or host.player == null:
		return
	_clock += dt
	var pt := host.map.tile_of(host.player.loco.logical)
	var pc := host.combat.pc
	if pt != _last_tile or pc.movement != "still" or pc.posture != "stand":
		_still_t = 0.0
		_last_tile = pt
	else:
		_still_t += dt
	_fitting(pt)
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 0.1
	var posing := posing_at(pt)
	for e in host.combat.enemies:
		if not _gang(e) or e == _lookout:
			continue
		if e.brain.state == AIBrain.S.COMBAT:
			e.det_mul = 1.0
		elif posing == 2:
			e.det_mul = 0.0
		elif posing == 1:
			e.det_mul = 0.5
		else:
			e.det_mul = 1.0
	_watch_lookout(pt)
	_count(pt, posing)
	_suit()
	_lure(0.1)


## 지금 마네킹으로 보이나: 2 = 방독면 · 줄 칸 · 서서 멈춤 0.6초 · 쏘지 않음 · 1 = 줄 칸에 섰지만 방독면이 없다(의심) · 0 = 아님
func posing_at(pt: Vector2i) -> int:
	if not _pose.has(pt) or _still_t < STILL_S or host.combat.since_shot < 1.0:
		return 0
	return 2 if str(st.vars.get_v("PC_HEAD")) == MASK else 1


# ---------------------------------------------------------------- 망꾼: 줄 속 마네킹 하나가 고개를 돌린다
func _watch_lookout(pt: Vector2i) -> void:
	if _lookout == null or v("SEEN") == 1:
		return
	if not is_instance_valid(_lookout) or _lookout.cmb.dead:
		_reveal(false)
		return
	var hit := _lookout.brain.state == AIBrain.S.COMBAT                  # 쏘아 맞혔다 — 마네킹이 비명을 지른다
	if hit or Vector2(pt).distance_to(Vector2(LOOKOUT_AT)) <= LOOK_R:
		_reveal(true)


func _reveal(alive: bool) -> void:
	_sv("SEEN", 1)
	if not _mann.is_empty():
		host.map.remove_runtime_prop(_mann)
		_mann = {}
	if alive and is_instance_valid(_lookout):
		_lookout.visible = true
		_lookout.det_mul = 1.0
		_lookout.brain.gauge = AIBrain.DETECT_AT
		_lookout.brain.last_seen = host.player.loco.logical
		_lookout.brain._go(AIBrain.S.COMBAT)
		host.combat._pop("…!", _lookout.loco.logical + Vector2(0, -30), Color("E8C860"))
		host.hint("마네킹 하나가 고개를 돌린다 — 방독면 너머로 눈이 있다. 사람이다!", 3.5)
		for e in host.combat.enemies:
			if _gang(e) and e != _lookout:
				e.hear("pistol", _lookout.loco.logical)            # 고함 — 12칸(총소리만큼 울린다)
	elif is_instance_valid(_lookout):
		_lookout.visible = true
	_lookout = null
	_log("망꾼 드러남(%s)" % ("살아서" if alive else "쓰러짐"))


# ---------------------------------------------------------------- 재고 세기: 두목이 줄 통로를 걸으며 센다
func _count(pt: Vector2i, posing: int) -> void:
	if _boss == null or not is_instance_valid(_boss) or _boss.cmb.dead:
		_boss = null
		return
	var bt := host.map.tile_of(_boss.loco.logical)
	if not _check.is_empty():
		_recheck(pt, bt)
		return
	if _boss.brain.state != AIBrain.S.IDLE:
		_aisle = -1
		_extra = Vector2i(-99, -99)
		return
	var aisle := bt.y if bt.y in AISLES else -1
	if aisle != _aisle:                                                   # 줄 끝: 이 줄에서 하나 더 셌으면 '313?'
		if _aisle != -1 and _extra.y == _aisle - 1:
			_doubt(_extra)
		_aisle = aisle
		_extra = Vector2i(-99, -99)
		return
	if aisle != -1 and posing == 2 and pt.y == aisle - 1 and absi(pt.x - bt.x) <= 1:
		_extra = pt


func _doubt(cell: Vector2i) -> void:
	_check = {"cell": cell, "t": 14.0}
	host.combat._pop("…313? 하나 많은데.", _boss.loco.logical + Vector2(0, -30), Color("E8C860"))
	_boss.brain.last_seen = _tc(cell)
	_boss.brain._go(AIBrain.S.SEARCH)
	_log("재고 세기 — 하나 많음 %s" % str(cell))


func _recheck(pt: Vector2i, bt: Vector2i) -> void:
	_check["t"] = float(_check["t"]) - 0.1
	var cell: Vector2i = _check["cell"]
	if _boss.brain.state == AIBrain.S.COMBAT:
		_check = {}
		return
	if Vector2(bt).distance_to(Vector2(cell)) > 1.6 and float(_check["t"]) > 0.0:
		_boss.brain.last_seen = _tc(cell)
		return
	if pt == cell:                                                         # 아직 그 칸이다 — 장부 끝으로 방독면을 툭 친다
		_sv("COUNTED", v("COUNTED") + 1)
		host.combat._pop("…숨을 쉬네?", _boss.loco.logical + Vector2(0, -30), Color("E05040"))
		host.hint("두목이 장부 끝으로 방독면을 툭 친다. 마네킹은 숨을 쉬지 않는다.", 3.5)
		_boss.brain.gauge = AIBrain.DETECT_AT
		_boss.brain.last_seen = host.player.loco.logical
		_boss.brain._go(AIBrain.S.COMBAT)
		_log("재고 세기에 걸림")
	else:
		host.combat._pop("312. 잘못 셌나.", _boss.loco.logical + Vector2(0, -30), Color("C8C0A8"))
		_boss.brain.gauge = 0.0
		_boss.brain._go(AIBrain.S.RETURN)
		_log("재고 세기 — 잘못 셌음")
	_check = {}


# ---------------------------------------------------------------- 볼트 작업복: 알아보고 외친다 · 생포 표지
func _suit() -> void:
	var vault := worn() == VAULT
	var cap := vault and sb_alive()
	for e in host.combat.enemies:
		if not _gang(e) or e == _lookout:
			continue
		if cap:
			e.set_meta("capture", "SB")
		elif e.has_meta("capture") and str(e.get_meta("capture")) == "SB":
			e.remove_meta("capture")
		if vault and not _shouted and e.brain.state in [AIBrain.S.SUSPICIOUS, AIBrain.S.SEARCH, AIBrain.S.COMBAT] \
				and e.loco.logical.distance_to(host.player.loco.logical) <= 10.0 * 32.0:
			_shouted = true
			host.combat._pop("S-07 작업복! 생포만 — 3,000이다!", e.loco.logical + Vector2(0, -30), Color("E05040"))
			host.hint("패거리가 파란 작업복을 알아봤다 — 쏘지 말고 잡으라고 소리친다.", 3.5)


# ---------------------------------------------------------------- 탈의실: 그들이 찾는 건 작업복이다
func _fitting(pt: Vector2i) -> void:
	var t := str(st.vars.get_v("PC_TORSO"))
	if t == _torso:
		return
	var was := _torso
	_torso = t
	if _mid() != HALL or not pt in FITTING or _clock - _lose_t < LOSE_GAP:
		return
	var lost := 0
	for e in host.combat.enemies:
		if _gang(e) and e.brain.state in [AIBrain.S.COMBAT, AIBrain.S.SEARCH, AIBrain.S.LOST, AIBrain.S.SUSPICIOUS]:
			e.brain.gauge = 0.0
			e.brain._go(AIBrain.S.RETURN)
			lost += 1
	if lost > 0:
		_lose_t = _clock
		host.hint("커튼 너머로 발소리가 지나간다. '…어디 갔어? %s 입은 놈!' — 다른 옷을 찾지는 않는다." % ("파란 작업복" if Gear.base(was) == VAULT else "그 옷"), 3.5)
	_log("탈의실에서 갈아입음(%s → %s · 놓침 %d)" % [was, t, lost])


# ---------------------------------------------------------------- 진열창 미끼: 사람 눈이 파란 작업복으로 몰린다
func _lure(dt: float) -> void:
	if _lure_t <= 0.0 or _mid() != HALL:
		return
	_lure_t -= dt
	for e in host.combat.enemies:
		if not _gang(e) or e == _lookout or e.brain.state == AIBrain.S.COMBAT:
			continue
		e.brain.last_seen = _tc(WINDOW_MARK)
		if e.brain.state != AIBrain.S.SEARCH:
			e.brain._go(AIBrain.S.SEARCH)


func _window_state() -> String:
	var pd := int(st.vars.get_v("PD_R01_6"))
	var base := "fallen" if int(st.vars.get_v("DG_GA")) >= 1 else ("tag" if pd >= 10 else ("target" if pd <= -10 else ""))
	if v("DECOY") == 1:
		return "decoy" if base == "" else "decoy_" + base
	return base


# ---------------------------------------------------------------- 원고 명령(@cmd ga …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"decoy":
			decoy()
		"undecoy":
			undecoy()
		"box":
			box(int(a[1]))
	done.call()


## 진열창 가운데 마네킹에 볼트 작업복을 입힌다(한 번) — 입고 있지 않은 한 벌을 가져간다
func decoy() -> void:
	if v("DECOY") == 1 or int(st.vars.get_v("DG_GA")) >= 1:
		return
	var spare := int(st.call_fn("has", [VAULT, 2])) == 1 or (int(st.call_fn("has", [VAULT])) == 1 and worn() != VAULT)
	if not spare:
		return
	st.call_fn("take", [VAULT, 1])
	_sv("DECOY", 1)
	if v("DECOY_DAY") == 0:
		_sv("DECOY_DAY", day())                                            # 소문은 첫 미끼 다음 날 한 번
	if host.map != null and _mid() == HALL:
		host.map.set_prop_state(WINDOW_AT, _window_state())
		if worn() == VAULT:
			host.hint("유리에 비친 내 작업복과 마네킹의 작업복이 똑같다. 둘 중 어느 쪽인지 — 그들은 가까운 쪽을 볼 것이다.", 4.0)
		else:
			_lure_t = LURE_S
			host.hint("위층에서 누가 외친다. '진열창! 작업복이다!' 발소리가 정문 쪽으로 몰린다.", 4.0)
	_log("진열창 미끼(%s)" % ("소용없음 — 나도 작업복" if worn() == VAULT else "몰려감 30초"))


func undecoy() -> void:
	if v("DECOY") != 1:
		return
	_sv("DECOY", 0)
	st.call_fn("give", [VAULT, 1])
	_lure_t = 0.0
	if host.map != null and _mid() == HALL:
		host.map.set_prop_state(WINDOW_AT, _window_state())
	_log("미끼를 도로 벗김")


## 작업복 상자: 1 넘김 · 2 태움(원고 선택) — 3 바꿔치기 · 5 빈 상자는 상자를 닫을 때(_on_box) · 4는 사흘 뒤 하루 판정
func box(n: int) -> void:
	if v("BOX") != 0 or not n in [1, 2]:
		return
	_sv("BOX", n)
	_sv("BOX_DAY", day())
	var b: Dictionary = host.map.boxes.get(CRATE_AT, {}) if host.map != null and _mid() == STORE else {}
	if not b.is_empty():
		(host.box_contents(b)["items"] as Dictionary).clear()               # 끌어다 둔 상자 · 타 버린 상자 — 안의 것은 더 없다
	if n == 2 and _mid() == STORE:
		host.map.set_prop_state(CRATE_AT, "burnt")
		host.combat.ord.zones.append({"p": _tc(CRATE_AT), "r": 1.5 * 32.0, "t": 8.0, "t0": 8.0, "kind": "fire", "team": "env", "w": {"dot": 4.0}})
		for e in host.combat.enemies:
			if is_instance_valid(e) and not e.cmb.dead:
				e.hear("impact", _tc(CRATE_AT))
	_log("작업복 상자 %s" % ("넘김" if n == 1 else "태움"))


## 상자를 닫았다: 작업복이 남았나 · 우비가 들었나(바꿔치기 3 · 빈 상자 5) — 인솔조가 보고 있으면 그 자리에서 들킨다
func _on_box(b: Dictionary, c: Dictionary) -> void:
	if str(b.get("kind", "")) != "suit_crate" or v("BOX") != 0:
		return
	var suits := 0
	var coats := 0
	for k in (c["items"] as Dictionary):
		var base := str(k).split("@")[0]
		if base == SUIT:
			suits += int(c["items"][k])
		elif base == RAINCOAT:
			coats += int(c["items"][k])
	var r := 0
	if coats >= 1 and suits < 5:
		r = 3
	elif suits == 0:
		r = 5
	if r == 0:
		return
	if watched():                                                          # 셔터 앞 인솔조가 본다 — 그 자리에서 상자째 실어 간다
		_sv("BOX", 4)
		_sv("BOX_DAY", day())
		(c["items"] as Dictionary).clear()
		host.hint("'어이 — 거기, 상자에서 손 떼!' 인솔조 둘이 달려와 상자를 통째로 손수레에 싣는다. 모자란 벌수를 세며 혀를 찬다.", 4.5)
		_log("상자 손댐 — 인솔조에게 들킴(그 자리 수거)")
		return
	_sv("BOX", r)
	_sv("BOX_DAY", day())
	_log("작업복 상자 %s(작업복 %d · 우비 %d)" % ["바꿔치기" if r == 3 else "빈 상자", suits, coats])


# ---------------------------------------------------------------- 하루 판정(06:00): 판도 반영 한 번 · 사흘 뒤 인솔조 수거
func _on_day(d: int) -> void:
	if v("BOX") == 0 and v("CRATE_DAY") > 0 and d >= v("CRATE_DAY") + PICKUP_DAYS and sb_alive():
		_sv("BOX", 4)
		_sv("BOX_DAY", d - 1)                                                # 오늘 아침 실어 갔다 — 반영도 오늘(반쯤 된 상태 없음, P10)
		_log("인솔조가 상자를 그냥 가져감")
	var bx := v("BOX")
	if bx >= 1 and v("BOX_DONE") == 0 and d > v("BOX_DAY"):
		_sv("BOX_DONE", 1)
		st.vars.set_v("PD_R01_6", int(st.vars.get_v("PD_R01_6")) + int(PD_DELTA.get(bx, 0)))
		if bx == 3:
			_sv("FEUD", 1)
		_log("판도 PD-R01-6 %+d → %d" % [int(PD_DELTA.get(bx, 0)), int(st.vars.get_v("PD_R01_6"))])


# ---------------------------------------------------------------- 두목이 쓰러졌다: 정리 · 패거리가 흩어진다
func _on_down(e: Enemy) -> void:
	if str(e.who) == "" or str(e.who) != BOSS or v("BOSS") == 1:
		if e == _lookout and v("SEEN") == 0:
			_reveal(false)
		return
	_sv("BOSS", 1)
	st.kill(BOSS)
	var msg := Dungeon.check_clear(st, HALL)
	host.hint("두목이 쓰러졌다. 재고 장부가 바닥에 펼쳐진다 — '마네킹 312'." + ("  " + msg if msg != "" else ""), 4.0)
	for o in host.combat.enemies:
		if _gang(o) and o != e:
			o.brain.flee(15.0 + randf() * 5.0)
	_boss = null
	_log("두목 처리 — 정리 %s" % ("됨" if msg != "" else "-"))
