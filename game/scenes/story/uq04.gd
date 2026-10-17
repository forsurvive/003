## 관악(R01) 비표시 퀘스트 UQ-04 「7호 냉동 창고」 진행기(단계 1-D3, SD-05 §2.6 UQ-04 · §3.18 단계표 · RE-045 · 1-D 계획 §9 · §9.6).
##   원고: script/act1/UQ-04.txt. 맵: DS-01 가공장 · DS-02 냉동 창고 동(던전 DG-DS) · 월드 문 둘(L-R01-29 정문 하역장 · 뒤 철길 하역장).
## 사실은 변수 한 곳(P1): 7호 상자는 UQ04_GONE(나간 수) 하나 — 남은 수 LEFT · 선반 그림 SHELF는 여기서 셈해 맵 조건이 읽는다(보여 주기용).
## 시간선(P4 · P6): 정착민 운반 · 짐꾼 · 냉동기 정지 · RE-045 대치는 06:00 하루 판정에서만 — 주인공이 독산 안에 있으면 하루 미룬다.
## 순서 꼼수(A109): 알림 보답 · 함준호 값 · 감시조는 남은 상자(LEFT)를 읽는다 — 먼저 털고 알리고 팔아도 세계가 남은 양을 안다.
## 왕쥐의 행방(UQ04_RATK): 굴에서 쓰러짐 · 냉기로 언 둥지 · 7호에 꾀어 가둠(문을 잠그면 8초 뒤 언다) · 7호에 둔 채 떠남(자리 잡음 · 상자 −5).
## 비표시(SD-05 §2.6): 알림 없음 · 단계 로그(메모) · XP만.
class_name Uq04
extends Node

const QID := "UQ-04"
const MAP1 := "DS-01"
const MAP2 := "DS-02"
const STOCK := 40                          ## 런천미트 20 · 꽁치 20(SD-05 UQ-04 ④)
const DUE_DAYS := 30                       ## 문을 연 날부터 냉동기가 버티는 날
const COLD_DAYS := 10                      ## 냉기를 굴로 돌리면 그날부터
const HAUL := 4                            ## 정착민이 하루에 지고 가는 상자
const GNAW := 5                            ## 왕쥐가 7호에서 갉아 먹는 상자
const FEUD_WAIT := 7                       ## RE-045: 주인공이 오지 않으면 스스로 나눠 끝내는 날
const LEAK_DAYS := 5                       ## ③ 소문이 봉천에 닿는 날(공개도 1)
const FEUD_LEFT := 8                       ## RE-045: 두 동네가 다 지키다 남은 상자가 이만큼(이틀 몫) 이하가 되면 대치(A107)
const PER_BOX := 5                         ## ③ 함준호 값: 상자당 캡(마흔이면 원문 200 — A109)
const SIGN_XP := 25                        ## 2077 고리 셋을 다 보고 '출고 확인'을 누름
const DOOR7 := Vector2i(34, 9)
const KEYPAD := Vector2i(36, 9)
const ROOM7 := Rect2i(28, 3, 14, 5)        ## 7호 안(칸)
const NEST := Rect2i(17, 3, 10, 5)         ## 굴(흙 — 왕쥐 둥지)
const TRAP_S := 8.0                        ## 7호에 갇힌 왕쥐가 조용해지기까지(초)
const XP := 80

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _trap := -1.0                          ## 가두기 남은 초(−1 = 없음)
var _rat_in7 := false                      ## 지난 틱에 왕쥐가 7호 안에 있었나(떠날 때 자리 잡음 판정)
var _last_map := ""


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["uq04"] = _cmd
	host.day_tick.connect(_on_day)
	host.combat.enemy_killed.connect(_on_kill)
	_sync()


func v(k: String) -> int:
	return int(st.vars.get_v("UQ04_" + k))


func _sv(k: String, n: int) -> void:
	st.vars.set_v("UQ04_" + k, n)


