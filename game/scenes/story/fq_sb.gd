## 세력 퀘스트 FQ-SB-01 「출근부」 · FQ-SB-02 「현장 운송」 진행기(단계 1-12f, SD-04d §6.3 · §6.4). 원고: script/act1/FQ-SB-01.txt · FQ-SB-02.txt ·
## MQ-105.txt X-SB_BOARD(쪽지). 계획 docs/seoul-fallout/_plans/1-12f_FQ-SB-01-02_plan.md §4 · §5 · §6.
## SB-01 — 구만호가 있는 곳은 FQ_SB01_WHERE 한 곳(P3): 0 2층 실장실 · 1 1층 출근부실 감독 책상(일이 걸려 있는 동안) · 2 마당(04~06시 인력시장 · 꼬드김 30분).
##   자리를 비움(AWAY)은 WHERE != 1 또는 구만호 사망. 빼기는 2쪽을 연 순간의 AWAY로 한 번 정한다(대화 · 서류 중엔 시계가 멈춘다).
##   발각 판정은 받은 날(SEED) 씨앗 하나 — 불러오기 · 날 바꾸기로 다시 굴릴 수 없다. 넷 넘게 빼면 40% · 하나~셋 20% · 도장 15% · 꼬드기다 실패(SUS) +10%p.
##   결과 RES 1 그대로 · 2 뺌/완납 안 들킴 · 3 발각 뒤 다시 침 · 4 발각 뒤 대납 — 봉천 배수는 Encounters.sb01_bc가 이 값만 읽는다.
##   3쪽 날짜(DUE — 낸 날의 다음 달 3일)에 봉천 X-BC 남긴 이름 집 앞에 추심원(맵 cond) · 뺀 사람은 사흘 안 첫 말에 한 줄(원고 FQSB01_THX*).
class_name FqSb
extends Node

signal want_save(why: String)

const Q1 := "FQ-SB-01"
const Q2 := "FQ-SB-02"
const GU := "C-049"                                                      ## 실장 구만호
const HDC := "C-013"                                                     ## 소장 황두칠
const DOK := "C-021"                                                     ## 추심원 독사(소장 승계)
const LURE_MIN := 30                                                     ## 꼬드김: 마당에서 손님을 찾는 시간(게임 분)

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _want_pick := false                                                  ## 도장 서랍 자물쇠 — 대화가 닫히면 연다
var _pass := []                                                          ## [인물, 지난 장면, 이름표] — 대화가 닫히면 같은 사람 다음 장면


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["sb01"] = _cmd1
	host.map_entered.connect(_on_map)


func v1(k: String) -> int:
	return int(st.vars.get_v("FQ_SB01_" + k))


func _s1(k: String, n: int) -> void:
	st.vars.set_v("FQ_SB01_" + k, n)


func gv(k: String) -> int:
	return int(st.vars.get_v(k)) if st.vars.has(k) else 0


func _log(s: String) -> void:
	if log_on:
		print("[출근부·운송] " + s)


func day() -> int:
	return maxi(1, gv("GAME_DAY"))


func now() -> int:
	return Clock.abs_min(host.date_text)


func stage1() -> int:
	return st.quests.stage(Q1)


func _up1(n: int) -> void:
	var s := stage1()
	if s < n and s < 100:
		st.quests.set_stage(Q1, n)
		_log("SB-01 단계 %d" % n)


func _paused() -> bool:
	return host.busy or host.ev.busy() or (host.box != null and host.box.active) or host.lockpick != null


func _map_id() -> String:
	return str(host.map.id) if host.map != null else ""


# ---------------------------------------------------------------- 시간
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	tick(_t)
	_t = 0.0


func tick(_dt := 0.5) -> void:
	_where_tick()
	var s := stage1()
	if s >= 10 and s < 100 and (gv("SB_RAID") != 0 or gv("AFF_SB") <= -60 or (st.is_dead(GU) and st.is_dead(HDC) and st.is_dead(DOK))):
		_cut1()
	if _paused():
		return
	if _want_pick:
		_want_pick = false
		host.open_lock(25, "pad", func() -> void:
			_s1("DRAWER", 1)
			host.play_scene("FQSB01_DRAWER", "OPEN"))
	if not _pass.is_empty():
		var p: Array = _pass
		_pass = []
		talk_next(str(p[0]), str(p[1]), str(p[2]))


