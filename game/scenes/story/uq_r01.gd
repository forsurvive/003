## 관악(R01) 비표시 퀘스트 넷 진행기(단계 1-12g, SD-05 §3.3 · §3.23~§3.26 · 계획 `_plans/1-12g_UQ-01-02-03-05_plan.md`).
##   UQ-01 「24시」 — 원고 script/act1/UQ-01.txt · 맵 K-11 봉천 번개24 · K-37 노량진 번개24(V24 로봇 창구).
##   UQ-02 「백구의 밥그릇」 — 원고 UQ-02.txt · X-BC 개집 · 월드 스팟 개천 배수구 둥지(@884,1385) · 숲 가장자리(@896,1418).
##     백구 자리 한 값(P3): 밤 나들이 동안 UQ02_DOG_OUT 1 — X-BC · B-01 백구 줄이 모두 이 값을 읽는다. 보이는 나들이(주인공이 가까울 때)는 배우를 세워 걷게 한다.
## 사실은 변수 한 곳(P1) — 변수 뜻은 원고 머리 주석. 시간 판정(목격 · 손님 · 재고 주)은 06:00 하루 판정에서만(P6).
## 비표시(SD-05 §2.6): 알림 없음 · 단계 로그(메모) · XP만.
class_name UqR01
extends Node

const SEEN_P := 40                         ## UQ-01 ③ 다음 날 석라희가 알아챌 확률(%)
const GUEST_P := 50                        ## 졸음 창 밤손님이 오는 날(%)
const BAN_DAYS := 7                        ## 뜯다 들킨 뒤 출입 막힘
const V24_SLOTS := 4                       ## 창구 품목 칸(V24_N1~N4)
# UQ-02: 밤 나들이 두 번(22:30~23:10 · 23:30~00:10) · 길 셋(직행 · 엄태경 오두막 손질터 · 동쪽 담 홈통) — X-BC 안 칸 · 둥지는 월드 칸
const OUT_A := [22 * 60 + 30, 23 * 60 + 10]
const OUT_B := [23 * 60 + 30, 24 * 60 + 10]
const KENNEL := Vector2i(36, 36)           ## X-BC 칸(개집 앞)
const GATE := Vector2i(29, 42)             ## X-BC 칸(아랫문)
const VIA := [[], [Vector2i(50, 38)], [Vector2i(55, 36), Vector2i(48, 41)]]   ## 길마다 거치는 X-BC 칸
const NEST_W := Vector2i(887, 1387)        ## 월드 칸(둥지 앞 — 백구가 밥을 내려놓는 자리)
const NEAR := 70                           ## 이 칸 수 안에 주인공이 있으면 나들이를 보여 준다
const LOOK_S := 5.0                        ## 뒤돌아보는 간격(초)
const SPOT_R := 6.0                        ## 뒤돌아볼 때 움직이는 주인공을 알아채는 거리(칸) — 웅크리면 절반
const FIND_R := 8.0                        ## 둥지 앞에 닿을 때 이 안에 있으면 새끼를 본다
const PUP_DAYS := 30                       ## 처음 본 뒤 그냥 두면 새끼가 혼자 산으로 가는 날

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _dog: Actor = null                     ## 보이는 나들이 배우(없으면 나들이는 변수로만)
var _dog_pts: Array = []                   ## 남은 경유점(월드 픽셀)
var _dog_path := PackedVector2Array()
var _dog_phase := ""                       ## go · stay · sit · back
var _dog_t := 0.0
var _look_t := 0.0
var _pc_last := Vector2.ZERO


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["uqr"] = _cmd
	host.day_tick.connect(_on_day)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v(k, n)


func _log(s: String) -> void:
	if log_on:
		print("[R01 비표시] " + s)


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func _roll(tag: String, pct: int) -> bool:
	return absi(hash("uqr:%s:%s" % [tag, str(st.vars.get_v("P_REGNO"))])) % 100 < pct


func _process(dt: float) -> void:
	_dog_frame(dt)
	_t += dt
	if _t < 1.0:
		return
	_t = 0.0
	_relay_tick()
	_outing_tick()
	_dog_frame(0.0)


