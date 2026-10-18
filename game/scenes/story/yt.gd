## 여의도 유리탑 3동 DG-YT · 증권가 객장 UQ-06 「마지막 시세」(단계 1-D9, 1-D 계획 §15.7 · SD-09a L-R02-08 · L-R02-07 · SD-05 §3.4)
## · 남의 이름으로 문을 연다: 사원증 넷(남기범 · 도미란 · 오정택 · 하보람) — 판독기는 그 이름으로 인사하고 마지막 기록을 안다.
##   23:21 집행 모드(SD-02 L167) 뒤 발급분은 무효 — 인사 단말 위조는 발급 시각 22:41~23:20(대장 마지막 줄 22:40 · 로그 23:21)만 진짜, 밖이면 임시 출입증(로봇 동행).
## · 18층 경비 로봇(비적대 · 집행 수칙: 대조 · 격리)은 카드 주인의 '마지막 기록'과 대조한다(알리바이) — 도미란은 이미 이 층 의자에 · 오정택은 퇴근했다 ·
##   하보람은 2동 7층 퇴실 기록이 없다 · 남기범은 밤마다 1층 승강기 홀 판독에 찍힌다(올라온 길의 판독 YT_UP이 그 카드가 아니면 '두 곳에').
##   로봇을 부수면 전 층 판독 봉쇄(YT_LOCK — 카드 무용 · 날개 · 셔터 닫힘 · 직결 · 자물쇠 · 환풍구만) · 대조 실패는 보안 사고(YT_INC — 격리, 안팎 모두).
## · 서기 남기범: 비상 전지를 올리면(또는 밤 반사 중 전지가 살아 있으면) 제 카드로 승강기를 타고 18층 도미란 곁으로 간다(YT_CUP) — 카드를 뺏겼으면 게이트에 부딪는다.
## · 도미란 카드로 '사망 확정'을 부르면 로봇이 기계실 틈 셔터를 내려 일개미를 가둔다(YT_TRAP — 엉뚱한 짓의 값).
## · 테이프(M-404)는 한 번 틀면 지워진다: ① 객장 전광판(마감 종 · 거리 시세판 · 경상현 떠남) ② 우도하(다음 06:00 남산 방송) ③ 가짜 마감([과학 40]).
## 사실은 변수 한 곳(P1) — 뜻은 script/act1/YT.txt 머리 주석.
class_name Yt
extends Node

const QID := "UQ-06"
const LOBBY := "YT-01"
const OFFICE := "YT-02"
const TOP := "YT-03"
const FLOOR := "SG-01"
const CLERK := "N-YTB-1"
const KYUNG := "N-R02-032"
const TAPE := "M-404"
const BLANK := "M-405"
const XP := 100
const WOO_CAPS := 80
const WOO_XP := 50
const ISSUED_LAST := 1360                           ## 발급 대장 마지막 줄 22:40(분)
const FILTER := 1401                                ## 23:21 집행 모드 — 이 분부터 발급분 무효
## 카드: 번호 → [아이템, 판독기 인사 이름, 기본 등급(2 파랑 · 3 빨강)]
const CARDS := {1: ["M-401", "남기범 서기님", 3], 2: ["M-402", "도미란 대리님", 3], 3: ["M-403", "오정택 과장님", 2], 4: ["M-072", "하보람 님", 2]}
const GATE1 := Vector2i(4, 11)
const GATE3 := Vector2i(30, 11)
const GATE2 := Vector2i(6, 29)
const SHUT_SG := Vector2i(34, 29)
const SHUT_18 := Vector2i(6, 12)
const STAIR_DOOR := Vector2i(36, 1)
const SOFA := Vector2i(21, 16)
const ELEV_1 := Vector2i(27, 4)
const TRAP_18 := Vector2i(15, 16)                    ## 18층 계단참 ↔ 기계실 틈(세로 2칸) — 격리 셔터
const CLERK_18 := Vector2i(7, 4)                     ## 18층 도미란 의자 곁(서기가 승강기로 올라가 앉는 자리)
const SG_FRONT := Vector2i(34, 28)                   ## 증권가 연결 셔터 앞(상가 쪽) — 테이프를 쥔 서기가 가는 곳
const CLERK_SG := Vector2i(17, 4)                    ## 객장 전광판 곁 의자(테이프를 배달한 서기가 앉아 조는 자리)
const NIGHT_A := 1360                               ## 22:40 — 서기의 밤 반사(게이트 → 승강기 문 긁기)
const NIGHT_B := 1401                               ## 23:21

