## 영등포 · 여의도(R02) 사이드 퀘스트 SQ-S12 「관리 요원의 유족」 진행기(단계 1-11k, SD-04a §5.5 · 구현 정합 이름 정합). 원고: script/act1/SQ-S12.txt ·
##   JM_PEOPLE.txt(진재석 · 엄수연 · 사공민영 · 염희정) · SQ-S11.txt SQS11_INJI(얼굴 알아보기) · terms/r02_market.txt(TM-J04 입점자 가족 연락부).
##   맵: Y-02 세 자리(권이준 · 강수아 · 문도하) · J-02 상호 간판 · 표식 · 내려놓는 자리 · J-03 분수 복사지 · 사공민영 벤치.
##   설계안 docs/seoul-fallout/_plans/1-11k_SQ-S12_plan.md(§4 확정안).
## 학습형: '물건을 누구 손에 두는가' — 세 가족이 바라는 것이 다르다(진재석 = 회의에서 이름 · 사공민영 = 그 달 배급표 · 엄수연 = 이름이 적힌 그것).
## 사실은 변수 한 곳(P1): 가족마다 SQ_S12_J · S · E(0 모름 · 1 앎 · 2 보여 줌 · 3 건넴 · 4 회의에 올림) · 유품 JR · SB · EW · 판매 SOLD.
## 단계는 이 진행기 한 곳에서만, 오르기만 한다(SD-20). 가족 셋 모두 자리가 정해지거나 묶음을 팔면 100.
class_name SideS12
extends Node

const KEY := {"j": "J", "s": "S", "e": "E"}
const NPC := {"j": "N-R02-005", "s": "N-R02-012", "e": "N-R02-006"}   ## 진재석 · 사공민영 · 엄수연
const BIT := {"j": 1, "s": 2, "e": 4}                                   ## SQH_IDCARD — 권이준 · 강수아 · 문도하
const ITEM := {"j": "M-412", "s": "M-413", "e": "M-414"}               ## 반지 · 10월분 배급표 묶음 · 손목시계
const ITEM_FLAG := {"j": "JR", "s": "SB", "e": "EW"}
const LAY_FLAG := {"j": "LAYJ", "s": "LAYS", "e": "LAYE"}
const BUNDLE := "M-210"
const CARDS := 12
const PRICE := 30                                                       ## 염희정 — 장당
const KNOWN_DAYS := 3                                                   ## 판 일이 알려지는 날(공개도 1)
const XP := 300
const XP_SOLD := 100                                                    ## 판매로 끝남 — 같은 '정해짐'이 아니다
const CARD_J := "M-415"                                                 ## 진재석 노점 상자 속 권이준의 신분증(한 장) — 되훔칠 수 있다
const BOX_NAME := "부품 상자"

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0

