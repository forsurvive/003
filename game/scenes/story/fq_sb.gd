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
	host.ev.handlers["sb02"] = _cmd2
	host.map_entered.connect(_on_map)
	host.interact_pre.append(_interact2)
	host.wait_vetoes.append(_wait_veto2)
	host.travel_blocks.append(_travel_veto2)
	_load_route()


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
	march(dt)
	_t += dt
	if _t < 0.5:
		return
	tick(_t)
	_t = 0.0


func tick(_dt := 0.5) -> void:
	_where_tick()
	tick2()
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
		"due":                                                            # 3쪽 출동 명단의 날짜 — 치는 순간 정한다(종이와 추심 날이 한 값, 1-12f 재검수)
			if v1("DUE") == 0:
				_set_due()
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
					"what": ("누군가 새벽인력 출근부의 봉천 빚 몇 줄을 제 캡으로 갚았다고 이장이 들었다" if v1("RES") == 4 else ("누군가 새벽인력 출근부에서 봉천 이름을 뺐다고 이장이 들었다" if removed() > 0 else "누군가 새벽인력 장부의 봉천 빚에 '완납' 도장을 찍었다고 이장이 들었다")), "seen_by": ["BC"], "about": []})
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
	if v1("DUE") == 0:
		_set_due()                                                    # 3쪽을 치며 이미 정했으면 그 날짜 그대로
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


# ================================================================ FQ-SB-02 「현장 운송」(계획 §5 · §6)
## 행렬: 인솔조장(갈고리 — 죽었거나 SQ-S09로 고척 노선이면 대리 반장, LEAD 1) + 인솔조원 둘(CR-437)은 '평화 무리' 적(led — 평시 걸음은 진행기,
##   맞거나 싸움이 붙으면 AI가 넘겨받는다), 인력 넷(오태수 + 무명 셋)은 비전투 배우. 경로는 구운 경유점(convoy_sb02.json) — 선두가 점마다 걷고
##   나머지는 선두 흔적을 2칸 간격으로 따른다. 저장하지 않는다(P10): 불러오기 · 맵을 건너면 LEG 경유점에서 다시 선다.
## 뒤처짐: 선두에서 14칸 넘게면 줄이 선다(한 번에 게임 30분까지 — 그 뒤엔 '호위 없이 간다') · 40칸 넘게 10분이거나 실내 30분이면 빠짐(RES 4).
## 사건: ① 고가 끝(북 램프) 오태수 탈주 → 상판 밑 ② 신도림 쉬는 박자(원격기 [은신 50]) · 정찰(방범대를 먼저 보면 우회 · 말 맞추기) ③ 노량진로 끝 방범대
##   ④ 철교 남단 인계 지점 — 노들 남문 경비 통행세 2배 · 출장소 인수원. 10:00을 넘기면 인수원은 돌아갔다(RES 2 — 넘기지 않음).
const HOOK := "N-R02-041"                                                ## 인솔조장 갈고리
const TAESU := "N-R02-506"                                               ## 오태수(봉천 출신 '인력')
const ROUTE_PATH := "res://data/world/convoy_sb02.json"
const YARD := Vector2i(630, 1333)                                        ## X-SB 마당 트럭 옆(손 맵 원점 606,1307 + 24,26) — 출발 줄
const LAG_R := 14.0
const LOST_R := 40.0
const WAIT_MAX := 30
const LOST_MAX := 10
const IN_MAX := 30
const ESC_MAX := 30
const REST_MIN := 5
const DEADLINE := 600                                                    ## 인계 지점 도착 마감 10:00(하루 안 분)
const SCOUT_R := 25.0
const GAP := 4                                                           ## 흔적 점(16px) 간격 — 2칸
const FOLK := ["en_refugee_loco", "en_refugee_b_loco", "en_trader_b_loco"]
const LAG_BARKS := ["\"호위가 줄 뒤에 붙어야지.\"", "\"서. …호위 기다린다.\"", "(인력 하나가 뒤를 돌아본다. 목걸이 불빛이 깜박인다.)", "\"시계 봐. 출장소는 안 기다려.\""]
const FOLK_BARKS := ["(목걸이를 손가락으로 감싸고 있다) ……", "\"…철교 건너면 뭐 해요? …몰라도 돼요.\"", "(발끝만 본다)"]

var _route: Array = []                                                   ## [[칸, 층], …] 본길
var _detour: Array = []                                                  ## 신도림 → 인계 지점 우회
var _meta: Dictionary = {}
var cv := {}                                                             ## {"phase", "lead", "men", "folk", "taesu", "trail", "path", "i", "hold", "stuck", "fight"}
var _lag_at := -1
var _lost_at := -1
var _in_at := -1
var _hold_until := -1
var _esc_at := -1
var _gave_up := false
var _patrol: Array = []                                                  ## 방범대(평화 → 싸움)
var _hand_people: Array = []                                             ## 인수원 · 노들 경비(배우)
var _bark_t := 0.0
var _bark_i := 0
var _pending2 := ""


func v2(k: String) -> int:
	return int(st.vars.get_v("FQ_SB02_" + k))


func _s2(k: String, n: int) -> void:
	st.vars.set_v("FQ_SB02_" + k, n)


func stage2() -> int:
	return st.quests.stage(Q2)


