## 영등포 · 여의도(R02) 사이드 퀘스트 SQ-S13 「제752차 개표」 진행기(단계 1-11l, SD-04a §5.6 · SD-09a L-R02-04 · SD-02 §S-02 '끝없는 선거').
## 원고: script/act1/SQ-S13.txt(볼트 장면 · 로봇 둘 · 등록부 · 기표소 · 개표 · 명부 · 유권자 일곱의 '부탁 · 도착 뒤' 장면) · 단말 terms/r02_s02.txt TM-SV04.
## 맵: maps/s02/SV-01~04(아트리움 · 개표실 · 거주 구역 · 오버시어실) · world r02.spots L-R02-04 · L-R02-12(역전 시장) · J-01(위서하).
## 설계: docs/seoul-fallout/_plans/1-11l_SQ-S13_plan.md §4 확정안 · §5 정합 · §6 구현 설계.
## 학습형 '세어 보게 한다': 유권자 다섯을 같은 6시간 창에 모으는 도착 약속 퍼즐 · 규칙(기호 등록순 · 동수 연장자)으로 표를 미리 센다 ·
##   당선의 대가 = 배급 명부(깎으면 2호가 소리 내 읽는다).
## 사실은 변수 한 곳(P1): 유권자마다 SQ_S13_V_<K>(0 모름 · 1 약속 · 2 도착 · 3 찍음 · 4 돌아감 · 9 무산/못 옴) · 약속 시각 T_<K>(절대 시각 = 날×24+시) ·
##   표 BL_<K>(후보 코드 · 0 백지 · 9 무효(2호 이름)) · 당선 WIN(코드 · 10 = 유권자 전원 · -1 당선자 없음). 단계는 이 진행기 한 곳에서만, 오르기만 한다.
class_name SideS13
extends Node

const VOTERS := {"B": "C-050", "K": "N-R02-032", "E": "N-R02-030", "T": "N-R02-019", "W": "N-R02-051", "I": "N-R02-014", "P": "N-R02-020"}
## 후보 코드: 1 주인공 · 2~8 유권자 · 9 투표함지기 2호(피선거권 없음 — 표는 무효)
const CODE := {"PC": 1, "B": 2, "K": 3, "E": 4, "T": 5, "W": 6, "I": 7, "P": 8, "R2": 9}
const NAME := {1: "당신", 2: "노복희", 3: "경상현", 4: "어하은", 5: "탁우빈", 6: "위서하", 7: "인지영", 8: "표강윤", 9: "투표함지기 2호"}
## 동수면 연장자(2104 개정 — 규칙 2): 출생 연도. 구울은 2077년생 셈(2077년의 나이대 · SD-07b) — 주인공은 볼트 2258년생
const BORN := {1: 2258, 2: 2023, 3: 2044, 4: 2054, 5: 2235, 6: 2254, 7: 2015, 8: 2244}
const HOUR := {"B": 22, "K": 18, "E": 19, "T": 14, "W": 15, "I": 22, "P": 13}     ## 약속 기본 시각(사정 — 원고가 앞당긴 시각을 넘긴다)
const JH := ["B", "I"]                                                           ## 판도 JH(SD-07b 소속 열) — 경상현 · 어하은 · 탁우빈 · 표강윤은 MS, 위서하는 DG(두 판도 변수는 아직 없다)
const WINDOW_H := 6                                                              ## 첫 도착부터 6시간(원문 — 모인 유권자는 6시간 안에 투표 못 하면 돌아간다)
const NEED := 5
const XP := 450
## 칸막이에서 나오는 모습(계획 §4 — 사람마다 다르게)
const BOOTH_LINE := {"B": "노복희가 칸막이 안을 한 바퀴 더듬는다 — 도청기부터. 그리고 도장을 꾹.", "K": "경상현이 나오며 중얼댄다. \"시세 확인했어요.\"",
	"E": "어하은이 투표함 앞에서 고개를 깊이 숙이고 용지를 넣는다.", "T": "탁우빈이 용지를 반으로 접어 투입구에 탁 넣는다. \"한 장은 한 장이지.\"",
	"W": "위서하가 도장을 찍기 전에 손을 한 번 닦는다. 버릇이다.", "I": "인지영이 칸막이 안에서 오래 있다. 이름을 소리 내지 않고 읽는 입 모양.",
	"P": "표강윤이 나오며 손가락으로 총 쏘는 시늉을 한다. \"한 발.\""}
