## 관악(R01) 사이드 퀘스트 SQ-S06 「근무자: 공란」 진행기(단계 1-11f, SD-04a §4.6). 원고: script/act1/SQ-S06.txt · SAGOGAE.txt(황보서현 · 권은서 · 게시판) ·
##   TRAVEL.txt(연보경 짐칸) · R01_NORTH.txt(심도겸 배) · JM_PEOPLE.txt(염희정 종이) · SADANG.txt(반로아 길). 맵: X-SH 시흥 고개 초소 · Q-30 탄약고 ·
##   월드 자리(다리목 검문 · 노들섬 남문) · X-SG 영창 · 배급 줄.
## 단계는 이 진행기 한 곳에서만, 오르기만 한다(SD-20). 진해원의 자리는 SQ_S06_JIN 하나(P3): 0 탄약고 · 1 호위 · 2 짐칸 · 3 노들섬 남문 · 4 영창(자수) ·
##   5 계엄군 손 · 6 죽음 · 7 혼자 길 위. 해법 SQ_S06_SOL: 1 짐칸 · 2 등록증 · 3 배 · 4 자수 · 5 인도 · 6 처치 · 7 혼자 닿음 · 8 혼자 잡힘 · 9 걸어서 남문.
## 수색(원문 수치): 첫 접촉 +24시간 시흥 고개 → 48시간마다 사당 고개 → 봉천 고개 → 노량진. 진해원과 함께 그 권역에 들면 수색조가 선다(권역 한 번) —
##   상황은 매번 굴린다(탐문 · 쉼 · 뒤따름 · 흔적만, 3~4명, 오는 쪽, 재미 검수 2). 7일이 지나도록 탄약고에 두면 혼자 길을 나선다(06시 판정 · 씨앗 고정).
## 재미 검수(SD-23 계획 때 8건 + 해 보고 싶은 짓 '전투복 미끼'): plan _plans/SQ-S06_plan.md.
class_name SideS06
extends Node

const JIN := "N-R01-064"
const HWANG := "N-R01-047"
const KWON := "N-R01-048"
const EOM := "N-R01-050"
const YEON := "N-R01-040"
const SIM := "N-R01-057"
const CIV_SHEET := "st_look_m1_s2_hr02_h1_t03_2_pf01_hd00_ey00_pr033"   ## 평상복 진해원(같은 얼굴 · T03)
const UNIFORM := "A-031"
const CIVVY := "A-005"
const PAPERS_ID := "M-062"
const TAG_ID := "M-185"
const SEARCH_H := 24                       ## 첫 접촉 뒤 수색조가 시흥 고개에 닿는 시간
const PHASE_H := 48                        ## 그 뒤 권역이 넓어지는 간격
const SOLO_DAYS := 7
const HUNGRY := 0.8                        ## 굶주린 걸음(음식 하나면 1.0)
const TRAVEL_HUNGRY := 1.25                ## 굶주린 동행과 빠른 이동: 시간 ×1.25(재미 검수 1)
const MEET_R := 6.0                        ## 수색조 분대장이 이만큼 다가오면 말을 건다(웅크리면 3칸)
const HIDE_OK := 20.0                      ## 숨기: 분대장에게서 이만큼 멀어지면 피했다
const ESCAPE_R := 35.0                     ## 달아남: 이만큼 떨어지면 따돌렸다
const DECOY_R := 15.0                      ## 미끼: 진해원이 이만큼 떨어져 있어야
const NEAR_R := 8.0                        ## 진해원이 '곁에 있다'(장면 조건 SQ_S06_NEAR)
const BRIDGE := Vector2i(965, 1157)        ## 한강대교 남단 계단(다리목 검문 자리)
## 수색 권역: [이름, 중심 타일, 반경(칸), 진해원의 한 줄(장소에 묶인 말 — 재미 검수 3)]
const ZONES := [
	["시흥 고개", Vector2i(715, 1545), 30.0, "여기 고개요… 밤마다 이 길 쪽 소리만 들었어요. 발소리인지 바람인지."],
	["사당 고개", Vector2i(1111, 1466), 26.0, "…저기예요. 배급 줄. (걸음이 멈춘다) 판독기 소리가 여기까지 들리는 것 같아요."],
	["봉천 고개", Vector2i(905, 1300), 26.0, "봉천… 그 아저씨들, 이 동네 사람이었어요. 이름도 못 물어봤어요."],
	["노량진", Vector2i(900, 1185), 30.0, "학원가네요. 할아버지가 여기서 '대피 적성' 공부했대요. 3등급 받았다고. 우습죠."],
]
const SAY_RIVER := 1 << 8                   ## SAID 비트: 한강이 처음 보임
const FEEDS := {"I-031": "…이거, 우리 거네요. 태성 전투식량. (한참 보다가 뜯는다) 맛은 똑같아요. 진짜 똑같아.",
	"I-030": "건빵… 근무 설 때 주머니에 넣고 다녔어요. 별사탕은 맨 나중에.",
	"I-044": "버섯이요? (조심스럽게 한 입) …사당 냄새가 나요. 나쁘다는 게 아니라.",
	"I-036": "바퀴… 고기요? (눈을 감고 먹는다) 네. 고마워요. 진짜로요."}

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _food_ids: Array = []
var squad: Dictionary = {}                 ## 지금 선 수색조: {"zone", "kind", "men": [Enemy], "lead": Enemy, "state", "t", "seen"}
var chasers: Array = []                    ## 다리목에서 쫓아오는 계엄병
var ambient: Dictionary = {}               ## 권역 → 탐문하는 계엄병(진해원이 없을 때도 수색이 보인다)
var _boars_day := -1
var _map_ref = null


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s06"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.enemy_down.connect(_on_down)
	host.combat.resident_down.connect(_on_resident_down)
	host.combat.mates.hid.connect(_on_hid)
	host.combat.mates.regrouped.connect(_on_regrouped)
	host.travel_block = _travel_block
	if FileAccess.file_exists("res://data/items_food.json"):
		_food_ids = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items_food.json")) as Dictionary).keys()


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v(k, n)


func _log(s: String) -> void:
	if log_on:
		print("[공란] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S06")


func _now() -> int:
	return Clock.abs_min(host.date_text)


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S06", n)
		_log("단계 %d" % n)


func _zone() -> String:
	return host.map.id if host.map != null else ""


func _has(id: String) -> bool:
	return bool(st.call_fn("has", [id]))