# ---------------------------------------------------------------- UQ-01 24시
## 연보경 편에 보낸 카드(§8.1): 수송대가 다음에 봉천 정류장에 서는 순간 닿는다. 그 전에 연보경이 죽으면 카드는 짐과 함께 사라진다(로봇이 재발급).
func _relay_tick() -> void:
	if v("UQ01_RELAY") != 1:
		return
	if st.is_dead("N-R01-040"):
		_sv("UQ01_RELAY", 0)
		_log("연보경 사망 — 카드 전달 끊김(노량진 재발급)")
		return
	if v("CARAVAN_V54") != 1 or v("UQ01_SOL") != 0:
		return
	_sv("UQ01_RELAY", 2)
	_sv("UQ01_SOL", 1)
	_sv("UQ01_CODE", 1)
	st.call_fn("karma", [25])
	st.call_fn("aff", ["BC", 4])
	st.call_fn("xp", [60])
	st.quests.set_stage("UQ-01", 100)
	_log("연보경이 카드를 꽂음 — 봉천점 회선 살아남")


# ---------------------------------------------------------------- UQ-02 백구의 밥그릇
func _min_of_day() -> int:
	return Clock.abs_min(host.date_text) % 1440 if host.date_text != "" else 0


## 지금 나들이 창(1 · 2) — 자정을 넘는 둘째 창은 00:10까지
func _out_window() -> int:
	var m := _min_of_day()
	if m >= OUT_A[0] and m < OUT_A[1]:
		return 1
	if m >= OUT_B[0] or m < OUT_B[1] - 1440:
		return 2
	return 0


func _dog_can_go() -> bool:
	if v("MQ101_STAGE") < 100 or st.is_dead("C-015"):
		return false
	if v("MQ101_DOG") == 1 or v("SQ_S01_DOG") == 1 or v("FQ_JC01_DOG") == 1 or v("FQ_JC01_DOG") == 5:
		return false                                                  # 동행 중엔 주인공 곁(P3)
	return v("UQ02_END") == 0 and v("UQ02_GONE_DAY") == 0


func _win_key(w: int) -> int:
	return day() * 10 + w


func _xbc(c: Vector2i) -> Vector2i:
	return WorldMap.origin_of("X-BC") + c


func _px(c: Vector2i) -> Vector2:
	return Vector2(c.x * 32 + 16, c.y * 32 + 16)


func _near_bc() -> bool:
	if not (host.map is WorldMap) or host.player == null:
		return false
	var k := _xbc(KENNEL)
	return host.player.loco.logical.distance_to(_px(k)) < NEAR * 32.0


## 1초마다: 창이 열리면 나들이를 시작하고(보이면 배우), 창이 닫혔는데 배우가 없으면 끝낸다.
func _outing_tick() -> void:
	var w := _out_window() if _dog_can_go() else 0
	if w > 0 and v("UQ02_DOG_OUT") == 0 and v("UQ02_LEG") != _win_key(w) and _dog == null:
		_sv("UQ02_DOG_OUT", 1)
		_sv("UQ02_LEG", _win_key(w))
		_sv("UQ02_PAW_DAY", day())
		_sv("UQ02_ROUTE", absi(hash("uq02:%d:%d" % [day(), w])) % 3)
		if _near_bc():
			_dog_spawn(false)
		if host.map is WorldMap:
			host.refresh_npcs()
		_log("백구 나들이 %d(길 %d)" % [w, v("UQ02_ROUTE")])
	elif v("UQ02_DOG_OUT") == 1 and _dog == null:
		if w == 0:
			_sv("UQ02_DOG_OUT", 0)
			if host.map is WorldMap:
				host.refresh_npcs()
		elif _near_bc():
			_dog_spawn(true)                                         # 나들이 중에 다가왔다: 둥지 앞에서 밥을 먹이는 중
	if v("UQ02_DOG_OUT") == 1 and not _dog_can_go() and _dog == null:
		_sv("UQ02_DOG_OUT", 0)                                       # 동행 · 죽음 · 끝: 나들이를 접는다


