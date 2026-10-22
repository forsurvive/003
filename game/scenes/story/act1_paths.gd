## 1막 경로 진행기(단계 1-4): MQ-102 「코드를 읽을 사람」 허브와 MQ-103 「지하시장」(SD-03a §8.2·§8.3).
## Mq101 진행기와 같은 InteriorHost 위에서 돈다. 원고(script/act1/MQ-103.txt · JM_PEOPLE.txt)가 부르는 사건(@cmd jm …)과 맵 사건을 맡는다.
## 단계: MQ-103 10 단서를 들음(지하시장에 들어간다) → 20 들어옴(마영식을 만날 방법) → 30 길을 얻음(출입패·몰래·출입 단말 해킹) →
##   해독(K_CODE·K_NET, 해독 메모 M-207, XP 300 — 다른 길로 이미 알았으면 180) → 40 (선택) 고백 → 100(고백하거나, 해독 뒤 배전실을 나서면).
## MQ-102: 1막이 열리면 10. 단서 셋은 경로 퀘스트를 10으로 열고 장소를 '표시'로 올린다. 경로 장소에 먼저 들어가도 열린다(O-02). K_CODE가 서면 100.
## S5 출구: 해독 뒤 북쪽 출구(J-01)로 나가면 수배 1 이상 + 추적대가 다닐 때 새벽인력 추적조 매복(셋). 출입패가 있으면 구울 경비 둘,
##   박춘삼을 고용했으면 박춘삼이 함께 싸운다. 남쪽 통로나 역사 쇼핑몰로 나가면 매복을 피한다(입구 선택이 곧 서사).
## MQ-104(1-5, SD-03a §8.4): 벙커에 들어오면 20 → 출석부·당직 일지·유해를 보면 30 → 인증 단말(K_CODE·K_NET, XP 300/180) 40 + 수색조가
##   12초 뒤 내려온다(그때 있는 방에서 선우진과 마주침 — 말로·과학·교전) · 기계실 환기구 → 배수로로 빠지면 은신 · 벙커를 나서면 100.
##   호송차의 하도윤(V_DOYUN 1): 자물쇠 50 · 은신 50(열쇠) · 경비 처리 · 수색조와 싸웠으면 초소가 빈다. 인증한 다음 날 아침 호송차는 떠난다.
## MQ-105(1-6, SD-03a §8.5 · SD-09a L-R02-19): 본소(손 맵 X-SB · H-02~H-05)에 들어오면 20 → 장부·의뢰서를 읽으면 30(K_CODE · K_NET · K_LINE,
##   XP 300/180) → HO_LEDGER가 정해지면 100(장부를 들고 본소를 나서도 100). 정면 습격(SB_RAID): 마당 사람을 치거나 정문·소장실에서 들키면
##   평시 인물이 적으로 바뀌고(맵마다, 들어오는 맵도) 마당엔 모자란 만큼 조직원이 붙는다(합 10). 황두칠은 HP 30%에서 장부를 난로에 넣으려 한다(8초).
##   표찰 없이 마당에 서면(웅크리지 않고 6칸 안) 한 번 경고하고 3초 뒤 습격. 근태 목걸이를 찬 채 본소 밖에 6초 서 있으면 터진다.
class_name Act1Paths
extends Node

var host: InteriorHost
var st: StoryState
var log_on := false
var _t := 0.0
var _ambush: Array = []
var _search_t := -1.0                                ## 인증 뒤 수색조가 내려오기까지 남은 초(-1 = 없음)
var _squad: Array = []
var _guards: Array = []
var _squad_left := 0                                 ## 수색조 중 아직 선 수(방을 옮기면 그만큼 뒤따른다)
const SEARCH_DELAY := 12.0
const CLUE_QUEST := {1: "MQ-103", 2: "MQ-104", 3: "MQ-105"}
const CLUE_TEXT := {1: "영등포 지하에 200살 먹은 기술자가 있다 — 2077년엔 세진 하청",
	2: "볼트 기록의 좌표가 여의도를 가리킨다", 3: "현상금을 건 자의 의뢰서는 새벽인력 장부에 붙어 있다"}
const PATH_MAPS := {"MQ-103": ["J-"], "MQ-104": ["Y-"], "MQ-105": ["H-0"]}
const BUNKER := Vector2i(806, 1091)                                     ## 여의도 지하 벙커 L-R02-02 — 카드 숫자 둘 = 청크 (20, 27)(1-12k D-046)
# MQ-105 새벽인력 본소: 평시 인물 → 습격 때 적 종류(SD-14 · SD-09a ⑤). 독사는 MQ-101과 같은 CR-534, 황두칠은 보스 CR-513
const SB_ROLE := {"N-R02-035": "CR-438", "CR-435": "CR-435", "CR-436": "CR-436", "CR-437": "CR-437", "CR-438": "CR-438",
	"C-021": "CR-534", "N-R02-037": "CR-435", "N-R02-036": "CR-435", "C-049": "CR-438", "N-R02-038": "CR-437", "C-013": "CR-513"}
const SB_RAID_N := 10                                ## 정면 습격 조직원 수(SD-03a §8.5: 조직원 10 + 황두칠 + 독사)
const SB_CAGES := {4: 1, 10: 1, 22: 2, 28: 1, 34: 1} ## H-03 우리 문 x → 갇힌 사람 수(주인공 칸 16 빼고 합 6)
const SB_YARD := Rect2i(11, 11, 37, 25)              ## X-SB 담 안(마당 + 뒷마당, 손 맵 좌표)
const SB_WALLS := Rect2i(10, 3, 39, 35)              ## X-SB 본소 울타리 안(건물 · 옥상 · 마당 — 이 밖이 '본소 밖')
const SB_BURN_SECS := 8.0
var _sb: Array = []                                  ## 지금 맵에서 싸우는 새벽인력
var _hdc: Enemy = null
var _hdc_burn := -1.0
var _sb_warn := -1.0
var _collar := -1.0
var _sb_zone := ""