func _seed(tag: String) -> int:
	return absi(hash("s06:%s:%s" % [tag, str(st.vars.get_v("P_REGNO"))]))


func _over() -> bool:
	return v("SQ_S06_SOL") > 0


func _mate() -> Dictionary:
	return host.combat.mates.get_mate(JIN)


## 진해원이 주인공 곁에서 걷고 있나(숨음 · 기다림이 아니라)
func _with_me() -> bool:
	var m := _mate()
	return v("SQ_S06_JIN") == 1 and not m.is_empty() and str(m["mode"]) in ["escort", "follow"] and is_instance_valid(m["actor"])


func _jin_dist() -> float:
	var m := _mate()
	if m.is_empty() or not is_instance_valid(m["actor"]) or str(m["mode"]) == "hidden":
		return 1e9
	return (m["actor"] as Actor).loco.logical.distance_to(host.player.loco.logical) / 32.0


func _say(text: String, secs := 5.0) -> void:
	host.hint("진해원: \"%s\"" % text, secs)


# ---------------------------------------------------------------- 단계
## 퀘스트가 열린다(단계 10) — 그 전에 한 일만큼 따라 올린다(P2)
func _start(why: String) -> void:
	if v("V_ACT") < 1:
		return
	if stage() == 0:
		_up(10)
		_log("발동(%s)" % why)
	_catch_up()


func _catch_up() -> void:
	if stage() < 10:
		return
	if v("SQ_S06_MET") == 1:
		_up(20)
	if v("SQ_S06_DISC") > 0 and (_now() >= v("SQ_S06_DISC") + SEARCH_H * 60 or v("SQ_S06_LEADER") > 0):
		_up(30)
	if v("SQ_S06_ROUTE") >= 2:
		_up(40)


## 첫 접촉(탄약고 첫 진입 · 쪽지 · 대화): 수색 시계가 여기서부터 돈다(재미 검수 7)
func _discover() -> void:
	if v("SQ_S06_DISC") == 0:
		_sv("SQ_S06_DISC", _now())
		_sv("SQ_S06_FOUND_AT", day())
		_log("첫 접촉 — 수색 시계")


## 수색 권역 단계(0 아직 · 1 시흥 … 4 노량진)
func phase() -> int:
	if v("SQ_S06_DISC") == 0:
		return 0
	var h := (_now() - v("SQ_S06_DISC")) / 60
	if h < SEARCH_H:
		return 0
	return mini(4, 1 + (h - SEARCH_H) / PHASE_H)


# ---------------------------------------------------------------- 매 0.25초
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.25:
		return
	_t = 0.0
	if host.map == null or host.player == null or v("V_ACT") < 1:
		return
	tick()


func tick() -> void:
	_sv("SQ_S06_FOOD", 1 if _food_ids.any(func(id): return int(st.items.get(id, 0)) > 0) else 0)
	_sv("SQ_S06_PHASE", phase())
	_sv("SQ_S06_NEAR", 1 if v("SQ_S06_JIN") == 1 and _jin_dist() <= NEAR_R else 0)   # 진해원이 곁(8칸)에 있을 때만 검문 · 남문 · 배 · 인도 장면이 열린다(재미 검수 ①)
	if stage() >= 10:
		_catch_up()
	_look_sync()
	_hunger()
	if host.map is WorldMap:
		_place_lines()
		_squad_tick()
		_ambient_tick()
		_chase_tick()
		_cargo_tick()
	if _zone() == "X-SH":
		_boars()
	if _zone() == "X-SG" and v("SQ_S06_REWARD") == 1 and not st.is_dead(HWANG):
		_sv("SQ_S06_REWARD", 2)                                            # 위치만 알린 인도(E): 다음에 오면 포상
		st.call_fn("caps", [150])
		host.hint("황보서현: \"시흥 고개 — 확인됐습니다. 신고 포상 150캡.\" 봉투가 얇다.", 6.0)


## 평상복으로 갈아입은 진해원은 맵을 넘어도 평상복(호위 · 짐칸 동안만 — 영창의 그는 다시 전투복)
func _look_sync() -> void:
	var civ := v("SQ_S06_CLOTH") == 1 and v("SQ_S06_JIN") in [1, 2]
	var want: String = CIV_SHEET if civ else ""
	if civ and str(host.ev.cast_sheets.get(JIN, "")) != CIV_SHEET:
		host.ev.cast_sheets[JIN] = CIV_SHEET
	elif not civ and host.ev.cast_sheets.get(JIN, "") == CIV_SHEET:
		host.ev.cast_sheets[JIN] = "st_n_r01_064"
	var m := _mate()
	if want != "" and not m.is_empty() and is_instance_valid(m["actor"]) and (m["actor"] as Actor).sheet != want:
		_reskin(m["actor"], want)


func _reskin(a: Actor, sheet: String) -> void:
	if not ResourceLoader.exists("res://assets/sprites/%s.tres" % sheet):
		return
	a.sheet = sheet
	a.sprite.sprite_frames = load("res://assets/sprites/%s.tres" % sheet)
	a.meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/%s.json" % sheet))
	a._show()


## 굶주림: 걸음 ×0.8 · 빠른 이동 ×1.25(음식 하나면 둘 다 풀린다)
func _hunger() -> void:
	var m := _mate()
	var hungry := v("SQ_S06_FED") == 0
	if not m.is_empty() and is_instance_valid(m["actor"]):
		(m["actor"] as Actor).loco.speed_mul = HUNGRY if hungry else 1.0
	host.travel_mul = TRAVEL_HUNGRY if (hungry and _with_me()) else 1.0


## 전투복 차림의 진해원과는 빠른 이동으로 큰길을 못 간다(평상복의 두 번째 값, 재미 검수 1)
func _travel_block(_lid: String) -> String:
	if _with_me() and v("SQ_S06_CLOTH") == 0:
		return "진해원: \"이 옷으로 큰길은 못 가요. 누가 보면 바로예요.\" — 걸어서 산길로 가거나, 평상복을 구해 준다."
	return ""


