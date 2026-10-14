## 1막 경로 진행기(단계 1-4): MQ-102 「코드를 읽을 사람」 허브와 MQ-103 「지하시장」(SD-03a §8.2·§8.3).
## Mq101 진행기와 같은 InteriorHost 위에서 돈다. 원고(script/act1/MQ-103.txt · JM_PEOPLE.txt)가 부르는 사건(@cmd jm …)과 맵 사건을 맡는다.
## 단계: MQ-103 10 단서를 들음(지하시장에 들어간다) → 20 들어옴(마영식을 만날 방법) → 30 길을 얻음(출입패·몰래·출입 단말 해킹) →
##   해독(K_CODE·K_NET, 해독 메모 M-207, XP 300 — 다른 길로 이미 알았으면 180) → 40 (선택) 고백 → 100(고백하거나, 해독 뒤 배전실을 나서면).
## MQ-102: 1막이 열리면 10. 단서 셋은 경로 퀘스트를 10으로 열고 장소를 '표시'로 올린다. 경로 장소에 먼저 들어가도 열린다(O-02). K_CODE가 서면 100.
## S5 출구: 해독 뒤 북쪽 출구(J-01)로 나가면 수배 1 이상 + 추적대가 다닐 때 새벽인력 추적조 매복(셋). 출입패가 있으면 구울 경비 둘,
##   박춘삼을 고용했으면 박춘삼이 함께 싸운다. 남쪽 통로나 역사 쇼핑몰로 나가면 매복을 피한다(입구 선택이 곧 서사).
class_name Act1Paths
extends Node

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _ambush: Array = []
const CLUE_QUEST := {1: "MQ-103", 2: "MQ-104", 3: "MQ-105"}
const CLUE_TEXT := {1: "영등포 지하에 200살 먹은 기술자가 있다 — 2077년엔 세진 하청",
	2: "볼트 기록의 좌표가 여의도를 가리킨다", 3: "현상금을 건 자의 의뢰서는 새벽인력 장부에 붙어 있다"}
const PATH_MAPS := {"MQ-103": ["J-"], "MQ-104": ["Y-"], "MQ-105": ["H-01", "H-02"]}


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["jm"] = _jm
	host.map_entered.connect(_on_map)
	host.combat.enemy_killed.connect(_on_killed)


func v(k: String) -> int:
	return int(st.vars.get_v(k))


func _log(s: String) -> void:
	if log_on:
		print("[1막 경로] " + s)


# ---------------------------------------------------------------- 매 프레임(가볍게: 0.5초마다)
func _process(dt: float) -> void:
	_t += dt
	if _t < 0.5:
		return
	_t = 0.0
	if st.quests.stage("MQ-101") >= 50 and st.quests.stage("MQ-102") == 0:
		_open_hub()
	var hub := st.quests.stage("MQ-102")
	if hub >= 10 and hub < 100:                                       # 물건·기록으로 서는 단서(오버시어 단말 K_RALLY · 수배 쪽지의 본소 주소 · 인력 장부 조각)
		if v("K_RALLY") >= 1 and v("MQ102_C2") == 0:
			clue(2)
		if (v("MQ101_BOARD") >= 1 or st.items.has("M-161")) and v("MQ102_C3") == 0:
			clue(3)
	if v("K_CODE") >= 1 and st.quests.stage("MQ-102") > 0 and st.quests.stage("MQ-102") < 100:
		st.quests.set_stage("MQ-102", 100)                            # 코드의 정체를 알았다(자동, 자체 XP 없음)
		_log("MQ-102 닫힘(K_CODE)")
	if host.map != null and host.map.id == "J-03" and v("MQ103_DOOR") >= 1:
		host.map.unlock_door(27, 1)
	if not _ambush.is_empty():
		var alive := _ambush.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
		if alive.is_empty():
			_ambush.clear()
			st.vars.set_v("MQ103_AMBUSH", 2)
			st.call_fn("aff", ["SB", -5])
			host.combat.clear_allies()
			host.hint("추적조가 쓰러졌다. 셔터 안 일은 셔터 안에 두고 간다.", 5.0)
			_log("매복 끝")