func _up2(n: int) -> void:
	var s := stage2()
	if s < n and s < 100:
		st.quests.set_stage(Q2, n)
		_log("SB-02 단계 %d" % n)


## 인솔이 대리 반장이면 같은 장면의 _L 판(tools/pipeline/script_variants.py)
func sc(id: String) -> String:
	return id + ("_L" if v2("LEAD") == 1 else "")


func _load_route() -> void:
	if not FileAccess.file_exists(ROUTE_PATH):
		return
	_meta = JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH))
	for q in _meta.get("route", []):
		_route.append([Vector2i(int(q[0]), int(q[1])), int(q[2])])
	for q in _meta.get("detour", []):
		_detour.append([Vector2i(int(q[0]), int(q[1])), int(q[2])])


## 지금 걷는 경유점 목록(우회면 신도림까지 본길 + 우회 길)
func points() -> Array:
	if v2("DETOUR") == 1 and not _detour.is_empty():
		return _route.slice(0, int(_meta["sindorim"]) + 1) + _detour.slice(1)
	return _route


func _px(t: Vector2i) -> Vector2:
	return Vector2(t.x * 32 + 16, t.y * 32 + 16)


func _world() -> bool:
	return host.map != null and host.map is WorldMap


func _ptile() -> Vector2i:
	return host.map.tile_of(host.player.loco.logical) if host.player != null and host.map != null else Vector2i(-9999, -9999)


func _pdist(p: Vector2) -> float:
	return host.player.loco.logical.distance_to(p) / 32.0 if host.player != null else 1e9


## 주인공이 선두보다 앞(앞 경유점에 더 가깝다)이고 40칸 안이면 정찰 — 줄은 서지 않는다(1-12f 재미 검수)
func _ahead(ld: Enemy) -> bool:
	var pts := points()
	var j := mini(int(cv.get("i", 0)) + 6, pts.size() - 1)
	if j < 0 or _pdist(ld.loco.logical) > LOST_R:
		return false
	var t := _px(pts[j][0])
	return host.player.loco.logical.distance_to(t) < ld.loco.logical.distance_to(t)


## 행렬에서 가장 가까운 사람까지(칸) — 줄이 12칸 넘게 늘어서므로 선두까지가 아니라 줄 꼬리에 붙었는지를 본다
func _cv_dist() -> float:
	var best := 1e9
	for a in [cv.get("lead")] + cv.get("men", []) + cv.get("folk", []):
		if _ok(a):
			best = minf(best, _pdist(a.loco.logical))
	return best


func _ok(a) -> bool:
	return a != null and is_instance_valid(a) and not (a is Enemy and (a as Enemy).cmb.dead)


func lead() -> Enemy:
	return cv.get("lead") if not cv.is_empty() and _ok(cv.get("lead")) else null


func walking() -> bool:
	return stage2() >= 10 and stage2() < 100 and v2("RES") == 0


func deadline_abs() -> int:
	var d := v2("DAY")
	return d - d % 1440 + DEADLINE


# ---------------------------------------------------------------- 매 0.5초
func tick2() -> void:
	if _route.is_empty() or host.player == null:
		return
	var s := stage2()
	var h := gv("GAME_HOUR")
	if s == 0 and v2("RES") == 0:
		if _world() and h == 4 and _in_yard() and stage1() == 100 and v2("DAY") / 1440 != now() / 1440:
			if cv.is_empty():
				_spawn(YARD, 0, "yard")
		elif not cv.is_empty() and cv.get("phase", "") == "yard" and (h != 4 or not _world()):
			_clear()                                                  # 그날 행렬은 혼자 떠났다(화면 밖)
		return
	if not walking():
		return
	if not _world():
		cv = {}                                                       # 맵을 건너면 사람은 지워졌다 — 돌아오면 LEG에서 다시 선다
		if _in_at < 0:
			_in_at = now()
		elif now() - _in_at >= IN_MAX:
			_drop_out()
		return
	_in_at = -1
	if cv.is_empty():
		_spawn_walk()
	if cv.is_empty():
		return
	if _check_fallen():
		return
	if bool(cv.get("fight", false)):
		if v2("PATROL") == 1 and _patrol.filter(func(e): return not _patrol_out(e)).is_empty():
			_patrol_won()
		return
	_lag_tick()
	_events()
	if _pending2 != "" and not _paused():
		var id := _pending2
		_pending2 = ""
		host.play_scene(sc(id))


func _in_yard() -> bool:
	return _world() and (host.map as WorldMap).zone_of(_ptile()) == "X-SB"


func _free(c: Vector2i) -> Vector2i:
	for r in range(0, 5):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var t := c + Vector2i(dx, dy)
				if not host.map.is_solid(t):
					return t
	return c


func _spawn_walk() -> void:
	var pts := points()
	var i := clampi(v2("LEG"), 0, pts.size() - 1)
	_spawn(pts[i][0], int(pts[i][1]), "walk")
	cv["i"] = i