## 장소에 묶인 한 줄(재미 검수 3): 권역마다 한 번 · 한강이 처음 보일 때
func _place_lines() -> void:
	if not _with_me():
		return
	var t := host.map.tile_of(host.player.loco.logical)
	for i in ZONES.size():
		var bit := 1 << i
		if v("SQ_S06_SAID") & bit != 0:
			continue
		var z: Array = ZONES[i]
		if Vector2(t).distance_to(Vector2(z[1])) <= float(z[2]) * 0.6:
			_sv("SQ_S06_SAID", v("SQ_S06_SAID") | bit)
			_say(str(z[3]), 6.0)
			return
	if v("SQ_S06_SAID") & SAY_RIVER == 0 and t.y < 1168 and t.x > 860 and t.x < 1000:
		_sv("SQ_S06_SAID", v("SQ_S06_SAID") | SAY_RIVER)
		_say("강이다… 진짜 강이네요. 근무 서면서 한 번도 못 봤어요. 고개 너머에 이게 있었어.", 6.0)


# ---------------------------------------------------------------- 수색조(진해원과 함께일 때 — 권역 한 번, 매번 다른 상황)
func _zone_at(t: Vector2i) -> int:
	for i in ZONES.size():
		var z: Array = ZONES[i]
		if Vector2(t).distance_to(Vector2(z[1])) <= float(z[2]):
			return i
	return -1


func _squad_tick() -> void:
	if not squad.is_empty():
		_squad_live()
		return
	if v("SQ_S06_JIN") != 1 or _over() or host.box.active or host.ev.busy():
		return
	if host.enc_live != null and host.enc_live.chasing():
		return                                                             # 생포 추적대가 이미 떠 있으면 미룬다(P4)
	var t := host.map.tile_of(host.player.loco.logical)
	var zi := _zone_at(t)
	if zi < 0 or zi >= phase() or v("SQ_S06_SQUADS") & (1 << zi) != 0:
		return
	_squad_spawn(zi)


## 상황 넷(재미 검수 2): 0 탐문(앞길에서 주민에게 묻는 중) · 1 쉼(앞길에 둘러앉아) · 2 뒤따름(등 뒤에서 다가온다) · 3 흔적만(방금 지나갔다)
func _squad_spawn(zi: int) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = _seed("sq%d:%d" % [zi, day()])
	var kind := r.randi_range(0, 3)
	if zi == 0 and kind == 3:
		kind = 0                                                           # 시흥 고개(첫 권역)는 흔적만으로 끝나지 않는다
	if kind == 3:
		_sv("SQ_S06_SQUADS", v("SQ_S06_SQUADS") | (1 << zi))
		host.hint("길바닥에 군화 자국이 줄지어 있다. 꺼진 담배꽁초 — 아직 따뜻하다. 수색조가 방금 이 길을 지나갔다.", 6.0)
		_say("…우리 분대 담배예요. '태성 군용'. 한 시간도 안 됐어요.", 5.0)
		_log("수색조 흔적(%s)" % ZONES[zi][0])
		return
	var me := host.player.loco.logical
	var f: Vector2 = Locomotion.VEC[host.player.loco.facing].normalized()
	var side := f.rotated(PI / 2.0 if r.randf() < 0.5 else -PI / 2.0)
	var dist := r.randf_range(11.0, 14.0)
	var at := me + (f * dist + side * r.randf_range(-3.0, 3.0)) * 32.0
	if kind == 2:
		at = me - f * 14.0 * 32.0 + side * r.randf_range(-2.0, 2.0) * 32.0
	var c := _free_tile(host.map.tile_of(at))
	if c.x < 0:
		return
	var n := r.randi_range(2, 3)
	var men: Array = []
	var lead: Enemy = null
	for k in n + 1:
		var off := Vector2(((k % 2) * 2 - 1) * (k + 1) / 2, (k / 2)) if k > 0 else Vector2.ZERO
		var cc := _free_tile(c + Vector2i(off))
		if cc.x < 0:
			cc = c
		var pos := Vector2(cc.x * 32 + 16, cc.y * 32 + 16)
		var id := "CR-403" if k == 0 else "CR-401"
		var o := {"lv": r.randi_range(6, 10), "team": "calm_s06", "foes": [], "dir": _dir_to(pos, me),
			"sheet": "en_cr403_loco" if k == 0 else "en_cr401_loco"}
		if kind == 2:
			var pt := host.map.tile_of(me)
			o["route"] = [[pt.x, pt.y, 30.0]]
		var e := host.combat.spawn(id, pos, host.map, st, o)
		e.set_meta("s06", 1)
		men.append(e)
		if k == 0:
			lead = e
	squad = {"zone": zi, "kind": kind, "men": men, "lead": lead, "state": "near", "t": 0.0}
	_sv("SQ_S06_KIND", kind)
	var how: String = ["주민 하나를 붙잡고 무언가 묻고 있다", "길가에 둘러앉아 수통을 돌린다", "등 뒤에서 군화 소리가 다가온다"][kind]
	host.hint("계엄군 수색조 %d명 — %s." % [men.size(), how], 5.0)
	if _jin_dist() < 8.0:
		_say("분대장은 손전등을 왼쪽부터 비춰요. …오른쪽 담장으로 붙어요.", 5.0)
	_up(30)
	_log("수색조 %s · 상황 %d · %d명" % [ZONES[zi][0], kind, men.size()])


func _dir_to(from: Vector2, to: Vector2) -> String:
	var d := to - from
	if absf(d.x) > absf(d.y):
		return "E" if d.x > 0 else "W"
	return "S" if d.y > 0 else "N"


func _free_tile(c: Vector2i) -> Vector2i:
	for r in range(0, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := c + Vector2i(dx, dy)
				if not host.map.is_solid(t):
					return t
	return Vector2i(-1, -1)


func _alive(list: Array) -> Array:
	return list.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)