func setup(h: InteriorHost, is_log := false) -> void:
	host = h
	st = h.st
	log_on = is_log
	host.ev.handlers["jm"] = _jm
	host.ev.handlers["yd"] = _yd
	host.ev.handlers["sb"] = _sb_cmd
	host.map_entered.connect(_on_map)
	host.combat.enemy_killed.connect(_on_killed)
	host.combat.resident_hit.connect(_on_sb_hit)


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
	if hub >= 10 and v("V_REGCARD") < 3:                              # 등록 카드 단계(SD-03a §4.8 정본): 3 = MQ-102 발동 · 4 = K_CODE(내려가지 않는다)
		st.vars.set_v("V_REGCARD", 3)
	if v("K_CODE") >= 1 and v("V_REGCARD") < 4:
		st.vars.set_v("V_REGCARD", 4)
		host.hint("핍-보이: 관리자 코드가 해독되었습니다.", 5.0)
	if hub >= 10 and hub < 100:                                       # 물건·기록으로 서는 단서(오버시어 단말 K_RALLY · 수배 쪽지의 본소 주소 · 인력 장부 조각)
		if v("K_RALLY") >= 1 and v("MQ102_C2") == 0:
			clue(2)
	if v("V_ACT") >= 1 and v("V_REGCARD") >= 2 and v("MQ102_C2") == 0 and st.quests.stage("MQ-102") < 100:
		if v("MQ102_MAPC") == 0 and host.map is WorldMap and host.player != null:   # 카드 숫자만 보고 발로 찾아옴(재미 검수 '해 보고 싶은 짓'): 벙커 둘레에 서면 '이미 앎' 판(P2)
			var me: Vector2i = host.map.tile_of(host.player.loco.logical)
			if Vector2(BUNKER.x - me.x, BUNKER.y - me.y).length() <= 12.0:
				st.vars.set_v("MQ102_MAPC", 2)
				host.hint("손목 카드의 숫자 둘 — 20 · 27. 여기였나.", 6.0)
		if v("MQ102_MAPC") >= 1:                                        # 지도를 보고 한 추론(1-12k D-046): 카드 끝 숫자 둘 = 청크 (20, 27) — MQ-102 전이면 허브도 함께 연다
			clue(2, v("MQ102_MAPC") != 2)                               # 발로 찾아왔으면 '여기였나' 한 줄만(알림 겹침 없이)
		if (v("MQ101_BOARD") >= 1 or st.items.has("M-161")) and v("MQ102_C3") == 0:
			clue(3)
	if v("K_CODE") >= 1 and st.quests.stage("MQ-102") > 0 and st.quests.stage("MQ-102") < 100:
		st.quests.set_stage("MQ-102", 100)                            # 코드의 정체를 알았다(자동, 자체 XP 없음)
		_log("MQ-102 닫힘(K_CODE)")
	if host.map != null and host.map.id == "J-03" and v("MQ103_DOOR") >= 1:
		host.map.unlock_door(27, 1)
	if host.map != null and host.map.id == "Y-00" and v("MQ104_FIRE") >= 1:
		host.map.unlock_door(6, 13)
	if host.map != null and host.map.id == "K-20" and v("GB_PASS") >= 1:
		host.map.unlock_door(27, 1)                                     # 길금순이 열어 준 벽장(1-6)
	if host.map != null and host.map.id == "Y-04" and v("MQ104_AUTH") >= 1:
		host.map.unlock_door(3, 12)                                     # 방폭문: 관리자 인증으로도 열린다(SD-09a Y-04)
	_yd_tick()
	_sb_tick()
	if not _ambush.is_empty():
		var alive := _ambush.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
		if alive.is_empty() and _lost(_ambush):                         # 셔터 밖으로 빠져나갔다: 따돌림(격퇴가 아니다 — SD-20 N4)
			_ambush.clear()
			st.vars.set_v("MQ103_AMBUSH", 3)
			host.combat.clear_allies()
			_log("매복 따돌림")
		elif alive.is_empty():
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
	if v("MQ103_HIRE") == 1 and v("MQ103_JOB") < 3 and host.combat.buddy == null and not host.combat.mates.away.has("C-018"):   # 기다리게 둔 박춘삼은 그 자리에
		_bring_park()
	if id == "J-01" and host.last_mark == "from_J-02":
		_maybe_ambush()
	if id.begins_with("Y-"):
		_enter_bunker(id)
	_sb_map(id)
	if id == "Y-05" and v("MQ104_SEARCH") == 1:                         # 수색조가 내려오기 전에 환기구로 빠졌다(은신)
		_search_t = -1.0
		st.vars.set_v("MQ104_SEARCH", 3)
		host.hint("덕트 너머로 군화 소리가 멀어진다. 아무도 따라오지 않는다.", 5.0)
		_log("수색조 은신으로 피함")
	if not id.begins_with("Y-") and st.quests.stage("MQ-104") >= 40 and st.quests.stage("MQ-104") < 100 and v("MQ104_SEARCH") >= 2:
		st.quests.set_stage("MQ-104", 100)                              # 벙커 탈출(SD-03a §8.4 단계 40 완료)
		_log("MQ-104 완료(수색조 %d)" % v("MQ104_SEARCH"))
	if not id.begins_with("Y-") and v("MQ104_SEARCH") == 1:              # 수색조가 내려오기 전에 계단으로 빠져나갔다
		_search_t = -1.0
		st.vars.set_v("MQ104_SEARCH", 3)
		if st.quests.stage("MQ-104") < 100:
			st.quests.set_stage("MQ-104", 100)
		_log("수색조가 내려오기 전에 빠져나감")


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
	if st.is_dead("C-018"):                                             # 죽은 경호원은 다시 오지 않는다(동행은 기절뿐이지만 맵 주민일 때 죽을 수 있다)
		return
	host._bring_buddy("C-018")                                          # 계약 경호 구울: 소방 도끼(Companions.ROSTER — SD-14 CR-457과 같은 직종)


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
	for e in _sb:                                                       # 본소 이름 있는 적(황두칠 · 독사)
		if is_instance_valid(e) and e.cmb.dead and not e.has_meta("sb_done"):
			e.set_meta("sb_done", true)
			if e.who == "C-013":
				_hdc_dead()
			elif e.who == "C-021":
				st.kill("C-021")                                       # 독사(생사는 st.dead 한 곳 — D_DS는 SD-03a에서 다니엘 서)
				_log("독사 사망")
			elif e.who != "":
				st.kill(e.who)                                         # 이름 있는 본소 사람(구만호 · 빨간펜 · 십장 · 소개비 · 철사)도 생사는 한 곳(P3) — KS · GA · GR · FQ-SB가 dead()로 본다(1-12f 교차 점검)
				_log("본소 인물 사망 %s" % e.who)
	if host.map.id == "J-09" and alive == 0 and v("MQ103_NEST") == 0:
		st.vars.set_v("MQ103_NEST", 1)
		if v("MQ103_JOB") == 1:
			st.vars.set_v("MQ103_JOB", 2)
			host.hint("둥지를 비웠다 — 상인회장 노복희에게 알린다", 7.0)
		_log("둥지 비움")


