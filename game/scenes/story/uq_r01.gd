## 관악(R01) 비표시 퀘스트 넷 진행기(단계 1-12g, SD-05 §3.3 · §3.23~§3.26 · 계획 `_plans/1-12g_UQ-01-02-03-05_plan.md`).
##   UQ-01 「24시」 — 원고 script/act1/UQ-01.txt · 맵 K-11 봉천 번개24 · K-37 노량진 번개24(V24 로봇 창구).
##   UQ-02 「백구의 밥그릇」 — 원고 UQ-02.txt · X-BC 개집 · 월드 스팟 개천 배수구 둥지(@884,1385) · 숲 가장자리(@896,1418).
##     백구 자리 한 값(P3): 밤 나들이 동안 UQ02_DOG_OUT 1 — X-BC · B-01 백구 줄이 모두 이 값을 읽는다. 보이는 나들이(주인공이 가까울 때)는 배우를 세워 걷게 한다.
##   UQ-67 「보라매 마지막 비행」(1-12i i5 — 원고 UQ-67.txt · 월드 스팟 L-R01-17 · 봉천 X-BC 가로등 · 아랫문 밖 렌치 · 새벽인력 매점) ·
##   UQ-63 「연수원의 졸업장」(1-12i i4 — 원고 UQ-63.txt · 맵 K-01 · 새 K-03 · X-S07 투입구 · 인터컴 SQS03_INTERCOM) ·
##   UQ-64 · 65(1-12i i1 · i2) · UQ-66 「전지 하나, 냉장고 둘」(1-12i i3 — 원고 UQ-66.txt · 맵 K-26 · K-26B · GS-02 · 월드 스팟 L-R01-25).
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
# UQ-05: 누렁이가 처지는 자리 넷(X-NS 칸 — 남서 비탈 · 남동 덤불 · 버스 뒤 풀밭 · 동쪽 고갯마루, 날 씨앗) · 정류장 앞(닿으면 데려다줌)
const NS_SPOTS := [Vector2i(4, 20), Vector2i(28, 20), Vector2i(10, 8), Vector2i(27, 3)]
const NS_MID := Vector2i(15, 11)
const NS_NEAR := 40.0                      ## 잃는 순간 주인공이 고개에서 이만큼 안이면 다음 바퀴로(허공에서 소가 생기지 않게)
const SD_CARAVAN := Vector2i(22, 12)       ## X-SD 수송대 짐소 자리
const SD_POST := Vector2i(20, 12)          ## X-SD 광장 말뚝(위강윤 대여 소 자리)
const BC_CARAVAN := Vector2i(24, 38)       ## X-BC 수송대 짐소 자리
const COW_HOME_R := 6.0                    ## 정류장 앞 이 칸 안에 닿으면 데려다줌
const COW_LOSE_R := 14.0                   ## 주인공이 이보다 멀어지면 누렁이가 선다(놓음)
const COW_GAP := 2.0                       ## 주인공 뒤 이 칸쯤에서 따라온다
const DOG_X := [990, 1090]                 ## 남부순환로 동쪽(낙성대 → 사당) — 소 냄새에 들개 무리가 한 번 붙는다
const SEEN_R := 25.0                       ## 사당 광장에서 이 안에서 잡으면 위강윤이 본다(낮)
const MOO_R := 25.0                        ## 처진 누렁이 울음이 들리는 거리

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
var _cow: Actor = null                     ## 끌려오는 누렁이(UQ05_COW 2) — 월드 맵에서만
var _cow_path := PackedVector2Array()
var _cow_rp := 0.0
var _cow_home := false
var _last_v54 := -1
var _moo_day := -1
var _u66_key := ""                         ## 수산시장 운반조 · 꼬리표 그림 상태(바뀌면 인물 · 소품을 다시 세운다)
var _spot_o := {}


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["uqr"] = _cmd
	host.day_tick.connect(_on_day)
	host.map_entered.connect(_on_map)
	if host.combat != null:
		host.combat.resident_down.connect(_on_resident_down)           # 1-12i UQ-62: 삽자루 · 권성민
		host.combat.provoked.connect(_on_provoked)                     # 고시촌 통행 중 패거리를 치면 적대


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
	_cow_frame(dt)
	_kwon_frame(dt)
	_t += dt
	if _t < 1.0:
		return
	_t = 0.0
	_relay_tick()
	_uq66_tick()
	_outing_tick()
	_dog_frame(0.0)
	_cow_tick()
	_gc_tick()


# ---------------------------------------------------------------- UQ-01 24시
## 연보경 편에 보낸 카드(§8.1): 수송대가 다음에 봉천 정류장에 서는 순간 닿는다. 그 전에 연보경이 죽으면 카드는 짐과 함께 사라진다(로봇이 재발급).
func _relay_tick() -> void:
	if v("UQ01_RELAY") != 1:
		return
	if st.is_dead("N-R01-038"):
		_sv("UQ01_RELAY", 0)                                         # 받을 사람이 없다 — 카드는 연보경 짐에 남는다
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
	_uq62_day(d)
	_uq67_day(d)
	_uq63_day(d)
	_uq66_day(d)
	_uq65_day(d)
	_uq64_day(d)
	if v("UQ01_SOL") == 3 and v("UQ01_SEEN") == 0 and v("UQ01_THEFT_DAY") > 0 and d >= v("UQ01_THEFT_DAY") and v("UQ01_WITNESS") == 0:
		_sv("UQ01_WITNESS", 1)                                       # 판정은 한 번 — 씨앗 = 뜯은 날(불러오기로 다시 굴리지 못함)
		if _roll("seen:%d" % v("UQ01_THEFT_DAY"), SEEN_P):
			_sv("UQ01_SEEN", 1)
			st.call_fn("aff", ["BC", -6])
			_log("석라희가 뜯은 사람을 알아챔(BC −6 · 가격 +10%)")
	# 밤손님은 오늘 밤(다음 자정 뒤 03시 — GAME_DAY는 자정에 넘어간다)
	_sv("UQ01_GUEST", d + 1 if (not st.is_dead("N-R01-038") and _roll("guest:%d" % d, GUEST_P)) else 0)
	var s1: int = st.quests.stage("UQ-01")
	if st.is_dead("N-R01-038") and s1 > 0 and s1 < 100:
		st.quests.set_stage("UQ-01", 90)                              # 석라희가 죽으면 소멸(계획 §4.1-6)
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
	_cow_day(d)


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


# ---------------------------------------------------------------- UQ-05 누렁이
func _ns(c: Vector2i) -> Vector2i:
	return WorldMap.origin_of("X-NS") + c


func _cow_tile() -> Vector2i:
	return Vector2i(v("UQ05_CX"), v("UQ05_CY"))


## 1초마다: 고개에서 잃기(V54 봉천 → 길 위 전환) · 사당 소식 출처 · 끌고 가는 동안의 놓음 · 정류장 닿음 · 들개 한 번
func _cow_tick() -> void:
	var now := v("CARAVAN_V54")
	if _last_v54 == 1 and now == 0:
		_cow_lose()
	_last_v54 = now
	var c := v("UQ05_COW")
	if c == 3 and v("UQ05_ABSENT") == 1 and now == 2:
		_sv("UQ05_ABSENT", 0)                                        # 말뚝의 누렁이를 수송대가 데려감
		if host.map != null:
			host.refresh_npcs()
	if (c == 1 or c == 2 or c == 4 or c == 5) and now == 2 and v("UQ05_TOLD") == 0:
		_sv("UQ05_TOLD", 1)                                          # 수송대가 사당에 닿은 뒤에야 위강윤이 안다(P7)
	host.lead_walk = c == 2 and _cow != null and is_instance_valid(_cow) and not _cow_home
	if c == 1 and _moo_day != day() and host.map is WorldMap and host.player != null:
		var dm := Vector2(host.map.tile_of(host.player.loco.logical)).distance_to(Vector2(_cow_tile()))
		if dm < MOO_R and dm > 6.0:
			_moo_day = day()                                             # 흔적 사슬의 첫 고리(재미 검수 — 마커 없이 고개로): 하루 한 번
			host.hint("(고개 쪽에서 두 목소리가 겹친 소 울음이 들린다.)", 4.0)
	if c != 2:
		return
	if not (host.map is WorldMap) or _cow == null or not is_instance_valid(_cow):
		_cow_drop("")
		return
	var ct: Vector2i = host.map.tile_of(_cow.loco.logical)
	_sv("UQ05_CX", ct.x)
	_sv("UQ05_CY", ct.y)
	if _cow_home:
		return
	var d := _cow.loco.logical.distance_to(host.player.loco.logical) / 32.0
	if d > COW_LOSE_R:
		_cow_drop("누렁이가 멈춰 섰다. 고삐가 땅에 끌린다.")
		return
	var at := _cow_arrive(ct)
	if at > 0:
		_cow_home = true
		_sv("UQ05_AT", at)
		host.play_scene.call_deferred("UQ05_BACK")
		return
	var pt: Vector2i = host.map.tile_of(host.player.loco.logical)
	if v("UQ05_DOGS") == 0 and pt.x >= DOG_X[0] and pt.x <= DOG_X[1] and host.enc_live != null:
		if host.enc_live.start({"re": "RE-X01", "state": "S1", "src": "uq05"}):
			_sv("UQ05_DOGS", 1)
			_log("누렁이 냄새에 들개")