func _spawn(base: Vector2i, fl: int, phase: String) -> void:
	_clear()
	if stage2() == 0:
		_s2("LEAD", 1 if st.is_dead(HOOK) or gv("SQ_S09_SOL2") == 2 else 0)
	var men: Array = []
	var specs := [["CR-438", "st_n_r02_041" if v2("LEAD") == 0 else "en_cr438_loco"], ["CR-437", "en_cr437_loco"], ["CR-437", "en_cr437_loco"]]
	for k in specs.size():
		var c := _free(base + Vector2i(0, k * 2))
		var e := host.combat.spawn(str(specs[k][0]), _px(c), host.map, st, {"lv": 8, "team": "calm_sb02", "foes": [], "sheet": str(specs[k][1])})
		e.led = true
		e.mode = "walk"
		_pace(e)
		if k == 0 and v2("LEAD") == 0:
			e.who = HOOK
		if k > 0:
			_pace(e, 1.2)
		if fl != 0:
			e.set_floor(fl)
		men.append(e)
	var folk: Array = []
	var with_taesu := v2("TAESU") == 0 or v2("TAESU") == 2
	var n := 4 if with_taesu else 3
	for k in n:
		var sheet: String = "st_n_r02_506" if with_taesu and k == 0 else str(FOLK[k % FOLK.size()])
		var a := _person(sheet, _free(base + Vector2i(1, 1 + k * 2)), fl)
		a.set_meta("sb02_folk", TAESU if with_taesu and k == 0 else "")
		folk.append(a)
	var tr: Array = []
	for k in 40:
		tr.append(men[0].loco.logical)
	cv = {"phase": phase, "lead": men[0], "men": men.slice(1), "folk": folk, "taesu": null, "trail": tr, "path": PackedVector2Array(),
		"i": 0, "hold": "", "stuck": 0.0, "fight": false}
	if v2("TAESU") == 1 and _meta.has("hide"):
		cv["taesu"] = _person("st_n_r02_506", Vector2i(int(_meta["hide"][0]), int(_meta["hide"][1])), 0)
	_log("행렬 섬(%s · 경유점 %d)" % [phase, v2("LEG")])


## 행렬 걸음(칸/초) — 적 걷기는 기본 속도 × 0.45(약 1칸/초)라 483칸이 게임 4시간이 된다(봇이 찾음). 줄 모두 같은 걸음, 따르는 사람은 조금 빠르게(흔적을 따라잡게)
const PACE := 2.5


func _pace(a: Actor, k := 1.0) -> void:
	var w: Dictionary = a.loco.custom.get("walk", {}).duplicate()
	if w.is_empty():
		w = {"frames": 6, "px": 4.0, "px_v": 3.0, "diag": 3.0, "contact": [0, 3]}
	w["speed_t"] = PACE * k
	var c: Dictionary = a.loco.custom.duplicate()
	c["walk"] = w
	a.loco.custom = c


func _person(sheet: String, c: Vector2i, fl: int) -> Actor:
	var a := Actor.new()
	a.setup(sheet, _px(c), host.map)
	a.mode = "walk"
	_pace(a, 1.2)
	host.map.add_actor(a)
	if fl != 0:
		a.set_floor(fl)
	a._show()
	return a


func _clear() -> void:
	if cv.is_empty():
		return
	for e in [cv.get("lead")] + cv.get("men", []):
		if _ok(e):
			host.combat.drop_enemy(e)
	for a in cv.get("folk", []) + [cv.get("taesu")]:
		_drop_actor(a)
	cv = {}


func _drop_actor(a) -> void:
	if a != null and is_instance_valid(a):
		if host.map != null:
			host.map.remove_actor(a)
		a.queue_free()


func _fade(a: Node2D) -> void:
	if a == null or not is_instance_valid(a):
		return
	var tw: Tween = a.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(a, "modulate:a", 0.0, 1.5)
	tw.tween_callback(func() -> void: _drop_actor(a))


# ---------------------------------------------------------------- 매 프레임 걸음
func march(dt: float) -> void:
	if cv.is_empty() or cv.get("phase", "") != "walk" or _paused() or cv.get("fight", false):
		return
	var ld := lead()
	if ld == null or ld.brain.state != AIBrain.S.IDLE:
		return
	var pts := points()
	var i := int(cv["i"])
	var stop := _holding() or i >= pts.size()
	if not stop:
		var tgt := _px(pts[i][0])
		if NpcRoutine.arrived(ld.loco.render, tgt) or ld.loco.logical.distance_to(tgt) < 10.0:
			_reach(i)
		else:
			var p: PackedVector2Array = cv["path"]
			if p.is_empty():
				p = NpcRoutine.with_start(host.map, ld.loco.logical, tgt, int(pts[i][1]))
				if p.is_empty():
					cv["stuck"] = float(cv["stuck"]) + dt
					if float(cv["stuck"]) > 2.0:                          # 길이 안 잡힌다(붙지 않은 청크 · 막힘): 다음 점으로 넘긴다
						cv["stuck"] = 0.0
						_reach(i)
			cv["path"] = NpcRoutine.walk_path(ld, p, dt) if not p.is_empty() else p
	else:
		ld.move(Vector2.ZERO, dt)
	var tr: Array = cv["trail"]
	if tr.back().distance_to(ld.loco.logical) >= 16.0:
		tr.append(ld.loco.logical)
		if tr.size() > 240:
			tr.pop_front()
	var k := 0
	for f in cv["men"] + cv["folk"]:
		k += 1
		if not _ok(f) or (f is Enemy and (f as Enemy).brain.state != AIBrain.S.IDLE):
			continue
		var idx := maxi(0, tr.size() - 1 - k * GAP)
		var t: Vector2 = tr[idx]
		if NpcRoutine.arrived(f.loco.render, t):
			f.move(Vector2.ZERO, dt)
		else:
			f.move(NpcRoutine.step_dir(f.loco.render, t), dt)
	var ta = cv.get("taesu")
	if _ok(ta) and v2("TAESU") == 1 and _meta.has("hide"):               # 달아난 아이: 상판 밑으로
		var hp := _px(Vector2i(int(_meta["hide"][0]), int(_meta["hide"][1])))
		if not NpcRoutine.arrived(ta.loco.render, hp):
			var q: PackedVector2Array = ta.get_meta("path", PackedVector2Array())
			if q.is_empty():
				q = NpcRoutine.with_start(host.map, ta.loco.logical, hp, 0)
			ta.set_meta("path", NpcRoutine.walk_path(ta, q, dt))