# ---------------------------------------------------------------- MQ-104 여의도 집결지(@cmd yd …)
func _enter_bunker(_id: String) -> void:
	if st.quests.stage("MQ-104") < 20:
		if st.quests.stage("MQ-104") < 10:
			st.quests.set_stage("MQ-104", 10)
		st.quests.set_stage("MQ-104", 20)
		st.places.raise("L-R02-02", PlaceLog.FOUND)
		_log("벙커 들어옴")


## 출석부·당직 일지·유해를 다 보면 단계 30(인증 단말)
func _check_look() -> void:
	if st.quests.stage("MQ-104") == 20 and v("MQ104_ROLL") >= 1 and v("MQ104_LOG") >= 1 and v("MQ104_SEEN") >= 1:
		st.quests.set_stage("MQ-104", 30)
		_log("집결지 조사 끝")


func _yd_tick() -> void:
	if _search_t >= 0.0 and not host.box.active and not host.ev.busy():
		_search_t -= 0.5
		if _search_t < 0.0:
			_squad_arrives()
	if not _squad.is_empty():
		var alive := _squad.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
		if alive.is_empty() and _lost(_squad):                          # 방을 옮겨 시야에서 사라졌다: 격퇴가 아니다(SD-20 N4) — 벙커 안이면 남은 수가 문으로 뒤따른다
			var left := _squad_left
			_squad.clear()
			if host.map != null and host.map.id in ["Y-00", "Y-01", "Y-02"] and left > 0:
				_squad_chase(left)
			_log("수색조 놓침(남은 %d)" % left)
		elif alive.is_empty():
			_squad.clear()
			st.vars.set_v("MQ104_SEARCH", 2)
			st.vars.set_v("MQ104_GUARDS", 1)                              # 초소가 비었다(S5 '수색조와 싸웠다면 쉽다')
			host.hint("수색조가 쓰러졌다. 계단 위 초소는 이제 비었을 것이다.", 5.0)
			_log("수색조 격퇴")
	_squad_left = _squad.filter(func(e): return is_instance_valid(e) and not e.cmb.dead).size() if not _squad.is_empty() else _squad_left
	if not _guards.is_empty():
		var g_alive := _guards.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
		if g_alive.is_empty() and _lost(_guards):                       # 자리를 떴다: 경비는 초소로 돌아간다(쓰러진 게 아니다)
			_guards.clear()
		elif g_alive.is_empty():
			_guards.clear()
			st.vars.set_v("MQ104_GUARDS", 1)
			host.hint("호송차 경비가 쓰러졌다. 열쇠는 초소 탁자에.", 5.0)
	var day := int(st.vars.get_v("GAME_DAY")) if st.vars.has("GAME_DAY") else 0
	if v("V_DOYUN") == 1 and v("MQ104_DOYUN") == 0 and v("MQ104_DAY") > 0 and day > v("MQ104_DAY"):
		st.vars.set_v("MQ104_DOYUN", 2)                                   # 다음 날 아침 청계산으로(MQ-106에서 다시 기회)
		_log("호송차 떠남")


## 수색조가 내려왔다: 지금 있는 벙커 방에서 선우진과 마주친다
func _squad_arrives() -> void:
	if host.map == null or not host.map.id in ["Y-00", "Y-01", "Y-02"]:
		if host.map != null and host.map.id in ["Y-03", "Y-04"]:
			_search_t = 0.0                                               # 기계실·통로에 숨어 있으면 큰 방으로 돌아오는 순간 마주친다
		return
	var m := "from_Y-01" if host.map.id == "Y-02" else ("from_Y-00" if host.map.id == "Y-01" else "from_W")
	if st.is_dead("C-034"):                                           # 선우진이 이미 죽었다(초소에서 등): 이름 없는 하사가 이끄는 수색조가 말없이 덮친다(SD-20 P3)
		host.ev.actors.erase("C-034")
		_squad_fight()
		_log("수색조 도착(선우진 없음)")
		return
	host.ev._show_actor("C-034", host.map.mark_pos(m), "N" if host.map.id == "Y-02" else "S")
	for i in 2:
		host.ev._show_actor("BJ%d" % (i + 1), host.map.mark_pos(m) + Vector2((i * 2 - 1) * 36, 20), "N", "en_cr401_loco")
	host.play_scene("MQ-104_SUNWOO")
	_log("수색조 도착(%s)" % host.map.id)