func _squad_live() -> void:
	var men := _alive(squad["men"])
	var lead: Enemy = squad["lead"]
	if men.is_empty():
		_squad_done("전멸")
		return
	if not is_instance_valid(lead) or lead.cmb.dead:
		lead = men[0]
		squad["lead"] = lead
	var me := host.player.loco.logical
	var d := lead.loco.logical.distance_to(me) / 32.0
	squad["t"] = float(squad["t"]) + 0.25
	match str(squad["state"]):
		"near":
			if int(squad["kind"]) == 2 and fmod(float(squad["t"]), 2.0) < 0.26:
				for e in men:                                              # 뒤따름: 2초마다 주인공이 있는 자리로 걸음을 고친다
					e.route = [[host.player.loco.logical, 30.0]]
					e._route_i = 0
					e._route_wait = 0.0
			var crouch: bool = host.combat.crouch
			if d <= (3.0 if crouch else MEET_R) or (int(squad["kind"]) == 2 and d <= MEET_R + 1.0):
				_squad_meet()
			elif d > float(ZONES[int(squad["zone"])][2]) + 12.0:
				host.hint("수색조를 지나쳤다. 등 뒤에서 손전등 하나가 엉뚱한 담장을 훑는다.", 5.0)
				_squad_done("지나침")
		"hide":
			if not host.combat.crouch and d < 10.0:
				host.hint("분대장: \"거기, 웅크린 놈! 일어서!\" — 들켰다.", 4.0)
				_squad_hostile()
			elif d >= HIDE_OK or float(squad["t"]) > 90.0:
				host.hint("수색조가 다른 골목으로 꺾는다. 숨죽였던 숨을 내쉰다.", 5.0)
				_squad_done("숨음")
		"hostile":
			if d >= ESCAPE_R:
				Wanted.add(st, 10)                                         # 살아서 본 자가 있다(원문 +10)
				host.hint("수색조를 따돌렸다. …얼굴은 봤을 것이다.", 5.0)
				_squad_done("따돌림")
		"leave":
			if float(squad["t"]) > 10.0:
				_squad_done("떠남")


## 분대장이 말을 건다: 미끼(주인공이 전투복 · 진해원이 15칸 밖) · 진해원이 곁에 없음(HID) · 같은 분대장 두 번째(LEADER)
func _squad_meet() -> void:
	squad["state"] = "talk"
	_sv("SQ_S06_LEADER", v("SQ_S06_LEADER") + 1)
	var far := _jin_dist() >= DECOY_R
	_sv("SQ_S06_HID", 1 if far else 0)
	if far and Gear.base(str(st.vars.get_v("PC_TORSO"))) == UNIFORM and v("SQ_S06_DECOY") == 0:
		_sv("SQ_S06_DECOY", 1)                                             # 해 보고 싶은 짓: 진해원의 전투복을 입은 주인공이 미끼
	for e in _alive(squad["men"]):
		e.brain.state = AIBrain.S.IDLE
	_up(30)
	host.play_scene("SQS06_SQUAD")


func _squad_hostile() -> void:
	if squad.is_empty():
		return
	squad["state"] = "hostile"
	squad["t"] = 0.0
	for e in _alive(squad["men"]):
		_side(e, false)
	_caught()


func _side(e: Enemy, calm: bool) -> void:
	e.cmb.team = "calm_s06" if calm else "enemy_s06"
	e.foes = [] if calm else ["player", "ally"]
	if not calm:
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
	host.combat._rebuild_list()


func _squad_done(why: String) -> void:
	if squad.is_empty():
		return
	_sv("SQ_S06_SQUADS", v("SQ_S06_SQUADS") | (1 << int(squad["zone"])))
	_leave(_alive(squad["men"]))
	_log("수색조 끝(%s)" % why)
	squad = {}


## 떠나는 계엄병: 노리지 않고 돌아서서 흐려진다(쓰러진 자리는 그대로)
func _leave(men: Array) -> void:
	for e in men:
		e.cmb.team = "gone"
		e.foes.clear()
		e.brain.state = AIBrain.S.RETURN
		var tw: Tween = e.create_tween()
		tw.tween_interval(4.0)
		tw.tween_property(e, "modulate:a", 0.0, 2.0)
		var gone_e: Enemy = e
		tw.tween_callback(func() -> void:
			if is_instance_valid(gone_e):
				gone_e.visible = false
				host.combat.drop_enemy(gone_e))
	host.combat._rebuild_list()


## 탈영병을 감싸다 들켰다(한 번만): BJ −6(정보원 경로 — 원문 '발각 시') · 수배는 따돌리거나 살아남은 자가 있을 때
func _caught() -> void:
	if v("SQ_S06_HOT") == 1:
		return
	_sv("SQ_S06_HOT", 1)
	st.call_fn("aff", ["BJ", -6])
	st.deeds.record(st, "side", "R01", 1, {"BJ": 0}, _now(), {"tag": "SQS06_HOT", "place": "SG", "what": "탈영병 진해원을 데리고 다니는 자가 계엄군 앞에서 달아났다",
		"seen_by": ["BJ"], "about": []})


## 진해원이 없을 때도 권역에 들어서면 탐문하는 계엄병 둘이 보인다(비적대 — 수색이 세계에 보인다, 재미 검수 2)
func _ambient_tick() -> void:
	if _over() or v("SQ_S06_JIN") != 0 or phase() == 0:
		return
	var t := host.map.tile_of(host.player.loco.logical)
	var zi := _zone_at(t)
	if zi < 0 or zi >= phase() or ambient.has(zi):
		for k in ambient.keys():
			var ms: Array = _alive(ambient[k])
			for e in ms:
				if e.loco.logical.distance_to(host.player.loco.logical) < 4.0 * 32.0 and e.say_t <= 0.0:
					e.say_text = ["탈영병 봤나? 스무 살. 전투복. 생포 150캡.", "이 고개 사람이면 알 텐데. 군화 신은 애 하나.",
						"…못 봤어? 다들 못 봤대. 이상하지."][(day() + int(e.get_instance_id() % 3)) % 3]
					e.say_t = 3.5
		return
	var r := RandomNumberGenerator.new()
	r.seed = _seed("amb%d:%d" % [zi, day()])
	var f: Vector2 = Locomotion.VEC[host.player.loco.facing].normalized()
	var c := _free_tile(host.map.tile_of(host.player.loco.logical + f.rotated(r.randf_range(-0.8, 0.8)) * r.randf_range(10.0, 15.0) * 32.0))
	if c.x < 0:
		return
	var list: Array = []
	for k in 2:
		var cc := _free_tile(c + Vector2i(k, 0))
		var e := host.combat.spawn("CR-401", Vector2(cc.x * 32 + 16, cc.y * 32 + 16), host.map, st, {"lv": 6, "team": "calm_s06", "foes": [],
			"sheet": "en_cr401_loco", "route": [[cc.x, cc.y, 6.0], [cc.x + 4, cc.y + 1, 6.0]]})
		e.set_meta("s06a", 1)
		list.append(e)
	ambient[zi] = list
	_up(30)                                                                # 수색조 목격(원문 30)


