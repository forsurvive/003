## 구로 공단 지식산업센터 DG-KS · 문래 철공소 골목 1-D7 진행기(SD-09a L-R02-21 · L-R02-14 · SD-05 §3.21 UQ-69 · 1-D 계획 §13.5 · §13.6).
##   원고: script/act1/KS.txt. 맵: KS-01 화물 로비 · KS-02 공장층 · KS-03 옥상 · X-MR 문래 골목 · MR-01 성씨 선반 · MR-02 연 용접 · MR-03 용두식 금형.
## 동사 '라인 박자대로 움직인다': 공장층 라인은 4초 주기(프레스 쿵 → 컨베이어 한 칸 → 감시포 회전). 쿵 하는 0.8초 동안은 발소리가 묻힌다 —
##   라인 구역에서 그 틈 밖에 걷다가 성형-4(CR-326 · 앞 5칸)나 감시포(CR-320 · 앞 7칸, 바로 아래 1.5칸은 사각) 눈에 띄면 '라인 이탈' 경고.
##   경고 셋이면 라인 전체가 적대(그 방문 동안 — 나갔다 오면 공장장이 다시 돌린다). 작업 위치(노란 테)에 선 사람은 작업자다.
##   화면 가장자리 램프(초록 · 노랑 · 빨강) · 휴대폰 진동 한 번. 출근 카드를 찍었으면 로봇이 그 이름으로 부른다. 하루 일한 적이 있으면 첫 경고 하나는 봐준다.
## 사실은 한 곳(P1): UQ69_PAPER 서류(0 없음 · 1 이관 · 2 110% · 3 퇴근 · 4 오타) · UQ69_DIE 금형(0 프레스 · 1 꺼내 듦 · 2 문래 · 3 새벽인력 · 4 재가동 ·
##   5 어딘가에 둠 · 6 하역장) · UQ69_DEST 수레 행선지(2 문래 · 3 새벽인력) · KS_LINE(0 가동 · 1 오타 두 배 · 2 재가동 · −1 멈춤) · KS_ALARM 1 = 모준서를 해쳤다(영구 적대).
## 결과 반영은 한 번(UQ69_DONE_DAY) — 수레는 다음 06:00(P6), 소문은 하루 늦게(P7, rumors.txt).
class_name Ks
extends Node

signal want_save(why: String)