## 구만호 자리(P3) — 한 값을 세 맵이 읽는다. 바뀌면 지금 맵 사람을 다시 세운다
func where_now() -> int:
	var h := gv("GAME_HOUR")
	if h >= 4 and h < 6:
		return 2
	var s := stage1()
	if s >= 10 and s < 100:
		if h == 12:
			return 0
		if now() < v1("LURE"):
			return 2
		return 1
	return 0


func _where_tick() -> void:
	var w := where_now()
	var away := 1 if w != 1 or st.is_dead(GU) else 0
	var moved := w != v1("WHERE")
	_s1("WHERE", w)
	_s1("AWAY", away)
	if moved and _map_id() in ["H-02", "H-04", "X-SB"] and not _paused():
		host.refresh_npcs()


func _on_map(_id: String) -> void:
	_where_tick()


## 같은 사람의 다음 장면(장면 색인은 ID 정렬 — FQSB01_* 장면이 앞을 가린다, 계획 §4.4)
func talk_next(npc: String, after: String, label: String = "") -> void:
	var list: Array = host.scenes_by_npc.get(npc, [])
	var seen := false
	for g in list:
		if not seen:
			seen = str(g.get("id", "")) == after
			continue
		var cond := str(g.get("cond", ""))
		if cond == "" or StoryExpr.test(cond, st):
			var lb := label if label != "" and (g.get("labels", {}) as Dictionary).has(label) else "START"
			host.box.open(st, g, lb)
			return