func _clear_actors() -> void:
	for a in ["C-034", "BJ1", "BJ2"]:
		host.ev.run("hide", [a], func() -> void: pass)


func _squad_fight() -> void:
	var base: Vector2 = host.ev.actors["C-034"].loco.logical if host.ev.actors.has("C-034") else host.player.loco.logical + Vector2(0, 96)
	_clear_actors()
	var ids := ["CR-403", "CR-401", "CR-401", "CR-401", "CR-402"]
	for i in ids.size():
		var off := Vector2((i - 2) * 34, -24 - (i % 2) * 20)             # 선우진 뒤(입구 쪽)가 아니라 방 안쪽으로 퍼진다
		var p := base + off
		if host.map.marks.has("search_%d" % (i + 1)):                  # 집결지: 맵에 둔 수색조 자리
			p = host.map.mark_pos("search_%d" % (i + 1))
		if host.map.is_solid(host.map.tile_of(p)):
			p = base
		var e := host.combat.spawn(ids[i], p, host.map, st, {"lv": 5})
		e.brain.gauge = 100.0
		_squad.append(e)
	st.call_fn("aff", ["BJ", -10])
	host.hint("수색조가 계단을 뛰어 내려와 덮쳐 온다!" if st.is_dead("C-034") else "선우진이 계단 위로 물러나며 무전을 친다. 수색조가 덮쳐 온다!", 5.0)


## 맵을 옮겨 지워진 적이 있나(쓰러뜨린 것과 놓친 것을 가른다 — SD-20 P1·N4)
func _lost(list: Array) -> bool:
	return list.any(func(e): return not is_instance_valid(e))


## 벙커 안에서 방을 옮겼다: 남은 수색조가 주인공이 들어온 문으로 뒤따라 들어온다(대화 없이 곧장 교전)
func _squad_chase(n: int) -> void:
	var at: Vector2 = host.map.mark_pos(host.last_mark) if host.map.marks.has(host.last_mark) else host.player.loco.logical + Vector2(0, 96)
	var ids := ["CR-401", "CR-401", "CR-402", "CR-401", "CR-403"]
	for i in mini(n, ids.size()):
		var p := at + Vector2((i - 1) * 30, 0)
		if host.map.is_solid(host.map.tile_of(p)):
			p = at
		var e := host.combat.spawn(ids[i], p, host.map, st, {"lv": 5})
		e.brain.gauge = 100.0
		_squad.append(e)
	host.hint("군화 소리가 문 너머에서 따라 들어온다.", 4.0)


func _yd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"enter":
			_enter_bunker("Y-00")
		"fire":
			host.map.unlock_door(6, 13)
		"look":
			_check_look()
		"auth":                                                         # 인증(K_CODE를 세우기 전에 부른다 — 이미 알았으면 XP 180)
			var later := v("K_CODE") >= 1
			st.call_fn("xp", [180 if later else 300])
			st.call_fn("wanted", [3, "auth"])                               # 관리자 인증 +3(SD-03a §6.5 '104 인증 단말 +3' · 하루 +9 상한)
			if st.quests.stage("MQ-104") < 40:
				st.quests.set_stage("MQ-104", 40)
			st.vars.set_v("MQ104_SEARCH", 1)
			st.vars.set_v("MQ104_DAY", int(st.vars.get_v("GAME_DAY")) if st.vars.has("GAME_DAY") else 1)
			_search_t = SEARCH_DELAY
			host.map.set_prop_state(host.map.tile_of(host.map.mark_pos("auth")) + Vector2i(0, -1), "lit")
		"talk":                                                         # 말로 돌려보냈다(비상 +5)
			_clear_actors()
			st.vars.set_v("MQ104_SEARCH", 4)
			st.call_fn("aff", ["BJ", 5])
			host.hint("수색조가 계단을 올라간다. 호송차 경비는 그대로다.", 5.0)
		"fight":
			_squad_fight()
		"vent":
			host.enter("Y-05", "from_Y-03")
		"pick":                                                         # 호송 칸 자물쇠(50): 미니게임
			if Lockpick.can_try(50, st.skill("LOCKPICK")):
				host.open_lock(50, "pad", func() -> void: _rescue())
			else:
				host.hint("자물쇠가 단단하다. [자물쇠 따기 50 필요]", 4.0)
		"guards":                                                       # 경비 처리: 둘이 적이 된다
			for n in host.npcs:
				if str(n["id"]) == "CR-401" and is_instance_valid(n["actor"]):
					var e := host.combat.spawn("CR-401", n["actor"].loco.logical, host.map, st, {"lv": 4})
					e.brain.gauge = 100.0
					_guards.append(e)
					n["actor"].visible = false
					host.map.blockers.erase(n["actor"])
			st.call_fn("aff", ["BJ", -5])
		"rescue":
			_rescue()
	done.call()