func _log(s: String) -> void:
	if log_on:
		print("[7호 냉동 창고] " + s)


func _mid() -> String:
	return host.map.id if host.map != null else ""


func day() -> int:
	return maxi(1, int(st.vars.get_v("GAME_DAY")))


func stage() -> int:
	return st.quests.stage(QID)


func _up(n: int) -> void:
	if stage() < n:
		st.quests.set_stage(QID, n)
		_log("단계 %d" % n)


## 처음 정해진 행방으로 닫는다(XP 한 번). 뒤에 다른 쪽에 또 알려도 결과는 따로 쌓인다(SD-05 '한 곳에만 알릴 수 있는 것이 아니다')
func _close(sol: int, why: String) -> void:
	if v("SOL") == 0:
		_sv("SOL", sol)
	if stage() >= 100:
		return
	_up(20)
	_sv("REWARD", day())
	_up(100)
	st.call_fn("xp", [XP])
	_log("닫힘 — " + why)


func left() -> int:
	return maxi(0, STOCK - v("GONE"))


## 보여 주기 변수(맵 조건이 읽는다): 남은 상자 · 선반 그림(0 가득 · 1 반 · 2 빔 · 3 땀 · 4 녹음 · 5 갉힘)
func _sync() -> void:
	_sv("LEFT", left())
	_sv("PRICE", left() * PER_BOX)
	var sh := 0
	if v("THAW") == 1:
		sh = 4
	elif left() <= 0:
		sh = 2
	elif v("RATK") == 4:
		sh = 5
	elif v("COLD") == 1:
		sh = 3
	elif left() <= STOCK / 2:
		sh = 1
	_sv("SHELF", sh)


func _gone(n: int) -> int:
	var k := mini(n, left())
	_sv("GONE", v("GONE") + k)
	_sync()
	return k


func in_dok() -> bool:
	return _mid() == MAP1 or _mid() == MAP2


# ---------------------------------------------------------------- 매 0.5초: 맵 들어옴(7호 문) · 왕쥐가 7호 안인가 · 가두기
func _process(dt: float) -> void:
	if host == null or host.map == null:
		return
	if _trap >= 0.0:
		_trap -= dt
		if _trap < 0.0:
			_freeze_trapped()
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	var mid := _mid()
	if mid != _last_map:
		if _last_map == MAP2 and _rat_in7 and v("RATK") == 0 and v("LOCK") == 0:
			_sv("RATK", 4)                                                   # 7호에 꾀어 둔 채 문을 열어 두고 떠났다 — 왕쥐가 7호에 자리 잡는다
			_gone(GNAW)
			_log("왕쥐가 7호에 자리 잡음")
		_last_map = mid
		_rat_in7 = false
		if mid == MAP2:
			_enter2()
	if mid == MAP2:
		var r := _king()
		_rat_in7 = r != null and ROOM7.has_point(host.map.tile_of(r.loco.logical))


## 냉동 창고 동에 들어섰다: 연 7호 문은 열어 둔다(맵 원고는 잠긴 문 — 사실은 UQ04_OPEN · LOCK)
func _enter2() -> void:
	if v("OPEN") >= 1 and v("LOCK") == 0:
		host.map.unlock_door(DOOR7.x, DOOR7.y)


## 살아 있는 왕쥐(굴 또는 7호)
func _king() -> Enemy:
	for e in host.combat.enemies:
		if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-097":
			return e
	return null