func _cow_arrive(ct: Vector2i) -> int:
	var cv := v("CARAVAN_V54")
	if cv == 2 and Vector2(ct).distance_to(Vector2(WorldMap.origin_of("X-SD") + SD_CARAVAN)) <= COW_HOME_R:
		return 1
	if cv == 1 and Vector2(ct).distance_to(Vector2(WorldMap.origin_of("X-BC") + BC_CARAVAN)) <= COW_HOME_R:
		return 1
	if Vector2(ct).distance_to(Vector2(WorldMap.origin_of("X-SD") + SD_POST)) <= COW_HOME_R:
		return 2
	return 0


## 봉천 → 사당 구간이 시작될 때(V54 1 → 0) 한 번: 연보경을 만난 뒤 · MQ-106 교전 · S06 짐칸 해법 · 주인공이 고개 가까이면 다음 바퀴
func _cow_lose() -> void:
	if v("UQ05_COW") != 0 or v("UQ05_LOST_DAY") != 0 or v("TR_YEON_MET") == 0 or st.is_dead("N-R01-040"):
		return
	var m6: int = st.quests.stage("MQ-106")
	if (m6 > 0 and m6 < 100) or v("SQ_S06_CARAVAN") == 1:
		return
	if host.map is WorldMap and host.player != null:
		var near: float = Vector2(host.map.tile_of(host.player.loco.logical)).distance_to(Vector2(_ns(NS_MID)))
		if near < NS_NEAR:
			return
	var d := day()
	var k := absi(hash("uq05:%d:%s" % [d, str(st.vars.get_v("P_REGNO"))]))
	_sv("UQ05_COW", 1)
	_sv("UQ05_LOST_DAY", d)
	_sv("UQ05_ABSENT", 1)
	_sv("UQ05_SPOT", k % NS_SPOTS.size())
	var t := _ns(NS_SPOTS[k % NS_SPOTS.size()])
	_sv("UQ05_CX", t.x)
	_sv("UQ05_CY", t.y)
	var hr := int(st.vars.get_v("GAME_HOUR"))
	_sv("UQ05_CAUSE", 1 if not st.is_dead("N-R01-062") else (3 if hr >= 6 and hr < 20 and (k >> 4) % 2 == 0 else 2))
	_cow_entry()
	_log("누렁이를 고개에서 잃음(자리 %d · 까닭 %d)" % [v("UQ05_SPOT"), v("UQ05_CAUSE")])


## 월드 맵 인물 목록에 처진 누렁이 한 줄(놓아둔 자리 UQ05_CX · CY) — 맵을 다시 읽을 때마다 붙인다
func _cow_entry() -> void:
	if not (host.map is WorldMap):
		return
	var e: Dictionary = {}
	for n in host.map.data["npcs"]:
		if n.get("uq05", false):
			e = n
	if e.is_empty():
		e = {"id": "N-UQ5-COW", "dir": "S", "route": [], "sheet": "cr_cr091_loco", "uq05": true,
			"cond": "UQ05_COW == 1 and (stage(\"MQ-106\") == 0 or stage(\"MQ-106\") >= 100)",
			"bark": "(두 머리 누렁소가 짐을 진 채 풀을 뜯는다. 끊긴 고삐가 풀에 감겼다.)"}
		host.map.data["npcs"].append(e)
	e["x"] = v("UQ05_CX")
	e["y"] = v("UQ05_CY")
	host.refresh_npcs()


func _on_map(_id: String) -> void:
	if not (host.map is WorldMap):
		_gc_clear()                                                      # 고시촌 패거리는 월드에서만(실내로 들어가면 거둔다)
		_kwon_clear()
	elif v("UQ62_WALK") == 2 and v("UQ62_GONE") == day() and _spot_mark("X-GC:d_door") != Vector2.ZERO and _gc_near("X-GC:yard", GC_DESPAWN_R):
		_kwon_walk()
	if _id == "K-26" and v("UQ66_OPEN") == 1 and host.map != null and host.map.has_method("unlock_door"):
		host.map.unlock_door(U66_DOOR.x, U66_DOOR.y)                # 연 철문은 열어 둔다(맵 원고는 잠긴 문 — 사실은 UQ66_OPEN)
	if v("UQ05_COW") == 2 and _cow == null:
		_cow_drop("")                                                # 불러오기 · 실내 · 생포 · 빠른 이동: 그 자리에 놓음(P10)
	if host.map is WorldMap and v("UQ05_COW") >= 1:
		_cow_entry()


## 놓음: 끌던 자리에서 풀을 뜯는다(UQ05_COW 1)
func _cow_drop(msg: String) -> void:
	if _cow != null and is_instance_valid(_cow):
		var ct := Vector2i(int(_cow.loco.logical.x) / 32, int(_cow.loco.logical.y) / 32)
		_sv("UQ05_CX", ct.x)
		_sv("UQ05_CY", ct.y)
		if host.map is WorldMap:
			host.map.remove_actor(_cow)
		_cow.queue_free()
	_cow = null
	_cow_home = false
	host.lead_walk = false
	_sv("UQ05_COW", 1)
	if msg != "":
		host.hint(msg, 4.0)
	_cow_entry()


func _cow_spawn() -> void:
	_cow = Actor.new()
	_cow.setup("cr_cr091_loco", _px(_cow_tile()), host.map)
	_cow.mode = "walk"
	host.map.add_actor(_cow)
	_cow._show()
	_cow_path = PackedVector2Array()
	_cow_rp = 0.0
	_cow_home = false
	host.lead_walk = true


## 매 프레임: 주인공 뒤 COW_GAP칸으로 걷는다(걷기 속도 3.0 — 발 고정 걸음). 싸움 중엔 겁먹고 선다
func _cow_frame(dt: float) -> void:
	if _cow == null or dt <= 0.0:
		return
	if not is_instance_valid(_cow) or not (host.map is WorldMap):
		_cow = null
		return
	if _cow_home or host.combat.in_combat():                             # 싸움 중(적이 교전 상태)엔 겁먹고 선다 — 그냥 서 있는 척후 캠프는 아님
		_cow.move(Vector2.ZERO, dt)
		return
	var me := host.player.loco.logical
	if _cow.loco.logical.distance_to(me) <= COW_GAP * 32.0:
		_cow.move(Vector2.ZERO, dt)
		_cow_path = PackedVector2Array()
		return
	_cow_rp -= dt
	if _cow_path.is_empty() or _cow_rp <= 0.0:
		_cow_rp = 0.8
		_cow_path = NpcRoutine.with_start(host.map, _cow.loco.logical, me)
	if _cow_path.is_empty():
		_cow.move(Vector2.ZERO, dt)
		return
	_cow_path = NpcRoutine.walk_path(_cow, _cow_path, dt)