func _rescue() -> void:
	if v("MQ104_DOYUN") != 0:
		return
	st.vars.set_v("V_DOYUN", 2)
	st.vars.set_v("MQ104_DOYUN", 1)
	st.call_fn("karma", [100])
	st.call_fn("aff", ["BJ", -5])
	st.call_fn("aff", ["JC_BC", 5])                                     # 봉천에 사람이 하나 늘었다
	var s := st.quests.stage("MQ-104")
	if s >= 40 and s < 45:                                              # 벙커를 다 본 뒤에만 단계 45(먼저 호송차를 털면 조사 단계 20→30이 막히던 것 — SD-20 N1)
		st.quests.set_stage("MQ-104", 45)
	host.play_scene.call_deferred("MQ-104_DOYUN_FREE")
	_log("하도윤 구출")


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


# ---------------------------------------------------------------- MQ-105 새벽인력 본소(@cmd sb …, 1-6)
## 지금 서 있는 본소 구역: "X-SB"(월드의 손 맵) · "H-02"~"H-05" · ""(밖)
## 잡혀 왔다(습격 중이었어도): 마당은 잡았으니 가라앉는다 — 교대 조가 다시 선다
func _on_captured() -> void:
	if v("SB_RAID") == 1:
		st.vars.set_v("SB_RAID", 0)
		for k in st.boxes.keys():
			if str(k).begins_with("sbclear:"):
				st.boxes.erase(k)
		_log("습격 중 생포 → 습격 끝")


func _sb_where() -> String:
	if host.map == null:
		return ""
	if host.map.id == "X-SB" or host.map.id.begins_with("H-0"):
		return host.map.id
	return ""


func _sb_local() -> Vector2i:
	return host.map.tile_of(host.player.loco.logical) - WorldMap.origin_of("X-SB")


func _sb_enter() -> void:
	var s := st.quests.stage("MQ-105")
	if s >= 20:
		return
	if st.quests.stage("MQ-102") == 0:
		_open_hub()
	if s < 10:
		st.quests.set_stage("MQ-105", 10)
	st.quests.set_stage("MQ-105", 20)
	st.places.raise("L-R02-19", PlaceLog.FOUND)
	_log("본소 들어옴")


func _sb_tick() -> void:
	var where := _sb_where()
	if where != _sb_zone:
		_sb_zone = where
		if where == "X-SB":
			_sb_map("X-SB")
	var inside := where != "" and (where != "X-SB" or SB_WALLS.has_point(_sb_local()))
	if inside and where != "X-SB":
		_sb_enter()
	elif where == "X-SB" and SB_YARD.has_point(_sb_local()):
		_sb_enter()
	# 장부를 들고 본소를 나섰다 = 결정(SD-03a §8.5 '가지고 나가기도 결정이다')
	if not inside and st.items.has("M-211") and st.quests.stage("MQ-105") >= 30 and st.quests.stage("MQ-105") < 100:
		_sb_decide(0)
	_sb_watch(where)
	_sb_collar(inside)
	if not _sb.is_empty():
		_sb = _sb.filter(func(e): return is_instance_valid(e) and not e.cmb.dead)
		if _sb.is_empty() and host.map != null:
			st.boxes["sbclear:" + host.map.id] = {"open": true}
	if is_instance_valid(_hdc) and not _hdc.cmb.dead:
		if _hdc_burn < 0.0 and _hdc.cmb.hp <= _hdc.cmb.max_hp * 0.3 and v("SB_SAFE") == 0 and v("SB_READ") == 0:
			_hdc_burn = SB_BURN_SECS
			host.hint("황두칠이 금고로 달려간다 — 장부를 난로에 처넣으려 한다!", 4.0)
		elif _hdc_burn > 0.0:
			_hdc_burn -= 0.5
			if _hdc_burn <= 0.0:
				st.vars.set_v("SB_BURNT", 1)
				st.vars.set_v("SB_SAFE", 1)
				st.vars.set_v("HO_LEDGER", 99)
				host.map.set_prop_state(Vector2i(36, 11), "open")
				host.hint("난로 속에서 장부가 타오른다. 의뢰서 봉투만 황두칠의 외투 안에 남았다.", 5.0)
				_log("황두칠이 장부를 태움")


## 표찰 없이 담 안에 선 사람: 6칸 안 · 서 있음(웅크리면 못 봄) → 경고 한 번, 3초 뒤에도 보이면 습격
func _sb_watch(where: String) -> void:
	if v("SB_RAID") != 0 or v("SB_DEAL") == 1 or v("SB_PASS") == 1 or v("SB_PASS") == 2 or where == "" or host.box.active or host.ev.busy() \
			or (st.quests.stage("FQ-SB-01") >= 10 and st.quests.stage("FQ-SB-01") < 200):
		_sb_warn = -1.0                                                 # 출근부 일꾼(FQ-SB-01을 받음 — 끊김 200 전)은 마당 사람이다(1-12f)
		return
	if where == "X-SB" and not SB_YARD.has_point(_sb_local()):
		_sb_warn = -1.0
		return
	if where == "H-03" and v("CAPTURE_BY") == 1 and Rect2i(13, 3, 6, 5).has_point(host.map.tile_of(host.player.loco.logical)):
		return                                                          # 잡혀 온 사람은 제 칸 안이 제자리다(칸 밖으로 나오면 감시 의자 경비가 본다 — 1-11h)
	var seen := ""
	var me: Vector2 = host.player.loco.logical
	for n in host.npcs:
		if str(n["id"]) == "N-R02-038":                                 # 철사는 감시를 안 선다 — 눈이 멀어 가고, 렌즈를 낀 뒤엔 그걸 준 사람이다(UQ-08 재미 검수 · 서사 대조 중3)
			if v("UQ08_LENS") == 2 and v("UQ08_TAGSAID") == 0 and not host.combat.crouch and is_instance_valid(n["actor"]) \
					and n["actor"].loco.logical.distance_to(me) <= 4.0 * 32.0:
				st.vars.set_v("UQ08_TAGSAID", 1)
				host.combat._pop("(고글 너머로) …너구나. 표찰은 좀 달고 다녀.", n["actor"].loco.logical + Vector2(0, -40), Color("D8C890"))
			continue
		if SB_ROLE.has(str(n["id"])) and is_instance_valid(n["actor"]) and n["actor"].visible \
				and n["actor"].loco.logical.distance_to(me) <= 6.0 * 32.0 and not host.combat.crouch \
				and host.map.line_of_sight(n["actor"].loco.logical, me):
			seen = str(n["id"])
			break
	if seen == "":
		if _sb_warn > 0.0:
			_sb_warn = -1.0
		return
	if _sb_warn < 0.0:
		_sb_warn = 3.0
		host.combat._pop("거기! 표찰 없는 놈이다. 나가!", me + Vector2(0, -40), Color("E04A35"))
		host.hint("들켰다 — 3초 안에 시야를 벗어나거나 몸을 낮춘다", 3.0)
		return
	_sb_warn -= 0.5
	if _sb_warn <= 0.0:
		_sb_warn = -1.0
		_sb_raid("들킴")