# ---------------------------------------------------------------- 다리목 검문(엄도현) · 쫓는 계엄병
func _bridge_alarm() -> void:
	_sv("SQ_S06_BFIGHT", 1)
	host.refresh_npcs()
	var at := host.map.tile_of(Vector2(BRIDGE.x * 32 + 16, BRIDGE.y * 32 + 16))
	for k in 2:
		var cc := _free_tile(at + Vector2i(k * 2 - 1, -1))
		if cc.x < 0:
			continue
		var e := host.combat.spawn("CR-401", Vector2(cc.x * 32 + 16, cc.y * 32 + 16), host.map, st, {"lv": 7, "team": "enemy_s06",
			"sheet": "en_cr401_loco", "dir": "S"})
		e.set_meta("s06", 1)
		e.brain.state = AIBrain.S.COMBAT
		e.brain.gauge = 100.0
		chasers.append(e)
	_caught()


func _chase_tick() -> void:
	if chasers.is_empty():
		return
	var men := _alive(chasers)
	if men.is_empty():
		chasers.clear()
		if v("SQ_S06_JIN") == 1 and v("SQ_S06_CHECK") == 0:
			_sv("SQ_S06_CHECK", 4)                                         # 힘으로 넘었다: 같은 검문이 다시 열리지 않는다(재미 검수 ②)
			host.hint("다리목이 조용해졌다. 다리 위로 길이 열려 있다.", 5.0)
		return
	var near := false
	for e in men:
		if e.loco.logical.distance_to(host.player.loco.logical) < ESCAPE_R * 32.0:
			near = true
	if not near:
		Wanted.add(st, 10)
		host.hint("다리목 호루라기 소리가 멀어진다. 따돌렸다.", 5.0)
		_leave(men)
		chasers.clear()


## 노들섬은 계엄 땅이 아니다: 남문에 닿으면 쫓던 계엄병이 다리 가운데서 멈춘다
func _stand_down() -> void:
	var men := _alive(chasers) + (_alive(squad["men"]) if not squad.is_empty() else [])
	if men.is_empty():
		return
	host.hint("조합 경비들이 총을 든다. 쫓던 계엄병들이 다리 가운데서 멈춰 선다 — 여기서부터는 계엄군 땅이 아니다.", 6.0)
	_leave(men)
	chasers.clear()
	squad = {}


# ---------------------------------------------------------------- A 행상 짐칸(수송대 V54가 사당에 있을 때 · 다리목에 닿는 시각)
## 수송대가 사당을 떠나는 분 뒤 5시간 = 다리목(노들섬 남단 정류장 한 시간 전)
func _cargo_eta(from: int) -> int:
	var t := from
	for k in 60:
		if Caravans.v54_at(t) != 2:
			return t + 5 * 60
		t += 60
	return from + 6 * 60


func _cargo_tick() -> void:
	if v("SQ_S06_JIN") != 2 or host.box.active or host.ev.busy():
		return
	if _now() < v("SQ_S06_GATE_AT"):
		return
	var at := Vector2(BRIDGE.x * 32 + 16, BRIDGE.y * 32 + 16)
	if host.player.loco.logical.distance_to(at) <= 20.0 * 32.0 and not st.is_dead(YEON):
		host.play_scene("SQS06_CARGO")                                     # 주인공이 곁에 있다: 함께 검문
		_sv("SQ_S06_GATE_AT", _now() + 24 * 60)                            # 장면 중 다시 열리지 않게
	else:
		_cargo_luck(false)


## 주인공이 곁에 없거나 지켜만 봤다: 연보경이 혼자 넘긴다(씨앗 고정 70%)
func _cargo_luck(watched: bool) -> void:
	if _seed("cargo") % 100 < 70:
		if watched:
			host.hint("엄도현이 짐소 배를 한 번 툭 치고 손을 턴다. \"가.\" 수송대가 다리를 건넌다.", 5.0)
		_arrive(1, watched)
	else:
		_sv("SQ_S06_HOW", 2)
		_taken(8, "다리목 짐 검사에 걸렸다")
		if watched:
			host.hint("다리목에서 짐소 배 밑이 뒤집혔다. 진해원이 끌려 나간다. 연보경이 고개를 돌린다.", 6.0)


func _on_day(_d: int) -> void:
	if v("V_ACT") < 1:
		return
	_sv("SQ_S06_BFIGHT", 0)                                                # 다리목 소동은 하루가 지나면 가라앉는다
	var j := v("SQ_S06_JIN")
	if j == 7:
		_solo_roll()
	elif j == 0 and v("SQ_S06_TOLD") == 1 and not _over():
		_taken(5, "위치 신고")                                             # 위치만 알린 인도(E): 다음 날 계엄군이 탄약고에 내려갔다
		_sv("SQ_S06_REWARD", 1)
		_hand_effects()
	elif (j == 0 or (j == 1 and (host.combat.mates.away.has(JIN) or not _with_me()))) and v("SQ_S06_DISC") > 0 and day() >= v("SQ_S06_FOUND_AT") + SOLO_DAYS and not _over():
		_solo_go()                                                         # 7일: 받고 안 한 퀘스트(탄약고 · 어딘가에 기다리게 두고 감) — 혼자 길을 나선다
	if v("SQ_S06_SOL") == 6 and v("SQ_S06_TAG") == 0 and phase() >= 1:
		if _has(TAG_ID):
			_sv("SQ_S06_TAG", 1)                                           # 군번줄을 먼저 챙겼다: 수색조가 신원을 못 확인(BJ +3 없음 · 전단은 '실종')
		else:
			_sv("SQ_S06_TAG", 2)
			st.call_fn("aff", ["BJ", 3])


func _solo_p() -> int:
	var p := 50 + 5 * (v("SQ_S06_FED") + v("SQ_S06_CLOTH") + v("SQ_S06_PAPERS") + (1 if v("SQ_S06_ROUTE") >= 1 else 0))
	if v("SQ_S06_PAPERS") == 1 and v("SQ_S06_CLOTH") == 1:
		p = 70                                                             # 원문 B '혼자 보내면 70%'
	return mini(70, p)


func _solo_go() -> void:
	_sv("SQ_S06_SOLO_P", _solo_p())
	_sv("SQ_S06_SOLO_DAY", day())
	_sv("SQ_S06_JIN", 7)
	_start("혼자")
	_drop_mate()
	_log("혼자 길 위 · %d%%" % v("SQ_S06_SOLO_P"))