# ---------------------------------------------------------------- 06:00 하루 판정
func _on_day(d: int) -> void:
	if v("FEUD") == 0 and v("THAW") == 0 and _standoff(d):
		if in_dok():
			_log("대치 미룸(주인공이 독산 안)")                                 # 지게도 멈춘 채 하루 더 노려본다
		else:
			_sv("FEUD", 1)                                                   # RE-045: 마지막 상자 몇 개를 두고 7호 앞 대치(A107)
			_sv("FEUD_DAY", d)
			_log("RE-045 대치(남은 상자 %d)" % left())
	_haul(d)
	if v("JH") == 1 and d >= v("JH_DAY") + 2:
		if in_dok():
			_log("짐꾼 미룸(주인공이 독산 안)")
		elif v("RATK") == 4:
			_sv("JH", 4)                                                     # 7호에 자리 잡은 왕쥐 — 짐꾼이 물려 수레를 버리고 도망친다
			_log("짐꾼이 왕쥐에게 물려 도망")
		elif _guarded(d):
			_sv("JH", 3)                                                     # 7호 앞을 정착민이 지키고 있었다 — 짐꾼이 빈손으로 돌아간다
			_log("짐꾼이 쫓겨남")
		else:
			_gone(STOCK)
			_sv("JH", 2)
			_log("짐꾼이 7호를 비움")
	if v("JH") >= 1 and v("LEAK") == 0 and d >= v("JH_DAY") + LEAK_DAYS:
		_sv("LEAK", 1)                                                       # 공개도 1: 봉천 · 사당 사람들이 나중에 안다(SD-05 ③ BC −3)
		st.call_fn("aff", ["BC", -3])
		_log("③ 소문 — BC −3")
	if v("FEUD") == 1 and d >= v("FEUD_DAY") + FEUD_WAIT:
		_sv("FEUD", 2)                                                       # 주인공이 오지 않았다 — 반씩 나눠 끝(변화 없음, P10)
		_after_feud(d)
		_log("RE-045 저절로 끝")
	if v("OPEN") >= 1 and v("THAW") == 0 and v("FEUD") != 1 and v("DUE") > 0 and d >= v("DUE"):
		if in_dok():
			_sv("DUE", d + 1)                                                # 주인공이 안에 있으면 하루 미룸(P4)
			_log("정지 미룸(주인공이 독산 안)")
		elif v("FEUD") == 0 and v("BC") >= 1 and v("SA") >= 1 and left() > 0:
			_sv("FEUD", 1)                                                   # RE-045: 멈추는 날 — 마지막 상자를 두고 대치
			_sv("FEUD_DAY", d)
			_log("RE-045 대치")
		else:
			_thaw(d)
	_sync()


## 정착민 운반(알린 다음 날부터 하루 4상자 — 녹기 전 · 짐꾼이 비우기 전 · 두 동네가 마지막 상자를 두고 노려보는 동안은 멈춤)
func _haul(d: int) -> void:
	if v("THAW") == 1 or v("FEUD") == 1 or (v("FEUD") == 0 and _standoff(d)):
		return
	for k in ["BC", "SA"]:
		if v(k) >= 1 and d > v(k + "_DAY"):
			_gone(HAUL)


## 두 동네가 다 7호 앞에 섰고 남은 상자가 이틀 몫 이하
func _standoff(d: int) -> bool:
	return v("BC") >= 1 and v("SA") >= 1 and d > v("BC_DAY") and d > v("SA_DAY") and left() > 0 and left() <= FEUD_LEFT


## 대치가 끝났다: 냉동기가 멈추는 날이었으면 녹고, 아니면 남은 상자를 나눠 지고 간다(냉동기는 제 날에 멈춘다)
func _after_feud(d: int) -> void:
	if v("DUE") > 0 and d >= v("DUE"):
		_thaw(d)
	else:
		_gone(STOCK)


func _guarded(d: int) -> bool:
	return (v("BC") >= 1 and d > v("BC_DAY")) or (v("SA") >= 1 and d > v("SA_DAY"))


## 냉동기가 멈췄다: 남은 상자는 상한다 · 정착민이 떠난다 · 7호에 파리가 돌아온다
func _thaw(d: int) -> void:
	if v("THAW") == 1:
		return
	_sv("THAW", 1)
	_sv("THAW_DAY", d)
	_gone(STOCK)
	_log("7호가 녹음")