func _reach(i: int) -> void:
	cv["i"] = i + 1
	cv["path"] = PackedVector2Array()
	cv["stuck"] = 0.0
	_s2("LEG", i + 1)
	if (i + 1) % 10 == 0:
		_log("경유점 %d · %s" % [i + 1, host.date_text])


func _holding() -> bool:
	return str(cv.get("hold", "")) != "" or bool(cv.get("lag", false)) or now() < _hold_until


func _release() -> void:
	if not cv.is_empty():
		cv["hold"] = ""


# ---------------------------------------------------------------- 뒤처짐 · 빠짐
func _lag_tick() -> void:
	var ld := lead()
	if ld == null:
		return
	var d := _cv_dist()
	if d > LAG_R and str(cv.get("hold", "")) == "" and not _ahead(ld):
		if _lag_at < 0:
			_lag_at = now()
		cv["lag"] = now() - _lag_at < WAIT_MAX
		if not bool(cv["lag"]) and not _gave_up:
			_gave_up = true
			_log("호위 없이 간다(%.0f칸 · %s)" % [d, host.date_text])
			host.hint("갈고리: \"호위 없이 간다.\"" if v2("LEAD") == 0 else "인솔 반장: \"호위 없이 간다.\"", 4.0)
		_bark_t += 0.5
		if bool(cv["lag"]) and _bark_t >= 8.0:
			_bark_t = 0.0
			host.hint(("갈고리: " if v2("LEAD") == 0 else "인솔 반장: ") + str(LAG_BARKS[_bark_i % LAG_BARKS.size()]), 4.0)
			_bark_i += 1
	else:
		_lag_at = -1
		_gave_up = false
		cv["lag"] = false
	if d > LOST_R and str(cv.get("hold", "")) != "esc":
		if _lost_at < 0:
			_lost_at = now()
		elif now() - _lost_at >= LOST_MAX:
			_drop_out()
	else:
		_lost_at = -1


func _drop_out() -> void:
	if not walking():
		return
	_s2("RES", 4)
	_set_twhere()
	st.call_fn("aff", ["SB", -3])
	st.quests.set_stage(Q2, 100)
	_clear()
	_clear_patrol()
	if not _paused():
		host.play_scene(sc("FQSB02_LEFT"))
	want_save.emit("sb02")
	_log("빠짐")


## 인솔조가 쓰러지거나 싸움이 붙었다: 이름 있는 처치는 생사 장부(P3) · 주인공이 건드려 무리가 돌아섰으면(편 이름 enemy_) 흩어짐(RES 5) ·
## 다른 것(길 위 무리)에 조장이 쓰러졌으면 조원이 대리 반장으로 이어 끈다(LEAD 1 — 같은 장면의 _L 판)
func _check_fallen() -> bool:
	if cv.is_empty():
		return false
	var sb: Array = [cv.get("lead")] + cv.get("men", [])
	for e in sb:
		if e != null and is_instance_valid(e) and (e as Enemy).cmb.dead and (e as Enemy).who != "" and not st.is_dead((e as Enemy).who):
			st.kill((e as Enemy).who)
	if bool(cv.get("fight", false)):
		return false
	var turned := false
	for e in sb:
		if e != null and is_instance_valid(e) and str((e as Enemy).cmb.team).begins_with("enemy"):
			turned = true
	if turned:
		cv["fight"] = true
		for e in sb:
			if _ok(e):
				(e as Enemy).led = false
				(e as Enemy).cmb.team = "enemy_sb02"
				(e as Enemy).foes = ["player", "ally"]
		host.combat._rebuild_list()
		_scatter2()
		return true
	if lead() == null:
		var alive: Array = cv.get("men", []).filter(func(e): return _ok(e))
		if alive.is_empty():
			_scatter2()
			cv["fight"] = true
			return true
		cv["lead"] = alive[0]
		cv["men"].erase(alive[0])
		_s2("LEAD", 1)
		host.hint("인솔조원: \"조장이 쓰러졌다. …철교 남단까진 간다. 내가 끈다.\"", 4.0)
	return false


func _patrol_won() -> void:
	for e in [cv.get("lead")] + cv.get("men", []):
		if _ok(e):
			var en: Enemy = e
			en.led = true
			en.cmb.team = "calm_sb02"
			en.foes = []
			en.brain.state = AIBrain.S.IDLE
			en.brain.gauge = 0.0
			en.brain.home = en.loco.logical
	host.combat._rebuild_list()
	_patrol = []
	cv["fight"] = false
	cv["path"] = PackedVector2Array()
	_release()
	_log("방범대를 물리침")