func _cow_day(d: int) -> void:
	var c := v("UQ05_COW")
	if c == 1:
		var lim := 3 if not st.is_dead("N-R01-062") else 7          # 척후가 살아 있으면 3일 뒤 끌고 감 · 아니면 들개에 쫓겨 7일 뒤
		if d >= v("UQ05_LOST_DAY") + lim and (v("UQ05_SAW") == 0 or lim == 7):
			_sv("UQ05_COW", 5)
			if lim == 3:
				_sv("UQ05_SPILL", 1)                                  # 꾸러미는 척후 캠프 버스 안에 남는다(재미 검수 §8.4)
			_up("UQ-05", 10)
			st.quests.set_stage("UQ-05", 100)
			if host.map is WorldMap:
				host.refresh_npcs()
			_log("누렁이 사라짐(%s)" % ("척후" if lim == 3 else "들개"))
	c = v("UQ05_COW")
	if c == 4 or c == 5:
		if d >= v("UQ05_LOST_DAY") + 7 and v("UQ05_ABSENT") == 1:
			_sv("UQ05_ABSENT", 2)                                     # 위강윤에게 빌린 소
			_sv("UQ05_NEWCOW_DAY", d)
			if host.map != null:
				host.refresh_npcs()
	if v("UQ05_PACK") == 1 and (st.count_of("M-429") == 0 or d >= v("UQ05_PACK_DAY") + 7):
		_sv("UQ05_PACK", 3)                                          # 갖기(팔았거나 7일) — 카르마 −10 한 번
		st.call_fn("karma", [-10])


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
			var told := v("UQ02_SOLNA_TOLD")
			var tonight := (hr >= 22 and day() == told) or (hr < 1 and day() == told + 1)
			if v("UQ02_HOW") == 2 and tonight and not st.is_dead("N-R01-034") and v("SQ_S04_HELD") == 0 and v("SQ_S04_AWAY") == 0:   # 남솔은 들은 그날 밤 몰래 따라 나온다(P7 — 그 자리에 있었다)
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
		"cow_lead":
			if v("UQ05_COW") == 1 and host.map is WorldMap:
				_sv("UQ05_COW", 2)
				_sv("UQ05_LEAD", int(a[1]) if a.size() > 1 else 1)
				_up("UQ-05", 10)
				_up("UQ-05", 20)
				host.refresh_npcs()
				_cow_spawn()
		"cow_home":
			if _cow != null and is_instance_valid(_cow):
				host.map.remove_actor(_cow)
				_cow.queue_free()
			_cow = null
			_cow_home = false
			host.lead_walk = false
			_sv("UQ05_COW", 3)
			# 수송대 앞이면 바로 수송대 짐소 · 말뚝(위강윤 · 밤)이면 다음 사당 정류까지 말뚝에(한 소는 한 곳에, P3) · 허순자가 맡으면 공동 짐소(수송대는 빌린 소)
			_sv("UQ05_ABSENT", 0 if v("UQ05_AT") == 1 else (2 if v("UQ05_RES") == 3 else 1))
			if host.map != null:
				host.refresh_npcs()
		"cow_kill":
			_sv("UQ05_COW", 4)
			st.call_fn("karma", [-25])
			st.call_fn("give", ["M-430", 1])
			if v("UQ05_PACK") == 0:
				st.call_fn("give", ["M-429", 1])
				_sv("UQ05_PACK", 1)
				_sv("UQ05_PACK_DAY", day())
			var hr := int(st.vars.get_v("GAME_HOUR"))
			var post := Vector2(WorldMap.origin_of("X-SD") + SD_POST)
			if Vector2(_cow_tile()).distance_to(post) <= SEEN_R and hr >= 6 and hr < 20 and not st.is_dead("N-R01-043"):
				_sv("UQ05_KILL_SEEN", 1)
				_sv("UQ05_REFUSE_DAY", day() + 3)                          # 위강윤이 봤다 — 수송대 3일 거래 거부
				host.hint("광장 쪽에서 위강윤이 이쪽을 본다. 말없이 고개를 돌린다.", 5.0)
			st.quests.set_stage("UQ-05", 100)
			if host.map != null:
				host.refresh_npcs()
		"v24_count":
			_sv("V24_TICKETS", _tickets())
		"v24":
			_v24_buy(str(a[1]), int(a[2]), int(a[3]))
		"q65":                                                           # UQ-65 단계(비표시 — 수업을 시작하면 10)
			if st.quests.stage("UQ-65") < int(a[1]):
				st.quests.set_stage("UQ-65", int(a[1]))
		"q65book":                                                       # 수업 끝: 문항집 M-439(몰래 집었으면 이미 손에) · 원문 80 XP의 나머지 30 · 지능 판정 보너스 1회
			if v("UQ65_BOOK") == 0:
				_sv("UQ65_BOOK", 1)
				st.call_fn("give", ["M-439", 1])
			if v("UQ65_XP") == 0:
				_sv("UQ65_XP", 1)
				_sv("UQ65_BONUS", 1)
				_sv("UQ65_LESSON_DAY", day())                                # '다음 시간엔 4번부터' — 같이 푸는 수업은 다음 날부터
				_sv("UQ65_LTODAY", 2)
				st.call_fn("xp", [30])
				st.quests.set_stage("UQ-65", 100)
				host.hint("문항집 여백의 붉은 필기를 읽었다 — 다음 [지능] 판정 하나는 1 모자라도 '문항 해설'로 열린다", 6.0)
				_log("UQ-65 수업 끝 · 문항집")
		"q64tags":                                                       # UQ-64 길덕수가 꼬리표 다섯을 맡김(죽었으면 선반에서 직접)
			if v("UQ64_TAGS") == 0:
				_sv("UQ64_TAGS", 1)
				st.call_fn("give", ["M-440", 5])
				if st.quests.stage("UQ-64") < 10:
					st.quests.set_stage("UQ-64", 10)
		"q64hint":
			_sv("UQ64_HINT", 1)
		"q64":                                                           # 대문에서 건넴 — 호감(한 번씩) · 매듭 판정
			_uq64_check()
		"q64mem":                                                        # 남은 꼬리표를 기념탑 받침 볼트에(다른 매듭)
			var left := st.count_of("M-440")
			if left > 0:
				st.call_fn("take", ["M-440", left])
			_sv("UQ64_MEM", 1)
			_uq64_finish()
		"q67start":                                                      # UQ-67 단계 10 — 렌치를 만난 날 + 3이 렌치의 날(만나기 전 · TOLD · 렌치 사망이면 없음 — '사흘'을 렌치가 말한다)
			_up("UQ-67", 10)
			if v("UQ67_DUE") == 0 and v("UQ67_MET") == 1 and v("UQ67_TOLD") == 0 and v("UQ67_CORE") == 0 and not st.is_dead("N-R01-063"):
				_sv("UQ67_DUE", day() + U67_DAYS)
		"q67told", "q67move":                                            # 머리카락 얘기 · 난로가 식음(봉인 · 혼자 꺼냄) — 렌치가 잠자리를 옮기고 기한이 사라진다
			_sv("UQ67_DUE", 0)
			if v("UQ67_WRENCH") == 0:
				_sv("UQ67_WRENCH", 2)
			_u67_refresh()
		"q67fail":                                                       # 꺼내다 실패 — 숨 한 번 20라드 · 고리 r6
			_u67_rad(20)
			_u67_zone()
		"q67take":                                                       # 꺼냄 — 지님(CORE 2) · 20라드 · 고리 꺼짐
			_sv("UQ67_CORE", 2)
			_sv("UQ67_DAY", day())
			_sv("UQ67_DUE", 0)
			st.call_fn("give", ["M-445", 1])
			_u67_rad(20)
			_up("UQ-67", 20)
			_u67_zone()
			_u67_jet()
		"q67pick":                                                       # 쓰러진 렌치 품에서 거둠
			_sv("UQ67_CORE", 2)
			_sv("UQ67_DAY", day())
			st.call_fn("give", ["M-445", 1])
			_u67_rad(10)
			_up("UQ-67", 20)
		"q67seal":                                                       # ② 봉인 — 카르마 +25 · 고리 꺼짐 · 매듭
			_sv("UQ67_CORE", 1)
			_sv("UQ67_DAY", day())
			_sv("UQ67_DUE", 0)
			st.call_fn("karma", [25])
			_u67_zone()
			_u67_jet()
			_u67_finish("봉인")
		"q67sell":                                                       # ③ 새벽인력 매점 — 300캡 · SB +3 · HALF면 렌치가 다음 06:00 아랫문 밖에서 반 몫을 묻는다
			_sv("UQ67_CORE", 3)
			_sv("UQ67_DAY", day())
			st.call_fn("caps", [300])
			st.call_fn("aff", ["SB", 3])
			_u67_finish("새벽인력에 팖")
		"q67power":                                                      # ① 봉천 발전기 — 다음 06:00 가로등 · BC +5 · 판도 +2
			_sv("UQ67_CORE", 4)
			_sv("UQ67_DAY", day())
			st.call_fn("aff", ["BC", 5])
			_sv("PD_R01", v("PD_R01") + 2)
			_u67_finish("봉천 발전기")
		"q67half":                                                       # 남무진이 렌치 몫 150캡을 쳐 줌 — 렌치는 다음 06:00 봉천으로 받으러 떠난다(그날은 활주로 공원에서 '내일 간다')
			_sv("UQ67_HALFPAY", day())
		"q67sulk":                                                       # 같이 꺼낸 몫을 묻음 — 렌치가 삐져 떠남
			_sv("UQ67_WRENCH", 5)
			_u67_refresh()
		"q67pay":                                                        # 아랫문 밖 — 반 몫 150캡([캡 150] 꼬리표가 뺀다 · 카르마 +10)
			st.call_fn("karma", [10])
			_sv("UQ67_WRENCH", 1)
			_u67_refresh()
		"q67cheat":                                                      # 떼먹음 — BC −2 · 소문
			_sv("UQ67_WRENCH", 6)
			st.call_fn("aff", ["BC", -2])
			_u67_refresh()
		"q62start":                                                      # UQ-62 단계 10 — 권성민을 만남(비표시)
			_up("UQ-62", 10)
		"q62card":                                                       # 답안 카드(M-446) — 처음 한 장 · 망치면 예비 한 장(CARD 2)
			_sv("UQ62_CARD", 2 if v("UQ62_CARD") >= 1 else 1)
			st.call_fn("give", ["M-446", 1])
		"q62grade":                                                      # ① 채점기 [과학 45] — 성적표 M-448
			_sv("UQ62_GRADED", 1)
			if st.count_of("M-446") > 0:
				st.call_fn("take", ["M-446", st.count_of("M-446")])
			st.call_fn("give", ["M-448", 1])
			_up("UQ-62", 20)
		"q62gradebad":                                                   # 어림짐작 — 카드를 망침(예비까지 망치면 ① 닫힘)
			if st.count_of("M-446") > 0:
				st.call_fn("take", ["M-446", 1])
			if v("UQ62_CARD") == 2:
				_sv("UQ62_CARD", 3)
		"q62paper":                                                      # ② 손재석이 출제를 약속한 날 — 다음 06:00 시험지
			_sv("UQ62_PAPER", day())
		"q62papergive":
			st.call_fn("give", ["M-447", 1])
			_up("UQ-62", 20)
		"q62forge":                                                      # ③ 위조 — 1 자습석 [과학 60] · 2 염희정(캡은 꼬리표가) · 3 어설픈 판
			var how := int(a[1]) if a.size() > 1 else 1
			st.call_fn("give", ["M-450", 1])
			_sv("UQ62_BAD", {1: 0, 2: 2, 3: 1}[how])
			_up("UQ-62", 20)
		"q62done":                                                       # 합격증을 권성민에게 — WAY · 매듭(100) · 카르마(①② +25 · ③ 0 · 어설픈 −10) · 90 XP 한 번 · 스탠드 끔
			var w := int(a[1]) if a.size() > 1 else 1
			_sv("UQ62_WAY", w)
			_sv("UQ62_DONE", day())
			for it in ["M-447", "M-448", "M-449", "M-450"]:
				if st.count_of(it) > 0:
					st.call_fn("take", [it, st.count_of(it)])
			if w <= 2:
				st.call_fn("karma", [25])
			elif v("UQ62_BAD") == 1:
				st.call_fn("karma", [-10])
			if st.quests.stage("UQ-62") < 100:
				st.quests.set_stage("UQ-62", 100)
				if v("UQ62_XP") == 0:
					_sv("UQ62_XP", 1)
					st.call_fn("xp", [90])
			_lamp_off()
			_log("UQ-62 매듭(길 %d)" % w)
		"q62tube":                                                       # 스탠드 진공관을 뺌 — M-014 · 스탠드 꺼짐(재미 검수 P6)
			_sv("UQ62_TUBE", 1)
			st.call_fn("give", ["M-014", 1])
			_lamp_off()
		"q62book":                                                       # 『발파 기능사 실기』 — 폭발물 +2
			st.vars.set_v("PC_SKP_EXPLOSIVES", int(st.vars.get_v("PC_SKP_EXPLOSIVES")) + 2)
			host.hint("폭발물 +2 — 장약량 표를 외웠다", 4.0)
		"q62intro":                                                      # 함준호에게 소개 — 취직하면 JH +3
			_sv("UQ62_INTRO", 1)
		"q62pass":                                                       # 고시촌 통행(그날) — 1 상담료 · 2 화술 · 3 척후 지도 · 4 어제 상담 받은 사람
			_sv("GC_PASS", day())
			_sv("GC_SEEN", 1)
			_gc_calm()
			_log("고시촌 통행(%s)" % str(a[1] if a.size() > 1 else ""))
		"q62own":                                                        # 진짜 분양 — A동 203호 열쇠(캡은 꼬리표가) · 통행 영구
			_sv("GC_OWN", 1)
			_sv("GC_PASS", day())
			st.call_fn("give", ["M-451", 1])
			_gc_calm()
		"q62boss":                                                       # 삽자루 화술 — SQ-S02 C 해법(side_s02 'boss 1')
			_sv("GC_BOSS", 1)
			if host.ev.handlers.has("s02"):
				host.ev.handlers["s02"].call(["boss", "1"], func() -> void: pass)
		"q63start":                                                      # UQ-63 단계 10(비표시 — 깔끔이 · 명부 · 보존함) · 주인공 성이 명부 30 성씨 안인지(MINEOK)
			_up("UQ-63", 10)
			_sv("UQ63_MINEOK", 1 if str(st.vars.get_v("P_SURNAME")) in U63_SURNAMES else 0)
		"q63wait":                                                       # 명부를 한 장씩 대조 — 30분(시계가 간다)
			host.advance_minutes(30)
		"q63put":                                                        # 투입구에 넣음 — 다음 06:00 행정과가 열어 나눈다(20)
			_sv("UQ63_IN", day())
			_up("UQ-63", 20)
		"q63said":
			pass
		"q63ledger":                                                     # 잃은 뒤 수료 대장 — 호명만(DONE 3 · 보상 반)
			_sv("UQ63_IN", day())
			_sv("UQ63_LOST", 2)
			_up("UQ-63", 20)
		"q66start":                                                      # UQ-66 단계 10(비표시 — 철문 · 원무 단말 · 혈액은행 · 시장 전지 이야기)
			_up("UQ-66", 10)
		"q66heard":                                                      # 시장 전지 이야기를 들음(심도겸 · 한가람) — 기한은 들은 날 + 4(재미 검수 W4)
			_up("UQ-66", 10)
			if v("UQ66_HEARD") == 0:
				_sv("UQ66_HEARD", day())
			if v("UQ66_DUE") == 0 and v("UQ66_BATT") == 0 and v("UQ66_PULLED") == 0 and v("SQH_BATT") != 7:
				_sv("UQ66_DUE", day() + U66_DAYS)
				_log("UQ-66 운반조 기한 %d일" % v("UQ66_DUE"))
		"q66watch":                                                      # 냉동고 들창: 심도겸이 살아 있고 웅크리지 않으면 본다(9 = 방금 들킴) · 한 번 들킨 뒤로는 밤(21~05)에 웅크려야
			var night := _hour() >= 21 or _hour() < 5
			if not st.is_dead("N-R01-057") and (not host.combat.crouch or (v("UQ66_CAUGHT") == 1 and not night)):
				_sv("UQ66_CSAID", 9)
		"q66pull":
			_up("UQ-66", 10)
			_sv("UQ66_PULL_DAY", day())
			_u66_freezer()
			_uq66_check()
		"q66back":                                                       # 도로 꽂음 — 시장 전지는 다시 냉동고(BATT 0)
			if v("UQ66_BATT") == 4:
				_sv("UQ66_BATT", 0)
			if not st.is_dead("N-R01-057"):
				_sv("UQ66_CSAID", 3)                                      # 심도겸 '누가 뺐다 넣었어?'(한 번)
			_u66_freezer()
			_uq66_check()
		"q66keep":                                                       # ① 지킴: 한가람 [화술 보통] · 운반조 [화술 어려움] · [힘 7](GS −5)
			if v("UQ66_BATT") == 0 and v("UQ66_PULLED") == 0:
				_sv("UQ66_BATT", 1)
				_sv("UQ66_HOW", {"talk": 1, "scare": 2, "han": 3}.get(str(a[1]), 1))   # 심도겸 대사 · 할인이 이 값을 읽는다
				if str(a[1]) == "scare":
					st.call_fn("aff", ["GS", -5])
				_log("UQ-66 ① 시장 전지를 지킴(%s)" % str(a[1]))
			_u66_freezer()
			_uq66_check()
			_u66_refresh()
		"q66help":                                                       # ② 운반조와 같이 뺌 — 심도겸이 봤다(CSAID 2)
			_sv("UQ66_PULLED", 1)
			_sv("UQ66_BATT", 2)
			_sv("UQ66_GSCELL", 1)
			_sv("UQ66_CSAID", 2)
			_sv("UQ66_PULL_DAY", day())
			st.call_fn("aff", ["GS", 4])
			_u66_freezer()
			_uq66_check()
			_u66_refresh()
		"q66gs":                                                         # 대기등 예비 전원 받침: 441 ③ 예비 전지(GS +3 · 카르마 +10 — 시장이 산다) · 442 ② 시장 전지(GS +4)
			if str(a[1]) == "441":
				_sv("UQ66_GSCELL", 2)
				st.call_fn("aff", ["GS", 3])
				if v("UQ66_BATT") == 0 and v("UQ66_PULLED") == 0:
					_sv("UQ66_BATT", 3)
					st.call_fn("karma", [10])
			else:
				_sv("UQ66_GSCELL", 1)
				_sv("UQ66_BATT", 2)
				st.call_fn("aff", ["GS", 4])
			_up("UQ-66", 10)
			_u66_freezer()
			_uq66_check()
			if host.map != null and host.map.id == "GS-02":
				host.map.set_prop_state(U66_SPARE, "on")
		"q66open":                                                       # 지하 철문(승인 · 퇴원 · 정지 · 정리 · 따기 — 어느 쪽이든 한 값)
			_sv("UQ66_OPEN", 1)
			_up("UQ-66", 20)
			if host.map != null and host.map.id == "K-26":
				host.map.unlock_door(U66_DOOR.x, U66_DOOR.y)
		"q66discharge":                                                  # a) 퇴원 — 병동 다섯이 뒤뜰 벤치로(병동 적은 맵 cond로도 사라진다)
			_sv("UQ66_WARD", 1)
			st.call_fn("karma", [10])
			_u66_clear_ward()
			_sv("UQ66_OPEN", 1)
			_up("UQ-66", 20)
			if host.map != null and host.map.id == "K-26":
				host.map.unlock_door(U66_DOOR.x, U66_DOOR.y)
		"q66stop":                                                       # b) 정지 — 충전대에 앉아 꺼짐(다시 깨울 수 있다)
			_sv("UQ66_NURSE", 2)
			if host.map != null:
				host.refresh_npcs()
				if host.map.id == "K-26":
					host.map.set_prop_state(U66_DOCK, "stopped")
		"q66wake":
			_sv("UQ66_NURSE", 0)
			if host.map != null:
				host.refresh_npcs()
				if host.map.id == "K-26":
					host.map.set_prop_state(U66_DOCK, "")
		"q66fridge":                                                     # 혈액은행 냉장고가 돎(1 예비 · 2 관악 · 3 시장 전지 — 시장이 멎음) · 7호가 로비에 글(다음 06:00 들것이 읽음)
			if v("UQ66_FRIDGE") == 3:
				_sv("UQ66_BATT", 7)
			if _nurse_ok():
				_sv("UQ66_NOTICE", 1)
			if host.map != null and host.map.id == "K-26B":
				host.map.set_prop_state(U66_FRIDGE_AT, "on")
			_up("UQ-66", 20)
			_uq66_check()
		"q66notice":                                                     # 재워 둔 사이 냉장고가 돌았다 — 깨어난 7호가 로비에 글
			if v("UQ66_FRIDGE") != 0 and _nurse_ok():
				_sv("UQ66_NOTICE", 1)
		"q66dg":                                                         # 소윤희에게 직접(7호가 없거나 글 전) — DG 협력 · 정류지(7호가 살아 돌 때 · DG_STOP 0)
			_sv("UQ66_DG", 1)
			_sv("UQ66_DG_SAID", 1)
			if v("DG_STOP") == 0 and _nurse_ok():
				_sv("DG_STOP", 2)
			_uq66_check()
		"q65sneak":                                                      # 교탁 문항집 몰래 집기: 웅크리지 않으면 손재석이 돌아본다(9 = 방금 들킴)
			if not host.combat.crouch:
				_sv("UQ65_STOLE", 9)
		"q65lesson":                                                     # '다음 시간엔 4번부터' — 하루 두 문항까지(4~9 · LTODAY 그날 푼 수)
			if v("UQ65_LESSON_DAY") == day():
				_sv("UQ65_LTODAY", v("UQ65_LTODAY") + 1)
			else:
				_sv("UQ65_LTODAY", 1)
			_sv("UQ65_LESSON", maxi(v("UQ65_LESSON"), 3) + 1)
			_sv("UQ65_LESSON_DAY", day())
	done.call()