## 허브 열기(MQ-101 단계 50 · 경로 장소 먼저 들어감): 이미 가진 단서는 바로 세운다(K_RALLY = 오버시어 단말 · 수배 쪽지의 본소 주소)
func _open_hub() -> void:
	st.quests.set_stage("MQ-102", 10)
	if v("K_RALLY") >= 1:
		clue(2, false)
	if v("MQ101_BOARD") >= 1:
		clue(3, false)
	_log("MQ-102 열림")


## 단서 n(1 지하시장 · 2 여의도 · 3 본소): 경로 퀘스트를 10으로, 장소를 지도에 '표시'로. 이미 들어간 경로는 그대로
func clue(n: int, say := true) -> void:
	if st.quests.stage("MQ-102") == 0:
		st.quests.set_stage("MQ-102", 10)
	st.vars.set_v("MQ102_C%d" % n, 1)
	var q: String = CLUE_QUEST[n]
	if st.quests.stage(q) == 0:
		st.quests.set_stage(q, 10)
	for lid in st.quests.places_of(q):
		st.places.raise(lid, PlaceLog.MARKED)
	if say:
		host.hint("단서: " + str(CLUE_TEXT[n]), 7.0)
	_log("단서 %d → %s" % [n, q])


# ---------------------------------------------------------------- 맵
func _on_map(id: String) -> void:
	for q in PATH_MAPS:                                                 # O-02: 경로 장소에 먼저 들어가도 허브가 열린다
		for pre in PATH_MAPS[q]:
			if id.begins_with(pre) and st.quests.stage("MQ-102") == 0:
				_open_hub()
	if id.begins_with("J-"):
		_enter_market(id)
	if id != "J-06" and st.quests.stage("MQ-103") == 40:                # 해독 뒤 배전실을 나서면 끝(고백은 나중에도 들을 수 있다)
		_finish()
	if v("MQ103_HIRE") == 1 and v("MQ103_JOB") < 3 and host.combat.buddy == null:
		_bring_park()
	if id == "J-01" and host.last_mark == "from_J-02":
		_maybe_ambush()


func _enter_market(id: String) -> void:
	var s := st.quests.stage("MQ-103")
	if s >= 20:
		return
	if id == "J-01" and v("MQ103_GATE") == 0:
		return                                                          # 북쪽 출구는 출입세 초소를 지나야 '들어온' 것이다
	if v("MQ103_GATE") == 0:
		st.vars.set_v("MQ103_GATE", 3 if id == "J-09" else 4)
	st.quests.set_stage("MQ-103", 20)
	st.places.raise("L-R02-11", PlaceLog.FOUND)
	_log("지하시장 들어옴(길 %d)" % v("MQ103_GATE"))


func _bring_park() -> void:
	host._bring_buddy("C-018")
	if host.combat.buddy != null:
		host.buddy_id = "C-018"
		host.buddy_name = "박춘삼"
		host.combat.buddy_weapon = "W-049"                             # 계약 경호 구울: 소방 도끼(SD-14 CR-457과 같은 직종)


func _maybe_ambush() -> void:
	if v("MQ103_AMBUSH") != 0 or v("K_CODE") == 0 or st.quests.stage("MQ-103") < 40:
		return
	if Wanted.grade(st) < 1 or not Encounters.new(st).tracker_on():
		st.vars.set_v("MQ103_AMBUSH", 2)
		return
	st.vars.set_v("MQ103_AMBUSH", 1)
	var lv := 4
	for i in 3:
		var p: Vector2 = host.map.mark_pos("ambush%d" % (i + 1))
		var e := host.combat.spawn("CR-436" if i == 0 else "CR-437", p, host.map, st, {"lv": lv})
		e.brain.gauge = 100.0
		_ambush.append(e)
	if st.items.has("M-078"):                                          # 상인회 출입패: 구울 경비 둘이 가세
		for n in host.npcs:
			if str(n["id"]) in ["CR-456", "N-R02-013"] and is_instance_valid(n["actor"]):
				host.combat.add_ally(str(n["id"]), n["actor"], 90.0, "W-002")
	host.hint("계단 위에서 장부 넘기는 소리. 새벽인력 추적조다!", 5.0)
	_log("북쪽 출구 매복")