var host: InteriorHost
var st: StoryState
var log_on := false
var _tick := 0.0
var _clerk_mode := -1                               ## 0 졸음 · 1 밤 반사 · 2 전지 소리에 승강기로 · 3 소파로 · 4 빈 목으로 게이트로
var _via_vent := false                              ## 이번 18층 진입이 환풍구(판독 없음)
var _hellos := {}                                   ## 카드별 인사 횟수(같은 인사가 닳지 않게 — 저장 안 함)

signal want_save(why: String)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["yt"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.combat.enemy_down.connect(_on_down)


func v(k: String) -> int:
	return int(st.vars.get_v("YT_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("YT_" + k, n)


func q(k: String) -> int:
	return int(st.vars.get_v("UQ06_" + k))


func _sq(k: String, n: int) -> void:
	st.vars.set_v("UQ06_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[유리탑] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func _minute() -> int:
	return TimeOfDay.minute(host.date_text)


# ---------------------------------------------------------------- 카드
## 그 카드의 지금 등급: 0 무효(사망 확정) · 2 파랑 · 3 빨강 · 4 임시 출입증(빨강이지만 집행 뒤 발급 — 동행)
func grade(n: int) -> int:
	if not CARDS.has(n):
		return 0
	if n == 2 and v("DEAD_DM") == 1:
		return 0
	if v("FORGE") == n:
		return 4 if v("TEMP") == 1 else 3
	return int(CARDS[n][2])


## 발급 시각(분)이 진짜인가: 대장 마지막 줄 뒤 · 집행 모드 앞
static func issue_ok(t: int) -> bool:
	return t > ISSUED_LAST and t < FILTER


func _hello(n: int, tail := "", door := "") -> void:
	var k := int(_hellos.get(n, 0)) + 1
	_hellos[n] = k
	var say := "어서 오십시오, %s." % CARDS[n][1]
	match door:
		"el":
			say = "%s, 승강기 호출 확인. 18층 송출실 방면." % CARDS[n][1]
		"st":
			say = "%s, 계단 이용 기록을 남깁니다." % CARDS[n][1]
		"sg":
			say = "%s, 객장 방면 연결 통로. 전달물 확인 바랍니다." % CARDS[n][1]
	if k >= 4:
		say = ["…%s." % CARDS[n][1], "%s. 오늘 %d번째 판독입니다." % [CARDS[n][1], k], "삐 — %s. 판독 간격이 짧습니다." % CARDS[n][1]][k % 3]
	host.hint("삑 — '%s'%s" % [say, tail], 3.0)


# ---------------------------------------------------------------- 게이트 · 셔터 · 문
func _open_prop(c: Vector2i, w := 2) -> void:
	if host.map == null:
		return
	host.map.set_prop_state(c, "open")
	for i in w:
		host.map._put_solid(c.x + i, c.y, 0)


func _close_prop(c: Vector2i, state: String, w := 2) -> void:
	if host.map == null:
		return
	host.map.set_prop_state(c, state)
	for i in w:
		host.map._put_solid(c.x + i, c.y, 1)


func _open_gate(c: Vector2i) -> void:
	_open_prop(c)


func _open_shutter(c: Vector2i) -> void:
	host.map.set_prop_state(c, "up")
	for i in 2:
		host.map._put_solid(c.x + i, c.y, 0)


func _shut(c: Vector2i) -> void:
	_close_prop(c, "")


## 판독: 문 g1 · g2 · g3 · st(비상 계단) · el(승강기) · sg(증권가 통로) · 18(18층 판독 홀). 결과 YT_R
func read(door: String, n: int) -> void:
	_sv("R", 0)
	if n == 9:
		_open_shutter(SHUT_18)
		return
	if v("LOCK") == 1:                                                 # 봉쇄: 판독기는 전부 빨간 엑스(카드 무용)
		_sv("R", 0)
		return
	var g := grade(n)
	if g == 0:
		_sv("R", 7)
		return
	match door:
		"g2":
			if g >= 2:
				_sv("R", 1)
				_hello(n)
				_open_gate(GATE2)
		"g3":
			if g >= 3:
				_sv("R", 1)
				_hello(n, "  날개가 접힌다." if g == 3 else "  '임시 출입증 — 18층에서 동행이 필요합니다.'")
				_open_gate(GATE3)
		"st":
			if g >= 3:
				_sv("R", 1)
				_hello(n, "  철문 잠금쇠가 풀린다.", "st")
				host.map.unlock_door(STAIR_DOOR.x, STAIR_DOOR.y)
				_sv("UPC", n)                                              # 올라가는 길의 판독(18층 대조에 쓴다)
		"el":
			if g >= 3 and v("POWER") == 1 and v("LOCK") == 0:
				_sv("R", 1)
				_hello(n, "", "el")
				_sv("UPC", n)
		"sg":
			if g >= 3:
				_sv("R", 1)
				_sv("SG", 1)
				_hello(n, "  셔터가 덜컹 오른다.", "sg")
				_open_shutter(SHUT_SG)
		"18":
			_read18(n, g)
	_log("판독 %s 카드 %d → %d" % [door, n, v("R")])


## 18층 판독 홀 — 경비 로봇의 대조(집행 수칙 1 · 2)
func _read18(n: int, g: int) -> void:
	if g == 4:
		_sv("R", 3)
		_sv("ESCORT", 1)
		_sv("ROBOT_OK", 1)
		_open_shutter(SHUT_18)
		return
	match n:
		1:                                                             # 22:40 진짜 임시 카드 — 그날 밤의 심부름꾼. 올라온 길이 그 카드여야 한다
			if v("CUP") == 1:
				_sv("R", 9)                                            # 서기가 이미 이 층 도미란 곁에 — '두 곳에'
			elif v("UP") != 1:
				_sv("R", 9)                                            # 기록상 그는 1층 승강기 홀(밤마다 찍힌다) — 탑승 · 계단 기록 없이 이 층에
			else:
				_sv("R", 1)
				_sv("ROBOT_OK", 1)
				_open_shutter(SHUT_18)
				host.hint("스피커: '남기범 서기님 — 송출실 심부름 확인. …도미란 대리님이 기다리셨습니다.'", 5.0)
		2:
			_sv("R", 5)                                                # 주인이 이미 이 층 의자에 — 질문
		3:
			_sv("R", 6 if g == 3 else 0)                               # 퇴근한 사람 — 잔업 사유
		4:                                                             # 2동 7층 퇴실 기록이 없다 — 승강기 판독이 있으면 '사유?', 없으면 '어떻게 올라왔나'
			if g == 3:
				_sv("R", 10 if v("UP") == 4 else 8)


## 인사 단말: 카드 n의 등급을 3동으로 덧쓴다. t = 입력한 발급 시각(분, 0 = 지금)
func forge(n: int, t: int) -> void:
	if v("FORGE") != 0 or not (n == 3 or n == 4):
		return
	_sv("FORGE", n)
	_sv("FORGE_T", t)
	_sv("TEMP", 0 if issue_ok(t) else 1)
	_log("위조 카드 %d 시각 %d → %s" % [n, t, "진짜" if v("TEMP") == 0 else "임시"])


# ---------------------------------------------------------------- 로봇
func robot(what: String) -> void:
	match what:
		"ok":
			_sv("ROBOT_OK", 1)
			if _mid() == TOP:
				_open_shutter(SHUT_18)
		"no":                                                         # 대조 불일치 — 둘째부터 보안 사고(격리)
			_sv("NO", v("NO") + 1)
			if v("NO") >= 2:
				robot("inc")
		"dead":                                                       # 엉뚱한 짓: 도미란 사망 확정 — 그 카드는 어디서도 안 열린다 · '미확인 생물 격리'
			_sv("DEAD_DM", 1)
			_sv("INC_DAY", day())
			_sv("TRAP", 1)
			if _mid() == TOP:
				_trap()
			_log("도미란 사망 처리 — 기계실 격리")
		"inc":
			_sv("INC", 1)
			_sv("INC_DAY", day())
			_sv("ROBOT_OK", 0)                                         # 격리는 안팎 모두 — 바깥 판독기도 보류
			if _mid() == TOP:
				_shut(SHUT_18)


## 로봇을 부순다: 전 층 판독 봉쇄 — 판독기 빨간 엑스 · 승강기 정지 · 날개 · 셔터는 닫힌 채(직결 · 자물쇠 · 환풍구 · 안쪽 단추만)
func smash() -> void:
	var first := v("LOCK") == 0
	_sv("LOCK", 1)
	_sv("ESCORT", 0)
	if _mid() == TOP and first:
		host.map.add_runtime_prop("metro_robot_down", Vector2i(11, 4))
		for p in host.map.props.duplicate():
			if p["name"] == "metro_robot_stand" and p.has("node"):
				p["node"].visible = false
	_log("경비 로봇 부숨 — 전 층 봉쇄")


## 18층 기계실 틈에 격리 셔터를 내린다(이미 있으면 그대로)
func _trap() -> void:
	if host.map == null:
		return
	for p in host.map.props:
		if p["name"] == "shutter_yt_v":
			return
	host.map.add_runtime_prop("shutter_yt_v", TRAP_18)


# ---------------------------------------------------------------- 서기 남기범(야생 구울 · 22:40 진짜 빨강 카드)
func _clerk():
	for e in host.combat.enemies:
		if is_instance_valid(e) and str(e.who) == CLERK and not e.cmb.dead:
			return e
	return null


## 낮엔 로비 소파에서 졸고(카드를 풀 수 있다) · 22:40~23:21엔 3동 게이트 너머 승강기 문 앞으로 가 긁는다 · 끝나면 걸어서 소파로(순간이동 없음)
## _clerk_mode: 0 졸음 · 1 밤 반사 · 2 전지 소리에 승강기로 · 3 소파로 돌아가는 중 · 4 카드 없이 깨어 게이트로(닿으면 부딪고 3)
func _clerk_step(placed: bool) -> void:
	var e = _clerk()
	if e == null:
		_sv("DOZE", 0)
		return
	if e.brain.state == AIBrain.S.COMBAT:
		_sv("DOZE", 0)
		return
	if _mid() == LOBBY and (_clerk_mode == 1 or _clerk_mode == 2) and _clerk_ride(e):
		return
	var sofa := Vector2(SOFA) * 32.0 + Vector2(16, 16)
	if _clerk_mode == 4:
		if e.loco.logical.distance_to(Vector2(GATE3.x, GATE3.y + 1) * 32.0 + Vector2(16, 16)) <= 24.0:
			if _mid() == LOBBY:
				host.hint("로비 3동 게이트 '삐 — 판독 실패.' 빈 목을 더듬던 구울이 유리 날개에 몸을 부딪고는 돌아선다.", 4.0)
			_clerk_mode = 3
			e.route = [[sofa, 9999.0]]
			e._route_i = 0
		return
	var m := _minute()
	var want := 1 if (m >= NIGHT_A and m < NIGHT_B) else 0
	if _clerk_mode == 2 and v("NOCARD") == 0 and v("POWER") == 1:
		want = 2                                                       # 승강기 앞에 닿을 때까지
	if _clerk_mode == 3 and want == 0:
		if e.loco.logical.distance_to(sofa) <= 20.0:
			_doze(e)
		return
	if want == _clerk_mode:
		return
	if want == 0:
		if placed or e.loco.logical.distance_to(sofa) <= 40.0:
			e.loco.place(sofa)
			_doze(e)
		else:
			_clerk_mode = 3
			e.route = [[sofa, 9999.0]]
			e._route_i = 0
		return
	_clerk_mode = want
	e.doze = ""
	e.asleep = false
	e.det_mul = 0.6
	e.set_pose("stand")
	_sv("DOZE", 0)
	if v("CTAPE") == 1:                                                # 무릎에 테이프 — 심부름의 끝(객장 방면 연결 통로 셔터)으로
		var sg := Vector2(SG_FRONT) * 32.0 + Vector2(16, 16)
		e.route = [[sg, 9999.0]]
		e._route_i = 0
		if placed:
			e.loco.place(sg)
		elif _mid() == LOBBY:
			host.hint("소파의 구울이 테이프를 안고 일어선다. 승강기가 아니라 — 에스컬레이터 아래, 증권가 통로 쪽으로.", 4.0)
		return
	if placed and want == 1:
		e.loco.place(Vector2(ELEV_1) * 32.0 + Vector2(16, 48))                  # 밤에 들어오면 이미 승강기 앞에 와 있다
	if v("NOCARD") == 1 or v("LOCK") == 1:                             # 카드를 뺏겼다(또는 봉쇄) — 날개 앞에서 부딪는다
		e.route = [[Vector2(GATE3.x, GATE3.y + 1) * 32.0 + Vector2(16, 16), 9999.0]]
		e._route_i = 0
		if placed:
			e.loco.place(Vector2(GATE3.x, GATE3.y + 1) * 32.0 + Vector2(16, 16))
		elif _mid() == LOBBY:
			host.hint("로비 3동 게이트 '삐 — 판독 실패.' 빈 목을 더듬던 구울이 유리 날개에 몸을 부딪는다.", 4.0)
		return
	_open_gate(GATE3)                                                  # 그의 카드는 진짜다 — 게이트가 혼자 삑
	if _mid() == LOBBY and not placed:
		host.hint("로비 3동 게이트가 혼자 '삑' — '어서 오십시오, 남기범 서기님.'", 3.5)
	e.route = [[Vector2(ELEV_1) * 32.0 + Vector2(16, 16), 9999.0]]
	e._route_i = 0


func _doze(e) -> void:
	_clerk_mode = 0
	e.route = []
	e.doze = "sit"
	e.asleep = true
	e.det_mul = 0.3
	e.set_pose("sit")
	_sv("DOZE", 1)


## 승강기 앞에 닿은 서기: 전지가 살아 있고 카드가 목에 있으면 그 카드로 18층 — 도미란 곁으로(맵 전환 = 인물은 한 곳 P3)
func _clerk_ride(e) -> bool:
	if v("CTAPE") == 1:
		return _clerk_deliver(e)
	if v("POWER") == 0 or v("LOCK") == 1 or v("NOCARD") == 1 or v("CUP") == 1:
		return false
	if e.loco.logical.distance_to(Vector2(ELEV_1) * 32.0 + Vector2(16, 16)) > 24.0:
		return false
	_sv("CUP", 1)
	_sv("DOZE", 0)
	e.visible = false
	e.cmb.dead = true                                                  # 이 맵에서는 빠진다(죽음 기록 아님 — st.kill 안 함)
	host.combat.enemies.erase(e)
	e.queue_free()
	host.hint("승강기 판독 '삑 — 남기범 서기님, 18층입니다.' 문이 닫힌다. 표시등 숫자가 하나씩 올라간다.", 5.0)
	_log("서기 — 승강기로 18층")
	return true


## 테이프를 쥔 서기가 연결 통로 셔터 앞에 닿음: 제 카드로 셔터를 열고 통로로 — 200년 만의 배달(카드가 없거나 봉쇄면 부딪고 돌아선다)
func _clerk_deliver(e) -> bool:
	if v("CDONE") == 1:
		return false
	if e.loco.logical.distance_to(Vector2(SG_FRONT) * 32.0 + Vector2(16, 16)) > 24.0:
		return false
	if v("NOCARD") == 1 or v("LOCK") == 1:
		if v("BUMP_DAY") != day():
			_sv("BUMP_DAY", day())
			host.hint("통로 셔터 판독기 '삐 — 판독 실패.' 테이프를 안은 구울이 셔터에 이마를 대고 한참 서 있다.", 4.5)
		return false
	_sv("CDONE", 1)
	_sv("CTAPE", 0)
	_sv("SG", 1)
	_open_shutter(SHUT_SG)
	e.visible = false
	e.cmb.dead = true
	host.combat.enemies.erase(e)
	e.queue_free()
	host.hint("삑 — '남기범 서기님, 객장 방면 연결 통로. 전달물 확인 바랍니다.' 셔터가 오르고, 구울이 테이프를 안은 채 통로 계단을 내려간다.", 6.0)
	_deliver()
	_log("서기 — 테이프를 안고 객장으로(배달)")
	return true


## 마감 테이프가 객장 전광판에 들어감(주인공이 넣든 · 서기가 배달하든 — 결과 한 곳 UQ06_RESULT 1)
func _deliver() -> void:
	var first := q("RESULT") != 1
	_sq("RESULT", 1)
	_sq("DAY", day())
	_sq("BACK", 0)
	if first:
		st.call_fn("karma", [25])
	if _mid() == FLOOR:
		host.map.set_prop_state(Vector2i(14, 1), "close")
	_quest()
	want_save.emit("uq06")


func steal() -> void:
	if v("NOCARD") == 1:
		return
	st.call_fn("give", ["M-401", 1])
	_sv("CLERK_SEEN", 1)
	_sv("NOCARD", 1)                                                   # 그의 목은 비었다(되팔거나 버려도 돌아가지 않는다)


func wake_clerk() -> void:
	var e = _clerk()
	if e == null:
		return
	e.doze = ""
	e.asleep = false
	e.set_pose("stand")
	e.brain.gauge = AIBrain.DETECT_AT
	e.brain.last_seen = host.player.loco.logical
	_sv("DOZE", 0)


func _on_down(e: Enemy) -> void:
	if str(e.who) != CLERK:
		return
	st.kill(CLERK)
	if v("NOCARD") == 1:
		return
	_sv("NOCARD", 1)
	var c: Vector2i = host.map.tile_of(e.loco.logical)
	if not host.map.boxes.has(c):
		host.map.boxes[c] = {"x": c.x, "y": c.y, "w": 1, "h": 1, "kind": "_corpse", "eid": "CR-200", "name": "남기범의 유해", "owner": "", "lock": 0,
			"cond": "", "key": "corpse:%s:%d,%d@%d:yt" % [host.map.id, c.x, c.y, day()]}
	var b: Dictionary = host.map.boxes[c]
	b["name"] = "남기범의 유해"
	var bc := host.box_contents(b)
	bc["items"]["M-401"] = 1                                          # 목에 걸린 빨강 사원증
	_log("서기 쓰러짐 — 카드는 유해에")


# ---------------------------------------------------------------- 테이프 · 전광판 · 우도하
func tape() -> void:
	if v("TAPE") == 1:
		return
	_sv("TAPE", 1)
	st.call_fn("give", [TAPE, 1])
	_quest()


func board() -> void:
	if not st.items.has(TAPE):
		return
	st.call_fn("take", [TAPE, 1])
	st.call_fn("give", [BLANK, 1])
	_deliver()


func fake() -> void:
	if q("RESULT") != 0:
		return
	_sq("RESULT", 3)
	_sq("DAY", day())
	_quest()


## 전지 손잡이 — 모터 소리에 졸던 서기가 일어나 승강기로 간다(공격이 아니다 — 눈에 띄면 그때 덤빈다)
func power() -> void:
	_sv("POWER", 1)
	var e = _clerk()
	if e == null or e.brain.state == AIBrain.S.COMBAT:
		return
	if v("NOCARD") == 1:
		_clerk_wake_nocard(e)                                          # 카드 없이 깨어 게이트 앞으로 — 닿으면 부딪고 돌아선다
		return
	_clerk_mode = 0
	_clerk_mode_force(e)


func _clerk_wake_nocard(e) -> void:
	e.doze = ""
	e.asleep = false
	e.det_mul = 0.6
	e.set_pose("stand")
	_sv("DOZE", 0)
	_clerk_mode = 4
	e.route = [[Vector2(GATE3.x, GATE3.y + 1) * 32.0 + Vector2(16, 16), 9999.0]]
	e._route_i = 0


func _clerk_mode_force(e) -> void:
	e.doze = ""
	e.asleep = false
	e.det_mul = 0.6
	e.set_pose("stand")
	_sv("DOZE", 0)
	_clerk_mode = 2
	_open_gate(GATE3)
	host.hint("로비 3동 게이트가 혼자 '삑' — '어서 오십시오, 남기범 서기님.'", 3.5)
	e.route = [[Vector2(ELEV_1) * 32.0 + Vector2(16, 16), 9999.0]]
	e._route_i = 0


func woo() -> void:
	if not st.items.has(TAPE) or q("RESULT") != 0:
		return
	st.call_fn("take", [TAPE, 1])                                       # 우도하가 남산으로 — 송출하면 지워진다(그 테이프는 거기서 끝)
	st.call_fn("caps", [WOO_CAPS])
	st.call_fn("xp", [WOO_XP])
	_sq("RESULT", 2)
	_sq("RADIO", 1)
	_sq("DAY", day())
	_quest()


# ---------------------------------------------------------------- 하루 판정
func _on_day(d: int) -> void:
	if q("RADIO") == 1 and d > q("DAY"):
		_sq("RADIO", 2)                                                # 다음 06:00 남산 방송(radio.txt N-YT-R)
	if q("RESULT") == 1 and q("GONE") == 0 and d > q("DAY") and not st.is_dead(KYUNG):
		_sq("GONE", 1)                                                 # 마감 종 다음 날 지하시장 관리사무소로(장부 정리)
		_log("경상현 — 지하시장으로")
	if q("RESULT") == 3:
		if q("GONE") == 0 and q("BACK") == 0 and d > q("DAY"):
			_sq("GONE", 1)
		elif q("GONE") == 1 and d >= q("DAY") + 7:
			_sq("GONE", 0)
			_sq("BACK", 1)                                             # '숫자가 너무 예뻤어요' — 객장으로 돌아옴
			_log("경상현 — 가짜 마감을 알아채고 돌아옴")
	_quest()


func _quest() -> void:
	var cur := st.quests.stage(QID)
	if cur >= 100:
		return
	var s := 0
	if q("MET") == 1:
		s = 10
	if q("HEARD") == 1 or v("TAPE") == 1:
		s = 20
	if q("RESULT") > 0:
		s = 100
	if s > cur:
		st.quests.set_stage(QID, s)
		if s == 100:
			st.call_fn("xp", [XP])
			st.call_fn("result", [QID, q("RESULT")])
			_log("UQ-06 끝 — 결과 %d" % q("RESULT"))


# ---------------------------------------------------------------- 맵 · 시간
func _on_map(id: String) -> void:
	_clerk_mode = -1
	match id:
		LOBBY:
			if v("SG") == 1:
				_open_shutter(SHUT_SG)
			if v("HK2") == 1:
				_open_gate(GATE2)                                          # 직결한 날개는 접힌 채
			if v("HK3") == 1:
				_open_gate(GATE3)
			if v("SEEN") == 0:
				_sv("SEEN", 1)
				host.hint("김밥집 쪽 낮은 목소리: '쉿 — 소파 그 양반 깨우지 마. 밤 열 시 사십 분이면 일어나 3동 문을 연다고.'", 6.0)
			var me: Vector2i = host.map.tile_of(host.player.loco.logical)
			if me.y < 11 and me.x > 22:                                 # 계단 · 승강기로 내려왔다: 출구 센서가 3동 게이트를 연다(봉쇄 중엔 비상 개방 — 접힌 채 굳음)
				_open_gate(GATE3)
				if v("LOCK") == 1:
					_sv("HK3", 1)
			_clerk_step(true)
		TOP:
			_sv("UP", 0 if _via_vent else v("UPC"))                         # 올라온 길의 판독 기록(환풍구 · 딴 자물쇠면 0)
			_sv("UPC", 0)
			_via_vent = false
			if v("ROBOT_OK") == 1 and v("INC") == 0 and v("LOCK") == 0:
				_open_shutter(SHUT_18)
			if v("LOCK") == 1:
				smash()
			if v("TRAP") == 1:
				_trap()
			if v("CUP") == 1 and not st.is_dead(CLERK):
				var ce = _clerk()
				if ce != null:
					ce.loco.place(Vector2(CLERK_18) * 32.0 + Vector2(16, 16))
					ce.route = []
					ce.doze = "sit"
					ce.asleep = true
					ce.det_mul = 0.3
					ce.set_pose("sit")
				if v("CUPSEEN") == 0:
					_sv("CUPSEEN", 1)
					if v("LOCK") == 0:
						host.hint("스피커: '남기범 서기님 도착 확인. …도미란 대리님이 기다리셨습니다.' 의자 곁에 정장 구울이 앉아 존다.", 6.0)
		FLOOR:
			if q("RESULT") == 1:
				host.map.set_prop_state(Vector2i(14, 1), "close")
			if v("CDONE") == 1 and not st.is_dead(CLERK):
				var fe = _clerk()
				if fe != null:
					fe.loco.place(Vector2(CLERK_SG) * 32.0 + Vector2(16, 16))
					fe.route = []
					fe.doze = "sit"
					fe.asleep = true
					fe.det_mul = 0.3
					fe.set_pose("sit")


func _process(dt: float) -> void:
	if _mid() != LOBBY:
		return
	_tick += dt
	if _tick < 1.0:
		return
	_tick = 0.0
	_clerk_step(false)


# ---------------------------------------------------------------- 명령(@cmd yt …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"read":
			read(str(a[1]), int(a[2]))
		"hack":
			_sv("UNK", v("UNK") + 1)
			match str(a[1]):
				"g2":
					_sv("HK2", 1)
					_open_gate(GATE2)
				"g3":
					_sv("HK3", 1)
					_open_gate(GATE3)
		"pick18":
			_sv("UNK", v("UNK") + 1)
			_open_shutter(SHUT_18)
			if v("LOCK") == 0:
				host.play_scene.call_deferred("YT_ROBOT_IN")
		"sgpick":                                                      # 객장 쪽 셔터 뒷면 비상 걸쇠 — 판독 없이 통로가 열린다
			_sv("UNK", v("UNK") + 1)
			_sv("SG", 1)
			_open_shutter(SHUT_SG)
		"side":                                                        # 셔터 앞(상가 쪽)이면 판독기 장면으로, 뒷면(통로 쪽)이면 이 장면 그대로
			var me: Vector2i = host.map.tile_of(host.player.loco.logical)
			_sv("SIDE", 1 if me.y > SHUT_SG.y else 0)
			if me.y <= SHUT_SG.y:
				host.play_scene.call_deferred("YT_SHUT")
		"trap":
			_sv("TRAP", 1)
			_trap()
		"untrap":                                                      # 격리 셔터를 손으로 해제(자물쇠 · 과학) — 기계실이 다시 열린다
			_sv("TRAP", 2)
			for p in host.map.props.duplicate():
				if p["name"] == "shutter_yt_v":
					host.map.remove_runtime_prop(p)
		"ctape":                                                       # 졸고 있는 서기의 무릎에 테이프를 올려 둔다(물건은 한 곳 — 이제 서기에게)
			if st.items.has(TAPE):
				st.call_fn("take", [TAPE, 1])
				_sv("CTAPE", 1)
				_clerk_mode = -1
		"ctape_back":
			if v("CTAPE") == 1:
				st.call_fn("give", [TAPE, 1])
				_sv("CTAPE", 0)
				_clerk_mode = -1
		"forge":
			forge(int(a[1]), int(a[2]))
		"robot":
			robot(str(a[1]))
		"smash":
			smash()
		"open18":
			_open_shutter(SHUT_18)
		"power":
			power()
		"elev":
			if str(a[1]) == "up":
				host.enter.call_deferred(TOP, "from_elev")
			else:
				host.enter.call_deferred(LOBBY, "from_elev")
		"vent":
			if str(a[1]) == "up":
				_via_vent = true
				host.enter.call_deferred(TOP, "from_vent")
			else:
				host.enter.call_deferred(OFFICE, "from_vent")
		"steal":
			steal()
		"steal18":                                                     # 18층 도미란 곁에서 조는 서기의 목걸이
			steal()
		"wake":
			wake_clerk()
		"tape":
			tape()
		"mound":
			_sv("MOUND", 1)
		"board":
			board()
		"fake":
			fake()
		"woo":
			woo()
		"met":
			_sq("MET", 1)
			_quest()
		"heard":
			_sq("HEARD", 1)
			_quest()
		"gate1":
			_sv("GATE1", v("GATE1") + 1)
		"log":
			pass
	done.call()