# ---------------------------------------------------------------- 원고 명령(@cmd uq04 …)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"tape":
			_sv("KNOW", 1)
			_up(10)
		"open":
			_sv("OPEN", int(a[1]))
			_sv("LOCK", 0)
			if v("DUE") == 0:
				_sv("OPEN_DAY", day())
				_sv("DUE", day() + DUE_DAYS)
			_up(10)
			_up(20)
			_door(false)
		"lock":
			_sv("LOCK", 1)
			_door(true)
			var r := _king()
			if r != null and v("RATK") == 0 and ROOM7.has_point(host.map.tile_of(r.loco.logical)):
				_trap = TRAP_S                                               # 꾀어 가뒀다 — 긁는 소리 뒤 조용해진다
				host.hint("문 안에서 긁는 소리. 찍찍 — 쾅. 한참 긁다가…", TRAP_S - 1.0)
				_log("왕쥐를 7호에 가둠")
		"unlock":
			_sv("LOCK", 0)
			_door(false)
			if _trap >= 0.0:
				_trap = -1.0                                                 # 다 얼기 전에 열었다 — 왕쥐가 튀어나온다
				_log("가두기 풀림")
		"take":
			var n := _gone(int(a[1]))
			var lunch := (n + 1) / 2
			if lunch > 0:
				st.call_fn("give", ["I-027", lunch])
			if n - lunch > 0:
				st.call_fn("give", ["I-035", n - lunch])
			_close(4, "직접 나름")
		"cold":
			_cold()
		"valve":
			st.vars.set_v("DS_VALVE", 1)
			if _mid() == MAP1:
				host.map.set_prop_state(Vector2i(36, 14), "washed")
				host.map.set_prop_state(Vector2i(41, 14), "open")
				for e in host.combat.enemies:
					if is_instance_valid(e) and not e.cmb.dead and str(e.row.get("id", "")) == "CR-004":
						e.wash()
		"shard":
			_sv("SHARD", 1)
			st.call_fn("caps", [15 + (day() * 7) % 11])                      # 쥐가 모아 둔 병뚜껑
			st.call_fn("give", ["I-027", 1])
			if _mid() == MAP2:
				host.map.set_prop_state(Vector2i(21, 4) if v("RATK") == 2 else Vector2i(36, 6), "broken")
		"tell":
			var k := "BC" if str(a[1]) == "bc" else "SA"
			if v(k) == 0:
				_sv(k, 1)
				_sv(k + "_DAY", day())
				st.call_fn("aff", [k, 6 if left() >= 30 else (3 if left() >= 10 else 1)])   # SD-05 ① BC +6 · ② SA +6 — 먼저 털었으면 남은 만큼(A109 · 공급 +10은 장부 D-195)
				_close(1 if k == "BC" else 2, "알림 " + k)
		"sell":
			if v("JH") == 0:
				_sv("JH", 1)
				_sv("JH_DAY", day())
				var price := left() * PER_BOX                                # 마흔이면 200(원문) — 남은 상자대로
				_sv("BACK", price / 2)
				st.call_fn("caps", [price])
				st.call_fn("aff", ["JH", 2])
				_close(3, "함준호에게 팖")
		"feud":
			_feud(str(a[1]))
		"link":
			_sv("LINK" + str(a[1]), 1)
		"sign":
			if v("SIGN") == 0:
				_sv("SIGN", 1)
				st.call_fn("xp", [SIGN_XP])
		"refund":
			if v("REFUND") == 0:
				if str(a[1]) == "pay":
					_sv("REFUND", 1)
					st.call_fn("caps", [-v("BACK")])
				else:
					_sv("REFUND", 2)
					st.call_fn("aff", ["JH", -3])
	_sync()
	done.call()


## 7호 문 · 번호판 그림(맵에 있을 때만)
func _door(lock: bool) -> void:
	if _mid() != MAP2:
		return
	if lock:
		host.map.lock_door(DOOR7.x, DOOR7.y)
		host.map.set_prop_state(KEYPAD, "")
	else:
		host.map.unlock_door(DOOR7.x, DOOR7.y)
		host.map.set_prop_state(KEYPAD, "open")