# ---------------------------------------------------------------- SB-01 명령
func _cmd1(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"take":                                                           # 받음(1 구만호 · 2 황두칠 · 3 독사)
			if stage1() == 0:
				_s1("SEED", day())
				_s1("WHO", int(a[1]) if a.size() > 1 else 1)
				_up1(10)
				_where_tick()
				want_save.emit("sb01")
				_log("출근부 받음")
		"page":                                                           # 쪽 하나 끝 — 게임 1시간
			var n := int(a[1]) if a.size() > 1 else 1
			if n == 1:
				_s1("TYPED", maxi(v1("TYPED"), 1))
				_up1(20)
			elif n == 2:
				_s1("TYPED", maxi(v1("TYPED"), 2))
				_up1(30)
			else:
				_s1("TYPED", 3)
			host.advance_minutes(60)
			_where_tick()
			_log("%d쪽 끝" % n)
		"pick":
			_want_pick = true
		"lure":                                                           # [화술] 꼬드기기 — 하루 한 번
			_s1("LURE_DAY", day())
			if a.size() > 1 and int(a[1]) == 1:
				_s1("LURE", now() + LURE_MIN)
			else:
				_s1("SUS", 1)
			_where_tick()
		"submit":
			submit()
		"payoff":
			payoff()
		"retype":
			retype()
		"convoy":
			st.vars.set_v("FQ_SB02_TOLD", 1)
		"told":                                                           # 조만석에게 — BC +8 · 공개도 1(봉천)
			if v1("TOLD") == 0:
				_s1("TOLD", 1)
				st.call_fn("aff", ["BC", 8])
				st.deeds.record(st, "faction", "R01", 1, {}, now(), {"tag": "FQSB01_TOLD", "place": "BC",
					"what": "누군가 새벽인력 출근부에서 봉천 이름을 뺐다고 이장이 들었다", "seen_by": ["BC"], "about": []})
		"thx":
			if a.size() > 1:
				_s1("THX" + str(a[1]), 1)
		"pass":                                                           # 같은 사람 다음 장면(이 장면 ID · 이름표)
			if a.size() > 1:
				_pass = [_npc_of(str(a[1])), str(a[1]), str(a[2]) if a.size() > 2 else ""]
	done.call()


func _npc_of(scene_id: String) -> String:
	for npc in host.scenes_by_npc.keys():
		for g in host.scenes_by_npc[npc]:
			if str(g.get("id", "")) == scene_id:
				return str(npc)
	return ""


## 뺀 줄 수 · 도장 · 빚 합
func removed() -> int:
	var n := 0
	for l in LedgerCopy.LINES:
		n += v1("X" + str(l[0]))
	return n


func owe() -> int:
	var n := 0
	for l in LedgerCopy.LINES:
		if v1("X" + str(l[0])) == 1 or v1("PD" + str(l[0])) == 1:
			n += int(l[3])
	return n


## 발각 확률(계획 §4.2 · §6)
func catch_p() -> float:
	var n := removed()
	var a := 0.4 if n >= 4 else (0.2 if n >= 1 else 0.0)
	var b := 0.15 if v1("STAMP") == 1 else 0.0
	var p := 1.0 - (1.0 - a) * (1.0 - b)
	if p > 0.0 and v1("SUS") == 1:
		p += 0.1
	return p


func caught() -> bool:
	var p := catch_p()
	return p > 0.0 and Speech.roll(st.check_seed, "FQSB01_%d" % v1("SEED")) < p


func submit() -> void:
	if v1("TYPED") < 3 or stage1() >= 100 or v1("RES") != 0:
		return
	if caught():
		_s1("RES", 3)                                                     # 갈래(다시 침 · 대납)를 고를 때까지 3 — 고르면 굳는다
		_s1("OWE", owe())
		_log("발각(뺀 줄 %d · 도장 %d)" % [removed(), v1("STAMP")])
		return
	_s1("RES", 2 if removed() > 0 or v1("STAMP") == 1 else 1)
	_finish(true)


func payoff() -> void:
	if v1("RES") != 3 or stage1() >= 100:
		return
	var n := v1("OWE")
	if gv("PC_CAPS") < n:
		return
	st.call_fn("caps", [-n])
	for l in LedgerCopy.LINES:
		var t := str(l[0])
		if v1("X" + t) == 1:
			_s1("X" + t, 0)
			_s1("PD" + t, 1)                                              # 빚을 산 줄 = '완납'(MQ-504 연계 비트와 같다)
	_s1("STAMP", 1)
	_s1("RES", 4)
	_finish(true)


func retype() -> void:
	if v1("RES") != 3 or stage1() >= 100:
		return
	for l in LedgerCopy.LINES:
		_s1("X" + str(l[0]), 0)
		_s1("PD" + str(l[0]), 0)                                          # 도장 줄도 빨간펜이 '미수'로 되돌린다
	_s1("STAMP", 0)
	_finish(false)


## 끝: 250 XP · 일당 100(발각 뒤 다시 침은 몰수) · SB +6(연동 JC −3 · YH −1 · JH −1 · KD −1) 또는 −5 · 추심 날
func _finish(paid: bool) -> void:
	st.call_fn("xp", [250])
	if paid:
		st.call_fn("caps", [100])
		st.call_fn("aff", ["SB", 6])
		st.call_fn("aff", ["JC", -3])
		st.call_fn("aff", ["YH", -1])
		st.call_fn("aff", ["JH", -1])
		st.call_fn("aff", ["KD", -1])
	else:
		st.call_fn("aff", ["SB", -5])
	_set_due()
	st.deeds.record(st, "faction", "R02", 0, {}, now(), {"tag": "FQSB01_DONE", "place": "SB", "what": "본소 출근부가 새 장부로 옮겨졌다", "seen_by": ["SB"], "about": []})
	st.quests.set_stage(Q1, 100)
	_where_tick()
	want_save.emit("sb01")
	_log("출근부 끝 RES %d" % v1("RES"))


## 3쪽 '다음 달 3일'(낸 날 기준) → GAME_DAY · 월 · 일
func _set_due() -> void:
	var t := Clock.parse(host.date_text)
	if t.is_empty():
		return
	var m := int(t[1]) + 1
	var y := int(t[0])
	if m > 12:
		m = 1
		y += 1
	var target := Clock.abs_min("%d. %02d. 03.  08:00" % [y, m]) / 1440
	_s1("DUE", day() + target - now() / 1440)
	_s1("DUE_M", m)
	_s1("DUE_D", 3)


func _cut1() -> void:
	if stage1() >= 10 and stage1() < 100:
		st.quests.set_stage(Q1, 200)
		_log("출근부 끊김")
