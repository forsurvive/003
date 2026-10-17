## U02 남태령 지하 진행기(단계 1-D2, SD-09f §3.2 U02 · L-UG-05 · 훅 UG-H01 「4호선 남쪽 터널 소등」 · UG-H02 「남태령 밀통로」 · 1-D 계획 §8).
## 원고: script/act1/U02.txt · SADANG.txt SD_BAN(반로아 안내) · SAGOGAE.txt SG_RADIO(막사 무전) · SG_KWON(할매 보증). 맵: NT-03 터널 · NT-02 승강장 · NT-01 대합실 지하 초소.
## 사실은 변수 한 곳(P1) — 원고 머리 주석. 훅 둘은 SD-04a에 퀘스트 ID가 없어 수첩 메모 한 줄 + XP로만 남긴다(목록 제목 없음).
## 시간선(P4 · P6): 교대 10분(06 · 18시)은 시계로 켠다. 밀통로 발각은 '흔적'이 있을 때 다음 교대 시작에 — 주인공이 남태령 지하에 있으면 그다음 교대로 미룬다.
##   붙들린 할매는 다음 날 06시 분류반(Q-02)으로, 거기서 사흘 뒤 청계산으로 — 주인공이 그 자리에 있으면 하루씩 미룬다.
class_name U02Paths
extends Node

const AJAE := "N-UG-001"
const EOM := "N-UG-006"
const HAL := "N-UG-007"
const MAPS := ["NT-01", "NT-02", "NT-03"]
const SHIFTS := [360, 1080]                                ## 06:00 · 18:00(하루 안 분)
const LAMPS := [8, 22, 28, 40, 44, 58]                     ## NT-03 터널 등(북쪽 벽 3줄) — 32칸 서쪽이 '사당 측'
const XP_H01 := 50
const XP_H02 := 75

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _last_map := ""


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["u02"] = _cmd
	host.day_tick.connect(_on_day)