## 냉기를 굴로: 냉동기 날이 10일로 줄고 · 굴의 짐승이 언다(왕쥐가 둥지에 있으면 던전 정리) · 흙 · 파리 · 서리가 바뀐 맵으로 다시 연다
func _cold() -> void:
	if v("COLD") == 1:
		return
	_sv("COLD", 1)
	_sv("COLD_DAY", day())
	_sv("DUE", mini(v("DUE") if v("DUE") > 0 else day() + DUE_DAYS, day() + COLD_DAYS))
	if _mid() == MAP2:
		for e in host.combat.enemies.duplicate():
			if is_instance_valid(e) and not e.cmb.dead and NEST.has_point(host.map.tile_of(e.loco.logical)):
				var id := str(e.row.get("id", ""))
				if id == "CR-097" and v("RATK") == 0:
					_sv("RATK", 2)
					_record_boss(e)
				host.combat.enemies.erase(e)
				e.queue_free()
		host.combat._rebuild_list()
	elif v("RATK") == 0:
		_sv("RATK", 2)                                                       # 맵 밖(시험): 둥지째 언다
	_clear_check()
	_sync()
	if _mid() == MAP2 and host.is_inside_tree():
		host.go.call_deferred(MAP2, "panel")                              # 서리 · 언 흙 · 죽은 파리 · 언 왕쥐 — 바뀐 창고로 다시 연다
	_log("냉기를 굴로")


## 7호에 갇힌 왕쥐가 언다(가두기 8초 뒤 · 문이 아직 잠겨 있으면)
func _freeze_trapped() -> void:
	if v("LOCK") != 1 or v("RATK") != 0:
		return
	var r := _king()
	if r != null:
		_record_boss(r)
		host.combat.enemies.erase(r)
		r.queue_free()
		host.combat._rebuild_list()
	_sv("RATK", 3)
	_gone(GNAW)                                                              # 갇힌 동안 상자를 갉았다(재미 검수 '엉뚱한 짓' 대가)
	_clear_check()
	host.hint("…조용해졌다. 문 너머가 차갑게 고요하다.", 4.0)
	_log("왕쥐가 7호에서 얼어붙음")


## 우두머리 처치 기록(맵 자리 — 다시 서지 않게)
func _record_boss(e: Enemy) -> void:
	if e.has_meta("spawn_key"):
		st.boxes[str(e.get_meta("spawn_key"))] = {"day": day(), "boss": true}


func _clear_check() -> void:
	var msg := Dungeon.check_clear(st, MAP2)
	if msg != "" and host.is_inside_tree():
		host.hint(msg, 4.0)


## 왕쥐를 쓰러뜨렸다(어디서든)
func _on_kill(id: String, _left: int) -> void:
	if id == "CR-097" and in_dok() and v("RATK") in [0, 4]:
		_sv("RATK", 1)
		_sync()
		_clear_check()
		_log("왕쥐 처치")


## RE-045 결말: 순번(BC +3 · SA +3) · 한쪽 편(그쪽 +3 · 다른 쪽 −5) · 끼어들지 않음 — 남은 상자는 나눠 지고, 멈추는 날이었으면 7호가 녹는다
func _feud(how: String) -> void:
	if v("FEUD") != 1:
		return
	match how:
		"share":
			st.call_fn("aff", ["BC", 3])
			st.call_fn("aff", ["SA", 3])
		"bc":
			st.call_fn("aff", ["BC", 3])
			st.call_fn("aff", ["SA", -5])
		"sa":
			st.call_fn("aff", ["SA", 3])
			st.call_fn("aff", ["BC", -5])
	_sv("FEUD", 2)
	_sv("FEUD_DAY", day())
	_after_feud(day())
	if _mid() == MAP2 and host.is_inside_tree():
		host.go.call_deferred(MAP2, "door7")
	_log("RE-045 " + how)
