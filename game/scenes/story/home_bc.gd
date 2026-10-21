## 봉천 옥탑방 거처 진행기(단계 1-8b, SD-15 §7.2 · §7.5 · §7.7 · SD-04a §2.5). 원고: script/act1/HOME_BC.txt
## ① 조건: MQ-101 완료(100) + 봉천 우호(AFF_JC_BC ≥ +20)가 찬 날을 HOME_BC_OK에 적는다(우호 밑 +14 이하로 떨어지면 지운다 — SD-06 §4.2 히스테리시스).
## ② 그다음 날 06:00 하루 판정 뒤, 옥탑 이장실(B-01)에 있고 안전한 순간(대화·연출·이야기 사건·교전 아님)에 HOME_BC_KEY.
##    봉천 바깥(X-BC)에 들어오면 하루 한 번 '조만석이 찾는다' 안내. 장면 끝(@cmd home in)에 방을 다시 들어와 거처 가구가 선다.
## ③ 압류(§7.7): 경계(−25 이하) → '출입 자제' 쪽지 · 적대(−65 이하) → 압류(HOME_BC 2, 보관함이 닫힌다 — 물건은 그대로) ·
##    중립(−19 이상)으로 돌아오면 다시 연다. 조합 창고(§5.6)가 아직 없어 물건은 옮기지 않고 제자리에 묶어 둔다(구현 정합).
## ④ 백구: 거처가 있으면 하루 판정마다 30%로 그날 옥탑방 문 앞에서 잔다(BAEKGU_NAP — 그날은 봉천 바깥 자리에 없다, SD-20 P3).
class_name HomeBc
extends Node

const AFF_OK := 20                 ## 우호로 오르는 값
const AFF_LOST := 14               ## 우호에서 떨어지는 값(이하)
const WARN_AT := -25               ## 경계로 떨어지는 값(이하)
const SEIZE_AT := -65              ## 적대로 떨어지는 값(이하)
const CLEAR_AT := -19              ## 중립으로 돌아오는 값(이상)
const NAP_P := 0.3

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _hint_day := -1


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["home"] = _cmd
	host.map_entered.connect(_on_map)
	host.day_tick.connect(_on_day)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[거처] " + s)


## 열쇠를 받을 때가 됐나(조건이 찬 다음 날부터)
func key_due() -> bool:
	# 조만석이 죽었으면: 그 죽음이 알려지고 범인이 주인공으로 지목되지 않았을 때 하숙자 · 반상회 쪽지가 잇는다(1-X, P11 — 거처가 영영 닫히지 않게)
	var chief_ok := not st.is_dead("C-010") or (st.known_dead("C-010") and not Crimes.knows_killer(st, "C-010"))
	return v("HOME_BC") == 0 and v("HOME_BC_OK") > 0 and v("GAME_DAY") > v("HOME_BC_OK") and chief_ok


func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	check()
	if host.map != null and host.map.id == "B-01" and _safe():
		var sc := _due_scene()
		if sc != "":
			_log("장면 " + sc)
			host.play_scene(sc)


## 호감도·퀘스트를 보고 거처 상태를 맞춘다(매 0.5초 · 시험에서 직접 부른다)
func check() -> void:
	var aff := v("AFF_JC_BC")
	var home := v("HOME_BC")
	if home == 0:
		if v("HOME_BC_OK") == 0 and st.quests.stage("MQ-101") >= 100 and aff >= AFF_OK:
			st.vars.set_v("HOME_BC_OK", maxi(1, v("GAME_DAY")))
			_log("조건 참(%d일, 봉천 %d)" % [v("GAME_DAY"), aff])
		elif v("HOME_BC_OK") > 0 and aff <= AFF_LOST:
			st.vars.set_v("HOME_BC_OK", 0)                                   # 열쇠를 받기 전에 인심을 잃었다
			_log("조건 거짓(봉천 %d)" % aff)
		return
	var note := v("HOME_BC_NOTE")
	if home == 1:
		if aff <= SEIZE_AT:
			st.vars.set_v("HOME_BC", 2)
			st.vars.set_v("HOME_BC_NOTE", 3)
			host.hint("봉천 반상회가 312번째 계단 옥탑방을 압류했다.", 6.0)
			_log("압류(봉천 %d)" % aff)
		elif aff <= WARN_AT and note in [0, 5]:
			st.vars.set_v("HOME_BC_NOTE", 1)
			_log("출입 자제(봉천 %d)" % aff)
		elif aff >= CLEAR_AT and note in [1, 2]:
			st.vars.set_v("HOME_BC_NOTE", 0)
	elif home == 2 and aff >= CLEAR_AT:
		st.vars.set_v("HOME_BC", 1)
		st.vars.set_v("HOME_BC_NOTE", 5)
		host.hint("봉천 인심이 돌아왔다. 옥탑방 압류가 풀렸다.", 6.0)
		_log("압류 풀림(봉천 %d)" % aff)


func _due_scene() -> String:
	if key_due():
		return "HOME_BC_KEY"
	match [v("HOME_BC"), v("HOME_BC_NOTE")]:
		[1, 1]:
			return "HOME_BC_WARN"
		[2, 3]:
			return "HOME_BC_SEIZED"
		[1, 5]:
			return "HOME_BC_BACK"
	return ""


## 장면을 열어도 되는 순간(SD-20 P5): 대화·연출·창·이야기 사건·교전 중이 아니다
func _safe() -> bool:
	if host.box.active or host.ev.busy() or host.busy or host.story_hold or host.locked:
		return false
	if host.pipboy != null or host.container != null or host.wait_ui != null or host.terminal != null or host.lockpick != null:
		return false
	return host.wait_block() == ""


func _on_map(id: String) -> void:
	if id == "X-BC" and key_due() and _hint_day != v("GAME_DAY"):
		_hint_day = v("GAME_DAY")
		host.hint("조만석이 옥탑 이장실에서 찾는다고 한다.", 6.0)


## 하루 판정(06:00): 백구 낮잠 굴림. 판의 씨앗 + 날짜로 정해서 불러와도 같다
func _on_day(day: int) -> void:
	var nap := 0
	if v("HOME_BC") == 1 and not st.is_dead("C-015") and v("UQ02_END") != 1:   # UQ-02 새끼를 데려온 뒤엔 마을 강아지 곁에서 잔다(1-12g 계획 §8.2)
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("baekgu|%d|%d" % [st.check_seed, day])
		nap = 1 if rng.randf() < NAP_P else 0
	st.vars.set_v("BAEKGU_NAP", nap)
	if nap == 1:
		_log("백구 낮잠(%d일)" % day)


## 원고 명령 @cmd home in: 방을 다시 들어와 거처 가구·보관함을 세운다(맵 조건은 들어올 때 본다)
func _cmd(a: Array, done: Callable) -> void:
	match str(a[0]) if a.size() > 0 else "":
		"in":
			host.busy = true
			host.ev.run("fade_out", ["black", "6"], func() -> void:
				host.enter("B-01", "home_in")
				host.ev.run("fade_in", ["black", "6"], func() -> void:
					host.busy = false
					host.hint("312번째 계단 옥탑방 — 내 방이다. 침대에서 자면 숙면, 궤짝·사물함은 비워지지 않는다.", 7.0)
					done.call()))
		_:
			done.call()