func _dog_spawn(at_nest: bool) -> void:
	_dog = Actor.new()
	var start := NEST_W + Vector2i(1, 0) if at_nest else _xbc(KENNEL)
	_dog.setup("cr_baekgu_loco", _px(start), host.map)
	_dog.mode = "walk"
	host.map.add_actor(_dog)
	_dog._show()
	_dog_pts = []
	if at_nest:
		_dog_phase = "stay"
	else:
		for c in VIA[clampi(v("UQ02_ROUTE"), 0, 2)]:
			_dog_pts.append(_px(_xbc(c)))
		_dog_pts.append(_px(_xbc(GATE)))
		_dog_pts.append(_px(NEST_W))
		_dog_phase = "go"
	_dog_path = PackedVector2Array()
	_dog_t = 0.0
	_look_t = LOOK_S
	_pc_last = host.player.loco.logical


func _dog_drop() -> void:
	if _dog != null and is_instance_valid(_dog):
		if host.map != null:
			host.map.remove_actor(_dog)
		_dog.queue_free()
	_dog = null
	_dog_phase = ""


func _dog_home() -> void:
	_dog_pts = [_px(_xbc(GATE)), _px(_xbc(KENNEL))]
	_dog_path = PackedVector2Array()
	_dog_phase = "back"


## 매 프레임: 경유점을 걷는다(발 고정 걸음 — NpcRoutine). 갈 때는 몇 초마다 뒤돌아본다.
func _dog_frame(dt: float) -> void:
	if _dog == null:
		return
	if not is_instance_valid(_dog) or not (host.map is WorldMap):
		_dog = null
		return
	if dt <= 0.0:
		return
	_dog_t += dt
	match _dog_phase:
		"sit":
			_dog.move(Vector2.ZERO, dt)
			if _dog_t > 2.0:
				_dog_home()
			return
		"stay":
			_dog.move(Vector2.ZERO, dt)
			if _out_window() == 0 or _dog_t > 90.0:
				_dog_home()
			return
	if _dog_pts.is_empty():
		_dog.move(Vector2.ZERO, dt)
		if _dog_phase == "go":
			_at_nest()
		elif _dog_phase == "back":
			_dog_drop()
			_sv("UQ02_DOG_OUT", 0)
			host.refresh_npcs()
		return
	var tgt: Vector2 = _dog_pts[0]
	if NpcRoutine.arrived(_dog.loco.render, tgt) or _dog.loco.logical.distance_to(tgt) < 10.0:
		_dog_pts.pop_front()
		_dog_path = PackedVector2Array()
		return
	if _dog_path.is_empty():
		_dog_path = NpcRoutine.with_start(host.map, _dog.loco.logical, tgt)
		if _dog_path.is_empty():
			_dog_pts.pop_front()                                     # 길이 안 잡히면 다음 점으로
			return
	_dog_path = NpcRoutine.walk_path(_dog, _dog_path, dt)
	if _dog_phase == "go":
		_look_t -= dt
		if _look_t <= 0.0:
			_look_t = LOOK_S
			_look_back()
		_pc_last = host.player.loco.logical


func _look_back() -> void:
	var pc := host.player.loco.logical
	var d := _dog.loco.logical.distance_to(pc) / 32.0
	_dog.loco.facing = Locomotion.snap8(pc - _dog.loco.logical)
	var r := SPOT_R * (0.5 if host.combat.crouch else 1.0)
	var moving := pc.distance_to(_pc_last) > 1.5
	if d < r and moving:
		_sv("UQ02_SPOT", v("UQ02_LEG"))
		_dog_phase = "sit"
		_dog_t = 0.0
		var dodge := absi(hash("uq02s:%d" % v("UQ02_LEG"))) % 2 == 0
		host.hint("백구가 뒤돌아 앉는다. 꼬리를 흔든다 — 이번엔 안 가겠다는 얼굴이다." if dodge else
			"백구가 갑자기 엉뚱한 풀숲을 킁킁댄다. 딴청이다. …이번엔 안 가겠다.", 4.0)
		_log("나들이 들킴")


func _at_nest() -> void:
	_dog_phase = "stay"
	_dog_t = 0.0
	var d := _dog.loco.logical.distance_to(host.player.loco.logical) / 32.0
	if d <= FIND_R and v("UQ02_END") == 0:
		if v("UQ02_SAW") == 0:
			_sv("UQ02_SAW", 1)
			_sv("UQ02_PUP_SPOT", day())
		if v("UQ02_HOW") == 0 or v("UQ02_HOW") == 3:
			_sv("UQ02_HOW", 1)
		_up("UQ-02", 10)
		_up("UQ-02", 20)
		host.hint("백구가 덤불 앞에 밥을 내려놓는다. 덤불 속에서 작은 머리가 나온다 — 귀 끝이 하얗다.", 5.0)
		_log("나들이를 따라가 새끼를 봄")


