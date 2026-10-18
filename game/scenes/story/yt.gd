## 여의도 유리탑 3동 DG-YT · 증권가 객장 UQ-06 「마지막 시세」(단계 1-D9, 1-D 계획 §15.7 · SD-09a L-R02-08 · L-R02-07 · SD-05 §3.4)
## · 남의 이름으로 문을 연다: 사원증 넷(남기범 · 도미란 · 오정택 · 하보람) — 판독기는 그 이름으로 인사하고 마지막 기록을 안다.
##   23:21 집행 모드(SD-02 L167) 뒤 발급분은 무효 — 인사 단말 위조는 발급 시각 22:41~23:20(대장 마지막 줄 22:40 · 로그 23:21)만 진짜, 밖이면 임시 출입증(로봇 동행).
## · 18층 경비 로봇(비적대 · 집행 수칙: 대조 · 격리)은 카드 주인과 대조한다 — 도미란은 이미 이 층 의자에 · 오정택은 퇴근했다 · 남기범은 심부름 중.
##   로봇을 부수면 전 층 판독 봉쇄(YT_LOCK) · 대조 실패는 보안 사고(YT_INC — 18층 셔터가 안에서 안 열림, 환풍구로).
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
const NIGHT_A := 1360                               ## 22:40 — 서기의 밤 반사(게이트 → 승강기 문 긁기)
const NIGHT_B := 1401                               ## 23:21

var host: InteriorHost
var st: StoryState
var log_on := false
var _tick := 0.0
var _clerk_mode := -1                               ## 0 졸음 · 1 밤 반사

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


func _hello(n: int, tail := "") -> void:
	host.hint("삑 — '어서 오십시오, %s.'%s" % [CARDS[n][1], tail], 3.0)


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
	if n == 0:                                                         # 봉쇄 뒤: 날개 · 셔터가 반쯤 열린 채 굳었다(지나갈 수 있다)
		match door:
			"g2":
				_open_gate(GATE2)
			"g3":
				_open_gate(GATE3)
			"18":
				_open_shutter(SHUT_18)
		return
	if n == 9:
		_open_shutter(SHUT_18)
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
				_hello(n, "  철문 잠금쇠가 풀린다.")
				host.map.unlock_door(STAIR_DOOR.x, STAIR_DOOR.y)
		"el":
			if g >= 3 and v("POWER") == 1 and v("LOCK") == 0:
				_sv("R", 1)
				_hello(n)
		"sg":
			if g >= 3:
				_sv("R", 1)
				_sv("SG", 1)
				_hello(n, "  셔터가 덜컹 오른다.")
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
		1:                                                             # 22:40 진짜 임시 카드 — 그날 밤의 심부름꾼
			_sv("R", 1)
			_sv("ROBOT_OK", 1)
			_open_shutter(SHUT_18)
			host.hint("스피커: '남기범 서기님 — 송출실 심부름 확인. …도미란 대리님이 기다리셨습니다.'", 5.0)
		2:
			_sv("R", 5)                                                # 주인이 이미 이 층 의자에 — 질문
		3:
			_sv("R", 6 if g == 3 else 0)                               # 퇴근한 사람 — 잔업 사유
		4:
			if g == 3:
				_sv("R", 1)
				_sv("ROBOT_OK", 1)
				_open_shutter(SHUT_18)
				host.hint("스피커: '하보람 님, 2동에서 오셨습니다. 3동 권한 갱신 확인.'", 4.0)


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
		"no":
			pass
		"dead":                                                       # 엉뚱한 짓: 도미란 사망 확정 — 그 카드는 어디서도 안 열린다
			_sv("DEAD_DM", 1)
			_sv("INC_DAY", day())
			_log("도미란 사망 처리")
		"inc":
			_sv("INC", 1)
			_sv("INC_DAY", day())
			if _mid() == TOP:
				_shut(SHUT_18)


func smash() -> void:
	_sv("LOCK", 1)
	_sv("ESCORT", 0)
	if _mid() == TOP:
		host.map.add_runtime_prop("metro_robot_down", Vector2i(11, 4))
		for p in host.map.props.duplicate():
			if p["name"] == "metro_robot_stand" and p.has("node"):
				p["node"].visible = false
		_open_shutter(SHUT_18)
	_log("경비 로봇 부숨 — 전 층 봉쇄")