# ---------------------------------------------------------------- UQ-67 보라매 마지막 비행(1-12i i5 — SD-05 §3.32)
const U67_DAYS := 3                                ## 발동 뒤 사흘 — 렌치가 직접 꺼내 봉천으로
const U67_CARRY_RAD := 10                          ## 노심을 지닌 채 06:00마다
const U67_JET := Vector2i(1, 1)                    ## 보라매 스팟 안 시험기 칸


func _u67_rad(n: int) -> void:
	st.vars.set_v("PC_RADS", Radiation.rads(st) + n)
	host.hint("배낭이 따뜻하다 — 선량계 바늘이 뜬다(+%d 라드)" % n, 4.0)


## 조건부 Rad 고리(rad_zones COND_ZONES — UQ67_CORE · LEAK)를 지금 맵에 다시 건다
func _u67_zone() -> void:
	if host.map is WorldMap and host.combat != null and host.combat.rad != null:
		host.combat.rad.setup(host.map, st)


func _u67_jet() -> void:
	if host.map is WorldMap:
		var o := spot_o("L-R01-17")
		if o.x >= 0:
			var c := v("UQ67_CORE")
			host.map.set_prop_state(o + U67_JET, "sealed" if c == 1 else ("empty" if c >= 2 else ("core" if v("UQ67_LEAK") == 1 else "")))