signal want_save(why: String)


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["s12"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func q(k: String) -> int:
	return int(st.vars.get_v("SQ_S12_" + k))


func _sq(k: String, n: int) -> void:
	st.vars.set_v("SQ_S12_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[유족] " + s)


func day() -> int:
	return maxi(1, v("GAME_DAY"))


func stage() -> int:
	return st.quests.stage("SQ-S12")


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage("SQ-S12", n)
		_log("단계 %d" % n)


func _has(id: String) -> bool:
	return int(st.items.get(id, 0)) > 0


# ---------------------------------------------------------------- 발동 · 따라 올림(P2)
func start(why: String) -> void:
	if v("V_ACT") < 1:
		return
	if q("START") == 0:
		_sq("START", day())
		_sq("EVID", CARDS - _given_cards())
		_log("발동(%s)" % why)
	_up(10)
	_catch_up()


## 묶음을 떠난 장 — 가족 손 · 진재석 상자 · 기다리던 자리(3). 진재석 상자에서 되훔친 장은 묶음으로 돌아온다(STOLE).
## EVID = 묶음 안에 남은 장(한 곳 — P1). 진재석 상자 속 장은 SQH_IDCARD 비트 1이 말하고, 회의 날 그가 들고 온다(MQ-502 몫)
func _given_cards() -> int:
	var n := 0
	for k in KEY:
		if q(KEY[k]) == 3:
			n += 1
	if q("J") == 3 and q("STOLE") == 1:
		n -= 1
	return n


func _catch_up() -> void:
	if q("START") == 0:
		return
	if q("LOOK") == 1:
		_up(20)
		for k in KEY:
			if q(KEY[k]) == 0:
				_sq(KEY[k], 1)
	for k in KEY:
		if q(KEY[k]) >= 1:
			_up(30)
		if q(KEY[k]) >= 2:
			_up(40)
	_check_done()


func _resolved(k: String) -> bool:
	return q(KEY[k]) >= 3


func _check_done() -> void:
	if q("DONE") == 1:
		return
	var all := q("SOLD") == 1
	if not all:
		all = true
		for k in KEY:
			if not _resolved(k):
				all = false
	if not all:
		return
	_sq("DONE", 1)
	_up(100)
	if q("SOLD") == 1:
		st.call_fn("xp", [XP_SOLD])
		host.hint("관리 요원의 유족 — 이름들은 인쇄소 뒤칸에서 지워진다.", 4.0)
	else:
		st.call_fn("xp", [XP])
		host.hint("관리 요원의 유족 — 신분증의 자리가 정해졌다.", 4.0)
	want_save.emit("s12_done")


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if q("LOOK") == 1 and q("START") == 0 and _has(BUNDLE):
		start("연락부")                                                # 단말 · 인지영이 먼저(묶음을 들고) — 따라 올림
	elif q("START") > 0:
		_catch_up()
	if q("J") == 3 and q("STOLE") == 0 and _has(CARD_J):
		_stole()


## 진재석 노점 상자에서 권이준의 장을 되훔쳤다(절도 · 목격은 엔진 범죄 규칙) — 건넸던 사실(J 3 · 비트 1)은 그대로, 장은 묶음으로
func _stole() -> void:
	_sq("STOLE", 1)
	if _has(BUNDLE):
		st.call_fn("take", [CARD_J, 1])
	st.call_fn("aff", ["JH", -2])
	_sq("EVID", CARDS - _given_cards() if q("SOLD") == 0 else 0)
	_log("상자에서 되훔침")


## 진재석 노점 상자에 그 장을 실제 물건으로 둔다(J-02에 들 때마다 — 한 번만)
func _stock_box() -> void:
	if host.map == null or host.map.id != "J-02" or q("J") != 3 or q("STOLE") == 1 or q("BOXED") == 1 or st.is_dead(NPC["j"]):
		return
	for c in host.map.boxes:
		var b: Dictionary = host.map.boxes[c]
		if str(b.get("name", "")) == BOX_NAME:
			var bx: Dictionary = host.box_contents(b)
			bx["items"][CARD_J] = 1
			_sq("BOXED", 1)
			return


# ---------------------------------------------------------------- 가족 앞에서
func show(k: String) -> void:
	start("가족")
	if q(KEY[k]) < 2:
		_sq(KEY[k], 2)
	_catch_up()


## 회의 탁자에 올리기로(해법 B) — 묶음은 그대로 · 유족이 증언자로
func keep(k: String) -> void:
	if _resolved(k):
		return
	_sq(KEY[k], 4)
	st.vars.set_v("SQE_FAMILY", 1)
	st.call_fn("karma", [15])
	st.call_fn("aff", ["JH", 2])
	if k == "j":
		_sq("REWARD", q("REWARD") | 2)                                   # 진재석 진공관 '감정' — 그 말대로 해 준 손님(재미 검수: B가 맞는 답이 숫자로도 이기게)
	_after_card()


## 누구 가족인지 알게 됨(유품 · 얼굴 · 호수) — 0일 때만 1
func know(k: String) -> void:
	start("앎")
	if q(KEY[k]) == 0:
		_sq(KEY[k], 1)
	_catch_up()


## 가족 손에(해법 A) — 그 장은 묶음에서 빠진다(회의 증거 −1) · 진재석은 노점 상자에 맡아 둔다(회의 날 들고 옴 — 되훔칠 수 있음)
func give(k: String) -> void:
	if _resolved(k):
		return
	_sq(KEY[k], 3)
	st.vars.set_v("SQH_IDCARD", v("SQH_IDCARD") | int(BIT[k]))
	st.vars.set_v("SQE_FAMILY", 1)
	st.call_fn("karma", [25])
	st.call_fn("aff", ["JH", 2])
	if k == "e":
		_sq("REWARD", q("REWARD") | 1)                                   # 엄수연 약 상시 −15%(SD-04a §5.5 보상)
	if k == "j":
		_stock_box()
	_after_card()


## 가족이 죽었다 — 기다리던 자리에 내려놓는다(건넴과 같은 자리 · 노복희가 대신 시각을 적는다)
func lay(k: String) -> void:
	if _resolved(k):
		return
	_sq(KEY[k], 3)
	_sq(LAY_FLAG[k], 1)
	st.vars.set_v("SQH_IDCARD", v("SQH_IDCARD") | int(BIT[k]))
	st.call_fn("karma", [25])
	_after_card()


func _after_card() -> void:
	_sq("EVID", CARDS - _given_cards() if q("SOLD") == 0 else 0)
	var all := true
	for kk in KEY:
		if not _resolved(kk):
			all = false
	if all and q("HINT") == 0:
		_sq("HINT", 1)
		st.call_fn("aff", ["JH", 3])                                    # 셋 모두 — 지하시장이 안다
	_catch_up()


## 유품(해법 C) — 가족마다 풍경 하나가 바뀐다
func item(k: String) -> void:
	if q(ITEM_FLAG[k]) == 1 or not _has(ITEM[k]):
		return
	st.call_fn("take", [ITEM[k], 1])
	_sq(ITEM_FLAG[k], 1)
	st.call_fn("karma", [25])
	st.call_fn("aff", ["JH", 1])
	if k == "s" and not st.is_dead(NPC["s"]):
		st.call_fn("give", ["M-003", 3])                                # '이제 필요 없어' — 사공민영이 평생 찾던 것을 넘긴다
		host.refresh_npcs()                                             # 순회를 접고 인지영 옆 벤치에 앉는다
	start("유품")


## 묶음째 판다(해법 D — 염희정 V13)
func sell() -> void:
	if q("SOLD") == 1 or not _has(BUNDLE):
		return
	var n := q("EVID") if q("START") > 0 else CARDS
	st.call_fn("take", [BUNDLE, 1])
	st.call_fn("caps", [PRICE * n])
	st.call_fn("karma", [-25])
	_sq("SOLD", 1)
	_sq("SOLD_DAY", day())
	_sq("EVID", 0)
	start("판매")


func look(why: String) -> void:
	_sq("LOOK", 1)
	_log("연락부 · 얼굴(%s)" % why)
	if _has(BUNDLE) or q("START") > 0:
		start(why)


# ---------------------------------------------------------------- 하루 · 맵
func _on_day(_d: int) -> void:
	if q("SOLD") == 1 and q("KNOWN") == 0 and day() >= q("SOLD_DAY") + KNOWN_DAYS:
		_sq("KNOWN", 1)                                                  # 인쇄소 뒤칸 일이 시장에 돈다(공개도 1)
		st.call_fn("aff", ["JH", -3])
		_log("판 일이 알려짐")


func _on_map(id: String) -> void:
	if id == "J-02":
		_stock_box()
	if not id.begins_with("J-") or v("V_ACT") < 1 or q("START") > 0 or not _has(BUNDLE):
		return
	start("지하시장")                                                  # 묶음을 들고 지하시장에 들면 자동(원문 발동)
	host.hint("셔터마다 붙은 호수 — 'A-11', 'A-13'. 신분증 묶음 뒷면 '비상 연락' 칸에도 그 호수가 있었다(살펴보기)", 6.0)


# ---------------------------------------------------------------- 명령(@cmd s12 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"start":
			start("살펴보기")
		"look":
			look(str(a[1]) if a.size() > 1 else "단말")
		"show":
			show(str(a[1]))
		"keep":
			keep(str(a[1]))
		"know":
			know(str(a[1]))
		"log":
			_sq("LOG", 1)                                                  # 엄수연에게 당직 일지 '10. 31.'을 알려 줌 — 간판 아래 분필이 늘어난다
		"give":
			give(str(a[1]))
		"lay":
			lay(str(a[1]))
		"item":
			item(str(a[1]))
		"sell":
			sell()
	done.call()