const QID := "UQ-69"
const LOBBY := "KS-01"
const FLOOR := "KS-02"
const ROOF := "KS-03"
const ALLEY := "X-MR"
const MO := "N-R02-049"
const SEONG := "N-R02-021"
const YEON := "N-R02-022"
const YONG := "N-R02-504"
const SB_HEADS := ["C-013", "C-049"]              ## 새벽인력 소장 · 실장 — 둘 다 죽었으면 ② 없음
const ROBOT := "CR-326"
const TURRET := "CR-320"
const DIE := "M-395"
const TELE := "M-396"
const TICKET := "M-197"
const HALF := "M-198"
const TEAM := "calm_ks"
const PERIOD := 4.0                               ## 라인 한 주기(초) — 오타 '1030%'면 절반
const WINDOW_K := 0.2                             ## 프레스가 쿵 하는 동안(주기의 20% — 4초면 0.8초 · 오타 두 배 박자면 0.4초)
const IDLE_S := 1.2                               ## 노란 테 밖에서 감시포 · 성형-4 눈앞에 이만큼 서 있으면 '무단 정지' 경고
const BACK_S := 0.6                               ## 성형-4가 박자마다 뒤를 돌아보는 동안(시야가 뒤로)
const WARN_MAX := 3
const WARN_GAP := 2.0
const WARN_COOL := 15.0                           ## 이만큼 조용하면 경고 하나가 풀린다
const ROBOT_R := 5.0
const TURRET_R := 7.0
const BLIND_R := 1.5                              ## 감시포 바로 아래 사각(원작 계승)
const CARRY_MUL := 0.6                            ## 금형을 들고 걷는 걸음(과적)
const XP := 110
const SB_PAY := 400
const BOARD_PAY := 45
const LOCKER_FEE := 25
const LOCKER_DAYS := 7
const WORK_HOURS := 8
const LINES := [14, 19, 24]
const BELTS := [18, 21, 24, 27, 30]
const SLOT_X := [20, 26, 32]
const FLOOR_RECT := Rect2i(13, 12, 30, 17)       ## 라인 구역 — 이 안에서만 박자를 본다
const QC_RECT := Rect2i(1, 3, 11, 6)             ## 품질 관리실 = 쉼터(자동 저장)
const DROP_AT := Vector2i(30, 9)
const DOCK_BOX := Vector2i(34, 12)
const ESTOP_AT := Vector2i(40, 19)
const CRANE_AT := Vector2i(44, 22)
const BOARD_AT := Vector2i(24, 1)
const BENCHES := [Vector2i(17, 5), Vector2i(21, 5), Vector2i(29, 5), Vector2i(33, 5)]
const NAMES := ["박태섭", "김말순", "이동철", "정순애", "최병길", "윤영자", "한기만", "오경희"]   ## 2077 카드 주인(이름 있는 인물과 겹치지 않게)
const REQ := [["M-011", 3, "구로 차량기지 객차 철근"], ["M-012", 3, "금탑 승강기 케이블에서 벗긴 구리선"], ["M-015", 2, "남태령 신호 계전기"]]   ## 칠판 '이번 주 깎는 것'

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _ph := 0.0
var _hot := false                                 ## 이 방문 동안 라인이 적대(경고 셋 · 설비를 쳤다)
var _warn := 0
var _warn_t := -99.0
var _quiet := 0.0
var _forgive := false                             ## 숙련자 재량(하루 일한 사람 — 방문마다 한 번)
var _press_t := 0.0
var _step := false
var _turn := 0
var _tick := 0.0
var _in_qc := false
var _idle_t := 0.0
var _back_t := 0.0
var _lamp: CanvasLayer = null
var _lamp_rects: Array = []
var _ride_due := false                            ## 화물칸을 타고 내려왔다 — 하역장에 들어서면 쥐가 깬다


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["ks"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)
	host.box_closed.connect(_on_box)
	host.combat.enemy_down.connect(_on_down)
	host.combat.provoked.connect(_on_provoked)
	_lamp = CanvasLayer.new()
	_lamp.layer = 5
	_lamp.visible = false
	add_child(_lamp)
	for i in 4:
		var r := ColorRect.new()
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lamp.add_child(r)
		_lamp_rects.append(r)