## 혼자 간 다음 날 06시 판정 한 번(씨앗 고정 — 저장 · 불러오기로 바뀌지 않는다)
func _solo_roll() -> void:
	if day() <= v("SQ_S06_SOLO_DAY"):
		return
	if _seed("solo") % 100 < v("SQ_S06_SOLO_P"):
		_sv("SQ_S06_JIN", 3)
		_sv("SQ_S06_SOL", 7)
		_sv("SQ_S06_DAY", day())
		_sv("SQE_DESERTER", 1)
		st.call_fn("karma", [50])
		st.call_fn("aff", ["ND", 5])
		_up(50)
		_up(100)
		_sv("SQ_S06_REWARD", 4)                                            # 군번줄은 남문에서 건넨다
		_deed("SQS06_SOLO", {"ND": 0}, "탈영병 진해원이 혼자 노들섬 남문에 닿았다")
		_log("혼자 닿음")
	else:
		_sv("SQ_S06_HOW", 1)
		_taken(8, "혼자 가다 잡힘")


# ---------------------------------------------------------------- 결과
## 노들섬에 닿았다(A · B · C · 걸어서): 400 XP · 군번줄 M-185 · SQE_DESERTER · ND +5 · 카르마 +100(B는 JH +2)
func _arrive(sol: int, watched := true) -> void:
	if _over():
		return
	_sv("SQ_S06_JIN", 3)
	_sv("SQ_S06_SOL", sol)
	_sv("SQ_S06_DAY", day())
	_sv("SQE_DESERTER", 1)
	_drop_mate()
	_start("남문")
	_up(50)
	_up(100)
	if watched:
		_reward()
	else:
		_sv("SQ_S06_REWARD", 3)                                            # 남문에서 진해원이 직접 건넨다(멀리 있는 가방에 바로 들어오지 않게, 재미 검수 ③)
	st.call_fn("karma", [100])
	st.call_fn("aff", ["ND", 5])
	if sol == 2:
		st.call_fn("aff", ["JH", 2])
	_stand_down()
	host.refresh_npcs()
	var what := {1: "고개길 수송대 짐칸에 탄 탈영병이 다리목을 넘었다", 2: "위조 등록증을 쥔 탈영병이 다리목 판독기를 통과했다",
		3: "밤 물길로 탈영병 하나가 노들섬 갈대밭에 내렸다", 9: "탈영병 하나가 다리목을 넘어 노들섬 남문에 닿았다"}
	_deed("SQS06_ARRIVE", {"ND": 0}, str(what.get(sol, "")))
	_log("노들섬 도착(해법 %d)" % sol)


## 노들섬 몫: 400 XP · 군번줄(혼자 닿은 판은 군번줄만)
func _reward() -> void:
	if v("SQ_S06_REWARD") == 5:
		return
	if v("SQ_S06_REWARD") != 4:
		st.call_fn("xp", [400])
	st.call_fn("give", [TAG_ID, 1])
	_sv("SQ_S06_REWARD", 5)


## 계엄군 손에(51): 자수(4 — 영창 사흘 · 배급 줄) · 인도(5) · 혼자 잡힘(8)
func _taken(sol: int, why: String) -> void:
	if _over():
		return
	_sv("SQ_S06_JIN", 4 if sol == 4 else 5)
	_sv("SQ_S06_SOL", sol)
	_sv("SQ_S06_DAY", day())
	if sol == 4:
		_sv("SQ_S06_JAIL_DAY", day())
	_drop_mate()
	_start("계엄군")
	_up(51)
	_up(100)
	_log("계엄군 손(%s)" % why)


func _hand_effects() -> void:
	st.call_fn("karma", [-100])
	st.call_fn("aff", ["BJ", 6])
	for kv in [["YH", -3], ["JG", -3], ["JC", -2]]:
		if st._aff_key(str(kv[0])) != "":
			st.call_fn("aff", kv)
	st.deeds.record(st, "side", "R01", 2, {"JC_BC": -3}, _now(), {"tag": "SQS06_E", "place": "BC", "what": "누가 사당 고개 검문소에 탈영병을 넘겼다",
		"seen_by": ["BJ"], "about": []})


func _deed(tag: String, fx: Dictionary, what: String) -> void:
	st.deeds.record(st, "side", "R01", 1, fx, _now(), {"tag": tag, "place": "ND", "what": what, "seen_by": [], "about": []})


func _drop_mate() -> void:
	if not _mate().is_empty():
		var a = _mate()["actor"]
		host.combat.mates.remove(JIN)
		host._sync_mates()
		if is_instance_valid(a) and host.ev.actors.has(JIN):
			host.ev.run("hide", [JIN], func() -> void: pass)
	host.combat.mates.away.erase(JIN)


func _join() -> void:
	_sv("SQ_S06_JIN", 1)
	for n in host.npcs.duplicate():                                        # 맵 인물(탄약고의 진해원)을 동행으로 떼어 낸다 — 맵 인물 다시 세우기가 지우지 않게
		if str(n["id"]) == JIN:
			host.npcs.erase(n)
			if is_instance_valid(n["actor"]):
				host.map.blockers.erase(n["actor"])
			host.sync_residents()
	if _mate().is_empty():
		if host.ev.actors.has(JIN):
			host.ev.handlers["buddy"].call([JIN], func() -> void: pass)
		else:
			host._bring_buddy(JIN)
	host.combat.mates.set_mode(JIN, "escort")
	_log("호위 시작")