# ---------------------------------------------------------------- 서기 남기범(야생 구울 · 22:40 진짜 빨강 카드)
func _clerk():
	for e in host.combat.enemies:
		if is_instance_valid(e) and str(e.who) == CLERK and not e.cmb.dead:
			return e
	return null


## 낮엔 로비 소파에서 졸고(카드를 풀 수 있다) · 22:40~23:21엔 3동 게이트 너머 승강기 문 앞으로 가 긁는다
func _clerk_step(placed: bool) -> void:
	var e = _clerk()
	if e == null:
		_sv("DOZE", 0)
		return
	if e.brain.state == AIBrain.S.COMBAT:
		_sv("DOZE", 0)
		return
	var m := _minute()
	var mode := 1 if (m >= NIGHT_A and m < NIGHT_B) else 0
	if mode == _clerk_mode:
		return
	_clerk_mode = mode
	var sofa := Vector2(SOFA) * 32.0 + Vector2(16, 16)
	if mode == 0:
		if placed or e.loco.logical.distance_to(sofa) > 40.0:
			e.loco.place(sofa)
		e.route = []
		e.doze = "sit"
		e.asleep = true
		e.det_mul = 0.3
		e.set_pose("sit")
		_sv("DOZE", 1)
	else:
		e.doze = ""
		e.asleep = false
		e.det_mul = 0.6
		e.set_pose("stand")
		_open_gate(GATE3)                                              # 그의 카드는 진짜다 — 게이트가 혼자 삑
		if _mid() == LOBBY:
			host.hint("로비 3동 게이트가 혼자 '삑' — '어서 오십시오, 남기범 서기님.'", 3.5)
		e.route = [[Vector2(ELEV_1) * 32.0 + Vector2(16, 16), 9999.0]]
		e._route_i = 0
		_sv("DOZE", 0)


func steal() -> void:
	if st.items.has("M-401"):
		return
	st.call_fn("give", ["M-401", 1])
	_sv("CLERK_SEEN", 1)


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
	if st.items.has("M-401"):
		return
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


func fake() -> void:
	if q("RESULT") != 0:
		return
	_sq("RESULT", 3)
	_sq("DAY", day())
	_quest()


func woo() -> void:
	if not st.items.has(TAPE) or q("RESULT") != 0:
		return
	st.call_fn("take", [TAPE, 1])                                       # 우도하가 남산으로 — 송출하면 지워진다(그 테이프는 거기서 끝)
	st.call_fn("caps", [WOO_CAPS])
	st.call_fn("xp", [WOO_XP])
	_sq("RESULT", 2)
	_sq("RADIO", 1)
	_sq("DAY", day())
	host.hint("우도하: '…이거 그날 객장 소리야. 내일 아침 남산이 읽어. 송미래 누나가 한 줄 붙일 거고.'", 5.0)
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
			if v("LOCK") == 1:
				_open_gate(GATE2)
				_open_gate(GATE3)
			var me: Vector2i = host.map.tile_of(host.player.loco.logical)
			if me.y < 11 and me.x > 22:                                 # 계단 · 승강기로 내려왔다: 출구 센서가 3동 게이트를 연다
				_open_gate(GATE3)
			_clerk_step(true)
		TOP:
			if v("LOCK") == 1 or (v("ROBOT_OK") == 1 and v("INC") == 0):
				_open_shutter(SHUT_18)
			if v("LOCK") == 1:
				smash()
		FLOOR:
			if q("RESULT") == 1:
				host.map.set_prop_state(Vector2i(14, 1), "close")


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
					_open_gate(GATE2)
				"g3":
					_open_gate(GATE3)
		"pick18":
			_sv("UNK", v("UNK") + 1)
			_open_shutter(SHUT_18)
			host.play_scene.call_deferred("YT_ROBOT_IN")
		"forge":
			forge(int(a[1]), int(a[2]))
		"robot":
			robot(str(a[1]))
		"smash":
			smash()
		"open18":
			_open_shutter(SHUT_18)
		"power":
			_sv("POWER", 1)
			var e = _clerk()
			if e != null and e.asleep:                                 # 모터 소리에 서기가 깬다(밤 반사처럼 승강기로)
				wake_clerk()
		"elev":
			if str(a[1]) == "up":
				host.enter.call_deferred(TOP, "from_elev")
			else:
				host.enter.call_deferred(LOBBY, "from_elev")
		"vent":
			if str(a[1]) == "up":
				host.enter.call_deferred(TOP, "from_vent")
			else:
				host.enter.call_deferred(OFFICE, "from_vent")
		"steal":
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