func _u67_refresh() -> void:
	if host.map != null and not host.box.active and not host.ev.busy():
		host.refresh_npcs()


func _u67_finish(how: String) -> void:
	_sv("UQ67_DUE", 0)
	if st.quests.stage("UQ-67") < 100:
		st.quests.set_stage("UQ-67", 100)
		if v("UQ67_XP") == 0:
			_sv("UQ67_XP", 1)
			st.call_fn("xp", [90])
		_log("UQ-67 매듭(%s · 렌치 %d)" % [how, v("UQ67_WRENCH")])


func _uq67_day(d: int) -> void:
	if v("UQ67_WRENCH") == 0 and st.is_dead("N-R01-063"):
		_sv("UQ67_DUE", 0)
	var due := v("UQ67_DUE")
	if due > 0 and v("UQ67_CORE") == 0 and v("UQ67_WRENCH") == 0 and d >= due and not st.is_dead("N-R01-063"):
		_sv("UQ67_CORE", 5)                                           # 렌치가 직접 꺼내 봉천으로 — 아랫문 밖에 쓰러진 채(노심은 그 옆)
		_sv("UQ67_WRENCH", 3)
		_sv("UQ67_DAY", d)
		_sv("UQ67_DUE", 0)
		st.kill("N-R01-063")
		_up("UQ-67", 10)
		_log("UQ-67 렌치가 노심을 안고 봉천 아랫문 밖에 쓰러짐")
	elif v("UQ67_WRENCH") == 3 and d > v("UQ67_DAY") and not st.is_dead("N-R01-030"):
		_sv("UQ67_WRENCH", 4)                                         # 다음 날 남무진이 묻어 줌(남무진이 죽었으면 그대로 · 노심은 거뒀으면 없고 아니면 그 자리)
	if v("UQ67_HALFPAY") > 0 and v("UQ67_WRENCH") == 0 and d > v("UQ67_HALFPAY"):
		_sv("UQ67_WRENCH", 1)                                         # 남무진이 쳐 준 반 몫을 받으러 봉천으로 — 그 길로 떠남
	if v("UQ67_CORE") == 2:
		if _owned("M-445") == 0:
			_sv("UQ67_LOST", 1)                                       # 팔거나 버림(값 0 — 거래창엔 안 뜸 · 보관함 포함 셈 A244)
			if st.quests.stage("UQ-67") < 90:
				st.quests.set_stage("UQ-67", 90)
			_log("UQ-67 노심을 잃음")
		elif st.count_of("M-445") > 0:
			_u67_rad(U67_CARRY_RAD)                                   # 배낭에 있을 때만 — 보관함에 넣어 두면 식는다(§7c ③)
	if v("UQ67_CORE") == 3 and v("UQ67_HALF") == 1 and v("UQ67_ASK") == 0 and v("UQ67_WRENCH") == 0 and d > v("UQ67_DAY") and not st.is_dead("N-R01-063"):
		_sv("UQ67_ASK", d)                                            # 같이 꺼낸 몫 — 렌치가 봉천 아랫문 밖에서 기다린다