func v(k: String) -> int:
	return int(st.vars.get_v("UQ69_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("UQ69_" + k, n)


func kv(k: String) -> int:
	return int(st.vars.get_v("KS_" + k))


func _skv(k: String, n: int) -> void:
	st.vars.set_v("KS_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[지식산업센터] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func _tc(c: Vector2i) -> Vector2:
	return Vector2(c) * 32.0 + Vector2(16, 16)


func sb_alive() -> bool:
	return not SB_HEADS.all(func(c): return st.is_dead(c))


## ② 용두식 중개가 열려 있나(용두식 생존 · 새벽인력이 아직 섰다)
func sb_open() -> bool:
	return not st.is_dead(YONG) and sb_alive()


## ① 받을 사람(성태경 — 죽었으면 연시헌이 잇는다 · 둘 다 죽으면 없음)
func smith() -> String:
	if not st.is_dead(SEONG):
		return SEONG
	return "" if st.is_dead(YEON) else YEON


func line_on() -> bool:
	return kv("LINE") >= 0


func card_name() -> String:
	return NAMES[clampi(kv("CARD_N"), 0, NAMES.size() - 1)]


func _line_unit(e) -> bool:
	return is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) in [ROBOT, TURRET]


func units() -> Array:
	return host.combat.enemies.filter(func(e): return _line_unit(e))


# ---------------------------------------------------------------- 맵에 들어섰다
func _on_map(id: String) -> void:
	_t = 0.0
	_hot = false
	_warn = 0
	_quiet = 0.0
	_forgive = kv("WORK_N") >= 1
	_in_qc = false
	_idle_t = 0.0
	_back_t = 0.0
	_lamp.visible = false
	host.carry_mul = CARRY_MUL if int(st.call_fn("has", [DIE])) == 1 else 1.0
	_die_where()
	if id == LOBBY and _ride_due:
		_ride_due = false
		for e in host.combat.enemies:
			if is_instance_valid(e) and not e.cmb.dead:
				e.hear("impact", host.player.loco.logical)
		host.hint("화물칸이 쿵 내려앉는다. 하역장의 쥐들이 일제히 고개를 든다.", 3.0)
	if id == LOBBY:
		if kv("SEEN") == 0:
			_skv("SEEN", 1)
			host.hint("쿵 … 쿵 … 위층에서 일정한 박자. 4초에 한 번 — 박자 사이로 컨베이어가 한 칸 끌리는 소리.", 4.5)
		_stock_dock()
	if id != FLOOR:
		return
	for e in units():
		if kv("ALARM") == 1:
			continue                                                  # 모준서를 해쳤다 — 라인은 처음부터 적대
		e.cmb.team = TEAM
		e.foes = []
		if not line_on():
			e.route = []
	if line_on() and kv("ALARM") == 0:
		if kv("WARN") == day():                                         # 오늘 이미 이탈 기록이 남았다 — 경고 하나를 안고 시작(실패의 무게)
			_warn = 1
			_forgive = false
			host.hint("성형-4의 렌즈가 이쪽에서 한 박자 더 머문다. 오늘 이탈 기록이 남아 있다.", 3.5)
		_lamp.visible = true
		_paint_lamp()
	_log("공장층 — 라인 %d · 단위 %d · 경보 %d" % [kv("LINE"), units().size(), kv("ALARM")])


# ---------------------------------------------------------------- 매 프레임: 박자 · 과적 · 쉼터
func _process(dt: float) -> void:
	if host == null or host.map == null or host.player == null:
		return
	var mid := _mid()
	if mid == FLOOR:
		_floor(dt)
	if not (mid.begins_with("KS-") or mid.begins_with("MR-") or mid == ALLEY):
		return
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 0.25
	host.carry_mul = CARRY_MUL if int(st.call_fn("has", [DIE])) == 1 else 1.0
	if v("DIE") == 1 and int(st.call_fn("has", [DIE])) == 0:
		_die_where()
	if kv("ALARM") == 0 and st.is_dead(MO):
		_robbed()


func _floor(dt: float) -> void:
	if not line_on() or kv("ALARM") == 1:
		return
	var period := PERIOD * (0.5 if kv("LINE") == 1 else 1.0)
	var prev := _ph
	_t += dt
	_ph = fmod(_t, period)
	if _ph < prev:
		_thump()
	if _press_t > 0.0:
		_press_t -= dt
		if _press_t <= 0.0:
			for y in LINES:
				host.map.set_prop_state(Vector2i(15, y), "")
	if prev < period * 0.5 and _ph >= period * 0.5:
		_back_t = BACK_S                                              # 성형-4가 박자 한가운데 뒤를 돌아본다
		for e in units():
			if str(e.row["id"]) == ROBOT and e.loco.motion == "idle":
				e.loco.facing = posmod(int(e.loco.facing) + 4, 8)
	if _back_t > 0.0:
		_back_t -= dt
	if prev < period * 0.25 and _ph >= period * 0.25:
		_step = not _step
		for y in LINES:
			for x in BELTS:
				host.map.set_prop_state(Vector2i(x + 1, y), "step" if _step else "")
	if prev < period * 0.75 and _ph >= period * 0.75:
		_turn = (_turn + 1) % 4
		for e in units():
			if str(e.row["id"]) == TURRET:
				e.stance = "hold"
				e.hold_dir = posmod(4 + [0, 1, 0, -1][_turn], 8)        # 서쪽(라인 쪽)을 보며 좌우로 45도
	if _hot:
		return
	_quiet += dt
	if _quiet >= WARN_COOL and _warn > 0:
		_quiet = 0.0
		_warn -= 1
		_paint_lamp()
	var pt := host.map.tile_of(host.player.loco.logical)
	var qc := QC_RECT.has_point(pt)
	if qc and not _in_qc:
		want_save.emit("shelter")                                    # 쉼터(품질 관리실) — '서류까지'와 '금형 반출'을 끊는다(F11)
	_in_qc = qc
	if not FLOOR_RECT.has_point(pt):
		return
	var pc := host.combat.pc
	var moving: bool = pc.movement != "still"
	var on_slot := pt.x in SLOT_X and (pt.y - 1) in LINES
	if on_slot:                                                        # 노란 테 안 = 작업자(걷든 서든)
		_idle_t = 0.0
		return
	var who = _seen_by(pt)
	if not moving:                                                     # 테 밖에 멈춰 서 있다 — 눈앞이면 '무단 정지'(어디에 서느냐가 동사)
		_idle_t = _idle_t + dt if who != null else 0.0
		if _idle_t >= IDLE_S and not _clock_gap():
			_idle_t = 0.0
			_warn_step(who, pt, true)
		return
	_idle_t = 0.0
	if _ph < period * WINDOW_K or host.combat.since_shot < 0.5 or _clock_gap():
		return
	if who != null:
		_warn_step(who, pt)


func _clock_gap() -> bool:
	return _t - _warn_t < WARN_GAP


## 프레스가 쿵 — 그림 · 근처면 '쿵'
func _thump() -> void:
	_press_t = 0.3
	for y in LINES:
		host.map.set_prop_state(Vector2i(15, y), "down")
	var pp := host.player.loco.logical
	if pp.distance_to(_tc(Vector2i(16, 19))) < 14.0 * 32.0:
		host.combat._pop("쿵", _tc(Vector2i(16, 19)) + Vector2(0, -40), Color("A8A090"))


## 나를 보는 라인 설비(성형-4 앞 5칸 · 감시포 앞 7칸, 바로 아래는 사각) — 벽이 가리면 못 본다
func _seen_by(pt: Vector2i):
	var pp := host.player.loco.logical
	for e in units():
		var r := ROBOT_R if str(e.row["id"]) == ROBOT else TURRET_R
		var to: Vector2 = pp - e.loco.logical
		var d := to.length() / 32.0
		if d > r or (str(e.row["id"]) == TURRET and d < BLIND_R):
			continue
		var f: Vector2 = Locomotion.VEC[int(e.loco.facing)].normalized()
		if str(e.row["id"]) == ROBOT and _back_t > 0.0 and e.loco.motion != "idle":
			f = -f                                                        # 걸으며 뒤돌아보는 동안(그림은 걷는 쪽 — 시야만 뒤로)
		if f.dot(to.normalized()) < 0.4:
			continue
		if not host.map.line_of_sight(e.loco.logical, pp):
			continue
		return e
	return null


func _warn_step(e, pt: Vector2i, idle := false) -> void:
	_warn_t = _t
	_quiet = 0.0
	if _forgive:
		_forgive = false
		host.combat._pop("…숙련자 재량.", e.loco.logical + Vector2(0, -34), Color("C8C0A8"))
		return
	_warn += 1
	var ln := 1 + LINES.find(_near_line(pt.y))
	var nm := (card_name() + " 작업자") if kv("CARD") >= 1 else "작업자"
	var msg := ("%s, 작업 위치 아님 — %d번 라인 노란 테로." if idle else "%s, %d번 라인 복귀 바랍니다.") % [nm, ln] if _warn < WARN_MAX else "라인 이탈 — 경보."
	host.combat._pop(msg, e.loco.logical + Vector2(0, -34), Color("E8C860") if _warn < WARN_MAX else Color("E05040"))
	Input.vibrate_handheld(80)
	_paint_lamp()
	_log("경고 %d (%s)" % [_warn, str(e.row["id"])])
	if _warn >= WARN_MAX:
		_go_hot("라인 이탈")


func _near_line(y: int) -> int:
	var best := LINES[0]
	for l in LINES:
		if absi(l - y) < absi(best - y):
			best = l
	return best


## 이 방문 동안 라인 전체가 적대(경고 셋 · 설비를 쳤다 · 모준서를 해쳤다)
func _go_hot(why: String) -> void:
	if _hot:
		return
	_hot = true
	_warn = WARN_MAX
	_skv("WARN", day())
	_paint_lamp()
	for e in units():
		e.foes = ["player", "ally"]
		e.cmb.team = "enemy_ks"
		e.wake()
		e.brain.gauge = AIBrain.DETECT_AT
		e.brain.last_seen = host.player.loco.logical
		e.brain._go(AIBrain.S.COMBAT)
	host.hint("천장 회전등이 붉게 돈다. '라인 이탈 — 불량 작업자 처리.' 감시포가 이쪽으로 돈다.", 4.0)
	_log("라인 적대(%s)" % why)


func _on_provoked(team: String) -> void:
	if team == TEAM:
		_go_hot("설비를 쳤다")


func _paint_lamp() -> void:
	if _lamp == null or not host.is_inside_tree():
		return
	var vp := host.get_viewport().get_visible_rect().size
	var col := Color(0.35, 0.8, 0.4, 0.55) if _warn == 0 else (Color(0.95, 0.8, 0.25, 0.65) if _warn < WARN_MAX else Color(0.9, 0.25, 0.2, 0.75))
	var th := 3.0
	var rs := [Rect2(0, 0, vp.x, th), Rect2(0, vp.y - th, vp.x, th), Rect2(0, 0, th, vp.y), Rect2(vp.x - th, 0, th, vp.y)]
	for i in 4:
		var r: ColorRect = _lamp_rects[i]
		r.position = (rs[i] as Rect2).position
		r.size = (rs[i] as Rect2).size
		r.color = col


# ---------------------------------------------------------------- 명령(@cmd ks …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"heard":                                                      # 성태경이 금형 얘기를 했다(발동 ① — 리어카를 보낼 수 있다)
			_sv("HEARD", 1)
		"seen":                                                       # 3라인 프레스의 금형을 직접 봤다(발동 ②)
			if v("HEARD") == 0:
				_sv("HEARD", 2)
		"met":
			_sv("MET", 1)
		"card":
			card()
		"tele":
			tele(int(a[1]))
		"paper":
			paper(int(a[1]))
		"estop":
			estop()
		"take":
			take_die()
		"crane":
			crane()
		"ride":
			ride()
		"lift":
			lift()
		"dest":
			dest(int(a[1]))
		"give":
			give(int(a[1]))
		"work":
			work()
		"board":
			board()
		"boardshow":
			board_show()
		"req":
			req()
		"rent":
			rent()
		"stamp":
			_skv("STAMP", day())                                       # 도장 찍은 날(소문은 다음 날부터 — P7)
	_quest()
	done.call()


## 출근 카드: 카드꽂이에서 하나를 뽑아 찍는다(마지막 찍은 이름 — 날마다 다른 카드)
func card() -> void:
	var n := posmod(day() * 3 + kv("CARD"), NAMES.size())
	_skv("CARD", kv("CARD") + 1)
	_skv("CARD_N", n)
	if host.map != null and _mid() == LOBBY:
		host.map.set_prop_state(Vector2i(18, 1), "punched")
	host.hint("카드를 기록기에 넣고 레버를 당긴다. 찰칵 — '%s · 출근 · 2277'. 200년 만의 출근 도장." % NAMES[n], 4.0)
	_log("출근 카드 — %s" % NAMES[n])


## 본사 전보 조각(1 굴뚝 · 2 경비실 · 3 용두식) — 한 번씩
func tele(n: int) -> void:
	var k := "T%d" % n
	if v(k) == 1:
		return
	_sv(k, 1)
	st.call_fn("give", [TELE, 1])
	var got := v("T1") + v("T2") + v("T3")
	host.hint("본사 전보 조각(%d/3)." % got + ("  셋이 맞물린다 — 끊긴 글이 이어진다." if got == 3 else ""), 3.5)


## 11월 서류: 1 이관(문래) · 2 110%(재가동) · 3 전원 퇴근 · 4 오타 1030%(라인 두 배)
func paper(n: int) -> void:
	if st.is_dead(MO) or (v("PAPER") >= 1 and v("PAPER") != 4):
		return
	_sv("PAPER", n)
	match n:
		1, 3:
			_stop_line("서류")
		2:
			_skv("LINE", 2)
			_sv("DEST", 0)
			_resolve(4, false)                                          # ③ 재가동 — 금형은 라인에 박힌 채(빼려면 라인을 부숴야 한다 — 막음)
		4:
			_skv("LINE", 1)
			host.hint("라인 소리가 바뀐다 — 쿵, 쿵, 쿵. 박자가 두 배로 빨라졌다.", 4.0)
	if n == 3 and _mid() == FLOOR:
		for b in BENCHES:
			host.map.set_prop_state(b, "stamped")
		_skv("STAMP", day())                                       # 도장 찍은 날(소문은 다음 날부터 — P7)
	_log("11월 서류 %d" % n)


## 비상정지: 오타(1030%)로 과부하일 때만 승인 없이 눌린다
func estop() -> void:
	if kv("LINE") != 1:
		return
	_skv("ESTOP", 1)
	if _mid() == FLOOR:
		host.map.set_prop_state(ESTOP_AT, "pressed")
	_stop_line("비상정지")


func _stop_line(why: String) -> void:
	_skv("LINE", -1)
	_lamp.visible = false
	_hot = false
	if host.map != null and _mid() == FLOOR:
		for y in LINES:
			host.map.set_prop_state(Vector2i(15, y), "off")
			for x in BELTS:
				host.map.set_prop_state(Vector2i(x + 1, y), "step")
		host.map.set_prop_state(BOARD_AT, "off")
		for e in units():
			e.foes = []
			e.cmb.team = TEAM
			e.route = []
			e.brain._go(AIBrain.S.IDLE)
	Dungeon.check_clear(st, FLOOR)
	_log("라인 멈춤(%s)" % why)


## 프레스에서 금형을 뺀다: 라인이 섰거나 · 모준서가 없거나(강탈)
func take_die() -> void:
	if v("DIE") != 0 or (line_on() and kv("ALARM") == 0):
		return
	st.call_fn("give", [DIE, 1])
	_sv("DIE", 1)
	host.carry_mul = CARRY_MUL
	host.hint("볼트 여섯을 풀고 지렛대로 들어 올린다. 태성 총열 금형 — 묵직하다. 걸음이 느려진다.", 4.0)


## 외벽 데크 크레인으로 하역장에 내린다(금형만 · 나는 계단으로)
func crane() -> void:
	if int(st.call_fn("has", [DIE])) == 0:
		return
	st.call_fn("take", [DIE, 1])
	_sv("DIE", 6)
	host.carry_mul = 1.0
	if v("PAPER") == 1 and v("DEST") == 0 and smith() != "":
		_sv("DEST", 2)                                                # 이관 통보서가 붙어 내려간다 — 성씨 리어카가 알아서 온다
		_sv("DEST_DAY", day())
	if _mid() == FLOOR:
		host.map.set_prop_state(CRANE_AT, "lowered")
	host.hint("권양기 손잡이를 돌린다. 화물칸이 덜컹거리며 외벽을 타고 내려간다 — 아래 하역장에서 쥐들이 찍찍댄다.", 4.0)


## 화물칸에 직접 타고 내려간다(소리 큼 — 하역장 쥐가 깬다)
func ride() -> void:
	if int(st.call_fn("has", [DIE])) == 1:
		crane()                                                       # 금형을 들었으면 같이 싣고 내린다
	if host.is_inside_tree():
		host.go.call_deferred(LOBBY, "drop")
	_ride_due = true


## 하역장 금형을 다시 든다
func lift() -> void:
	if v("DIE") != 6:
		return
	st.call_fn("give", [DIE, 1])
	_sv("DIE", 1)
	_sv("DEST", 0)
	host.carry_mul = CARRY_MUL
	if _mid() == LOBBY:
		_hide_prop("die_mold")


## 수레 행선지(하역장 금형) — 다음 06:00에 실어 간다
func dest(n: int) -> void:
	if v("DIE") != 6 or not n in [2, 3]:
		return
	_sv("DEST", n)
	_sv("DEST_DAY", day())
	_log("수레 행선지 %d" % n)


## 손으로 건넨다: 2 문래(성태경 · 연시헌) · 3 용두식 → 새벽인력
func give(n: int) -> void:
	if int(st.call_fn("has", [DIE])) == 0 or not n in [2, 3]:
		return
	st.call_fn("take", [DIE, 1])
	host.carry_mul = 1.0
	_resolve(n, true)


## 결과: 2 문래 · 3 새벽인력 · 4 재가동 — 한 번만(P1 · P10)
func _resolve(n: int, by_hand: bool) -> void:
	if v("DONE_DAY") > 0:
		return
	_sv("DIE", n)
	_sv("DONE_DAY", day())
	match n:
		2:
			st.call_fn("aff", ["JC", 3])
			st.call_fn("result", [QID, 1])
		3:
			st.call_fn("aff", ["SB", 4])
			st.call_fn("result", [QID, 2])
			if by_hand:
				st.call_fn("caps", [SB_PAY])
			else:
				_sv("REWARD", 1)                                          # 수레로 보냈다 — 값은 용두식에게서
		4:
			st.call_fn("result", [QID, 3])
	_log("금형 자리 %d(%s)" % [n, "손" if by_hand else "수레"])


## 금형이 손에서 사라졌다(버림 · 상자) — 그 자리가 금형 자리(5). 다시 쥐면 1
func _die_where() -> void:
	var has := int(st.call_fn("has", [DIE])) == 1
	if v("DIE") == 5 and has:
		_sv("DIE", 1)
	elif v("DIE") == 1 and not has:
		_sv("DIE", 5)
		_log("금형을 어딘가에 둠")


func _on_box(_b: Dictionary, _c: Dictionary) -> void:
	_die_where()


## 맵 소품 그림 하나를 숨긴다(조건이 바뀌었는데 맵을 다시 읽기 전 — 들어 올린 금형)
func _hide_prop(pname: String) -> void:
	for p in host.map.props:
		if str(p["name"]) == pname and p.has("node"):
			(p["node"] as Node2D).visible = false


## 하루 일하기: 출근 카드 · 작업 위치 · 라인 가동 · 주에 한 번 — 8시간(P6 날마다 판정) · 그날 묶인 사건이 있으면 안 된다(P4 · P5)
func can_work() -> String:
	if kv("CARD") == 0:
		return "카드부터 찍어야 작업자다."
	if not line_on() or _hot or kv("ALARM") == 1:
		return "라인이 일을 받지 않는다."
	if kv("WORK_DAY") > 0 and day() < kv("WORK_DAY") + 7:
		return "이번 주 작업은 했다."
	if int(st.vars.get_v("CAPTURE_BY")) != 0:
		return "지금은 일할 처지가 아니다."
	return host.wait_block()


func work() -> void:
	var why := can_work()
	if why != "":
		host.hint(why, 3.0)
		return
	host.busy = true
	host.ev.run("fade_out", ["black", "3"], func() -> void:
		host.advance_minutes(WORK_HOURS * 60)
		_skv("WORK_N", kv("WORK_N") + 1)
		_skv("WORK_DAY", day())
		st.call_fn("give", [TICKET, 1])
		st.call_fn("give", [HALF, 1])
		_forgive = true
		host.hint("여덟 시간. 쿵 — 내려놓고 — 쿵. 손이 박자를 외웠다. 퇴근 칸에 카드를 꽂으려다 그만둔다. 식권 한 장 · 총열 반제품 하나.", 5.0)
		ev_fade_in())
	_log("하루 일함 %d" % (kv("WORK_N") + 1))


func ev_fade_in() -> void:
	host.ev.run("fade_in", ["black", "3"], func() -> void: host.busy = false)


## 게시판 '이달의 우수 작업자' — 하루 일한 다음 날부터(첫 번째는 카드 주인 이름 · 두 번째부터 내 이름)
func board() -> void:
	if kv("AWARD") == 0:
		return
	var nm := card_name() if kv("AWARD") == 1 else st.player_full()
	host.hint("'이달의 우수 작업자 — %s'. 분필이 아니라 게시판 글자판이 새로 돌아갔다." % nm, 4.0)


## 칠판 '이번 주 깎는 것': 주마다 하나 — 가져오면 값(작은 부탁)
func req_now() -> Array:
	return REQ[posmod(int(day() / 7.0), REQ.size())]


func board_show() -> void:
	var r: Array = req_now()
	var done := int(st.vars.get_v("MR_BOARD_WK")) == int(day() / 7.0) + 1
	host.hint("칠판 '이번 주 깎는 것' — %s %d개.%s" % [str(r[2]), int(r[1]), "  (줄이 그어졌다 — 이번 주는 끝)" if done else "  '재료 있으면 가져와. 값 쳐 준다.'"], 4.0)


func req() -> void:
	var wk := int(day() / 7.0) + 1
	if st.is_dead(SEONG) or v("DIE") == 3 or int(st.vars.get_v("MR_BOARD_WK")) == wk:
		return
	var r: Array = req_now()
	if int(st.call_fn("has", [str(r[0]), int(r[1])])) == 0:
		return
	st.call_fn("take", [str(r[0]), int(r[1])])
	st.call_fn("caps", [BOARD_PAY])
	st.vars.set_v("MR_BOARD_WK", wk)
	st.vars.set_v("MR_BOARD", int(st.vars.get_v("MR_BOARD")) + 1)
	st.call_fn("aff", ["JC", 1])
	host.hint("성태경이 칠판의 줄을 분필로 긋는다. (+%d캡)" % BOARD_PAY, 3.0)


## 공구 사물함 빌리기(7일 25캡 — 지키는 사람이 있어 털리지 않는다 · 기한이 지나면 성태경이 맡아 둔다)
func rent() -> void:                                                  # 값은 선택지 [캡 25] 태그가 이미 받았다
	st.vars.set_v("MR_LOCKER", 1)
	st.vars.set_v("MR_LOCKER_DAY", day() + LOCKER_DAYS)


## 재가동(③): 주마다 반제품 하나가 하역장 납품 상자에 쌓인다(문래가 사 간다)
func _stock_dock() -> void:
	var n := v("HALF")
	if n <= 0 or host.map == null:
		return
	var b: Dictionary = host.map.boxes.get(DOCK_BOX, {})
	if b.is_empty():
		return
	var items: Dictionary = host.box_contents(b)["items"]
	items[HALF] = int(items.get(HALF, 0)) + n
	_sv("HALF", 0)


# ---------------------------------------------------------------- 하루 판정(06:00): 수레 · 반제품 · 사물함 · 게시판
func _on_day(d: int) -> void:
	if v("DIE") == 6 and v("DEST") in [2, 3] and d > v("DEST_DAY"):
		var n := v("DEST")
		if n == 3 and not sb_open():
			_sv("DEST", 0)                                                # 그사이 용두식이 죽었거나 새벽인력이 기울었다 — 수레가 안 온다
		elif n == 2 and smith() == "":
			_sv("DEST", 0)
		else:
			_resolve(n, false)
			_quest()
	if v("DIE") == 4 and kv("LINE") == 2 and v("DONE_DAY") > 0 and (d - v("DONE_DAY")) % 7 == 0:
		_sv("HALF", v("HALF") + 1)
	if int(st.vars.get_v("MR_LOCKER")) == 1 and d >= int(st.vars.get_v("MR_LOCKER_DAY")):
		st.vars.set_v("MR_LOCKER", 2)                                     # 기한이 지났다 — 성태경이 꺼내 맡아 둔다(잃지 않음)
	if kv("WORK_DAY") > 0 and d > kv("WORK_DAY") and kv("AWARD") < mini(2, kv("WORK_N")):
		_skv("AWARD", mini(2, kv("WORK_N")))


## 모준서를 해쳤다(강탈): 로봇 · 감시포 영구 적대 · 금형은 자유 · 카르마
func _robbed() -> void:
	_skv("ALARM", 1)
	if _mid() == FLOOR:
		_go_hot("공장장")
	_quest()
	_log("모준서 사망 — 강탈")


func _on_down(e: Enemy) -> void:
	if not str(e.row.get("id", "")) in [ROBOT, TURRET] or _mid() != FLOOR:
		return
	if units().is_empty() and line_on():
		_stop_line("설비 파손")
		host.hint("마지막 설비가 멈춘다. 프레스 램이 반쯤 내려온 채 굳는다. 라인이 섰다.", 4.0)


# ---------------------------------------------------------------- UQ-69 단계는 사실로 센다(P2)
func _quest() -> void:
	var cur := st.quests.stage(QID)
	if cur >= 100:
		return
	if cur == 0:
		if v("HEARD") == 0 and v("MET") == 0 and int(st.call_fn("has", [DIE])) == 0 and v("DIE") == 0:
			return
		st.quests.set_stage(QID, 10)
	var s := 10
	if v("MET") == 1:
		s = 20
	if v("PAPER") >= 1 or kv("ALARM") == 1 or kv("LINE") < 0:
		s = 30
	if v("DIE") in [1, 5, 6]:
		s = 40
	if v("DIE") in [2, 3, 4] and v("DONE_DAY") > 0:
		s = 100
	if s > st.quests.stage(QID):
		st.quests.set_stage(QID, s)
		if s == 100:
			st.call_fn("xp", [XP])
			_log("UQ-69 끝 — 금형 자리 %d" % v("DIE"))