func _scatter2() -> void:
	if not walking():
		return
	_s2("RES", 5)
	_set_twhere()
	st.call_fn("aff", ["SB", -10])
	st.deeds.record(st, "faction", "R02", 1, {}, now(), {"tag": "FQSB02_SCATTER", "place": "SB", "what": "운송조 호위가 인솔조에게 총을 겨눴다", "seen_by": ["SB"], "about": []})
	st.quests.set_stage(Q2, 200)
	for a in cv.get("folk", []):
		_fade(a)                                                      # 목걸이를 단 채 흩어진다(원격기는 인솔조원 허리춤 — CR-437 처치 = 해방)
	cv["folk"] = []
	want_save.emit("sb02")
	_log("흩어짐")


# ---------------------------------------------------------------- 사건
func _events() -> void:
	var s := stage2()
	var leg := v2("LEG")
	var pts := points()
	if s < 20 and leg < pts.size() and int(pts[mini(leg, pts.size() - 1)][1]) >= 1:
		_up2(20)                                                      # 고가 상판에 올랐다
	if v2("TAESU") == 0 and leg > int(_meta.get("ramp_n", 9999)) and s < 30:
		_escape()
	if v2("TAESU") == 1 and str(cv.get("hold", "")) == "esc" and _esc_at >= 0 and now() - _esc_at >= ESC_MAX:
		_taesu_back(false)                                            # 아무도 안 찾았다 — 조원이 끌고 온다
	if str(cv.get("hold", "")) == "report" and _pdist(lead().loco.logical) <= 3.0 and not _paused():
		_pending2 = "FQSB02_REPORT"
		cv["hold"] = "report_open"
	if v2("REST") == 0 and leg > int(_meta.get("sindorim", 9999)):
		_s2("REST", 1)
		_hold_until = now() + REST_MIN
		_pending2 = "FQSB02_REST"
	# 정찰: 행렬보다 먼저 방범대 자리를 본다
	var pa := Vector2i(int(_meta.get("patrol_at", [0, 0])[0]), int(_meta.get("patrol_at", [0, 0])[1]))
	if v2("SCOUT") == 0 and v2("DETOUR") == 0 and v2("PATROL") == 0 and leg < int(_meta.get("patrol", 0)) - 6 and _pdist(_px(pa)) <= SCOUT_R:
		_s2("SCOUT", 1)
		_spawn_patrol(pa)
		host.hint("노량진로 끝에 형광 조끼 셋 — 행렬은 아직 못 봤다.", 4.0)
	if v2("DETOUR") == 0 and leg >= int(_meta.get("patrol", 9999)) - 1 and str(cv.get("hold", "")) == "" and not bool(cv.get("patrol_done", false)):
		cv["hold"] = "patrol"
		cv["patrol_done"] = true
		if _patrol.is_empty():
			_spawn_patrol(pa)
		_up2(40)
		_pending2 = "FQSB02_PATROL"
	if leg >= pts.size() and s < 50:
		_up2(50)
		cv["hold"] = "hand"
		if now() > deadline_abs():
			_s2("LATE", 1)
			_pending2 = "FQSB02_HAND"
		else:
			_spawn_hand()
			_pending2 = "FQSB02_TOLL"


func _escape() -> void:
	_s2("TAESU", 1)
	_up2(30)
	_esc_at = now()
	cv["hold"] = "esc"
	for a in cv["folk"]:
		if str(a.get_meta("sb02_folk", "")) == TAESU:
			cv["folk"].erase(a)
			cv["taesu"] = a
			break
	_pending2 = "FQSB02_ESCAPE"


func _taesu_back(by_player: bool) -> void:
	_s2("TAESU", 2)
	var ta = cv.get("taesu")
	if _ok(ta):
		cv["folk"].insert(0, ta)
		ta.set_meta("sb02_folk", TAESU)
	cv["taesu"] = null
	cv["hold"] = "report" if by_player else ""
	if not by_player:
		host.hint("인솔조원 하나가 상판 밑에서 아이를 끌고 나온다.", 4.0)


func _spawn_patrol(pa: Vector2i) -> void:
	_clear_patrol()
	for k in 3:
		var c := _free(pa + Vector2i(1, -2 + k * 2))
		var e := host.combat.spawn("CR-452", _px(c), host.map, st, {"lv": 8, "team": "calm_jy", "foes": [], "sheet": "en_cr452_loco" if k != 1 else "en_cr452b_loco"})
		e.led = true
		_patrol.append(e)


func _clear_patrol() -> void:
	for e in _patrol:
		if _ok(e):
			host.combat.drop_enemy(e)
	_patrol = []


func _spawn_hand() -> void:
	var h: Vector2i = points().back()[0]
	_hand_people = [_person("en_cr435_loco", _free(h + Vector2i(1, -3)), 0), _person("en_downed_loco", _free(h + Vector2i(4, 1)), 0),
		_person("en_downed_loco", _free(h + Vector2i(5, 3)), 0)]


func _patrol_fight(team_sb: String, sb_foes: Array, jy_foes: Array) -> void:
	cv["fight"] = true
	for e in [cv.get("lead")] + cv.get("men", []):
		if _ok(e):
			(e as Enemy).led = false
			(e as Enemy).cmb.team = team_sb
			(e as Enemy).foes = sb_foes
			_to_fight(e)
	for e in _patrol:
		if _ok(e):
			(e as Enemy).led = false
			(e as Enemy).cmb.team = "jy_sb02"
			(e as Enemy).foes = jy_foes
			_to_fight(e)
	host.combat._rebuild_list()