# ---------------------------------------------------------------- UQ-63 연수원의 졸업장(1-12i i4 — SD-05 §3.31)
const U63_SURNAMES := ["윤", "하", "김", "이", "박", "최", "정", "강", "조", "장", "임", "한", "오", "서", "신", "권", "황", "안", "송", "전", "홍", "유", "고", "문", "도", "차", "방", "나", "남", "백"]   ## S-07 성씨 30(SD-18 §P1 v1.1)
## 다음 06:00: 투입한 묶음을 행정과가 열어 가문별로 나눔(DONE 1 맞춤 · 2 그냥 — 카르마 +25 · 80 XP 한 번 · 100) / 묶음을 잃으면 90(보관함 포함 셈 — A244)
func _uq63_day(d: int) -> void:
	if v("UQ63_IN") > 0 and v("UQ63_DONE") == 0 and d > v("UQ63_IN"):
		var ledger := v("UQ63_LOST") == 2
		_sv("UQ63_DONE", 3 if ledger else (1 if v("UQ63_MATCH") > 0 else 2))
		if v("UQ63_XP") == 0:
			_sv("UQ63_XP", 1)
			st.call_fn("karma", [10 if ledger else 25])
			st.call_fn("xp", [40 if ledger else 80])
		st.quests.set_stage("UQ-63", 100)
		_log("UQ-63 졸업장 나눔(DONE %d · LEFT %d · MINE %d)" % [v("UQ63_DONE"), v("UQ63_LEFT"), v("UQ63_MINE")])
		if host.map != null and host.map.id == "K-01":
			host.refresh_npcs()
	elif v("UQ63_BOX") == 1 and v("UQ63_IN") == 0 and v("UQ63_LOST") == 0 and _owned("M-443") == 0:
		_sv("UQ63_LOST", 1)
		if st.quests.stage("UQ-63") < 90:
			st.quests.set_stage("UQ-63", 90)
		_log("UQ-63 졸업장 묶음을 잃음")


# ---------------------------------------------------------------- UQ-66 전지 하나, 냉장고 둘(1-12i i3 — SD-05 §3.30)
const U66_DAYS := 4                                ## 시장 전지 이야기를 들은 날 + 4 · 10~14시 운반조(재미 검수 W4)
const U66_TAKE_H := 14                             ## 이 시각까지 매듭이 없으면 심도겸이 내준다(GS 세력권)
const U66_DOOR := Vector2i(29, 1)                  ## K-26 병동 북동 철문
const U66_DOCK := Vector2i(31, 3)                  ## K-26 충전대
const U66_FRIDGE_AT := Vector2i(2, 3)              ## K-26B 혈액 냉장고
const U66_SPARE := Vector2i(13, 6)                 ## GS-02 대기등 예비 전원 받침
const U66_FREEZER := Vector2i(8, 1)                ## 수산시장 스팟 안 냉동고 칸
const U66_WARD := [Vector2i(19, 5), Vector2i(25, 5), Vector2i(22, 11), Vector2i(28, 11), Vector2i(17, 12)]   ## 병동 구울 다섯(맵 칸 = 쓰러뜨림 키)


func _nurse_ok() -> bool:
	return v("UQ66_NURSE") == 0 and not st.is_dead("N-R01-058")


func spot_o(lid: String) -> Vector2i:
	if not _spot_o.has(lid):
		_spot_o[lid] = Vector2i(-1, -1)
		var g = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/place_geo.json"))
		for sp in (g.get("_spots", []) if g is Dictionary else []):
			if str(sp.get("lid", "")) == lid:
				_spot_o[lid] = Vector2i(int(sp["at"][0]), int(sp["at"][1]))
	return _spot_o[lid]


## 냉동고 그림(월드 스팟 — 소품 cond는 들어올 때만 읽으므로 지금 그 자리에 있으면 바로 바꾼다)
func _u66_freezer() -> void:
	if v("UQ66_BATT") != 0 or v("UQ66_PULLED") == 1:
		_sv("UQ66_TAG", 0)
	if host.map is WorldMap:
		var o := spot_o("L-R01-25")
		if o.x >= 0:
			host.map.set_prop_state(o + U66_FREEZER, "off" if v("UQ66_PULLED") == 1 else ("tagged" if v("UQ66_TAG") == 1 else ""))


func _u66_refresh() -> void:
	if host.map != null and not host.box.active and not host.ev.busy():
		host.refresh_npcs()


## 병동 구울 다섯을 지금 맵에서 치운다(퇴원 — 7호가 뒤뜰로 모심)
func _u66_clear_ward() -> void:
	if host.map == null or host.map.id != "K-26":
		return
	for e in host.combat.enemies.duplicate():
		if is_instance_valid(e) and str(e.row.get("id", "")) == "CR-200":
			host.combat.enemies.erase(e)
			e.queue_free()


## 운반조가 가져감(기한 날 14시 · 넘긴 날 · 각성회 적대면 기한 날 06:00) — 시장 냉동고 멎음 · 대기등 예비 전원
func _u66_take() -> void:
	_sv("UQ66_BATT", 5)
	_sv("UQ66_PULLED", 1)
	_sv("UQ66_GSCELL", 1)
	_sv("UQ66_PULL_DAY", day())
	_log("UQ-66 운반조가 시장 전지를 가져감")
	_u66_freezer()
	_uq66_check()
	_u66_refresh()


func _uq66_tick() -> void:
	if v("UQ66_NURSE") == 0 and st.is_dead("N-R01-058"):
		_sv("UQ66_NURSE", 3)                                          # 부서짐 — 정류지 없음(충전대는 빈 채)
	var due := v("UQ66_DUE")
	if due > 0 and v("UQ66_BATT") == 0 and v("UQ66_PULLED") == 0:
		if st.is_dead("N-GS-C1") or st.is_dead("N-GS-C2"):
			_sv("UQ66_BATT", 1)                                       # 운반조를 죽임 — 시장 전지는 남는다(살해는 엔진 규칙 · 할인 없음)
			_sv("UQ66_HOW", 4)
			st.call_fn("aff", ["GS", -15])
			_log("UQ-66 운반조 살해 — ①(GS −15)")
			_uq66_check()
		elif v("UQ66_HEARD") > 0 and v("SQH_BATT") == 7:
			_sv("UQ66_BATT", 6)                                       # 관악 전지가 대기등 받침에 — 그 자리에서 행방이 정해진다(운반조를 부르지 않음)
			_uq66_check()
			_u66_refresh()
		elif day() > due or (day() == due and _hour() >= U66_TAKE_H):
			_u66_take()
	if v("UQ66_BATT") == 0 and v("UQ66_PULLED") == 0 and v("UQ66_GSCELL") == 2:
		_sv("UQ66_BATT", 3)                                           # 예비 전지가 받침에 있는데 시장 전지를 뺐다 도로 꽂음 — 시장 몫은 그대로
		_uq66_check()
	if host.map != null and host.map.id == "K-26" and v("UQ66_WARD") == 0 and _ward_cleared():
		_sv("UQ66_WARD", 3)                                           # c) 병동 정리 — 다시 서지 않는다(맵 cond)
		_log("UQ-66 병동 정리")
	var key := "%d:%d:%d:%d:%d" % [v("UQ66_BATT"), v("UQ66_PULLED"), v("UQ66_GSCELL"), 1 if (due > 0 and day() == due and _hour() >= 10 and _hour() < U66_TAKE_H) else 0, 1 if (due > 0 and day() == due - 1 and _hour() >= 8 and _hour() < 18) else 0]
	if key != _u66_key:
		var first := _u66_key == ""
		_u66_key = key
		if not first and host.map is WorldMap:
			_u66_refresh()


func _hour() -> int:
	return int(st.vars.get_v("GAME_HOUR"))


## 병동 구울 다섯이 모두 쓰러진 채(쓰러뜨림 키가 다섯 다 있고, 지금 맵에 산 CR-200이 없다)
func _ward_cleared() -> bool:
	for c in U66_WARD:
		if not st.boxes.has("kill:K-26:%d,%d" % [c.x, c.y]):
			return false
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-200":
			return false
	return true


func _uq66_day(d: int) -> void:
	var due := v("UQ66_DUE")
	if v("UQ66_HEARD") > 0 and v("UQ66_BATT") == 0 and v("UQ66_PULLED") == 0:
		if v("SQH_BATT") == 7:
			_sv("UQ66_BATT", 6)                                       # 관악 전지가 대기등 예비 전원으로(SQ-S04 — 그쪽이 GS를 올림, A111)
			_log("UQ-66 관악 전지로 대신")
		elif d > v("UQ66_HEARD"):
			_sv("UQ66_TAG", 1)                                        # 들은 다음 날부터 붉은 천 꼬리표(운반조가 다녀간 흔적, P7)
	if due > 0 and v("UQ66_BATT") == 0 and v("UQ66_PULLED") == 0 and (d > due or (d == due and v("AFF_GS") <= -60)):
		_u66_take()                                                   # 시간 도약 · 생포 · 적대 판(주인공을 피해 06:00 전에)
	if v("UQ66_NOTICE") == 1 and v("UQ66_DG") == 0 and not st.is_dead("C-067") and Caravans.medic_at(d, v("DG_STOP"), v("FQ_JH03_SOL") == 1) != 0:
		_sv("UQ66_DG", 1)                                             # 7호의 로비 글을 들것 대원이 읽음(들것이 강 이쪽을 도는 날 — 출처 = 붙은 글)
		if v("DG_STOP") == 0 and _nurse_ok():
			_sv("DG_STOP", 2)
		_log("UQ-66 들것 협력 · 정류지 %d" % v("DG_STOP"))
	_uq66_check()