func v(k: String) -> int:
	return int(st.vars.get_v("U02_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("U02_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[남태령 지하] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func _tile() -> Vector2i:
	return host.map.tile_of(host.player.loco.logical) if host.map != null and host.player != null else Vector2i(-1, -1)


func _noop() -> void:
	pass


## 순찰이 늘어난 날(초소 회로를 끊은 다음 사흘 · 무전 들킴 사흘): 교대 틈이 닫힌다
func patrol() -> bool:
	var d := day()
	return (v("LIGHT") == 3 and d > v("LIGHT_DAY") and d <= v("LIGHT_DAY") + 3) or (v("RADIO") == 3 and d <= v("PATROL_DAY") + 2)


## 지금이 교대 틈인가(06 · 18시부터 10분 — 무전 거짓 보고를 한 날과 다음 날은 20분)
func shift_now() -> bool:
	if patrol():
		return false
	var m := Clock.abs_min(host.date_text) % 1440
	var span := 20 if v("GAP_DAY") > 0 and day() <= v("GAP_DAY") + 1 else 10
	for s in SHIFTS:
		if m >= s and m < s + span:
			return true
	return false


# ---------------------------------------------------------------- 매 0.5초: 교대 틈 · 철망 빗장 · 뒷구멍 손님 · 초소 차단봉
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5 or host == null or host.map == null or host.player == null:
		return
	_t = 0.0
	_sv("PATROL", 1 if patrol() else 0)                                  # 원고가 읽는 순찰 판(할매: '요 며칠은 애기들이 안 올라가')
	var on := shift_now()
	if on != (v("SHIFT") == 1):
		_sv("SHIFT", 1 if on else 0)
		_log("교대 틈 %s" % ("열림" if on else "닫힘"))
		if on:
			_shift_start()
		if _mid() in ["NT-01", "NT-02"] and not host.ev.busy() and not host.box.active:
			host.ev.handlers["refresh"].call([], _noop)                  # 엄태하 · 계단참 보초가 자리를 비우고 돌아온다
	var mid := _mid()
	if mid != _last_map:
		if mid == "NT-03" and Vector2(_tile()).distance_to(Vector2(host.map.tile_of(host.map.mark_pos("from_shaft")))) <= 2.0 and v("MET_HAL") == 0:
			_sv("BACKDOOR", 1)                                           # 맨홀로 내려왔다 — 할매가 '뒷구멍 손님'으로 맞는다
		_last_map = mid
	if mid == "NT-03" and v("OPEN") == 0 and _tile().x <= 3:
		_sv("OPEN", 1)                                                   # 철망 빗장은 안쪽에 있다(U-02 철문과 같은 규칙)
		host.hint("철망 문 빗장이 이쪽에 걸려 있다. 빗장을 뽑아 둔다 — 이제 사당 쪽에서도 열린다.", 6.0)


## 교대가 시작되는 순간: 흔적이 남은 밀통로를 찾아낸다(UG-H02) — 주인공이 남태령 지하에 있으면 다음 교대로(P4)
func _shift_start() -> void:
	if v("PATH") != 1 or v("TRACE") != 1 or v("HAL") != 0 or st.is_dead(HAL):
		return
	if _mid() in MAPS:
		_log("발각 미룸(주인공이 남태령 지하에 있다)")
		return
	_sv("PATH", 3)
	_sv("HAL", 1)
	_sv("FOUND", day())
	_sv("HAL_DAY", day())
	_sv("HFEE", 40 + 10 * clampi(v("USED"), 1, 4))
	var who := "계단참 보초가" if st.is_dead(EOM) else "엄 하사가"              # 초소장이 없으면 보초가 맨홀 자국을 찾는다
	var why: String = ["", "반쯤 걸친 맨홀 뚜껑을", "맨홀에서 올라오던 나를", "밝은 터널을 지나는 나를"][clampi(v("TRACE"), 1, 3)]   # 발각의 까닭은 내가 한 일(재미 검수 ②)
	st.book.memo(HAL, "밀통로가 들켰다 — %s %s 봤다. 할매는 초소 책상 옆 의자에, 내일 아침 분류반으로." % [who, why], host.date_text)
	_log("밀통로 발각 — 할매 붙들림(벌금 %d)" % v("HFEE"))


# ---------------------------------------------------------------- 06:00: 붙들린 할매의 하루 · 분류반 사흘
func _on_day(d: int) -> void:
	if v("HAL") == 1 and d >= v("HAL_DAY") + 1 and not st.is_dead(HAL):
		if _mid() == "NT-01":
			_sv("HAL_DAY", d)                                            # 눈앞에서 사라지게 하지 않는다(P4) — 하루 미룸
			return
		_sv("HAL", 2)
		_sv("HAL_DAY", d)
		_sv("SOL", 4)
		st.book.memo(HAL, "지상 분류반 천막으로 넘겨졌다. 사흘 뒤 청계산 호송 — 권은서 분류관이 보증을 받는다.", host.date_text)
		_log("할매 → 분류반")
	elif v("HAL") == 2 and d >= v("HAL_DAY") + 3 and not st.is_dead(HAL):
		if _mid() in ["Q-02", "X-SG"]:
			_sv("HAL_DAY", d - 2)
			return
		_sv("HAL", 4)
		st.book.memo(HAL, "청계산으로 호송됐다. 대피 측실은 빈 집이다.", host.date_text)
		_log("할매 → 청계산")


# ---------------------------------------------------------------- 원고 명령(@cmd u02 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"open":
			_sv("OPEN", 1)
		"go":
			done.call()
			_go(str(a[1]), str(a[2]))
			return
		"scene":                                                         # 차단봉에서 초소장을 부른다 — 지금 장면이 닫힌 뒤
			done.call()
			host.play_scene.call_deferred(str(a[1]))
			return
		"guide":                                                         # 반로아 안내(캡은 선택지 태그가 받았다): 40분 걸어 승강장 앞 · 벽에 분필 화살표
			_sv("OPEN", 1)
			_sv("GUIDE", 1)
			host.advance_minutes(40)
			done.call()
			_go("NT-03", "roa")
			return
		"light":
			_light(int(a[1]))
		"ajae_pay":
			_sv("ASK", 2)
			st.call_fn("caps", [40])
		"pay":                                                           # 할매에게 길값(캡은 선택지 태그가 받았다)
			_sv("PATH", 1)
			st.book.memo(HAL, "과천 쪽 밀통로 — 측실 뒤 환기 갱 → 과천대로 배수 맨홀. 06 · 18시 교대 10분에만. 뚜껑은 꼭 덮을 것.", host.date_text)
		"wait":                                                          # 다음 교대 틈까지 쉰다(할매 차 · 발판에 기대기) — 주인공이 남태령 지하에 있으니 발각 판정은 없다
			host.advance_minutes(_to_next_shift())
			_sv("SHIFT", 1 if shift_now() else 0)                         # 순찰이 늘어난 날은 기다려도 틈이 열리지 않는다(재미 검수 ②)
		"wait_hour":                                                     # 밤 막사: 다음 정시 호출까지(황보서현이 수화기를 들고 등을 돌린다)
			var mm := Clock.abs_min(host.date_text) % 60
			if mm > 0:
				host.advance_minutes(60 - mm)
		"climb":
			_climb(str(a[1]) == "trace")
			done.call()
			_go("W", "L-UG-05>from_shaft")
			return
		"caught":                                                        # 틈이 아닌데 올라갔다: 정지 명령 · 흔적(2 들킴)
			_sv("TRACE", 2)
			st.call_fn("aff", ["BJ", -5])
		"collapse":                                                      # ③ 증거 인멸: 갱이 없으면 엄태하도 할 말이 없다
			_sv("PATH", 2)
			_sol(3)
			st.call_fn("karma", [5])
			if _mid() == "NT-03":
				host.map.set_prop_state(Vector2i(53, 0), "collapsed")
		"sol":
			_sol(int(a[1]))
		"fee":
			_fee(a.size() > 1 and str(a[1]) == "haggle")
		"boom":                                                          # 차단봉을 올렸다 내린다 — 주인공이 건너편에 선다
			_sv("PASSED", v("PASSED") + 1)
			if str(a[1]) == "bribe":
				_sv("LASTFEE", v("FEE"))                                     # 다음엔 '지난번과 같은 계산' 한 줄(재미 검수 ①)
			var to := "out" if v("SIDE") == 1 else "in"
			if not host.is_inside_tree():                                # 시험(장면 트리 밖): 연출 없이 바로 건너편
				host.ev.handlers["pc"].call([to, "S" if to == "in" else "N"], _noop)
				done.call()
				return
			host.ev.run("fade_out", ["black", "4"], func() -> void:
				host.ev.handlers["pc"].call([to, "S" if to == "in" else "N"], _noop)
				host.ev.run("fade_in", ["black", "4"], func() -> void: done.call()))
			return
		"vent":                                                          # 1 조용히 · 2 뜯음 · 0 황보서현이 다시 조임 · 3 용접 봉인
			_sv("VENT", int(a[1]))
			if _mid() == "NT-01":
				host.map.set_prop_state(Vector2i(4, 14), "open" if int(a[1]) in [1, 2] else "")
		"radio":
			_sv("RADIO", int(a[1]))
			if int(a[1]) == 2:
				_sv("GAP_DAY", day())
			elif int(a[1]) == 3:
				_sv("PATROL_DAY", day())
	done.call()


## 맵 옮기기(장면이 닫힌 뒤) — 시험(장면 트리 밖)에서는 옮기지 않는다
func _go(map_id: String, mark: String) -> void:
	if host.is_inside_tree():
		host.go.call_deferred(map_id, mark)


## 다음 교대 틈 시작까지 남은 분(지금이 틈이면 0)
func _to_next_shift() -> int:
	if shift_now():
		return 0
	var m := Clock.abs_min(host.date_text) % 1440
	var best := 1440
	for s in SHIFTS:
		var dm: int = (int(s) - m + 1440) % 1440
		if dm > 0 and dm < best:
			best = dm
	return best


func _climb(trace: bool) -> void:
	_sv("USED", v("USED") + 1)
	if trace:
		_sv("TRACE", 1)                                                  # 뚜껑을 안 덮었다(재미 검수 ② — 발각의 까닭은 내가 한 일)
	elif v("LIGHT") == 2 and v("TRACE") == 0:
		_sv("TRACE", 3)                                                  # 터널이 밝아 초소가 지켜본다
	if v("USED") == 1:
		st.call_fn("xp", [25])
	_log("밀통로 통과(흔적 %d)" % v("TRACE"))


## UG-H01: 회로 범위 하나만(SA +5~+10 · BJ −5~+5, SD-09f UG-H01)
func _light(n: int) -> void:
	var was := v("LIGHT")
	_sv("LIGHT", n)
	_sv("LIGHT_DAY", day())
	match n:
		1:
			st.call_fn("aff", ["JC_SA", 5])
		2:
			st.call_fn("aff", ["JC_SA", 10 if was == 0 else 5])
			st.call_fn("aff", ["BJ", 5])
		3:
			st.call_fn("aff", ["BJ", -5])
	if was == 0:
		st.call_fn("xp", [XP_H01])
	if was == 0 and not st.is_dead(AJAE):                                # 맡긴 사람이 살아 있을 때만 그 사람 수첩 칸에(없으면 XP만)
		st.book.memo(AJAE, ["", "남태령 쪽 터널 등 — 사당 측만 켰다.", "남태령 쪽 터널 등 — 끝까지 켰다. 초소가 터널을 본다.",
			"남태령 측 선을 끊었다. 초소가 어두워졌다 — 다음 날 순찰이 터널까지."][n], host.date_text)
	if _mid() == "NT-03":                                                # 맵 안에서 바로: 회로 함 · 터널 등 그림
		host.map.set_prop_state(Vector2i(16, 0), ["", "sadang", "full", "cut"][n])
		for x in LAMPS:
			var lit: bool = n == 2 or (n == 1 and int(x) < 32)
			host.map.set_prop_state(Vector2i(x, 3), "on" if lit else "")
	_log("회로 %d" % n)


## UG-H02 매듭(1 대납 · 2 위조 · 3 붕괴 · 5 등록 보증 · 7 사진): 할매는 측실로 돌아간다
func _sol(n: int) -> void:
	_sv("SOL", n)
	if n in [1, 2]:
		_sv("PATH", 1)                                                   # 장부엔 '배수 정비' — 길은 다시 열린다(원문: 할매 생존 시 R01 남쪽 은신 우회로)
		_sv("TRACE", 0)
	_sv("HAL", 0)
	_sv("HAL_DAY", day())
	st.call_fn("xp", [XP_H02])
	if n == 1:
		st.call_fn("aff", ["BJ", -5])                                    # 밀통 방조 벌금을 대신 낸 사람으로 장부에 남는다
	if n == 7:
		st.call_fn("karma", [5])
	st.book.memo(HAL, ["", "할매 벌금을 대신 냈다 — 맨홀은 '배수 정비'. 길은 그대로.", "교대 근무표를 고쳤다 — 맨홀은 '초소 입회 정비'. 길은 그대로.",
		"갱을 무너뜨렸다. 증거가 없어 할매가 풀려났다. 길은 없다.", "", "권은서 분류관에게 보증을 서서 할매가 측실로 돌아갔다. 판자는 그대로.",
		"", "돌 사진 — 엄 하사가 할매를 그냥 보냈다. 판자는 그대로."][n], host.date_text)
	if _mid() == "NT-01":
		host.ev.handlers["refresh"].call([], _noop)
	_log("밀통로 매듭 %d" % n)


## 엄태하의 '정확한 계산'(NT_DESK 규정표 그대로): 미등록 20 · 야간(20시~) 10 · 수배 인상 30 · 동행 거부 10 · 회로 조사 20 · 우호 −10
func _fee(haggle: bool) -> void:
	_sv("SIDE", 1 if _tile().y >= 12 else 0)
	var h := int(st.vars.get_v("GAME_HOUR"))
	var fn := 1 if (h >= 18 or h < 6) else 0                            # 초소 시계는 18시부터 할증을 붙인다 — 규정은 20시(18~20시엔 화술로 깎는다)
	if (haggle or v("HAGGLED") == day()) and h >= 18 and h < 20:
		fn = 0                                                           # 그날 한 번 따져 이겼으면 그날 18~20시엔 할증 없음(실패하면 음수 날짜 — 그날은 다시 못 따진다)
	var fw := 1 if int(st.vars.get_v("V_WANTED")) >= 1 else 0
	var fr := 1 if int(st.vars.get_v("SG_REFUSED")) >= 1 else 0
	var fs := 1 if v("LIGHT") == 3 and day() <= v("LIGHT_DAY") + 7 else 0
	var fd := 1 if int(st.vars.get_v("AFF_BJ")) >= 20 else 0
	_sv("FN", fn)
	_sv("FW", fw)
	_sv("FR", fr)
	_sv("FS", fs)
	_sv("FD", fd)
	_sv("FEE", clampi(20 + 10 * fn + 30 * fw + 10 * fr + 20 * fs - 10 * fd, 10, 90))