## 방범대원이 싸움에서 빠졌나: 쓰러짐 · 기절(HP 0) · 달아남 · 항복 · 놓아줌 · 싸움을 놓고 멀리(20칸) 쉼 — 남은 사람만 이 싸움의 상대(1-13 sb02f 회귀: 달아난 한 명 · 기절한 한 명이 '살아 있음'으로 남아 행렬이 영영 섰다)
func _patrol_out(e) -> bool:
	if not _ok(e):
		return true
	var en: Enemy = e
	if en.cmb.hp <= 0.0 or en.brain.fleeing() or en.released or en.brain.state == AIBrain.S.SURRENDER:
		return true
	return en.brain.state != AIBrain.S.COMBAT and en.loco.logical.distance_to(host.player.loco.logical) > 20.0 * 32.0


## 싸움이 정해진 순간 두 편이 곧장 교전에 든다(노량진로 끝 방범대는 25칸 넘게 떨어져 서 있어 서로 못 보고 쉬는 채 서 있었다 — 1-13 sb02f 회귀)
func _to_fight(e) -> void:
	var en: Enemy = e
	en.brain.gauge = 100.0
	en.brain.state = AIBrain.S.COMBAT
	en.brain.home = en.loco.logical


## 오태수 자리(계획 §6.5 — P1): 운송이 끝날 때 한 번. 1 출장소(섬으로) · 2 본소 대기(늦음) · 3 봉천 아랫마당 · 4 방범대가 데려감 · 5 행방 모름.
## 형 재회(D-291) · 봉천 배치는 이 값만 읽는다. 죽었으면 생사 장부가 먼저(P3).
func _set_twhere() -> void:
	if v2("TWHERE") != 0:
		return
	var t := v2("TAESU")
	var w := 1
	if t == 4:
		w = 3                                                         # 숨김 · 풀어 줌
	elif t == 3:
		w = 5                                                         # 고가에서 달아난 채
	else:
		match v2("RES"):
			2:
				w = 2
			3:
				w = 4
			5, 6:
				w = 5
	_s2("TWHERE", w)


## 결과(원문 §6.4 · 계획 §5.3 · §6)
func _finish2(res: int) -> void:
	_s2("RES", res)
	_set_twhere()
	var n := v2("N")
	match res:
		1:
			st.call_fn("aff", ["SB", 10])
			for l in [["JC", -6], ["YH", -3], ["JH", -3], ["KD", -2], ["NJ", 1]]:
				st.call_fn("aff", l)
			st.call_fn("karma", [-mini(200, 50 * n)])
			st.call_fn("aff", ["ND", -5])
			st.call_fn("xp", [300])
			st.call_fn("caps", [70 if v2("TOLL") == 3 else 150])           # 갈고리에게 맡기면 통행세 60 + 품 20을 일당에서 깜
			st.deeds.record(st, "faction", "HR", 2, {}, now(), {"tag": "FQSB02_HANDED", "place": "ND",
				"what": "새벽인력 운송조가 한강철교 남단에서 인력 %d을 넘겼다" % n, "seen_by": ["ND"], "about": []})
		2:
			st.call_fn("aff", ["SB", 4])
			st.call_fn("xp", [300])
			st.call_fn("caps", [75])
		6:
			st.call_fn("aff", ["SB", -10])
			st.call_fn("karma", [100])
			st.deeds.record(st, "faction", "HR", 1, {}, now(), {"tag": "FQSB02_UNHOOK", "place": "ND",
				"what": "새벽인력 운송조의 목걸이가 철교 남단에서 한꺼번에 꺼졌다 — 호위가 원격기를 쥐고 있었다", "seen_by": ["SB"], "about": []})
		3:
			st.call_fn("aff", ["SB", -10])
			st.call_fn("karma", [100])
			st.deeds.record(st, "faction", "HR", 2, {"JC": 5}, now(), {"tag": "FQSB02_FREED", "place": "ND",
				"what": "자율방범대가 새벽인력 운송조의 목걸이를 끊었다 — 호위가 넘겼다", "seen_by": ["SB"], "about": []})
	if (res == 1 or res == 2) and gv("AFF_SB") >= 20 and not st.items.has("M-129"):
		st.call_fn("give", ["M-129", 1])
	st.quests.set_stage(Q2, 100)
	want_save.emit("sb02")
	_log("운송 끝 RES %d · 인계 %d" % [res, n])


## 인계 뒤: 인력은 인수원을 따라 철교로, 인솔조는 본소로(화면 밖) — 사람은 흐려진다
func _after_hand(turn_back: bool) -> void:
	for a in cv.get("folk", []) + _hand_people:
		_fade(a)
	_hand_people = []
	for e in [cv.get("lead")] + cv.get("men", []):
		if _ok(e):
			var en: Enemy = e
			var tw: Tween = en.create_tween()
			tw.tween_interval(3.5)
			tw.tween_property(en, "modulate:a", 0.0, 1.5)
			tw.tween_callback(func() -> void:
				if is_instance_valid(en):
					host.combat.drop_enemy(en))
	cv = {}
	_clear_patrol()
	if turn_back:
		_log("인수원 없음 — 본소로")