# ---------------------------------------------------------------- 사건
func _on_map(_id: String) -> void:
	var fresh: bool = host.map != _map_ref
	_map_ref = host.map
	if fresh:
		squad = {}
		chasers.clear()
		ambient.clear()
	if host.map == null:
		return
	if v("SQ_S06_JIN") == 1 and _zone() in ["H-03", "CG-05"] and not _over():
		if _zone() == "H-03":                                              # 새벽인력에 생포됐다: 진해원은 그 틈에 혼자 달아난다(동행이 우리에 함께 서지 않게, P3)
			_solo_go()
			host.hint("끌려가는 길에 진해원이 사라졌다. 등 뒤에서 누가 '…노들섬에서요'라고 속삭인 것 같다.", 6.0)
		else:                                                              # 계엄군에 생포됐다: 탈영병도 함께 잡혔다
			_sv("SQ_S06_HOW", 3)
			_taken(8, "주인공과 함께 생포")
			host.hint("호송 차량 뒤칸에서 진해원이 다른 차로 옮겨진다. 눈이 마주쳤지만, 진해원은 고개를 젓는다.", 6.0)
		return
	match _zone():
		"Q-30":
			_start("탄약고")
			_discover()
			var wb: Variant = host.map.boxes.get(Vector2i(3, 7))
			if wb != null and v("SQ_S06_ARM") == 0:
				_sv("SQ_S06_ARM", 1)                                       # 예비군 무기 상자: 원문 W-014 사냥용 소총 한 정(탄약은 상자 표대로)
				(host.box_contents(wb)["items"] as Dictionary)["W-014"] = 1
			if v("SQ_S06_JIN") == 3:
				host.map.set_prop_state(Vector2i(5, 1), "signed")          # 근무표 마지막 칸 아래 '2277 진해원 — 근무 끝'
		"X-SG":
			if _with_me() and v("SQ_S06_PERSUADE") == 0 and v("SQ_S06_SEEN_SG") == 0:
				_sv("SQ_S06_SEEN_SG", 1)
				_say("…여, 여기는 사당이잖아요. (걸음이 멈춘다)", 5.0)      # 재미 검수 6: 데려가는 길이 보이는 순간


func _boars() -> void:
	var h := Clock.hour(host.date_text)
	if (h >= 5 and h < 20) or _boars_day == day():
		return
	_boars_day = day()
	for k in ["boar1", "boar2"]:                                           # 원문 '변이 멧돼지 CR-101(밤), 들개' — 멧돼지는 크리처 묶음과 함께(이월), 지금은 들개
		host.combat.spawn("CR-104", host.map.mark_pos(k), host.map, st, {"lv": 5, "dir": host.map.mark_dir(k)})


func _on_hid(id: String) -> void:
	if id != JIN:
		return
	_sv("SQ_S06_HID", 1)
	host.hint("진해원이 근처에 숨었다 — 돌아와 곁에 서면 다시 따라온다.", 5.0)


## 숨었다 다시 따라올 때의 한 줄: 미끼 뒤 · 밤 · 사당 · 그 밖(날마다 다르게, 재미 검수 3)
func _on_regrouped(id: String) -> void:
	if id != JIN:
		return
	_sv("SQ_S06_HID", 0)
	var h := Clock.hour(host.date_text)
	if v("SQ_S06_DECOY") == 2:
		_sv("SQ_S06_DECOY", 3)
		_say("제 옷 입으니까 어때요? 무겁죠. …저 그거 이 년 입었어요.")
		return
	if h >= 20 or h < 5:
		_say("(어둠 속에서) 저예요. 쏘지 마세요. …그냥 습관이에요.")
		return
	var t := host.map.tile_of(host.player.loco.logical)
	if Vector2(t).distance_to(Vector2(ZONES[1][1])) < 40.0:
		_say("여기 사람 많아요. 다들 저 쳐다보는 것 같아서… 벽만 보고 있었어요.")
		return
	var lines := ["왔네요. 진짜 왔네.", "숨는 건 잘해요. 그것만 배웠어요.", "발소리 듣고 알았어요. 걸음이 계엄군이랑 달라요.", "…다리가 저려서 일어나는 데 한참 걸렸어요."]
	_say(lines[(day() + v("SQ_S06_LEADER")) % lines.size()])


func _on_down(e: Enemy) -> void:
	if not e.cmb.dead or not (e.has_meta("s06") or e.has_meta("s06a")):
		return
	if e.cmb.last_by in ["player", "mate"]:
		Wanted.add(st, 2, "kill")                                          # 계엄군 사살 +2/명(SD-03a §6.5)


## 진해원이 쓰러졌다: 주인공 손이면 F(카르마 −100은 호스트가 이미) — 시신 목에 군번줄
func _on_resident_down(id: String, killed: bool) -> void:
	if id != JIN or not killed or _over():
		return
	_dead(true)


func _dead(by_pc: bool) -> void:
	_sv("SQ_S06_JIN", 6)
	_sv("SQ_S06_SOL", 6)
	_sv("SQ_S06_DAY", day())
	_start("죽음")
	_up(100)
	var at := host.player.loco.logical
	var m := _mate()
	if not m.is_empty() and is_instance_valid(m["actor"]):
		at = (m["actor"] as Actor).loco.logical
	else:
		for n in host.npcs:
			if str(n["id"]) == JIN and is_instance_valid(n["actor"]):
				at = n["actor"].loco.logical
	_drop_mate()
	var c := host.map.tile_of(at)
	var key := "s06:tag"
	if not st.boxes.has(key):
		var items := {TAG_ID: 1}
		if v("SQ_S06_CLOTH") == 0:
			items[Gear.key_of(UNIFORM, 2)] = 1
		st.boxes[key] = {"items": items, "opened": 0, "taken": 0}
	if not host.map.boxes.has(c):
		host.map.boxes[c] = {"x": c.x, "y": c.y, "w": 1, "h": 1, "kind": "_corpse", "eid": "", "name": "진해원의 유해", "owner": "", "lock": 0,
			"cond": "", "key": key}
	if not by_pc:
		st.kill(JIN)
		st.book.died(JIN, host.date_text)
	_log("진해원 죽음(%s)" % ("주인공" if by_pc else "전투"))


## 호위 중 쓰러짐 = 죽음(기절 대신 — 원문 '호위 대상'): 주인공이 죽인 게 아니면 카르마 없음
func _mate_watch() -> void:
	var m := _mate()
	if not m.is_empty() and bool(m["down"]) and not _over():
		host.hint("진해원이 쓰러졌다. …숨소리가 없다.", 6.0)
		_dead(false)


func _physics_process(_dt: float) -> void:
	if host != null and v("SQ_S06_JIN") == 1:
		_mate_watch()