## 근태 목걸이를 찬 채 본소 밖(SD-06 · H-03 '마당 문 밖으로 나가면 터진다'): 6초 삑삑 → 폭발(최대 HP 60%)
func _sb_collar(inside: bool) -> void:
	if v("SB_COLLAR") == 0 or inside or host.map == null or not (host.map is WorldMap):
		_collar = -1.0
		return
	if _collar < 0.0:
		_collar = 6.0
		host.hint("목걸이가 빠르게 삑삑거린다 — 담 밖이다!", 3.0)
		return
	_collar -= 0.5
	if _collar <= 0.0:
		_collar = -1.0
		st.vars.set_v("SB_COLLAR", 0)
		if v("UQ08_SAFE") == 1 and v("CAPTURE_AT") >= v("UQ08_SAFE_AT") + 1440 and (v("UQ08_WIRE_AT") == 0 or v("CAPTURE_AT") < v("UQ08_WIRE_AT")):   # UQ-08 ② 뒤 감긴 목걸이 — 담 밖 기폭 신호에 '원격 해제 = 무조건 열림'(계획 1-12h §8b S5)
			st.vars.set_v("UQ08_HEAT", v("UQ08_HEAT") + 1)
			st.vars.set_v("UQ08_SNAP_DAY", int(st.vars.get_v("GAME_DAY")))
			host.hint("삑, 삑 — 딸깍. 목걸이가 두 쪽으로 벌어져 발치에 떨어진다. 뒤판 땜 자국이 낯익다.", 5.0)
			_log("목걸이가 담 밖에서 열림(UQ-08 ②)")
			return
		host.combat.damage(host.combat.pc.max_hp * 0.6)
		host.hint("목걸이가 터졌다. 귀가 먹먹하다.", 5.0)
		_log("목걸이 폭발")


func _on_sb_hit(id: String) -> void:
	if SB_ROLE.has(id) and _sb_where() != "" and v("SB_RAID") == 0:
		_sb_raid("마당 사람을 침")


## 정면 습격: 이 맵의 평시 인물을 적으로 바꾸고, 마당이면 모자란 만큼 습격 자리에 붙인다
func _sb_raid(why: String) -> void:
	if v("SB_RAID") != 0:
		return
	st.vars.set_v("SB_RAID", 1)
	st.call_fn("aff", ["SB", -10])
	_log("정면 습격(%s)" % why)
	host.hint("새벽인력이 몰려나온다!", 4.0)
	for n in host.npcs:
		var id := str(n["id"])
		if SB_ROLE.has(id) and is_instance_valid(n["actor"]) and n["actor"].visible:
			_sb_spawn(id, n["actor"].loco.logical)
			n["actor"].visible = false
			host.map.blockers.erase(n["actor"])
	if host.map.id == "X-SB":
		_sb_fill()


func _sb_lv(boss := false) -> int:
	var pl := int(host.level())
	return clampi(pl + 3, 8, 22) if boss else clampi(pl + 2, 4, 22)       # 정합: 위협 4(Lv 10~22)를 1막 레벨에 맞춰 낮춘다


func _sb_spawn(id: String, p: Vector2) -> Enemy:
	var cr: String = SB_ROLE[id]
	var opts := {"lv": _sb_lv(cr == "CR-513")}
	if id.begins_with("C-") or id.begins_with("N-"):
		opts["who"] = id
	if id == "CR-436" and host.map.id == "X-SB":
		opts["arm"] = "rifle"                                            # 옥상 저격수(추심원 소총 판본)
	var e := host.combat.spawn(cr, p, host.map, st, opts)
	e.brain.gauge = 100.0
	e.set_meta("capture", "SB")                                         # 새벽인력은 '생포만'(칠판 맨 아랫줄): 지면 우리에서 깬다
	_sb.append(e)
	if id == "C-013":
		_hdc = e
		_hdc_burn = -1.0
	return e


func _sb_fill() -> void:
	var have := _sb.filter(func(e): return is_instance_valid(e) and not e.cmb.dead and str(e.get_meta("enemy_id")) != "CR-107").size()
	var ids := ["CR-437", "CR-436", "CR-437", "CR-435", "CR-438", "CR-437", "CR-436", "CR-435", "CR-436", "CR-436"]
	for i in range(SB_RAID_N):
		if have >= SB_RAID_N:
			break
		var p: Vector2 = host.map.mark_pos("raid_%d" % (i + 1))
		_sb_spawn(ids[i], p)
		have += 1