func _on_killed(_eid: String, alive: int) -> void:
	if host.map == null:
		return
	if host.map.id == "J-09" and alive == 0 and v("MQ103_NEST") == 0:
		st.vars.set_v("MQ103_NEST", 1)
		if v("MQ103_JOB") == 1:
			st.vars.set_v("MQ103_JOB", 2)
			host.hint("둥지를 비웠다 — 상인회장 노복희에게 알린다", 7.0)
		_log("둥지 비움")


# ---------------------------------------------------------------- 원고 사건(@cmd jm …)
func _jm(a: Array, done: Callable) -> void:
	match str(a[0]):
		"enter":                                                        # 출입세를 냈거나 농담으로 지나갔다
			_enter_market("J-02")
		"hire":
			_bring_park()
		"pass":                                                         # 상인회 출입패: 1 상인회 일 · 2 면담료
			st.call_fn("give", ["M-078", 1])
			if int(a[1]) == 1:
				st.vars.set_v("MQ103_JOB", 3)
				st.vars.set_v("JM_REG", 1)
				st.call_fn("aff", ["JH", 10])
				st.call_fn("karma", [25])
				if v("MQ103_HIRE") == 1:
					host.ev.handlers["buddy"].call(["off"], func() -> void: pass)
					st.vars.set_v("MQ103_HIRE", 2)
			else:
				st.call_fn("aff", ["JH", 3])
			_got_way()
		"clue":                                                         # 단서 n(조만석·하숙자·독사·구울 행상·게시판)
			if v("MQ102_C%d" % int(a[1])) == 0:
				clue(int(a[1]))
		"door":                                                         # 출입패로 문을 열었다
			_got_way()
		"vent":                                                         # 환풍구: quiet = 들키지 않음 · loud = 경비 셋
			var loud := str(a[1]) == "loud"
			_got_way()
			host.enter("J-06", "vent_drop")
			if loud:
				st.call_fn("aff", ["JH", -10])
				for i in 3:
					var e := host.combat.spawn("CR-456", host.map.mark_pos("from_J-03") + Vector2((i - 1) * 40, -32), host.map, st, {"lv": 4})
					e.brain.gauge = 100.0
				host.play_scene.call_deferred("MQ-103_CAUGHT")
		"decode":                                                       # 해독(K_CODE를 세우기 전에 부른다 — 이미 알았으면 XP 180)
			var later := v("K_CODE") >= 1
			st.call_fn("give", ["M-207", 1])
			st.vars.set_v("HO_DECODE", 0)
			st.call_fn("xp", [180 if later else 300])
			if st.quests.stage("MQ-103") < 40:
				st.quests.set_stage("MQ-103", 40)
		"confess":                                                      # 고백: 시공 일지(LR-23) · 사양서 1쪽(LR-21)
			st.vars.set_v("K_LINE", 1)
			st.call_fn("give", ["M-206", 1])
			st.call_fn("give", ["M-232", 1])
			st.call_fn("aff", ["JH", 5])
			_finish()
	done.call()


## 마영식을 만날 길을 얻었다(단계 20 → 30)
func _got_way() -> void:
	if st.quests.stage("MQ-103") < 20:
		st.quests.set_stage("MQ-103", 20)
	if st.quests.stage("MQ-103") < 30:
		st.quests.set_stage("MQ-103", 30)


func _finish() -> void:
	if st.quests.stage("MQ-103") < 100:
		st.quests.set_stage("MQ-103", 100)
		# 판도 지하상가 +지하시장 5는 1-12 판도 표와 함께 붙인다(구현 정합)
		_log("MQ-103 완료")