## 행방 판정 · 둘 다 삶(카르마 한 번) · 매듭(100 · 120 XP 한 번) / 90(운반조가 가져감 · 잃음 — 혈액은행이 아직 꺼져 있으면)
func _uq66_check() -> void:
	if st.quests.stage("UQ-66") == 0 and v("UQ66_BATT") == 0 and v("UQ66_FRIDGE") == 0:
		return
	if v("UQ66_PULLED") == 1 and v("UQ66_BATT") == 0 and v("UQ66_GSCELL") != 1 and v("UQ66_FRIDGE") != 3 and _owned("M-442") == 0:
		_sv("UQ66_BATT", 4)                                           # 뺀 시장 전지를 팔거나 버림(보관함 포함 셈 — A244)
		_log("UQ-66 시장 전지를 잃음")
	var b := v("UQ66_BATT")
	if v("UQ66_BOTH") == 0 and v("UQ66_FRIDGE") > 0 and b in [1, 3, 6]:
		_sv("UQ66_BOTH", 1)
		st.call_fn("karma", [25])                                     # 시장 냉동고와 혈액은행 냉장고가 둘 다 돈다(원문 ③ 카르마 +25)
		_log("UQ-66 둘 다 삶")
	var s66: int = st.quests.stage("UQ-66")
	if s66 < 100 and (b in [1, 2, 3, 6, 7] or v("UQ66_FRIDGE") > 0):
		st.quests.set_stage("UQ-66", 100)
		if v("UQ66_XP") == 0:
			_sv("UQ66_XP", 1)
			st.call_fn("xp", [120])
		_log("UQ-66 매듭(BATT %d · FRIDGE %d)" % [b, v("UQ66_FRIDGE")])
	elif s66 < 90 and b in [4, 5]:
		st.quests.set_stage("UQ-66", 90)


# ---------------------------------------------------------------- UQ-65 일타 강사의 문항집(1-12i — SD-05 §3.29)
## 문항집이 어디에도 없으면(팖 · 버림) 류정 갈래가 닫히고 손재석이 '돌고 도는 교재' 한 줄
func _uq65_day(_d: int) -> void:
	if v("UQ65_BOOK") == 1 and v("UQ65_TO") == 0 and _owned("M-439") == 0:
		_sv("UQ65_TO", 3)
		_log("UQ-65 문항집을 잃음(팖 · 버림)")
	var s65: int = st.quests.stage("UQ-65")
	if st.is_dead("N-R01-056") and s65 > 0 and s65 < 100:              # 수업 도중 손재석이 죽음 — 문항집을 몰래 집었어도 수업은 못 끝난다
		st.quests.set_stage("UQ-65", 90)


## 가방 + 주인공 보관함(상점 칸 제외) — 팔거나 버리면 0
func _owned(id: String) -> int:
	var n := st.count_of(id)
	for k in st.boxes:
		if not str(k).begins_with("shop:"):
			n += int(st.boxes[k].get("items", {}).get(id, 0))
	return n


# ---------------------------------------------------------------- UQ-64 귀환 유해 대장(1-12i — SD-05 §3.28)
## 대문에서 건넨 뒤: 봉천 셋 가운데 둘 이상이면 BC +4 · 사당이면 SA +4(한 번씩) · 네 집 다 · 손에 꼬리표가 없으면 매듭
func _uq64_check() -> void:
	var bc_n := v("UQ64_D412") + v("UQ64_D414") + v("UQ64_D416")
	if bc_n + v("UQ64_D413") >= 1 and st.quests.stage("UQ-64") < 20:
		st.quests.set_stage("UQ-64", 20)
	if bc_n >= 2 and v("UQ64_BC") == 0:
		_sv("UQ64_BC", 1)
		st.call_fn("aff", ["BC", 4])
	if v("UQ64_D413") == 1 and v("UQ64_SA") == 0:
		_sv("UQ64_SA", 1)
		st.call_fn("aff", ["SA", 4])
	var given := bc_n + v("UQ64_D413")
	if v("UQ64_TAGS") == 0 or v("UQ64_DONE_DAY") > 0:
		return
	if given >= 4 or (_owned("M-440") == 0 and given + v("UQ64_T415") >= 1):
		_uq64_finish()
	elif _owned("M-440") == 0:     # 하나도 건네지 않고 다 팔거나 버림 — 이름을 잃음(XP 없음)
		_sv("UQ64_LOST", 1)
		_sv("UQ64_XP", 1)
		_uq64_finish()


## 매듭(마지막 대문 또는 받침 볼트) — 100 · 70 XP 한 번. 소식과 근무지는 다음 06:00(교대 자경이 묘지에 — P7)
func _uq64_finish() -> void:
	if v("UQ64_DONE_DAY") > 0:
		return
	_sv("UQ64_DONE_DAY", day())
	if v("UQ64_XP") == 0:
		_sv("UQ64_XP", 1)
		st.call_fn("xp", [70])
	st.quests.set_stage("UQ-64", 100)
	_log("UQ-64 매듭(MEM %d)" % v("UQ64_MEM"))


func _uq64_day(d: int) -> void:
	_uq64_check()
	if v("UQ64_DONE_DAY") > 0 and v("UQ64_NEWS") == 0 and d > v("UQ64_DONE_DAY"):
		_sv("UQ64_NEWS", 1)
		_sv("UQ64_POST", v("UQ64_BC") + 2 * v("UQ64_SA"))
		_log("UQ-64 소식 · 근무지 %d" % v("UQ64_POST"))


# ---------------------------------------------------------------- UQ-62 고시생의 마지막 시험 · 신림 고시촌 블록 X-GC(1-12i i6 — SD-05 §3.16 · 계획 §8)
const GC_SPAWN_R := 45.0                           ## 고시촌 마당(yard)에서 이 안이면 패거리를 세운다
const GC_DESPAWN_R := 70.0
const GC_GATE_R := 6.0                             ## 동쪽 초소 문지기가 외치는 거리(통행 전 · 하루 한 번)
const GC_LAMP := Vector2i(16, 3)                   ## K-43 진공관 스탠드 칸
var _gc: Array = []                                ## 세운 패거리(월드에서만)
var _gc_on := false
var _gc_gate_day := -1
var _kwon: Actor = null                            ## 떠나는 아침의 권성민(연출 — 값은 06:00 판정)
var _kwon_path := PackedVector2Array()
var _kwon_leg := 0


func _gc_passed() -> bool:
	if st.is_dead("N-R01-059"):
		return false                                                  # 부적을 죽인 놈 — 영구 적대(재미 검수 ②)
	return v("GC_OWN") == 1 or v("GC_PASS") == day()


func _gc_safe() -> bool:
	return not host.box.active and not host.ev.busy() and not host.busy and not host.combat.in_combat()


func _lamp_off() -> void:
	if host.map != null and host.map.id == "K-43" and host.map.has_method("set_prop_state"):
		host.map.set_prop_state(GC_LAMP, "off")