## 맵에 들어옴: 습격 중이면 그 맵 사람도 적으로 · 우리 문·금고 상태를 되살린다
func _sb_map(id: String) -> void:
	if v("CAPTURE_BY") == 1 and v("SB_CUFF") == 0 and not (id == "X-SB" or id.begins_with("H-0") or id == "K-23"):
		st.vars.set_v("CAPTURE_BY", 0)                                   # 본소를 빠져나갔다: 더는 '잡혀 온 사람'이 아니다(남아 있으면 H-03 감시·습격이 영영 꺼지던 것)
		_log("생포 탈출 — 본소 밖")
	if not (id == "X-SB" or id.begins_with("H-0")):
		return
	if id != "X-SB":
		_sb_enter()
	_sb.clear()
	_hdc = null
	if v("SB_RAID") == 1 and not st.boxes.has("sbclear:" + id):
		for n in host.map.data.get("npcs", []):
			var nid := str(n["id"])
			if not SB_ROLE.has(nid) or st.is_dead(nid) or (nid == "C-013" and st.is_dead("C-013")):
				continue
			if host.map is WorldMap and host.map.zone_of(Vector2i(int(n["x"]), int(n["y"]))) != "X-SB":
				continue
			if nid == "C-013" and id != "H-04":
				continue                                                # 습격 중 황두칠은 소장실을 지킨다
			_sb_spawn(nid, Vector2(int(n["x"]) * 32 + 16, int(n["y"]) * 32 + 16))
		if id == "X-SB":
			_sb_fill()
	if id == "H-03" and v("CAPTURE_BY") == 1:
		_on_captured()
	if id == "H-03":
		for x in SB_CAGES:
			if st.boxes.has("sbcage:%d" % x):
				host.ev.handlers["cage"].call(["open", x, 8], func() -> void: pass)
				_sb_hide_cage(x)
		if st.boxes.has("sb88"):
			_sb_hide_npc("N-R02-040")
	if id == "H-04" and v("SB_SAFE") == 1:
		host.map.set_prop_state(Vector2i(36, 11), "open")


func _sb_hide_npc(nid: String) -> void:
	for n in host.npcs:
		if str(n["id"]) == nid and is_instance_valid(n["actor"]):
			n["actor"].visible = false
			host.map.blockers.erase(n["actor"])


## 우리 칸(문 x 기준 왼쪽 3 · 오른쪽 2, 3~7행)의 사람(소품 · 인물)을 지운다
func _sb_hide_cage(x: int) -> void:
	var r := Rect2i(x - 3, 3, 6, 5)
	for p in host.map.props:
		if str(p["name"]).begins_with("detainee") and r.has_point(Vector2i(int(p["x"]), int(p["y"]))):
			p["node"].visible = false
			host.map._put_solid(int(p["x"]), int(p["y"]), 0)
	for n in host.npcs:
		if is_instance_valid(n["actor"]) and r.has_point(host.map.tile_of(n["actor"].loco.logical)):
			n["actor"].visible = false
			host.map.blockers.erase(n["actor"])


## 황두칠 사망(SD-03a §8.5 정면 습격: 카르마 +100 · 새벽 −30 · D_HDC): 허리춤 열쇠 · 외투 안주머니의 의뢰서 봉투
func _hdc_dead() -> void:
	st.kill("C-013")                                                  # D_HDC는 이 사실에서 계산된다(StoryState.DEAD_VARS)
	st.call_fn("karma", [100])
	st.call_fn("aff", ["SB", -30])
	st.vars.set_v("SB_RAID", 2)
	st.vars.set_v("SB_KEY", 1)
	st.book.died("C-013", host.date_text)
	_hdc_burn = -1.0
	_log("황두칠 사망")
	if v("SB_READ") == 0:
		host.play_scene.call_deferred("MQ-105_COAT")
	else:
		host.hint("허리춤 열쇠고리를 챙겼다.", 4.0)


func _sb_read() -> void:
	if v("SB_READ") == 1:
		return
	var later := v("K_CODE") >= 1
	st.vars.set_v("SB_READ", 1)
	st.call_fn("give", ["M-212", 1])
	st.vars.set_v("K_CODE", 1)
	st.vars.set_v("K_NET", 1)
	if v("K_LINE") == 0:
		st.vars.set_v("K_LINE", 1)                                       # 시공 확인서 사본(K_LINE 일부, SD-03a §8.5)
	st.call_fn("xp", [180 if later else 300])
	_sb_enter()
	if st.quests.stage("MQ-105") < 30:
		st.quests.set_stage("MQ-105", 30)
	_log("장부 읽음(XP %d)" % (180 if later else 300))


func _sb_decide(ho: int) -> void:
	st.vars.set_v("HO_LEDGER", ho)
	if st.quests.stage("MQ-105") < 30:
		_sb_read()
	if st.quests.stage("MQ-105") < 100:
		st.quests.set_stage("MQ-105", 100)
		_log("MQ-105 완료(HO_LEDGER %d)" % ho)


func _sb_safe_open() -> void:
	st.vars.set_v("SB_SAFE", 1)
	host.map.set_prop_state(Vector2i(36, 11), "open")
	if v("SB_BURNT") == 0 and not st.items.has("M-211") and v("HO_LEDGER") != 81 and v("HO_LEDGER") != 1 and v("HO_LEDGER") != 99:
		host.play_scene.call_deferred("MQ-105_LEDGER" if v("SB_READ") == 0 else "H-04_SAFE")