# ---------------------------------------------------------------- 원고 명령(@cmd s06 …)
func _cmd(a: Array, done: Callable) -> void:
	var what := str(a[0]) if a.size() > 0 else ""
	var arg := str(a[1]) if a.size() > 1 else ""
	match what:
		"go":
			var mk := str(a[2]) if a.size() > 2 else ""
			done.call()
			host.go.call_deferred(arg, mk)
			return
		"flyer":
			_sv("SQ_S06_FLYER", 1)
			_start("전단")
		"notes":
			_start("쪽지")
			_discover()
		"met":
			_sv("SQ_S06_MET", 1)
			_start("대화")
			_discover()
			_up(20)
		"route":
			_sv("SQ_S06_ROUTE", maxi(1, v("SQ_S06_ROUTE")))
		"asked":
			_sv("SQ_S06_ROUTE", 2)
			_start("길 안내")
			_up(40)
		"join":
			_join()
		"stay":
			host.combat.mates.set_mode(JIN, "wait")
		"feed":
			_feed()
		"cloth":
			st.call_fn("take", [CIVVY, 1])
			st.call_fn("give", [Gear.key_of(UNIFORM, 2), 1])                # 이 년 입은 전투복 — 낡음(420캡 새 옷이 아니다, 재미 검수 ⑤)
			_sv("SQ_S06_CLOTH", 1)
			_look_sync()
			var m := _mate()
			if not m.is_empty() and is_instance_valid(m["actor"]):
				_reskin(m["actor"], CIV_SHEET)
			elif host.ev.actors.has(JIN):
				_reskin(host.ev.actors[JIN], CIV_SHEET)
		"papers":
			st.call_fn("take", [PAPERS_ID, 1])
			_sv("SQ_S06_PAPERS", 1)
		"persuade":
			_sv("SQ_S06_PERSUADE", 1)
			if v("SQ_S06_JIN") == 0:
				_join()
		"solo":
			_solo_go()
		"note":
			_sv("SQ_S06_NOTE", 1)
		"pass":
			_sv("SQ_S06_CHECK", {"talk": 1, "bribe": 2, "papers": 3}.get(arg, 1))
			if arg == "papers":
				host.hint("판독기가 삑 — 초록 불. 진해원의 손이 등록증을 너무 꽉 쥐고 있다.", 5.0)
		"flee", "fight":
			if v("SQ_S06_JIN") == 2:
				_sv("SQ_S06_JIN", 1)                                       # 짐칸에서 굴러 나왔다: 다시 호위
				host._bring_buddy(JIN)
				host.combat.mates.set_mode(JIN, "escort")
			if not squad.is_empty():
				_squad_hostile()
			else:
				_bridge_alarm()
			host.hint("달아나라 — 진해원은 엄폐하며 따라온다. 35칸을 벌리면 따돌린다." if what == "flee" else "싸움이다. 진해원은 엄폐한다.", 5.0)
		"back":
			pass
		"arrive":
			done.call()
			if arg == "boat":
				_arrive(3)
				host.advance_minutes(60)
				host.ev.run("fade_in", ["black", "8"], func() -> void: pass)
			else:
				_arrive(2 if v("SQ_S06_CHECK") == 3 else 9)
			return
		"squad":
			if arg == "pass":
				if not squad.is_empty():
					squad["state"] = "leave"
					squad["t"] = 0.0
					_squad_done("통과")
			elif arg == "hide":
				if not squad.is_empty():
					squad["state"] = "hide"
					squad["t"] = 0.0
				host.hint("웅크린 채(%s) 분대장에게서 20칸 멀어진다. 서면 들킨다." % ("웅크리기" if host.combat.crouch else "웅크리기 키"), 6.0)
		"decoy":
			_sv("SQ_S06_DECOY", 2)
			Wanted.add(st, 5)
			if not squad.is_empty():
				_sv("SQ_S06_SQUADS", v("SQ_S06_SQUADS") | (1 << int(squad["zone"])))   # 진해원은 그 사이 권역을 지나간다
				squad["state"] = "hostile"
				for e in _alive(squad["men"]):
					_side(e, false)
			host.hint("수색조가 당신을 '탈영병'으로 쫓는다. 그 사이 진해원은 이 권역을 빠져나간다.", 6.0)
		"cargo":
			match arg:
				"":
					_sv("SQ_S06_CARAVAN", 1)
					_sv("SQ_S06_CARGO_AT", _now())
					_sv("SQ_S06_GATE_AT", _cargo_eta(_now()))
					_sv("SQ_S06_JIN", 2)
					_sv("SQ_S06_ROUTE", 2)
					_up(40)
					_drop_mate()
					var hh := (v("SQ_S06_GATE_AT") / 60) % 24
					host.hint("진해원이 짐소 둘째 짐칸 밑으로 들어간다. 수송대는 %02d시쯤 다리목(한강대교 남단)에 닿는다 — 곁에 있으려면 그때 거기로." % hh, 7.0)
				"pass":
					host.hint("수송대가 다리를 건넌다. 남문 앞, 짐소 배 밑에서 기어 나온 진해원이 군모를 벗어 강에 던진다.", 6.0)
					_arrive(1)
				"luck":
					_cargo_luck(true)
		"boat":
			_sv("SQ_S06_BOAT", 1)
			_sv("SQ_S06_ROUTE", 2)
			_up(40)
			done.call()
			host.ev.run("fade_out", ["black", "8"], func() -> void:
				host.advance_minutes(60)
				host.play_scene("SQS06_BOAT"))
			return
		"surrender":
			if arg == "ok":
				_taken(4, "자수")
				st.call_fn("karma", [25])
				st.call_fn("aff", ["BJ", 4])
				st.call_fn("xp", [200])
				st.deeds.record(st, "side", "R01", 2, {"BJ": 0}, _now(), {"tag": "SQS06_D", "place": "SG", "what": "탈영병 진해원이 사당 고개 검문소에 자진 복귀했다",
					"seen_by": ["BJ"], "about": []})
			else:
				_taken(5, "자수했으나 재교육")                             # 카르마 변화 없음(재미 검수 6)
		"hand":
			_taken(5, "인도")
			st.call_fn("caps", [150])
			_hand_effects()
		"reward":
			_reward()
		"tell":
			_sv("SQ_S06_TOLD", 1)
			_start("신고")
	done.call()


## 음식 하나(전투식량이면 '우리 거네요' — 음식마다 반응, 재미 검수 3)
func _feed() -> void:
	var pick := ""
	for id in ["I-031", "I-030", "I-044", "I-036"]:
		if _has(id):
			pick = id
			break
	if pick == "":
		for id in _food_ids:
			if int(st.items.get(id, 0)) > 0:
				pick = str(id)
				break
	if pick == "":
		return
	st.call_fn("take", [pick, 1])
	_sv("SQ_S06_FED", 1)
	_say(str(FEEDS.get(pick, "(허겁지겁 먹는다) …고마워요. 사흘 만이에요.")), 6.0)