# ---------------------------------------------------------------- 조사 키 · 막기
func _interact2() -> bool:
	if cv.is_empty() or host.player == null or _paused():
		return false
	var me := host.player.loco.logical
	var best = null
	var bd := 46.0
	for a in [cv.get("lead"), cv.get("taesu")] + cv.get("men", []) + cv.get("folk", []) + _patrol:
		if _ok(a) and a.loco.logical.distance_to(me) < bd:
			bd = a.loco.logical.distance_to(me)
			best = a
	if best == null:
		return false
	if best == cv.get("lead"):
		if cv.get("phase", "") == "yard":
			host.play_scene(sc("FQSB02_YARD"))
		elif str(cv.get("hold", "")).begins_with("report"):
			host.play_scene(sc("FQSB02_REPORT"))
		elif v2("SCOUT") == 1 and v2("DETOUR") == 0 and v2("PATROL") == 0 and v2("LEG") < int(_meta.get("patrol", 0)) - 1:
			host.play_scene(sc("FQSB02_TELL"))
		elif now() < _hold_until and host.combat.crouch and v2("TRIED") == 0:
			host.play_scene(sc("FQSB02_POCKET"))
		else:
			host.hint(("갈고리: " if v2("LEAD") == 0 else "인솔 반장: ") + "\"줄 뒤에 붙어. 말은 인계 지점 가서.\"", 3.0)
		return true
	if best == cv.get("taesu") and v2("TAESU") == 1:
		var ld := lead()
		var far := ld == null or ld.loco.logical.distance_to(best.loco.logical) / 32.0 > 12.0
		_s2("SNEAK", 1 if host.combat.crouch or far else 0)
		cv["seen_now"] = 0 if (host.combat.crouch or far) else 1
		host.play_scene("FQSB02_TAESU")
		return true
	if best in _patrol:
		if v2("SCOUT") == 1 and v2("PATROL") == 0 and not str(cv.get("hold", "")).begins_with("patrol"):
			host.play_scene("FQSB02_SCOUT")
			return true
		return false
	if best in cv.get("folk", []) and str(best.get_meta("sb02_folk", "")) == TAESU and v2("TAESU") == 2 and v2("REMOTE") == 1:
		var ld2 := lead()                                                 # 데려온 오태수 — 원격기를 쥐었으면 풀어 줄 수 있다(1-12f 재미 검수)
		var far2 := ld2 == null or ld2.loco.logical.distance_to(best.loco.logical) / 32.0 > 12.0
		cv["seen_now"] = 0 if (host.combat.crouch or far2) else 1
		host.play_scene("FQSB02_TAESU")
		return true
	if best in cv.get("folk", []) or best == cv.get("taesu"):
		host.hint(str(FOLK_BARKS[_bark_i % FOLK_BARKS.size()]), 3.0)
		_bark_i += 1
		return true
	if best in cv.get("men", []):
		host.hint("인솔조원: \"갈 길 가.\"", 2.5)
		return true
	return false


func _wait_veto2() -> String:
	if walking() and _world():
		return "운송 중이다. 행렬은 쉬지 않는다 — 출장소 지나서."
	return ""


func _travel_veto2(_lid: String) -> String:
	if walking():
		return "운송 중이다. 행렬을 두고 갈 수 없다."
	return ""