## 우리 문 하나를 연다(주인공 앞 가장 가까운 닫힌 문 · only면 그 칸): 갇힌 사람이 뒷문 통로로 빠져나간다. 여섯이 다 나가면 카르마 +100 · 새벽 −15 · 고향 +5
func _sb_free(only := -1) -> void:
	var me := host.map.tile_of(host.player.loco.logical)
	var best := -1
	for x in SB_CAGES:
		if st.boxes.has("sbcage:%d" % x):
			continue
		if (only >= 0 and x != only) or (only < 0 and x == 10):
			continue                                                    # 127번 칸은 그 칸 문 장면(SQS09_CAGE10 — 목걸이부터)만 연다(1-11h)
		if best < 0 or absi(x - me.x) < absi(best - me.x):
			best = x
	if best < 0:
		return
	st.boxes["sbcage:%d" % best] = {"open": true}
	host.ev.handlers["cage"].call(["open", best, 8], func() -> void: pass)
	var kira_in := best == 22 and not st.boxes.has("sb88") and v("SQ_S10_KIRA") in [0, 7] and v("SB_DEBT") == 0 and not st.is_dead("N-R02-040")   # 88번이 칸에 있나(1-11i — 고척으로 옮겨졌으면 없다)
	var n: int = SB_CAGES[best] - (1 if best == 22 and not kira_in else 0) - (1 if best == 10 and st.boxes.has("sb127") else 0)
	if best == 10 and v("SB_127") < 2:
		st.vars.set_v("SB_127", 2)                                        # 127번을 우리에서 빼 왔다(훅 「127번」)
	st.vars.set_v("SB_FREED", v("SB_FREED") + n)
	var said := {10: "127번 — 채윤재가 판자 틈으로 빠져나간다. '할매 칸에서 기다릴게. 구로 107동.'", 22: "88번 — 기라희가 문살을 놓는다. 세이프빌 대신 노들로 간다고 했다."}
	if best == 22 and not kira_in:
		said.erase(22)
	host.hint(said.get(best, "철창 안 사람이 말없이 뒷문 통로로 빠져나간다."), 5.0)
	_sb_hide_cage(best)
	if v("SB_FREED") >= 6 and not st.boxes.has("sbfreed6"):
		st.boxes["sbfreed6"] = {"open": true}
		st.call_fn("karma", [100])
		st.call_fn("aff", ["SB", -15])
		st.call_fn("aff", ["JC_BC", 5])                                   # 구출된 사람의 고향(우리 벽의 고향 이름 — 봉천이 가장 많다)
		host.hint("우리에 남은 사람이 없다. 여섯이 모두 뒷문 통로로 나갔다.", 6.0)
		_log("인력 여섯 풀어 줌")


func _sb_cmd(a: Array, done: Callable) -> void:
	match str(a[0]):
		"enter":
			_sb_enter()
		"pass":
			host.hint("손님 표찰을 목에 걸었다 — 마당과 본동을 다닐 수 있다", 5.0)
		"shoo":
			host.hint("번호표 없이는 마당에 못 들어간다. 다른 길도 있을 것이다.", 5.0)
		"surrender":
			host.capture.call_deferred("SB")
		"raid":
			_sb_raid("원고")
		"pick":
			if Lockpick.can_try(50, st.skill("LOCKPICK")):
				host.open_lock(50, "dial", func() -> void: _sb_safe_open())
			else:
				host.hint("다이얼이 단단하다. [자물쇠 따기 50 필요]", 4.0)
		"safe":
			_sb_safe_open()
		"safe_show":
			pass
		"read":
			_sb_read()
		"took":
			host.hint("장부를 챙겼다 — 어디에 넘길지는 걸으며 정한다", 5.0)
		"decide":
			_sb_decide(int(a[1]))
		"burned":
			if v("SB_RAID") == 0 and _sb_where() == "X-SB":
				host.hint("불길이 치솟자 마당이 술렁인다 — 장부 타는 냄새를 모를 리 없다!", 4.0)
				_sb_raid("장부를 태움")
		"hatch":
			host.enter("H-04", "from_roof")
		"dogs":
			for e in host.combat.enemies.duplicate():
				if is_instance_valid(e) and str(e.get_meta("enemy_id", "")) == "CR-107":
					host.combat.drop_enemy(e)
			host.hint("개들이 고기에 정신이 팔렸다. 뒷마당을 지나갈 수 있다.", 4.0)
		"buy":                                                          # 소장에게 값을 치르고 산 '인력'(88 · 127): 그 사람만 우리에서 나간다
			st.boxes["sb%s" % str(a[1])] = {"open": true}
			st.vars.set_v("SB_FREED", v("SB_FREED") + 1)
		"sleep":                                                        # 은신처에서 잔다(길금순 칸 · 1-6): 8시간 · 체력 회복(침대 휴식, SD-11 '자연 회복 없음'과 별개)
			host.ev.run("fade_out", ["black", "8"], func() -> void:
				host.advance_minutes(8 * 60)
				host.combat.pc.hp = host.combat.pc.max_hp
				host.ev.run("fade_in", ["black", "8"], func() -> void:
					host.hint("푹 잤다. 몸이 가볍다. (%s)" % host.date_text.substr(13), 4.0)))
		"wardrobe":
			if host.map != null and host.map.id == "K-20":
				host.map.unlock_door(27, 1)
				host.hint("할매가 벽장 문고리를 돌려 준다. 벽 사이로 바람이 분다.", 4.0)
		"free":
			_sb_free()
		"free10":                                                       # 127번 칸(SQ-S09 진행기가 부른다 — 목걸이가 풀렸거나 습격 중)
			_sb_free(10)
	done.call()