const LOOT := {"M-014": 10, "M-019": 4, "M-002": 50}                              ## 선거 비축 창고(원문) — 점프슈트 A-003(S-02)은 따로

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _seq: Array = []                                                             ## 투표 연출 줄(남은 유권자) — 칸막이 하나씩
var _seq_t := 0.0

signal want_save(why: String)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s13"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func q(k: String) -> int:
	return int(st.vars.get_v("SQ_S13_" + k))


func _sq(k: String, n: int) -> void:
	st.vars.set_v("SQ_S13_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[개표] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func now_h() -> int:
	return day() * 24 + v("GAME_HOUR")


func stage() -> int:
	return st.quests.stage("SQ-S13")


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S13", n)
		_log("단계 %d" % n)


func _refresh() -> void:
	if host.map != null and not host.box.active and not host.ev.busy():
		host.refresh_npcs()


# ---------------------------------------------------------------- 발동 · 안전 · 2호
func start() -> void:
	if q("START") == 0:
		_sq("START", day())
		_log("발동")
	_up(10)


## 아트리움의 야생 구울 — 다 쓰러졌거나(이 맵에 머무는 동안 센다) 2호 방송으로 거주 구역에 유인했으면 안전
func _check_safe() -> void:
	if q("SAFE") == 1 or host.map == null or host.map.id != "SV-01":
		return
	var alive := 0
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-200":
			alive += 1
	if alive == 0:
		_sq("SAFE", 1)
		_up(20)
		host.hint("아트리움이 조용해졌다. 투표함지기 2호의 방송만 남았다.", 4.0)


func lure() -> void:
	_sq("LURE", 1)
	_sq("SAFE", 1)
	_up(20)
	if q("MET2") == 1:
		_up(30)
	_refresh()


func met() -> void:
	start()
	_sq("MET2", 1)
	if q("SAFE") == 1:
		_up(30)


# ---------------------------------------------------------------- 유권자: 약속 · 도착 · 창
func ask(k: String, hour: int) -> void:
	if st.is_dead(VOTERS[k]) or q("V_" + k) in [1, 2, 3]:
		return
	var h := v("GAME_HOUR")
	var t := day() * 24 + hour if hour > h else (day() + 1) * 24 + hour
	_sq("T_" + k, t)
	_sq("V_" + k, 1)
	_log("약속 %s %d시(절대 %d)" % [k, hour, t])


func _arrivals() -> void:
	var n := now_h()
	var changed := false
	for k in VOTERS:
		if q("V_" + k) != 1 or n < q("T_" + k):
			continue
		if st.is_dead(VOTERS[k]):
			_sq("V_" + k, 9)
			continue
		_sq("V_" + k, 2)
		changed = true
		if q("OPEN") == 0 or q("T_" + k) < q("OPEN"):
			_sq("OPEN", q("T_" + k))                                   # 창은 가장 먼저 온 사람부터(시간 도약으로 한꺼번에 와도 — P6)
		_log("도착 %s" % k)
	if q("HERE") != present():
		_sq("HERE", present())                                         # 원고가 읽는 '지금 아트리움의 유권자 수'(변수 한 곳 — present()를 그대로 옮김)
	if present() >= NEED:
		_up(50)
	# 창: 첫 도착 + 6시간 안에 투표가 시작되지 않으면 모였던 사람은 돌아간다(무산 · 칠판 · 다시 부탁은 쉬움)
	if q("OPEN") > 0 and q("VOTING") <= 1 and q("CAST") == 0 and n > q("OPEN") + WINDOW_H:   # 투표를 열어 놓고 주인공이 기표소에 안 들어가도 같다(재미 검수 — 제15조)
		var snub := q("VOTING") == 1
		_sq("VOTING", 0)
		for k in VOTERS:
			if q("V_" + k) == 2:
				_sq("V_" + k, 9)
				_sq("EASY_" + k, 0 if snub else 1)                       # 볼트 양반이 안 찍어서 무산이면 다시 부탁이 쉬워지지 않는다
		_sq("OPEN", 0)
		if snub:
			host.hint("투표함지기 2호: \"관리자님 기표 대기 6시간. 제15조 — 제752차 무산.\"", 4.0)
		_sq("BOARD", 1)
		_sq("FAILS", q("FAILS") + 1)
		changed = true
		_log("무산")
		want_save.emit("s13_fail")
	if changed:
		_refresh()


func present() -> int:
	var c := 0
	for k in VOTERS:
		if q("V_" + k) == 2 or q("V_" + k) == 3:
			c += 1
	return c


# ---------------------------------------------------------------- 후보 등록(기호 = 등록순, 규칙 1)
func reg(code: int) -> void:
	if code == 9:
		return                                                        # 2호는 피선거권이 없다(원고가 거절 대사)
	for i in [1, 2, 3]:
		if q("C%d" % i) == code:
			return
	for i in [1, 2, 3]:
		if q("C%d" % i) == 0:
			_sq("C%d" % i, code)
			_up(40)
			_log("등록 기호 %d = %s" % [i, NAME[code]])
			return


func show_reg() -> void:
	var parts := []
	for i in [1, 2, 3]:
		var c := q("C%d" % i)
		parts.append("기호 %d %s" % [i, NAME.get(c, "(빈칸)") if c > 0 else "(빈칸)"])
	host.hint(" · ".join(parts), 5.0)


## 2호의 사전 등록 명부(재미 검수 — 약속을 확인할 곳): 약속한 사람의 날 · 시각 · 도착 · 창 남은 시간
func roster() -> void:
	var parts := []
	for k in VOTERS:
		var vk := q("V_" + k)
		if vk == 1:
			var t := q("T_" + k)
			parts.append("%s %d일 %d시" % [NAME[CODE[k]], t / 24, t % 24])
		elif vk == 2:
			parts.append("%s(도착)" % NAME[CODE[k]])
	if parts.is_empty():
		host.hint("투표함지기 2호: \"사전 등록 유권자 없음.\"", 4.0)
		return
	var tail := ""
	if q("OPEN") > 0:
		tail = " · 마감까지 %d시간" % maxi(0, q("OPEN") + WINDOW_H - now_h())
	host.hint(" · ".join(parts) + tail, 6.0)


func _registered(code: int) -> bool:
	for i in [1, 2, 3]:
		if q("C%d" % i) == code:
			return true
	return false


# ---------------------------------------------------------------- 투표
## 2호 "투표를 시작합니다" — 다섯 이상 · 후보 하나 이상. 주인공이 기표소에서 먼저 찍으면 유권자가 차례로 칸막이에 든다
func begin() -> void:
	if present() < NEED or q("C1") == 0 or q("VOTING") != 0 or q("OFF") != 0:
		return
	_sq("VOTING", 1)
	_log("투표 시작")


## 주인공 한 표(code: 후보 코드 · 0 백지 · 9 2호 이름 = 무효)
func pc_vote(code: int) -> void:
	if q("VOTING") != 1 or q("PCV") != 0:
		return
	_sq("PCV", 100 + code)                                             # 100 + 코드(0도 '찍었음'이 되게)
	_sq("CAST", q("CAST") + 1)
	if code == 9:
		_sq("INVALID", q("INVALID") + 1)
	_seq = []
	for k in VOTERS:
		if q("V_" + k) == 2:
			_seq.append(k)
	_seq_t = 0.0


## 유권자 한 명의 표 — 칸막이에서 나오는 순간 확정(P10: 불러와도 같은 사람은 같은 표)
func ballot(k: String) -> int:
	if q("TWO_" + k) == 1:
		return 9                                                       # 2호 이름을 써 달라는 부탁을 받아들임
	if q("ASK_" + k) == 1 and _registered(1):
		return 1                                                       # [화술] 부탁 — 주인공에게
	match k:
		"K":                                                           # 경상현: 기호 1번(누구든 — '반등'을 찾는다) · '1번은 반등이 아니에요'라고 정직하게 말하면 백지(원문 대사)
			return 0 if q("LIE") == 2 else q("C1")
		"B":                                                           # 노복희: 상인회 — 자기 · 상인회 단골인 주인공 · 아니면 백지
			if _registered(2):
				return 2
			return 1 if v("JM_REG") == 1 and _registered(1) else 0
		"T":                                                           # 탁우빈: 시장 사람 — 자기 · 아니면 백지
			return 5 if _registered(5) else 0
		"E":                                                           # 어하은: 안내를 끝까지 들어 준 사람
			return 1 if q("HEARD_E") == 1 and _registered(1) else (4 if _registered(4) else 0)
		"W":                                                           # 위서하: 지상 · 지하 어느 쪽도 빼지 않는 사람(명부를 똑같이 적겠다는 약속)
			return 1 if q("PROMISE") == 1 and _registered(1) else (6 if _registered(6) else 0)
		"I":                                                           # 인지영: 토요일에 이름을 같이 읽은 사람 · 아니면 노복희
			if v("SQ_S11_READ") != 0 and _registered(1):
				return 1
			return 2 if _registered(2) else (7 if _registered(7) else 0)
		"P":                                                           # 표강윤: 자기 · 아니면 백지
			return 8 if _registered(8) else 0
	return 0


func _vote_tick(dt: float) -> void:
	if q("VOTING") != 1 or q("PCV") == 0:
		return
	_seq_t += dt
	if _seq.is_empty():
		if q("BOOTH") != 0:
			_sq("BOOTH", 0)
			_refresh()
		return
	var k: String = _seq[0]
	var slot := 1 + (q("CAST") % 5)
	if q("BOOTH") == 0 and _seq_t > 0.6:
		_sq("BOOTH", slot)                                             # 칸막이가 닫히고 발이 보인다
		_refresh()
	elif q("BOOTH") != 0 and _seq_t > 2.2:
		var b := ballot(k)
		_sq("BL_" + k, b)
		_sq("V_" + k, 3)
		_sq("CAST", q("CAST") + 1)
		if b == 9:
			_sq("INVALID", q("INVALID") + 1)
		_sq("BOOTH", 0)
		_seq.pop_front()
		_seq_t = 0.0
		_log("표 %s → %d" % [k, b])
		host.hint(BOOTH_LINE[k], 3.0)
		if _seq.is_empty():
			_sq("VOTING", 2)                                           # 다 찍었다 — 개표실로(4호가 셈한다 · 그 사이 개표기를 만질 수 있다)
			host.hint("투표함지기 2호: \"투표를 마감합니다. 개표는 개표실에서.\"", 4.0)
		_refresh()


## 표를 센다(동수 → 연장자). 반환: 당선 코드 · -1 당선자 없음 · 10 유권자 전원(유효표 0 · 다섯 모두 2호 이름)
func tally() -> int:
	var votes := {}
	var valid := 0
	var all_two := true
	var pcv := q("PCV") - 100
	var ballots := [pcv]
	for k in VOTERS:
		if q("V_" + k) == 3:
			ballots.append(q("BL_" + k))
			if q("BL_" + k) != 9:
				all_two = false
	for b in ballots:
		if b >= 1 and b <= 8:
			votes[b] = int(votes.get(b, 0)) + 1
			valid += 1
	for i in [1, 2, 3]:
		_sq("N%d" % i, int(votes.get(q("C%d" % i), 0)))                 # 4호 발표용 기호별 표 수
	_sq("NB", ballots.count(0))
	if valid == 0:
		return 10 if all_two and ballots.size() > NEED else -1
	var best := -1
	var top := -1
	for c in votes:
		var n: int = votes[c]
		if n > top or (n == top and BORN.get(c, 9999) < BORN.get(best, 9999)):
			best = c
			top = n
	return best


## 4호 개표 발표(SQS13_RESULT 원고가 부른다)
func count() -> void:
	if q("VOTING") != 2:
		return                                                         # 부정(FRAUD 1)이면 WIN이 이미 섰다 — 숫자 창을 그대로 발표
	if q("FRAUD") == 0:
		_sq("WIN", tally())
	_sq("VOTING", 3)
	var all := true
	for k in VOTERS:
		if q("V_" + k) == 2:
			all = false
	_sq("TURN", 1 if all and q("FRAUD") == 0 else 0)
	_up(60)
	if q("TURN") == 1:
		_sq("BOARD", 2)                                                # 실험 종료 조건 — 표준 헌장(임기 4년)
	else:
		_sq("BOARD", 3)
	_log("개표 당선 %d" % q("WIN"))
	want_save.emit("s13_count")


## 당선자 없음(유효표 0 · 2호 이름이 다섯이 아님) — 제752차를 다시 공고한다. 반쯤 된 상태 없음(P10): 이번 회차 칸을 모두 비운다
func again() -> void:
	if q("WIN") != -1:
		return
	for k in VOTERS:
		if q("V_" + k) in [2, 3]:
			_sq("V_" + k, 9)
			_sq("EASY_" + k, 1)
		for f in ["BL_", "ASK_", "TWO_"]:
			_sq(f + k, 0)
	for f in ["C1", "C2", "C3", "VOTING", "CAST", "PCV", "WIN", "TURN", "OPEN", "INVALID", "N1", "N2", "N3", "NB", "BOOTH", "LIE", "PROMISE"]:
		_sq(f, 0)
	_sq("HERE", 0)
	_sq("BOARD", 1)
	_sq("FAILS", q("FAILS") + 1)
	_refresh()
	want_save.emit("s13_again")


# ---------------------------------------------------------------- 해법 B · C
## 개표기 [과학 50]: 숫자 창을 바꿔 당선자를 정한다(남을 위해서도) — 투표가 끝나고 발표 전
func fraud(code: int) -> void:
	if q("VOTING") != 2 or q("FRAUD") != 0:
		return
	_sq("FRAUD", 1)
	_sq("WIN", code)
	_sq("FRAUD_DAY", day())
	st.call_fn("karma", [-50])


## 유권자 없이 등록부 · 투표함 위조 [과학 75] — 주인공 당선 · 투표율 100%가 아니라 실험은 계속(제753차)
func forge() -> void:
	if q("CAST") != 0 or q("WIN") != 0 or not _registered(1):
		return
	_sq("FRAUD", 2)
	_sq("WIN", 1)
	_sq("VOTING", 3)
	_sq("TURN", 0)
	_sq("BOARD", 3)
	_sq("FRAUD_DAY", day())
	st.call_fn("karma", [-50])
	_up(60)


## 로봇 끄기: 선거 전(OFF 1 — 창고 잠김 · 진공관 ×8) · 선거 뒤(OFF 2 — 4호가 스스로 진공관을 내준다)
func off() -> void:
	if q("OFF") != 0:
		return
	_sq("OFF", 2 if q("VOTING") == 3 else 1)
	st.call_fn("give", ["M-014", 8])
	_refresh()
	if q("OFF") == 1 and q("DONE") == 0:
		_finish("끔")


# ---------------------------------------------------------------- 결과: 열쇠 · 명부 · 창고
## 명부: 주인공을 안 찍은 유권자의 몫(0 그대로 · 1 −10% · 2 0)
func cut(k: String, n: int) -> void:
	_sq("CUT_" + k, n)


func roll_done() -> void:
	if q("ROLL") == 1 or q("WIN") != 1:
		return
	_sq("ROLL", 1)
	st.call_fn("give", ["M-417", 1])                                   # 당선 오버시어 열쇠(주인공 당선일 때만 손에 남는다)
	var sk := "SV-04:24,16@%d" % st.year()                              # 오버시어 금고 — 비어 있는 채로 주인공의 보관 자리 후보(삼으면 털림 판정 · UQ-125)
	if not st.boxes.has(sk):
		st.boxes[sk] = {"items": {}, "opened": 0, "taken": 0}
	var cuts := 0
	for k in VOTERS:
		if q("CUT_" + k) > 0:
			cuts += 1
	_sq("CUTS", cuts)
	var fair := q("FRAUD") == 0                                         # 부정 · 위조 당선이면 명부 카르마는 없다(부정 −50은 이미)
	if cuts == 0:
		_sq("PLEDGE", _pc_number())
		if fair:
			st.call_fn("karma", [75])
	else:
		if fair:
			st.call_fn("karma", [75 - 15 * cuts])                         # 명부를 깎을수록 — 2호가 소리 내 읽는다(볼트 방송 · 소문)
		for k in JH:
			if q("CUT_" + k) > 0:
				st.call_fn("aff", ["JH", -2])
	open_vault(0.5 + 0.1 * cuts if q("FRAUD") == 0 else 1.0)


func _pc_number() -> int:
	for i in [1, 2, 3]:
		if q("C%d" % i) == 1:
			return i
	return 0


## NPC 당선 — 열쇠는 그 사람에게 · 창고는 공동체에 · 주인공에게 절반 사례
func hand_key() -> void:
	var w := q("WIN")
	if w < 2 or w > 8 or q("LOOT") != 0:
		return
	st.call_fn("karma", [75 if q("FRAUD") == 0 else 0])
	if w in [2, 7]:                                                   # 노복희 · 인지영(JH) — 다른 판도는 변수가 생기면(이월)
		st.call_fn("aff", ["JH", 6])
	_sq("PLEDGE", _number_of(w))
	open_vault(0.5)


func _number_of(code: int) -> int:
	for i in [1, 2, 3]:
		if q("C%d" % i) == code:
			return i
	return 0


## 유권자 전원(해법 D) — 공동 관리 · 주인공 몫 1/6
func share_all() -> void:
	if q("WIN") != 10 or q("LOOT") != 0:
		return
	st.call_fn("karma", [50])
	open_vault(1.0 / 6.0)


func open_vault(frac: float) -> void:
	if q("LOOT") != 0:
		return
	_sq("LOOT", 1)
	for id in LOOT:
		var n := int(round(LOOT[id] * frac))
		if n > 0:
			st.call_fn("give", [id, n])
	st.call_fn("give", ["A-003", 1])                                   # 서울 볼트 점프슈트(S-02 번호판)
	if host.map != null and host.map.id == "SV-04":
		st.boxes["door:SV-04:14,13"] = {"open": true}
		host.map.unlock_door(14, 13)
	_finish("창고")


## 끈 · 위조 없이 창고 문을 억지로 연 경우(자물쇠 100 · 과학 75) — 2호가 켜져 있으면 '공금 횡령' 방송
func break_vault() -> void:
	if q("LOOT") != 0:
		return
	if q("OFF") == 0:
		st.call_fn("karma", [-25])
	_sq("LOOT", 2)
	if host.map != null and host.map.id == "SV-04":
		st.boxes["door:SV-04:14,13"] = {"open": true}
		host.map.unlock_door(14, 13)
	for id in LOOT:
		st.call_fn("give", [id, LOOT[id]])
	st.call_fn("give", ["A-003", 1])
	_finish("억지로")


func _finish(why: String) -> void:
	if q("DONE") == 1:
		return
	_sq("DONE", 1)
	_up(100)
	st.call_fn("xp", [XP if why != "끔" and why != "억지로" else XP / 3])
	for k in VOTERS:
		if q("V_" + k) == 2 or q("V_" + k) == 3:
			_sq("V_" + k, 4)                                           # 각자 집으로(일시 동행 아님 — 따라다니지 않는다)
	_refresh()
	_log("끝(%s)" % why)
	want_save.emit("s13_done")


# ---------------------------------------------------------------- 하루 · 맵 · 매 틱
func _on_day(_d: int) -> void:
	if q("FRAUD") == 1 and q("KNOWN") == 0:
		_sq("PILE", q("PILE") + 1)                                     # 4호가 날마다 '재검표 요구' 한 장
		if day() >= q("FRAUD_DAY") + 3:
			_sq("KNOWN", 1)                                            # 공개도 1 — 유권자 공동체가 결과를 의심
			st.call_fn("aff", ["JH", -3])
			_log("부정 알려짐")


func _on_map(id: String) -> void:
	if id.begins_with("SV-"):
		start()
		if id == "SV-04" and q("LOOT") != 0:
			st.boxes["door:SV-04:14,13"] = {"open": true}


func _process(dt: float) -> void:
	_vote_tick(dt)
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if q("START") == 0 and q("V_B") == 0 and q("V_T") == 0:
		return
	if q("OFF") == 0 and (st.is_dead("N-R02-028") or st.is_dead("N-R02-029")):
		off()                                                          # 부순 로봇은 끈 것과 같다(해법 C — 잔해에서 진공관 ×8 · 고칠 수 없음)
	_check_safe()
	_arrivals()
	if q("SAFE") == 1 and q("MET2") == 1:
		_up(30)


# ---------------------------------------------------------------- 명령(@cmd s13 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"start":
			start()
		"met":
			met()
		"lure":
			lure()
		"ask":
			ask(str(a[1]), int(a[2]))
		"reg":
			reg(int(a[1]))
		"show_reg":
			show_reg()
		"begin":
			begin()
		"vote":
			pc_vote(int(a[1]))
		"plead":                                                      # [화술] 부탁 성공 — 그 유권자는 주인공에게
			_sq("ASK_" + str(a[1]), 1)
		"two":                                                        # 2호 이름을 써 달라는 부탁 성공
			_sq("TWO_" + str(a[1]), 1)
		"heard":
			_sq("HEARD_" + str(a[1]), 1)
		"promise":
			_sq("PROMISE", 1)
		"lie":                                                        # 경상현 '1번이 반등이에요?' — 1 거짓 '네' · 2 정직 '아니요'(백지)
			_sq("LIE", int(a[1]) if a.size() > 1 else 1)
		"rule":
			_sq("RULE", q("RULE") | int(a[1]))
		"count":
			count()
		"fraud":
			fraud(int(a[1]))
		"forge":
			forge()
		"off":
			off()
		"cut":
			cut(str(a[1]), int(a[2]))
		"roll":
			roll_done()
		"key":
			hand_key()
		"all":
			share_all()
		"break":
			break_vault()
		"voteno":                                                     # 기표소: 기호 n번(등록순 칸 → 후보 코드)
			pc_vote(q("C%d" % int(a[1])))
		"fraudno":                                                    # 개표기: 기호 n번이 이기게
			fraud(q("C%d" % int(a[1])))
		"regk":                                                       # 등록부: 아트리움의 유권자(코드 이름)
			reg(CODE[str(a[1])])
		"auth":                                                       # [관리자 인증] 임명 — 거절 · 수배도 +3(원문)
			st.call_fn("wanted", [3, "auth"])
			_sq("AUTH", 1)
		"card":                                                       # 유권자 등록증(처음 · 잃었으면 재발급)
			if int(st.call_fn("has", ["M-416"])) == 0:
				st.call_fn("give", ["M-416", 1])
			_sq("CARD", 1)
		"nom":                                                        # 2호를 후보로 추천(거절 — 처음 받아 보는 추천)
			_sq("NOM", 1)
		"again":
			again()
		"roster":
			roster()
		"orphan":                                                     # 당선자가 열쇠를 받기 전에 죽음 — 공동 관리 · 주인공 몫 1/6(P3)
			if q("LOOT") == 0:
				open_vault(1.0 / 6.0)
		"said":
			_sq("SAID_" + str(a[1]), 1)
		"susp":
			_sq("SUSP_" + str(a[1]), 1)
	done.call()