func _up(qid: String, n: int) -> void:
	if st.quests.stage(qid) < n:
		st.quests.set_stage(qid, n)


func _on_day(d: int) -> void:
	if v("UQ01_SOL") == 3 and v("UQ01_SEEN") == 0 and v("UQ01_THEFT_DAY") > 0 and d > v("UQ01_THEFT_DAY") and v("UQ01_WITNESS") == 0:
		_sv("UQ01_WITNESS", 1)                                       # 판정은 한 번 — 씨앗 = 뜯은 날(불러오기로 다시 굴리지 못함)
		if _roll("seen:%d" % v("UQ01_THEFT_DAY"), SEEN_P):
			_sv("UQ01_SEEN", 1)
			st.call_fn("aff", ["BC", -6])
			_log("석라희가 뜯은 사람을 알아챔(BC −6 · 가격 +10%)")
	_sv("UQ01_GUEST", d if (not st.is_dead("N-R01-038") and _roll("guest:%d" % d, GUEST_P)) else 0)
	var wk := (d - 1) / 7
	if wk != v("V24_WEEK"):
		_sv("V24_WEEK", wk)
		for i in V24_SLOTS:
			_sv("V24_N%d" % (i + 1), 0)
	if v("V24_HOSTILE") == 0 and st.is_dead("N-R01-508"):
		_sv("V24_HOSTILE", 1)
	if v("UQ02_END") == 0 and v("UQ02_GONE_DAY") == 0 and v("UQ02_CARRY") == 0 and v("UQ02_PUP_SPOT") > 0 and d >= v("UQ02_PUP_SPOT") + PUP_DAYS:
		_sv("UQ02_GONE_DAY", d)                                      # 그냥 두면 새끼는 백구 밥으로 커서 혼자 산으로(소멸 — 바크로만)
		_log("새끼가 혼자 산으로 감")
	_uq03_day(d)


# ---------------------------------------------------------------- UQ-03 다리목 하사의 배급표
## 하루 판정(계획 §8.3): 받고 7일 — 냉담만(카르마 그대로) · 30일 — 갖기(RES 3 · 카르마 −10) · 사진을 쥔 채 30일 — 끝(전함 결과 그대로).
## 알린 뒤 7일 — 엄도현이 초소에서 사라짐(EOM 2). 엄도현 · 엄옥순이 죽으면 단계 90(물건은 남는다).
func _uq03_day(d: int) -> void:
	var s: int = st.quests.stage("UQ-03")
	if s > 0 and s < 100 and (st.is_dead("N-R01-050") or (s == 10 and st.is_dead("N-R01-507"))):
		st.quests.set_stage("UQ-03", 90)
		_log("UQ-03 소멸(엄도현 · 엄옥순 사망)")
		s = 90
	if s == 10:
		if v("UQ03_COLD") == 0 and d >= v("UQ03_GOT_DAY") + 7:
			_sv("UQ03_COLD", 1)
		if d >= v("UQ03_GOT_DAY") + 30:
			_sv("UQ03_RES", 3)
			_sv("UQ03_DAY", d)
			st.call_fn("karma", [-10])
			st.quests.set_stage("UQ-03", 100)
			_log("UQ-03 ③ 갖기로 정산(30일)")
	elif s == 30 and v("UQ03_DELIVER_DAY") > 0 and d >= v("UQ03_DELIVER_DAY") + 30:
		_sv("UQ03_RES", 1)
		_sv("UQ03_DAY", d)
		st.quests.set_stage("UQ-03", 100)
		_log("UQ-03 사진을 안 건넨 채 끝")
	if v("UQ03_EOM") == 1 and d >= v("UQ03_REPORT_DAY") + 7 and not st.is_dead("N-R01-050"):
		_sv("UQ03_EOM", 2)                                           # 근무지 이탈 — 다리목은 무명 분대장(N-BJ-C2)
		_sv("UQ03_EOM_DAY", d)
		if host.map is WorldMap:
			host.refresh_npcs()
		_log("엄도현 근무지 이탈")