func _uq62_day(d: int) -> void:
	if v("UQ62_DONE") > 0 and v("UQ62_GONE") == 0 and d > v("UQ62_DONE") and not st.is_dead("N-R01-059"):
		_sv("UQ62_GONE", d)                                           # 합격증을 받은 다음 06:00 고시촌을 떠난다
		var ham := not st.is_dead("N-R02-009")
		_sv("UQ62_JOB", 1 if (v("UQ62_INTRO") == 1 and ham) else 2)
		_sv("UQ62_JOB_DAY", d)
		if v("UQ62_INTRO") == 1 and ham:
			st.call_fn("aff", ["JH", 3])
		if host.map is WorldMap and host.map.id == "W" and _spot_mark("X-GC:d_door") != Vector2.ZERO and _gc_near("X-GC:yard", GC_DESPAWN_R):
			_kwon_walk()                                              # 그 시각 블록에 있으면 떠나는 걸 본다(재미 검수 P3)
		elif host.map != null and host.map.id in ["K-40", "K-41", "K-42", "K-43", "K-44"]:
			_sv("UQ62_WALK", 2)                                       # 블록 실내(분양 원룸에서 잔 사람)면 그날 처음 나올 때 걷는다
		if host.map != null:
			host.refresh_npcs()
		_log("UQ-62 권성민이 고시촌을 떠남(소개 %d)" % v("UQ62_INTRO"))
	elif v("UQ62_JOB") == 2 and not st.is_dead("N-R02-009") and (d >= v("UQ62_JOB_DAY") + 3 or v("UQ62_INTRO") == 1):
		_sv("UQ62_JOB", 1)                                            # 소개 없이 — 사흘 뒤 함준호가 알아서 들임(JH 없음) · 복도에 있을 때 소개하면 다음 날
		if v("UQ62_INTRO") == 1:
			st.call_fn("aff", ["JH", 3])
		if host.map != null:
			host.refresh_npcs()
	if v("GC_HOT") > 0 and d > v("GC_HOT"):
		_sv("GC_HOT", 0)                                              # 적대는 그날뿐(두목이 죽었으면 패거리가 반이고 문지기가 없다)
	if v("UQ62_PAPER") > 0 and st.is_dead("N-R01-056") and v("UQ62_PGIVEN") == 0:
		_sv("UQ62_PAPER", 0)                                          # 밤에 쓴다던 사람이 죽었다 — 시험지는 없다
		host.hint("밤에 문제를 쓴다던 손재석은 이제 없다 — 시험지도 없다.", 5.0)


func _spot_mark(mark: String) -> Vector2:
	if host.map == null or not host.map.has_method("mark_pos"):
		return Vector2.ZERO
	return host.map.mark_pos(mark)


func _gc_near(mark: String, r: float) -> bool:
	var p := _spot_mark(mark)
	return p != Vector2.ZERO and host.player.loco.logical.distance_to(p) <= r * 32.0


func _gc_rng(tag: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("gc:%s:%d" % [tag, Clock.abs_min(host.date_text) / 60])   # 같은 때 다시 오면 같은 자리 — 때가 바뀌면 다른 수 · 방향(SD-22)
	return r


func _gc_spot(mark: String, r: RandomNumberGenerator, rx := 2, ry := 1) -> Vector2:
	var c0: Vector2i = host.map.tile_of(host.map.mark_pos(mark))
	for _i in 20:
		var c := c0 + Vector2i(r.randi_range(-rx, rx), r.randi_range(-ry, ry))
		if not host.map.is_solid(c):
			return Vector2(c.x * 32 + 16, c.y * 32 + 16)
	return host.map.mark_pos(mark)


## 패거리 세우기(SD-22): 낮엔 창고 앞 · 마당, 밤엔 드럼통 곁 — 두목이 죽은 뒤 7일은 반(내분)
func _gc_spawn() -> void:
	_gc_on = true
	_gc.clear()
	var r := _gc_rng("GC")
	var night := _hour() >= 22 or _hour() < 6
	var n := r.randi_range(8, 11)
	if v("GC_BOSS") == 2 and day() < v("GC_FEUD_DAY") + 7:
		n = n / 2
	var marks := ["X-GC:yard", "X-GC:yard2", "X-GC:front", "X-GC:west", "X-GC:walk1", "X-GC:walk2"] if not night else ["X-GC:yard", "X-GC:yard2", "X-GC:yard", "X-GC:west"]
	var kinds := ["CR-420", "CR-421", "CR-423"]
	for i in n:
		var m: String = marks[i % marks.size()]
		_gc.append(host.combat.spawn(str(kinds[r.randi() % 3]), _gc_spot(m, r, 3, 2), host.map, st,
			{"lv": r.randi_range(4, 8), "dir": ["N", "E", "W", "S"][r.randi() % 4]}))
	for i in 2:
		_gc.append(host.combat.spawn("CR-107", _gc_spot("X-GC:gate_e" if i == 0 else "X-GC:gate_s", r, 2, 2), host.map, st, {"lv": r.randi_range(4, 6)}))
	if _gc_passed() and v("GC_HOT") == 0:
		_gc_calm()
	_log("고시촌 패거리 %d(%s)" % [_gc.size(), "통행" if _gc_passed() else "적대"])


func _gc_calm() -> void:
	for e in _gc:
		if is_instance_valid(e) and not e.cmb.dead:
			e.cmb.team = "calmgc"
			e.foes.clear()


func _gc_hostile() -> void:
	for e in _gc:
		if is_instance_valid(e) and not e.cmb.dead:
			e.cmb.team = "enemygc"
			e.foes = ["player", "ally"]
			e.wake()
			e.brain.gauge = 100.0


func _gc_clear() -> void:
	for e in _gc:
		if is_instance_valid(e) and not e.cmb.dead:
			host.combat.drop_enemy(e)
	_gc.clear()
	_gc_on = false


func _gc_tick() -> void:
	if not (host.map is WorldMap) or _spot_mark("X-GC:yard") == Vector2.ZERO:
		return
	var near := _gc_near("X-GC:yard", GC_SPAWN_R)
	if near and not _gc_on:
		_gc_spawn()
	elif not _gc_near("X-GC:yard", GC_DESPAWN_R) and _gc_on and not host.combat.in_combat():
		_gc_clear()
	if not _gc_on:
		return
	# 동쪽 초소: 통행 전이면 문지기가 6칸 안에서 외친다(하루 한 번 · 낮 06~23 · 적대 아님 · 두목이 살아 있을 때)
	if not _gc_passed() and v("GC_HOT") == 0 and v("GC_BOSS") != 2 and _hour() >= 6 and _hour() < 23 and _gc_gate_day != day() \
			and _gc_safe() and _gc_near("X-GC:gate_e", GC_GATE_R) and not st.is_dead("N-GC-G1"):
		_gc_gate_day = day()
		host.play_scene("GC_GATE")


func _on_provoked(team: String) -> void:
	if team == "calmgc":
		_sv("GC_HOT", day())                                          # 통행 중에 쳤다 — 그날 적대
		_sv("GC_SHOT", day())                                         # 다음 날 문지기 '상담료 두 배'
		_gc_hostile()
		host.hint("패거리: '손님이 총을 들었다!' 상담은 끝났다.", 4.0)


func _on_resident_down(id: String, killed: bool) -> void:
	if id == "N-R01-060" and killed and v("GC_BOSS") != 2:
		_sv("GC_BOSS", 2)                                             # 삽자루 처치 — 거점 공백 · 7일 내분(SQ-S02 C 처치)
		_sv("GC_FEUD_DAY", day())
		if host.ev.handlers.has("s02"):
			host.ev.handlers["s02"].call(["boss", "2"], func() -> void: pass)
		_log("삽자루 처치 — 내분")
	elif id == "N-R01-059" and killed:
		if st.quests.stage("UQ-62") > 0 and st.quests.stage("UQ-62") < 100:
			st.quests.set_stage("UQ-62", 90)                          # 부적을 죽였다 — 패거리 적대 · 소멸
		_sv("GC_HOT", day())
		_gc_hostile()


## 떠나는 아침: D동 문 → 동쪽 초소 → 길 밖(배우 — 값은 바뀌지 않는다 · 보는 것만)
func _kwon_walk() -> void:
	_kwon_clear()
	_kwon = Actor.new()
	_kwon.setup("st_look_m1_sg1_hr04_h1_t03_2_pf00_hd00_ey03_pr021", _spot_mark("X-GC:d_door"), host.map)
	_kwon.mode = "walk"
	host.map.add_actor(_kwon)
	_kwon._show()
	_kwon_leg = 0
	_kwon_path = NpcRoutine.with_start(host.map, _kwon.loco.logical, _spot_mark("X-GC:gate_e"))
	_sv("UQ62_WALK", 1)
	host.hint("패거리: '…부적이 나간다.' 드럼통 앞이 조용하다.", 5.0)


func _kwon_frame(dt: float) -> void:
	if _kwon == null or dt <= 0.0:
		return
	if not is_instance_valid(_kwon) or not (host.map is WorldMap):
		_kwon = null
		return
	if _kwon_path.is_empty():
		_kwon_leg += 1
		if _kwon_leg >= 2:
			_kwon_clear()
			return
		_kwon_path = NpcRoutine.with_start(host.map, _kwon.loco.logical, _spot_mark("X-GC:walk2"))
		if _kwon_path.is_empty():
			_kwon_clear()
			return
	_kwon_path = NpcRoutine.walk_path(_kwon, _kwon_path, dt)


func _kwon_clear() -> void:
	if _kwon != null and is_instance_valid(_kwon):
		if host.map is WorldMap:
			host.map.remove_actor(_kwon)
		_kwon.queue_free()
	_kwon = null
	_kwon_path = PackedVector2Array()