# ---------------------------------------------------------------- SB-02 명령
func _cmd2(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"start":
			if stage2() == 0:
				_s2("DAY", now())
				_s2("LEG", 0)
				_up2(10)
				if not cv.is_empty():
					cv["phase"] = "walk"
					cv["i"] = 0
				want_save.emit("sb02")
				_log("운송 출발")
		"taesu":
			var n := int(a[1]) if a.size() > 1 else 2
			var seen := int(cv.get("seen_now", 0)) == 1
			if seen and v2("SEEN") == 0:
				_s2("SEEN", 1)
			match n:
				2:
					_taesu_back(true)
				3:
					_s2("TAESU", 3)
					cv["hold"] = "report"
				4:
					_s2("TAESU", 4)
					st.call_fn("karma", [50])
					if v2("SEEN") == 1:
						_s2("SEEN", 2)
						st.call_fn("aff", ["SB", -6])
					_fade(cv.get("taesu"))
					cv["taesu"] = null
					cv["hold"] = "report"
				5:                                                    # 원격기로 목걸이를 끄고 풀어 줌(1-12f 재미 검수 — 탈주 때든 데려온 뒤든)
					var was_out := v2("TAESU") == 1
					_s2("TAESU", 4)
					_s2("FREE", 1)
					st.call_fn("karma", [50])
					if seen and v2("SEEN") != 2:
						_s2("SEEN", 2)
						st.call_fn("aff", ["SB", -6])
					var ta = cv.get("taesu")
					if not was_out:
						for f in cv.get("folk", []):
							if str(f.get_meta("sb02_folk", "")) == TAESU:
								ta = f
						cv["folk"].erase(ta)
					_fade(ta)
					cv["taesu"] = null
					if was_out:
						cv["hold"] = "report"
					elif not seen:                                            # 걷는 중 몰래 — 갈고리는 누가 했는지 모르지만 줄이 준 건 안다
						host.hint(("갈고리" if v2("LEAD") == 0 else "인솔 반장") + ": (줄을 센다) \"…셋? 하나 어디 갔어.\" (줄 뒤를 한참 본다)", 5.0)
		"report":                                                         # 0 '못 찾았다' · 1 '도망치게 뒀다'
			if v2("TAESU") != 2 and v2("SEEN") != 2 and (v2("SEEN") == 1 or (a.size() > 1 and int(a[1]) == 1)):
				_s2("SEEN", 2)
				st.call_fn("aff", ["SB", -6])
			if v2("TAESU") == 3 and _ok(cv.get("taesu")):
				_fade(cv.get("taesu"))
				cv["taesu"] = null
			_esc_at = -1
			_release()
		"stall":                                                          # 일부러 늦춤(찾는 척 · 두 시간 쉬자) — 시간 도약(P6, 06시를 넘으면 하루 판정)
			host.advance_minutes(int(a[1]) if a.size() > 1 else 60)
			if a.size() > 2 and str(a[2]) == "rest":
				_hold_until = now() + REST_MIN                                # 쉰 끝에 갈고리가 존다 — 허리춤 틈은 그대로(재검수 ②)
			_log("늦춤 · %s" % host.date_text)
		"unhook":                                                         # 인계 지점에서 원격기로 넷을 끔 — 인력은 둔치로 흩어짐(RES 6)
			_s2("N", 0)
			_s2("REMOTE", 2)
			_finish2(6)
			_after_hand(false)
		"pocket":
			if a.size() > 1 and int(a[1]) == 1:
				_s2("TRIED", 1)
				if host.combat.crouch:
					_s2("REMOTE", 1)
				else:
					_pending2 = "FQSB02_POCKET_FAIL"
			elif v2("SEEN") != 2:
				_s2("SEEN", 2)
				st.call_fn("aff", ["SB", -6])
		"scout":
			_s2("PATROL", int(a[1]) if a.size() > 1 else 2)
		"detour":
			_s2("DETOUR", 1)
			_clear_patrol()
			if not cv.is_empty():
				var pts := points()
				var ld := lead()
				var bi := int(_meta.get("sindorim", 0))
				if ld != null:
					for j in range(bi, pts.size()):
						if _px(pts[j][0]).distance_to(ld.loco.logical) < _px(pts[bi][0]).distance_to(ld.loco.logical):
							bi = j
				cv["i"] = maxi(int(cv["i"]), bi)
				_s2("LEG", int(cv["i"]))
				cv["path"] = PackedVector2Array()
		"patrol":
			var n := int(a[1]) if a.size() > 1 else 1
			match n:
				1:
					_s2("PATROL", 1)
					_patrol_fight("ally_sb02", ["jy_sb02"], ["player", "ally", "ally_sb02"])
				2:
					_s2("PATROL", 2)
					for e in _patrol:
						if _ok(e):
							(e as Enemy).led = false
					_leave_patrol()
					_release()
				3:
					_s2("PATROL", 3)
					_s2("N", 0)
					_patrol_fight("enemy_sb02", ["player", "ally", "jy_sb02"], ["enemy_sb02"])
					_finish2(3)
					for f in cv.get("folk", []):
						_fade(f)                                              # 방범대가 목걸이를 끊고 데려간다
					cv["folk"] = []
				4:
					_s2("PATROL", 4)
					_s2("N", 0)
					_s2("REMOTE", 2)
					for e in [cv.get("lead")] + cv.get("men", []):
						if _ok(e):
							(e as Enemy).led = false
					_finish2(3)
					_after_hand(false)
		"toll":
			var n := int(a[1]) if a.size() > 1 else 3
			_s2("TOLL", n)
			if n == 2:                                                    # 1(60)은 선택지 [캡 60] 태그가 이미 뺐다
				st.call_fn("caps", [-mini(30, gv("PC_CAPS"))])
			for p in _hand_people.slice(1):
				_fade(p)
			_pending2 = "FQSB02_HAND"
		"hand":
			var cnt := 0
			for f in cv.get("folk", []):
				if _ok(f):
					cnt += 1
			_s2("N", cnt)
		"remote":
			if a.size() > 1 and int(a[1]) == 0:
				_s2("REMOTE", 0)
				if v2("FREE") == 1 and v2("SEEN") != 2:                   # 불빛 하나가 꺼져 있다 — 돌려주면 들킨다
					_s2("SEEN", 2)
					st.call_fn("aff", ["SB", -6])
			else:
				_s2("REMOTE", 2)                                          # 버려진다(아이템이 아니다 — 다른 퀘스트로 새지 않게)
				if v2("SEEN") != 2:
					_s2("SEEN", 2)
					st.call_fn("aff", ["SB", -6])
		"pay":
			_finish2(1)
			_after_hand(false)
		"late":
			if v2("REMOTE") == 1:
				_s2("REMOTE", 2)                                          # 들고 온 원격기는 버려진다(아이템 아님) — 인수원이 없으니 끌 자리도 없다
			_finish2(2)
			_after_hand(true)
	done.call()


func _leave_patrol() -> void:
	for e in _patrol:
		if _ok(e):
			var en: Enemy = e
			var tw: Tween = en.create_tween()
			tw.tween_interval(2.0)
			tw.tween_property(en, "modulate:a", 0.0, 1.5)
			tw.tween_callback(func() -> void:
				if is_instance_valid(en):
					host.combat.drop_enemy(en))
	_patrol = []