func _tickets() -> int:
	return st.count_of("M-003") + st.count_of("M-167")


## 창구 결제: 청솔 상품권을 먼저(배급표 한 장과 같다 — SD-15 V24), 모자라면 배급표.
func _v24_buy(id: String, cost: int, slot: int) -> void:
	if _tickets() < cost:
		host.hint("배급표가 모자란다.", 3.0)
		return
	var left := cost
	var g := mini(left, st.count_of("M-167"))
	if g > 0:
		st.call_fn("take", ["M-167", g])
		left -= g
	if left > 0:
		st.call_fn("take", ["M-003", left])
	st.call_fn("give", [id, 1])
	_sv("V24_N%d" % slot, v("V24_N%d" % slot) + 1)
	_sv("V24_TICKETS", _tickets())
	_log("V24 %s (배급표 %d)" % [id, cost])


func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"gut":
			_sv("UQ01_THEFT_DAY", day())
			_log("등록기 뜯음(카르마 −25)")
		"caught":
			_sv("UQ01_BAN_DAY", day() + BAN_DAYS)
			_sv("UQ01_SEEN_SAID", 1)
			_log("뜯다 들킴 — 7일 출입 막힘")
		"fixed":
			_log("등록기 직접 수리")
		"tin":
			_sv("UQ01_TIN_SAID", day())
			if v("UQ01_TIN_BC") == 0:
				_sv("UQ01_TIN_BC", 1)
				st.call_fn("aff", ["BC", 1])
		"relay":
			if st.count_of("M-427") > 0:
				st.call_fn("take", ["M-427", 1])
				_sv("UQ01_RELAY", 1)
				_log("카드를 연보경 편에 보냄")
		"saw":
			if v("UQ02_PUP_SPOT") == 0:
				_sv("UQ02_PUP_SPOT", day())
			_up("UQ-02", 10)
			_up("UQ-02", 20)
		"carry":
			if host.map is WorldMap:
				host.refresh_npcs()
		"adopt":
			_sv("UQ02_END_DAY", day())
			if host.map is WorldMap:
				host.refresh_npcs()
		"free":
			_sv("UQ02_END_DAY", day())
			_sv("UQ02_SEE_OFF_UNTIL", day() + 3)
		"kill":
			_sv("UQ02_END_DAY", day())
			_sv("UQ02_BARK_UNTIL", day() + 7)
			var hr := int(st.vars.get_v("GAME_HOUR"))
			if v("UQ02_HOW") == 2 and (hr >= 22 or hr < 1) and not st.is_dead("N-R01-034"):   # 남솔은 들은 그날 밤 몰래 따라 나온다(P7 — 그 자리에 있었다)
				_sv("UQ02_WITNESS", 1)
				st.call_fn("aff", ["BC", -8])
				host.hint("덤불 뒤에서 작은 숨소리 — 남솔이다. 남솔이 울면서 아랫문 쪽으로 달려간다.", 5.0)
			if host.map is WorldMap:
				host.refresh_npcs()
		"bag":
			if v("UQ03_COLD") != 2:                                      # 자기 몫만 한 번 도로 가져간다(배급표 ≤10 · 식량 ≤2)
				_sv("UQ03_COLD", 2)
				var t := mini(10, st.count_of("M-003"))
				var f := mini(2, st.count_of("I-031"))
				if t > 0:
					st.call_fn("take", ["M-003", t])
				if f > 0:
					st.call_fn("take", ["I-031", f])
				_log("엄도현이 가방에서 배급표 %d · 식량 %d를 도로 가져감" % [t, f])
		"report":
			_sv("UQ03_EOM", 1)
			_sv("UQ03_EOM_DAY", day())
			_sv("UQ03_REPORT_DAY", day())
			_sv("UQ03_DAY", day())
			_log("황보서현에게 알림 — 엄도현 강등")
		"v24_count":
			_sv("V24_TICKETS", _tickets())
		"v24":
			_v24_buy(str(a[1]), int(a[2]), int(a[3]))
	done.call()
